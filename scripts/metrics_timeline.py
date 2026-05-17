#!/usr/bin/env python3
"""metrics_timeline.py — Trace Timeline v1 (#229 PBI-HI-013 / experimental)

docs/working/_metrics/events.ndjson から TASK 単位の timeline を
phase / gate / timestamp 順（#229 AC-3 契約）に正規化した JSON で出力する。

  python3 scripts/metrics_timeline.py <TASK-XXXX> [--events-log PATH]

experimental: quickstart / README 非掲載。debug / audit 用途限定。
schema 1.1 (gate_id / parent_event_id / phase WF・handoff) を読めるが
1.0 event とも後方互換。
"""
import json
import sys
from pathlib import Path

import sys as _phsys; from pathlib import Path as _phP; _phsys.path.insert(0, str(_phP(__file__).resolve().parent))
from _paths import REPO_ROOT  # noqa: E402
DEFAULT_LOG = REPO_ROOT / "docs" / "working" / "_metrics" / "events.ndjson"

# phase 正規化順（1.0 A..C-4 + 1.1 WF-01..06 / handoff）。enum 外は末尾。
PHASE_ORDER = [
    "A", "B", "C-1", "C-2", "C-3", "D", "L-0",
    "V-1", "V-2", "V-3", "V-4", "PR", "C-4",
    "WF-01", "WF-02", "WF-03", "WF-04", "WF-05", "WF-06", "handoff",
]


def main(argv: list[str]) -> int:
    task_id = None
    log = DEFAULT_LOG
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--events-log":
            i += 1
            log = Path(argv[i])
        elif a.startswith("TASK-"):
            task_id = a
        i += 1
    if not task_id:
        print("usage: metrics_timeline.py <TASK-XXXX> [--events-log PATH]",
              file=sys.stderr)
        return 2
    if not log.exists():
        print(json.dumps(
            {"task_id": task_id, "schema_version": "1.1",
             "experimental": True, "count": 0, "timeline": [],
             "note": "events.ndjson not found"},
            ensure_ascii=False, indent=2))
        return 0
    evs = []
    for raw in log.read_text().splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            ev = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if ev.get("task_id") == task_id:
            evs.append(ev)

    def sort_key(ev):
        # #229 AC-3 契約: phase / gate / timestamp 順で正規化
        ph = ev.get("phase", "")
        pidx = PHASE_ORDER.index(ph) if ph in PHASE_ORDER else len(PHASE_ORDER)
        return (pidx, ev.get("gate_id", "") or "", ev.get("ts", "") or "")

    evs.sort(key=sort_key)
    timeline = [
        {
            "ts": ev.get("ts"),
            "phase": ev.get("phase"),
            "gate_id": ev.get("gate_id"),
            "event": ev.get("event"),
            "parent_event_id": ev.get("parent_event_id"),
            "verdict": ev.get("verdict"),
        }
        for ev in evs
    ]
    print(json.dumps(
        {"task_id": task_id, "schema_version": "1.1",
         "experimental": True, "count": len(timeline), "timeline": timeline},
        ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
