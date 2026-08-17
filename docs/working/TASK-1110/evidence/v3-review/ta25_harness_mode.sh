#!/bin/sh
# Emulate run-tests.sh harness mode for ta-25 (PG_HARNESS_SOURCED=1 + FIXTURES_DIR).
WT=/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a7a16f3a740ac59c7
PG_HARNESS_SOURCED=1
export PG_HARNESS_SOURCED
FIXTURES_DIR="$WT/tests/fixtures"
export FIXTURES_DIR
pass=0
fail=0
register_cleanup() { :; }
. "$WT/tests/extras/ta-25-approval-token-guard.sh"
printf '\nHARNESS-MODE ta-25: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" = "0" ]
