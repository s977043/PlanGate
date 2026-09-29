#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-88 — ai-loop V2 owner-backed Delivery runtime (#1391/#1392/#1393/#1395).

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
pg_extra_contract_init ta-88-ai-loop-v2-owner-backed-delivery standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T88_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T88_ROOT="${_pg_extra_dir%/tests/extras}"
fi

printf 'TA-88: ai-loop V2 owner-backed Delivery runtime\n'

if _T88_OUT=$(python3 "$_T88_ROOT/scripts/ai-loop-v2/test_delivery_v2.py" 2>&1); then
  printf '%s\n' "$_T88_OUT"
  printf '  [PASS] owner-backed event/state/decision/E2E tests\n'
  pass=$((pass + 1))
else
  _T88_RC=$?
  printf '%s\n' "$_T88_OUT" >&2
  printf '  [FAIL] owner-backed tests failed (rc=%s)\n' "$_T88_RC" >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
