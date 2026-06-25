#!/bin/sh
# TASK-0144 Gemini レビュー指摘修正スクリプト
# Patch 5: bin/plangate doctor の _read_plangate_config 2>/dev/null 削除
# Gemini medium 指摘: doctor は診断コマンドなので stderr を隠すべきでない
#
# 使い方:
#   sh scripts/apply-task-0144-gemini-fix.sh           # dry-run
#   sh scripts/apply-task-0144-gemini-fix.sh --apply   # 適用

set -eu

DRY_RUN=1
if [ "${1:-}" = "--apply" ]; then
  DRY_RUN=0
fi

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET="$REPO_ROOT/bin/plangate"

OLD="  _c3mode_doctor=\$(_read_plangate_config c3_approval.mode 2>/dev/null || echo 'cli')"
NEW="  _c3mode_doctor=\$(_read_plangate_config c3_approval.mode || echo 'cli')"

if ! grep -qF "$OLD" "$TARGET"; then
  if grep -qF "$NEW" "$TARGET"; then
    echo "[SKIP] bin/plangate: already applied (2>/dev/null already removed)"
    exit 0
  fi
  echo "[ERROR] bin/plangate: anchor not found"
  exit 1
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY-RUN] bin/plangate: 2>/dev/null を削除します（診断警告を表示）"
  echo "  OLD: $OLD"
  echo "  NEW: $NEW"
  echo ""
  echo "適用するには: sh scripts/apply-task-0144-gemini-fix.sh --apply"
else
  cp "$TARGET" "$TARGET.bak"
  python3 - "$TARGET" << 'PYEOF'
import sys
path = sys.argv[1]
old = "  _c3mode_doctor=$(_read_plangate_config c3_approval.mode 2>/dev/null || echo 'cli')"
new = "  _c3mode_doctor=$(_read_plangate_config c3_approval.mode || echo 'cli')"
with open(path, encoding="utf-8") as f:
    content = f.read()
with open(path, "w", encoding="utf-8") as f:
    f.write(content.replace(old, new, 1))
PYEOF
  echo "[DONE] bin/plangate: 2>/dev/null 削除 (.bak saved)"
fi
