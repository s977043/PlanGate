# tests/extras/ta-72-extras-progress.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# extras の「失敗属性化」機構（進行マーカー / 所要時間レポート / ウォッチドッグ /
# Step Summary）の回帰テスト。
#
# 背景: extras は 1 プロセスで直列 source される。CI の job timeout で殺されると
#   どの ta-NN が原因か分からず全滅していた（per-file timeout は無い。extras が
#   pass / fail / register_cleanup を共有するため、サブプロセス隔離は集計を壊す）。
#   run-tests.sh は代わりに source 直前のマーカー・事後の所要時間レポート・
#   別プロセスのウォッチドッグで犯人を一意に指す。
#
#   TC-01: 進行マーカーの printf が `. "$extra"` より **前** にある
#   TC-02: 所要時間レポート（遅い順）の実装が存在する
#   TC-03: ウォッチドッグの既定閾値が存在し、CI の job timeout より小さい
#   TC-04: Step Summary への追記が GITHUB_STEP_SUMMARY 有無でガードされている
#   TC-05: 動的 — 各 extras の開始マーカーが glob 順に全件出る
#   TC-06: 動的 — 失敗がファイル単位で属性化される（new failures: N）
#   TC-07: 動的 — 変異注入（マーカー printf を削った runner）ではマーカーが消える
#          ＝ TC-05 の検出力の実証（陰性コントロール）
#   TC-08: 動的 — GITHUB_STEP_SUMMARY に失敗ファイル表と遅いファイル表が入る
#   TC-09: 動的 — ウォッチドッグが閾値超過ファイル名を出力する

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
pg_extra_contract_init ta-72-extras-progress standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-72: extras progress markers / timing / watchdog ===\n'

t72_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t72_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T72_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T72_RUNNER="$_T72_ROOT/tests/run-tests.sh"

# === TC-01 マーカーは source より前 ===
_t72_marker_line=$(grep -n 'extras\] >>>' "$_T72_RUNNER" | head -1 | cut -d: -f1)
_t72_source_line=$(grep -n '^[[:space:]]*\. "\$extra"' "$_T72_RUNNER" | head -1 | cut -d: -f1)
if [ -n "$_t72_marker_line" ] && [ -n "$_t72_source_line" ] && [ "$_t72_marker_line" -lt "$_t72_source_line" ]; then
  t72_pass "TC-01 進行マーカーが source 行より前に出力される (marker=$_t72_marker_line source=$_t72_source_line)"
else
  t72_fail "TC-01 進行マーカーが source 前に無い (marker=${_t72_marker_line:-none} source=${_t72_source_line:-none}): $_T72_RUNNER"
fi

# === TC-02 所要時間レポート ===
if grep -q 'extras timing' "$_T72_RUNNER" && grep -q 'sort -rn' "$_T72_RUNNER"; then
  t72_pass "TC-02 所要時間レポート（遅い順）の実装が存在する"
else
  t72_fail "TC-02 所要時間レポートの実装が見つからない: $_T72_RUNNER"
fi

# === TC-03 ウォッチドッグ既定閾値 < CI job timeout ===
_t72_wd_default=$(sed -n 's/^PG_EXTRA_WATCHDOG_SEC="${PG_EXTRA_WATCHDOG_SEC:-\([0-9]*\)}".*/\1/p' "$_T72_RUNNER" | head -1)
_t72_job_min=$(sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*\([0-9]*\).*/\1/p' "$_T72_ROOT/.github/workflows/test.yml" 2>/dev/null | head -1)
[ -n "$_t72_job_min" ] || _t72_job_min=10
if [ -n "$_t72_wd_default" ] && [ "$_t72_wd_default" -gt 0 ] && [ "$_t72_wd_default" -lt "$((_t72_job_min * 60))" ]; then
  t72_pass "TC-03 watchdog 既定 ${_t72_wd_default}s < job timeout $((_t72_job_min * 60))s"
else
  t72_fail "TC-03 watchdog 既定が不正 (default=${_t72_wd_default:-none}, job=$((_t72_job_min * 60))s): $_T72_RUNNER"
fi

# === TC-04 Step Summary はガードされている ===
if grep -q 'GITHUB_STEP_SUMMARY:-' "$_T72_RUNNER" && grep -q '>>"$GITHUB_STEP_SUMMARY"' "$_T72_RUNNER"; then
  t72_pass "TC-04 Step Summary 追記が GITHUB_STEP_SUMMARY 有無でガードされている"
else
  t72_fail "TC-04 Step Summary 追記のガードが見つからない: $_T72_RUNNER"
fi

# ---------------------------------------------------------------------------
# 動的検査: サンドボックスに最小 harness を組み、実際の出力で検証する。
# bin/plangate はスタブ（base tests の合否は問わない — 検証対象は extras 機構）。
_T72_TMP=$(mktemp -d "${TMPDIR:-/tmp}/ta72.XXXXXX")
register_cleanup "$_T72_TMP"

mkdir -p "$_T72_TMP/bin" "$_T72_TMP/tests/extras" "$_T72_TMP/docs/working"
printf '#!/bin/sh\nexit 1\n' > "$_T72_TMP/bin/plangate"
chmod +x "$_T72_TMP/bin/plangate"
ln -s "$_T72_ROOT/tests/fixtures" "$_T72_TMP/tests/fixtures"
cp "$_T72_RUNNER" "$_T72_TMP/tests/run-tests.sh"
printf 'pass=$((pass + 1)); printf "  [PASS] T72-A\\n"\n' > "$_T72_TMP/tests/extras/ta-01-alpha.sh"
printf 'fail=$((fail + 1)); printf "  [FAIL] T72-B\\n"\n' > "$_T72_TMP/tests/extras/ta-02-bravo.sh"
printf 'pass=$((pass + 1)); printf "  [PASS] T72-C\\n"\n' > "$_T72_TMP/tests/extras/ta-03-charlie.sh"

_T72_SUMMARY="$_T72_TMP/summary.md"
_t72_out=$(GITHUB_STEP_SUMMARY="$_T72_SUMMARY" PG_EXTRA_TOP_SLOW=2 PG_EXTRA_WATCHDOG_SEC=0 \
  sh "$_T72_TMP/tests/run-tests.sh" </dev/null 2>&1 || true)

# === TC-05 全ファイルの開始マーカーが glob 順に出る ===
_t72_order=$(printf '%s\n' "$_t72_out" | sed -n 's/^\[extras\] >>> \([^ ]*\).*/\1/p' | tr '\n' ' ')
if [ "$_t72_order" = "ta-01-alpha.sh ta-02-bravo.sh ta-03-charlie.sh " ]; then
  t72_pass "TC-05 開始マーカーが glob 順に全件出力される"
else
  t72_fail "TC-05 開始マーカーの列が不一致: [$_t72_order]"
fi

# === TC-06 失敗のファイル属性化 ===
_t72_attr_ok=1
printf '%s\n' "$_t72_out" | grep -q '^\[extras\] <<< ta-02-bravo.sh done in [0-9]*s (new failures: 1)$' || _t72_attr_ok=0
printf '%s\n' "$_t72_out" | grep -q '^\[extras\] <<< ta-01-alpha.sh done in [0-9]*s (new failures: 0)$' || _t72_attr_ok=0
printf '%s\n' "$_t72_out" | grep -q '^  ta-02-bravo.sh: 1 failing check(s)$' || _t72_attr_ok=0
if [ "$_t72_attr_ok" = "1" ]; then
  t72_pass "TC-06 失敗が ta-02-bravo.sh に属性化され、無失敗ファイルは 0 と表示される"
else
  t72_fail "TC-06 失敗の属性化が不成立: $(printf '%s' "$_t72_out" | grep 'extras\]' | tr '\n' ';')"
fi

# === TC-07 変異注入（マーカー printf 削除）でマーカーが消える＝検出力の実証 ===
sed '/\[extras\] >>> /d' "$_T72_RUNNER" > "$_T72_TMP/tests/run-tests-mutant.sh"
_t72_mut_out=$(PG_EXTRA_WATCHDOG_SEC=0 sh "$_T72_TMP/tests/run-tests-mutant.sh" </dev/null 2>&1 || true)
_t72_mut_hits=$(printf '%s\n' "$_t72_mut_out" | grep -c '^\[extras\] >>> ' || true)
_t72_orig_hits=$(printf '%s\n' "$_t72_out" | grep -c '^\[extras\] >>> ' || true)
if [ "${_t72_mut_hits:-0}" -eq 0 ] && [ "${_t72_orig_hits:-0}" -gt 0 ]; then
  t72_pass "TC-07 変異注入でマーカー 0 件 / 原本 $_t72_orig_hits 件（TC-05 は空振りでない）"
else
  t72_fail "TC-07 変異注入の対照が不成立 (mutant=$_t72_mut_hits, original=$_t72_orig_hits)"
fi

# === TC-08 Step Summary ===
_t72_sum_ok=1
[ -f "$_T72_SUMMARY" ] || _t72_sum_ok=0
if [ "$_t72_sum_ok" = "1" ]; then
  grep -q 'failing extras' "$_T72_SUMMARY" || _t72_sum_ok=0
  grep -q 'ta-02-bravo.sh' "$_T72_SUMMARY" || _t72_sum_ok=0
  grep -q 'slowest extras' "$_T72_SUMMARY" || _t72_sum_ok=0
fi
if [ "$_t72_sum_ok" = "1" ]; then
  t72_pass "TC-08 GITHUB_STEP_SUMMARY に失敗ファイル表と遅いファイル表が追記される"
else
  t72_fail "TC-08 Step Summary の内容が不足: $(cat "$_T72_SUMMARY" 2>/dev/null | tr '\n' ';')"
fi

# === TC-09 ウォッチドッグ ===
printf 'sleep 3\npass=$((pass + 1))\n' > "$_T72_TMP/tests/extras/ta-02-bravo.sh"
_t72_wd_out=$(PG_EXTRA_WATCHDOG_SEC=1 PG_EXTRA_WATCHDOG_POLL=1 \
  sh "$_T72_TMP/tests/run-tests.sh" </dev/null 2>&1 || true)
if printf '%s\n' "$_t72_wd_out" | grep -q 'WATCHDOG: ta-02-bravo.sh has been running'; then
  t72_pass "TC-09 watchdog が閾値超過ファイル名を出力する"
else
  t72_fail "TC-09 watchdog が発火しない: $(printf '%s' "$_t72_wd_out" | grep -i watchdog | tr '\n' ';')"
fi

rm -rf "$_T72_TMP"

pg_extra_contract_finalize
