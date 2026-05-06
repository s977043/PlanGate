#!/usr/bin/env python3
"""
PlanGate Doctor (machine-readable) — v8.6.0 PR7 / K-3.

Emits JSON status for the v8.6.0 Metrics & Privacy section so that CI / external
tooling can grep for `failures == 0` without parsing the human-readable doctor
output. Privacy: only file presence / executable bits / gitignore status are
reported. No file contents, no paths beyond what is already public, no env vars.

Usage:
    python3 scripts/doctor_check.py [--scope v8.6.0]

Exit codes:
    0 — all "fail"-level checks passed
    1 — at least one "fail"-level check failed
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

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


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--scope", default="v8.6.0", help="Check scope (currently: v8.6.0)")
    args = parser.parse_args(argv)

    if args.scope != "v8.6.0":
        print(f"[error] unknown scope: {args.scope}", file=sys.stderr)
        return 2

    result = run_v860_checks()
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
