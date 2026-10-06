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

_t113_status=$(sed -n 's/^\*\*Status\*\*: \([^ ]*\).*/\1/p' "$_T113_ADR" | head -1)
_t113_record=$(sed -n '/^### Human Decision Record$/,/^### Decision-state transition contract$/p' "$_T113_ADR")
_t113_record_fields=0
_t113_undecided=0
for _t113_key in \
  selected_option \
  external_verifier_location \
  external_verifier_admin \
  nonce_ledger_owner \
  trusted_issuer \
  decision_recorded_by \
  decision_recorded_at \
  decision_evidence_ref
do
  _t113_value=$(printf '%s\n' "$_t113_record" | sed -n "s/^${_t113_key} = //p" | head -1)
  if [ -n "$_t113_value" ]; then
    _t113_record_fields=$((_t113_record_fields + 1))
    if [ "$_t113_value" = "UNDECIDED" ]; then
      _t113_undecided=$((_t113_undecided + 1))
    fi
  fi
done

_t113_state_ok=0
case "$_t113_status" in
  Proposed)
    if grep -Fq '**Decision Makers**: Human / external-boundary administrator — UNASSIGNED' "$_T113_ADR" \
      && grep -Fq '**Decision state: NOT_MADE.**' "$_T113_ADR" \
      && [ "$_t113_record_fields" -eq 8 ] \
      && [ "$_t113_undecided" -eq 8 ]; then
      _t113_state_ok=1
    fi
    ;;
  Accepted)
    if grep -Fq '**Decision Makers**:' "$_T113_ADR" \
      && ! grep -Fq '**Decision Makers**: Human / external-boundary administrator — UNASSIGNED' "$_T113_ADR" \
      && grep -Fq '**Decision state: RECORDED_BY_HUMAN.**' "$_T113_ADR" \
      && [ "$_t113_record_fields" -eq 8 ] \
      && [ "$_t113_undecided" -eq 0 ]; then
      _t113_state_ok=1
    fi
    ;;
esac

if [ "$_t113_state_ok" -eq 1 ]; then
  printf '  [PASS] ownership: ADR state and Human Decision Record are structurally consistent (%s)\n' "$_t113_status"; pass=$((pass + 1))
else
  printf '  [FAIL] ownership: invalid Proposed/Accepted decision-state combination (%s; fields=%s undecided=%s)\n' \
    "$_t113_status" "$_t113_record_fields" "$_t113_undecided" >&2
  fail=$((fail + 1))
fi

if grep -Fq 'AI/automation MUST NOT satisfy items 1–6 on behalf of the Human owner.' "$_T113_ADR" \
  && grep -Fq 'External provisioning may start only after this ADR is `Accepted` by a Human' "$_T113_ADR" \
  && grep -Fq 'Record has no `UNDECIDED` values.' "$_T113_ADR"; then
  printf '  [PASS] activation: automation cannot accept or provision before Human decision\n'; pass=$((pass + 1))
else
  printf '  [FAIL] activation: Human acceptance gate is incomplete\n' >&2; fail=$((fail + 1))
fi

if grep -Fq '## Evaluation Matrix' "$_T113_ADR" \
  && grep -Fq 'A separate repository name, organization membership, workflow file, or repository-authored statement is' "$_T113_ADR" \
  && grep -Fq '### Option C: Another PlanGate-local workflow or repository-authored verifier' "$_T113_ADR" \
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
  && grep -Fq 'Future reviewers can distinguish "decision recorded" from "independence proven".' "$_T113_ADR" \
  && grep -Fq 'Filling this block records the **choice**; it does not prove the external boundary is already independent.' "$_T113_ADR"; then
  printf '  [PASS] evidence boundary: decision record is not independence proof\n'; pass=$((pass + 1))
else
  printf '  [FAIL] evidence boundary: decision-vs-proof distinction missing\n' >&2; fail=$((fail + 1))
fi

unset _t113_status _t113_record _t113_record_fields _t113_undecided _t113_state_ok \
  _t113_key _t113_value _t113_field _t113_false 2>/dev/null || true

pg_extra_contract_finalize
