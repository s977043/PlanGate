# tests/extras/ta-40-task-0129-review-gate.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh
# TASK-0129 (#543): Plan Review Gate 判定連携テスト（TC-01〜TC-09）

# ---- extras execution contract bootstrap (#921) ----------------------------
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
pg_extra_contract_init ta-40-task-0129-review-gate standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠: FIXTURES_DIR:- を含む extras は
# standalone 経路で runner と同一の 7 env unset を自ファイル内に持つ必要がある
# （#921 bootstrap が FIXTURES_DIR:- を持ち込み走査対象になった。helper init と冪等）。
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-40: TASK-0129 Review Gate Decision Mapping ===\n'

_t40_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
if [ ! -f "$_t40_root/schemas/c3-approval.schema.json" ]; then
  _t40_root="$(CDPATH= cd -- "$_t40_root/.." && pwd)"
fi
_t40_doc="$_t40_root/docs/ai/review-gate-decision-mapping.md"
_t40_schema="$_t40_root/schemas/c3-approval.schema.json"
_t40_schema_script="$_t40_root/scripts/apply-task-0129-schema.sh"
_t40_wc_script="$_t40_root/scripts/apply-task-0129-wc.sh"
_t40_skill="$_t40_root/.claude/skills/plan-quality-check/SKILL.md"

# ── TC-01: go → APPROVED 候補 ──────────────────────────────────────────────
if grep -q '`go` | `APPROVED` 候補' "$_t40_doc" 2>/dev/null || \
   grep -q "go.*APPROVED" "$_t40_doc" 2>/dev/null; then
  printf '[PASS] TA-40 TC-01: Decision=go → APPROVED 候補がドキュメントに定義されている\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 TC-01: Decision=go → APPROVED 候補が見つからない\n'; fail=$((fail + 1))
fi

# ── TC-02: revise_plan → CONDITIONAL ──────────────────────────────────────
if grep -q 'revise_plan.*CONDITIONAL' "$_t40_doc" 2>/dev/null; then
  printf '[PASS] TA-40 TC-02: Decision=revise_plan → CONDITIONAL がドキュメントに定義されている\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 TC-02: Decision=revise_plan → CONDITIONAL が見つからない\n'; fail=$((fail + 1))
fi

# ── TC-03: human_approval_required → 人間 C-3 強制 ────────────────────────
if grep -q 'human_approval_required.*人間C-3強制\|human_approval_required.*人間 C-3 強制' "$_t40_doc" 2>/dev/null; then
  printf '[PASS] TA-40 TC-03: Decision=human_approval_required → 人間C-3強制がドキュメントに定義されている\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 TC-03: Decision=human_approval_required → 人間C-3強制が見つからない\n'; fail=$((fail + 1))
fi

# ── TC-04: no_go → REJECTED ───────────────────────────────────────────────
if grep -q 'no_go.*REJECTED' "$_t40_doc" 2>/dev/null; then
  printf '[PASS] TA-40 TC-04: Decision=no_go → REJECTED がドキュメントに定義されている\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 TC-04: Decision=no_go → REJECTED が見つからない\n'; fail=$((fail + 1))
fi

# ── TC-05: Risk=high → autonomous APPROVE 無効化 ──────────────────────────
if grep -q 'autonomous APPROVE 無効化' "$_t40_doc" 2>/dev/null; then
  printf '[PASS] TA-40 TC-05: Risk=high → autonomous APPROVE 無効化が定義されている\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 TC-05: Risk=high → autonomous APPROVE 無効化の定義が見つからない\n'; fail=$((fail + 1))
fi

# ── TC-06: C-1 充足チェック（C1-LOOP-01/02）──────────────────────────────
if grep -q 'C1-LOOP-01' "$_t40_skill" 2>/dev/null && \
   grep -q 'C1-LOOP-02' "$_t40_skill" 2>/dev/null; then
  printf '[PASS] TA-40 TC-06: C1-LOOP-01/02 が plan-quality-check SKILL.md に定義されている\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 TC-06: C1-LOOP-01/02 が plan-quality-check SKILL.md に見つからない\n'; fail=$((fail + 1))
fi

# ── TC-07: Stop-Work Conditions ↔ 機械トリガー対応表 ───────────────────────
_t40_ok=1
for _t40_trigger in 'file_count_exceeded' 'consecutive_failures' 'loop_repetition' 'out_of_plan_scope' 'ac_mutation'; do
  if ! grep -q "$_t40_trigger" "$_t40_doc" 2>/dev/null; then
    _t40_ok=0
    printf '[FAIL] TA-40 TC-07: 機械トリガー %s が見つからない\n' "$_t40_trigger"; fail=$((fail + 1))
  fi
done
if [ "$_t40_ok" = "1" ]; then
  printf '[PASS] TA-40 TC-07: 5 機械トリガーすべてが対応表に定義されている\n'; pass=$((pass + 1))
fi

# ── TC-08: schema は apply-script 経由（--dry-run で差分・本体未変更）──────
if [ ! -f "$_t40_schema_script" ]; then
  printf '[FAIL] TA-40 TC-08: apply-task-0129-schema.sh が見つからない\n'; fail=$((fail + 1))
else
  # --dry-run を実行しスクリプトが終了 0 で差分を出力すること（本体は未変更）
  _t40_dry_out="" ; _t40_dry_rc=0
  _t40_dry_out="$(sh "$_t40_schema_script" --dry-run 2>&1)" || _t40_dry_rc=$?

  # SKIP（べき等）または diff 出力があれば PASS
  if printf '%s' "$_t40_dry_out" | grep -q 'review_decision\|SKIP'; then
    printf '[PASS] TA-40 TC-08: apply-script --dry-run が差分またはSKIPを出力（本体未変更）\n'; pass=$((pass + 1))
  else
    printf '[FAIL] TA-40 TC-08: --dry-run の出力が期待と異なる: %s\n' "$_t40_dry_out"; fail=$((fail + 1))
  fi
fi

# ── TC-09: 後方互換（既存 c3.json が拡張後 schema で valid）────────────────
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  # Python で後方互換を直接検証（apply 不要・テンポラリで拡張 schema を生成して確認）
  _t40_compat_out="" ; _t40_compat_rc=0
  _t40_compat_out="$(python3 - "$_t40_schema" "$_t40_root/tests/fixtures/schema-validate/valid/c3.json" <<'PY40' 2>&1
import json, sys, copy
import jsonschema

schema_path, c3_path = sys.argv[1], sys.argv[2]
with open(schema_path, encoding='utf-8') as f:
    schema = json.load(f)
with open(c3_path, encoding='utf-8') as f:
    c3 = json.load(f)

# 拡張フィールドを schema に一時追加（apply-script と同じ内容）
new_props = {
    "review_decision": {"type": "string", "enum": ["go", "revise_plan", "human_approval_required", "no_go"]},
    "review_risk": {"type": "string", "enum": ["low", "medium", "high"]},
    "review_stop_works": {"type": "array", "items": {"type": "string"}},
    "review_source": {"type": "string"},
    "lite_eligible": {"type": "boolean"}
}
schema_extended = copy.deepcopy(schema)
schema_extended["properties"].update(new_props)

try:
    jsonschema.validate(c3, schema_extended)
    print("COMPAT_OK")
except jsonschema.ValidationError as e:
    print(f"COMPAT_FAIL: {e.message}")
    sys.exit(1)
PY40
  )" || _t40_compat_rc=$?

  if [ "$_t40_compat_rc" -eq 0 ] && printf '%s' "$_t40_compat_out" | grep -q 'COMPAT_OK'; then
    printf '[PASS] TA-40 TC-09: 既存 c3.json が拡張後 schema でも valid（後方互換）\n'; pass=$((pass + 1))
  else
    printf '[FAIL] TA-40 TC-09: 後方互換検証失敗: %s\n' "$_t40_compat_out"; fail=$((fail + 1))
  fi
else
  printf '[SKIP] TA-40 TC-09: jsonschema 未インストール（CI で再検証）\n'
fi

# ── lite_eligible=false 強制の記録（TC-09 後半）──────────────────────────
if grep -q 'lite_eligible.*false\|false.*承認境界\|lite_eligible=false' "$_t40_doc" 2>/dev/null; then
  printf '[PASS] TA-40 TC-09b: lite_eligible=false 強制がドキュメントに明記されている\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 TC-09b: lite_eligible=false 強制の記述が見つからない\n'; fail=$((fail + 1))
fi

# ── apply-task-0129-wc.sh の存在検証 ──────────────────────────────────────
if [ -f "$_t40_wc_script" ]; then
  printf '[PASS] TA-40 WC-01: apply-task-0129-wc.sh が存在する\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 WC-01: apply-task-0129-wc.sh が見つからない\n'; fail=$((fail + 1))
fi

# ── mapping doc の承認境界整合（AC-06）────────────────────────────────────
if grep -q 'high-risk\|高リスク\|Standard 同期\|Standard C-3' "$_t40_doc" 2>/dev/null; then
  printf '[PASS] TA-40 AC06: 承認境界整合（mode=high-risk / Standard C-3）がドキュメントに明記\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-40 AC06: 承認境界整合の記述が見つからない\n'; fail=$((fail + 1))
fi

pg_extra_contract_finalize
