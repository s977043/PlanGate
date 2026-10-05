#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-110 — external verifier provenance candidate (#1468 / #1473).

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
pg_extra_contract_init ta-110-runtime-evidence-external-verifier-provenance standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T110_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T110_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T110_AI_LOOP="$_T110_ROOT/scripts/ai-loop"
_T110_PY="${PLANGATE_PYTHON:-python3}"
_T110_IMPL="$_T110_AI_LOOP/runtime_evidence_external_verifier_provenance.py"
_T110_TEST="$_T110_AI_LOOP/test_runtime_evidence_external_verifier_provenance.py"
_T110_PROPOSAL="$_T110_ROOT/docs/working/_runtime-attestation/r1-external-verifier-provenance.proposed.json"

printf 'TA-110: external verifier provenance candidate (#1468 / #1473)\n'

_t107_tmp=$(mktemp -d)
register_cleanup "$_t107_tmp"
_t107_unit="$_t107_tmp/unit.log"
_t107_rc=0
"$_T110_PY" "$_T110_TEST" >"$_t107_unit" 2>&1 || _t107_rc=$?
_t107_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t107_unit" | head -1)
[ -n "$_t107_n" ] || _t107_n=0
if [ "$_t107_rc" -eq 0 ] && [ "$_t107_n" -gt 0 ] && grep -q '^OK' "$_t107_unit"; then
  printf '  [PASS] unit: external verifier provenance suite passed (%s tests)\n' "$_t107_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: external verifier provenance suite failed (rc=%s ran=%s)\n' "$_t107_rc" "$_t107_n" >&2
  sed 's/^/    /' "$_t107_unit" >&2
  fail=$((fail + 1))
fi

if ! grep -Eq '^[[:space:]]*(import subprocess|from subprocess import|import gh_exec|from gh_exec import)' "$_T110_IMPL"; then
  printf '  [PASS] execution boundary: provenance validator spawns no process\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] execution boundary: unexpected process or gh execution path\n' >&2
  fail=$((fail + 1))
fi

if grep -q '"same_challenge_replay_prevented": False' "$_T110_IMPL" \
  && grep -q '"provenance_receipt_signature_verified": False' "$_T110_IMPL" \
  && grep -q '"crypto_verifier_binary_verified": False' "$_T110_IMPL" \
  && grep -q '"github_actions_oidc_issuer_bound_candidate": True' "$_T110_IMPL" \
  && grep -q '"independent_admin_boundary_verified": False' "$_T110_IMPL" \
  && grep -q '"runtime_probe_attestation_verified": False' "$_T110_IMPL" \
  && grep -q '"dispatch_allowed": False' "$_T110_IMPL"; then
  printf '  [PASS] non-promotion: provenance/authority remains candidate-only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] non-promotion: required false field missing\n' >&2
  fail=$((fail + 1))
fi

if [ -f "$_T110_PROPOSAL" ] \
  && grep -q '"immutable_verifier_identity_binding_candidate"' "$_T110_PROPOSAL" \
  && grep -q '"same_challenge_replay_prevented": false' "$_T110_PROPOSAL" \
  && grep -q '"independent_admin_boundary_verified": false' "$_T110_PROPOSAL"; then
  printf '  [PASS] proposal: immutable identity is not independent-admin proof\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: trust boundary incomplete\n' >&2
  fail=$((fail + 1))
fi

_t107_guard="$(sed -n '1,10p' "$_T110_IMPL")"
if printf '%s\n' "$_t107_guard" | grep -q 'PG-SH-GUARD (#1169)' \
  && printf '%s\n' "$_t107_guard" | grep -q 'Use: python3'; then
  printf '  [PASS] guard: canonical polyglot guard present\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] guard: canonical polyglot guard missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
