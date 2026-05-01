#!/bin/sh
# check-test-cases.sh — Hook EH-4: test-cases.md なし V-1 ブロック
#
# Usage:
#   sh scripts/hooks/check-test-cases.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-test-cases.sh
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（V-1 block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0057

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-test-cases\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-4] BYPASS\n'
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

tc_file="$WORKING_DIR/$task_id/test-cases.md"

if [ -f "$tc_file" ]; then
  log_event "PASS" "test-cases.md exists"
  printf '[Hook EH-4 PASS] test-cases.md present at %s\n' "$tc_file"
  exit 0
fi

reason="test-cases.md not found: $tc_file (V-1 cannot proceed without test cases)"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-4 BLOCK] %s\n' "$reason" >&2
  printf '  Action: docs/working/%s/test-cases.md を作成してから V-1 を実行してください。\n' "$task_id" >&2
  exit 1
fi

printf '[Hook EH-4 WARNING] %s\n' "$reason" >&2
exit 0
