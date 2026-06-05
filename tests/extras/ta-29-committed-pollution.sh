# tests/extras/ta-29-committed-pollution.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #452: コミット済み SSoT の AI memory 汚染検査スクリプトの検証

printf '\n=== TA-29: committed-pollution (#452) ===\n'

PG_T29_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T29_SCRIPT="$PG_T29_ROOT/scripts/check-committed-memory-pollution.sh"

t29_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t29_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: スクリプト存在・実行可能
if [ -f "$PG_T29_SCRIPT" ] && [ -x "$PG_T29_SCRIPT" ]; then
  t29_pass "TC-01 check-committed-memory-pollution.sh 存在・実行可能"
else
  t29_fail "TC-01 不在 or 非実行可能"
fi

# TC-02: sh -n syntax
if sh -n "$PG_T29_SCRIPT" 2>/dev/null; then
  t29_pass "TC-02 sh -n syntax check"
else
  t29_fail "TC-02 syntax error"
fi

# TC-03: --warn-only は汚染があっても exit 0
if sh "$PG_T29_SCRIPT" --warn-only >/dev/null 2>&1; then
  t29_pass "TC-03 --warn-only は exit 0"
else
  t29_fail "TC-03 --warn-only が exit 非0"
fi

# TC-04: 検出力 — 汚染を仕込んだ一時ファイルで grep 検出
_t29_tmp=$(mktemp)
printf '# T\n<claude-mem-context>\nget_observations([1])\n</claude-mem-context>\n' > "$_t29_tmp"
if grep -qE '<claude-mem-context>|get_observations' "$_t29_tmp" 2>/dev/null; then
  t29_pass "TC-04 汚染パターンを検出できる（grep ロジック）"
else
  t29_fail "TC-04 汚染パターンを検出できない"
fi
rm -f "$_t29_tmp"

# TC-05: クリーンなファイルは誤検出しない
_t29_clean=$(mktemp)
printf '# AGENTS\nThis is a clean repo instruction file.\nMemory: persistent.\n' > "$_t29_clean"
if grep -qE '<claude-mem-context>|</claude-mem-context>|get_observations|mem-search skill' "$_t29_clean" 2>/dev/null; then
  t29_fail "TC-05 クリーンなファイルを誤検出した"
else
  t29_pass "TC-05 クリーンなファイルは誤検出しない"
fi
rm -f "$_t29_clean"
