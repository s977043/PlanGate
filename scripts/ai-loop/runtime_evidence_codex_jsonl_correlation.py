#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """runtime_evidence_codex_jsonl_correlation.py — Codex JSONL correlation candidate.

Correlates a reviewed Explorer lifecycle-hook candidate with the public
`codex exec --json` event envelope.

The public Codex eval guidance documents JSONL structured events such as
item.started / item.completed and turn.completed. This module also accepts the
observed thread/turn envelope used by the current Codex CLI, but does not treat
undocumented item types as a stable public schema contract.

The strongest result in this slice is a same-parent-thread candidate plus one
successful turn envelope. It cannot independently match hook turn_id or agent_id
to an exec JSONL field, so strong runtime attestation remains false.
"""

import argparse
import hashlib
import json
import pathlib
import re
import stat
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_codex_probe_candidate as probe  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-codex-jsonl-correlation/v1"
CONTRACT_STAGE = "r1-codex-jsonl-correlation-candidate-v1"

MAX_EXEC_JSONL_BYTES = 2 * 1024 * 1024
MAX_EXEC_EVENTS = 512
ID_RE = re.compile(r"^[A-Za-z0-9_.:/-]{1,256}$")

TOP_LEVEL_EVENTS = {
    "thread.started",
    "turn.started",
    "turn.completed",
    "turn.failed",
    "item.started",
    "item.completed",
    "error",
}
ITEM_EVENTS = {"item.started", "item.completed"}
DOCUMENTED_ITEM_TYPES = {"command_execution"}
FORBIDDEN_R1_ITEM_TYPES = {"file_change", "web_search", "error"}


class CodexJsonlCorrelationError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _require_trace_outside_repo(
    path: str | pathlib.Path,
    repo_root: str | pathlib.Path,
    field: str,
) -> pathlib.Path:
    root = pathlib.Path(repo_root).resolve()
    source = pathlib.Path(path)
    if not source.is_absolute():
        raise CodexJsonlCorrelationError(
            [f"{field}: absolute path required"]
        )
    raw_parent = source.parent
    parent = raw_parent.resolve()
    target = source.resolve(strict=False)

    if not root.is_dir():
        raise CodexJsonlCorrelationError(
            ["repo_root: existing directory required"]
        )
    if not raw_parent.is_dir():
        raise CodexJsonlCorrelationError(
            [f"{field}: parent directory must exist"]
        )
    if parent != raw_parent:
        raise CodexJsonlCorrelationError(
            [f"{field}: parent path must not traverse symlinks"]
        )
    if not source.exists():
        raise CodexJsonlCorrelationError(
            [f"{field}: trace file must exist"]
        )
    mode = source.lstat().st_mode
    if stat.S_ISLNK(mode):
        raise CodexJsonlCorrelationError(
            [f"{field}: trace file symlink is not allowed"]
        )
    if not stat.S_ISREG(mode):
        raise CodexJsonlCorrelationError(
            [f"{field}: regular file required"]
        )
    try:
        target.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False
    if inside_repo:
        raise CodexJsonlCorrelationError(
            [f"{field}: trace must stay outside repository"]
        )
    return source


def load_hook_jsonl(
    path: str | pathlib.Path,
    *,
    repo_root: str | pathlib.Path | None = None,
) -> tuple[list[Any], str]:
    source = pathlib.Path(path)
    if repo_root is not None:
        source = _require_trace_outside_repo(
            source,
            repo_root,
            "hooks_jsonl",
        )
    try:
        raw = source.read_bytes()
    except OSError as exc:
        raise CodexJsonlCorrelationError(
            [f"hooks_jsonl: cannot read: {exc}"]
        ) from exc

    if len(raw) > probe.MAX_JSONL_BYTES:
        raise CodexJsonlCorrelationError(
            ["hooks_jsonl: file exceeds 1 MiB limit"]
        )

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise CodexJsonlCorrelationError(
            ["hooks_jsonl: UTF-8 required"]
        ) from exc

    values: list[Any] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if len(values) >= probe.MAX_JSONL_RECORDS:
            raise CodexJsonlCorrelationError(
                ["hooks_jsonl: record count exceeds limit"]
            )
        stripped = line.strip()
        if not stripped:
            continue
        try:
            values.append(json.loads(stripped))
        except json.JSONDecodeError as exc:
            raise CodexJsonlCorrelationError(
                [f"hooks_jsonl line {line_number}: invalid JSON"]
            ) from exc

    return values, _sha256_bytes(raw)


def load_exec_jsonl(
    path: str | pathlib.Path,
    *,
    repo_root: str | pathlib.Path | None = None,
) -> tuple[list[Any], str]:
    source = pathlib.Path(path)
    if repo_root is not None:
        source = _require_trace_outside_repo(
            source,
            repo_root,
            "exec_jsonl",
        )
    try:
        raw = source.read_bytes()
    except OSError as exc:
        raise CodexJsonlCorrelationError(
            [f"exec_jsonl: cannot read: {exc}"]
        ) from exc

    if len(raw) > MAX_EXEC_JSONL_BYTES:
        raise CodexJsonlCorrelationError(
            ["exec_jsonl: file exceeds 2 MiB limit"]
        )

    events: list[Any] = []
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise CodexJsonlCorrelationError(
            ["exec_jsonl: UTF-8 required"]
        ) from exc

    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped:
            continue
        if len(events) >= MAX_EXEC_EVENTS:
            raise CodexJsonlCorrelationError(
                ["exec_jsonl: event count exceeds limit"]
            )
        try:
            events.append(json.loads(stripped))
        except json.JSONDecodeError as exc:
            raise CodexJsonlCorrelationError(
                [f"exec_jsonl line {line_number}: invalid JSON"]
            ) from exc

    return events, _sha256_bytes(raw)


def _validate_exec_events(events: Any) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    if not isinstance(events, list):
        return ["exec_events: array required"], {}

    if not events:
        return ["exec_events: non-empty array required"], {}

    summaries: list[dict[str, Any]] = []
    thread_ids: list[str] = []
    turn_started = 0
    turn_completed = 0
    turn_failed = 0
    top_errors = 0
    forbidden_items: list[str] = []
    undocumented_item_types: list[str] = []

    for index, event in enumerate(events):
        prefix = f"exec_events[{index}]"
        if not isinstance(event, dict):
            errors.append(f"{prefix}: object required")
            continue

        event_type = event.get("type")
        if event_type not in TOP_LEVEL_EVENTS:
            errors.append(
                f"{prefix}.type: unsupported exec JSONL event {event_type!r}"
            )
            continue

        summary: dict[str, Any] = {"type": event_type}

        if event_type == "thread.started":
            thread_id = event.get("thread_id")
            if not isinstance(thread_id, str) or not ID_RE.fullmatch(thread_id):
                errors.append(f"{prefix}.thread_id: bounded identifier required")
            else:
                thread_ids.append(thread_id)
                summary["thread_id"] = thread_id

        elif event_type == "turn.started":
            turn_started += 1

        elif event_type == "turn.completed":
            turn_completed += 1
            usage = event.get("usage")
            if not isinstance(usage, dict):
                errors.append(f"{prefix}.usage: object required")

        elif event_type == "turn.failed":
            turn_failed += 1
            errors.append(f"{prefix}: failed turn is not an R1 success candidate")

        elif event_type == "error":
            top_errors += 1
            errors.append(f"{prefix}: top-level Codex error event is not allowed")

        elif event_type in ITEM_EVENTS:
            item = event.get("item")
            if not isinstance(item, dict):
                errors.append(f"{prefix}.item: object required")
            else:
                item_type = item.get("type")
                item_id = item.get("id")
                if not isinstance(item_type, str) or not ID_RE.fullmatch(item_type):
                    errors.append(
                        f"{prefix}.item.type: bounded identifier required"
                    )
                elif item_type not in DOCUMENTED_ITEM_TYPES:
                    undocumented_item_types.append(item_type)
                if not isinstance(item_id, str) or not ID_RE.fullmatch(item_id):
                    errors.append(f"{prefix}.item.id: bounded identifier required")
                summary["item_type"] = item_type
                if isinstance(item_id, str):
                    summary["item_id"] = item_id
                status = item.get("status")
                if isinstance(status, str):
                    summary["status"] = status
                if item_type in FORBIDDEN_R1_ITEM_TYPES:
                    forbidden_items.append(str(item_type))
                    errors.append(
                        f"{prefix}.item.type: {item_type} forbidden in R1 candidate"
                    )

        summaries.append(summary)

    if not isinstance(events[0], dict) or events[0].get("type") != "thread.started":
        errors.append("exec_events: thread.started must be the first event")

    event_types = [
        event.get("type") if isinstance(event, dict) else None
        for event in events
    ]
    if "turn.started" in event_types and "turn.completed" in event_types:
        start_index = event_types.index("turn.started")
        completed_index = event_types.index("turn.completed")
        if start_index <= 0:
            errors.append(
                "exec_events: turn.started must follow thread.started"
            )
        if completed_index <= start_index:
            errors.append(
                "exec_events: turn.completed must follow turn.started"
            )
        if completed_index != len(events) - 1:
            errors.append(
                "exec_events: turn.completed must be the final event"
            )
        for index, event_type in enumerate(event_types):
            if event_type in ITEM_EVENTS and not (
                start_index < index < completed_index
            ):
                errors.append(
                    f"exec_events[{index}]: item event must stay inside turn boundary"
                )

    if len(thread_ids) != 1:
        errors.append("exec_events: exactly one thread.started required")
    if turn_started != 1:
        errors.append("exec_events: exactly one turn.started required")
    if turn_completed != 1:
        errors.append("exec_events: exactly one turn.completed required")
    if turn_failed:
        errors.append("exec_events: turn.failed must be absent")
    if top_errors:
        errors.append("exec_events: top-level error must be absent")

    return errors, {
        "thread_id": thread_ids[0] if len(thread_ids) == 1 else None,
        "turn_started_count": turn_started,
        "turn_completed_count": turn_completed,
        "event_count": len(events),
        "forbidden_item_types": sorted(set(forbidden_items)),
        "undocumented_item_types": sorted(set(undocumented_item_types)),
        "event_summaries": summaries,
    }


def correlate_candidate(
    *,
    hook_records: Any,
    exec_events: Any,
    request_hash: str,
    config_sha: str,
    provider: str,
    hook_jsonl_sha256: str,
    exec_jsonl_sha256: str,
) -> dict[str, Any]:
    hook_result = probe.verify_candidate_trace(
        records=hook_records,
        request_hash=request_hash,
        config_sha=config_sha,
        provider=provider,
    )

    errors, exec_summary = _validate_exec_events(exec_events)
    thread_id = exec_summary.get("thread_id")
    if thread_id != hook_result.get("session_id"):
        errors.append(
            "correlation: hook session_id must match exec thread.started.thread_id"
        )

    if not probe.HASH_RE.fullmatch(hook_jsonl_sha256):
        errors.append("hook_jsonl_sha256: sha256:<64 lowercase hex> required")
    if not probe.HASH_RE.fullmatch(exec_jsonl_sha256):
        errors.append("exec_jsonl_sha256: sha256:<64 lowercase hex> required")

    if errors:
        raise CodexJsonlCorrelationError(errors)

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "provider": provider,
        "platform": "codex",
        "runtime_role": probe.EXPECTED_AGENT_TYPE,
        "hook_session_id": hook_result["session_id"],
        "hook_turn_id": hook_result["turn_id"],
        "hook_agent_id": hook_result["agent_id"],
        "exec_thread_id": thread_id,
        "hook_jsonl_sha256": hook_jsonl_sha256,
        "exec_jsonl_sha256": exec_jsonl_sha256,
        "trace_content_binding_verified": True,
        "exec_jsonl_structure_verified": True,
        "identifier_value_match_verified": True,
        "hook_session_id_equals_exec_thread_id": True,
        "session_thread_semantic_binding_verified": False,
        "parent_thread_correlation_candidate": True,
        "parent_thread_correlation_verified": False,
        "thread_id_correlation_verified": False,
        "single_turn_envelope_verified": True,
        "explicit_forbidden_item_type_absence_verified": True,
        "documented_item_schema_coverage_complete": (
            len(exec_summary["undocumented_item_types"]) == 0
        ),
        "undocumented_item_type_count": len(
            exec_summary["undocumented_item_types"]
        ),
        "command_execution_read_only_verified": False,
        "mcp_tool_read_only_verified": False,
        "repository_postcondition_verified": False,
        "turn_id_exposed_in_exec_jsonl": False,
        "turn_id_correlation_verified": False,
        "subagent_identity_exposed_in_exec_jsonl": False,
        "subagent_identity_correlation_verified": False,
        "same_subagent_execution_correlated": False,
        "hook_execution_root_attested": False,
        "codex_jsonl_thread_correlation_verified": False,
        "codex_jsonl_runtime_correlation_verified": False,
        "hard_read_only_enforced": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "hook session_id and exec thread_id have equal identifier values, "
            "but the current public contract reviewed here does not independently "
            "guarantee that those differently named fields are the same semantic "
            "thread identity. A successful turn envelope is observed, while "
            "subagent identity/turn binding, command/MCP read-only semantics, "
            "repository postconditions, and undocumented item schema coverage "
            "remain unverified"
        ),
        "event_summary": {
            "event_count": exec_summary["event_count"],
            "turn_started_count": exec_summary["turn_started_count"],
            "turn_completed_count": exec_summary["turn_completed_count"],
        },
        "authority": {
            "agent_invoke_allowed": False,
            "code_write_allowed": False,
            "approval_write_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }
    result["result_hash"] = ingress._canonical_hash(result)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--hooks-jsonl", required=True)
    parser.add_argument("--exec-jsonl", required=True)
    parser.add_argument("--request-hash", required=True)
    parser.add_argument("--config-sha", required=True)
    parser.add_argument("--provider", required=True)
    args = parser.parse_args(argv)

    try:
        hook_records, hook_sha = load_hook_jsonl(
            args.hooks_jsonl,
            repo_root=args.repo_root,
        )
        exec_events, exec_sha = load_exec_jsonl(
            args.exec_jsonl,
            repo_root=args.repo_root,
        )
        result = correlate_candidate(
            hook_records=hook_records,
            exec_events=exec_events,
            request_hash=args.request_hash,
            config_sha=args.config_sha,
            provider=args.provider,
            hook_jsonl_sha256=hook_sha,
            exec_jsonl_sha256=exec_sha,
        )
    except (probe.CodexProbeCandidateError, CodexJsonlCorrelationError) as exc:
        errors = getattr(exc, "errors", [str(exc)])
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
