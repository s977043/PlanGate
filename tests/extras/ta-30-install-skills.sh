# tests/extras/ta-30-install-skills.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# Plugin 配布の中核スクリプト install-plangate-skills.sh の回帰テスト

printf '\n=== TA-30: install-skills coverage ===\n'

PG_T30_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T30_SH="$PG_T30_ROOT/plugin/plangate/scripts/install-plangate-skills.sh"
PG_T30_TOCODEX="$PG_T30_ROOT/scripts/install-plangate-skills-to-codex.sh"
PG_T30_SPEC="$PG_T30_ROOT/scripts/check-codex-skill-spec.sh"

t30_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t30_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: install-plangate-skills.sh 存在・実行可能
if [ -f "$PG_T30_SH" ] && [ -x "$PG_T30_SH" ]; then
  t30_pass "TC-01 install-plangate-skills.sh 存在・実行可能"
else
  t30_fail "TC-01 不在 or 非実行可能"
fi

# TC-02: syntax（両スクリプト）
if sh -n "$PG_T30_SH" 2>/dev/null && sh -n "$PG_T30_TOCODEX" 2>/dev/null; then
  t30_pass "TC-02 sh -n syntax check（両スクリプト）"
else
  t30_fail "TC-02 syntax error"
fi

# TC-03: --help が exit 0
if sh "$PG_T30_SH" --help >/dev/null 2>&1; then
  t30_pass "TC-03 --help が exit 0"
else
  t30_fail "TC-03 --help が exit 非0"
fi

# TC-04: --target で一時展開し、plugin/plangate/skills と同数を展開
_t30_tmp=$(mktemp -d)
sh "$PG_T30_SH" --target "$_t30_tmp" >/dev/null 2>&1
_t30_src=$(find "$PG_T30_ROOT/plugin/plangate/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
_t30_out=$(ls "$_t30_tmp" 2>/dev/null | grep -v '^\.' | wc -l | tr -d ' ')
if [ "$_t30_out" = "$_t30_src" ] && [ "$_t30_out" -gt 0 ]; then
  t30_pass "TC-04 --target 展開数($_t30_out) = plugin skills 数($_t30_src)"
else
  t30_fail "TC-04 展開数不一致: out=$_t30_out src=$_t30_src"
fi

# TC-05: 展開物が check-codex-skill-spec を PASS
if sh "$PG_T30_SPEC" --target "$_t30_tmp" >/dev/null 2>&1; then
  t30_pass "TC-05 展開物が check-codex-skill-spec PASS"
else
  t30_fail "TC-05 spec check が FAIL"
fi
rm -rf "$_t30_tmp"

# TC-06: 各展開スキルに SKILL.md + agents/openai.yaml がある（サンプル: brainstorming）
_t30_tmp2=$(mktemp -d)
sh "$PG_T30_SH" --target "$_t30_tmp2" >/dev/null 2>&1
if [ -f "$_t30_tmp2/brainstorming/SKILL.md" ] && [ -f "$_t30_tmp2/brainstorming/agents/openai.yaml" ]; then
  t30_pass "TC-06 展開スキルに SKILL.md + agents/openai.yaml"
else
  t30_fail "TC-06 展開スキルの構造不備"
fi
rm -rf "$_t30_tmp2"
