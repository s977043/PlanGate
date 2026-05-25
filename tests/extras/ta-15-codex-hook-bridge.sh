# tests/extras/ta-15-codex-hook-bridge.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# Gap 4 / #336: .codex/hooks/eh-bridge.sh と .codex/hooks.json の検証

printf '\n=== TA-15: .codex/hooks/eh-bridge.sh (Gap 4 / #336) ===\n'

PG_T15_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T15_BRIDGE="$PG_T15_ROOT/.codex/hooks/eh-bridge.sh"
PG_T15_HOOKS_JSON="$PG_T15_ROOT/.codex/hooks.json"

t15_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t15_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01: bridge script 存在 + 実行権限 ===
if [ -f "$PG_T15_BRIDGE" ] && [ -x "$PG_T15_BRIDGE" ]; then
  t15_pass "TC-01 eh-bridge.sh exists and is executable"
else
  t15_fail "TC-01 eh-bridge.sh missing or not executable"
fi

# === TC-02: shell syntax ===
if sh -n "$PG_T15_BRIDGE" 2>/dev/null; then
  t15_pass "TC-02 eh-bridge.sh shell syntax OK"
else
  t15_fail "TC-02 eh-bridge.sh shell syntax error"
fi

# === TC-03: hooks.json valid JSON ===
if [ -f "$PG_T15_HOOKS_JSON" ] && python3 -m json.tool "$PG_T15_HOOKS_JSON" >/dev/null 2>&1; then
  t15_pass "TC-03 .codex/hooks.json is valid JSON"
else
  t15_fail "TC-03 .codex/hooks.json missing or invalid JSON"
fi

# === TC-04: hooks.json に PlanGate EH-1/2/3/6/9 hook 配線あり ===
_tc04_count=0
for eh in check-plan-exists check-c3-approval check-plan-hash check-forbidden-files check-delegation-commit-boundary; do
  if grep -q "$eh" "$PG_T15_HOOKS_JSON" 2>/dev/null; then
    _tc04_count=$((_tc04_count + 1))
  fi
done
if [ "$_tc04_count" = "5" ]; then
  t15_pass "TC-04 hooks.json wires all 5 PlanGate hooks (EH-1/2/3/6/9)"
else
  t15_fail "TC-04 hooks.json wires $_tc04_count/5 PlanGate hooks"
fi

# === TC-05: bridge が hook name 未指定で allow を返す (safety default) ===
_tc05_out=$(echo '{}' | "$PG_T15_BRIDGE" 2>/dev/null || true)
if printf '%s' "$_tc05_out" | grep -q '"permissionDecision":"allow"'; then
  t15_pass "TC-05 bridge with missing hook name returns allow (safety default)"
else
  t15_fail "TC-05 bridge with missing hook name should return allow, got: $_tc05_out"
fi

# === TC-06: bridge が存在しない hook script 名で deny を返す ===
_tc06_out=$(echo '{"tool_name":"Edit"}' | "$PG_T15_BRIDGE" check-nonexistent-xyz.sh 2>/dev/null || true)
if printf '%s' "$_tc06_out" | grep -q '"permissionDecision":"deny"'; then
  t15_pass "TC-06 bridge with nonexistent hook returns deny"
else
  t15_fail "TC-06 bridge with nonexistent hook should return deny, got: $_tc06_out"
fi

# === TC-07: bridge が JSON 出力するか (hookSpecificOutput 構造) ===
_tc07_out=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/safe.txt"}}' | "$PG_T15_BRIDGE" check-plan-exists.sh 2>/dev/null || true)
if printf '%s' "$_tc07_out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert 'hookSpecificOutput' in d
assert d['hookSpecificOutput']['hookEventName'] == 'PreToolUse'
assert d['hookSpecificOutput']['permissionDecision'] in ('allow', 'deny')
print('OK')
" 2>/dev/null | grep -q OK; then
  t15_pass "TC-07 bridge outputs valid Codex hookSpecificOutput JSON"
else
  t15_fail "TC-07 bridge output invalid: $_tc07_out"
fi
