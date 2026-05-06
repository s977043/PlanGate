#!/usr/bin/env python3
"""
PlanGate Eval Baseline Snapshot Generator (v8.6.0 PR4 / C-3).

Runs `bin/plangate eval` against representative TASKs and aggregates the
results into a baseline JSON conforming to schemas/eval-baseline.schema.json.

Usage:
    python3 scripts/baseline-snapshot.py \\
        --baseline-id 2026-05-04 \\
        --release v8.5.0 \\
        --tasks TASK-0050 TASK-0054 TASK-0055 TASK-0056 TASK-0057 \\
        [--out docs/ai/eval-baselines/2026-05-04-baseline.json] \\
        [--dry-run]

Privacy: only schema-allowed scalars are written. No file paths, prompts,
command outputs, or other §4 Forbidden fields per metrics-privacy.md.
"""

from __future__ import annotations

import argparse
import datetime
import json
import platform
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKING_DIR = REPO_ROOT / "docs" / "working"
EVAL_RUNNER = REPO_ROOT / "scripts" / "eval-runner.py"
PLANGATE_BIN = REPO_ROOT / "bin" / "plangate"
DEFAULT_OUT_DIR = REPO_ROOT / "docs" / "ai" / "eval-baselines"

TASK_ID_RE = re.compile(r"^TASK-[0-9]{4}$")


def utc_now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_eval_runner_version() -> str:
    if not EVAL_RUNNER.is_file():
        return "unknown"
    text = EVAL_RUNNER.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r'EVAL_RUNNER_VERSION\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else "unknown"


def read_plangate_cli_version() -> str:
    if not PLANGATE_BIN.is_file():
        return "unknown"
    text = PLANGATE_BIN.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r'PLANGATE_VERSION\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else "unknown"


def host_os_id() -> str:
    # Privacy: only platform name + release, no hostname / IP / username
    return f"{platform.system().lower()}-{platform.release()}"


def run_eval(task_id: str) -> dict:
    """Run eval-runner for one task and return its eval-result.json content."""
    if not EVAL_RUNNER.is_file():
        raise FileNotFoundError(f"eval-runner not found: {EVAL_RUNNER}")
    proc = subprocess.run(
        [sys.executable, str(EVAL_RUNNER), task_id],
        capture_output=True,
        text=True,
        check=False,
        cwd=str(REPO_ROOT),
        timeout=60,
    )
    if proc.returncode not in (0,):
        # eval-runner may exit non-zero on release blockers; still read result
        pass
    result_path = WORKING_DIR / task_id / "eval-result.json"
    if not result_path.is_file():
        raise RuntimeError(f"eval-runner did not produce {result_path} (rc={proc.returncode})")
    return json.loads(result_path.read_text(encoding="utf-8"))


def normalize_decision(value) -> str:
    if value is None:
        return "n/a"
    s = str(value)
    if s in ("PASS", "FAIL", "WARN", "n/a"):
        return s
    return "n/a"


def task_summary(eval_result: dict) -> dict:
    """Map eval-runner output → eval-baseline.schema task entry."""
    blockers = eval_result.get("release_blocker_violations", []) or []
    out: dict = {
        "task_id": eval_result["task_id"],
        "ac_coverage_pct": float(eval_result.get("ac_coverage", {}).get("rate_percent", 0)),
        "approval_discipline": normalize_decision(eval_result.get("approval_discipline", {}).get("decision")),
        "format_adherence": normalize_decision(eval_result.get("format_adherence", {}).get("decision")),
        "scope_discipline": normalize_decision(eval_result.get("scope_discipline", {}).get("decision")),
        "verification_honesty": normalize_decision(eval_result.get("verification_honesty", {}).get("decision")),
        "stop_behavior": normalize_decision(eval_result.get("stop_behavior", {}).get("decision")),
        "tool_overuse": normalize_decision(eval_result.get("tool_overuse", {}).get("decision")),
        "latency_cost": normalize_decision(eval_result.get("latency_cost", {}).get("decision")),
        "release_blocker_count": len(blockers),
    }
    if blockers:
        aspects = sorted({b.get("aspect", "?") for b in blockers if "aspect" in b})
        if aspects:
            out["release_blocker_aspects"] = aspects
    return out


def compute_aggregate(tasks: list[dict]) -> dict:
    if not tasks:
        return {"task_count": 0}
    n = len(tasks)
    pass_rate = lambda key: round(  # noqa: E731
        100.0 * sum(1 for t in tasks if t.get(key) == "PASS") / n, 2
    )
    blocker_aspects = Counter()
    blocker_total = 0
    for t in tasks:
        blocker_total += int(t.get("release_blocker_count", 0))
        for asp in t.get("release_blocker_aspects", []):
            blocker_aspects[asp] += 1
    return {
        "task_count": n,
        "ac_coverage_avg_pct": round(sum(t["ac_coverage_pct"] for t in tasks) / n, 2),
        "format_adherence_pass_rate_pct": pass_rate("format_adherence"),
        "scope_discipline_pass_rate_pct": pass_rate("scope_discipline"),
        "verification_honesty_pass_rate_pct": pass_rate("verification_honesty"),
        "stop_behavior_pass_rate_pct": pass_rate("stop_behavior"),
        "approval_discipline_pass_rate_pct": pass_rate("approval_discipline"),
        "release_blocker_total": blocker_total,
        "release_blocker_unique_aspects": sorted(blocker_aspects.keys()),
    }


def build_baseline(
    baseline_id: str,
    release: str,
    task_ids: list[str],
    profile: str | None = None,
    notes: list[str] | None = None,
) -> dict:
    task_summaries: list[dict] = []
    for tid in task_ids:
        if not TASK_ID_RE.match(tid):
            raise ValueError(f"invalid task_id: {tid}")
        if not (WORKING_DIR / tid).is_dir():
            raise FileNotFoundError(f"TASK directory missing: {WORKING_DIR / tid}")
        eval_result = run_eval(tid)
        task_summaries.append(task_summary(eval_result))
    return {
        "baseline_id": baseline_id,
        "evaluated_at": utc_now_iso(),
        "release": release,
        "evaluator_version": read_eval_runner_version(),
        "plangate_cli_version": read_plangate_cli_version(),
        "host_os": host_os_id(),
        "profile": profile,
        "session_log_supplied": False,
        "tasks": task_summaries,
        "aggregate": compute_aggregate(task_summaries),
        "notes": notes or [],
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--baseline-id", required=True, help="Baseline identifier (YYYY-MM-DD)")
    parser.add_argument("--release", required=True, help="PlanGate release (e.g. v8.5.0)")
    parser.add_argument("--tasks", required=True, nargs="+", help="Representative TASK-XXXX list")
    parser.add_argument("--profile", default=None, help="Model profile key (optional)")
    parser.add_argument("--note", action="append", default=None, help="Note line (repeatable)")
    parser.add_argument(
        "--out",
        default=None,
        help="Output JSON path (default: docs/ai/eval-baselines/<baseline-id>-baseline.json)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print to stdout instead of writing")
    args = parser.parse_args(argv)

    baseline = build_baseline(
        args.baseline_id,
        args.release,
        args.tasks,
        profile=args.profile,
        notes=args.note,
    )

    out_str = json.dumps(baseline, ensure_ascii=False, indent=2) + "\n"

    if args.dry_run:
        sys.stdout.write(out_str)
        return 0

    out_path = (
        Path(args.out)
        if args.out
        else DEFAULT_OUT_DIR / f"{args.baseline_id}-baseline.json"
    )
    if not out_path.is_absolute():
        out_path = REPO_ROOT / out_path
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(out_str, encoding="utf-8")
    print(f"Wrote: {out_path.relative_to(REPO_ROOT)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
