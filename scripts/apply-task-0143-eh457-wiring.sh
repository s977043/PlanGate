#!/bin/sh
# scripts/apply-task-0143-eh457-wiring.sh
# TASK-0143 AC-01/02/07 HO パッチ適用スクリプト
#
# 変更内容:
#   Patch 1: bin/plangate cmd_verify に EH-4 呼び出し追加（strict=1、V-1 前）
#   Patch 2: bin/plangate cmd_verify に EH-5 呼び出し追加（warn、V-1 後）
#   Patch 3: bin/plangate cmd_doctor に CLI Hook Wiring セクション追加
#
# Human が実行する（HO パス bin/plangate を変更するため）
#
# 使い方:
#   sh scripts/apply-task-0143-eh457-wiring.sh --dry-run  # 差分確認のみ
#   sh scripts/apply-task-0143-eh457-wiring.sh --apply    # 実際に適用

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=1
for _arg in "$@"; do
  case "$_arg" in
    --apply)   DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      printf 'Usage: %s [--dry-run|--apply]\n' "$0" >&2
      exit 2
      ;;
  esac
done

printf '=== apply-task-0143-eh457-wiring.sh (dry_run=%s) ===\n' "$DRY_RUN"

exec python3 "$REPO_ROOT/scripts/_apply_task_0143_patches.py" "$REPO_ROOT" "$DRY_RUN"
