#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-105 — independent R1 artifact-attestation verifier crypto slice (#1468).

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
pg_extra_contract_init ta-105-runtime-evidence-independent-attestation-verifier standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T105_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T105_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T105_AI_LOOP="$_T105_ROOT/scripts/ai-loop"
_T105_PY="${PLANGATE_PYTHON:-python3}"
_T105_IMPL="$_T105_AI_LOOP/runtime_evidence_independent_attestation_verifier.py"
_T105_GH="$_T105_AI_LOOP/gh_exec.py"
_T105_PROPOSAL="$_T105_ROOT/docs/working/_runtime-attestation/r1-independent-attestation-verifier.proposed.json"

printf 'TA-105: independent R1 attestation verifier crypto slice (#1468)\n'

_t105_tmp=$(mktemp -d)
register_cleanup "$_t105_tmp"
_t105_unit="$_t105_tmp/unit.log"
_t105_rc=0
"$_T105_PY" "$_T105_AI_LOOP/test_runtime_evidence_independent_attestation_verifier.py" >"$_t105_unit" 2>&1 || _t105_rc=$?
_t105_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t105_unit" | head -1)
[ -n "$_t105_n" ] || _t105_n=0
if [ "$_t105_rc" -eq 0 ] && [ "$_t105_n" -gt 0 ] && grep -q '^OK' "$_t105_unit"; then
  printf '  [PASS] unit: independent verifier suite passed (%s tests)\n' "$_t105_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: independent verifier suite failed (rc=%s ran=%s)\n' "$_t105_rc" "$_t105_n" >&2
  sed 's/^/    /' "$_t105_unit" >&2
  fail=$((fail + 1))
fi

if grep -q 'name="attestation verify"' "$_T105_GH" \
  && grep -q '"--deny-self-hosted-runners"' "$_T105_GH" \
  && grep -q '"--signer-workflow"' "$_T105_GH" \
  && grep -q '"--source-digest"' "$_T105_GH"; then
  printf '  [PASS] execution boundary: strict attestation verify allowlist declared\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] execution boundary: attestation verify policy incomplete\n' >&2
  fail=$((fail + 1))
fi

if ! grep -Eq '^[[:space:]]*(import subprocess|from subprocess import)' "$_T105_IMPL" \
  && grep -q '^import gh_exec' "$_T105_IMPL"; then
  printf '  [PASS] execution boundary: verifier uses gh_exec only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] execution boundary: direct subprocess path detected\n' >&2
  fail=$((fail + 1))
fi

if grep -q '"gh_attestation_cli_execution_verified": True' "$_T105_IMPL" \
  && grep -q '"attestation_signature_cryptographically_verified": True' "$_T105_IMPL" \
  && grep -q '"independent_admin_boundary_verified": False' "$_T105_IMPL" \
  && grep -q '"independent_verifier_execution_attested": False' "$_T105_IMPL" \
  && grep -q '"runtime_probe_attestation_verified": False' "$_T105_IMPL" \
  && grep -q '"dispatch_ready": False' "$_T105_IMPL" \
  && grep -q '"dispatch_allowed": False' "$_T105_IMPL"; then
  printf '  [PASS] promotion split: crypto true does not imply admin/runtime authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] promotion split: authority separation missing\n' >&2
  fail=$((fail + 1))
fi

if [ -f "$_T105_PROPOSAL" ] \
  && grep -q '"external_admin_boundary_is_separate_gate": true' "$_T105_PROPOSAL" \
  && grep -q '"statement_predicate_is_not_authority": true' "$_T105_PROPOSAL"; then
  printf '  [PASS] proposal: independent-admin and predicate trust boundaries declared\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: trust-boundary declaration missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
