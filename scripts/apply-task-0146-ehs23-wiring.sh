#!/bin/sh
# scripts/apply-task-0146-ehs23-wiring.sh
# TASK-0146 / #527: EHS-2/3 配線 apply ラッパー
# Usage:
#   sh scripts/apply-task-0146-ehs23-wiring.sh          # dry-run（デフォルト）
#   sh scripts/apply-task-0146-ehs23-wiring.sh --apply  # 適用
#
# Human が実行する。AI は dry-run のみ（--apply 実行禁止）。

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APPLY_FLAG=0

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY_FLAG=1 ;;
  esac
done

if [ "$APPLY_FLAG" = "0" ]; then
  printf "[dry-run] EHS-2/3 配線 diff (bin/plangate)\n"
  python3 "$REPO_ROOT/scripts/_apply_task_0146_patches.py" "$REPO_ROOT" 1
  printf "\n[dry-run] bin/plangate への適用を確認したら --apply で実行してください。\n"
  exit 0
fi

printf "[apply] EHS-2/3 配線を bin/plangate に適用します...\n"
python3 "$REPO_ROOT/scripts/_apply_task_0146_patches.py" "$REPO_ROOT" 0
printf "[apply] 完了。sh tests/run-tests.sh で ta-47 PASS を確認してください。\n"
