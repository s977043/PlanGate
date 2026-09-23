#!/usr/bin/env python3
""":"
echo "ERROR: $0 is a Python script; use python3 $0" >&2
exit 2
":"""

from __future__ import annotations

import copy
import fcntl
import json
import os
from pathlib import Path

from run_event import finalize_event, validate_append, validate_event

ALLOWED_STATES = {
    "PLANNING", "PLAN_VERIFYING", "EXECUTING", "VERIFYING", "DIAGNOSING",
    "REPAIRING", "REPLANNING", "PR_CONVERGING", "WAITING_HUMAN",
    "WAITING_EXTERNAL",
}


class StateConflict(RuntimeError):
    pass


class StateStoreError(RuntimeError):
    pass


def _canonical_text(value):
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ) + "\n"


def _fsync_dir(path: Path):
    fd = os.open(str(path), os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _atomic_json(path: Path, value):
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(_canonical_text(value))
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)
    _fsync_dir(path.parent)


class DurableRunStore:
    def __init__(self, root):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.state_path = self.root / "state.json"
        self.events_path = self.root / "events.jsonl"
        self.tx_path = self.root / "transaction.json"
        self.lock_path = self.root / ".lock"

    def init(self, state):
        required = {
            "run_id", "state", "revision",
            "harness_manifest_ref", "plan_hash", "source_sha",
        }
        if not isinstance(state, dict) or not required.issubset(state):
            raise StateStoreError("invalid initial state")
        if state["state"] not in ALLOWED_STATES or type(state["revision"]) is not int:
            raise StateStoreError("invalid initial state")
        if self.state_path.exists():
            raise StateStoreError("already initialized")
        _atomic_json(self.state_path, state)
        if not self.events_path.exists():
            self.events_path.write_text("", encoding="utf-8")
        return copy.deepcopy(state)

    def _lock(self):
        handle = open(self.lock_path, "a+", encoding="utf-8")
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        return handle

    def read_state(self):
        if not self.state_path.exists():
            raise StateStoreError("state missing")
        return json.loads(self.state_path.read_text(encoding="utf-8"))

    def read_events(self):
        if not self.events_path.exists():
            return []
        values = []
        for line in self.events_path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                values.append(json.loads(line))
        return values

    def _append_event_idempotent(self, event):
        events = self.read_events()
        for existing in events:
            if existing.get("event_ref") == event["event_ref"]:
                if existing != event:
                    raise StateStoreError("event_ref conflict")
                return False
        validate_append(events, event)
        with open(self.events_path, "a", encoding="utf-8") as fh:
            fh.write(_canonical_text(event))
            fh.flush()
            os.fsync(fh.fileno())
        _fsync_dir(self.root)
        return True

    def _apply_tx(self, tx):
        event = validate_event(tx["event"])
        old_state = tx["old_state"]
        new_state = tx["new_state"]
        current = self.read_state()
        if current == old_state:
            self._append_event_idempotent(event)
            _atomic_json(self.state_path, new_state)
        elif current == new_state:
            self._append_event_idempotent(event)
        else:
            raise StateStoreError("transaction state mismatch")
        if self.tx_path.exists():
            self.tx_path.unlink()
            _fsync_dir(self.root)

    def recover(self):
        lock = self._lock()
        try:
            if not self.tx_path.exists():
                return False
            tx = json.loads(self.tx_path.read_text(encoding="utf-8"))
            self._apply_tx(tx)
            return True
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            lock.close()

    def transition(
        self,
        expected_revision,
        new_state_name,
        draft,
        *,
        pending_action=None,
        policy_verdict=None,
        test_fail_after=None,
    ):
        if new_state_name not in ALLOWED_STATES:
            raise StateStoreError("invalid lifecycle state")
        lock = self._lock()
        try:
            if self.tx_path.exists():
                self._apply_tx(json.loads(self.tx_path.read_text(encoding="utf-8")))
            old_state = self.read_state()
            if old_state["revision"] != expected_revision:
                raise StateConflict(
                    f"expected {expected_revision}, actual {old_state['revision']}"
                )
            events = self.read_events()
            event_seq = len(events) + 1
            context = {
                "run_id": old_state["run_id"],
                "revision": expected_revision,
                "harness_manifest_ref": old_state["harness_manifest_ref"],
                "plan_hash": old_state["plan_hash"],
                "source_sha": old_state["source_sha"],
            }
            event = finalize_event(draft, context, event_seq)
            validate_append(events, event)

            new_state = copy.deepcopy(old_state)
            new_state["state"] = new_state_name
            new_state["revision"] = expected_revision + 1
            if pending_action is not None:
                new_state["pending_action"] = pending_action
            if policy_verdict is not None:
                new_state["policy_verdict"] = policy_verdict

            transaction = {
                "old_state": old_state,
                "new_state": new_state,
                "event": event,
            }
            _atomic_json(self.tx_path, transaction)
            if test_fail_after == "journal":
                raise RuntimeError("test failpoint after journal")
            self._append_event_idempotent(event)
            if test_fail_after == "event":
                raise RuntimeError("test failpoint after event")
            _atomic_json(self.state_path, new_state)
            if test_fail_after == "state":
                raise RuntimeError("test failpoint after state")
            self.tx_path.unlink()
            _fsync_dir(self.root)
            return copy.deepcopy(new_state), copy.deepcopy(event)
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            lock.close()
