#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-94 — ai-loop V2 PBI materializer (#1442).
#
# This is the CI execution path for scripts/ai-loop/test_pbi_materializer.py.
# It prevents a false green where the Python test file exists but never executes.

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
pg_extra_contract_init ta-94-pbi-materializer standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T94_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T94_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T94_AI_LOOP="$_T94_ROOT/scripts/ai-loop"
_T94_PLUGIN="$_T94_ROOT/plugin/plangate/skills/ai-loop-cycle/scripts"
_T94_PY="${PLANGATE_PYTHON:-python3}"

printf 'TA-94: ai-loop V2 PBI materializer (#1442)\n'

_t94_tmp=$(mktemp -d)
register_cleanup "$_t94_tmp"

# 1. Unit suite must actually execute at least one test and report OK.
_t94_log="$_t94_tmp/unit.log"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/test_pbi_materializer.py" >"$_t94_log" 2>&1 || _t94_rc=$?
_t94_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t94_log" | head -1)
[ -n "$_t94_n" ] || _t94_n=0
if [ "$_t94_rc" -eq 0 ] && [ "$_t94_n" -gt 0 ] && grep -q '^OK' "$_t94_log"; then
  printf '  [PASS] unit: test_pbi_materializer.py (Ran %s tests / OK)\n' "$_t94_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: test_pbi_materializer.py failed (rc=%s ran=%s)\n' "$_t94_rc" "$_t94_n" >&2
  sed 's/^/    /' "$_t94_log" >&2
  fail=$((fail + 1))
fi

# 2. Distribution mirror must be byte-identical after sync.
if cmp -s "$_T94_AI_LOOP/pbi_materializer.py" "$_T94_PLUGIN/pbi_materializer.py" \
  && cmp -s "$_T94_AI_LOOP/test_pbi_materializer.py" "$_T94_PLUGIN/test_pbi_materializer.py"; then
  printf '  [PASS] distribution: source/plugin materializer + test are byte-identical\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] distribution: plugin mirror drift detected\n' >&2
  fail=$((fail + 1))
fi

# 3. Existing execution-boundary checker must include the new source tree without violation.
_t94_boundary="$_t94_tmp/boundary.log"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/check_exec_boundary.py" >"$_t94_boundary" 2>&1 || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] && grep -q 'clean' "$_t94_boundary"; then
  printf '  [PASS] execution boundary: clean\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] execution boundary: not clean (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_boundary" >&2
  fail=$((fail + 1))
fi

# 4. First slice must remain shadow-only: parser must not expose a write mode.
if grep -q 'choices=("shadow",)' "$_T94_AI_LOOP/pbi_materializer.py" \
  && ! grep -Eq 'choices=.*write|--write|auto[_-]?write' "$_T94_AI_LOOP/pbi_materializer.py"; then
  printf '  [PASS] rollout boundary: shadow-only CLI; no write mode\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] rollout boundary: shadow-only CLI invariant missing\n' >&2
  fail=$((fail + 1))
fi

rm -rf "$_t94_tmp"
pg_extra_contract_finalize
