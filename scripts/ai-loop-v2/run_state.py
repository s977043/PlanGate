#!/usr/bin/env python3
"""ai-loop V2 durable RunState snapshot.

TASK-1392 / #1392.

This module owns persistence / CAS / crash recovery for the first V2 slice.
RunEvent semantics remain owned by #1391 (run_event.py).
"""

from __future__ import annotations

import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
from typing import Any, Iterable, Mapping

from run_event import (
    EventParseError,
    StreamContractError,
    finalize_event,
    validate_append,
    validate_event_draft,
    validate_stream,
)


SNAPSHOT_SCHEMA_VERSION = "1"
_RUN_ID_RE = re.compile(r"^RUN-[A-Z0-9][A-Z0-9_-]{0,63}$")
_SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
_COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")

_ALLOWED_STATES = {
    "PLANNING",
    "PLAN_VERIFYING",
    "EXECUTING",
    "VERIFYING",
    "DIAGNOSING",
    "REPAIRING",
    "REPLANNING",
    "PR_CONVERGING",
    "WAITING_HUMAN",
    "WAITING_EXTERNAL",
}
_ALLOWED_POLICY_VERDICTS = {None, "AUTO_APPROVED", "HUMAN_REQUIRED", "DENIED"}

_FIRST_SLICE_TRANSITIONS = {
    "PLAN_VERIFYING": {"EXECUTING", "REPLANNING"},
    "EXECUTING": {"VERIFYING"},
    "VERIFYING": {"DIAGNOSING", "PR_CONVERGING"},
    "DIAGNOSING": {"REPAIRING", "REPLANNING"},
    "REPAIRING": {"VERIFYING"},
    "REPLANNING": {"PLAN_VERIFYING"},
    "PR_CONVERGING": {"REPAIRING"},
}

_SNAPSHOT_KEYS = {"schema_version", "generation", "state", "events", "snapshot_ref"}
_STATE_REQUIRED_KEYS = {
    "run_id",
    "lifecycle_state",
    "revision",
    "pending_action",
    "policy_verdict",
    "harness_manifest_ref",
    "plan_hash",
    "source_sha",
}
_STATE_OPTIONAL_KEYS = {"resumed_from_run_id"}
_MAX_SNAPSHOT_BYTES = 16 * 1024 * 1024


class RunStateError(RuntimeError):
    pass


class RunNotFound(RunStateError):
    pass


class RunAlreadyExists(RunStateError):
    pass


class RevisionConflict(RunStateError):
    def __init__(self, expected: int, actual: int, conflict_event_ref: str | None = None):
        self.expected = expected
        self.actual = actual
        self.conflict_event_ref = conflict_event_ref
        super().__init__(
            f"revision conflict: expected={expected} actual={actual}"
            + (f" event={conflict_event_ref}" if conflict_event_ref else "")
        )


class TerminalRunError(RunStateError):
    pass


class SnapshotCorrupt(RunStateError):
    pass


class UnsupportedStateTransition(RunStateError):
    pass


class InjectedCrash(RuntimeError):
    def __init__(self, label: str):
        self.label = label
        super().__init__(f"injected crash at {label}")


def _require(condition: bool, message: str, exc=RunStateError) -> None:
    if not condition:
        raise exc(message)


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _strict_object_pairs(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise SnapshotCorrupt(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def _reject_constant(value: str):
    raise SnapshotCorrupt(f"non-finite JSON number: {value}")


def _strict_json_loads(raw: bytes) -> Any:
    try:
        text = raw.decode("utf-8", errors="strict")
        return json.loads(
            text,
            object_pairs_hook=_strict_object_pairs,
            parse_constant=_reject_constant,
        )
    except UnicodeDecodeError as exc:
        raise SnapshotCorrupt("snapshot is not strict UTF-8") from exc
    except json.JSONDecodeError as exc:
        raise SnapshotCorrupt("snapshot is not valid JSON") from exc


def _canonical_bytes(value: Mapping[str, Any]) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def _snapshot_without_ref(snapshot: Mapping[str, Any]) -> dict[str, Any]:
    return {k: copy.deepcopy(v) for k, v in snapshot.items() if k != "snapshot_ref"}


def canonical_snapshot_ref(snapshot_without_ref: Mapping[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(_canonical_bytes(snapshot_without_ref)).hexdigest()


def _validate_run_id(run_id: Any) -> str:
    _require(
        isinstance(run_id, str) and _RUN_ID_RE.fullmatch(run_id) is not None,
        "invalid run_id",
    )
    return run_id


def _validate_sha256(value: Any, label: str) -> str:
    _require(
        isinstance(value, str) and _SHA256_RE.fullmatch(value) is not None,
        f"invalid {label}",
    )
    return value


def _validate_commit(value: Any, label: str) -> str:
    _require(
        isinstance(value, str) and _COMMIT_RE.fullmatch(value) is not None,
        f"invalid {label}",
    )
    return value


def validate_state(state: Any) -> dict[str, Any]:
    _require(isinstance(state, dict), "state must be an object")
    unknown = set(state) - (_STATE_REQUIRED_KEYS | _STATE_OPTIONAL_KEYS)
    missing = _STATE_REQUIRED_KEYS - set(state)
    _require(not unknown, f"unknown RunState keys: {sorted(unknown)}")
    _require(not missing, f"missing RunState keys: {sorted(missing)}")

    run_id = _validate_run_id(state["run_id"])
    lifecycle = state["lifecycle_state"]
    _require(lifecycle in _ALLOWED_STATES, "invalid lifecycle_state")
    _require(
        _is_int(state["revision"]) and state["revision"] >= 0,
        "revision must be a non-negative int",
    )
    _require(
        state["pending_action"] is None,
        "pending_action is unsupported in the first slice",
    )
    _require(
        state["policy_verdict"] in _ALLOWED_POLICY_VERDICTS,
        "invalid policy_verdict",
    )
    harness_ref = _validate_sha256(state["harness_manifest_ref"], "harness_manifest_ref")
    plan_hash = _validate_sha256(state["plan_hash"], "plan_hash")
    source_sha = _validate_commit(state["source_sha"], "source_sha")

    resumed = state.get("resumed_from_run_id")
    if resumed is not None:
        _validate_run_id(resumed)

    out = {
        "run_id": run_id,
        "lifecycle_state": lifecycle,
        "revision": state["revision"],
        "pending_action": None,
        "policy_verdict": state["policy_verdict"],
        "harness_manifest_ref": harness_ref,
        "plan_hash": plan_hash,
        "source_sha": source_sha,
    }
    if resumed is not None:
        out["resumed_from_run_id"] = resumed
    return out


def _is_terminal(events: list[dict[str, Any]]) -> bool:
    if not events:
        return False
    last = events[-1]
    return (
        last.get("event_type") == "decision_made"
        and last.get("payload", {}).get("outcome") is not None
    )


def _validate_snapshot(snapshot: Any) -> dict[str, Any]:
    _require(isinstance(snapshot, dict), "snapshot must be an object", SnapshotCorrupt)
    unknown = set(snapshot) - _SNAPSHOT_KEYS
    missing = _SNAPSHOT_KEYS - set(snapshot)
    _require(not unknown, f"unknown snapshot keys: {sorted(unknown)}", SnapshotCorrupt)
    _require(not missing, f"missing snapshot keys: {sorted(missing)}", SnapshotCorrupt)
    _require(
        snapshot["schema_version"] == SNAPSHOT_SCHEMA_VERSION,
        "invalid snapshot schema_version",
        SnapshotCorrupt,
    )
    _require(
        _is_int(snapshot["generation"]) and snapshot["generation"] >= 1,
        "generation must be a positive int",
        SnapshotCorrupt,
    )
    _require(
        isinstance(snapshot["snapshot_ref"], str)
        and _SHA256_RE.fullmatch(snapshot["snapshot_ref"]) is not None,
        "invalid snapshot_ref",
        SnapshotCorrupt,
    )

    expected_ref = canonical_snapshot_ref(_snapshot_without_ref(snapshot))
    _require(
        snapshot["snapshot_ref"] == expected_ref,
        "snapshot_ref mismatch",
        SnapshotCorrupt,
    )

    try:
        state = validate_state(snapshot["state"])
        events = validate_stream(snapshot["events"])
    except (RunStateError, EventParseError, StreamContractError) as exc:
        raise SnapshotCorrupt(str(exc)) from exc

    first = events[0]
    for key in ("run_id", "harness_manifest_ref", "plan_hash", "source_sha"):
        _require(
            state[key] == first[key],
            f"state/event binding mismatch: {key}",
            SnapshotCorrupt,
        )

    out = {
        "schema_version": SNAPSHOT_SCHEMA_VERSION,
        "generation": snapshot["generation"],
        "state": state,
        "events": events,
    }
    out["snapshot_ref"] = canonical_snapshot_ref(out)
    return out


def _root(runtime_root: os.PathLike[str] | str) -> Path:
    path = Path(runtime_root)
    _require(path.is_absolute(), "runtime_root must be absolute")
    try:
        st = os.lstat(path)
    except OSError as exc:
        raise RunStateError("runtime_root is unavailable") from exc
    _require(stat.S_ISDIR(st.st_mode), "runtime_root must be a directory")
    _require(not stat.S_ISLNK(st.st_mode), "runtime_root symlink is not allowed")
    return path


def _paths(root: Path, run_id: str) -> tuple[Path, Path, Path]:
    safe = _validate_run_id(run_id)
    return (
        root / f"{safe}.lock",
        root / f"{safe}.json",
        root / f"{safe}.json.tmp",
    )


def _open_nofollow(path: Path, flags: int, mode: int = 0o600) -> int:
    flags |= getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags, mode)
    st = os.fstat(fd)
    if not stat.S_ISREG(st.st_mode):
        os.close(fd)
        raise RunStateError(f"not a regular file: {path.name}")
    return fd


def _fsync_dir(root: Path) -> None:
    flags = getattr(os, "O_DIRECTORY", 0) | os.O_RDONLY
    fd = os.open(root, flags)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _lock(root: Path, run_id: str):
    lock_path, _, _ = _paths(root, run_id)
    fd = _open_nofollow(lock_path, os.O_RDWR | os.O_CREAT)
    fcntl.flock(fd, fcntl.LOCK_EX)
    return fd


def _unlock(fd: int) -> None:
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)


def _cleanup_stale_temp(root: Path, run_id: str) -> None:
    _, _, temp_path = _paths(root, run_id)
    try:
        st = os.lstat(temp_path)
    except FileNotFoundError:
        return
    _require(stat.S_ISREG(st.st_mode), "stale temp is not a regular file")
    os.unlink(temp_path)
    _fsync_dir(root)


def _read_snapshot_unlocked(root: Path, run_id: str) -> dict[str, Any]:
    _, path, _ = _paths(root, run_id)
    try:
        fd = _open_nofollow(path, os.O_RDONLY)
    except FileNotFoundError as exc:
        raise RunNotFound(run_id) from exc
    try:
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            total += len(chunk)
            _require(total <= _MAX_SNAPSHOT_BYTES, "snapshot too large", SnapshotCorrupt)
            chunks.append(chunk)
        raw = b"".join(chunks)
    finally:
        os.close(fd)
    return _validate_snapshot(_strict_json_loads(raw))


def _fault(label: str, fault_at: str | None) -> None:
    if fault_at == label:
        raise InjectedCrash(label)


def _atomic_replace(
    root: Path,
    run_id: str,
    snapshot: Mapping[str, Any],
    *,
    fault_at: str | None = None,
) -> None:
    _, target, temp = _paths(root, run_id)
    _cleanup_stale_temp(root, run_id)

    data = _canonical_bytes(snapshot) + b"\n"
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    fd = _open_nofollow(temp, flags)
    try:
        _fault("after_temp_open", fault_at)
        offset = 0
        while offset < len(data):
            written = os.write(fd, data[offset:])
            _require(written > 0, "short write")
            offset += written
        _fault("after_temp_write", fault_at)
        os.fsync(fd)
        _fault("after_temp_fsync", fault_at)
    finally:
        os.close(fd)

    _fault("before_replace", fault_at)
    os.replace(temp, target)
    _fault("after_replace", fault_at)
    _fsync_dir(root)
    _fault("after_dir_fsync", fault_at)


def _build_snapshot(
    generation: int,
    state: Mapping[str, Any],
    events: list[dict[str, Any]],
) -> dict[str, Any]:
    base = {
        "schema_version": SNAPSHOT_SCHEMA_VERSION,
        "generation": generation,
        "state": validate_state(dict(state)),
        "events": validate_stream(events),
    }
    base["snapshot_ref"] = canonical_snapshot_ref(base)
    return base


def create_run(
    runtime_root: os.PathLike[str] | str,
    initial_state: Mapping[str, Any],
    plan_event_draft: Mapping[str, Any],
    *,
    fault_at: str | None = None,
) -> dict[str, Any]:
    root = _root(runtime_root)
    state = validate_state(dict(initial_state))
    _require(state["revision"] == 0, "initial revision must be 0")
    _require(
        state["lifecycle_state"] == "PLAN_VERIFYING",
        "first slice must start in PLAN_VERIFYING",
    )
    run_id = state["run_id"]
    fd = _lock(root, run_id)
    try:
        _cleanup_stale_temp(root, run_id)
        _, target, _ = _paths(root, run_id)
        if target.exists():
            raise RunAlreadyExists(run_id)

        draft = validate_event_draft(dict(plan_event_draft))
        _require(
            draft["event_type"] == "plan_contract_bound",
            "first event must be plan_contract_bound",
        )
        context = {
            "run_id": run_id,
            "harness_manifest_ref": state["harness_manifest_ref"],
            "plan_hash": state["plan_hash"],
            "source_sha": state["source_sha"],
            "revision": 0,
        }
        event = finalize_event(draft, context, 1)
        validate_append([], event)
        snapshot = _build_snapshot(1, state, [event])
        _atomic_replace(root, run_id, snapshot, fault_at=fault_at)
        return copy.deepcopy(snapshot)
    finally:
        _unlock(fd)


def load_run(
    runtime_root: os.PathLike[str] | str,
    run_id: str,
) -> dict[str, Any]:
    root = _root(runtime_root)
    run_id = _validate_run_id(run_id)
    fd = _lock(root, run_id)
    try:
        _cleanup_stale_temp(root, run_id)
        return copy.deepcopy(_read_snapshot_unlocked(root, run_id))
    finally:
        _unlock(fd)


def _transition_allowed(from_state: str, to_state: str) -> bool:
    return to_state in _FIRST_SLICE_TRANSITIONS.get(from_state, set())


def _terminal_draft(event: Mapping[str, Any]) -> bool:
    return (
        event["event_type"] == "decision_made"
        and event["payload"].get("outcome") is not None
    )


def commit(
    runtime_root: os.PathLike[str] | str,
    run_id: str,
    expected_revision: int,
    event_drafts: Iterable[Mapping[str, Any]] = (),
    *,
    transition_to: str | None = None,
    fault_at: str | None = None,
) -> dict[str, Any]:
    root = _root(runtime_root)
    run_id = _validate_run_id(run_id)
    _require(_is_int(expected_revision) and expected_revision >= 0, "invalid expected_revision")
    drafts = [validate_event_draft(dict(d)) for d in event_drafts]
    _require(bool(drafts) or transition_to is not None, "empty commit is not allowed")

    for d in drafts:
        _require(
            d["event_type"] not in {"state_transitioned", "state_conflict"},
            "state events are internal to #1392",
        )

    fd = _lock(root, run_id)
    try:
        _cleanup_stale_temp(root, run_id)
        snapshot = _read_snapshot_unlocked(root, run_id)
        state = snapshot["state"]
        events = list(snapshot["events"])

        if _is_terminal(events):
            raise TerminalRunError("run already has terminal Outcome")

        actual_revision = state["revision"]
        if expected_revision != actual_revision:
            next_seq = events[-1]["event_seq"] + 1
            conflict_ref = (
                f"state-conflict:{run_id}:{expected_revision}:{actual_revision}:{next_seq}"
            )
            draft = {
                "schema_version": "1",
                "event_type": "state_conflict",
                "payload": {
                    "conflict_ref": conflict_ref,
                    "expected_revision": expected_revision,
                    "actual_revision": actual_revision,
                },
                "evidence_refs": [],
            }
            context = {
                "run_id": run_id,
                "harness_manifest_ref": state["harness_manifest_ref"],
                "plan_hash": state["plan_hash"],
                "source_sha": state["source_sha"],
                "revision": actual_revision,
            }
            event = finalize_event(draft, context, next_seq)
            validate_append(events, event)
            conflict_events = events + [event]
            conflict_snapshot = _build_snapshot(
                snapshot["generation"] + 1,
                state,
                conflict_events,
            )
            _atomic_replace(root, run_id, conflict_snapshot, fault_at=fault_at)
            raise RevisionConflict(expected_revision, actual_revision, event["event_ref"])

        context = {
            "run_id": run_id,
            "harness_manifest_ref": state["harness_manifest_ref"],
            "plan_hash": state["plan_hash"],
            "source_sha": state["source_sha"],
            "revision": actual_revision,
        }

        terminal_seen = False
        for index, draft in enumerate(drafts):
            next_seq = events[-1]["event_seq"] + 1
            event = finalize_event(draft, context, next_seq)
            validate_append(events, event)
            if _terminal_draft(event):
                _require(
                    index == len(drafts) - 1,
                    "terminal decision must be final draft",
                )
                terminal_seen = True
            events.append(event)

        new_state = dict(state)
        if transition_to is not None:
            _require(not terminal_seen, "terminal decision cannot include state transition")
            _require(transition_to in _ALLOWED_STATES, "invalid transition target")
            _require(
                transition_to not in {"WAITING_HUMAN", "WAITING_EXTERNAL"},
                "WAITING_* transition unsupported in first slice",
            )
            _require(
                _transition_allowed(state["lifecycle_state"], transition_to),
                f"unsupported state transition: {state['lifecycle_state']} -> {transition_to}",
                UnsupportedStateTransition,
            )
            new_revision = actual_revision + 1
            transition_ref = (
                f"state-transition:{run_id}:{actual_revision}:{new_revision}:"
                f"{events[-1]['event_seq'] + 1}"
            )
            transition_draft = {
                "schema_version": "1",
                "event_type": "state_transitioned",
                "payload": {
                    "transition_ref": transition_ref,
                    "from_state": state["lifecycle_state"],
                    "to_state": transition_to,
                    "expected_revision": actual_revision,
                    "new_revision": new_revision,
                },
                "evidence_refs": [],
            }
            transition_context = dict(context)
            transition_context["revision"] = new_revision
            transition_event = finalize_event(
                transition_draft,
                transition_context,
                events[-1]["event_seq"] + 1,
            )
            validate_append(events, transition_event)
            events.append(transition_event)
            new_state["revision"] = new_revision
            new_state["lifecycle_state"] = transition_to

        next_snapshot = _build_snapshot(
            snapshot["generation"] + 1,
            new_state,
            events,
        )
        _atomic_replace(root, run_id, next_snapshot, fault_at=fault_at)
        return copy.deepcopy(next_snapshot)
    finally:
        _unlock(fd)


__all__ = [
    "InjectedCrash",
    "RevisionConflict",
    "RunAlreadyExists",
    "RunNotFound",
    "RunStateError",
    "SnapshotCorrupt",
    "TerminalRunError",
    "UnsupportedStateTransition",
    "canonical_snapshot_ref",
    "commit",
    "create_run",
    "load_run",
    "validate_state",
]
