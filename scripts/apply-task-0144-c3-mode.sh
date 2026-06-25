#!/usr/bin/env bash
# TASK-0144: C-3 approval mode (cli/conversation) apply-script ラッパー
# 使い方:
#   sh scripts/apply-task-0144-c3-mode.sh           # dry-run（確認のみ）
#   sh scripts/apply-task-0144-c3-mode.sh --apply   # 実際にパッチ適用
#
# HO パス対象: bin/plangate / schemas/*.schema.json / scripts/hooks/check-plan-hash.sh
# → AI が直接編集不可（HO ガード）なのでこのスクリプトをユーザーが --apply 実行する
#
# Non-HO: schemas/plangate-config.schema.json は新規ファイルで HO 対象外だが、
#         一括適用の便宜上ここに含める。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY_SCRIPT="$REPO_ROOT/scripts/_apply_task_0144_patches.py"

if [ ! -f "$PY_SCRIPT" ]; then
  printf 'ERROR: %s not found\n' "$PY_SCRIPT" >&2
  exit 1
fi

if [ "${1:-}" = "--apply" ]; then
  printf '=== APPLY MODE: HO パスに実際にパッチを書き込みます ===\n'
  printf 'Backups will be created as *.bak\n\n'
  python3 "$PY_SCRIPT" "$REPO_ROOT" "0"
  printf '\nApply complete. Run: sh tests/run-tests.sh\n'
else
  printf '=== DRY-RUN MODE (確認のみ) ===\n'
  printf 'To apply, run: sh %s --apply\n\n' "$0"
  python3 "$PY_SCRIPT" "$REPO_ROOT" "1"
fi
