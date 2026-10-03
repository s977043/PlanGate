#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-98 — external trust boundary for pre-PBI R1 (#1448).
#
# Proves:
# - live GitHub owner comments are only owner-account candidates, not Human authority;
# - existing Claude canary is a reusable pattern but not request-bound attestation;
# - dispatch remains false;
# - no dispatch/execute CLI switch exists.

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
pg_extra_contract_init ta-98-runtime-evidence-external-trust standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T98_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T98_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T98_AI_LOOP="$_T98_ROOT/scripts/ai-loop"
_T98_PY="${PLANGATE_PYTHON:-python3}"

printf 'TA-98: external trust boundary for pre-PBI R1 (#1448)\n'

_t98_tmp=$(mktemp -d)
register_cleanup "$_t98_tmp"

# 1. Unit suite must execute.
_t98_unit="$_t98_tmp/unit.log"
_t98_rc=0
"$_T98_PY" "$_T98_AI_LOOP/test_runtime_evidence_external_trust.py" >"$_t98_unit" 2>&1 || _t98_rc=$?
_t98_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t98_unit" | head -1)
[ -n "$_t98_n" ] || _t98_n=0

if [ "$_t98_rc" -eq 0 ] && [ "$_t98_n" -gt 0 ] && grep -q '^OK' "$_t98_unit"; then
  printf '  [PASS] unit: external trust suite passed (%s tests)\n' "$_t98_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: external trust suite failed (rc=%s ran=%s)\n' "$_t98_rc" "$_t98_n" >&2
  sed 's/^/    /' "$_t98_unit" >&2
  fail=$((fail + 1))
fi

# 2. Current canary pattern must remain explicitly insufficient for request-bound attestation.
_t98_gap="$_t98_tmp/gap.json"
_t98_req="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
_t98_cfg="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

_t98_rc=0
"$_T98_PY" "$_T98_AI_LOOP/runtime_evidence_external_trust.py" attestation-gap \
  --request-hash "$_t98_req" \
  --config-sha "$_t98_cfg" \
  >"$_t98_gap" 2>"$_t98_tmp/gap.err" || _t98_rc=$?

if [ "$_t98_rc" -eq 0 ] \
  && grep -q '"request_bound_runtime_attestation_available": false' "$_t98_gap" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t98_gap" \
  && grep -q '"dispatch_ready": false' "$_t98_gap" \
  && grep -q '"dispatch_allowed": false' "$_t98_gap" \
  && grep -q '"agent_invoke_allowed": false' "$_t98_gap"; then
  printf '  [PASS] attestation gap: existing canary pattern cannot self-promote R1\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] attestation gap: current canary was incorrectly promoted (rc=%s)\n' "$_t98_rc" >&2
  sed 's/^/    /' "$_t98_tmp/gap.err" >&2
  fail=$((fail + 1))
fi

# 3. Source must explicitly preserve the GitHub owner-comment limitation.
if grep -q '"human_rollout_decision_verified": False' "$_T98_AI_LOOP/runtime_evidence_external_trust.py" \
  && grep -q 'cannot distinguish Web UI human action' "$_T98_AI_LOOP/runtime_evidence_external_trust.py" \
  && grep -q 'app-authored comments cannot grant Human rollout authority' "$_T98_AI_LOOP/runtime_evidence_external_trust.py"; then
  printf '  [PASS] Human boundary: owner-account comment remains candidate-only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] Human boundary: owner-comment limitation is missing\n' >&2
  fail=$((fail + 1))
fi

# 4. CLI must expose no dispatch/execute/approval-write path.
if ! grep -Eq -- '--(dispatch|execute|invoke-agent|enable-r1|write-approval|merge|deploy)' \
  "$_T98_AI_LOOP/runtime_evidence_external_trust.py"; then
  printf '  [PASS] CLI boundary: external trust verifier exposes no dispatch/mutation switch\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI boundary: dispatch/mutation switch detected\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finish
