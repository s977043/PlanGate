#!/bin/sh
# scripts/apply-task-0147-bias-export.sh
# TASK-0147 / EPIC #527 follow-up — validation_bias の conductor export 配線
#
#   bin/plangate verify / handoff --verify が --profile <key> を受理し、
#   model-profiles.yaml の validation_bias を解決して PLANGATE_VALIDATION_BIAS
#   を内部 export する。これにより strict profile で EHS-1/2/3 が実 run 発火する。
#   env で既に明示注入済みなら尊重（上書きしない）。normal/lenient は非発火＝
#   既存挙動不変。workflow-conductor.md には非強制の運用補足を追記。
#
# Human が実行する（HO パス bin/plangate / .claude/agents を変更するため）。
#
# 使い方:
#   sh scripts/apply-task-0147-bias-export.sh --dry-run  # 差分確認のみ
#   sh scripts/apply-task-0147-bias-export.sh --apply    # 実際に適用

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=1
for _arg in "$@"; do
  case "$_arg" in
    --apply)   DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    *) printf 'Usage: %s [--dry-run|--apply]\n' "$0" >&2; exit 2 ;;
  esac
done

printf '=== apply-task-0147-bias-export.sh (dry_run=%s) — validation_bias export ===\n' "$DRY_RUN"
exec python3 "$REPO_ROOT/scripts/_apply_task_0147_patches.py" "$REPO_ROOT" "$DRY_RUN"
