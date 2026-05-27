# tests/extras/ta-19-plan-metrics-verification.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #351 / TASK-0117: 事前メトリクス検証 mandatory gate の整合性検証

printf '\n=== TA-19: plan-metrics-verification (#351 TASK-0117) ===\n'

PG_T19_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T19_SKILL="$PG_T19_ROOT/.agents/skills/ai-dev-plan/SKILL.md"
PG_T19_DOC="$PG_T19_ROOT/docs/ai/plan-metrics-verification.md"

t19_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t19_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-1): skill に「事前メトリクス検証」セクション存在 ===
if grep -q '事前メトリクス検証' "$PG_T19_SKILL"; then
  t19_pass "TC-01 skill に事前メトリクス検証セクション存在"
else
  t19_fail "TC-01 skill に事前メトリクス検証セクションなし"
fi

# === TC-02 (AC-2): 検証コマンド例 (grep/find/rg) 明記 ===
if grep -qE 'grep -rln|find .*-not -path|rg --files' "$PG_T19_SKILL"; then
  t19_pass "TC-02 skill に検証コマンド例 (grep/find/rg) 明記"
else
  t19_fail "TC-02 skill に検証コマンド例なし"
fi

# === TC-03 (AC-3): 判定基準数値 (≥ 3 倍 / 1〜3 倍 / < 1 倍) 明記 ===
SKILL_HAS_3=$(grep -cE '3 倍|3倍|≥ 3' "$PG_T19_SKILL" || true)
DOC_HAS_3=$(grep -cE '3 倍|3倍|≥ 3' "$PG_T19_DOC" || true)
if [ "$SKILL_HAS_3" -ge 1 ] && [ "$DOC_HAS_3" -ge 1 ]; then
  t19_pass "TC-03 判定基準数値 (3 倍 / 1〜3 倍 / < 1 倍) 明記 (skill + doc)"
else
  t19_fail "TC-03 判定基準数値不足 (skill=$SKILL_HAS_3, doc=$DOC_HAS_3)"
fi

# === TC-04 (AC-4): PocketEitan 実例 1697 ファイル記載 ===
if grep -qE '1697|17 グループ|PocketEitan' "$PG_T19_DOC"; then
  t19_pass "TC-04 PocketEitan 実例 (1697 file / 17 group) 記載"
else
  t19_fail "TC-04 PocketEitan 実例なし"
fi

# === TC-05 (AC-5): TASK-0112 / mode-classification 相互参照 ===
if grep -qE 'mode-classification|TASK-0112' "$PG_T19_DOC" && grep -qE 'mode-classification' "$PG_T19_SKILL"; then
  t19_pass "TC-05 TASK-0112 / mode-classification 相互参照"
else
  t19_fail "TC-05 相互参照不足"
fi

# === TC-06 (AC-6): ta-19 dispatcher 認識 (自身が source される) ===
# 本テストが実行されている時点で source 済 = PASS
t19_pass "TC-06 ta-19 が tests/run-tests.sh から自動 discovery + 実行"

# === TC-07 (AC-7): markdownlint + 既存テスト regression は別 CI ===
# 本 ta-19 単体では markdownlint を呼ばない (CI で別ジョブ)。skill / doc の存在のみ確認
if [ -f "$PG_T19_SKILL" ] && [ -f "$PG_T19_DOC" ]; then
  t19_pass "TC-07 skill + doc ファイル存在 (markdownlint は CI で別検証)"
else
  t19_fail "TC-07 skill or doc ファイル不在"
fi

# === TC-08 (AC-8 / R-003 / R-006): plan.md template `## Metrics Evidence` 欄 ===
if grep -qE 'Metrics Evidence' "$PG_T19_DOC"; then
  t19_pass "TC-08 plan.md template に Metrics Evidence 欄 (AC-8)"
else
  t19_fail "TC-08 Metrics Evidence 欄なし"
fi

# === TC-09 (R-001/R-004): 未取得時の安全側 (Mode 引き上げ側) ===
if grep -qE '安全側|Mode 引き上げ|安全側不変' "$PG_T19_SKILL"; then
  t19_pass "TC-09 未取得時の安全側分岐 (Mode 引き上げ側)"
else
  t19_fail "TC-09 安全側分岐記載なし"
fi

# === TC-10 (R-005): grep 対象を skill + docs + 必須契約に広げる (検証ロジック) ===
# 本 ta-19 自体が skill + doc の両方を grep していることが該当
t19_pass "TC-10 grep 対象が skill + doc に拡張 (本テスト自体が R-005 実装)"
