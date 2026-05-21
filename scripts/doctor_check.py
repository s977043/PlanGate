#!/usr/bin/env python3
"""
PlanGate Doctor (machine-readable) — v8.6.0 PR7 / K-3.

Emits JSON status for the v8.6.0 Metrics & Privacy section so that CI / external
tooling can grep for `failures == 0` without parsing the human-readable doctor
output. Privacy: only file presence / executable bits / gitignore status are
reported. No file contents, no paths beyond what is already public, no env vars.

Usage:
    python3 scripts/doctor_check.py [--scope v8.6.0|hooks]

Exit codes:
    0 — all "fail"-level checks passed
    1 — at least one "fail"-level check failed
    2 — unknown scope
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

import sys as _phsys; from pathlib import Path as _phP; _phsys.path.insert(0, str(_phP(__file__).resolve().parent))
from _paths import REPO_ROOT as REPO  # noqa: E402

V860_FILE_CHECKS: list[tuple[str, str]] = [
    ("schemas/plangate-event.schema.json", "fail"),
    ("schemas/eval-baseline.schema.json", "fail"),
    ("scripts/metrics_collector.py", "fail"),
    ("scripts/metrics_reporter.py", "fail"),
    ("scripts/baseline-snapshot.py", "fail"),
    ("scripts/hooks/check-metrics-privacy.sh", "fail"),
    ("docs/ai/metrics.md", "fail"),
    ("docs/ai/metrics-privacy.md", "fail"),
    ("docs/ai/issue-governance.md", "fail"),
    ("docs/ai/eval-baselines/2026-05-04-baseline.md", "fail"),
    ("docs/ai/eval-baselines/2026-05-04-baseline.json", "fail"),
    (".github/workflows/metrics-privacy.yml", "fail"),
]


def check_file(path_rel: str, level: str) -> dict:
    p = REPO / path_rel
    return {
        "name": path_rel,
        "ok": p.is_file(),
        "level": level,
        "detail": None if p.is_file() else f"missing: {path_rel}",
    }


def check_eh8_executable() -> dict:
    p = REPO / "scripts/hooks/check-metrics-privacy.sh"
    ok = p.is_file() and os.access(p, os.X_OK)
    return {
        "name": "EH-8 hook is executable",
        "ok": ok,
        "level": "warn",
        "detail": None if ok else "chmod +x scripts/hooks/check-metrics-privacy.sh",
    }


def check_events_gitignored() -> dict:
    gi = REPO / ".gitignore"
    text = gi.read_text(encoding="utf-8", errors="ignore") if gi.is_file() else ""
    ok = "docs/working/_metrics/events.ndjson" in text
    return {
        "name": "events.ndjson is .gitignore-d",
        "ok": ok,
        "level": "fail",
        "detail": None if ok else "add 'docs/working/_metrics/events.ndjson' to .gitignore (privacy §8)",
    }


def check_events_actually_ignored() -> dict:
    log = REPO / "docs/working/_metrics/events.ndjson"
    if not log.is_file():
        return {
            "name": "events.ndjson git-ignored (verified)",
            "ok": True,
            "level": "info",
            "detail": "events.ndjson absent (opt-in not yet exercised)",
        }
    proc = subprocess.run(
        ["git", "-C", str(REPO), "check-ignore", "docs/working/_metrics/events.ndjson"],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
    )
    ok = proc.returncode == 0
    return {
        "name": "events.ndjson git-ignored (verified)",
        "ok": ok,
        "level": "fail",
        "detail": None if ok else "events.ndjson is NOT git-ignored despite .gitignore entry",
    }


def check_events_not_tracked() -> dict:
    proc = subprocess.run(
        ["git", "-C", str(REPO), "ls-files", "--error-unmatch", "docs/working/_metrics/events.ndjson"],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
    )
    ok = proc.returncode != 0  # tracked → 0、untracked → 非 0
    return {
        "name": "events.ndjson not tracked by git",
        "ok": ok,
        "level": "fail",
        "detail": None if ok else "events.ndjson IS tracked — privacy §8 violation",
    }


def _extract_hook_blocks(doc: dict) -> set:
    """Extract (event, matcher, type, command) tuples from a settings doc.

    Privacy: this returns an in-memory set used only for membership testing.
    No element is ever emitted into the JSON result; only counts / booleans are.
    Keys prefixed with '_' (comments) are ignored.
    """
    blocks: set = set()
    hooks = doc.get("hooks")
    if not isinstance(hooks, dict):
        return blocks
    for event, entries in hooks.items():
        if event.startswith("_") or not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            matcher = entry.get("matcher")
            for h in entry.get("hooks", []) or []:
                if not isinstance(h, dict):
                    continue
                blocks.add((event, matcher, h.get("type"), h.get("command")))
    return blocks


def _load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def check_hooks_wired() -> dict:
    example = REPO / ".claude/settings.example.json"
    settings = REPO / ".claude/settings.json"

    if not example.is_file():
        return {
            "name": "PlanGate hooks wired",
            "ok": False,
            "level": "fail",
            "detail": "missing: .claude/settings.example.json (cannot determine expected wiring)",
        }
    if not settings.is_file():
        return {
            "name": "PlanGate hooks wired",
            "ok": False,
            "level": "fail",
            "detail": "missing: .claude/settings.json (run: plangate doctor --fix)",
        }

    example_doc = _load_json(example)
    settings_doc = _load_json(settings)
    if example_doc is None:
        return {
            "name": "PlanGate hooks wired",
            "ok": False,
            "level": "fail",
            "detail": ".claude/settings.example.json is not valid JSON",
        }
    if settings_doc is None:
        return {
            "name": "PlanGate hooks wired",
            "ok": False,
            "level": "fail",
            "detail": ".claude/settings.json is not valid JSON",
        }

    expected = _extract_hook_blocks(example_doc)
    actual = _extract_hook_blocks(settings_doc)
    missing = expected - actual
    ok = not missing
    return {
        "name": "PlanGate hooks wired",
        "ok": ok,
        "level": "fail",
        "detail": None
        if ok
        else f"{len(missing)} of {len(expected)} expected hook block(s) not wired (run: plangate doctor --fix)",
    }


def run_hooks_checks() -> dict:
    checks: list[dict] = [check_hooks_wired()]

    failures = sum(1 for c in checks if not c["ok"] and c["level"] == "fail")
    warnings = sum(1 for c in checks if not c["ok"] and c["level"] == "warn")

    return {
        "scope": "hooks",
        "checks": checks,
        "failures": failures,
        "warnings": warnings,
        "passed": failures == 0,
    }


def run_v860_checks() -> dict:
    checks: list[dict] = []
    for path_rel, level in V860_FILE_CHECKS:
        checks.append(check_file(path_rel, level))
    checks.append(check_eh8_executable())
    checks.append(check_events_gitignored())
    checks.append(check_events_actually_ignored())
    checks.append(check_events_not_tracked())

    failures = sum(1 for c in checks if not c["ok"] and c["level"] == "fail")
    warnings = sum(1 for c in checks if not c["ok"] and c["level"] == "warn")

    return {
        "scope": "v8.6.0 Metrics & Privacy",
        "checks": checks,
        "failures": failures,
        "warnings": warnings,
        "passed": failures == 0,
    }


def run_maintenance_checks() -> dict:
    """maintenance scope: report active maintenance window metadata (TASK-0106 / AC-13)."""
    import time
    maint = REPO / "docs/working/_maintenance/maintenance.json"
    out: dict = {
        "scope": "maintenance",
        "checks": [],
        "failures": 0,
        "warnings": 0,
        "passed": True,
        "maintenance": {"present": False},
    }
    if not maint.is_file():
        out["checks"].append({
            "id": "maintenance.json", "level": "info",
            "status": "ok", "msg": "no active maintenance window",
        })
        return out
    try:
        d = json.loads(maint.read_text())
    except Exception as e:
        out["checks"].append({
            "id": "maintenance.json", "level": "warn",
            "status": "fail", "msg": f"unparsable: {e}",
        })
        out["warnings"] += 1
        return out
    now = int(time.time())
    until = int(d.get("until", 0))
    gat = int(d.get("granted_at", 0))
    remaining = max(0, until - now)
    consumed_at = d.get("consumed_at")
    info = {
        "present": True,
        "scope": d.get("scope", ""),
        "approved_by": d.get("approved_by", ""),
        "reason": d.get("reason", ""),
        "granted_at": gat,
        "until_epoch": until,
        "remaining_seconds": remaining,
        "remaining_mmss": f"{remaining // 60:02d}:{remaining % 60:02d}",
        "allowed_paths": d.get("allowed_paths"),
        "one_shot": bool(d.get("one_shot", False)),
        "consumed_at": consumed_at,
        "active": gat <= now < until and consumed_at is None,
    }
    out["maintenance"] = info
    if info["active"]:
        out["checks"].append({
            "id": "maintenance.json", "level": "info",
            "status": "ok",
            "msg": f"active: remaining={info['remaining_mmss']} scope={info['scope']} paths={info['allowed_paths']}",
        })
    else:
        reason = "expired" if until <= now else (
            "consumed (one_shot)" if consumed_at is not None else "not yet started")
        out["checks"].append({
            "id": "maintenance.json", "level": "info",
            "status": "ok", "msg": f"inactive: {reason}",
        })
    return out


SCOPES = {
    "v8.6.0": run_v860_checks,
    "hooks": run_hooks_checks,
    "maintenance": run_maintenance_checks,
}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--scope", default="v8.6.0", help="Check scope (v8.6.0 | hooks | maintenance)")
    args = parser.parse_args(argv)

    runner = SCOPES.get(args.scope)
    if runner is None:
        print(f"[error] unknown scope: {args.scope}", file=sys.stderr)
        return 2

    result = runner()
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
