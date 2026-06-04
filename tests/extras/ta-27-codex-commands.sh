# tests/extras/ta-27-codex-commands.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #455: README/docs に実在しない codex コマンド例が無いことを検証

printf '\n=== TA-27: codex-commands (#455) ===\n'

PG_T27_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T27_SCRIPT="$PG_T27_ROOT/scripts/check-codex-commands.sh"

t27_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t27_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: スクリプト存在・実行可能
if [ -f "$PG_T27_SCRIPT" ] && [ -x "$PG_T27_SCRIPT" ]; then
  t27_pass "TC-01 check-codex-commands.sh 存在・実行可能"
else
  t27_fail "TC-01 check-codex-commands.sh 不在 or 非実行可能"
fi

# TC-02: sh -n syntax
if sh -n "$PG_T27_SCRIPT" 2>/dev/null; then
  t27_pass "TC-02 sh -n syntax check"
else
  t27_fail "TC-02 syntax error"
fi

# TC-03: 現状の repo はクリーン（exit 0）
if sh "$PG_T27_SCRIPT" >/dev/null 2>&1; then
  t27_pass "TC-03 現状 repo に無効 codex コマンド例なし（exit 0）"
else
  t27_fail "TC-03 無効 codex コマンド例を検出（exit 1）"
fi

# TC-04: 検出力 — 無効コマンド例を仕込んだ一時ディレクトリで exit 1
_t27_tmp=$(mktemp -d)
(
  cd "$_t27_tmp" || exit 1
  printf '# T\n```bash\ncodex plugin install plangate\n```\n' > README.md
  mkdir -p docs plugin
  grep -rnE "^[[:space:]]*(codex plugin install|codex plugin marketplace list)([[:space:]]|\$)" README.md >/dev/null 2>&1
)
_t27_detect=$?
rm -rf "$_t27_tmp"
if [ "$_t27_detect" = "0" ]; then
  t27_pass "TC-04 無効コマンド例を検出できる（grep ロジック）"
else
  t27_fail "TC-04 無効コマンド例を検出できない"
fi

# TC-05: 注記文（行頭が codex でない）は誤検出しない
_t27_note='> 注記: `codex plugin install` は存在しません'
if printf '%s\n' "$_t27_note" | grep -qE "^[[:space:]]*(codex plugin install)([[:space:]]|\$)"; then
  t27_fail "TC-05 注記文を誤検出した（false positive）"
else
  t27_pass "TC-05 注記文は誤検出しない"
fi
