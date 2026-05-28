# tests/extras/ta-21-codex-mvp-split.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0118 / #352: codex-mvp-split skill / command 構造検証

printf '\n=== TA-21: codex-mvp-split (#352 TASK-0118) ===\n'

PG_T21_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T21_CMD="$PG_T21_ROOT/.claude/commands/codex-mvp-split.md"
PG_T21_SKILL="$PG_T21_ROOT/.agents/skills/codex-mvp-split/SKILL.md"
PG_T21_DOC="$PG_T21_ROOT/docs/ai/codex-mvp-split.md"

t21_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t21_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-1): slash command 存在 ===
if [ -f "$PG_T21_CMD" ]; then
  t21_pass "TC-01 .claude/commands/codex-mvp-split.md 存在"
else
  t21_fail "TC-01 command 不在"
fi

# === TC-02 (AC-2): skill 存在 + frontmatter ===
if [ -f "$PG_T21_SKILL" ] && grep -qE "^name:" "$PG_T21_SKILL" && grep -qE "^description:" "$PG_T21_SKILL"; then
  t21_pass "TC-02 skill 存在 + frontmatter (name/description)"
else
  t21_fail "TC-02 skill 不在 or frontmatter 不足"
fi

# === TC-03 (AC-3): 質問テンプレ 4 選択肢 (A/B/C/D) ===
ABCD_COUNT=$(grep -cE '\(A\)|\(B\)|\(C\)|\(D\)' "$PG_T21_CMD" "$PG_T21_DOC" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
if [ "$ABCD_COUNT" -ge 4 ]; then
  t21_pass "TC-03 質問テンプレ 4 選択肢 (A/B/C/D) 存在"
else
  t21_fail "TC-03 4 選択肢不足 (count=$ABCD_COUNT)"
fi

# === TC-03b (AC-3): 工数 S/M/L + 判断材料 3 軸 ===
if grep -qE "S/M/L|工数" "$PG_T21_DOC" && \
   grep -qE "ユーザ価値" "$PG_T21_DOC" && \
   grep -qE "実装の独立性|独立性" "$PG_T21_DOC" && \
   grep -qE "次フェーズへの拡張性|拡張性" "$PG_T21_DOC"; then
  t21_pass "TC-03b 工数 S/M/L + 判断材料 3 軸 (価値/独立性/拡張性)"
else
  t21_fail "TC-03b 工数 or 3 軸不足"
fi

# === TC-04 (AC-4): Phase 分割表 template ===
if grep -qE "Phase 分割表" "$PG_T21_ROOT/docs/working/templates/README.md" "$PG_T21_DOC" "$PG_T21_CMD" 2>/dev/null; then
  t21_pass "TC-04 Phase 分割表 template 記述"
else
  t21_fail "TC-04 Phase 分割表 なし"
fi

# === TC-05 (AC-5): TASK-0117 (#351) 連携明記 ===
if grep -qE "TASK-0117|事前メトリクス検証|plan-metrics-verification|#351" "$PG_T21_DOC"; then
  t21_pass "TC-05 TASK-0117 (#351) 連携明記"
else
  t21_fail "TC-05 TASK-0117 連携なし"
fi

# === TC-06 (AC-6): PocketEitan 実例 2 件 ===
EXAMPLE_COUNT=$(grep -cE "例文音読カード|TASK-srs-unification" "$PG_T21_DOC" 2>/dev/null || echo 0)
if [ "$EXAMPLE_COUNT" -ge 2 ]; then
  t21_pass "TC-06 PocketEitan 実例 2 件 (例文音読カード / TASK-srs-unification)"
else
  t21_fail "TC-06 実例不足 (count=$EXAMPLE_COUNT)"
fi

# === TC-07 (AC-7): doc 正本構造 ===
if grep -qE "## 目的|## 質問テンプレ|## 採用後" "$PG_T21_DOC"; then
  t21_pass "TC-07 doc 正本構造 (目的/質問テンプレ/採用後)"
else
  t21_fail "TC-07 doc 構造不足"
fi

# === TC-08 (AC-2): skill が薄い設計 (正本参照) ===
if grep -qE "正本とし|Read First|順序のみ" "$PG_T21_SKILL"; then
  t21_pass "TC-08 skill が薄い設計 (doc 正本参照、ai-dev-plan と同 pattern)"
else
  t21_fail "TC-08 skill 設計不適"
fi
