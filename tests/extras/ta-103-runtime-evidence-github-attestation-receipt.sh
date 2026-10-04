#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-103 — GitHub artifact attestation receipt candidate (#1448).

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
pg_extra_contract_init ta-103-runtime-evidence-github-attestation-receipt standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T103_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T103_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T103_AI_LOOP="$_T103_ROOT/scripts/ai-loop"
_T103_PY="${PLANGATE_PYTHON:-python3}"
_T103_PROPOSAL="$_T103_ROOT/docs/working/_runtime-attestation/github-r1-attestation-receipt.proposed.json"
_T103_IMPL="$_T103_AI_LOOP/runtime_evidence_github_attestation_receipt.py"

printf 'TA-103: GitHub attestation receipt candidate (#1448)\n'

_t103_tmp=$(mktemp -d)
register_cleanup "$_t103_tmp"

_t103_unit="$_t103_tmp/unit.log"
_t103_rc=0
"$_T103_PY" "$_T103_AI_LOOP/test_runtime_evidence_github_attestation_receipt.py" >"$_t103_unit" 2>&1 || _t103_rc=$?
_t103_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t103_unit" | head -1)
[ -n "$_t103_n" ] || _t103_n=0
if [ "$_t103_rc" -eq 0 ] && [ "$_t103_n" -gt 0 ] && grep -q '^OK' "$_t103_unit"; then
  printf '  [PASS] unit: GitHub attestation receipt suite passed (%s tests)\n' "$_t103_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: GitHub attestation receipt suite failed (rc=%s ran=%s)\n' "$_t103_rc" "$_t103_n" >&2
  sed 's/^/    /' "$_t103_unit" >&2
  fail=$((fail + 1))
fi

if [ -f "$_T103_PROPOSAL" ] \
  && grep -q '"statement_predicate_is_workflow_controllable": true' "$_T103_PROPOSAL" \
  && grep -q '"gh_attestation_cli_execution_verified"' "$_T103_PROPOSAL" \
  && grep -q '"attestation_signature_cryptographically_verified"' "$_T103_PROPOSAL" \
  && grep -q '"managed_hook_root_attested"' "$_T103_PROPOSAL" \
  && grep -q '"dispatch_allowed"' "$_T103_PROPOSAL"; then
  printf '  [PASS] proposal: cryptographic promotion boundary declared\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: attestation trust boundary incomplete\n' >&2
  fail=$((fail + 1))
fi

if ! grep -Eq '^[[:space:]]*(import (subprocess|os)|from (subprocess|os) import)' "$_T103_IMPL" \
  && ! grep -Eq '^[[:space:]]*(import gh_exec|from gh_exec import)' "$_T103_IMPL"; then
  printf '  [PASS] execution boundary: parser does not invoke gh/process APIs\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] execution boundary: unexpected process/gh execution path detected\n' >&2
  fail=$((fail + 1))
fi

if grep -q '"statement_predicate_trusted": False' "$_T103_IMPL" \
  && grep -q '"gh_attestation_cli_execution_verified": False' "$_T103_IMPL" \
  && grep -q '"attestation_signature_cryptographically_verified": False' "$_T103_IMPL" \
  && grep -q '"signer_certificate_identity_verified": False' "$_T103_IMPL" \
  && grep -q '"independent_admin_boundary_verified": False' "$_T103_IMPL" \
  && grep -q '"runtime_probe_attestation_verified": False' "$_T103_IMPL" \
  && grep -q '"dispatch_allowed": False' "$_T103_IMPL"; then
  printf '  [PASS] non-promotion: crypto/authority remains false\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] non-promotion: required false field missing\n' >&2
  fail=$((fail + 1))
fi

_t103_guard="$(sed -n '1,10p' "$_T103_IMPL")"
if printf '%s\n' "$_t103_guard" | grep -q 'PG-SH-GUARD (#1169)' \
  && printf '%s\n' "$_t103_guard" | grep -q 'Use: python3'; then
  printf '  [PASS] guard: canonical polyglot guard present\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] guard: canonical polyglot guard missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
