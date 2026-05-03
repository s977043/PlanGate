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
    """Compute summary counters for the given event slice."""
    summary: dict = {
        "event_count": len(events),
        "events_by_type": dict(Counter(ev.get("event", "?") for ev in events)),
        "hook_violations": {
            "total": 0,
            "by_hook_id": {},
            "by_result": {},
        },
        "c3": {"APPROVED": 0, "CONDITIONAL": 0, "REJECTED": 0},
        "c4": {"APPROVED": 0, "REQUEST_CHANGES": 0, "REJECTED": 0},
        "v1": {"PASS": 0, "FAIL": 0, "WARN": 0},
        "fix_loop_max": 0,
        "modes": {},
    }

    for ev in events:
        event_type = ev.get("event")

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
        elif event_type == "c3_decided":
            v = ev.get("verdict", "?")
            if v in summary["c3"]:
                summary["c3"][v] += 1
        elif event_type == "c4_decided":
            v = ev.get("verdict", "?")
            if v in summary["c4"]:
                summary["c4"][v] += 1
        elif event_type == "v1_completed":
            v = ev.get("verdict", "?")
            if v in summary["v1"]:
                summary["v1"][v] += 1
        elif event_type == "fix_loop_incremented":
            count = ev.get("fix_loop_count", 0)
            if isinstance(count, int) and count > summary["fix_loop_max"]:
                summary["fix_loop_max"] = count
        elif event_type == "plan_generated":
            mode = ev.get("mode")
            if mode:
                summary["modes"][mode] = summary["modes"].get(mode, 0) + 1

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
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("task_id", nargs="?", help="Target TASK-XXXX (omit with --aggregate)")
    parser.add_argument("--aggregate", action="store_true", help="Aggregate across all TASKs")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text")
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

    if args.aggregate:
        target_events = all_events
        task_id_label = None
    else:
        target_events = filter_task(all_events, args.task_id)
        task_id_label = args.task_id

    summary = summarize(target_events)
    if args.json:
        out = {"task_id": task_id_label, "summary": summary}
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(render_text(task_id_label, summary))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
