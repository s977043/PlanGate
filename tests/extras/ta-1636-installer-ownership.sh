#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Issue #1636: run isolated direct-install ownership regressions.
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-1636-installer-ownership standalone-capable
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi
if [ "$_pg_extra_mode" = harness ]; then
  _T1636_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T1636_ROOT="${_pg_extra_dir%/tests/extras}"
fi
if ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip 'python3 required'
  return 0
fi
if PLANGATE_TEST_INSTALLER="$_T1636_ROOT/install.sh" python3 "$_T1636_ROOT/tests/test_installer_ownership.py"; then
  printf '  [PASS] installer ownership fixture\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] installer ownership fixture\n' >&2
  fail=$((fail + 1))
fi
pg_extra_contract_finalize
