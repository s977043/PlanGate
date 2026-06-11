#!/bin/sh
# apply-explorer-agent-tools-fix.sh — explorer-agent の実在しないツール名を除去（Human 実行）
#
# 背景: tools: に Claude Code に存在しない ViewCodeItem / FindByName が残存
# （v6 期の他ツール由来の名残。model tier レビューで指摘、2026-06-11 改善提案 3）。
# .claude/agents/*.md は HO のため AI は本スクリプト作成と --dry-run まで。
# 再発防止は tests/extras/ta-38-agent-tools.sh が CI で機械検査する。
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
F="$ROOT/.claude/agents/explorer-agent.md"
OLD='tools: Read, Grep, Glob, Bash, ViewCodeItem, FindByName'
NEW='tools: Read, Grep, Glob, Bash'

if grep -qF -- "$NEW" "$F" && ! grep -qF -- "$OLD" "$F"; then echo "OK (already)"; exit 0; fi
grep -qF -- "$OLD" "$F" || { echo "ERROR: アンカー不在" >&2; exit 1; }
case "$MODE" in
  --dry-run) echo "[dry-run] explorer-agent.md:"; echo "- $OLD"; echo "+ $NEW" ;;
  --apply)
    python3 - "$F" "$OLD" "$NEW" <<'PY'
import sys
f, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(f, encoding="utf-8").read()
assert s.count(old) == 1
open(f, "w", encoding="utf-8").write(s.replace(old, new))
PY
    echo "APPLIED: explorer-agent.md" ;;
  *) echo "usage: $0 [--dry-run|--apply]"; exit 1 ;;
esac
