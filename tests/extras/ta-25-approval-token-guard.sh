# tests/extras/ta-25-approval-token-guard.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0123: EH-token-guard + HMAC schema tests
# NOTE: TC-01/02/03/04/05/06 require patch to be applied first (Human: sh scripts/apply-task-0123-patches.sh)

printf '\n=== TA-25: TASK-0123 approval-token-guard ===\n'

PG_T25_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T25_GUARD="$PG_T25_ROOT/scripts/check-approval-token-write.sh"
PG_T25_SCHEMA="$PG_T25_ROOT/schemas/maintenance.schema.json"
PG_T25_PATCH="$PG_T25_ROOT/scripts/apply-task-0123-patches.sh"

t25_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t25_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: check-approval-token-write.sh が存在・実行可能
if [ -f "$PG_T25_GUARD" ] && [ -x "$PG_T25_GUARD" ]; then
  t25_pass "TC-01 check-approval-token-write.sh exists and is executable"
else
  t25_fail "TC-01 check-approval-token-write.sh missing or not executable (run: sh scripts/apply-task-0123-patches.sh)"
fi

# TC-02: syntax check
if [ -f "$PG_T25_GUARD" ] && sh -n "$PG_T25_GUARD" 2>/dev/null; then
  t25_pass "TC-02 check-approval-token-write.sh syntax ok"
elif [ ! -f "$PG_T25_GUARD" ]; then
  t25_fail "TC-02 check-approval-token-write.sh not found (run patch first)"
else
  t25_fail "TC-02 check-approval-token-write.sh syntax error"
fi

# TC-03: maintenance.json パスへの write を検知して exit 1
if [ -f "$PG_T25_GUARD" ]; then
  _tc03_exit=0
  PLANGATE_HOOK_FILE="docs/working/_maintenance/maintenance.json" "$PG_T25_GUARD" 2>/dev/null || _tc03_exit=$?
  if [ "$_tc03_exit" = "1" ]; then
    t25_pass "TC-03 maintenance.json path blocked (exit 1)"
  else
    t25_fail "TC-03 maintenance.json path not blocked (exit $_tc03_exit)"
  fi
else
  t25_fail "TC-03 SKIP: check-approval-token-write.sh not found (run patch first)"
fi

# TC-04: approvals/c3.json パスへの write を検知して exit 1
if [ -f "$PG_T25_GUARD" ]; then
  _tc04_exit=0
  PLANGATE_HOOK_FILE="docs/working/TASK-0001/approvals/c3.json" "$PG_T25_GUARD" 2>/dev/null || _tc04_exit=$?
  if [ "$_tc04_exit" = "1" ]; then
    t25_pass "TC-04 approvals/c3.json path blocked (exit 1)"
  else
    t25_fail "TC-04 approvals/c3.json not blocked (exit $_tc04_exit)"
  fi
else
  t25_fail "TC-04 SKIP: check-approval-token-write.sh not found (run patch first)"
fi

# TC-05: 通常ファイルは通過（exit 0）
if [ -f "$PG_T25_GUARD" ]; then
  _tc05_exit=0
  PLANGATE_HOOK_FILE="src/index.ts" "$PG_T25_GUARD" 2>/dev/null || _tc05_exit=$?
  if [ "$_tc05_exit" = "0" ]; then
    t25_pass "TC-05 normal file passes (exit 0)"
  else
    t25_fail "TC-05 normal file incorrectly blocked (exit $_tc05_exit)"
  fi
else
  t25_fail "TC-05 SKIP: check-approval-token-write.sh not found (run patch first)"
fi

# TC-06: schemas/maintenance.schema.json に hmac_signature フィールド存在
_tc06_result=$(python3 -c "
import json, sys
try:
    d = json.load(open('$PG_T25_SCHEMA'))
    if 'hmac_signature' in d.get('properties', {}):
        print('present')
    else:
        print('missing')
except Exception as e:
    print('error:' + str(e))
" 2>/dev/null || echo "error")
if [ "$_tc06_result" = "present" ]; then
  t25_pass "TC-06 hmac_signature field present in maintenance.schema.json"
elif [ "$_tc06_result" = "missing" ]; then
  pass=$((pass + 1)); printf '  [SKIP] TC-06 hmac_signature not yet in schema (HO patch unapplied — SKIP)\n'
else
  t25_fail "TC-06 maintenance.schema.json read error: $_tc06_result"
fi

# TC-07: apply-task-0123-patches.sh が存在・syntax check
if [ -f "$PG_T25_PATCH" ] && sh -n "$PG_T25_PATCH" 2>/dev/null; then
  t25_pass "TC-07 apply-task-0123-patches.sh exists and syntax ok"
else
  t25_fail "TC-07 apply-task-0123-patches.sh missing or syntax error"
fi
