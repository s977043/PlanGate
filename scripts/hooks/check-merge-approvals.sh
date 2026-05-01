#!/bin/sh
# check-merge-approvals.sh — Hook EH-7: 2 段階レビューなしマージ block
#
# Usage:
#   sh scripts/hooks/check-merge-approvals.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-merge-approvals.sh
#
# 検査:
#   docs/working/$TASK/approvals/c3.json と c4-approval.json (or c4.json) の
#   両方が `APPROVED` であることを確認。
#   どちらかでも欠損 / 別ステータスなら違反。
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（マージ block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 注意: 本 hook は **ローカル CLI 検証のみ**。GitHub branch protection /
# ruleset の自動適用は scope 外（別 PBI 候補）。
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0058

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-merge-approvals\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

read_status() {
  # $1: file path, $2: key（c3_status or c4_status）
  if [ ! -f "$1" ]; then
    echo "MISSING"
    return
  fi
  grep "\"$2\"" "$1" 2>/dev/null \
    | sed "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/" \
    | head -1
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-7] BYPASS\n'
  exit 0
fi

task_id=${PLANGATE_HOOK_TASK:-${1:-}}
if [ -z "$task_id" ]; then
  printf 'Usage: %s <TASK-XXXX>  (or set PLANGATE_HOOK_TASK)\n' "$0" >&2
  exit 2
fi

case "$task_id" in
  TASK-*) ;;
  *)
    printf 'error: invalid task_id: %s\n' "$task_id" >&2
    exit 2
    ;;
esac

c3_file="$WORKING_DIR/$task_id/approvals/c3.json"
# c4 の正規 filename は c4-approval.json（schemas/c4-approval.schema.json）だが
# 過去運用の c4.json も互換性のため許容
c4_file_a="$WORKING_DIR/$task_id/approvals/c4-approval.json"
c4_file_b="$WORKING_DIR/$task_id/approvals/c4.json"
if [ -f "$c4_file_a" ]; then
  c4_file=$c4_file_a
else
  c4_file=$c4_file_b
fi

c3_status=$(read_status "$c3_file" "c3_status")
c4_status=$(read_status "$c4_file" "c4_status")

violations=""
[ "$c3_status" = "APPROVED" ] || violations="${violations}c3=$c3_status "
[ "$c4_status" = "APPROVED" ] || violations="${violations}c4=$c4_status "

if [ -z "$violations" ]; then
  log_event "PASS" "c3=APPROVED c4=APPROVED"
  printf '[Hook EH-7 PASS] both C-3 and C-4 are APPROVED\n'
  exit 0
fi

reason="2-stage review incomplete: $violations(merge requires C-3 APPROVED + C-4 APPROVED)"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-7 BLOCK] %s\n' "$reason" >&2
  printf '  Action: docs/working/%s/approvals/{c3.json, c4-approval.json} を APPROVED 状態に揃えてからマージしてください。\n' "$task_id" >&2
  exit 1
fi

printf '[Hook EH-7 WARNING] %s\n' "$reason" >&2
exit 0
