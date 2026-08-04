# tests/extras/ta-44-eh457-cli-wiring.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0143 AC-01/02/04/07: EH-4/5/7 CLI 配線テスト
#
# TC-01: apply-script 未適用 → SKIP
# TC-02（apply 後）: EH-4 strict — test-cases.md なし → exit 1
# TC-03（apply 後）: EH-4 — test-cases.md あり → exit 0
# TC-04（apply 後）: doctor 出力に CLI Hook Wiring セクションが含まれる
# TC-05（apply 後）: doctor が check-test-cases.sh を報告する
#
# hook スクリプトは REPO_ROOT/docs/working/ を内部計算するため
# サンドボックスも同 REPO 配下に一時 TASK ディレクトリを作成する

printf '\n=== TA-44: EH-4/5/7 CLI Wiring (TASK-0143) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T44_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T44_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T44_BIN="$_T44_ROOT/bin/plangate"

t44_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t44_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# ── 適用済み確認 ─────────────────────────────────────────────────
_T44_APPLIED=0
if grep -q 'check-test-cases\.sh' "$_T44_BIN" 2>/dev/null && \
   grep -q 'check-verification-evidence\.sh' "$_T44_BIN" 2>/dev/null; then
  _T44_APPLIED=1
fi

if [ "$_T44_APPLIED" = "0" ]; then
  _T44_SCRIPT="$_T44_ROOT/scripts/apply-task-0143-eh457-wiring.sh"
  if [ -f "$_T44_SCRIPT" ]; then
    _dry_out=$(sh "$_T44_SCRIPT" --dry-run 2>&1 || true)
    if printf '%s' "$_dry_out" | grep -q 'check-test-cases\|Patch 1'; then
      printf '  [SKIP] TC-02~05: apply-task-0143-eh457-wiring.sh --apply 実行前 (dry-run 差分 OK)\n'
    else
      t44_fail "apply-script が期待差分を生成しない: $_dry_out"
    fi
  else
    printf '  [SKIP] TC-02~05: apply-script 未作成\n'
  fi
  return 0 2>/dev/null || exit 0
fi

# ── TC-01: 適用済み確認 ──────────────────────────────────────────
t44_pass "TC-01: apply 適用済み (bin/plangate に check-test-cases.sh 配線あり)"

# ── サンドボックス: REPO 配下に一時 TASK ディレクトリを作成 ──────
# hook スクリプトが REPO_ROOT を内部計算するため、実際の docs/working/ 配下を使う
_T44_TASK_NONE="TASK-T4400-ta44-tmp"
_T44_TASK_OK="TASK-T4401-ta44-tmp"
_T44_WDIR="$_T44_ROOT/docs/working"
mkdir -p "$_T44_WDIR/$_T44_TASK_NONE" "$_T44_WDIR/$_T44_TASK_OK"
touch "$_T44_WDIR/$_T44_TASK_OK/test-cases.md"
# register_cleanup を使って run-tests.sh の一括削除に委譲
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T44_WDIR/$_T44_TASK_NONE"
  register_cleanup "$_T44_WDIR/$_T44_TASK_OK"
fi

# ── TC-02: EH-4 strict — test-cases.md なし → exit 1 ────────────
rc=0
PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK="$_T44_TASK_NONE" \
  sh "$_T44_ROOT/scripts/hooks/check-test-cases.sh" "$_T44_TASK_NONE" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
  t44_pass "TC-02 AC-01: EH-4 strict, test-cases.md なし → exit 1"
else
  t44_fail "TC-02 AC-01: EH-4 strict で exit 1 にならない (rc=$rc)"
fi

# ── TC-03: EH-4 — test-cases.md あり → exit 0 ───────────────────
rc=0
PLANGATE_HOOK_TASK="$_T44_TASK_OK" \
  sh "$_T44_ROOT/scripts/hooks/check-test-cases.sh" "$_T44_TASK_OK" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 0 ]; then
  t44_pass "TC-03 AC-01: EH-4, test-cases.md あり → exit 0"
else
  t44_fail "TC-03 AC-01: EH-4 PASS で exit 0 にならない (rc=$rc)"
fi

# ── TC-04: doctor 出力に CLI Hook Wiring セクションが含まれる ────
_doctor_out=$("$_T44_BIN" doctor 2>&1 || true)
if printf '%s' "$_doctor_out" | grep -q 'CLI Hook Wiring'; then
  t44_pass "TC-04 AC-07: doctor 出力に 'CLI Hook Wiring' セクションあり"
else
  t44_fail "TC-04 AC-07: doctor 出力に 'CLI Hook Wiring' なし"
fi

# ── TC-05: doctor が check-test-cases.sh を報告 ──────────────────
if printf '%s' "$_doctor_out" | grep -q 'check-test-cases'; then
  t44_pass "TC-05 AC-07: doctor が check-test-cases.sh を認識"
else
  t44_fail "TC-05 AC-07: doctor が check-test-cases.sh を報告しない"
fi

# ── クリーンアップ（register_cleanup 未使用環境向け） ──────────
if ! command -v register_cleanup >/dev/null 2>&1; then
  rm -rf "$_T44_WDIR/$_T44_TASK_NONE" "$_T44_WDIR/$_T44_TASK_OK" 2>/dev/null || true
fi
