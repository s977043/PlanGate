#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-113 — P0 external-verifier boundary decision packet stays Human-owned (#1473).

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-113-runtime-evidence-external-verifier-decision-packet standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T113_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T113_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T113_ADR="$_T113_ROOT/docs/decisions/adr-007-external-runtime-verifier-boundary.md"

printf 'TA-113: external verifier P0 decision packet (#1473)\n'

if [ -f "$_T113_ADR" ] \
  && grep -Fq '**Status**: Proposed' "$_T113_ADR" \
  && grep -Fq '**Decision Makers**: Human / external-boundary administrator — UNASSIGNED' "$_T113_ADR" \
  && grep -Fq 'Decision state: NOT_MADE' "$_T113_ADR"; then
  printf '  [PASS] ownership: ADR remains Proposed and Human-owned\n'; pass=$((pass + 1))
else
  printf '  [FAIL] ownership: Proposed/Human-owned decision state missing\n' >&2; fail=$((fail + 1))
fi

_t113_placeholders=0
for _t113_key in external_verifier_location external_verifier_admin nonce_ledger_owner trusted_issuer; do
  if grep -Fq "$_t113_key = UNDECIDED" "$_T113_ADR"; then
    _t113_placeholders=$((_t113_placeholders + 1))
  fi
done
if [ "$_t113_placeholders" -eq 4 ]; then
  printf '  [PASS] decision fields: all four Human-owned values remain undecided\n'; pass=$((pass + 1))
else
  printf '  [FAIL] decision fields: expected 4 UNDECIDED values, found %s\n' "$_t113_placeholders" >&2; fail=$((fail + 1))
fi

if grep -Fq 'AI/automation MUST NOT satisfy items 1–6 on behalf of the Human owner.' "$_T113_ADR" \
  && grep -Fq 'External provisioning may start only after this ADR is `Accepted` by a Human' "$_T113_ADR"; then
  printf '  [PASS] activation: automation cannot accept or provision before Human decision\n'; pass=$((pass + 1))
else
  printf '  [FAIL] activation: Human acceptance gate is incomplete\n' >&2; fail=$((fail + 1))
fi

if grep -Fq '### Option C: Another PlanGate-local workflow or repository-authored verifier' "$_T113_ADR" \
  && grep -A 12 -F '### Option C:' "$_T113_ADR" | grep -Fq '**Decision status**: REJECTED.' \
  && grep -Fq '### Option D: Separate repository without separate administration' "$_T113_ADR"; then
  printf '  [PASS] independence: local/self-administered substitutes are rejected\n'; pass=$((pass + 1))
else
  printf '  [FAIL] independence: rejected self-attestation options not explicit\n' >&2; fail=$((fail + 1))
fi

_t113_false=0
for _t113_field in \
  admin_evidence_independently_verified \
  nonce_one_time_consumption_verified \
  independent_admin_boundary_verified \
  independent_verifier_execution_attested \
  runtime_probe_attestation_verified \
  human_rollout_decision_verified \
  dispatch_ready \
  dispatch_allowed
do
  if grep -Fq "$_t113_field = false" "$_T113_ADR"; then
    _t113_false=$((_t113_false + 1))
  fi
done
if [ "$_t113_false" -eq 8 ]; then
  printf '  [PASS] authority: decision packet promotes no trust or dispatch field\n'; pass=$((pass + 1))
else
  printf '  [FAIL] authority: expected 8 fail-closed fields, found %s\n' "$_t113_false" >&2; fail=$((fail + 1))
fi

if grep -Fq 'The `Proposed` ADR itself is planning material. It is not external Evidence.' "$_T113_ADR" \
  && grep -Fq 'Future reviewers can distinguish "decision recorded" from "independence proven".' "$_T113_ADR"; then
  printf '  [PASS] evidence boundary: decision record is not independence proof\n'; pass=$((pass + 1))
else
  printf '  [FAIL] evidence boundary: decision-vs-proof distinction missing\n' >&2; fail=$((fail + 1))
fi

unset _t113_key _t113_placeholders _t113_field _t113_false 2>/dev/null || true

pg_extra_contract_finalize
