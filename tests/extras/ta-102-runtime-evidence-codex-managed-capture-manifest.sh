#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-102 — Codex managed same-run capture manifest candidate (#1448).

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
pg_extra_contract_init ta-102-runtime-evidence-codex-managed-capture-manifest standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T102_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T102_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T102_AI_LOOP="$_T102_ROOT/scripts/ai-loop"
_T102_PY="${PLANGATE_PYTHON:-python3}"
_T102_PROPOSAL="$_T102_ROOT/docs/working/_runtime-attestation/codex-r1-managed-capture-manifest.proposed.json"
_T102_IMPL="$_T102_AI_LOOP/runtime_evidence_codex_managed_capture_manifest.py"

printf 'TA-102: Codex managed capture manifest candidate (#1448)\n'

_t102_tmp=$(mktemp -d)
register_cleanup "$_t102_tmp"

_t102_unit="$_t102_tmp/unit.log"
_t102_rc=0
"$_T102_PY" "$_T102_AI_LOOP/test_runtime_evidence_codex_managed_capture_manifest.py" >"$_t102_unit" 2>&1 || _t102_rc=$?
_t102_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t102_unit" | head -1)
[ -n "$_t102_n" ] || _t102_n=0
if [ "$_t102_rc" -eq 0 ] && [ "$_t102_n" -gt 0 ] && grep -q '^OK' "$_t102_unit"; then
  printf '  [PASS] unit: managed capture manifest suite passed (%s tests)\n' "$_t102_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: managed capture manifest suite failed (rc=%s ran=%s)\n' "$_t102_rc" "$_t102_n" >&2
  sed 's/^/    /' "$_t102_unit" >&2
  fail=$((fail + 1))
fi

if [ -f "$_T102_PROPOSAL" ] \
  && grep -q '"managed_hook_sources_include_requirements_toml": true' "$_T102_PROPOSAL" \
  && grep -q '"allow_managed_hooks_only_skips_non_managed_sources": true' "$_T102_PROPOSAL" \
  && grep -q '"production_manifest_builder_in_repository": false' "$_T102_PROPOSAL" \
  && grep -q '"managed_hook_root_attested"' "$_T102_PROPOSAL" \
  && grep -q '"runtime_probe_attestation_verified"' "$_T102_PROPOSAL" \
  && grep -q '"dispatch_allowed"' "$_T102_PROPOSAL"; then
  printf '  [PASS] proposal: managed capture stays candidate-only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: managed capture trust boundary incomplete\n' >&2
  fail=$((fail + 1))
fi

if ! grep -Eq 'add_parser\("(create|build|dispatch|attest|approve|merge|deploy)"\)' "$_T102_IMPL" \
  && ! grep -Eq 'def (create|build)_manifest\(' "$_T102_IMPL"; then
  printf '  [PASS] CLI boundary: verifier cannot self-create authority evidence\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI boundary: authority/self-manifest creation path detected\n' >&2
  fail=$((fail + 1))
fi

if grep -q '"managed_hook_source_runtime_verified": False' "$_T102_IMPL" \
  && grep -q '"manifest_signature_verified": False' "$_T102_IMPL" \
  && grep -q '"managed_hook_root_attested": False' "$_T102_IMPL" \
  && grep -q '"same_run_identity_verified": False' "$_T102_IMPL" \
  && grep -q '"runtime_probe_attestation_verified": False' "$_T102_IMPL" \
  && grep -q '"dispatch_allowed": False' "$_T102_IMPL"; then
  printf '  [PASS] non-promotion: trust/dispatch authority remains false\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] non-promotion: required false authority field missing\n' >&2
  fail=$((fail + 1))
fi

_t102_guard="$(sed -n '1,10p' "$_T102_IMPL")"
if printf '%s\n' "$_t102_guard" | grep -q 'PG-SH-GUARD (#1169)' \
  && printf '%s\n' "$_t102_guard" | grep -q 'Use: python3'; then
  printf '  [PASS] guard: canonical polyglot guard present\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] guard: canonical polyglot guard missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
