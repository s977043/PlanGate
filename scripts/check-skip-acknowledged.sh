#!/bin/sh
# check-skip-acknowledged.sh — SKIP_REASON 未追認検出（TASK-0082 S5 / C-3 ③）
#
# docs/working/_audit/skip-decision-log.jsonl の EH-3_SKIP エントリで
# acknowledged_by が null のものがあれば fail（CI required）。
# 人間が C-3/C-4 で reason を確認し acknowledged_by/acknowledged_at を
# 追記するまで PR を通さない（SKIP_REASON の形骸化防止）。
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOG="$ROOT/docs/working/_audit/skip-decision-log.jsonl"
[ -f "$LOG" ] || { printf '[skip-ack] PASS: skip-decision-log なし（SKIP 実績なし）\n'; exit 0; }
python3 - "$LOG" <<'PY'
import json, sys
unack = []
for i, line in enumerate(open(sys.argv[1]), 1):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        print(f"[skip-ack] FAIL: L{i} 不正 JSON", file=sys.stderr); sys.exit(1)
    if d.get("event") == "EH-3_SKIP" and (not d.get("acknowledged_by") or not d.get("acknowledged_at")):
        unack.append((i, d.get("skip_reason", ""), d.get("target", "")))
if unack:
    for i, r, t in unack:
        print(f"[skip-ack] 未追認 L{i}（acknowledged_by/at 両方必須）: target={t} reason={r}", file=sys.stderr)
    print(f"[skip-ack] FAIL: 未追認 SKIP {len(unack)} 件。人間が acknowledged_by/"
          f"acknowledged_at を追記してください（C-3/C-4 で reason 確認）", file=sys.stderr)
    sys.exit(1)
print("[skip-ack] PASS: 全 EH-3_SKIP が人間追認済")
PY
