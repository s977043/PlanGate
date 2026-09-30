#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-93 — ai-loop V2 owner-backed Delivery runtime (#1391/#1392/#1393/#1395).

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
pg_extra_contract_init ta-93-ai-loop-v2-owner-backed-delivery standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T93_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T93_ROOT="${_pg_extra_dir%/tests/extras}"
fi

printf 'TA-93: ai-loop V2 owner-backed Delivery runtime\n'

if _T93_OUT=$(python3 "$_T93_ROOT/scripts/ai-loop-v2/test_delivery_v2.py" 2>&1); then
  printf '%s\n' "$_T93_OUT"
  printf '  [PASS] owner-backed event/state/decision/E2E tests\n'
  pass=$((pass + 1))
else
  _T93_RC=$?
  printf '%s\n' "$_T93_OUT" >&2
  printf '  [FAIL] owner-backed tests failed (rc=%s)\n' "$_T93_RC" >&2
  fail=$((fail + 1))
fi

# run_state.py is provisional (R-023 / Human decision 2 on #1392): until the
# migration to #1392 it may be imported only by these two files. Only tracked
# *.py files are scanned (git grep).
_T93_IMPORT_ERE='^[[:space:]]*(from|import)[[:space:]]+([^#]*[^A-Za-z0-9_#])?run_state([^A-Za-z0-9_]|$)|(import_module|__import__)\([[:space:]]*["'"'"']([A-Za-z0-9_.]*\.)?run_state["'"'"']'
_T93_WANT='scripts/ai-loop-v2/delivery_runtime.py
scripts/ai-loop-v2/test_delivery_v2.py'
_t93_importers() {
  git -C "$1" grep -lE "$_T93_IMPORT_ERE" -- '*.py' | sort
}
_T93_PROBE=$(mktemp -d)
mkdir -p "$_T93_PROBE/a" && git -C "$_T93_PROBE" init -q
printf 'from run_state import DurableRunStore\n' > "$_T93_PROBE/a/w.py"
printf 'import os, run_state\n' > "$_T93_PROBE/a/x.py"
printf 'm = importlib.import_module("run_state")\n' > "$_T93_PROBE/a/y.py"
printf 'run_state = {}\nfrom run_state_extra import z\nimport os  # run_state\n' > "$_T93_PROBE/a/z.py"
git -C "$_T93_PROBE" add -A
_T93_PROBE_GOT=$(_t93_importers "$_T93_PROBE")
rm -rf "$_T93_PROBE"
_T93_GOT=$(_t93_importers "$_T93_ROOT")
if [ "$_T93_PROBE_GOT" != "a/w.py
a/x.py
a/y.py" ]; then
  printf '  [FAIL] run_state import detector self-check failed: %s\n' "$_T93_PROBE_GOT" >&2
  fail=$((fail + 1))
elif ! git -C "$_T93_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '  [FAIL] run_state import check needs a git checkout: %s\n' "$_T93_ROOT" >&2
  fail=$((fail + 1))
elif [ "$_T93_GOT" = "$_T93_WANT" ]; then
  printf '  [PASS] run_state.py is imported only by delivery_runtime.py and test_delivery_v2.py\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] run_state.py importers differ from the pinned two files:\n%s\n' "$_T93_GOT" >&2
  fail=$((fail + 1))
fi

pg_extra_contract_finalize
