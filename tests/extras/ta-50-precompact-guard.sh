# tests/extras/ta-50-precompact-guard.sh
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# TASK issue #742: PreCompact memory guard (staged hook, non-HO)
#
# Sandbox: copy scripts/precompact-memory-guard.sh into a tmp dir mimicking
# <tmp>/scripts/precompact-memory-guard.sh + <tmp>/docs/working/... so the
# hook's own REPO_ROOT resolution (dirname "$0"/..) points into the sandbox
# (ta-39 pattern) -- avoids touching real docs/working.

printf '\n=== TA-50: PreCompact memory guard (#742) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T50_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T50_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T50_SRC="$_T50_ROOT/scripts/precompact-memory-guard.sh"
_T50_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T50_TMP"
fi

mkdir -p "$_T50_TMP/scripts"
mkdir -p "$_T50_TMP/docs/working/TASK-TA50"
cp "$_T50_SRC" "$_T50_TMP/scripts/precompact-memory-guard.sh"
chmod +x "$_T50_TMP/scripts/precompact-memory-guard.sh"
_T50_HOOK="$_T50_TMP/scripts/precompact-memory-guard.sh"
_T50_CS="$_T50_TMP/docs/working/TASK-TA50/current-state.md"

t50_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t50_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# --- TC-01: non-TASK context -> silent (exit 0, no output) ---
_t50_rc=0
_t50_out=$(PLANGATE_HOOK_TASK= sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
if [ "$_t50_rc" = "0" ] && [ -z "$_t50_out" ]; then
  t50_pass "TC-01: no TASK context -> silent exit 0"
else
  t50_fail "TC-01: expected silent exit0, got rc=$_t50_rc out=$_t50_out"
fi

# --- TC-01b: invalid task_id formats (path traversal / non-TASK) -> silent ---
# PLANGATE_HOOK_TASK is interpolated into a filesystem path; invalid formats
# must be silently skipped (exit 0, no output) -- traversal guard.
_t50_trav_ok=1
for _t50_bad in "../../etc" "TASK-../../etc" "TASK-X/../../etc" "notatask"; do
  _t50_rc=0
  _t50_out=$(PLANGATE_HOOK_TASK="$_t50_bad" sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
  if [ "$_t50_rc" != "0" ] || [ -n "$_t50_out" ]; then
    _t50_trav_ok=0
    printf '    (invalid task_id %s: rc=%s out=%s)\n' "$_t50_bad" "$_t50_rc" "$_t50_out" >&2
  fi
done
if [ "$_t50_trav_ok" = "1" ]; then
  t50_pass "TC-01b: invalid task_id (traversal/non-TASK) -> silent exit 0"
else
  t50_fail "TC-01b: invalid task_id must be silent exit 0 (see above)"
fi

# --- TC-02: current-state.md missing -> warn (exit 0 + WARN on stderr) ---
rm -f "$_T50_CS"
_t50_rc=0
_t50_out=$(PLANGATE_HOOK_TASK=TASK-TA50 sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
if [ "$_t50_rc" = "0" ] && printf '%s' "$_t50_out" | grep -q 'WARN.*not found'; then
  t50_pass "TC-02: current-state.md missing -> WARN + exit 0"
else
  t50_fail "TC-02: expected WARN+exit0, got rc=$_t50_rc out=$_t50_out"
fi

# --- TC-03: fresh current-state.md, no PENDING-VERIFY -> silent ---
printf '# state\n' > "$_T50_CS"
_t50_rc=0
_t50_out=$(PLANGATE_HOOK_TASK=TASK-TA50 sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
if [ "$_t50_rc" = "0" ] && [ -z "$_t50_out" ]; then
  t50_pass "TC-03: fresh current-state.md -> silent exit 0"
else
  t50_fail "TC-03: expected silent, got rc=$_t50_rc out=$_t50_out"
fi

# --- TC-04: stale current-state.md (via PLANGATE_TEST_MODE/NOW) -> warn ---
_t50_rc=0
_t50_out=$(PLANGATE_HOOK_TASK=TASK-TA50 PLANGATE_TEST_MODE=1 PLANGATE_TEST_NOW=$(( $(date -u +%s) + 20000 )) sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
if [ "$_t50_rc" = "0" ] && printf '%s' "$_t50_out" | grep -q 'WARN.*last updated'; then
  t50_pass "TC-04: stale current-state.md -> WARN + exit 0"
else
  t50_fail "TC-04: expected stale WARN, got rc=$_t50_rc out=$_t50_out"
fi

# --- TC-05: PENDING-VERIFY marker present -> warn ---
printf '# state\nPENDING-VERIFY: unverified merge claim\n' > "$_T50_CS"
_t50_rc=0
_t50_out=$(PLANGATE_HOOK_TASK=TASK-TA50 sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
if [ "$_t50_rc" = "0" ] && printf '%s' "$_t50_out" | grep -q 'WARN.*PENDING-VERIFY'; then
  t50_pass "TC-05: PENDING-VERIFY marker -> WARN + exit 0"
else
  t50_fail "TC-05: expected PENDING-VERIFY WARN, got rc=$_t50_rc out=$_t50_out"
fi

# --- TC-06: block opt-in (PLANGATE_PRECOMPACT_BLOCK=1) with a warn condition -> exit 2 ---
_t50_rc=0
_t50_out=$(PLANGATE_HOOK_TASK=TASK-TA50 PLANGATE_PRECOMPACT_BLOCK=1 sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
if [ "$_t50_rc" = "2" ] && printf '%s' "$_t50_out" | grep -q 'BLOCK'; then
  t50_pass "TC-06: block opt-in -> exit 2 + BLOCK message"
else
  t50_fail "TC-06: expected exit2+BLOCK, got rc=$_t50_rc out=$_t50_out"
fi

# --- TC-06b (FAIL-direction control): block opt-in with clean state -> exit 0 (no false block) ---
printf '# state\n' > "$_T50_CS"
_t50_rc=0
_t50_out=$(PLANGATE_HOOK_TASK=TASK-TA50 PLANGATE_PRECOMPACT_BLOCK=1 sh "$_T50_HOOK" 2>&1) || _t50_rc=$?
if [ "$_t50_rc" = "0" ] && [ -z "$_t50_out" ]; then
  t50_pass "TC-06b: block opt-in with clean state -> no false block"
else
  t50_fail "TC-06b: expected exit0 silent, got rc=$_t50_rc out=$_t50_out"
fi

# --- syntax check of the staged hook itself ---
if sh -n "$_T50_SRC" 2>/dev/null; then
  t50_pass "TC-07: scripts/precompact-memory-guard.sh syntax OK (sh -n)"
else
  t50_fail "TC-07: scripts/precompact-memory-guard.sh syntax error"
fi

rm -rf "$_T50_TMP" 2>/dev/null || true
