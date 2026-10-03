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

_T95_RC=0
_T95_OUT=$(python3 "$_T95_ROOT/tests/test_certification_shadow_spec.py" 2>&1) || _T95_RC=$?
printf '%s\n' "$_T95_OUT"

if [ "$_T95_RC" -ne 0 ]; then
  printf '  [FAIL] certification shadow spec failed (rc=%s)\n' "$_T95_RC" >&2
  fail=$((fail + 1))
elif printf '%s\n' "$_T95_OUT" | grep -Eq '^Ran [1-9][0-9]* tests? in '; then
  printf '  [PASS] certification shadow executable spec ran non-zero tests\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] certification shadow spec reported no non-zero test count\n' >&2
  fail=$((fail + 1))
fi

# Mode A must remain tests-only. Production paths must not import the test spec.
_t95_prod_refs() {
  git -C "$1" grep -lF 'test_certification_shadow_spec' -- 'scripts' 'bin' 2>/dev/null || true
}

_T95_PROBE=$(mktemp -d)
mkdir -p "$_T95_PROBE/scripts" "$_T95_PROBE/bin"
git -C "$_T95_PROBE" init -q
printf 'import test_certification_shadow_spec\n' >"$_T95_PROBE/scripts/leak.py"
printf 'print("ok")\n' >"$_T95_PROBE/scripts/ok.py"
printf '#!/bin/sh\nexit 0\n' >"$_T95_PROBE/bin/ok"
git -C "$_T95_PROBE" add scripts bin
_T95_PROBE_GOT=$(_t95_prod_refs "$_T95_PROBE")
rm -rf "$_T95_PROBE"

if [ "$_T95_PROBE_GOT" = "scripts/leak.py" ]; then
  printf '  [PASS] production-reference detector positive control\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] production-reference detector missed planted leak: %s\n' "$_T95_PROBE_GOT" >&2
  fail=$((fail + 1))
fi

_T95_GOT=$(_t95_prod_refs "$_T95_ROOT")
if [ -n "$_T95_GOT" ]; then
  printf '  [FAIL] production path imports/references certification test spec:\n%s\n' "$_T95_GOT" >&2
  fail=$((fail + 1))
else
  printf '  [PASS] certification spec is not imported by production paths\n'
  pass=$((pass + 1))
fi

pg_extra_contract_finalize
