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
   printf '%s' "$_t31_out2" | grep -q 'marketplace add s977043/plangate'; then
  t31_pass "TC-05 未登録時に導入コマンドを案内"
else
  t31_fail "TC-05 未登録案内が無い"
fi
rm -rf "$_t31_tmp"

# TC-06: marketplace cache だけの環境は registered:NO（#1085 AC-5 / 旧実装の false-green）
# 旧実装は「marketplace cache ディレクトリの存在」だけで registered:YES を返していた。
# marketplace add は plugin を install しない（`codex plugin add` が別に要る）ため、
# この状態で YES を返すと「plugin が 1 件もロードされていないのに doctor が緑」になる。
# /tmp 配下のみを使うため trap は使わない（sourced 元 run-tests.sh の trap を
# 破壊しないため）。中断時の tmp 残留は OS 側で掃除されるため許容する。
_t31_home=$(mktemp -d) || { t31_fail "TC-06 mktemp 失敗"; return 0 2>/dev/null || true; }
mkdir -p "$_t31_home/.tmp/marketplaces/plangate/.claude-plugin"
printf '{"name":"plangate","plugins":[{"name":"plangate","version":"9.9.9"}]}\n' \
  > "$_t31_home/.tmp/marketplaces/plangate/.claude-plugin/marketplace.json"
_t31_out6=$(CODEX_HOME="$_t31_home" sh "$PG_T31_SCRIPT" 2>/dev/null || printf '')
if printf '%s' "$_t31_out6" | grep -q 'registered: NO' && \
   printf '%s' "$_t31_out6" | grep -q 'marketplace cache: FOUND' && \
   printf '%s' "$_t31_out6" | grep -q 'cache version: 9.9.9'; then
  t31_pass "TC-06 marketplace cache のみは registered:NO（cache 状態は別行で報告）"
else
  t31_fail "TC-06 marketplace cache のみで registered:NO にならない（出力: $(printf '%s' "$_t31_out6" | tr '\n' '|'))"
fi
rm -rf "$_t31_home"

# TC-08: install 済み環境（config.toml の enabled 宣言 + plugins/cache 実体）で
#        registered:YES + plugin root を出力（positive / #1085 AC-5）
_t31_home8=$(mktemp -d) || { t31_fail "TC-08 mktemp 失敗"; return 0 2>/dev/null || true; }
printf '[plugins."plangate@plangate"]\nenabled = true\n' > "$_t31_home8/config.toml"
mkdir -p "$_t31_home8/plugins/cache/plangate/plangate/9.9.9/skills/sample-skill"
_t31_out8=$(CODEX_HOME="$_t31_home8" sh "$PG_T31_SCRIPT" 2>/dev/null || printf '')
if printf '%s' "$_t31_out8" | grep -q 'registered: YES' && \
   printf '%s' "$_t31_out8" | grep -q 'plugin root: .*plugins/cache/plangate/plangate/9.9.9'; then
  t31_pass "TC-08 install 済みで registered:YES + plugin root 出力"
else
  t31_fail "TC-08 install 済みを検出できない（出力: $(printf '%s' "$_t31_out8" | tr '\n' '|'))"
fi

# TC-09: enabled 宣言だけで cache 実体が無い場合は registered:NO（片側成立を YES にしない）
_t31_home9=$(mktemp -d) || { t31_fail "TC-09 mktemp 失敗"; return 0 2>/dev/null || true; }
printf '[plugins."plangate@plangate"]\nenabled = true\n' > "$_t31_home9/config.toml"
_t31_out9=$(CODEX_HOME="$_t31_home9" sh "$PG_T31_SCRIPT" 2>/dev/null || printf '')
if printf '%s' "$_t31_out9" | grep -q 'registered: NO'; then
  t31_pass "TC-09 config 宣言のみ（cache 実体なし）は registered:NO"
else
  t31_fail "TC-09 cache 実体が無いのに registered:YES（出力: $(printf '%s' "$_t31_out9" | tr '\n' '|'))"
fi
rm -rf "$_t31_home8" "$_t31_home9"

# TC-07: --online で gh 不在時に「gh CLI 不在のためスキップ」（#476 / coverage 補完）
# gh だけを除外した PATH（python3/dirname のみリンク）で実行し、ネットワーク非依存で
# online 分岐の gh 不在パスを検証する。
_t31_bin=$(mktemp -d) || { t31_fail "TC-07 mktemp 失敗"; return 0 2>/dev/null || true; }
_t31_home7=$(mktemp -d) || { rm -rf "$_t31_bin"; t31_fail "TC-07 mktemp 失敗"; return 0 2>/dev/null || true; }
for _c in sh python3 dirname; do
  _src=$(command -v "$_c" 2>/dev/null) && ln -s "$_src" "$_t31_bin/$_c" 2>/dev/null
done
_t31_out7=$(CODEX_HOME="$_t31_home7" PATH="$_t31_bin" sh "$PG_T31_SCRIPT" --online 2>/dev/null || printf '')
if printf '%s' "$_t31_out7" | grep -q 'gh CLI 不在のためスキップ'; then
  t31_pass "TC-07 --online で gh 不在時にスキップ案内"
else
  t31_fail "TC-07 --online gh 不在スキップが出ない（出力: $(printf '%s' "$_t31_out7" | tr '\n' '|'))"
fi
rm -rf "$_t31_bin" "$_t31_home7"
