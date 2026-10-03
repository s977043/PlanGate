#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-99 — request-bound R1 canary proposal / fail-closed boundary (#1448).

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
pg_extra_contract_init ta-99-runtime-evidence-request-bound-canary standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T99_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T99_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T99_AI_LOOP="$_T99_ROOT/scripts/ai-loop"
_T99_PY="${PLANGATE_PYTHON:-python3}"
_T99_PROPOSAL="$_T99_ROOT/docs/working/_runtime-attestation/runtime-r1-request-bound-canary.proposed.yml"

printf 'TA-99: request-bound R1 canary fail-closed boundary (#1448)\n'

_t99_tmp=$(mktemp -d)
register_cleanup "$_t99_tmp"

# 1. Unit suite must execute.
_t99_unit="$_t99_tmp/unit.log"
_t99_rc=0
"$_T99_PY" "$_T99_AI_LOOP/test_runtime_evidence_request_bound_canary.py" >"$_t99_unit" 2>&1 || _t99_rc=$?
_t99_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t99_unit" | head -1)
[ -n "$_t99_n" ] || _t99_n=0

if [ "$_t99_rc" -eq 0 ] && [ "$_t99_n" -gt 0 ] && grep -q '^OK' "$_t99_unit"; then
  printf '  [PASS] unit: request-bound canary suite passed (%s tests)\n' "$_t99_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: request-bound canary suite failed (rc=%s ran=%s)\n' "$_t99_rc" "$_t99_n" >&2
  sed 's/^/    /' "$_t99_unit" >&2
  fail=$((fail + 1))
fi

# 2. Proposal must remain fail-closed and must not claim Human/environment verification.
if [ -f "$_T99_PROPOSAL" ] \
  && grep -q '^# PROPOSAL ONLY' "$_T99_PROPOSAL" \
  && grep -q 'probe-unavailable' "$_T99_PROPOSAL" \
  && grep -q 'environment: runtime-r1-rollout' "$_T99_PROPOSAL" \
  && grep -q 'provider=${{ inputs.provider }}' "$_T99_PROPOSAL"; then
  printf '  [PASS] proposal: request/provider binding + fail-closed probe preserved\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: fail-closed/request binding contract drifted\n' >&2
  fail=$((fail + 1))
fi

# 3. Real repository Codex Explorer config must bind exactly at preflight,
#    without promoting runtime enforcement or dispatch.
_t99_config_sha=$(
  "$_T99_PY" - "$_T99_ROOT/.codex/agents/explorer_agent.toml" <<'PY'
import hashlib
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
print("sha256:" + hashlib.sha256(path.read_bytes()).hexdigest())
PY
)
_t99_req="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
_t99_pre="$_t99_tmp/preflight.json"
_t99_rc=0
"$_T99_PY" "$_T99_AI_LOOP/runtime_evidence_request_bound_canary.py" preflight \
  --repo-root "$_T99_ROOT" \
  --request-hash "$_t99_req" \
  --config-sha "$_t99_config_sha" \
  --platform codex \
  --provider cloudflare \
  >"$_t99_pre" 2>"$_t99_tmp/preflight.err" || _t99_rc=$?

if [ "$_t99_rc" -eq 0 ] \
  && grep -q '"static_sandbox_candidate": true' "$_t99_pre" \
  && grep -q '"hard_read_only_enforced": false' "$_t99_pre" \
  && grep -q '"runtime_role_registered": false' "$_t99_pre" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t99_pre" \
  && grep -q '"protected_environment_configuration_verified": false' "$_t99_pre" \
  && grep -q '"human_rollout_decision_verified": false' "$_t99_pre" \
  && grep -q '"dispatch_ready": false' "$_t99_pre" \
  && grep -q '"dispatch_allowed": false' "$_t99_pre"; then
  printf '  [PASS] preflight: exact config binds without runtime/Human promotion\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] preflight: request/config boundary failed (rc=%s)\n' "$_t99_rc" >&2
  sed 's/^/    /' "$_t99_tmp/preflight.err" >&2
  fail=$((fail + 1))
fi

# 4. Runtime probe must fail closed with rc=2.
_t99_probe="$_t99_tmp/probe.json"
_t99_rc=0
"$_T99_PY" "$_T99_AI_LOOP/runtime_evidence_request_bound_canary.py" probe-unavailable \
  --request-hash "$_t99_req" \
  --config-sha "$_t99_config_sha" \
  --platform codex \
  --provider cloudflare \
  >"$_t99_probe" 2>"$_t99_tmp/probe.err" || _t99_rc=$?

if [ "$_t99_rc" -eq 2 ] \
  && grep -q '"status": "UNAVAILABLE"' "$_t99_probe" \
  && grep -q '"runtime_probe_reached": true' "$_t99_probe" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t99_probe" \
  && grep -q '"dispatch_allowed": false' "$_t99_probe"; then
  printf '  [PASS] probe: platform adapter absence fails closed as UNAVAILABLE\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] probe: unavailable adapter did not fail closed (rc=%s)\n' "$_t99_rc" >&2
  fail=$((fail + 1))
fi

# 5. CLI surface has no dispatch/execute/activation mutation subcommand.
if ! grep -Eq 'add_parser\("(dispatch|execute|invoke-agent|enable-r1|approve|merge|deploy)"\)' \
  "$_T99_AI_LOOP/runtime_evidence_request_bound_canary.py"; then
  printf '  [PASS] CLI boundary: no dispatch/approval mutation subcommand\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI boundary: mutation subcommand detected\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
