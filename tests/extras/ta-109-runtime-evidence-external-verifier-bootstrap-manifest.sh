#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-109 — external verifier bootstrap bytes are content-addressed without authority promotion (#1473).

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
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-109-runtime-evidence-external-verifier-bootstrap-manifest standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T109_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T109_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T109_AI_LOOP="$_T109_ROOT/scripts/ai-loop"
_T109_IMPL="$_T109_AI_LOOP/runtime_evidence_external_verifier_bootstrap_manifest.py"
_T109_TEST="$_T109_AI_LOOP/test_runtime_evidence_external_verifier_bootstrap_manifest.py"
_T109_PACKAGE="$_T109_ROOT/docs/working/_runtime-attestation/external-verifier-bootstrap"
_T109_PROPOSAL="$_T109_ROOT/docs/working/_runtime-attestation/r1-external-verifier-bootstrap-manifest.proposed.json"

printf 'TA-109: external verifier bootstrap manifest candidate (#1473)\n'

_t109_tmp=$(mktemp -d)
register_cleanup "$_t109_tmp"

_t109_unit="$_t109_tmp/unit.log"
_t109_rc=0
python3 "$_T109_TEST" >"$_t109_unit" 2>&1 || _t109_rc=$?
_t109_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t109_unit" | head -1)
[ -n "$_t109_n" ] || _t109_n=0
if [ "$_t109_rc" -eq 0 ] && [ "$_t109_n" -gt 0 ] && grep -q '^OK' "$_t109_unit"; then
  printf '  [PASS] unit: bootstrap manifest negative controls execute (%s tests)\n' "$_t109_n"; pass=$((pass + 1))
else
  printf '  [FAIL] unit: bootstrap manifest tests failed (rc=%s ran=%s)\n' "$_t109_rc" "$_t109_n" >&2; fail=$((fail + 1))
fi

_t109_result="$_t109_tmp/result.json"
_t109_rc=0
python3 "$_T109_IMPL" \
  --repo-root "$_T109_ROOT" \
  --bootstrap-dir "$_T109_PACKAGE" \
  --declared-source-commit 1111111111111111111111111111111111111111 \
  >"$_t109_result" 2>"$_t109_tmp/result.err" || _t109_rc=$?

if [ "$_t109_rc" -eq 0 ] \
  && grep -q '"package_file_count": 4' "$_t109_result" \
  && grep -q '"exact_required_file_set_verified": true' "$_t109_result" \
  && grep -q '"package_bytes_content_addressed_candidate": true' "$_t109_result" \
  && grep -q '"declared_source_commit_bound_candidate": true' "$_t109_result"; then
  printf '  [PASS] binding: exact four-file bootstrap package is content-addressed\n'; pass=$((pass + 1))
else
  printf '  [FAIL] binding: bootstrap manifest generation failed\n' >&2; fail=$((fail + 1))
fi

if grep -q '"bootstrap_contract_semantics_revalidated": false' "$_t109_result" \
  && grep -q '"source_commit_repository_membership_verified": false' "$_t109_result" \
  && grep -q '"external_operator_received_package_verified": false' "$_t109_result" \
  && grep -q '"external_operator_accepted_package_verified": false' "$_t109_result" \
  && grep -q '"independent_admin_boundary_verified": false' "$_t109_result" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t109_result" \
  && grep -q '"human_rollout_decision_verified": false' "$_t109_result" \
  && grep -q '"dispatch_ready": false' "$_t109_result" \
  && grep -q '"dispatch_allowed": false' "$_t109_result"; then
  printf '  [PASS] authority: content binding cannot self-promote trust or dispatch\n'; pass=$((pass + 1))
else
  printf '  [FAIL] authority: fail-closed manifest boundary missing\n' >&2; fail=$((fail + 1))
fi

if grep -q '"must_remain_false"' "$_T109_PROPOSAL" \
  && grep -q '"source_commit_repository_membership_verified"' "$_T109_PROPOSAL" \
  && grep -q '"external_operator_received_package_verified"' "$_T109_PROPOSAL"; then
  printf '  [PASS] proposal: local manifest limits are documented\n'; pass=$((pass + 1))
else
  printf '  [FAIL] proposal: verification limits are incomplete\n' >&2; fail=$((fail + 1))
fi

rm -rf "$_t109_tmp"
unset _t109_tmp _t109_unit _t109_result _t109_rc _t109_n 2>/dev/null || true

pg_extra_contract_finalize
