#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-101 — Codex JSONL pairing candidate remains non-promoted (#1448).

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
pg_extra_contract_init ta-101-runtime-evidence-codex-jsonl-correlation-candidate standalone-capable

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

printf 'TA-101: Codex JSONL pairing candidate (#1448)\n'

_t101_tmp=$(mktemp -d)
register_cleanup "$_t101_tmp"
_t101_repo="$_t101_tmp/repo"
mkdir -p "$_t101_repo"

# 1. Unit suite.
_t101_unit="$_t101_tmp/unit.log"
_t101_rc=0
"$_T101_PY" "$_T101_AI_LOOP/test_runtime_evidence_codex_jsonl_correlation_candidate.py" >"$_t101_unit" 2>&1 || _t101_rc=$?
_t101_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t101_unit" | head -1)
[ -n "$_t101_n" ] || _t101_n=0
if [ "$_t101_rc" -eq 0 ] && [ "$_t101_n" -gt 0 ] && grep -q '^OK' "$_t101_unit"; then
  printf '  [PASS] unit: JSONL pairing candidate suite passed (%s tests)\n' "$_t101_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: JSONL pairing candidate suite failed (rc=%s ran=%s)\n' "$_t101_rc" "$_t101_n" >&2
  sed 's/^/    /' "$_t101_unit" >&2
  fail=$((fail + 1))
fi

_t101_req="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
_t101_cfg="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
_t101_hook="$_t101_tmp/hook-candidate.json"
_t101_jsonl="$_t101_tmp/codex.jsonl"
_t101_result="$_t101_tmp/result.json"

# 2. Generate a valid hook candidate outside the repository.
"$_T101_PY" - "$_T101_AI_LOOP" "$_t101_hook" "$_t101_req" "$_t101_cfg" <<'PY'
import json
import pathlib
import sys

sys.path.insert(0, sys.argv[1])
import runtime_evidence_codex_probe_candidate as probe

out = pathlib.Path(sys.argv[2])
request_hash = sys.argv[3]
config_sha = sys.argv[4]
provider = "cloudflare"

start = probe.normalize_hook_event(
    event={
        "session_id": "sess-101",
        "transcript_path": "/tmp/main.jsonl",
        "cwd": "/workspace",
        "hook_event_name": "SubagentStart",
        "model": "gpt-5.6",
        "turn_id": "turn-101",
        "agent_id": "agent-101",
        "agent_type": "explorer_agent",
        "permission_mode": "default",
    },
    request_hash=request_hash,
    config_sha=config_sha,
    provider=provider,
)
stop = probe.normalize_hook_event(
    event={
        "session_id": "sess-101",
        "transcript_path": "/tmp/main.jsonl",
        "cwd": "/workspace",
        "hook_event_name": "SubagentStop",
        "model": "gpt-5.6",
        "turn_id": "turn-101",
        "agent_id": "agent-101",
        "agent_type": "explorer_agent",
        "permission_mode": "default",
        "agent_transcript_path": "/tmp/subagent.jsonl",
        "stop_hook_active": False,
        "last_assistant_message": "inspection complete",
    },
    request_hash=request_hash,
    config_sha=config_sha,
    provider=provider,
)
result = probe.verify_candidate_trace(
    records=[start, stop],
    request_hash=request_hash,
    config_sha=config_sha,
    provider=provider,
)
out.write_text(json.dumps(result, sort_keys=True) + "\n", encoding="utf-8")
PY

# 3. Synthetic Codex JSONL follows the observed TASK-1078 item.completed shape.
cat >"$_t101_jsonl" <<'JSON'
{"type":"item.completed","item":{"id":"item_3","type":"command_execution","command":"PRIVATE COMMAND MUST NOT LEAK","exit_code":0,"status":"completed"}}
{"type":"item.completed","item":{"id":"item_5","type":"agent_message","text":"PRIVATE MESSAGE MUST NOT LEAK"}}
JSON

_t101_rc=0
"$_T101_PY" "$_T101_AI_LOOP/runtime_evidence_codex_jsonl_correlation_candidate.py" \
  --repo-root "$_t101_repo" \
  --hook-candidate "$_t101_hook" \
  --codex-jsonl "$_t101_jsonl" \
  --request-hash "$_t101_req" \
  --config-sha "$_t101_cfg" \
  --provider cloudflare \
  >"$_t101_result" 2>"$_t101_tmp/result.err" || _t101_rc=$?

if [ "$_t101_rc" -eq 0 ] \
  && grep -q '"cross_source_pairing_candidate": true' "$_t101_result" \
  && grep -q '"same_run_copresence_verified": false' "$_t101_result" \
  && grep -q '"same_run_identity_verified": false' "$_t101_result" \
  && grep -q '"direct_agent_id_correlation_available": false' "$_t101_result" \
  && grep -q '"codex_jsonl_runtime_correlation_verified": false' "$_t101_result" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t101_result" \
  && grep -q '"dispatch_ready": false' "$_t101_result" \
  && grep -q '"dispatch_allowed": false' "$_t101_result"; then
  printf '  [PASS] pairing: cross-source inputs do not promote same-run correlation\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] pairing: candidate was incorrectly promoted (rc=%s)\n' "$_t101_rc" >&2
  sed 's/^/    /' "$_t101_tmp/result.err" >&2
  fail=$((fail + 1))
fi

# 4. Privacy: raw command/message bodies must never appear in the output artifact.
if ! grep -q 'PRIVATE COMMAND MUST NOT LEAK' "$_t101_result" \
  && ! grep -q 'PRIVATE MESSAGE MUST NOT LEAK' "$_t101_result" \
  && grep -q '"raw_payload_copied": false' "$_t101_result"; then
  printf '  [PASS] privacy: raw Codex runtime content not copied into Evidence\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] privacy: raw runtime content leaked into Evidence\n' >&2
  fail=$((fail + 1))
fi

# 5. Raw JSONL inside the repository must fail closed.
cp "$_t101_jsonl" "$_t101_repo/codex.jsonl"
_t101_rc=0
"$_T101_PY" "$_T101_AI_LOOP/runtime_evidence_codex_jsonl_correlation_candidate.py" \
  --repo-root "$_t101_repo" \
  --hook-candidate "$_t101_hook" \
  --codex-jsonl "$_t101_repo/codex.jsonl" \
  --request-hash "$_t101_req" \
  --config-sha "$_t101_cfg" \
  --provider cloudflare \
  >"$_t101_tmp/inside.out" 2>"$_t101_tmp/inside.err" || _t101_rc=$?
if [ "$_t101_rc" -eq 2 ] && grep -q 'outside repository' "$_t101_tmp/inside.err"; then
  printf '  [PASS] storage: raw Codex JSONL is forbidden inside repository\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] storage: repo-local raw JSONL was not rejected (rc=%s)\n' "$_t101_rc" >&2
  fail=$((fail + 1))
fi

# 6. No authority-bearing command surface.
if ! grep -Eq 'add_parser\("(dispatch|attest|approve|merge|deploy)"\)' \
  "$_T101_AI_LOOP/runtime_evidence_codex_jsonl_correlation_candidate.py"; then
  printf '  [PASS] CLI boundary: correlation candidate exposes no authority command\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI boundary: authority-bearing command detected\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
