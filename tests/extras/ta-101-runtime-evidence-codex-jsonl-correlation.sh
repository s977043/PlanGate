#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-101 — Codex JSONL × Explorer hook thread-correlation candidate (#1448).

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
pg_extra_contract_init ta-101-runtime-evidence-codex-jsonl-correlation standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T101_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T101_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T101_AI_LOOP="$_T101_ROOT/scripts/ai-loop"
_T101_PY="${PLANGATE_PYTHON:-python3}"
_T101_PROPOSAL="$_T101_ROOT/docs/working/_runtime-attestation/codex-r1-jsonl-correlation.proposed.json"

printf 'TA-101: Codex JSONL x Explorer hook correlation candidate (#1448)\n'

_t101_tmp=$(mktemp -d)
register_cleanup "$_t101_tmp"

# 1. Unit suite.
_t101_unit="$_t101_tmp/unit.log"
_t101_rc=0
"$_T101_PY" "$_T101_AI_LOOP/test_runtime_evidence_codex_jsonl_correlation.py" >"$_t101_unit" 2>&1 || _t101_rc=$?
_t101_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t101_unit" | head -1)
[ -n "$_t101_n" ] || _t101_n=0
if [ "$_t101_rc" -eq 0 ] && [ "$_t101_n" -gt 0 ] && grep -q '^OK' "$_t101_unit"; then
  printf '  [PASS] unit: JSONL correlation suite passed (%s tests)\n' "$_t101_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: JSONL correlation suite failed (rc=%s ran=%s)\n' "$_t101_rc" "$_t101_n" >&2
  sed 's/^/    /' "$_t101_unit" >&2
  fail=$((fail + 1))
fi

# 2. Proposal must state the exact non-promotion boundary.
if [ -f "$_T101_PROPOSAL" ] \
  && grep -q '"thread_started_exposes_thread_id": true' "$_T101_PROPOSAL" \
  && grep -q '"turn_started_exposes_turn_id": false' "$_T101_PROPOSAL" \
  && grep -q '"public_thread_item_exposes_subagent_identity": false' "$_T101_PROPOSAL" \
  && grep -q '"codex_jsonl_runtime_correlation_verified"' "$_T101_PROPOSAL" \
  && grep -q '"dispatch_allowed"' "$_T101_PROPOSAL"; then
  printf '  [PASS] proposal: thread-only correlation boundary declared\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] proposal: JSONL correlation boundary incomplete\n' >&2
  fail=$((fail + 1))
fi

# 3. Create hook candidate trace outside repo.
_t101_repo="$_t101_tmp/repo"
_t101_hooks="$_t101_tmp/hooks.jsonl"
_t101_exec="$_t101_tmp/exec.jsonl"
_t101_result="$_t101_tmp/result.json"
mkdir -p "$_t101_repo"

_t101_req="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
_t101_cfg="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

_t101_start='{"session_id":"sess-1","transcript_path":"/tmp/main.jsonl","cwd":"/workspace","hook_event_name":"SubagentStart","model":"gpt-5.6","turn_id":"turn-hook-1","agent_id":"agent-1","agent_type":"explorer_agent","permission_mode":"default"}'
_t101_stop='{"session_id":"sess-1","transcript_path":"/tmp/main.jsonl","cwd":"/workspace","hook_event_name":"SubagentStop","model":"gpt-5.6","turn_id":"turn-hook-1","agent_id":"agent-1","agent_type":"explorer_agent","permission_mode":"default","agent_transcript_path":"/tmp/subagent.jsonl","stop_hook_active":false,"last_assistant_message":"inspection complete"}'

printf '%s\n' "$_t101_start" | "$_T101_PY" "$_T101_AI_LOOP/runtime_evidence_codex_probe_candidate.py" record-hook \
  --repo-root "$_t101_repo" \
  --output "$_t101_hooks" \
  --request-hash "$_t101_req" \
  --config-sha "$_t101_cfg" \
  --provider cloudflare >/dev/null

printf '%s\n' "$_t101_stop" | "$_T101_PY" "$_T101_AI_LOOP/runtime_evidence_codex_probe_candidate.py" record-hook \
  --repo-root "$_t101_repo" \
  --output "$_t101_hooks" \
  --request-hash "$_t101_req" \
  --config-sha "$_t101_cfg" \
  --provider cloudflare >/dev/null

cat >"$_t101_exec" <<'JSONL'
{"type":"thread.started","thread_id":"sess-1"}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item-1","type":"reasoning","text":"raw reasoning must not be copied"}}
{"type":"item.completed","item":{"id":"item-2","type":"agent_message","text":"raw agent message must not be copied"}}
{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":2,"reasoning_output_tokens":1}}
JSONL

_t101_rc=0
"$_T101_PY" "$_T101_AI_LOOP/runtime_evidence_codex_jsonl_correlation.py" \
  --repo-root "$_t101_repo" \
  --hooks-jsonl "$_t101_hooks" \
  --exec-jsonl "$_t101_exec" \
  --request-hash "$_t101_req" \
  --config-sha "$_t101_cfg" \
  --provider cloudflare \
  >"$_t101_result" 2>"$_t101_tmp/result.err" || _t101_rc=$?

if [ "$_t101_rc" -eq 0 ] \
  && grep -q '"thread_id_correlation_verified": true' "$_t101_result" \
  && grep -q '"single_turn_envelope_verified": true' "$_t101_result" \
  && grep -q '"command_execution_read_only_verified": false' "$_t101_result" \
  && grep -q '"mcp_tool_read_only_verified": false' "$_t101_result" \
  && grep -q '"repository_postcondition_verified": false' "$_t101_result" \
  && grep -q '"turn_id_correlation_verified": false' "$_t101_result" \
  && grep -q '"subagent_identity_correlation_verified": false' "$_t101_result" \
  && grep -q '"codex_jsonl_runtime_correlation_verified": false' "$_t101_result" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t101_result" \
  && grep -q '"dispatch_ready": false' "$_t101_result" \
  && grep -q '"dispatch_allowed": false' "$_t101_result" \
  && ! grep -q 'raw reasoning must not be copied' "$_t101_result" \
  && ! grep -q 'raw agent message must not be copied' "$_t101_result"; then
  printf '  [PASS] correlation: same-thread evidence remains partial/candidate-only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] correlation: candidate was promoted or raw text leaked (rc=%s)\n' "$_t101_rc" >&2
  sed 's/^/    /' "$_t101_tmp/result.err" >&2
  fail=$((fail + 1))
fi

# 4. Thread mismatch must fail closed.
sed 's/"thread_id":"sess-1"/"thread_id":"different-thread"/' "$_t101_exec" >"$_t101_tmp/mismatch.jsonl"
_t101_rc=0
"$_T101_PY" "$_T101_AI_LOOP/runtime_evidence_codex_jsonl_correlation.py" \
  --repo-root "$_t101_repo" \
  --hooks-jsonl "$_t101_hooks" \
  --exec-jsonl "$_t101_tmp/mismatch.jsonl" \
  --request-hash "$_t101_req" \
  --config-sha "$_t101_cfg" \
  --provider cloudflare \
  >"$_t101_tmp/mismatch.out" 2>"$_t101_tmp/mismatch.err" || _t101_rc=$?

if [ "$_t101_rc" -eq 2 ] \
  && grep -q 'hook session_id must match exec thread.started.thread_id' "$_t101_tmp/mismatch.err"; then
  printf '  [PASS] negative: thread mismatch rejected\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] negative: thread mismatch was not rejected (rc=%s)\n' "$_t101_rc" >&2
  fail=$((fail + 1))
fi

# 5. Correlator exposes no authority-bearing subcommand.
if ! grep -Eq 'add_parser\("(dispatch|attest|approve|merge|deploy)"\)' \
  "$_T101_AI_LOOP/runtime_evidence_codex_jsonl_correlation.py"; then
  printf '  [PASS] CLI boundary: correlation exposes verification only\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI boundary: authority-bearing subcommand detected\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
