#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-88 — ai-loop V2 RunEvent / RunEvidence pure spine (#1391).

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
pg_extra_contract_init ta-88-ai-loop-v2-event-evidence standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T88_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T88_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_EVENT="$_T88_ROOT/scripts/ai-loop-v2/run_event.py"
_EVIDENCE="$_T88_ROOT/scripts/ai-loop-v2/run_evidence.py"
_TEST_EVENT="$_T88_ROOT/scripts/ai-loop-v2/test_run_event.py"
_TEST_EVIDENCE="$_T88_ROOT/scripts/ai-loop-v2/test_run_evidence.py"

printf 'TA-88: ai-loop V2 RunEvent / RunEvidence pure spine (#1391)\n'

for _f in "$_EVENT" "$_EVIDENCE" "$_TEST_EVENT" "$_TEST_EVIDENCE"; do
  if [ ! -r "$_f" ]; then
    printf '  [FAIL] missing file: %s\n' "$_f" >&2
    fail=$((fail + 1))
  fi
done

_t88_run_python() {
  _label="$1"
  _file="$2"
  if _out=$(python3 "$_file" 2>&1); then
    printf '%s\n' "$_out"
    printf '  [PASS] %s\n' "$_label"
    pass=$((pass + 1))
  else
    _rc=$?
    printf '%s\n' "$_out" >&2
    printf '  [FAIL] %s (rc=%s)\n' "$_label" "$_rc" >&2
    fail=$((fail + 1))
  fi
}

if [ -r "$_TEST_EVENT" ]; then
  _t88_run_python "TC-01 RunEvent unit tests" "$_TEST_EVENT"
fi
if [ -r "$_TEST_EVIDENCE" ]; then
  _t88_run_python "TC-02 RunEvidence unit tests" "$_TEST_EVIDENCE"
fi

# #1391 is deliberately storage-agnostic and pure.
if grep -En '(^|[[:space:]])(import|from)[[:space:]]+(os|subprocess|socket|urllib|http|requests|time|datetime)([[:space:].]|$)' "$_EVENT" "$_EVIDENCE" >/dev/null 2>&1; then
  printf '  [FAIL] TC-03 forbidden runtime/network/time import found\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] TC-03 no runtime/network/time imports\n'
  pass=$((pass + 1))
fi

if grep -En 'open[[:space:]]*\(|write_text|write_bytes|os\.replace|fcntl|flock|LOCK_EX|jsonl' "$_EVENT" "$_EVIDENCE" >/dev/null 2>&1; then
  printf '  [FAIL] TC-04 persistence primitive found in #1391 pure layer\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] TC-04 no persistence primitive in #1391\n'
  pass=$((pass + 1))
fi

if grep -En 'gh pr merge|merge_pull_request|auto.?merge|production_promotion' "$_EVENT" "$_EVIDENCE" >/dev/null 2>&1; then
  printf '  [FAIL] TC-05 merge/promotion primitive found\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] TC-05 no merge/promotion primitive\n'
  pass=$((pass + 1))
fi

if grep -q 'def validate_event_draft' "$_EVENT" &&
   grep -q 'def finalize_event' "$_EVENT" &&
   grep -q 'def validate_append' "$_EVENT" &&
   grep -q 'def validate_stream' "$_EVENT" &&
   grep -q 'def project_run_evidence' "$_EVIDENCE"; then
  printf '  [PASS] TC-06 expected pure interfaces present\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] TC-06 expected pure interfaces missing\n' >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
