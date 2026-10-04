#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-97 — pre-PBI R1 dispatch readiness Evidence boundary (#1448).

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
pg_extra_contract_init ta-97-runtime-evidence-dispatch-readiness standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T97_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T97_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T97_AI_LOOP="$_T97_ROOT/scripts/ai-loop"
_T97_PY="${PLANGATE_PYTHON:-python3}"

printf 'TA-97: pre-PBI R1 dispatch readiness Evidence boundary (#1448)\n'

_t97_tmp=$(mktemp -d)
register_cleanup "$_t97_tmp"

# 1. Unit suite must execute.
_t97_unit="$_t97_tmp/unit.log"
_t97_rc=0
"$_T97_PY" "$_T97_AI_LOOP/test_runtime_evidence_dispatch_readiness.py" >"$_t97_unit" 2>&1 || _t97_rc=$?
_t97_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t97_unit" | head -1)
[ -n "$_t97_n" ] || _t97_n=0
if [ "$_t97_rc" -eq 0 ] && [ "$_t97_n" -gt 0 ] && grep -q '^OK' "$_t97_unit"; then
  printf '  [PASS] unit: dispatch readiness suite passed (%s tests)\n' "$_t97_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: dispatch readiness suite failed (rc=%s ran=%s)\n' "$_t97_rc" "$_t97_n" >&2
  sed 's/^/    /' "$_t97_unit" >&2
  fail=$((fail + 1))
fi

# 2. Build R0 source and R1 shadow request.
_t97_repo="$_t97_tmp/repo"
mkdir -p "$_t97_repo/docs/working" "$_t97_repo/scripts" "$_t97_repo/.codex/agents"
cat >"$_t97_repo/.codex/agents/explorer_agent.toml" <<'TOML'
name = "explorer_agent"
sandbox_mode = "read-only"
TOML

_t97_payload="$_t97_tmp/cloudflare.json"
_t97_envelope="$_t97_tmp/envelope.json"
_t97_r0="$_t97_tmp/r0.json"
_t97_r1="$_t97_tmp/r1.json"

cat >"$_t97_payload" <<'JSON'
{
  "event_id": "ta97-event-001",
  "captured_at": "2026-10-03T08:10:00Z",
  "environment": "production",
  "issue_fingerprint": "TypeError:ta97:42",
  "deployment_ref": "worker-version-ta97",
  "occurrence_count": 2,
  "recurrence": true,
  "error_type": "TypeError",
  "statement": "Cloudflare reported repeated worker failures.",
  "trace_refs": ["cf-trace:ta97"],
  "log_refs": ["cf-log:ta97"],
  "status": "active",
  "candidate_problem": "A production worker failure is recurring."
}
JSON

cat >"$_t97_envelope" <<'JSON'
{
  "authenticated": true,
  "replayed": false,
  "redaction_applied": true,
  "secret_scan": "pass"
}
JSON

_t97_rc=0
"$_T97_PY" "$_T97_AI_LOOP/runtime_evidence_ingress.py" \
  --cloudflare-issue "$_t97_payload" \
  --envelope "$_t97_envelope" \
  --persist-root "$_t97_repo" \
  >"$_t97_r0" 2>"$_t97_tmp/r0.err" || _t97_rc=$?
_t97_ref=$(sed -n 's/.*"source_ref": "\([^"]*\)".*/\1/p' "$_t97_r0" | tail -1)

if [ "$_t97_rc" -eq 0 ] && [ -n "$_t97_ref" ]; then
  "$_T97_PY" "$_T97_AI_LOOP/runtime_evidence_investigation.py" \
    --repo-root "$_t97_repo" \
    --source-ref "$_t97_ref" \
    --platform codex \
    >"$_t97_r1" 2>"$_t97_tmp/r1.err" || _t97_rc=$?
fi

if [ "$_t97_rc" -eq 0 ] && grep -q '"domain": "plangate.runtime-investigation-request/v1"' "$_t97_r1"; then
  printf '  [PASS] setup: R0 -> R1 shadow request created\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] setup: R0 -> R1 request failed (rc=%s)\n' "$_t97_rc" >&2
  fail=$((fail + 1))
fi

# 3. Create four machine-candidate observations. They remain self-unattested.
_t97_obs="$_t97_tmp/observations.json"
mkdir -p "$_t97_repo/docs/working/_runtime-activation"
for _name in role connector sandbox admission; do
  printf '%s candidate pass\n' "$_name" >"$_t97_repo/docs/working/_runtime-activation/$_name.txt"
done

"$_T97_PY" - "$_t97_repo" "$_t97_r1" "$_t97_obs" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
request = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
out = pathlib.Path(sys.argv[3])

specs = [
    ("runtime_role_registered", "runtime_probe", "role.txt",
     {"role": request["role"]["runtime_role"], "config_sha": request["role"]["config_sha"]}),
    ("provider_connector_registered", "runtime_probe", "connector.txt",
     {"provider": request["source"]["provider"]}),
    ("hard_read_only_enforced", "runtime_probe", "sandbox.txt",
     {"role": request["role"]["runtime_role"], "config_sha": request["role"]["config_sha"]}),
    ("admission_binding_verified", "repository_evidence", "admission.txt",
     {"source_ref": request["source"]["source_ref"]}),
]
rows = []
for idx, (kind, source_kind, filename, extra) in enumerate(specs):
    path = root / "docs" / "working" / "_runtime-activation" / filename
    ref = path.relative_to(root).as_posix()
    sha = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    row = {
        "schema_version": "1",
        "domain": "plangate.runtime-pre-run-observation/v1",
        "kind": kind,
        "request_hash": request["request_hash"],
        "platform": "codex",
        "observed_at": f"2026-10-03T08:1{idx}:00Z",
        "source_kind": source_kind,
        "verdict": "pass",
        "evidence_ref": ref,
        "evidence_sha": sha,
    }
    row.update(extra)
    rows.append(row)
out.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

_t97_ready="$_t97_tmp/readiness.json"
_t97_rc=0
"$_T97_PY" "$_T97_AI_LOOP/runtime_evidence_dispatch_readiness.py" \
  --repo-root "$_t97_repo" \
  --request "$_t97_r1" \
  --observations "$_t97_obs" \
  >"$_t97_ready" 2>"$_t97_tmp/readiness.err" || _t97_rc=$?

if [ "$_t97_rc" -eq 0 ] \
  && grep -q '"machine_candidate_evidence_complete": true' "$_t97_ready" \
  && grep -q '"runtime_probe_attestation_verified": false' "$_t97_ready" \
  && grep -q '"human_rollout_decision_verified": false' "$_t97_ready" \
  && grep -q '"dispatch_ready": false' "$_t97_ready" \
  && grep -q '"dispatch_allowed": false' "$_t97_ready" \
  && grep -q '"agent_invoke_allowed": false' "$_t97_ready" \
  && grep -q '"applicable": false' "$_t97_ready" \
  && ! grep -q '"selected":' "$_t97_ready" \
  && ! grep -q '"fired":' "$_t97_ready"; then
  printf '  [PASS] readiness: complete candidate Evidence cannot self-attest runtime/Human authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] readiness: candidate Evidence incorrectly promoted (rc=%s)\n' "$_t97_rc" >&2
  sed 's/^/    /' "$_t97_tmp/readiness.err" >&2
  fail=$((fail + 1))
fi

# 4. A self-declared Human rollout observation must be rejected.
"$_T97_PY" - "$_t97_repo" "$_t97_r1" "$_t97_obs" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
request = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
path = root / "docs" / "working" / "_runtime-activation" / "fake-human.txt"
path.write_text("enable r1\n", encoding="utf-8")
rows = json.loads(pathlib.Path(sys.argv[3]).read_text(encoding="utf-8"))
rows.append({
    "schema_version": "1",
    "domain": "plangate.runtime-pre-run-observation/v1",
    "kind": "rollout_decision_recorded",
    "request_hash": request["request_hash"],
    "platform": "codex",
    "observed_at": "2026-10-03T08:19:00Z",
    "source_kind": "human_decision",
    "verdict": "pass",
    "evidence_ref": path.relative_to(root).as_posix(),
    "evidence_sha": "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest(),
    "decision": "enable_r1_read_only_dispatch"
})
pathlib.Path(sys.argv[3]).write_text(
    json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

_t97_rc=0
"$_T97_PY" "$_T97_AI_LOOP/runtime_evidence_dispatch_readiness.py" \
  --repo-root "$_t97_repo" \
  --request "$_t97_r1" \
  --observations "$_t97_obs" \
  >"$_t97_tmp/fake-human.out" 2>"$_t97_tmp/fake-human.err" || _t97_rc=$?

if [ "$_t97_rc" -eq 2 ] \
  && grep -q 'observations\[4\]\.kind: one of' "$_t97_tmp/fake-human.err" \
  && grep -q "unsupported keys: \['decision'\]" "$_t97_tmp/fake-human.err"; then
  printf '  [PASS] human boundary: self-declared rollout decision rejected\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] human boundary: fake rollout decision was not rejected (rc=%s)\n' "$_t97_rc" >&2
  fail=$((fail + 1))
fi

# 5. Evaluator must expose no dispatch/execute mutation switch.
if ! grep -Eq -- '--(dispatch|execute|invoke-agent|enable-r1|write|create-issue|merge|deploy)' \
  "$_T97_AI_LOOP/runtime_evidence_dispatch_readiness.py"; then
  printf '  [PASS] CLI boundary: evaluator exposes no dispatch/execution switch\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI boundary: dispatch/execution switch detected\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
