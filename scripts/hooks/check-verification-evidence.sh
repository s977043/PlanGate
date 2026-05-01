#!/bin/sh
# check-verification-evidence.sh — Hook EH-5: 検証ログなし PR 作成ブロック
#
# Usage:
#   sh scripts/hooks/check-verification-evidence.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-verification-evidence.sh
#
# 検査:
#   docs/working/$TASK/evidence/ 配下に verification 系ファイルが少なくとも 1 つ存在するか。
#   候補ファイル名（部分一致 OK）:
#     - verification.md
#     - v1-acceptance-result.md
#     - acceptance-result.md
#     - verification-*.md
#     - test-runs/
#     - baseline-data*.md
#
#   ディレクトリ自体が無い、または該当ファイルがゼロの場合は違反。
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（PR 作成 block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
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
  printf '%s\t%s\tcheck-verification-evidence\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-5] BYPASS\n'
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

evidence_dir="$WORKING_DIR/$task_id/evidence"

if [ ! -d "$evidence_dir" ]; then
  reason="evidence/ directory not found: $evidence_dir"
  log_event "VIOLATION" "$reason"
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    printf '[Hook EH-5 BLOCK] %s\n' "$reason" >&2
    printf '  Action: 検証ログ（verification.md / v1-acceptance-result.md 等）を docs/working/%s/evidence/ に保存してから PR を作成してください。\n' "$task_id" >&2
    exit 1
  fi
  printf '[Hook EH-5 WARNING] %s\n' "$reason" >&2
  exit 0
fi

# 候補ファイルパターン（POSIX find で any-match）
match_count=$(find "$evidence_dir" \( \
  -name 'verification.md' \
  -o -name 'verification-*.md' \
  -o -name 'v1-acceptance-result.md' \
  -o -name 'acceptance-result.md' \
  -o -name 'baseline-data*.md' \
  -o -name 'test-runs' \
  \) 2>/dev/null | wc -l | tr -d ' ')

if [ "$match_count" -gt 0 ]; then
  log_event "PASS" "evidence files found: $match_count"
  printf '[Hook EH-5 PASS] %d verification file(s) found in evidence/\n' "$match_count"
  exit 0
fi

# evidence/ は存在するが verification 系ファイルがない
reason="no verification artifacts in $evidence_dir (expected: verification.md / v1-acceptance-result.md / etc)"
log_event "VIOLATION" "$reason"
if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-5 BLOCK] %s\n' "$reason" >&2
  printf '  Action: 検証ログを保存してから PR を作成してください。\n' >&2
  exit 1
fi
printf '[Hook EH-5 WARNING] %s\n' "$reason" >&2
exit 0
