#!/bin/sh
# acknowledge-skip-log.sh — skip-decision-log.jsonl の未追認エントリを追認する
# 使用: sh scripts/acknowledge-skip-log.sh [acknowledged_by]
# 例:   sh scripts/acknowledge-skip-log.sh s977043

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOG="$REPO_ROOT/docs/working/_audit/skip-decision-log.jsonl"
BY="${1:-s977043}"

python3 - "$LOG" "$BY" << 'PYEOF'
import json, sys
from datetime import datetime, timezone

path, by = sys.argv[1], sys.argv[2]
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

updated, count = [], 0
with open(path, encoding='utf-8') as f:
    lines = [l.strip() for l in f if l.strip()]

for line in lines:
    e = json.loads(line)
    if e.get('event', '').startswith('EH-') and e.get('acknowledged_by') is None:
        e['acknowledged_by'] = by
        e['acknowledged_at'] = now
        count += 1
    updated.append(json.dumps(e, ensure_ascii=False, separators=(',', ':')))

with open(path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(updated) + '\n')

print(f"Updated {count} entries (acknowledged_by={by})")
PYEOF
