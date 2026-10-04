#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-107 — external admin boundary admission candidate (#1473).

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
pg_extra_contract_init ta-107-runtime-evidence-external-admin-admission standalone-capable

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
_T107_IMPL="$_T107_AI_LOOP/runtime_evidence_external_admin_admission.py"
_T107_TEST="$_T107_AI_LOOP/test_runtime_evidence_external_admin_admission.py"
_T107_PROPOSAL="$_T107_ROOT/docs/working/_runtime-attestation/r1-external-admin-admission.proposed.json"

printf 'TA-107: external admin boundary admission candidate (#1473)\n'

_t107_tmp=$(mktemp -d)
register_cleanup "$_t107_tmp"
_t107_unit="$_t107_tmp/unit.log"
_t107_rc=0
"$_T107_PY" "$_T107_TEST" >"$_t107_unit" 2>&1 || _t107_rc=$?
_t107_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t107_unit" | head -1)
[ -n "$_t107_n" ] || _t107_n=0
if [ "$_t107_rc" -eq 0 ] && [ "$_t107_n" -gt 0 ] && grep -q '^OK' "$_t107_unit"; then
  printf '  [PASS] unit: external admin admission suite passed (%s tests)\n' "$_t107_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: external admin admission suite failed (rc=%s ran=%s)\n' "$_t107_rc" "$_t107_n" >&2
  sed 's/^/    /' "$_t107_unit" >&2
  fail=$((fail + 1))
fi

if ! grep -Eq '^[[:space:]]*(import subprocess|from subprocess import)' "$_T107_IMPL" \
  && grep -q 'PLANGATE_REPO = "s977043/PlanGate"' "$_T107_IMPL"; then
  printf '  [PASS] boundary: no process execution and PlanGate self-signer is explicit\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] boundary: process path or repository identity drift detected\n' >&2
  fail=$((fail + 1))
fi

if grep -q '"signer_repo_structurally_separate_candidate": True' "$_T107_IMPL" \
  && grep -q '"admin_evidence_refs_content_addressed_candidate": True' "$_T107_IMPL" \
  && grep -q '"admin_evidence_independently_verified": False' "$_T107_IMPL" \
  && grep -q '"independent_admin_boundary_verified": False' "$_T107_IMPL" \
  && grep -q '"runtime_probe_attestation_verified": False' "$_T107_IMPL" \
  && grep -q '"human_rollout_decision_verified": False' "$_T107_IMPL" \
  && grep -q '"dispatch_ready": False' "$_T107_IMPL" \
  && grep -q '"dispatch_allowed": False' "$_T107_IMPL"; then
  printf '  [PASS] promotion split: structural admission cannot self-prove independence\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] promotion split: external-admin authority drift detected\n' >&2
  fail=$((fail + 1))
fi

if [ -f "$_T107_PROPOSAL" ] \
  && grep -q '"self_hosted_runner_denied": true' "$_T107_PROPOSAL" \
  && grep -q '"admin_evidence_independently_verified"' "$_T107_PROPOSAL" \
  && grep -q '"independent_admin_boundary_verified"' "$_T107_PROPOSAL" \
  && grep -q '"dispatch_allowed"' "$_T107_PROPOSAL"; then
  printf '  [PASS] proposal: admission and non-promotion contract documented\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: external-admin admission contract missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
