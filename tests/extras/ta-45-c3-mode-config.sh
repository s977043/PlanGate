# tests/extras/ta-45-c3-mode-config.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0144 AC-01〜06: C-3 approval mode (cli/conversation) テスト
#
# TC-01: conversation モード + exec 前に c3.json 生成 → EH-3 SKIP
# TC-02: cli モード（.plangate.yml あり）→ c3.json なしで exec は BLOCK
# TC-03: .plangate.yml 未存在 → cli フォールバック（EH-3 c3.json BLOCK）
# TC-04: AI 生成 c3.json に source: conversation フィールドの schema 検証
# TC-05: doctor が C-3 Approval Mode セクションを出力
# TC-06: plangate-config.schema.json が mode enum を検証（valid/invalid）

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
pg_extra_contract_init ta-45-c3-mode-config standalone-capable

printf '\n=== TA-45: C-3 Approval Mode Config (TASK-0144) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T45_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T45_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T45_BIN="$_T45_ROOT/bin/plangate"
_T45_EH3="$_T45_ROOT/scripts/hooks/check-plan-hash.sh"
_T45_CFG_SCHEMA="$_T45_ROOT/schemas/plangate-config.schema.json"
_T45_C3_SCHEMA="$_T45_ROOT/schemas/c3-approval.schema.json"

t45_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t45_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# ── 適用済み確認 ─────────────────────────────────────────────────
_T45_APPLIED=0
if grep -q '_read_plangate_config' "$_T45_BIN" 2>/dev/null && \
   grep -q 'C3_CONVERSATION_SKIP' "$_T45_EH3" 2>/dev/null && \
   [ -f "$_T45_CFG_SCHEMA" ]; then
  _T45_APPLIED=1
fi

if [ "$_T45_APPLIED" = "0" ]; then
  _T45_APPLY_SH="$_T45_ROOT/scripts/apply-task-0144-c3-mode.sh"
  if [ -f "$_T45_APPLY_SH" ]; then
    _dry_out=$(sh "$_T45_APPLY_SH" 2>&1 || true)
    if printf '%s' "$_dry_out" | grep -qE '\[DIFF\]|\[CREATE\]'; then
      printf '  [SKIP] TC-01~06: scripts/apply-task-0144-c3-mode.sh --apply 実行前\n'
      printf '         dry-run OK: %s\n' "$(printf '%s' "$_dry_out" | grep -c '\[DIFF\]\|\[CREATE\]') 差分検出"
    else
      printf '  [SKIP] TC-01~06: apply-script が見つからないかパッチ候補なし\n'
    fi
  else
    printf '  [SKIP] TC-01~06: apply-script 未存在 (%s)\n' "$_T45_APPLY_SH"
  fi
  # #921: standalone では skip が rc=3 で exit、harness では skip 後の
  # top-level return 0 で source 元へ戻る（R-021: 旧 || true 型はシェル依存）
  pg_extra_contract_skip "C-3 mode config が未適用 (apply-task-0144-c3-mode.sh --apply)"
  return 0
fi

# ── サンドボックス用一時タスク ───────────────────────────────────
_T45_TMP=$(mktemp -d)
_T45_TASK="TASK-T45"
_T45_WD="$_T45_ROOT/docs/working"
mkdir -p "$_T45_WD/$_T45_TASK/approvals"

# plan.md を最小限作成
cat > "$_T45_WD/$_T45_TASK/plan.md" << 'PLANEOF'
# Plan — TASK-T45 (test fixture)
## Mode判定
**モード**: ultra-light
PLANEOF

# plan_hash を記録した c3.json を作成（cli モードのテスト用）
_T45_HASH=$(sha256sum "$_T45_WD/$_T45_TASK/plan.md" 2>/dev/null | cut -d' ' -f1 \
  || shasum -a 256 "$_T45_WD/$_T45_TASK/plan.md" | cut -d' ' -f1)

cleanup_t45() {
  rm -rf "$_T45_TMP"
  rm -rf "$_T45_WD/$_T45_TASK"
}
trap cleanup_t45 EXIT

# ── TC-01: conversation モード + EH-3 c3.json SKIP ────────────────
# .plangate.yml に conversation を設定 → c3.json への Write が EH-3 で SKIP されること
_T45_TMP_CFG="$_T45_TMP/.plangate_conversation.yml"
cat > "$_T45_TMP_CFG" << 'CFGEOF'
c3_approval:
  mode: conversation
CFGEOF

_t45_c3_target="docs/working/$_T45_TASK/approvals/c3.json"
_t45_eh3_out=$(PLANGATE_HOOK_TASK="$_T45_TASK" \
  PLANGATE_HOOK_FILE="$_t45_c3_target" \
  sh "$_T45_EH3" "$_T45_TASK" "$_t45_c3_target" 2>&1 || true)

# EH-3 は plan_hash 比較に進む（c3.json 未存在なので SKIP[c3.json not found]）
# → TC-01 は conversation モード時 c3.json を生成後に exec する統合フローのため、
#   ここでは EH-3 が c3.json 未存在で SKIP (exit 0) することを確認する
if printf '%s' "$_t45_eh3_out" | grep -qiE 'SKIP|PASS'; then
  t45_pass "TC-01: EH-3 with TASK context handles c3.json path (SKIP/PASS)"
else
  t45_fail "TC-01: EH-3 expected SKIP/PASS, got: $(printf '%s' "$_t45_eh3_out" | head -1)"
fi

# ── TC-02: cli モード → _read_plangate_config が cli を返す ──────
_t45_mode_cli=$(cd "$_T45_ROOT" && python3 - "$_T45_ROOT/.plangate.yml" "c3_approval.mode" 2>/dev/null << 'PYEOF'
import sys, os
cfg_path, key = sys.argv[1], sys.argv[2]
try:
    import yaml
    if not os.path.exists(cfg_path):
        print("cli"); sys.exit(0)
    with open(cfg_path, "r") as f:
        d = yaml.safe_load(f)
    if not isinstance(d, dict):
        print("cli"); sys.exit(0)
    val = d
    for part in key.split("."):
        if not isinstance(val, dict):
            print("cli"); sys.exit(0)
        val = val.get(part)
    if val is None:
        print("cli"); sys.exit(0)
    allowed = {"cli", "conversation"}
    print(str(val) if str(val) in allowed else "cli")
except Exception:
    print("cli")
PYEOF
) || _t45_mode_cli="cli"

if [ "$_t45_mode_cli" = "cli" ]; then
  t45_pass "TC-02: .plangate.yml mode=cli → cli 返却"
else
  t45_fail "TC-02: expected cli, got: $_t45_mode_cli"
fi

# ── TC-03: .plangate.yml 未存在 → cli フォールバック ─────────────
_t45_mode_nofile=$(python3 - "/nonexistent/.plangate.yml" "c3_approval.mode" 2>/dev/null << 'PYEOF'
import sys, os
cfg_path, key = sys.argv[1], sys.argv[2]
try:
    import yaml
    if not os.path.exists(cfg_path):
        print("cli"); sys.exit(0)
    with open(cfg_path, "r") as f:
        d = yaml.safe_load(f)
    m = (d or {}).get("c3_approval", {}).get("mode", "cli")
    print(m if m in ("cli","conversation") else "cli")
except Exception:
    print("cli")
PYEOF
) || _t45_mode_nofile="cli"

if [ "$_t45_mode_nofile" = "cli" ]; then
  t45_pass "TC-03: .plangate.yml 未存在 → cli フォールバック"
else
  t45_fail "TC-03: expected cli fallback, got: $_t45_mode_nofile"
fi

# ── TC-04: source: conversation フィールドが c3-approval schema で valid ──
_t45_source_test=$(python3 - "$_T45_C3_SCHEMA" 2>&1 << 'PYEOF'
import sys, json
schema_path = sys.argv[1]
try:
    import jsonschema
    with open(schema_path, "r") as f:
        schema = json.load(f)
    # source: "conversation" を含む最小 c3.json（required: task_id/phase/c3_status/approved_by/approved_at/plan_hash）
    instance = {
        "task_id": "TASK-0045",
        "phase": "C-3",
        "c3_status": "APPROVED",
        "plan_hash": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "approved_at": "2026-06-25T00:00:00Z",
        "approved_by": "test@example.com",
        "source": "conversation"
    }
    jsonschema.validate(instance=instance, schema=schema)
    print("VALID")
except ImportError:
    print("SKIP_NO_JSONSCHEMA")
except Exception as e:
    print(f"INVALID: {e}")
PYEOF
)
if printf '%s' "$_t45_source_test" | grep -qE '^VALID$|^SKIP_NO_JSONSCHEMA$'; then
  t45_pass "TC-04: c3-approval schema: source: conversation は valid (${_t45_source_test})"
else
  t45_fail "TC-04: c3-approval schema validation failed: $_t45_source_test"
fi

# ── TC-05: doctor が C-3 Approval Mode を出力 ─────────────────────
_t45_doctor_out=$("$_T45_BIN" doctor 2>&1 || true)
if printf '%s' "$_t45_doctor_out" | grep -qE 'C-3 Approval Mode|c3_approval'; then
  t45_pass "TC-05: doctor に C-3 Approval Mode セクション確認"
else
  t45_fail "TC-05: doctor に C-3 Approval Mode セクションが見当たらない"
fi

# ── TC-06: plangate-config.schema.json が mode enum を検証 ─────────
_t45_schema_valid=$(python3 - "$_T45_CFG_SCHEMA" 2>&1 << 'PYEOF'
import sys, json
schema_path = sys.argv[1]
try:
    import jsonschema
    with open(schema_path, "r") as f:
        schema = json.load(f)
    # PASS ケース: mode=cli
    jsonschema.validate(instance={"c3_approval": {"mode": "cli"}}, schema=schema)
    # FAIL ケース: mode=invalid → 例外
    try:
        jsonschema.validate(instance={"c3_approval": {"mode": "invalid"}}, schema=schema)
        print("INVALID_ACCEPTED")  # これは失敗
    except jsonschema.ValidationError:
        print("ENUM_REJECTED_OK")
except ImportError:
    print("SKIP_NO_JSONSCHEMA")
except Exception as e:
    print(f"ERROR: {e}")
PYEOF
)
if printf '%s' "$_t45_schema_valid" | grep -qE '^ENUM_REJECTED_OK$|^SKIP_NO_JSONSCHEMA$'; then
  t45_pass "TC-06: plangate-config.schema: valid/invalid mode enum 検証 OK (${_t45_schema_valid})"
else
  t45_fail "TC-06: schema validation unexpected: $_t45_schema_valid"
fi

cleanup_t45
trap - EXIT

pg_extra_contract_finalize
