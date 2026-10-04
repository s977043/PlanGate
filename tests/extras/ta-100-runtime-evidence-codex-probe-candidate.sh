#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-100 — Codex Explorer lifecycle probe remains candidate-only (#1448).

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
pg_extra_contract_init ta-100-runtime-evidence-codex-probe-candidate standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T100_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T100_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T100_AI_LOOP="$_T100_ROOT/scripts/ai-loop"
_T100_PY="${PLANGATE_PYTHON:-python3}"
_T100_PROPOSAL="$_T100_ROOT/docs/working/_runtime-attestation/codex-r1-probe-hooks.proposed.json"

printf 'TA-100: Codex Explorer lifecycle probe candidate (#1448)\n'

_t100_tmp=$(mktemp -d)
register_cleanup "$_t100_tmp"

# 1. Unit suite.
_t100_unit="$_t100_tmp/unit.log"
_t100_rc=0
"$_T100_PY" "$_T100_AI_LOOP/test_runtime_evidence_codex_probe_candidate.py" >"$_t100_unit" 2>&1 || _t100_rc=$?
_t100_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t100_unit" | head -1)
[ -n "$_t100_n" ] || _t100_n=0
if [ "$_t100_rc" -eq 0 ] && [ "$_t100_n" -gt 0 ] && grep -q '^OK' "$_t100_unit"; then
  printf '  [PASS] unit: Codex probe candidate suite passed (%s tests)\n' "$_t100_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: Codex probe candidate suite failed (rc=%s ran=%s)\n' "$_t100_rc" "$_t100_n" >&2
  sed 's/^/    /' "$_t100_unit" >&2
  fail=$((fail + 1))
fi

# 2. Proposal is lifecycle-only and explicitly candidate-only.
if [ -f "$_T100_PROPOSAL" ] \
  && grep -q '"SubagentStart"' "$_T100_PROPOSAL" \
  && grep -q '"SubagentStop"' "$_T100_PROPOSAL" \
  && grep -q '\^explorer_agent\$' "$_T100_PROPOSAL" \
  && grep -q 'RUNNER_TEMP/r1-codex-hooks.jsonl' "$_T100_PROPOSAL" \
  && grep -q 'does not establish strong runtime attestation' "$_T100_PROPOSAL"; then
  printf '  [PASS] proposal: Explorer lifecycle observation is candidate-only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: lifecycle candidate contract incomplete\n' >&2
  fail=$((fail + 1))
fi

# 3. Record a start/stop pair outside the repository.
_t100_repo="$_t100_tmp/repo"
_t100_trace="$_t100_tmp/hooks.jsonl"
mkdir -p "$_t100_repo"
_t100_req="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
_t100_cfg="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

_t100_start='{"session_id":"sess-1","transcript_path":"/tmp/main.jsonl","cwd":"/workspace","hook_event_name":"SubagentStart","model":"gpt-5.6","turn_id":"turn-1","agent_id":"agent-1","agent_type":"explorer_agent","permission_mode":"default"}'
_t100_stop='{"session_id":"sess-1","transcript_path":"/tmp/main.jsonl","cwd":"/workspace","hook_event_name":"SubagentStop","model":"gpt-5.6","turn_id":"turn-1","agent_id":"agent-1","agent_type":"explorer_agent","permission_mode":"default","agent_transcript_path":"/tmp/subagent.jsonl","stop_hook_active":false,"last_assistant_message":"inspection complete"}'

_t100_out1=$(printf '%s\n' "$_t100_start" | "$_T100_PY" "$_T100_AI_LOOP/runtime_evidence_codex_probe_candidate.py" record-hook \
  --repo-root "$_t100_repo" \
  --output "$_t100_trace" \
  --request-hash "$_t100_req" \
  --config-sha "$_t100_cfg" \
  --provider cloudflare)
_t100_rc1=$?
_t100_out2=$(printf '%s\n' "$_t100_stop" | "$_T100_PY" "$_T100_AI_LOOP/runtime_evidence_codex_probe_candidate.py" record-hook \
  --repo-root "$_t100_repo" \
  --output "$_t100_trace" \
  --request-hash "$_t100_req" \
  --config-sha "$_t100_cfg" \
  --provider cloudflare)
_t100_rc2=$?

if [ "$_t100_rc1" -eq 0 ] && [ "$_t100_rc2" -eq 0 ] \
  && [ "$_t100_out1" = "{}" ] && [ "$_t100_out2" = "{}" ] \
  && [ "$(wc -l < "$_t100_trace" | tr -d ' ')" -eq 2 ]; then
  printf '  [PASS] recorder: neutral hook protocol + out-of-repo JSONL\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] recorder: hook protocol or trace output invalid\n' >&2
  fail=$((fail + 1))
fi

# 4. Candidate verification must never promote to attestation/dispatch.
_t100_result="$_t100_tmp/result.json"
_t100_rc=0
"$_T100_PY" "$_T100_AI_LOOP/runtime_evidence_codex_probe_candidate.py" verify-candidate \
  --jsonl "$_t100_trace" \
  --request-hash "$_t100_req" \
  --config-sha "$_t100_cfg" \
  --provider cloudflare \
  >"$_t100_result" 2>"$_t100_tmp/result.err" || _t100_rc=$?

if [ "$_t100_rc" -eq 0 ] \
  && grep -q '"runtime_role_observed_candidate": true' "$_t100_result" \
  && grep -q '"explorer_execution_candidate": true' "$_t100_result" \
  && grep -q '"candidate_trace_structure_verified": true' "$_t100_result" \
  && grep -q '"hook_execution_root_attested": false' "$_t100_result" \
  && grep -q '"codex_jsonl_runtime_correlation_verified": false' "$_t100_result" \
  && grep -q '"hard_read_only_enforced": false' "$_t100_result" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t100_result" \
  && grep -q '"dispatch_ready": false' "$_t100_result" \
  && grep -q '"dispatch_allowed": false' "$_t100_result"; then
  printf '  [PASS] verifier: lifecycle trace remains candidate-only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] verifier: candidate trace was incorrectly promoted (rc=%s)\n' "$_t100_rc" >&2
  sed 's/^/    /' "$_t100_tmp/result.err" >&2
  fail=$((fail + 1))
fi

# 5. No dispatch/attest/approval/merge/deploy subcommand.
if ! grep -Eq 'add_parser\("(dispatch|attest|approve|merge|deploy)"\)' \
  "$_T100_AI_LOOP/runtime_evidence_codex_probe_candidate.py"; then
  printf '  [PASS] CLI boundary: probe candidate exposes observation only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI boundary: authority-bearing subcommand detected\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
