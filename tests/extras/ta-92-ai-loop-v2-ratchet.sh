#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-92 — ai-loop V2 verification-skipped Ratchet vertical slice (#1381).

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
pg_extra_contract_init ta-92-ai-loop-v2-ratchet standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T89_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T89_ROOT="${_pg_extra_dir%/tests/extras}"
fi

printf 'TA-92: ai-loop V2 Ratchet verification-skipped vertical slice\n'

if _T89_OUT=$(python3 "$_T89_ROOT/scripts/ai-loop-v2/test_ratchet.py" 2>&1); then
  printf '%s\n' "$_T89_OUT"
  printf '  [PASS] provenance / trust-boundary / paired-eval / promotion tests\n'
  pass=$((pass + 1))
else
  _T89_RC=$?
  printf '%s\n' "$_T89_OUT" >&2
  printf '  [FAIL] Ratchet tests failed (rc=%s)\n' "$_T89_RC" >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
