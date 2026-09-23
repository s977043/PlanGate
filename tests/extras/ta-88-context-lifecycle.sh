#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-88 — Context Lifecycle integration contract (#1410).

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
pg_extra_contract_init ta-88-context-lifecycle standalone-capable

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

_T88_DOC="$_T88_ROOT/docs/ai/context-lifecycle.md"
_T88_WA="$_T88_ROOT/.agents/skills/working-context/SKILL.md"
_T88_WC="$_T88_ROOT/.codex/skills/working-context/SKILL.md"
_T88_WP="$_T88_ROOT/plugin/plangate/skills/working-context/SKILL.md"
_T88_CA="$_T88_ROOT/.agents/skills/context-packager/SKILL.md"
_T88_CC="$_T88_ROOT/.codex/skills/context-packager/SKILL.md"
_T88_CP="$_T88_ROOT/plugin/plangate/skills/context-packager/SKILL.md"

printf 'TA-88: Context Lifecycle integration contract (#1410)\n'

_t88_pass() {
  printf '  [PASS] %s\n' "$1"
  pass=$((pass + 1))
}

_t88_fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  fail=$((fail + 1))
}

if [ -r "$_T88_DOC" ]; then
  _t88_pass "TC-01 integration map exists"
else
  _t88_fail "TC-01 integration map missing"
fi

if grep -q 'Fresh-context triggers' "$_T88_DOC" &&
   grep -q 'No new .*checkpoint.json' "$_T88_DOC" &&
   grep -q 'River Review does not own execution-session memory' "$_T88_DOC"; then
  _t88_pass "TC-02 owner, triggers, and no-second-SSoT boundary documented"
else
  _t88_fail "TC-02 lifecycle boundary text incomplete"
fi

if grep -q 'worker / agent / model / runtime' "$_T88_WA" &&
   grep -q 'L0 → phase-required L1 → L2/L3 on demand' "$_T88_WA" &&
   grep -q 'raw chat transcript' "$_T88_WA"; then
  _t88_pass "TC-03 working-context carries fresh-context transition contract"
else
  _t88_fail "TC-03 working-context lifecycle contract incomplete"
fi

if grep -q 'conversation history の圧縮コピーではない' "$_T88_CA" &&
   grep -q 'review package + diff + evidence' "$_T88_CA" &&
   grep -q 'missing / stale' "$_T88_CA"; then
  _t88_pass "TC-04 context-packager is history-independent and fail-safe"
else
  _t88_fail "TC-04 context-packager handoff contract incomplete"
fi

if cmp -s "$_T88_WA" "$_T88_WC" && cmp -s "$_T88_WA" "$_T88_WP"; then
  _t88_pass "TC-05 working-context distributed surfaces are byte-identical"
else
  _t88_fail "TC-05 working-context distribution drift"
fi

if cmp -s "$_T88_CA" "$_T88_CC" && cmp -s "$_T88_CA" "$_T88_CP"; then
  _t88_pass "TC-06 context-packager distributed surfaces are byte-identical"
else
  _t88_fail "TC-06 context-packager distribution drift"
fi

if [ ! -e "$_T88_ROOT/schemas/context-checkpoint.schema.json" ] &&
   [ ! -e "$_T88_ROOT/schemas/context-lifecycle.schema.json" ]; then
  _t88_pass "TC-07 no duplicate checkpoint/context state schema introduced"
else
  _t88_fail "TC-07 duplicate checkpoint/context state schema detected"
fi

if grep -q 'Do not persist or mechanically replay' "$_T88_DOC" &&
   grep -q 'hidden chain-of-thought' "$_T88_DOC" &&
   grep -q 'credentials, secrets, or personal data' "$_T88_DOC"; then
  _t88_pass "TC-08 privacy and raw-history exclusions documented"
else
  _t88_fail "TC-08 privacy/history exclusions incomplete"
fi

if grep -q 'Do not infer that' "$_T88_DOC" &&
   grep -q 'Human-owned PreCompact wiring' "$_T88_DOC" &&
   grep -q '#938 remains the owner' "$_T88_DOC"; then
  _t88_pass "TC-09 staged enforcement and open wait/resume ownership stay explicit"
else
  _t88_fail "TC-09 staged/open integration status is overstated or missing"
fi

pg_extra_contract_finalize
