#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-106 — external verifier receipt nonce/freshness binding candidate (#1468).

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
pg_extra_contract_init ta-106-runtime-evidence-external-verifier-receipt standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T106_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T106_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T106_AI_LOOP="$_T106_ROOT/scripts/ai-loop"
_T106_PY="${PLANGATE_PYTHON:-python3}"
_T106_IMPL="$_T106_AI_LOOP/runtime_evidence_external_verifier_receipt.py"
_T106_TEST="$_T106_AI_LOOP/test_runtime_evidence_external_verifier_receipt.py"
_T106_PROPOSAL="$_T106_ROOT/docs/working/_runtime-attestation/r1-external-verifier-receipt.proposed.json"

printf 'TA-106: external verifier receipt replay/binding candidate (#1468)\n'

_t106_tmp=$(mktemp -d)
register_cleanup "$_t106_tmp"
_t106_unit="$_t106_tmp/unit.log"
_t106_rc=0
"$_T106_PY" "$_T106_TEST" >"$_t106_unit" 2>&1 || _t106_rc=$?
_t106_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t106_unit" | head -1)
[ -n "$_t106_n" ] || _t106_n=0
if [ "$_t106_rc" -eq 0 ] && [ "$_t106_n" -gt 0 ] && grep -q '^OK' "$_t106_unit"; then
  printf '  [PASS] unit: external verifier receipt suite passed (%s tests)\n' "$_t106_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: external verifier receipt suite failed (rc=%s ran=%s)\n' "$_t106_rc" "$_t106_n" >&2
  sed 's/^/    /' "$_t106_unit" >&2
  fail=$((fail + 1))
fi

if grep -q '^import gh_exec' "$_T106_IMPL" \
  && grep -q 'command_candidate.build_verify_args' "$_T106_IMPL" \
  && ! grep -Eq '^[[:space:]]*(import subprocess|from subprocess import)' "$_T106_IMPL"; then
  printf '  [PASS] execution boundary: reuses #1470 strict gh attestation path\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] execution boundary: direct process or duplicate verifier path detected\n' >&2
  fail=$((fail + 1))
fi

if grep -q 'PLANGATE_R1_EXTERNAL_VERIFIER_NONCE' "$_T106_IMPL" \
  && ! grep -q -- '--expected-nonce' "$_T106_IMPL" \
  && grep -q 'MAX_VALIDITY_SECONDS = 15 \* 60' "$_T106_IMPL"; then
  printf '  [PASS] nonce/freshness boundary: nonce is out-of-band and receipt lifetime is bounded\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] nonce/freshness boundary: contract incomplete\n' >&2
  fail=$((fail + 1))
fi

if grep -q '"receipt_candidate_binding_verified": True' "$_T106_IMPL" \
  && grep -q '"receipt_claims_authenticated": False' "$_T106_IMPL" \
  && grep -q '"independent_admin_boundary_verified": False' "$_T106_IMPL" \
  && grep -q '"runtime_probe_attestation_verified": False' "$_T106_IMPL" \
  && grep -q '"human_rollout_decision_verified": False' "$_T106_IMPL" \
  && grep -q '"dispatch_ready": False' "$_T106_IMPL" \
  && grep -q '"dispatch_allowed": False' "$_T106_IMPL"; then
  printf '  [PASS] promotion split: receipt validation cannot self-promote authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] promotion split: authority boundary drift detected\n' >&2
  fail=$((fail + 1))
fi

if [ -f "$_T106_PROPOSAL" ] \
  && grep -q '"receipt_claims_authenticated": false' "$_T106_PROPOSAL" \
  && grep -q '"independent_admin_boundary_verified": false' "$_T106_PROPOSAL" \
  && grep -q '"dispatch_allowed": false' "$_T106_PROPOSAL"; then
  printf '  [PASS] proposal: receipt candidate and authority split documented\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: receipt candidate contract missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
