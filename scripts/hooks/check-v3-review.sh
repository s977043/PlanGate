#!/bin/sh
# check-v3-review.sh — Hook EHS-1: V-3 外部レビュー必須化
#
# Usage:
#   sh scripts/hooks/check-v3-review.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-v3-review.sh
#
# Mode 連携:
#   PLANGATE_HOOK_MODE 環境変数で対象 PBI mode を受領。
#   standard / high-risk / critical では V-3 必須、light / ultra-light では skip。
#
# 検査:
#   docs/working/$TASK/review-external.md の存在
#   または docs/working/$TASK/evidence/v3-review/ ディレクトリ + 中にファイルあり
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（PR 作成 block、validation_bias: strict 用）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
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
  printf '%s\t%s\tcheck-v3-review\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EHS-1] BYPASS\n'
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

# mode による必須化判定
mode=${PLANGATE_HOOK_MODE:-standard}
case "$mode" in
  light|ultra-light)
    log_event "SKIP" "mode=$mode (V-3 not required)"
    printf '[Hook EHS-1 SKIP] mode=%s — V-3 review not required for light/ultra-light\n' "$mode"
    exit 0
    ;;
  standard|high-risk|critical) ;;
  *)
    log_event "WARN" "unknown mode: $mode (treating as standard)"
    ;;
esac

# 存在チェック: review-external.md OR evidence/v3-review/ 配下にファイルあり
external_md="$WORKING_DIR/$task_id/review-external.md"
v3_dir="$WORKING_DIR/$task_id/evidence/v3-review"

found=""
if [ -f "$external_md" ]; then
  found="review-external.md"
fi

if [ -z "$found" ] && [ -d "$v3_dir" ]; then
  if [ "$(find "$v3_dir" -type f 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
    found="evidence/v3-review/"
  fi
fi

if [ -n "$found" ]; then
  log_event "PASS" "V-3 evidence found: $found (mode=$mode)"
  printf '[Hook EHS-1 PASS] V-3 review evidence found: %s\n' "$found"
  exit 0
fi

reason="V-3 external review missing for mode=$mode (expected: review-external.md or evidence/v3-review/)"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EHS-1 BLOCK] %s\n' "$reason" >&2
  printf '  Action: docs/working/%s/review-external.md を作成、または evidence/v3-review/ に外部レビュー結果を保存してから PR を作成してください。\n' "$task_id" >&2
  exit 1
fi

printf '[Hook EHS-1 WARNING] %s\n' "$reason" >&2
exit 0
