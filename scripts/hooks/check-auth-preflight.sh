#!/bin/sh
# check-auth-preflight.sh — exec 前 認証三点プリフライト（F2 / #239 問題3）
#
# exec 開始前に git 操作の認証整合を決定論的に検証する:
#   1. gh active account     （gh auth status の active アカウント）
#   2. git config user.email （コミット主体）
#   3. git remote (origin)    （push 先）
#
# 期待値ソース（優先順）:
#   - env PLANGATE_EXPECTED_GH_ACCOUNT  期待 gh アカウント（明示時は厳格一致）
#   - 未指定時: 現状を報告し、3 点が「存在する」ことのみ検証（欠落は停止）
#
# Modes:
#   default                       不整合は exit 1（停止条件）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 監査: docs/working/_audit/hook-events.log
# F2 / TASK-0073 / V-3 MJ-2

set -eu
REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
AUDIT_LOG="$REPO_ROOT/docs/working/_audit/hook-events.log"

log_event() {
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-auth-preflight\t%s\t%s\n' "$ts" "$1" "${PLANGATE_HOOK_TASK:--}" "$2" >>"$AUDIT_LOG"
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1"
  printf '[auth-preflight] BYPASS\n'; exit 0
fi

fail=0
detail=""

# 1. gh active account
gh_acct=""
if command -v gh >/dev/null 2>&1; then
  gh_acct=$(gh auth status 2>/dev/null | sed -n 's/.*Active account: true.*//p' >/dev/null 2>&1; \
            gh auth status 2>/dev/null | awk '/Logged in to github.com account/{a=$0} /Active account: true/{print prev} {prev=$0}' \
            | sed -n 's/.*account \([A-Za-z0-9_-]*\).*/\1/p' | head -1)
  if [ -z "$gh_acct" ]; then
    gh_acct=$(gh api user -q .login 2>/dev/null || echo "")
  fi
fi
[ -z "$gh_acct" ] && { fail=1; detail="$detail gh-active-account=MISSING"; } || detail="$detail gh=$gh_acct"

# 2. git config user.email
g_email=$(git config user.email 2>/dev/null || echo "")
[ -z "$g_email" ] && { fail=1; detail="$detail git-user.email=MISSING"; } || detail="$detail email=$g_email"

# 3. git remote origin
g_remote=$(git remote get-url origin 2>/dev/null || echo "")
[ -z "$g_remote" ] && { fail=1; detail="$detail origin=MISSING"; } || detail="$detail remote=set"

# 期待値厳格一致（指定時）
exp=${PLANGATE_EXPECTED_GH_ACCOUNT:-}
if [ -n "$exp" ] && [ -n "$gh_acct" ] && [ "$exp" != "$gh_acct" ]; then
  fail=1
  detail="$detail EXPECTED=$exp ACTUAL=$gh_acct(MISMATCH)"
fi

if [ "$fail" = "1" ]; then
  log_event "VIOLATION" "auth preflight failed:$detail"
  printf '[auth-preflight] FAIL —%s\n' "$detail" >&2
  printf '  exec 前に認証三点（gh active / git user.email / origin）を整合させてください。\n' >&2
  exit 1
fi

log_event "PASS" "auth preflight ok:$detail"
printf '[auth-preflight] PASS —%s\n' "$detail"
exit 0
