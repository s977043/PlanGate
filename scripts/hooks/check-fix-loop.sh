#!/bin/sh
# check-fix-loop.sh — Hook EHS-3: V-1 fix loop 上限超過 escalation
#
# Usage:
#   sh scripts/hooks/check-fix-loop.sh <TASK-XXXX> [increment]
#
#   increment = "increment"  カウンタを +1 してから判定
#   省略時は判定のみ
#
# Modes:
#   default                       warning のみ
#   PLANGATE_HOOK_STRICT=1        上限超過時 exit 1（ABORT）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 上限: 5 回（PLANGATE_FIX_LOOP_MAX で上書き可）
# カウンタ: docs/working/TASK-XXXX/.fix-loop-count
#
# Issue #157 / TASK-0048

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"
MAX=${PLANGATE_FIX_LOOP_MAX:-5}

if [ $# -eq 0 ]; then
  printf 'Usage: %s <TASK-XXXX> [increment]\n' "$0" >&2
  exit 2
fi

task_id=$1
action=${2:-check}

case "$task_id" in
  TASK-*) ;;
  *)
    printf 'error: invalid task_id: %s\n' "$task_id" >&2
    exit 2
    ;;
esac

counter_file="$WORKING_DIR/$task_id/.fix-loop-count"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-fix-loop\t%s\t%s\n' "$ts" "$level" "$task_id" "$msg" >>"$AUDIT_LOG"
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EHS-3] BYPASS\n'
  exit 0
fi

# Read current count
if [ -f "$counter_file" ]; then
  count=$(cat "$counter_file")
else
  count=0
fi

# Increment if requested
if [ "$action" = "increment" ]; then
  count=$((count + 1))
  mkdir -p "$(dirname "$counter_file")"
  printf '%d\n' "$count" >"$counter_file"
  log_event "INCREMENT" "count=$count"
fi

# Judgment
if [ "$count" -gt "$MAX" ]; then
  reason="V-1 fix loop exceeded $MAX iterations (current: $count)"
  log_event "VIOLATION" "$reason"
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    printf '[Hook EHS-3 ABORT] %s\n' "$reason" >&2
    printf 'Escalate to user. Review root cause before retrying.\n' >&2
    printf 'Reset: rm "%s"\n' "$counter_file" >&2
    exit 1
  fi
  printf '[Hook EHS-3 WARNING] %s\n' "$reason" >&2
  exit 0
fi

log_event "PASS" "count=$count, max=$MAX"
printf '[Hook EHS-3 PASS] fix loop count: %d/%d\n' "$count" "$MAX"
exit 0
