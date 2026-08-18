#!/bin/sh
# Same mutations, but evaluated against the FULL ta-25 group (not just focused).
set -u
SB=/private/tmp/claude-502/-Users-user-Documents-GitHub-plangate/ed736940-223f-452c-bd1b-4dfefbc8ee9d/scratchpad
WT=/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a7a16f3a740ac59c7
SRC="$WT/scripts/check-approval-token-write.sh"

run_mutant() {
  _label="$1"; _mut="$2"
  cp "$SRC" "$SB/mutf.sh"
  LC_ALL=C sed -i.bak "$_mut" "$SB/mutf.sh" || { echo "$_label: sed failed"; return; }
  sh -n "$SB/mutf.sh" 2>/dev/null || { echo "$_label: SYNTAX ERROR"; return; }
  cmp -s "$SRC" "$SB/mutf.sh" && { echo "$_label: NO-OP"; return; }
  out=$(env PG_T25_GUARD="$SB/mutf.sh" sh "$WT/tests/extras/ta-25-approval-token-guard.sh" 2>&1)
  rc=$?
  printf '%-6s rc=%s  %s\n' "$_label" "$rc" "$(printf '%s\n' "$out" | grep 'TA-25 standalone:')"
  printf '%s\n' "$out" | grep '\[FAIL\]' | sed 's/^/      /'
}

run_mutant "M-B" "s@^    \\*'&>'\\*) _wi_redirect_target='&>(all-output-redirect)'; return 0 ;;\$@    *'\&>'*) return 1 ;;@"
run_mutant "M-C" 's@^  _wi_redirect_target=""$@  : # reset removed@'
run_mutant "M-D" "s@| tr '\\\\n' ' '@| cat@"
rm -f "$SB/mutf.sh" "$SB/mutf.sh.bak"
