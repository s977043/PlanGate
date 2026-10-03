#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-95 — external runtime evidence ingress R0 (#1448).
#
# Ensures the R0 unit suite and CLI/persistence path actually execute in repository Test.

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
pg_extra_contract_init ta-95-runtime-evidence-ingress standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T95_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T95_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T95_AI_LOOP="$_T95_ROOT/scripts/ai-loop"
_T95_PY="${PLANGATE_PYTHON:-python3}"

printf 'TA-95: external runtime evidence ingress R0 (#1448)\n'

_t95_tmp=$(mktemp -d)
register_cleanup "$_t95_tmp"

# 1. Unit suite must execute and report at least one test.
_t95_log="$_t95_tmp/unit.log"
_t95_rc=0
"$_T95_PY" "$_T95_AI_LOOP/test_runtime_evidence_ingress.py" >"$_t95_log" 2>&1 || _t95_rc=$?
_t95_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t95_log" | head -1)
[ -n "$_t95_n" ] || _t95_n=0
if [ "$_t95_rc" -eq 0 ] && [ "$_t95_n" -gt 0 ] && grep -q '^OK' "$_t95_log"; then
  printf '  [PASS] unit: runtime ingress suite passed (%s tests)\n' "$_t95_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: runtime ingress suite failed (rc=%s ran=%s)\n' "$_t95_rc" "$_t95_n" >&2
  sed 's/^/    /' "$_t95_log" >&2
  fail=$((fail + 1))
fi

# 2. CLI must map an allowlisted Cloudflare event without write/agent authority.
_t95_payload="$_t95_tmp/cloudflare.json"
_t95_envelope="$_t95_tmp/envelope.json"
_t95_out="$_t95_tmp/out.json"

cat >"$_t95_payload" <<'JSON'
{
  "event_id": "ta95-event-001",
  "captured_at": "2026-10-03T07:30:00Z",
  "environment": "production",
  "issue_fingerprint": "TypeError:ta95:42",
  "deployment_ref": "worker-version-ta95",
  "occurrence_count": 3,
  "recurrence": true,
  "error_type": "TypeError",
  "statement": "Cloudflare reported repeated worker failures.",
  "trace_refs": ["cf-trace:ta95"],
  "log_refs": ["cf-log:ta95"],
  "status": "active",
  "candidate_problem": "A production worker failure is recurring."
}
JSON

cat >"$_t95_envelope" <<'JSON'
{
  "authenticated": true,
  "replayed": false,
  "redaction_applied": true,
  "secret_scan": "pass"
}
JSON

_t95_rc=0
"$_T95_PY" "$_T95_AI_LOOP/runtime_evidence_ingress.py" \
  --cloudflare-issue "$_t95_payload" \
  --envelope "$_t95_envelope" \
  >"$_t95_out" 2>"$_t95_tmp/cli.err" || _t95_rc=$?

if [ "$_t95_rc" -eq 0 ] \
  && grep -q '"mode": "r0_shadow"' "$_t95_out" \
  && grep -q '"claim_class": "reported"' "$_t95_out" \
  && grep -q '"decision": "materialize"' "$_t95_out" \
  && grep -q '"agent_invoke_allowed": false' "$_t95_out" \
  && grep -q '"pbi_write_allowed": false' "$_t95_out" \
  && grep -q '"issue_write_allowed": false' "$_t95_out" \
  && grep -q '"code_write_allowed": false' "$_t95_out" \
  && grep -q '"merge_allowed": false' "$_t95_out" \
  && grep -q '"deploy_allowed": false' "$_t95_out"; then
  printf '  [PASS] CLI: Cloudflare mapping fired as reported R0 shadow evidence\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] CLI: R0 mapping/authority invariant failed (rc=%s)\n' "$_t95_rc" >&2
  sed 's/^/    /' "$_t95_tmp/cli.err" >&2
  fail=$((fail + 1))
fi

# 3. Optional persistence may create immutable source evidence only under the intake namespace.
_t95_repo="$_t95_tmp/repo"
mkdir -p "$_t95_repo/docs/working" "$_t95_repo/scripts"
_t95_persist="$_t95_tmp/persist.json"
_t95_rc=0
"$_T95_PY" "$_T95_AI_LOOP/runtime_evidence_ingress.py" \
  --cloudflare-issue "$_t95_payload" \
  --envelope "$_t95_envelope" \
  --persist-root "$_t95_repo" \
  >"$_t95_persist" 2>"$_t95_tmp/persist.err" || _t95_rc=$?

_t95_ref=$(sed -n 's/.*"source_ref": "\([^"]*\)".*/\1/p' "$_t95_persist" | tail -1)
if [ "$_t95_rc" -eq 0 ] \
  && [ -n "$_t95_ref" ] \
  && [ -f "$_t95_repo/$_t95_ref" ] \
  && printf '%s' "$_t95_ref" | grep -q '^docs/working/_runtime-ingress/cloudflare/' \
  && grep -q '"evidence_create_allowed": true' "$_t95_persist" \
  && grep -q '"overwrite_allowed": false' "$_t95_persist" \
  && grep -q '"pbi_write_allowed": false' "$_t95_persist" \
  && grep -q '"issue_write_allowed": false' "$_t95_persist"; then
  printf '  [PASS] persistence: create-only sanitized source evidence path fired\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] persistence: source evidence path/invariant failed (rc=%s ref=%s)\n' "$_t95_rc" "${_t95_ref:-missing}" >&2
  sed 's/^/    /' "$_t95_tmp/persist.err" >&2
  fail=$((fail + 1))
fi

# 4. CLI surface must not expose downstream mutation/rollout switches.
if ! grep -Eq -- '--(write-pbi|create-issue|write-code|approve|merge|deploy|publish|enable-r1|enable-r2|enable-r3)' \
  "$_T95_AI_LOOP/runtime_evidence_ingress.py"; then
  printf '  [PASS] rollout boundary: no downstream mutation/R1-R3 CLI switch\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] rollout boundary: downstream mutation/R1-R3 switch detected\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finish
