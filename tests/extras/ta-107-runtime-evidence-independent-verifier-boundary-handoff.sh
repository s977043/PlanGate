#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-107 — independent verifier boundary handoff candidate (#1473).

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
pg_extra_contract_init ta-107-runtime-evidence-independent-verifier-boundary-handoff standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T107_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T107_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T107_AI_LOOP="$_T107_ROOT/scripts/ai-loop"
_T107_PY="${PLANGATE_PYTHON:-python3}"
_T107_IMPL="$_T107_AI_LOOP/runtime_evidence_independent_verifier_boundary_handoff.py"
_T107_TEST="$_T107_AI_LOOP/test_runtime_evidence_independent_verifier_boundary_handoff.py"
_T107_PROPOSAL="$_T107_ROOT/docs/working/_runtime-attestation/r1-independent-verifier-boundary-handoff.proposed.json"

printf 'TA-107: independent verifier boundary handoff candidate (#1473)\n'

_t107_tmp=$(mktemp -d)
register_cleanup "$_t107_tmp"
_t107_unit="$_t107_tmp/unit.log"
_t107_rc=0
"$_T107_PY" "$_T107_TEST" >"$_t107_unit" 2>&1 || _t107_rc=$?
_t107_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t107_unit" | head -1)
[ -n "$_t107_n" ] || _t107_n=0
if [ "$_t107_rc" -eq 0 ] && [ "$_t107_n" -gt 0 ] && grep -q '^OK' "$_t107_unit"; then
  printf '  [PASS] unit: boundary handoff suite passed (%s tests)\n' "$_t107_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: boundary handoff suite failed (rc=%s ran=%s)\n' "$_t107_rc" "$_t107_n" >&2
  sed 's/^/    /' "$_t107_unit" >&2
  fail=$((fail + 1))
fi

if grep -q 'PLAN_GATE_REPO = "s977043/PlanGate"' "$_T107_IMPL" \
  && grep -q 'PlanGate-local verifier is not independent' "$_T107_IMPL" \
  && grep -q 'immutable workflow@40hex required' "$_T107_IMPL"; then
  printf '  [PASS] separation: PlanGate-local verifier rejected and workflow is immutable\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] separation contract missing\n' >&2
  fail=$((fail + 1))
fi

if grep -q 'exact boundary subject binding required' "$_T107_IMPL" \
  && grep -q 'PlanGate repository cannot be its own independent admin evidence source' "$_T107_IMPL" \
  && grep -q '"admin_evidence_refs_content_addressed_candidate": True' "$_T107_IMPL" \
  && grep -q '"admin_evidence_authenticated": False' "$_T107_IMPL"; then
  printf '  [PASS] evidence: subject-bound refs stay unauthenticated candidate evidence\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] evidence subject/authentication boundary drift\n' >&2
  fail=$((fail + 1))
fi

if grep -q '"nonce_one_time_contract_candidate": True' "$_T107_IMPL" \
  && grep -q '"nonce_one_time_consumption_verified": False' "$_T107_IMPL" \
  && grep -q '"independent_admin_boundary_verified": False' "$_T107_IMPL" \
  && grep -q '"dispatch_ready": False' "$_T107_IMPL" \
  && grep -q '"dispatch_allowed": False' "$_T107_IMPL"; then
  printf '  [PASS] promotion: declared one-time/admin boundary cannot self-promote\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] promotion boundary drift detected\n' >&2
  fail=$((fail + 1))
fi

if ! grep -Eq '^[[:space:]]*(import subprocess|from subprocess import)' "$_T107_IMPL" \
  && grep -q 'load_raw_bytes(' "$_T107_IMPL"; then
  printf '  [PASS] execution boundary: pure handoff consumer; no process spawn\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] unexpected process-spawn surface\n' >&2
  fail=$((fail + 1))
fi

if [ -f "$_T107_PROPOSAL" ] \
  && grep -q '"different_repository_is_necessary_not_sufficient_for_independence": true' "$_T107_PROPOSAL" \
  && grep -q '"content_addressed_admin_evidence_is_not_authenticated_admin_evidence": true' "$_T107_PROPOSAL" \
  && grep -q '"declared_one_time_nonce_contract_is_not_verified_consumption": true' "$_T107_PROPOSAL"; then
  printf '  [PASS] proposal: external independence gaps remain explicit\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal trust-boundary notes missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
