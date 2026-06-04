# tests/extras/ta-28-plugin-version.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #453: plugin.json version が最新 release tag と一致することを検証

printf '\n=== TA-28: plugin-version (#453) ===\n'

PG_T28_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T28_SCRIPT="$PG_T28_ROOT/scripts/check-plugin-version.sh"
PG_T28_JSON="$PG_T28_ROOT/plugin/plangate/.claude-plugin/plugin.json"

t28_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t28_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: スクリプト存在・実行可能
if [ -f "$PG_T28_SCRIPT" ] && [ -x "$PG_T28_SCRIPT" ]; then
  t28_pass "TC-01 check-plugin-version.sh 存在・実行可能"
else
  t28_fail "TC-01 不在 or 非実行可能"
fi

# TC-02: sh -n syntax
if sh -n "$PG_T28_SCRIPT" 2>/dev/null; then
  t28_pass "TC-02 sh -n syntax check"
else
  t28_fail "TC-02 syntax error"
fi

# TC-03: plugin.json に version フィールドが存在
if grep -q '"version"' "$PG_T28_JSON" 2>/dev/null; then
  t28_pass "TC-03 plugin.json に version あり"
else
  t28_fail "TC-03 plugin.json に version なし"
fi

# TC-04: --warn-only は不一致でも exit 0
if sh "$PG_T28_SCRIPT" --warn-only >/dev/null 2>&1; then
  t28_pass "TC-04 --warn-only は exit 0"
else
  t28_fail "TC-04 --warn-only が exit 非0"
fi

# TC-05: version が v プレフィックスを持たない（8.11.0 形式）
_t28_ver=$(python3 -c "import json; print(json.load(open('$PG_T28_JSON'))['version'])" 2>/dev/null || printf '')
case "${_t28_ver:-}" in
  v*) t28_fail "TC-05 plugin.json version に v プレフィックス（${_t28_ver:-}）" ;;
  "") t28_fail "TC-05 plugin.json version 取得失敗" ;;
  *)  t28_pass "TC-05 plugin.json version は v プレフィックスなし（${_t28_ver:-}）" ;;
esac
