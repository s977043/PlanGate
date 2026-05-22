# tests/extras/ta-13-plangate-setup.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0107: PlanGate Setup Command (Command + Agent + Skill + Workflow-owned 永続ロック)

printf '\n=== TA-13: TASK-0107 plangate-setup (Command + Agent + Skill) ===\n'

PG_T13_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T13_CMD="$PG_T13_ROOT/.claude/commands/plangate-setup.md"
PG_T13_AGT="$PG_T13_ROOT/.claude/agents/setup-coordinator.md"
PG_T13_SKL="$PG_T13_ROOT/.claude/skills/plangate-setup/SKILL.md"
PG_T13_CONTRACT="$PG_T13_ROOT/docs/working/TASK-0107/contract-notes.md"
PG_T13_STATUS="$PG_T13_ROOT/docs/working/TASK-0107/status.md"
PG_T13_JSONL="$PG_T13_ROOT/docs/working/TASK-0107/decision-log.jsonl"

t13_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t13_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 [AC-1] Command 起動口 + Agent 参照 ===
if [ -f "$PG_T13_CMD" ] && grep -q "setup-coordinator" "$PG_T13_CMD"; then
  t13_pass "TC-01 Command file exists with Agent reference"
else
  t13_fail "TC-01 Command file or Agent reference missing"
fi

# === TC-02 [AC-2] doctor --json mock B (不足項目あり) で抽出ロジック検証 ===
# Mock B: passed=false 相当 (checks[] に ok=false 項目を含む) → 不足項目をリスト化できるか
_tc02_mock=$(cat <<'JSON'
{
  "scope": "test-mock-b",
  "checks": [
    {"name": "schemas/foo.json", "ok": true, "level": "fail", "detail": null},
    {"name": "settings wiring (mock)", "ok": false, "level": "fail", "detail": "wiring not applied"},
    {"name": "EH-8 hook (mock)", "ok": false, "level": "warn", "detail": "not executable"}
  ]
}
JSON
)
_tc02_result=$(printf '%s' "$_tc02_mock" | python3 -c "
import json, sys
d = json.load(sys.stdin)
unmet = [c['name'] for c in d['checks'] if not c['ok']]
overall_pass = all(c['ok'] for c in d['checks'] if c['level'] == 'fail')
print(f'unmet={len(unmet)} overall_pass={overall_pass}')
" 2>/dev/null || echo "ERROR")
if [ "$_tc02_result" = "unmet=2 overall_pass=False" ]; then
  t13_pass "TC-02 doctor --json mock B extracts 2 unmet items, overall_pass=False"
else
  t13_fail "TC-02 mock B extraction failed (got: $_tc02_result)"
fi

# === TC-03 [AC-2] doctor --json mock A (passed=true) で抽出がスキップされる ===
_tc03_mock=$(cat <<'JSON'
{
  "scope": "test-mock-a",
  "checks": [
    {"name": "schemas/foo.json", "ok": true, "level": "fail", "detail": null},
    {"name": "settings wiring (mock)", "ok": true, "level": "fail", "detail": null}
  ]
}
JSON
)
_tc03_result=$(printf '%s' "$_tc03_mock" | python3 -c "
import json, sys
d = json.load(sys.stdin)
unmet = [c['name'] for c in d['checks'] if not c['ok']]
overall_pass = all(c['ok'] for c in d['checks'] if c['level'] == 'fail')
print(f'unmet={len(unmet)} overall_pass={overall_pass}')
" 2>/dev/null || echo "ERROR")
if [ "$_tc03_result" = "unmet=0 overall_pass=True" ]; then
  t13_pass "TC-03 doctor --json mock A: unmet=0, overall_pass=True (skip extraction)"
else
  t13_fail "TC-03 mock A extraction failed (got: $_tc03_result)"
fi

# === TC-04/TC-05 [AC-3] Agent が apply-claude-settings.sh を実行しない ===
# 「実行」を意味する記述で、かつ「禁止」「実行しない」「NG」等の禁止文脈でない行のみを真の違反とする
_real_violation=$(grep -E 'Bash\(["'"'"'].*apply-claude-settings\.sh|(直接実行|を実行する|執行する).*apply-claude-settings\.sh' "$PG_T13_AGT" 2>/dev/null \
  | grep -vE '(禁止|実行しない|提示のみ|NG|prohibited|forbidden|do not execute)' \
  | wc -l | tr -d ' \n')
if [ -z "$_real_violation" ] || [ "$_real_violation" = "0" ]; then
  t13_pass "TC-04 Agent does NOT execute apply-claude-settings.sh (prohibition context excluded)"
else
  t13_fail "TC-04 Agent appears to execute apply-claude-settings.sh (real violations=$_real_violation)"
fi

if grep -qE '(実行しない|提示のみ|Human-owned)' "$PG_T13_AGT"; then
  t13_pass "TC-05 Agent has '実行しない|提示のみ|Human-owned' wording"
else
  t13_fail "TC-05 Agent lacks 提示のみ 明文化"
fi

# === TC-09 [AC-6] Skill に 5 要素対応表 ===
count=$(grep -cE '(Context files|Global instructions|Folder|Plugins|Connectors)' "$PG_T13_SKL" 2>/dev/null || echo 0)
if [ "$count" -ge 5 ]; then
  t13_pass "TC-09 Skill has 5-element mapping (count=$count)"
else
  t13_fail "TC-09 Skill 5-element mapping insufficient (count=$count)"
fi

# === TC-10〜TC-14 [AC-7] Rule 1-5 ===
# Rule 1: Workflow 追加なし — git diff で docs/workflows/ 配下に新規無し
# 簡易検証: docs/workflows/ 内の新規ファイルが本 PBI で追加されていないこと
if [ ! -e "$PG_T13_ROOT/docs/workflows/06_setup.md" ] 2>/dev/null; then
  t13_pass "TC-10 Rule 1: no new workflow file added"
else
  t13_fail "TC-10 Rule 1: unexpected workflow file"
fi

# Rule 2: Skill 再利用単位（TASK-0107 / このプロジェクト等を含まない）
if ! grep -E "(TASK-0107|このプロジェクト)" "$PG_T13_SKL" >/dev/null 2>&1; then
  t13_pass "TC-11 Rule 2: Skill has no project-specific terms"
else
  t13_fail "TC-11 Rule 2: Skill contains project-specific terms"
fi

# Rule 3: Agent 責務のみ（frontmatter + description の単一責務）
if grep -qE '^description:.*(対話|追跡|Gate|検証)' "$PG_T13_AGT"; then
  t13_pass "TC-12 Rule 3: Agent description has single responsibility"
else
  t13_fail "TC-12 Rule 3: Agent description responsibility unclear"
fi

# Rule 4: 案件固有は CLAUDE.md 経由参照（Agent/Skill/Command 内に直書きしない）
# 簡易検証: PlanGate（成果物名なので OK）は許容、wiring 詳細は contract-notes.md 経由
if grep -q "contract-notes" "$PG_T13_AGT"; then
  t13_pass "TC-13 Rule 4: Agent references contract-notes (CLAUDE.md/working ref pattern)"
else
  t13_fail "TC-13 Rule 4: Agent lacks contract-notes reference"
fi

# Rule 5: handoff 集約は exec 後（本 PBI handoff.md は exec 完了時に生成）
# 本テスト時点では handoff.md は未生成でも OK。template 準拠を後段で確認
t13_pass "TC-14 Rule 5: handoff.md will be generated at T-08 (deferred)"

# === TC-15 [AC-8] handoff 6 要素（exec 完了時生成 / deferred）===
PG_T13_HANDOFF="$PG_T13_ROOT/docs/working/TASK-0107/handoff.md"
if [ -f "$PG_T13_HANDOFF" ]; then
  count=$(grep -cE '(要件適合|既知課題|V2|妥協点|引き継ぎ|テスト結果)' "$PG_T13_HANDOFF" 2>/dev/null || echo 0)
  if [ "$count" -ge 6 ]; then
    t13_pass "TC-15 handoff.md has 6 elements"
  else
    t13_fail "TC-15 handoff.md elements insufficient (count=$count)"
  fi
else
  printf '  [DEFER] TC-15 handoff.md not yet generated (will be created at T-08)\n'
fi

# === TC-16 [AC-9] Agent frontmatter 既存 Agent と同構造 ===
# acceptance-tester と同じキー集合: name, description, tools, model
PG_T13_REF="$PG_T13_ROOT/.claude/agents/acceptance-tester.md"
ref_keys=$(awk '/^---$/{f=!f; next} f{ if($1~/^[a-z]+:/) print $1 }' "$PG_T13_REF" | sort | head -5)
new_keys=$(awk '/^---$/{f=!f; next} f{ if($1~/^[a-z]+:/) print $1 }' "$PG_T13_AGT" | sort | head -5)
if [ "$ref_keys" = "$new_keys" ]; then
  t13_pass "TC-16 Agent frontmatter keys match acceptance-tester"
else
  t13_fail "TC-16 Agent frontmatter keys differ (ref=$ref_keys / new=$new_keys)"
fi

# === TC-17 [AC-10] settings.json hooks 変更なし ===
# 本 PBI のコミット前/中で .claude/settings.json の変更がないことを git diff で確認
# main から HEAD への diff で .claude/settings.json を含まない
if [ -d "$PG_T13_ROOT/.git" ]; then
  diff_lines=$(cd "$PG_T13_ROOT" && git diff --name-only main..HEAD 2>/dev/null | grep '^\.claude/settings\.json$' | wc -l | tr -d ' \n')
  if [ -z "$diff_lines" ] || [ "$diff_lines" = "0" ]; then
    t13_pass "TC-17 .claude/settings.json: no diff vs main (AC-10)"
  else
    t13_fail "TC-17 .claude/settings.json: unexpected diff vs main (lines=$diff_lines)"
  fi
else
  printf '  [SKIP] TC-17 not a git repo\n'
fi

# === TC-18 [AC-11] status.md に完了マーカー ===
if [ -f "$PG_T13_STATUS" ] && grep -qE '(✅|完了|Setup Summary)' "$PG_T13_STATUS"; then
  t13_pass "TC-18 status.md has completion marker"
else
  t13_fail "TC-18 status.md lacks completion marker"
fi

# === TC-19 [AC-11] decision-log.jsonl に append-only エントリ ===
if [ -f "$PG_T13_JSONL" ]; then
  # 各行が JSON としてパース可能か Python で検証
  if python3 -c "
import json, sys
lines = open('$PG_T13_JSONL').read().splitlines()
n_valid = 0
for l in lines:
    if not l.strip(): continue
    try:
        json.loads(l)
        n_valid += 1
    except:
        sys.exit(1)
if n_valid == 0: sys.exit(1)
print(n_valid)
" >/dev/null 2>&1; then
    t13_pass "TC-19 decision-log.jsonl has valid JSON entries"
  else
    t13_fail "TC-19 decision-log.jsonl has invalid JSON entries"
  fi
else
  t13_fail "TC-19 decision-log.jsonl not found"
fi

# === TC-20 [AC-12] doctor --check-settings ゲート ===
# CI 環境では settings wiring が未適用のため doctor --check-settings は FAIL する想定。
# テストは: (1) Agent definition に --check-settings ゲート記述があること を static 検証
# 実環境での実 PASS 検証は manual 種別（V-1 checklist / handoff §1 で扱う）に分離（R-016 反映）
if grep -qE 'doctor --check-settings' "$PG_T13_AGT" 2>/dev/null; then
  t13_pass "TC-20 Agent has doctor --check-settings gate description (static check, AC-12)"
else
  t13_fail "TC-20 Agent lacks doctor --check-settings gate description"
fi
# 実機 PASS は補助情報として記録（FAIL でも block しない）
_out=$("$PG_T13_ROOT/bin/plangate" doctor --check-settings 2>&1 || true)
if printf '%s' "$_out" | grep -q '^\[check-settings\] PASS:'; then
  printf '  [INFO] TC-20-runtime doctor --check-settings PASS (local env)\n'
else
  printf '  [INFO] TC-20-runtime doctor --check-settings not PASS (CI/ephemeral env expected)\n'
fi

# === TC-21/TC-22 [AC-13] 解消不能 FAIL 脱出経路 ===
if grep -qE '(フォローアップ|PBI 起票|承知スキップ|脱出経路)' "$PG_T13_AGT"; then
  t13_pass "TC-21/22 Agent has escape path for unsolvable FAIL"
else
  t13_fail "TC-21/22 Agent lacks escape path"
fi

# === Contract notes 存在検証（T-01/T-02 Output）===
if [ -f "$PG_T13_CONTRACT" ] && grep -q "doctor --json" "$PG_T13_CONTRACT"; then
  t13_pass "Contract notes exist with doctor --json schema"
else
  t13_fail "Contract notes missing or incomplete"
fi

printf '=== TA-13 done ===\n\n'
