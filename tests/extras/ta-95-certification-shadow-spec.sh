#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-95 — Certification View non-authoritative executable spec (#1460).

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _T95_MODE=harness
  _T95_DIR="$EXTRAS_DIR"
else
  _T95_MODE=standalone
  _T95_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi

_T95_HELPER="$_T95_DIR/_extra-contract.sh"
if [ ! -r "$_T95_HELPER" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_T95_HELPER" >&2
  if [ "$_T95_MODE" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi

. "$_T95_HELPER"
pg_extra_contract_init ta-95-certification-shadow-spec standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_T95_MODE" = harness ]; then
  _T95_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T95_ROOT="${_T95_DIR%/tests/extras}"
fi

printf 'TA-95: Certification View executable specification\n'

if _T95_OUT=$(python3 "$_T95_ROOT/tests/test_certification_shadow_spec.py" 2>&1); then
  printf '%s\n' "$_T95_OUT"
  printf '  [PASS] certification shadow executable spec\n'
  pass=$((pass + 1))
else
  _T95_RC=$?
  printf '%s\n' "$_T95_OUT" >&2
  printf '  [FAIL] certification shadow spec failed (rc=%s)\n' "$_T95_RC" >&2
  fail=$((fail + 1))
fi

# Mode A must remain tests-only. Production paths must not import the test spec.
if git -C "$_T95_ROOT" grep -lF 'test_certification_shadow_spec' -- 'scripts' 'bin' >/dev/null 2>&1; then
  printf '  [FAIL] production path imports/references certification test spec\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] certification spec is not imported by production paths\n'
  pass=$((pass + 1))
fi

pg_extra_contract_finalize
