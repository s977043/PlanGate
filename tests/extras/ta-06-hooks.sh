# tests/extras/ta-06-hooks.sh
# Sourced by tests/run-tests.sh
# Issue #170 で run-tests.sh から分離

printf '\n=== TA-06: hooks (Issue #157) ===\n'

HOOK_TESTS_SCRIPT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/hooks/run-tests.sh"
if [ -f "$HOOK_TESTS_SCRIPT" ]; then
  _ta06_rc=0
  _ta06_out=$(sh "$HOOK_TESTS_SCRIPT" 2>&1) || _ta06_rc=$?
  if [ "$_ta06_rc" -eq 0 ]; then
    printf '[PASS] tests/hooks/run-tests.sh — all hook unit tests\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] tests/hooks/run-tests.sh (exit %s)\n' "$_ta06_rc"
    printf '%s\n' "$_ta06_out" | tail -20
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] tests/hooks/run-tests.sh not found\n'
fi
