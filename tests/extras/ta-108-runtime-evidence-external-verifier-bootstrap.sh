#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-108 — external verifier bootstrap package remains non-activating (#1473).

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
pg_extra_contract_init ta-108-runtime-evidence-external-verifier-bootstrap standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T108_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T108_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T108_DIR="$_T108_ROOT/docs/working/_runtime-attestation/external-verifier-bootstrap"
_T108_README="$_T108_DIR/README.md"
_T108_WORKFLOW="$_T108_DIR/verifier-workflow.proposed.yml"
_T108_NONCE="$_T108_DIR/nonce-ledger-policy.proposed.json"
_T108_HANDOFF="$_T108_DIR/operator-handoff.proposed.json"

printf 'TA-108: external verifier bootstrap remains proposal-only (#1473)\n'

if [ -f "$_T108_README" ] && [ -f "$_T108_WORKFLOW" ] && [ -f "$_T108_NONCE" ] && [ -f "$_T108_HANDOFF" ]; then
  printf '  [PASS] package: bootstrap handoff files exist\n'; pass=$((pass + 1))
else
  printf '  [FAIL] package: bootstrap handoff files missing\n' >&2; fail=$((fail + 1))
fi

if grep -q 'planGate_install_allowed: false' "$_T108_WORKFLOW" \
  && grep -q 'allowed: false' "$_T108_WORKFLOW" \
  && grep -q '"promotion_allowed": false' "$_T108_NONCE"; then
  printf '  [PASS] activation: package cannot self-authorize PlanGate rollout\n'; pass=$((pass + 1))
else
  printf '  [FAIL] activation: non-activating contract missing\n' >&2; fail=$((fail + 1))
fi

if grep -q 'self_hosted_runner_denied: true' "$_T108_WORKFLOW" \
  && grep -q '"atomic_consume_required": true' "$_T108_NONCE" \
  && grep -q '"durable_consumption_record_required": true' "$_T108_NONCE" \
  && grep -q '"request_hash_binding_required": true' "$_T108_NONCE" \
  && grep -q '"max_validity_seconds": 900' "$_T108_NONCE" \
  && grep -q '"consumption_receipt_content_addressed": true' "$_T108_NONCE" \
  && grep -q '"consumption_receipt_external_storage_required": true' "$_T108_NONCE" \
  && grep -q '"reuse_rejected": true' "$_T108_NONCE"; then
  printf '  [PASS] safety: runner and nonce ledger requirements are explicit\n'; pass=$((pass + 1))
else
  printf '  [FAIL] safety: runner/nonce requirements incomplete\n' >&2; fail=$((fail + 1))
fi

if grep -q 'plangate_repository_write_allowed: false' "$_T108_WORKFLOW" \
  && grep -q 'issue_write_allowed: false' "$_T108_WORKFLOW" \
  && grep -q 'pull_request_write_allowed: false' "$_T108_WORKFLOW" \
  && grep -q 'merge_allowed: false' "$_T108_WORKFLOW" \
  && grep -q 'deploy_allowed: false' "$_T108_WORKFLOW" \
  && grep -q 'bounded_receipt_only: true' "$_T108_WORKFLOW"; then
  printf '  [PASS] least privilege: external verifier cannot write PlanGate/merge/deploy\n'; pass=$((pass + 1))
else
  printf '  [FAIL] least privilege: external verifier write boundary incomplete\n' >&2; fail=$((fail + 1))
fi

if grep -q 'administrator-separation-attestation, subject = signer_repo' "$_T108_README" \
  && grep -q 'signer-identity-attestation, subject = signer_workflow@signer_digest' "$_T108_README" \
  && grep -q 'nonce-lifecycle-policy, subject = nonce_owner' "$_T108_README"; then
  printf '  [PASS] evidence: exact external Evidence subjects documented\n'; pass=$((pass + 1))
else
  printf '  [FAIL] evidence: subject binding contract incomplete\n' >&2; fail=$((fail + 1))
fi

if grep -q '"separate_administration_required": true' "$_T108_HANDOFF" \
  && grep -q '"normal_plangate_repository_writer_as_sole_admin_allowed": false' "$_T108_HANDOFF" \
  && grep -q '"plangate_self_certification_allowed": false' "$_T108_HANDOFF"; then
  printf '  [PASS] ownership: bootstrap requires a genuinely external operator boundary\n'; pass=$((pass + 1))
else
  printf '  [FAIL] ownership: external operator separation contract missing\n' >&2; fail=$((fail + 1))
fi

if grep -q 'dispatch_ready=false' "$_T108_README" \
  && grep -q 'dispatch_allowed=false' "$_T108_README" \
  && grep -q 'independent_admin_boundary_verified=false' "$_T108_README"; then
  printf '  [PASS] authority: strong promotion remains false\n'; pass=$((pass + 1))
else
  printf '  [FAIL] authority: fail-closed statement missing\n' >&2; fail=$((fail + 1))
fi

pg_extra_contract_finalize
