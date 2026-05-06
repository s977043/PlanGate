#!/usr/bin/env python3
"""
PlanGate Metrics Reporter v1 (Issue #195 / PBI-HI-001).

Reads docs/working/_metrics/events.ndjson and prints a TASK-level
or aggregate summary covering hook violations / C-3 / V-1 / C-4.

Privacy: only reads the allowed §3 fields. No file paths, stack
traces, command outputs are dereferenced (per metrics-privacy.md).

Usage:
    python3 scripts/metrics_reporter.py TASK-XXXX
    python3 scripts/metrics_reporter.py --aggregate
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_EVENTS_LOG = REPO_ROOT / "docs" / "working" / "_metrics" / "events.ndjson"


def load_events(events_log: Path) -> list[dict]:
    if not events_log.is_file():
        return []
    out = []
    for line in events_log.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def filter_task(events: list[dict], task_id: str) -> list[dict]:
    return [ev for ev in events if ev.get("task_id") == task_id]


def summarize(events: list[dict]) -> dict:
    """Compute summary counters for the given event slice.

    H-3 (v8.6.0 PR6): includes per-mode V-1 / C-3 PASS rates and per-mode
    hook violation counts to make harness changes evaluable by mode.
    """
    summary: dict = {
        "event_count": len(events),
        "events_by_type": dict(Counter(ev.get("event", "?") for ev in events)),
        "hook_violations": {
            "total": 0,
            "by_hook_id": {},
            "by_result": {},
            "by_mode": {},
        },
        "c3": {"APPROVED": 0, "CONDITIONAL": 0, "REJECTED": 0},
        "c4": {"APPROVED": 0, "REQUEST_CHANGES": 0, "REJECTED": 0},
        "v1": {"PASS": 0, "FAIL": 0, "WARN": 0},
        "fix_loop_max": 0,
        "modes": {},
        # H-3: TASK ごとの mode を解決した上で gate verdict を mode 別に集計
        "by_mode": {},
    }

    # First pass: TASK ID → mode を index 化（plan_generated に mode が記録される）
    task_to_mode: dict[str, str] = {}
    for ev in events:
        if ev.get("event") == "plan_generated" and ev.get("mode"):
            task_to_mode[ev.get("task_id", "")] = ev["mode"]

    def bump_mode_bucket(mode: str, key: str, sub: str) -> None:
        if not mode:
            return
        bucket = summary["by_mode"].setdefault(
            mode,
            {
                "c3": {"APPROVED": 0, "CONDITIONAL": 0, "REJECTED": 0},
                "v1": {"PASS": 0, "FAIL": 0, "WARN": 0},
                "c4": {"APPROVED": 0, "REQUEST_CHANGES": 0, "REJECTED": 0},
                "hook_violations": 0,
            },
        )
        if key == "hook_violations":
            bucket["hook_violations"] += 1
        elif sub in bucket.get(key, {}):
            bucket[key][sub] += 1

    for ev in events:
        event_type = ev.get("event")
        ev_mode = task_to_mode.get(ev.get("task_id", ""))

        if event_type == "hook_violation":
            summary["hook_violations"]["total"] += 1
            hid = ev.get("hook_id", "?")
            hresult = ev.get("hook_result", "?")
            summary["hook_violations"]["by_hook_id"][hid] = (
                summary["hook_violations"]["by_hook_id"].get(hid, 0) + 1
            )
            summary["hook_violations"]["by_result"][hresult] = (
                summary["hook_violations"]["by_result"].get(hresult, 0) + 1
            )
            if ev_mode:
                summary["hook_violations"]["by_mode"][ev_mode] = (
                    summary["hook_violations"]["by_mode"].get(ev_mode, 0) + 1
                )
                bump_mode_bucket(ev_mode, "hook_violations", "")
        elif event_type == "c3_decided":
            v = ev.get("verdict", "?")
            if v in summary["c3"]:
                summary["c3"][v] += 1
            bump_mode_bucket(ev_mode, "c3", v)
        elif event_type == "c4_decided":
            v = ev.get("verdict", "?")
            if v in summary["c4"]:
                summary["c4"][v] += 1
            bump_mode_bucket(ev_mode, "c4", v)
        elif event_type == "v1_completed":
            v = ev.get("verdict", "?")
            if v in summary["v1"]:
                summary["v1"][v] += 1
            bump_mode_bucket(ev_mode, "v1", v)
        elif event_type == "fix_loop_incremented":
            count = ev.get("fix_loop_count", 0)
            if isinstance(count, int) and count > summary["fix_loop_max"]:
                summary["fix_loop_max"] = count
        elif event_type == "plan_generated":
            mode = ev.get("mode")
            if mode:
                summary["modes"][mode] = summary["modes"].get(mode, 0) + 1

    # H-3: per-mode pass rates (helps interpret the by_mode buckets)
    for mode, bucket in summary["by_mode"].items():
        v1 = bucket["v1"]
        v1_total = sum(v1.values())
        if v1_total > 0:
            bucket["v1_pass_rate_pct"] = round(100.0 * v1["PASS"] / v1_total, 2)

    return summary


def render_text(task_id: str | None, summary: dict) -> str:
    title = f"# Metrics summary: {task_id}" if task_id else "# Metrics summary: aggregate"
    lines = [title, ""]
    lines.append(f"- events: {summary['event_count']}")
    lines.append("- events by type:")
    for k, v in sorted(summary["events_by_type"].items()):
        lines.append(f"    - {k}: {v}")
    if summary["modes"]:
        lines.append(f"- modes: {summary['modes']}")
    lines.append("")

    lines.append("## Hook violations")
    lines.append(f"- total: {summary['hook_violations']['total']}")
    if summary["hook_violations"]["by_hook_id"]:
        lines.append("- by hook_id:")
        for k, v in sorted(summary["hook_violations"]["by_hook_id"].items()):
            lines.append(f"    - {k}: {v}")
    if summary["hook_violations"]["by_result"]:
        lines.append("- by result:")
        for k, v in sorted(summary["hook_violations"]["by_result"].items()):
            lines.append(f"    - {k}: {v}")
    lines.append("")

    lines.append("## Gate decisions")
    lines.append(f"- C-3: {summary['c3']}")
    lines.append(f"- V-1: {summary['v1']}")
    lines.append(f"- C-4: {summary['c4']}")
    if summary["fix_loop_max"] > 0:
        lines.append(f"- fix_loop_max: {summary['fix_loop_max']}")

    # H-3 (v8.6.0 PR6): per-mode breakdown
    if summary.get("by_mode"):
        lines.append("")
        lines.append("## By mode (H-3)")
        for mode, bucket in sorted(summary["by_mode"].items()):
            v1 = bucket.get("v1", {})
            c3 = bucket.get("c3", {})
            v1_total = sum(v1.values())
            v1_pass_rate = bucket.get("v1_pass_rate_pct")
            line = f"- **{mode}**: V-1 {v1.get('PASS', 0)}/{v1_total} PASS"
            if v1_pass_rate is not None:
                line += f" ({v1_pass_rate}%)"
            line += f" / C-3 APPROVED={c3.get('APPROVED', 0)}"
            line += f" / hook_violations={bucket.get('hook_violations', 0)}"
            lines.append(line)

    return "\n".join(lines)


def render_markdown_section(task_id: str | None, summary: dict) -> str:
    """K-1 (v8.6.0 PR7): handoff §7 に貼れる最小 markdown 表を生成。

    privacy: docs/ai/metrics-privacy.md §3 Allowed のみ含む。
    """
    title = task_id or "aggregate"
    hv = summary["hook_violations"]
    by_hook = ", ".join(f"{k}={v}" for k, v in sorted(hv.get("by_hook_id", {}).items()))
    hv_cell = f"{hv['total']}" + (f"（{by_hook}）" if by_hook else "")
    modes = ", ".join(f"{m}×{n}" for m, n in sorted(summary.get("modes", {}).items()))
    mode_lines = []
    for mode, bucket in sorted(summary.get("by_mode", {}).items()):
        v1 = bucket.get("v1", {})
        v1_total = sum(v1.values())
        rate = bucket.get("v1_pass_rate_pct")
        rate_str = f" ({rate}%)" if rate is not None else ""
        mode_lines.append(
            f"| {mode} | V-1 {v1.get('PASS', 0)}/{v1_total} PASS{rate_str} | "
            f"C-3 APPROVED={bucket.get('c3', {}).get('APPROVED', 0)} | "
            f"hook_violations={bucket.get('hook_violations', 0)} |"
        )

    lines = [
        f"## 7. Metrics summary ({title}, v8.6.0+)",
        "",
        "| 観点 | 値 |",
        "| --- | --- |",
        f"| events | {summary['event_count']} |",
        f"| modes | {modes or '(none)'} |",
        f"| C-3 | APPROVED={summary['c3']['APPROVED']} / "
        f"CONDITIONAL={summary['c3']['CONDITIONAL']} / "
        f"REJECTED={summary['c3']['REJECTED']} |",
        f"| V-1 | PASS={summary['v1']['PASS']} / "
        f"FAIL={summary['v1']['FAIL']} / "
        f"WARN={summary['v1']['WARN']} |",
        f"| C-4 | APPROVED={summary['c4']['APPROVED']} / "
        f"REQUEST_CHANGES={summary['c4']['REQUEST_CHANGES']} / "
        f"REJECTED={summary['c4']['REJECTED']} |",
        f"| hook violations | {hv_cell} |",
        f"| fix_loop_max | {summary['fix_loop_max']} |",
    ]
    if mode_lines:
        lines += [
            "",
            "### By mode",
            "",
            "| mode | V-1 | C-3 | hooks |",
            "| --- | --- | --- | --- |",
            *mode_lines,
        ]
    lines += [
        "",
        "> Privacy: §3 Allowed only. See `docs/ai/metrics-privacy.md`.",
    ]
    return "\n".join(lines)


def filter_since(events: list[dict], since_iso: str) -> list[dict]:
    """K-2 (v8.6.0 PR7): keep events with ts >= since_iso (ISO 8601)."""
    if not since_iso:
        return events
    # Allow YYYY-MM-DD shorthand → 00:00:00 UTC
    if len(since_iso) == 10 and since_iso[4] == "-" and since_iso[7] == "-":
        since_iso = since_iso + "T00:00:00Z"
    return [ev for ev in events if str(ev.get("ts", "")) >= since_iso]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("task_id", nargs="?", help="Target TASK-XXXX (omit with --aggregate)")
    parser.add_argument("--aggregate", action="store_true", help="Aggregate across all TASKs")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text")
    parser.add_argument(
        "--markdown-section",
        action="store_true",
        help="Emit a handoff §7 markdown section (v8.6.0 PR7 / K-1)",
    )
    parser.add_argument(
        "--since",
        default=None,
        help="Filter events with ts >= ISO date (e.g. 2026-05-04 or 2026-05-04T00:00:00Z) — v8.6.0 PR7 / K-2",
    )
    parser.add_argument(
        "--events-log",
        default=str(DEFAULT_EVENTS_LOG),
        help="Path to events.ndjson (default: docs/working/_metrics/events.ndjson)",
    )
    args = parser.parse_args(argv)

    if not args.task_id and not args.aggregate:
        parser.error("either task_id or --aggregate is required")

    events_log = Path(args.events_log)
    if not events_log.is_absolute():
        events_log = REPO_ROOT / events_log
    all_events = load_events(events_log)
    if args.since:
        all_events = filter_since(all_events, args.since)

    if args.aggregate:
        target_events = all_events
        task_id_label = None
    else:
        target_events = filter_task(all_events, args.task_id)
        task_id_label = args.task_id

    summary = summarize(target_events)
    if args.markdown_section:
        print(render_markdown_section(task_id_label, summary))
    elif args.json:
        out = {"task_id": task_id_label, "summary": summary}
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(render_text(task_id_label, summary))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
