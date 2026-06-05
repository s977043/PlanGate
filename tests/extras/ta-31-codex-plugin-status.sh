# tests/extras/ta-31-codex-plugin-status.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #451: Codex Plugin の登録・version・skill 数のローカル検査スクリプトを検証

printf '\n=== TA-31: codex-plugin-status (#451) ===\n'

PG_T31_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T31_SCRIPT="$PG_T31_ROOT/scripts/check-codex-plugin-status.sh"

t31_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t31_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: スクリプト存在・実行可能
if [ -f "$PG_T31_SCRIPT" ] && [ -x "$PG_T31_SCRIPT" ]; then
  t31_pass "TC-01 check-codex-plugin-status.sh 存在・実行可能"
else
  t31_fail "TC-01 不在 or 非実行可能"
fi

# TC-02: sh -n syntax
if sh -n "$PG_T31_SCRIPT" 2>/dev/null; then
  t31_pass "TC-02 sh -n syntax check"
else
  t31_fail "TC-02 syntax error"
fi

# TC-03: 常に exit 0（doctor 非 fatal セクション想定）
if sh "$PG_T31_SCRIPT" >/dev/null 2>&1; then
  t31_pass "TC-03 exit 0（非 fatal）"
else
  t31_fail "TC-03 exit 非 0"
fi

# TC-04: repo manifest の version/skills 行を出力する
_t31_out=$(sh "$PG_T31_SCRIPT" 2>/dev/null || printf '')
if printf '%s' "$_t31_out" | grep -q 'repo manifest: version='; then
  t31_pass "TC-04 repo manifest version/skills を出力"
else
  t31_fail "TC-04 repo manifest 行が無い"
fi

# TC-05: 未登録環境（空 CODEX_HOME）で導入コマンドを案内する
_t31_tmp=$(mktemp -d) || { t31_fail "TC-05 mktemp 失敗"; return 0 2>/dev/null || true; }
_t31_out2=$(CODEX_HOME="$_t31_tmp" sh "$PG_T31_SCRIPT" 2>/dev/null || printf '')
if printf '%s' "$_t31_out2" | grep -q 'registered: NO' && \
   printf '%s' "$_t31_out2" | grep -q 'marketplace add s977043/PlanGate'; then
  t31_pass "TC-05 未登録時に導入コマンドを案内"
else
  t31_fail "TC-05 未登録案内が無い"
fi
rm -rf "$_t31_tmp"
