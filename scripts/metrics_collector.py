#!/usr/bin/env python3
"""
PlanGate Metrics Collector v1 (Issue #195 / PBI-HI-001).

Reads workflow artifacts from docs/working/<TASK-XXXX>/ and appends
metrics events to docs/working/_metrics/events.ndjson.

Privacy: only emits fields allowed by docs/ai/metrics-privacy.md §3.
File paths, stack traces, command output, and raw prompts MUST NOT
appear in emitted events (§4 Forbidden).

Usage:
    python3 scripts/metrics_collector.py TASK-XXXX [--dry-run]
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKING_DIR = REPO_ROOT / "docs" / "working"
METRICS_DIR = WORKING_DIR / "_metrics"
EVENTS_LOG = METRICS_DIR / "events.ndjson"
HOOK_AUDIT_LOG = WORKING_DIR / "_audit" / "hook-events.log"
SCHEMA_VERSION = "1.0"

TASK_ID_RE = re.compile(r"^TASK-[0-9]{4}$")
HOOK_ID_RE = re.compile(r"\b(EH|EHS)-[0-9]+\b")

# v8.6.0 PR3 (A-1): hook script name → schema-conformant hook_id
HOOK_NAME_TO_ID = {
    "check-plan-exists": "EH-1",
    "check-c3-approval": "EH-2",
    "check-plan-hash": "EH-3",
    "check-test-cases": "EH-4",
    "check-verification-evidence": "EH-5",
    "check-forbidden-files": "EH-6",
    "check-merge-approvals": "EH-7",
    "check-metrics-privacy": "EH-8",
    "check-v3-review": "EHS-1",
    "check-handoff-elements": "EHS-2",
    "check-fix-loop": "EHS-3",
}

# audit log level → schema-conformant hook_result
HOOK_LEVEL_TO_RESULT = {
    "VIOLATION": "block",
    "BLOCK": "block",
    "WARNING": "warn",
    "WARN": "warn",
}

# v8.6.0 PR3 (A-2): match (#NN) at end of git commit subject
GIT_COMMIT_PR_RE = re.compile(r"\(#(\d+)\)\s*$")


def utc_now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def file_mtime_iso(path: Path) -> str:
    ts = datetime.datetime.fromtimestamp(path.stat().st_mtime, tz=datetime.timezone.utc)
    return ts.strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def base_event(task_id: str, event: str, ts: str | None = None) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "ts": ts or utc_now_iso(),
        "task_id": task_id,
        "event": event,
    }


def derive_events(task_dir: Path, task_id: str) -> list[dict]:
    """Derive metrics events from TASK artifacts.

    Each event satisfies plangate-event.schema.json. Privacy-sensitive
    fields (file paths, stdout, prompts, etc.) are NEVER emitted —
    only the allowed scalar fields from §3 of metrics-privacy.md.
    """
    events: list[dict] = []

    # 1. task_initialized — derived from pbi-input.md mtime
    pbi = task_dir / "pbi-input.md"
    if pbi.is_file():
        events.append(
            base_event(task_id, "task_initialized", file_mtime_iso(pbi)) | {"phase": "A"}
        )

    # 2. plan_generated — when plan.md & todo.md & test-cases.md all exist
    plan = task_dir / "plan.md"
    todo = task_dir / "todo.md"
    test_cases = task_dir / "test-cases.md"
    if plan.is_file():
        ev = base_event(task_id, "plan_generated", file_mtime_iso(plan)) | {"phase": "B"}
        ev["plan_hash"] = "sha256:" + sha256_hex(plan.read_bytes())
        # mode detection from plan.md (light/standard/high-risk/critical)
        mode_match = re.search(
            r"\*\*モード\*\*[^\n]*?(ultra-light|light|standard|high-risk|critical)",
            plan.read_text(errors="ignore"),
        )
        if mode_match:
            ev["mode"] = mode_match.group(1)
        events.append(ev)

    # 3. c3_decided — from approvals/c3.json if present
    c3 = task_dir / "approvals" / "c3.json"
    if c3.is_file():
        try:
            data = json.loads(c3.read_text())
            verdict = str(data.get("decision", "")).upper()
            if verdict in {"APPROVED", "CONDITIONAL", "REJECTED"}:
                events.append(
                    base_event(task_id, "c3_decided", file_mtime_iso(c3))
                    | {"phase": "C-3", "verdict": verdict}
                )
        except (json.JSONDecodeError, ValueError):
            pass

    # 4. exec_started — derived from any file under TASK-XXXX/evidence/ or todo.md modification
    evidence_dir = task_dir / "evidence"
    if evidence_dir.is_dir() and any(evidence_dir.iterdir()):
        first_evidence = min(evidence_dir.rglob("*"), key=lambda p: p.stat().st_mtime, default=None)
        if first_evidence and first_evidence.is_file():
            events.append(
                base_event(task_id, "exec_started", file_mtime_iso(first_evidence))
                | {"phase": "D"}
            )

    # 5. v1_completed — from handoff.md (assumes V-1 PASS recorded inside handoff)
    handoff = task_dir / "handoff.md"
    if handoff.is_file():
        text = handoff.read_text(errors="ignore")
        # Count AC PASS / FAIL from "✅ PASS" / "❌ FAIL" markers (privacy-safe: counts only)
        ac_pass = len(re.findall(r"✅\s*PASS", text))
        ac_fail = len(re.findall(r"❌\s*FAIL", text))
        ac_warn = len(re.findall(r"⚠️\s*WARN", text))
        ac_total = ac_pass + ac_fail + ac_warn
        verdict = "PASS" if ac_fail == 0 and ac_total > 0 else "FAIL" if ac_fail > 0 else "WARN"
        ev = base_event(task_id, "v1_completed", file_mtime_iso(handoff)) | {
            "phase": "V-1",
            "verdict": verdict,
        }
        if ac_total > 0:
            ev.update({"ac_total": ac_total, "ac_pass": ac_pass, "ac_fail": ac_fail})
            if ac_warn > 0:
                ev["ac_warn"] = ac_warn
        events.append(ev)

        # 6. handoff_completed
        events.append(
            base_event(task_id, "handoff_completed", file_mtime_iso(handoff))
            | {"phase": "V-1"}
        )

    # 7. external_review_completed — from review-external.md presence
    review_ext = task_dir / "review-external.md"
    if review_ext.is_file():
        events.append(
            base_event(task_id, "external_review_completed", file_mtime_iso(review_ext))
            | {"phase": "V-3"}
        )

    # 8. hook_violation — derived from docs/working/_audit/hook-events.log (v8.6.0 PR3 / A-1)
    events.extend(derive_hook_events(task_id))

    # 9. pr_created — derived from git log on handoff.md (v8.6.0 PR3 / A-2)
    if (task_dir / "handoff.md").is_file():
        events.extend(derive_pr_event(task_id, task_dir / "handoff.md"))

    return events


def derive_hook_events(task_id: str, audit_log: Path = HOOK_AUDIT_LOG) -> list[dict]:
    """Read hook audit log and emit hook_violation events for the given TASK.

    Audit log format (TSV): ts \t level \t hook_name \t task_id \t message

    Only VIOLATION / WARNING / BLOCK / WARN levels are emitted (PASS / BYPASS skip).
    Privacy: the message column is NOT emitted; only schema-allowed scalars
    (hook_id, hook_result) are kept per metrics-privacy.md §3.
    """
    out: list[dict] = []
    if not audit_log.is_file():
        return out
    try:
        lines = audit_log.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError:
        return out
    for line in lines:
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        ts, level, hook_name, log_task = parts[0], parts[1], parts[2], parts[3]
        if log_task != task_id:
            continue
        result = HOOK_LEVEL_TO_RESULT.get(level)
        if result is None:
            continue  # PASS / BYPASS は emit しない
        hook_id = HOOK_NAME_TO_ID.get(hook_name)
        if hook_id is None:
            continue
        out.append(
            base_event(task_id, "hook_violation", ts)
            | {"hook_id": hook_id, "hook_result": result}
        )
    return out


def derive_pr_event(task_id: str, handoff_path: Path) -> list[dict]:
    """Emit pr_created event by inspecting git log for the handoff commit.

    Looks for the most recent commit that touched handoff.md and extracts
    the PR number from a "(#NN)" suffix in the subject (squash-merge convention).
    Returns empty list if no PR number can be derived (silent — privacy-safe).
    """
    import subprocess  # local import to keep top-level minimal

    try:
        rel = handoff_path.relative_to(REPO_ROOT)
    except ValueError:
        return []
    try:
        proc = subprocess.run(
            [
                "git",
                "-C",
                str(REPO_ROOT),
                "log",
                "-1",
                "--pretty=format:%H%x09%cI%x09%s",
                "--",
                str(rel),
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    if proc.returncode != 0 or not proc.stdout.strip():
        return []
    parts = proc.stdout.strip().split("\t", 2)
    if len(parts) < 3:
        return []
    _commit, commit_iso, subject = parts
    m = GIT_COMMIT_PR_RE.search(subject)
    if not m:
        return []
    pr_number = int(m.group(1))
    # normalize timestamp to UTC Z form
    try:
        dt = datetime.datetime.fromisoformat(commit_iso.replace("Z", "+00:00"))
        ts = dt.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        ts = utc_now_iso()
    return [
        base_event(task_id, "pr_created", ts) | {"phase": "PR", "pr_number": pr_number}
    ]


def append_events(events: list[dict], events_log: Path = EVENTS_LOG) -> None:
    events_log.parent.mkdir(parents=True, exist_ok=True)
    with events_log.open("a", encoding="utf-8") as fp:
        for ev in events:
            fp.write(json.dumps(ev, ensure_ascii=False, sort_keys=True) + "\n")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("task_id", help="Target TASK-XXXX")
    parser.add_argument("--dry-run", action="store_true", help="Print events without appending")
    parser.add_argument(
        "--events-log",
        default=str(EVENTS_LOG),
        help="Override events log path (default: docs/working/_metrics/events.ndjson)",
    )
    args = parser.parse_args(argv)

    if not TASK_ID_RE.match(args.task_id):
        print(f"Invalid task_id format: {args.task_id} (expected TASK-XXXX)", file=sys.stderr)
        return 2

    task_dir = WORKING_DIR / args.task_id
    if not task_dir.is_dir():
        print(f"TASK directory not found: {task_dir}", file=sys.stderr)
        return 2

    events = derive_events(task_dir, args.task_id)

    if args.dry_run:
        for ev in events:
            print(json.dumps(ev, ensure_ascii=False, sort_keys=True))
        return 0

    target_log = Path(args.events_log)
    if not target_log.is_absolute():
        target_log = REPO_ROOT / target_log
    append_events(events, target_log)
    try:
        display = target_log.relative_to(REPO_ROOT)
    except ValueError:
        display = target_log
    print(f"Appended {len(events)} events to {display}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
