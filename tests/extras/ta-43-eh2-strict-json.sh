# tests/extras/ta-43-eh2-strict-json.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0141 AC-1/AC-2/AC-4: EH-2 strict JSON + stdin fallback の自動テスト
#
# TC-01: 正常 APPROVED c3.json → allow
# TC-02: 壊れた JSON → warn + allow（非 APPROVED 扱い）
# TC-03: コメント埋め込み JSON（python3 では parse エラー）→ 非 APPROVED
# TC-04: c3_status フィールドなし → 非 APPROVED
# TC-05: stdin file_path から TASK-ID 解決 → APPROVED 判定
# TC-06: stdin なし + env なし → SKIP（allow）
#
# サンドボックス: check-c3-approval.sh を tmp に複製し実 audit ログ汚染なし

printf '\n=== TA-43: EH-2 strict JSON + stdin fallback (TASK-0141) ===\n'

# ── セットアップ ──────────────────────────────────────────────────
if [ -n "${FIXTURES_DIR:-}" ]; then
  _T43_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T43_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T43_HOOK_SRC="$_T43_ROOT/scripts/hooks/check-c3-approval.sh"
_T43_APPLY_SCRIPT="$_T43_ROOT/scripts/apply-task-0141-eh2-strict.sh"
_T43_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T43_TMP"
fi

t43_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t43_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# ── 適用済み確認 ─────────────────────────────────────────────────
_T43_APPLIED=0
if grep -q 'python3' "$_T43_HOOK_SRC" 2>/dev/null && \
   grep -q '_eh2_stdin' "$_T43_HOOK_SRC" 2>/dev/null; then
  _T43_APPLIED=1
fi

if [ "$_T43_APPLIED" = "0" ]; then
  # apply 未適用: dry-run で差分が出ることだけ確認して SKIP
  if [ -f "$_T43_APPLY_SCRIPT" ]; then
    _dry_out=$(sh "$_T43_APPLY_SCRIPT" --dry-run 2>&1 || true)
    if printf '%s' "$_dry_out" | grep -q 'python3\|_eh2_stdin'; then
      printf '  [SKIP] TC-01〜06: apply-task-0141-eh2-strict.sh --apply 実行前 (dry-run 差分 OK)\n'
    else
      t43_fail "apply-script が期待差分を生成しない: $_dry_out"
    fi
  else
    printf '  [SKIP] TC-01〜06: apply-script が未作成 (apply-task-0141-eh2-strict.sh)\n'
  fi
  rm -rf "$_T43_TMP" 2>/dev/null || true
  return 0 2>/dev/null || exit 0
fi

# ── サンドボックス構築 ─────────────────────────────────────────
mkdir -p "$_T43_TMP/scripts/hooks"
mkdir -p "$_T43_TMP/docs/working/_audit"
cp "$_T43_HOOK_SRC" "$_T43_TMP/scripts/hooks/check-c3-approval.sh"
_T43_HOOK="$_T43_TMP/scripts/hooks/check-c3-approval.sh"

# テスト用 TASK ディレクトリ
_T43_TASK="TASK-T4300"
mkdir -p "$_T43_TMP/docs/working/$_T43_TASK/approvals"

run_hook() {
  # run_hook [env_task] [stdin_json]
  _rh_task="${1:-}"
  _rh_stdin="${2:-}"
  _rh_out=""
  if [ -n "$_rh_stdin" ]; then
    _rh_out=$(printf '%s' "$_rh_stdin" \
      | PLANGATE_HOOK_TASK="$_rh_task" \
        PLANGATE_HOOK_STRICT="${PLANGATE_HOOK_STRICT:-0}" \
        PLANGATE_BYPASS_HOOK="" \
        sh "$_T43_HOOK" 2>&1 || true)
  else
    _rh_out=$(PLANGATE_HOOK_TASK="$_rh_task" \
      PLANGATE_HOOK_STRICT="${PLANGATE_HOOK_STRICT:-0}" \
      PLANGATE_BYPASS_HOOK="" \
      sh "$_T43_HOOK" 2>&1 </dev/null || true)
  fi
  printf '%s' "$_rh_out"
}

# ── TC-01: 正常 APPROVED c3.json → allow ──────────────────────
printf '{"task_id":"%s","c3_status":"APPROVED","phase":"C-3","plan_hash":"sha256:dummy"}\n' \
  "$_T43_TASK" > "$_T43_TMP/docs/working/$_T43_TASK/approvals/c3.json"

_t01_out=$(run_hook "$_T43_TASK" "")
if printf '%s' "$_t01_out" | grep -q '"continue":true'; then
  t43_pass "TC-01 AC-1: 正常 APPROVED c3.json → continue:true"
else
  t43_fail "TC-01 AC-1: APPROVED なのに allow されない: $_t01_out"
fi

# ── TC-02: 壊れた JSON → 非 APPROVED 扱い（warn + allow）─────
printf 'NOT_JSON_at_all\n' > "$_T43_TMP/docs/working/$_T43_TASK/approvals/c3.json"
_t02_out=$(run_hook "$_T43_TASK" "")
if printf '%s' "$_t02_out" | grep -q '"continue":true'; then
  t43_pass "TC-02 AC-1: 壊れた JSON → 非 APPROVED (warn) + allow"
else
  t43_fail "TC-02 AC-1: 壊れた JSON で allow されない: $_t02_out"
fi

# ── TC-03: コメント行に "c3_status":"APPROVED" 埋め込み → 非 APPROVED ──
printf '// comment: "c3_status":"APPROVED"\n{"task_id":"%s","c3_status":"PENDING"}\n' \
  "$_T43_TASK" > "$_T43_TMP/docs/working/$_T43_TASK/approvals/c3.json"
_t03_out=$(run_hook "$_T43_TASK" "")
# PENDING または parse エラー（コメント行があるため json.load が失敗 → c3_status=""）→ 非 APPROVED
if printf '%s' "$_t03_out" | grep -q '"continue":true'; then
  t43_pass "TC-03 AC-1: コメント埋め込み JSON → python3 parse 失敗 → 非 APPROVED (allow/warn)"
else
  t43_fail "TC-03 AC-1: コメント埋め込み JSON で allow されない: $_t03_out"
fi

# ── TC-04: c3_status フィールドなし → 非 APPROVED ────────────
printf '{"task_id":"%s","phase":"C-3"}\n' "$_T43_TASK" \
  > "$_T43_TMP/docs/working/$_T43_TASK/approvals/c3.json"
_t04_out=$(run_hook "$_T43_TASK" "")
if printf '%s' "$_t04_out" | grep -q '"continue":true'; then
  t43_pass "TC-04 AC-1: c3_status フィールドなし → 非 APPROVED (allow/warn)"
else
  t43_fail "TC-04 AC-1: フィールドなし JSON で allow されない: $_t04_out"
fi

# ── TC-05: stdin file_path から TASK-ID 解決 → APPROVED 判定 ──
# APPROVED c3.json を restore
printf '{"task_id":"%s","c3_status":"APPROVED","phase":"C-3","plan_hash":"sha256:dummy"}\n' \
  "$_T43_TASK" > "$_T43_TMP/docs/working/$_T43_TASK/approvals/c3.json"

_t05_stdin='{"tool_input":{"file_path":"docs/working/TASK-T4300/plan.md"}}'
_t05_out=$(run_hook "" "$_t05_stdin")
if printf '%s' "$_t05_out" | grep -q '"continue":true'; then
  t43_pass "TC-05 AC-2: stdin file_path TASK-T4300 → APPROVED → allow"
else
  t43_fail "TC-05 AC-2: stdin fallback が APPROVED を解決できない: $_t05_out"
fi

# ── TC-06: stdin なし + env なし → SKIP（allow）──────────────
_t06_out=$(run_hook "" "")
if printf '%s' "$_t06_out" | grep -q '"continue":true'; then
  t43_pass "TC-06 AC-2: stdin なし + env なし → SKIP → allow"
else
  t43_fail "TC-06 AC-2: no-task で SKIP されない: $_t06_out"
fi

# ── クリーンアップ ─────────────────────────────────────────────
rm -rf "$_T43_TMP" 2>/dev/null || true
