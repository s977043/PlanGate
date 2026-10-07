#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-114 — ADR-007 P0 structural preflight stays non-authoritative (#1473).

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
pg_extra_contract_init ta-114-runtime-evidence-external-verifier-p0-preflight standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T114_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T114_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T114_IMPL="$_T114_ROOT/scripts/ai-loop/runtime_evidence_external_verifier_p0_preflight.py"
_T114_TEST="$_T114_ROOT/scripts/ai-loop/test_runtime_evidence_external_verifier_p0_preflight.py"
_T114_DOC="$_T114_ROOT/docs/working/_runtime-attestation/external-verifier-p0-preflight.md"

printf 'TA-114: external verifier P0 structural preflight (#1473)\n'

_t114_tmp=$(mktemp -d)
register_cleanup "$_t114_tmp"

_t114_unit="$_t114_tmp/unit.log"
_t114_rc=0
python3 "$_T114_TEST" >"$_t114_unit" 2>&1 || _t114_rc=$?
_t114_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t114_unit" | head -1)
[ -n "$_t114_n" ] || _t114_n=0
if [ "$_t114_rc" -eq 0 ] && [ "$_t114_n" -ge 8 ] && grep -q '^OK' "$_t114_unit"; then
  printf '  [PASS] unit: P0 transition negative controls execute (%s tests)\n' "$_t114_n"; pass=$((pass + 1))
else
  printf '  [FAIL] unit: P0 preflight tests failed (rc=%s ran=%s)\n' "$_t114_rc" "$_t114_n" >&2; fail=$((fail + 1))
fi

_t114_out="$_t114_tmp/result.json"
_t114_err="$_t114_tmp/result.err"
_t114_rc=0
python3 "$_T114_IMPL" --repo-root "$_T114_ROOT" >"$_t114_out" 2>"$_t114_err" || _t114_rc=$?

if [ "$_t114_rc" -eq 1 ] \
  && grep -q '"adr_status":"Proposed"' "$_t114_out" \
  && grep -q '"decision_state":"NOT_MADE"' "$_t114_out" \
  && grep -q '"decision_record_structurally_valid":true' "$_t114_out" \
  && grep -q '"human_decision_recorded_candidate":false' "$_t114_out" \
  && grep -q '"p1_preflight_candidate":false' "$_t114_out" \
  && grep -q '"state":"blocked_on_human_decision"' "$_t114_out"; then
  printf '  [PASS] current state: Proposed ADR blocks P1 preflight\n'; pass=$((pass + 1))
else
  printf '  [FAIL] current state: expected Proposed/NOT_MADE block (rc=%s)\n' "$_t114_rc" >&2
  cat "$_t114_err" >&2
  fail=$((fail + 1))
fi

_t114_false=0
for _t114_field in \
  human_decision_identity_verified \
  decision_evidence_ref_authenticated \
  external_boundary_provisioned_verified \
  admin_evidence_independently_verified \
  nonce_one_time_consumption_verified \
  independent_admin_boundary_verified \
  independent_verifier_execution_attested \
  runtime_probe_attestation_verified \
  human_rollout_decision_verified \
  dispatch_ready \
  dispatch_allowed
do
  if grep -q "\"$_t114_field\":false" "$_t114_out"; then
    _t114_false=$((_t114_false + 1))
  fi
done
if [ "$_t114_false" -eq 11 ]; then
  printf '  [PASS] authority: P0 preflight promotes no trust/Human/dispatch field\n'; pass=$((pass + 1))
else
  printf '  [FAIL] authority: expected 11 fail-closed fields, found %s\n' "$_t114_false" >&2; fail=$((fail + 1))
fi

if grep -Fq 'without modifying the content-addressed bootstrap package' "$_T114_DOC" \
  && grep -Fq 'The preflight must never be used as administrator-independence Evidence.' "$_T114_DOC"; then
  printf '  [PASS] package boundary: P0 wiring leaves bootstrap bytes untouched\n'; pass=$((pass + 1))
else
  printf '  [FAIL] package boundary: immutable bootstrap / evidence limit missing\n' >&2; fail=$((fail + 1))
fi

rm -rf "$_t114_tmp"
unset _t114_tmp _t114_unit _t114_out _t114_err _t114_rc _t114_n \
  _t114_field _t114_false 2>/dev/null || true

pg_extra_contract_finalize
