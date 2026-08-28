#!/bin/sh
# V-3 independent mutation probe: mutate call sites the worker's M-1/M-2 do NOT cover,
# and check whether the focused TC group kills them.
set -u
SB=/private/tmp/claude-502/-Users-user-Documents-GitHub-plangate/ed736940-223f-452c-bd1b-4dfefbc8ee9d/scratchpad
WT=/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a7a16f3a740ac59c7
SRC="$WT/scripts/check-approval-token-write.sh"

run_mutant() {
  _label="$1"; _mut="$2"
  cp "$SRC" "$SB/mut.sh"
  LC_ALL=C sed -i.bak "$_mut" "$SB/mut.sh" || { echo "$_label: sed failed"; return; }
  if ! sh -n "$SB/mut.sh" 2>/dev/null; then echo "$_label: SYNTAX ERROR in mutant"; return; fi
  if cmp -s "$SRC" "$SB/mut.sh"; then echo "$_label: MUTATION WAS A NO-OP (not applied)"; return; fi
  out=$(env PG_T25_GUARD="$SB/mut.sh" PG_T25_MUTATION_CHILD=1 \
        sh "$WT/tests/extras/ta-25-approval-token-guard.sh" 2>&1)
  rc=$?
  failed=$(printf '%s\n' "$out" | grep -c '\[FAIL\]' || true)
  printf '%-16s rc=%s failing-TCs=%s\n' "$_label" "$rc" "$failed"
  printf '%s\n' "$out" | grep '\[FAIL\]' | sed 's/^/      /'
}

echo "=== baseline (unmutated, focused group) ==="
run_mutant "M-0 baseline" 's@__never_matches__@x@'

echo
echo "=== V-3 mutation A: fail-closed branch for \$ / backtick / glob is neutered ==="
run_mutant "M-A" "s@^        _wi_redirect_target=\"\$_rw_t\"; _rw_hit=0; break ;;\$@        continue ;;@"

echo
echo "=== V-3 mutation B: &> early-return no longer blocks ==="
run_mutant "M-B" "s@^    \\*'&>'\\*) _wi_redirect_target='&>(all-output-redirect)'; return 0 ;;\$@    *'\&>'*) return 1 ;;@"

echo
echo "=== V-3 mutation C: revert commit f922442 (drop the diagnostic reset line) ==="
run_mutant "M-C" 's@^  _wi_redirect_target=""$@  : # reset removed@'

echo
echo "=== V-3 mutation D: newline flattening removed (heredoc/multi-line lane) ==="
run_mutant "M-D" "s@| tr '\\\\n' ' '@| cat@"

rm -f "$SB/mut.sh" "$SB/mut.sh.bak"
