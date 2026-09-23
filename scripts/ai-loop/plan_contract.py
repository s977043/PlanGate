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

__doc__ = """Plan Contract execution-reference helper (#981 / #1403).

The Plan Contract is not a new Plan identity system. It references the existing
Plan Package / C-3 approval identity and optionally binds #1389 Intent Context.

Semantic execution identity:
- plan_hash / plan_package_hash: #872 owners
- approval digest: exact approval artifact identity
- context_ref: semantic Intent Context identity, when present

snapshot_ref is audit-only and is intentionally not a stale/preflight key.
"""

import argparse
import contextlib
import io
import json
import pathlib
import re
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
SCRIPTS = HERE.parent
REPO = SCRIPTS.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(SCRIPTS))

import c3_contract  # noqa: E402
import c3prime_verify  # noqa: E402
import plan_package  # noqa: E402
import intent_context_contract  # noqa: E402

PLAN_CONTEXT_ID_RE = re.compile(r"^Intent-Context-ID: (CTX-[0-9A-Za-z._-]+)$", re.MULTILINE)
PLAN_CONTEXT_REF_RE = re.compile(
    r"^Intent-Context-Ref: (sha256:[0-9a-f]{64})$", re.MULTILINE
)

TOP_KEYS = {"schema_version", "task_id", "plan_ref", "approval_ref", "context_binding"}
PLAN_KEYS = {"path", "plan_hash", "plan_package_hash"}
APPROVAL_KEYS = {"path", "approval_kind", "decision", "approval_digest"}
CONTEXT_KEYS = {"path", "context_id", "context_ref", "snapshot_ref"}


class PlanContractError(Exception):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256(path: pathlib.Path) -> str:
    return c3_contract.sha256_of_file(path)


def _rel(path: pathlib.Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO.resolve()))
    except ValueError as exc:
        raise PlanContractError([f"path is outside repository: {path}"]) from exc


def _strict_marker(text: str, regex: re.Pattern[str], label: str) -> tuple[str | None, list[str]]:
    matches = regex.findall(text)
    if len(matches) == 0:
        return None, []
    if len(matches) != 1:
        return None, [f"{label} must appear exactly once when present"]
    return matches[0], []


def plan_context_marker(plan_text: str) -> tuple[dict[str, str] | None, list[str]]:
    """Parse the explicit semantic Context binding embedded in approved plan.md."""
    context_id, errors = _strict_marker(plan_text, PLAN_CONTEXT_ID_RE, "Intent-Context-ID")
    context_ref, more = _strict_marker(plan_text, PLAN_CONTEXT_REF_RE, "Intent-Context-Ref")
    errors += more
    if errors:
        return None, errors
    if context_id is None and context_ref is None:
        return None, []
    if context_id is None or context_ref is None:
        return None, ["Intent Context plan marker requires both ID and Ref"]
    return {"context_id": context_id, "context_ref": context_ref}, []


def _load_intent_context(task_dir: pathlib.Path) -> tuple[dict[str, Any] | None, bytes | None, list[str]]:
    path = task_dir / "intent-context.json"
    if not path.is_file():
        return None, None, []
    try:
        raw = path.read_bytes()
        payload = json.loads(raw)
    except (OSError, ValueError) as exc:
        return None, None, [f"intent-context strict JSON parse failed: {exc}"]
    errors = intent_context_contract.validate_package(payload)
    if payload.get("task_id") != task_dir.name:
        errors = list(errors) + [
            f"intent-context task_id mismatch: {payload.get('task_id')!r} != {task_dir.name!r}"
        ]
    return payload, raw, errors


def _approval_snapshot(task_dir: pathlib.Path) -> tuple[dict[str, str] | None, list[str]]:
    path = task_dir / "approvals" / "c3.json"
    if not path.is_file():
        return None, ["approvals/c3.json not found"]
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return None, [f"approval strict JSON parse failed: {exc}"]
    if not isinstance(data, dict):
        return None, ["approval must be a JSON object"]
    if data.get("task_id") != task_dir.name:
        return None, ["approval task_id does not match task directory"]

    if data.get("approval_kind") == "c3-prime":
        buf = io.StringIO()
        with contextlib.redirect_stderr(buf):
            rc = c3prime_verify.main(["c3prime_verify.py", str(task_dir)])
        if rc != 0:
            return None, [f"c3-prime approval verification failed: {buf.getvalue().strip()}"]
        kind = "c3-prime"
        decision = str(data.get("decision"))
    elif "approval_kind" in data:
        return None, [f"unknown approval_kind: {data.get('approval_kind')!r}"]
    else:
        if data.get("phase") != "C-3" or data.get("c3_status") != "APPROVED":
            return None, ["legacy approval is not C-3 APPROVED"]
        plan = task_dir / "plan.md"
        if not plan.is_file():
            return None, ["plan.md not found"]
        if data.get("plan_hash") != _sha256(plan):
            return None, ["legacy approval plan_hash is stale"]
        kind = "legacy"
        decision = "APPROVED"

    return {
        "path": _rel(path),
        "approval_kind": kind,
        "decision": decision,
        "approval_digest": _sha256(path),
    }, []


def build_record(task_dir: pathlib.Path) -> dict[str, Any]:
    task_dir = pathlib.Path(task_dir)
    task_id = task_dir.name
    if not re.fullmatch(r"TASK-[0-9]{4}", task_id):
        raise PlanContractError([f"task directory is not TASK-XXXX: {task_id!r}"])

    hashes = plan_package.compute_hashes(task_dir)
    approval, errors = _approval_snapshot(task_dir)
    if errors or approval is None:
        raise PlanContractError(errors or ["approval unavailable"])

    plan = task_dir / "plan.md"
    plan_text = plan.read_text(encoding="utf-8", errors="replace")
    marker, marker_errors = plan_context_marker(plan_text)
    payload, raw, context_errors = _load_intent_context(task_dir)
    errors = marker_errors + context_errors

    context_binding = None
    if payload is None and raw is None:
        if marker is not None:
            errors.append("plan has Intent Context marker but intent-context.json is absent")
    elif not context_errors and payload is not None and raw is not None:
        expected = {
            "context_id": payload["context_id"],
            "context_ref": intent_context_contract.compute_context_ref(payload),
        }
        if marker is None:
            errors.append("intent-context.json exists but plan.md lacks Intent Context marker")
        elif marker != expected:
            errors.append("plan Intent Context marker does not match current semantic context")
        else:
            context_binding = {
                "path": _rel(task_dir / "intent-context.json"),
                "context_id": expected["context_id"],
                "context_ref": expected["context_ref"],
                "snapshot_ref": intent_context_contract.compute_snapshot_ref(raw),
            }

    if errors:
        raise PlanContractError(errors)

    record: dict[str, Any] = {
        "schema_version": 1,
        "task_id": task_id,
        "plan_ref": {
            "path": _rel(plan),
            "plan_hash": hashes["plan_hash"],
            "plan_package_hash": hashes["plan_package_hash"],
        },
        "approval_ref": approval,
    }
    if context_binding is not None:
        record["context_binding"] = context_binding
    return record


def _shape_errors(record: Any) -> list[str]:
    if not isinstance(record, dict):
        return ["plan-contract record must be an object"]
    errors: list[str] = []
    keys = set(record)
    if keys - TOP_KEYS:
        errors.append(f"unknown top-level keys: {sorted(keys - TOP_KEYS)}")
    for key in ("schema_version", "task_id", "plan_ref", "approval_ref"):
        if key not in record:
            errors.append(f"missing required key: {key}")
    if record.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    for key, allowed in (("plan_ref", PLAN_KEYS), ("approval_ref", APPROVAL_KEYS)):
        value = record.get(key)
        if isinstance(value, dict):
            if set(value) != allowed:
                errors.append(f"{key} keys must be exactly {sorted(allowed)}")
        elif key in record:
            errors.append(f"{key} must be an object")
    if "context_binding" in record:
        value = record["context_binding"]
        if not isinstance(value, dict) or set(value) != CONTEXT_KEYS:
            errors.append(f"context_binding keys must be exactly {sorted(CONTEXT_KEYS)}")
    return errors


def validate_record(task_dir: pathlib.Path, record: dict[str, Any]) -> list[str]:
    """Validate sidecar against current Plan/approval/semantic Context state."""
    task_dir = pathlib.Path(task_dir)
    errors = _shape_errors(record)
    if errors:
        return errors
    if record["task_id"] != task_dir.name:
        errors.append("record task_id does not match task directory")
        return errors

    try:
        current = build_record(task_dir)
    except PlanContractError as exc:
        return exc.errors

    if record["plan_ref"] != current["plan_ref"]:
        errors.append("plan_ref is stale or mismatched")
    if record["approval_ref"] != current["approval_ref"]:
        errors.append("approval_ref is stale or mismatched")

    old_context = record.get("context_binding")
    new_context = current.get("context_binding")
    if old_context is None and new_context is not None:
        errors.append("context_binding missing for current Intent Context")
    elif old_context is not None and new_context is None:
        errors.append("record binds Intent Context but current task does not")
    elif old_context is not None and new_context is not None:
        # snapshot_ref is audit-only. Semantic identity is the stale boundary.
        for key in ("path", "context_id", "context_ref"):
            if old_context.get(key) != new_context.get(key):
                errors.append(f"context_binding.{key} is stale or mismatched")
    return errors


def serialize(record: dict[str, Any]) -> str:
    return json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build/validate Plan Contract sidecar")
    sub = parser.add_subparsers(dest="command", required=True)

    b = sub.add_parser("build")
    b.add_argument("--task-dir", required=True)
    b.add_argument("--out")

    v = sub.add_parser("validate")
    v.add_argument("--task-dir", required=True)
    v.add_argument("--record")

    args = parser.parse_args(argv)
    task_dir = pathlib.Path(args.task_dir)

    if args.command == "build":
        try:
            record = build_record(task_dir)
        except PlanContractError as exc:
            for error in exc.errors:
                print(f"[plan-contract] FAIL: {error}", file=sys.stderr)
            return 1
        output = serialize(record)
        if args.out:
            path = pathlib.Path(args.out)
            if path.name != "plan-contract.json":
                print("[plan-contract] FAIL: --out basename must be plan-contract.json", file=sys.stderr)
                return 2
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(output, encoding="utf-8")
        else:
            print(output, end="")
        return 0

    record_path = pathlib.Path(args.record) if args.record else task_dir / "execution" / "plan-contract.json"
    try:
        record = json.loads(record_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"[plan-contract] FAIL: {exc}", file=sys.stderr)
        return 1
    errors = validate_record(task_dir, record)
    if errors:
        for error in errors:
            print(f"[plan-contract] FAIL: {error}", file=sys.stderr)
        return 1
    print("[plan-contract] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
