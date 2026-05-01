# tests/extras/ta-06-hooks.sh
# Sourced by tests/run-tests.sh
# Issue #170 で run-tests.sh から分離

printf '\n=== TA-06: hooks (Issue #157) ===\n'

HOOK_TESTS_SCRIPT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/hooks/run-tests.sh"
if [ -f "$HOOK_TESTS_SCRIPT" ]; then
  if sh "$HOOK_TESTS_SCRIPT" >/dev/null 2>&1; then
    printf '[PASS] tests/hooks/run-tests.sh — all hook unit tests\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] tests/hooks/run-tests.sh — see "sh tests/hooks/run-tests.sh" output\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] tests/hooks/run-tests.sh not found\n'
fi
