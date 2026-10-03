# tests/extras/ta-94-pbi-materializer.sh
# Sourced by tests/run-tests.sh.
# TASK-1442 / #1442: AI-generated PBI shadow materializer.
#
# Why this file exists:
#   scripts/ai-loop/test_*.py is NOT automatically executed by tests/run-tests.sh.
#   This extra provides the CI execution path and prevents a "test file exists but never ran"
#   false green.

printf '\n=== TA-94: ai-loop V2 PBI materializer (#1442) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  _T94_STANDALONE=1
  FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
  pass=0
  fail=0
else
  _T94_STANDALONE=0
fi

_T94_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
_T94_AI_LOOP="$_T94_ROOT/scripts/ai-loop"
_T94_PLUGIN="$_T94_ROOT/plugin/plangate/skills/ai-loop-cycle/scripts"
_T94_PY="${PLANGATE_PYTHON:-python3}"

t94_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t94_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_t94_tmp=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_t94_tmp"
fi

# 1. Unit suite must actually execute at least one test and report OK.
_t94_log="$_t94_tmp/unit.log"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/test_pbi_materializer.py" >"$_t94_log" 2>&1 || _t94_rc=$?
_t94_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t94_log" | head -1)
[ -n "$_t94_n" ] || _t94_n=0
if [ "$_t94_rc" -eq 0 ] && [ "$_t94_n" -gt 0 ] && grep -q '^OK' "$_t94_log"; then
  t94_pass "unit: test_pbi_materializer.py (Ran $_t94_n tests / OK)"
else
  t94_fail "unit: test_pbi_materializer.py failed (rc=$_t94_rc ran=$_t94_n): $(tail -5 "$_t94_log" | tr '\n' ' ')"
fi

# 2. Distribution mirror must be byte-identical after sync.
if cmp -s "$_T94_AI_LOOP/pbi_materializer.py" "$_T94_PLUGIN/pbi_materializer.py"   && cmp -s "$_T94_AI_LOOP/test_pbi_materializer.py" "$_T94_PLUGIN/test_pbi_materializer.py"; then
  t94_pass "distribution: source/plugin materializer + test are byte-identical"
else
  t94_fail "distribution: plugin mirror drift detected"
fi

# 3. Existing execution-boundary checker must include the new source tree without violation.
_t94_boundary="$_t94_tmp/boundary.log"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/check_exec_boundary.py" >"$_t94_boundary" 2>&1 || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] && grep -q 'clean' "$_t94_boundary"; then
  t94_pass "execution boundary: clean"
else
  t94_fail "execution boundary: not clean (rc=$_t94_rc): $(tail -3 "$_t94_boundary" | tr '\n' ' ')"
fi

# 4. First slice must remain shadow-only: parser must not expose a write mode.
if grep -q 'choices=("shadow",)' "$_T94_AI_LOOP/pbi_materializer.py"   && ! grep -Eq 'choices=.*write|--write|auto[_-]?write' "$_T94_AI_LOOP/pbi_materializer.py"; then
  t94_pass "rollout boundary: shadow-only CLI; no write mode"
else
  t94_fail "rollout boundary: shadow-only CLI invariant missing"
fi

rm -rf "$_t94_tmp"

if [ "$_T94_STANDALONE" -eq 1 ]; then
  printf 'TA-94 Results: %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
fi
