#!/bin/sh
# check-plan-hash.sh — Hook EH-3: plan_hash 改竄検知
#
# approvals/c3.json の plan_hash と現 plan.md の SHA-256 を突合。
# 不一致なら C-3 承認後に plan が改変されたことを示す → 違反。
#
# Usage:
#   sh scripts/hooks/check-plan-hash.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-plan-hash.sh
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0056

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# bypass
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-3] BYPASS\n'
  exit 0
fi

# TASK resolution
task_id=${PLANGATE_HOOK_TASK:-}
if [ -z "$task_id" ]; then
  task_id=${1:-}
fi

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

plan_file="$WORKING_DIR/$task_id/plan.md"
c3_file="$WORKING_DIR/$task_id/approvals/c3.json"

if [ ! -f "$plan_file" ]; then
  reason="plan.md not found: $plan_file"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

if [ ! -f "$c3_file" ]; then
  reason="c3.json not found: $c3_file (no approval to compare against)"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

# c3.json から plan_hash を抽出
recorded_hash=$(grep '"plan_hash"' "$c3_file" 2>/dev/null \
  | sed 's/.*"plan_hash"[[:space:]]*:[[:space:]]*"sha256:\([0-9a-f]*\)".*/\1/' || echo "")

if [ -z "$recorded_hash" ]; then
  reason="plan_hash not found in c3.json"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

current_hash=$(sha256_of "$plan_file")

if [ "$recorded_hash" = "$current_hash" ]; then
  log_event "PASS" "plan_hash matches"
  printf '[Hook EH-3 PASS] plan_hash matches current plan.md\n'
  exit 0
fi

reason="plan_hash mismatch: recorded=$recorded_hash, current=$current_hash"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-3 BLOCK] plan.md was modified after C-3 approval.\n' >&2
  printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
  printf '  Current : sha256:%s\n' "$current_hash" >&2
  printf '  Action  : Re-approval required (update c3.json plan_hash) or revert plan.md.\n' >&2
  exit 1
fi

printf '[Hook EH-3 WARNING] plan_hash mismatch (plan.md modified post-C-3)\n' >&2
printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
printf '  Current : sha256:%s\n' "$current_hash" >&2
exit 0
