#!/bin/sh
# scripts/apply-task-0145-ehs-wiring.sh
# TASK-0145 / EPIC #527 — EHS strict 発火配線（増分1: EHS-1）
#
#   EHS-1: bin/plangate verify が validation_bias=strict 時に V-3 外部レビュー
#   合格を必須化（block）。発火条件は env PLANGATE_VALIDATION_BIAS（conductor が
#   model-profiles.yaml の active profile から解決・エクスポート）。
#   非 strict（既定 normal）は従来どおり warn のみ＝既存挙動不変。
#
#   EHS-2（handoff 6要素）/ EHS-3（fix-loop 上限）は増分2 で別 apply-script。
#
# Human が実行する（HO パス bin/plangate を変更するため）。
#
# 使い方:
#   sh scripts/apply-task-0145-ehs-wiring.sh --dry-run  # 差分確認のみ
#   sh scripts/apply-task-0145-ehs-wiring.sh --apply    # 実際に適用

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

printf '=== apply-task-0145-ehs-wiring.sh (dry_run=%s) — EHS-1 ===\n' "$DRY_RUN"
exec python3 "$REPO_ROOT/scripts/_apply_task_0145_patches.py" "$REPO_ROOT" "$DRY_RUN"
