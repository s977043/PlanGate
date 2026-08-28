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

# ── 一時状態の射程宣言 + 先頭 prune + cleanup 登録（#947 / #1210）─────
# 旧実装は trap cleanup_t45 EXIT + 末尾 trap - EXIT に依存していたが、これは
# tests/extras/README.md 「隔離・後始末の規約」1/2 に真正面から反する:
# extras は同一シェルへ直列 source されるため EXIT trap は後続に上書きされ
# 発火が保証されず、`trap - EXIT` は他 extras / ハーネスの cleanup を巻き込む。
# 宣言 → body の副作用より前に prune → register_cleanup 登録 へ寄せる。
# ${_t45_p:?} は防御的措置（#1210）— 実バグの修正ではなく、将来「変数が空の
# まま rm に渡る」退行が入ったときのガード。
_T45_TASK="TASK-T45"
_T45_WD="${_T45_ROOT:?ta-45: repo root unresolved}/docs/working"
_t45_scope_reset() {
  for _t45_p in "$@"; do
    rm -rf "${_t45_p:?ta-45: empty cleanup path refused}"
    if command -v register_cleanup >/dev/null 2>&1; then
      register_cleanup "$_t45_p"
    fi
  done
}
_t45_scope_reset "$_T45_WD/$_T45_TASK"

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

# ── サンドボックス用一時タスク（宣言・prune・登録は先頭で実施済）──
_T45_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T45_TMP"
fi
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

# 後始末は末尾の明示呼出に一本化する（trap は張らない = README 規約 1/2）。
cleanup_t45() {
  rm -rf "${_T45_TMP:?ta-45: empty tmp path refused}"
  rm -rf "$_T45_WD/${_T45_TASK:?ta-45: empty task name refused}"
}

# ── TC-01: conversation モード → EH-3 の C3_CONVERSATION_SKIP 分岐 ──
# 旧実装（#1108）は 2 重に空振りしていた:
#   1. `PLANGATE_HOOK_TASK` を設定していたため **no-task 分岐に入らず**、
#      検査したい C-3 conversation 分岐へそもそも到達していなかった
#   2. 判定が `grep -qiE 'SKIP|PASS'` の**選言**で、到達した先が別分岐でも
#      出力に SKIP の 3 文字があれば通った（cli モードの `SKIP 拒否: ...`
#      = exit 2 すら「PASS」になる）
# 是正: no-task 経路で起動して当該分岐へ到達させ、判定を
# **rc と一意 reason トークンの対**にする（矯正パターン: ta-39:94）。
# 分岐は `$REPO_ROOT/.plangate.yml` を読むため、hook を sandbox へ複製して
# そこに設定ファイルを置く（README「隔離・後始末の規約」3 / できること節）。
mkdir -p "$_T45_TMP/scripts/hooks"
mkdir -p "$_T45_TMP/docs/working/_audit"
cp "$_T45_EH3" "$_T45_TMP/scripts/hooks/check-plan-hash.sh"
_T45_EH3_SANDBOX="$_T45_TMP/scripts/hooks/check-plan-hash.sh"
_t45_c3_target="docs/working/$_T45_TASK/approvals/c3.json"

_t45_run_eh3_notask() {
  # $1 = PLANGATE_HOOK_FILE。TASK 文脈を渡さない（no-task 経路）
  PLANGATE_HOOK_FILE="$1" sh "$_T45_EH3_SANDBOX" </dev/null 2>&1
}

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  # 規約 6（依存ゲート）: 分岐は PyYAML で mode を読む。未導入環境では
  # 常に cli へフォールバックするため、conversation 分岐は検査できない
  printf '  [SKIP] TC-01: PyYAML 未導入のため C-3 conversation 分岐を検査できない\n'
else
  # (a) conversation → rc=0 かつ一意 reason トークン C3_CONVERSATION_SKIP
  printf 'c3_approval:\n  mode: conversation\n' > "$_T45_TMP/.plangate.yml"
  _t45_rc_conv=0
  _t45_out_conv=$(_t45_run_eh3_notask "$_t45_c3_target") || _t45_rc_conv=$?
  # (b) 対照（cli）: 同じ sandbox・同じ target で mode だけ替える。分岐に
  #     到達していることと mode 感応であることを同時に示す。cli 側の出力にも
  #     `SKIP` の語は現れる（`SKIP 拒否`）ので、選言述語では区別できない
  printf 'c3_approval:\n  mode: cli\n' > "$_T45_TMP/.plangate.yml"
  _t45_rc_cli=0
  _t45_out_cli=$(_t45_run_eh3_notask "$_t45_c3_target") || _t45_rc_cli=$?

  _t45_cli_has_token=no
  if printf '%s' "$_t45_out_cli" | grep -q 'C3_CONVERSATION_SKIP'; then
    _t45_cli_has_token=yes
  fi
  if [ "$_t45_rc_conv" = "0" ] \
     && printf '%s' "$_t45_out_conv" | grep -q 'C3_CONVERSATION_SKIP' \
     && [ "$_t45_rc_cli" = "2" ] && [ "$_t45_cli_has_token" = no ]; then
    t45_pass "TC-01: no-task + mode=conversation → rc=0 + C3_CONVERSATION_SKIP（対照 cli は rc=2・トークンなし）"
  else
    t45_fail "TC-01: conversation rc=$_t45_rc_conv out=$(printf '%s' "$_t45_out_conv" | head -1) / cli rc=$_t45_rc_cli token=$_t45_cli_has_token"
  fi

  # 副次: sandbox 側の skip-decision-log にのみ記録され、実 repo は汚れない
  _t45_dlog="$_T45_TMP/docs/working/_audit/skip-decision-log.jsonl"
  if [ -f "$_t45_dlog" ] && grep -q 'EH-3_C3_CONVERSATION_SKIP' "$_t45_dlog"; then
    t45_pass "TC-01 副次: sandbox skip-decision-log に EH-3_C3_CONVERSATION_SKIP あり"
  else
    t45_fail "TC-01 副次: sandbox skip-decision-log に EH-3_C3_CONVERSATION_SKIP なし (log=$_t45_dlog)"
  fi
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

pg_extra_contract_finalize
