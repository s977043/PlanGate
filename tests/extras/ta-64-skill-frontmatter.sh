# tests/extras/ta-64-skill-frontmatter.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# SKILL.md frontmatter の YAML パース健全性回帰テスト。
#
# 背景: plangate-setup/SKILL.md の description が未クォートのまま `Use when:` を
# 含み、YAML が行途中を新しいマッピングキーと解釈して frontmatter 全体が壊れて
# いた（runtime で name/description が silently drop される）。既存の skill 系
# 検査は grep/awk の行単位マッチのみで YAML として parse しないため素通りした。
#   TC-01: scripts/check-skill-frontmatter.py が存在し実行可能
#   TC-02: --selftest が exit 0
#   TC-03: 実リポジトリ走査が exit 0（回帰ガード本体）
#   TC-04: 負側 — 実際に壊れていた description 行を fixture に入れると exit 1
#   TC-05: 同一文言をダブルクォートで囲めば exit 0（検出が記法ではなく
#          クォート有無に反応していることの実証）
#   TC-06: 負側の出力に破損 skill 名が含まれる（診断可能性）

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
pg_extra_contract_init ta-64-skill-frontmatter standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-64: SKILL.md frontmatter parse health ===\n'

t64_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t64_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T64_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T64_SCRIPT="$_T64_ROOT/scripts/check-skill-frontmatter.py"

# 依存ゲート（README 規約 6）: PyYAML 不在環境では検査本体を SKIP
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  pg_extra_contract_skip "PyYAML 未導入のため TA-64 を skip"
  return 0
fi

# === TC-01 スクリプト存在 ===
if [ -f "$_T64_SCRIPT" ] && [ -x "$_T64_SCRIPT" ]; then
  t64_pass "TC-01 check-skill-frontmatter.py が存在し実行可能"
else
  t64_fail "TC-01 check-skill-frontmatter.py が不在 or 非実行可能: $_T64_SCRIPT"
fi

# === TC-02 selftest ===
_t64_rc2=0
_t64_out2=$(python3 "$_T64_SCRIPT" --selftest 2>&1) || _t64_rc2=$?
if [ "$_t64_rc2" -eq 0 ] && printf '%s' "$_t64_out2" | grep -q 'SELFTEST PASS'; then
  t64_pass "TC-02 --selftest が exit 0 / SELFTEST PASS"
else
  t64_fail "TC-02 --selftest 失敗 (rc=$_t64_rc2): $(printf '%s' "$_t64_out2" | head -5 | tr '\n' ';')"
fi

# === TC-03 実リポジトリ走査（回帰ガード本体） ===
_t64_rc3=0
_t64_out3=$(python3 "$_T64_SCRIPT" 2>&1) || _t64_rc3=$?
if [ "$_t64_rc3" -eq 0 ]; then
  t64_pass "TC-03 実リポジトリの全 SKILL.md が frontmatter パース可能"
else
  t64_fail "TC-03 frontmatter 破損を検出 (rc=$_t64_rc3): $(printf '%s' "$_t64_out3" | head -8 | tr '\n' ';')"
fi

# === TC-04 / TC-05 / TC-06 変異注入（負側実証） ===
_T64_TMP="$(mktemp -d)"
rm -rf "$_T64_TMP/skills"
mkdir -p "$_T64_TMP/skills/broken-fixture" "$_T64_TMP/skills/fixed-fixture"

# 実際に壊れていた行（未クォート + 値中の `Use when:`）
_t64_desc='PlanGate 初期セットアップを対話的に進めるためのチェックリスト、5 要素対応観点、Human-owned 操作の script 提示テンプレ。doctor を単一検証源とする。Use when: 「PlanGate をセットアップして」「導入したい」と依頼された時。'

{
  printf -- '---\n'
  printf 'name: broken-fixture\n'
  printf 'description: %s\n' "$_t64_desc"
  printf -- '---\n\n# broken fixture\n'
} > "$_T64_TMP/skills/broken-fixture/SKILL.md"

{
  printf -- '---\n'
  printf 'name: fixed-fixture\n'
  printf 'description: "%s"\n' "$_t64_desc"
  printf -- '---\n\n# fixed fixture\n'
} > "$_T64_TMP/skills/fixed-fixture/SKILL.md"

# 負側単独: 壊れた fixture だけの root
mkdir -p "$_T64_TMP/only-broken"
cp -R "$_T64_TMP/skills/broken-fixture" "$_T64_TMP/only-broken/"
_t64_rc4=0
_t64_out4=$(python3 "$_T64_SCRIPT" --root "$_T64_TMP/only-broken" 2>&1) || _t64_rc4=$?
if [ "$_t64_rc4" -eq 1 ]; then
  t64_pass "TC-04 負側: 未クォート description を含む fixture で exit 1"
else
  t64_fail "TC-04 負側で検出できず (rc=$_t64_rc4, 期待 1): $(printf '%s' "$_t64_out4" | head -5 | tr '\n' ';')"
fi

if printf '%s' "$_t64_out4" | grep -q 'broken-fixture'; then
  t64_pass "TC-06 負側出力に破損 skill の path が含まれる"
else
  t64_fail "TC-06 負側出力に破損 path が無い: $(printf '%s' "$_t64_out4" | head -5 | tr '\n' ';')"
fi

# 正側単独: 同一文言をクォートした fixture だけの root
mkdir -p "$_T64_TMP/only-fixed"
cp -R "$_T64_TMP/skills/fixed-fixture" "$_T64_TMP/only-fixed/"
_t64_rc5=0
_t64_out5=$(python3 "$_T64_SCRIPT" --root "$_T64_TMP/only-fixed" 2>&1) || _t64_rc5=$?
if [ "$_t64_rc5" -eq 0 ]; then
  t64_pass "TC-05 正側: 同一文言をクォートすれば exit 0（記法ではなくクォート有無に反応）"
else
  t64_fail "TC-05 正側で誤検出 (rc=$_t64_rc5, 期待 0): $(printf '%s' "$_t64_out5" | head -5 | tr '\n' ';')"
fi

rm -rf "$_T64_TMP"

pg_extra_contract_finalize
