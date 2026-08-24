#!/bin/sh
# PlanGate CLI test suite
# Usage: sh tests/run-tests.sh
#
# 構成:
#   - 本体（base tests）: 下記 TA-01 / TA-02 / TA-03 + plangate validate --dir
#   - 拡張テスト: tests/extras/ta-*.sh を順次 source（Issue #170 で導入）
#     新規テストブロック追加時は tests/extras/ にファイルを置くこと。
#     詳細は tests/extras/README.md 参照。

set -eu

# 呼び出し元 env の漏れで実 hooks の挙動が変わり実監査ログを汚染するのを防ぐ
# （tests/extras/README.md 規約 7 / 2026-06-11 実害: PLANGATE_SKIP_REASON 漏れ）
# PG_HARNESS_SOURCED: harness/standalone 判別シグナル（#877 F3）。外部 env から
#   漏れると extras が誤って harness 実行と判定するため必ず先に unset する。
# PLANGATE_ALLOW_MASS_DELETE: sync の mass-delete guard 解除フラグ（#877 F1）。
#   開発者環境に export されたままだと guard が恒久的に無効化され、テストが
#   guard の発火を検出できなくなる。
unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true

PLANGATE_BIN="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/bin/plangate"
FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/fixtures"
EXTRAS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/extras"

pass=0
fail=0

# ── 共有 cleanup ユーティリティ（#530-3）─────────────────────────────
# extras が個別に trap EXIT を張ると source 連鎖で互いに上書きし合い（さらに
# `trap - EXIT` がハーネス側の trap まで消す）発火が保証されない
# （tests/extras/README.md 規約参照）。代わりに extras は register_cleanup で
# 一時パスを登録し、extras ループ末尾の単一 drain で一括削除する（trap 非依存）。
_PG_CLEANUP_PATHS=""
register_cleanup() {
  for _pg_cp in "$@"; do
    [ -n "$_pg_cp" ] || continue
    _PG_CLEANUP_PATHS="${_PG_CLEANUP_PATHS}${_pg_cp}
"
  done
}
_pg_drain_cleanup() {
  [ -n "$_PG_CLEANUP_PATHS" ] || return 0
  printf '%s' "$_PG_CLEANUP_PATHS" | while IFS= read -r _pg_cp; do
    [ -n "$_pg_cp" ] || continue
    rm -rf "$_pg_cp" 2>/dev/null || true
  done
  _PG_CLEANUP_PATHS=""
}

assert_pass() {
  label=$1
  shift
  if "$@" >/dev/null; then
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s — expected PASS but got FAIL\n' "$label"
    fail=$((fail + 1))
  fi
}

assert_fail() {
  label=$1
  shift
  if ! "$@" >/dev/null; then
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s — expected FAIL but got PASS\n' "$label"
    fail=$((fail + 1))
  fi
}

printf '=== plangate validate --dir ===\n'

assert_pass "complete-task: all artifacts + valid c3.json → PASS" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/complete-task"

assert_fail "missing-approval: no approvals/c3.json → FAIL" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/missing-approval"

assert_fail "stale-plan-hash: plan.md modified after approval → FAIL" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/stale-plan-hash"

assert_fail "broken-pbi: pbi-input.md missing → FAIL" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/broken-pbi"

printf '\n=== TA-01: validate --mode ===\n'

# complete-task has plan.md, todo.md, test-cases.md, review-self.md + valid c3.json
# standard.yaml c3 requires: [plan, todo, test_cases, review_self] — no pbi-input.md
assert_pass "validate --mode standard: complete-task passes" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/complete-task" --mode standard

# missing-approval has no approvals/c3.json → FAIL regardless of mode
assert_fail "validate --mode standard: missing-approval fails" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/missing-approval" --mode standard

assert_fail "validate --mode unknown-xyz: non-existent mode returns error" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/complete-task" --mode unknown-xyz

printf '\n=== TA-02: review command ===\n'

assert_fail "review: no args shows usage (exit 1)" \
  sh "$PLANGATE_BIN" review

# Verify that the usage text is emitted to stderr
if sh "$PLANGATE_BIN" review 2>&1 | grep -q 'Usage'; then
  printf '[PASS] review: no args emits Usage text\n'
  pass=$((pass + 1))
else
  printf '[FAIL] review: no args — Usage text not found\n'
  fail=$((fail + 1))
fi

printf '\n=== TA-03: exec command gate enforcement ===\n'

# Create a temporary task dir without approvals/c3.json to test gate enforcement
TMPDIR_TASK="$(dirname "$FIXTURES_DIR")/tmp-working"
mkdir -p "$TMPDIR_TASK"

# Temporarily point plangate_working_dir at our tmp dir by creating TASK-GATETEST
GATE_TASK_DIR="$TMPDIR_TASK/TASK-GATETEST"
mkdir -p "$GATE_TASK_DIR"
touch "$GATE_TASK_DIR/plan.md"

# exec requires PLANGATE_WORKING_DIR override — we need to run it with modified path.
# Since bin/plangate computes plangate_working_dir from its own location, we use a
# wrapper that symlinks docs/working/TASK-GATETEST to our temp dir.
REPO_WORKING="$(CDPATH= cd -- "$(dirname "$FIXTURES_DIR")/.." && pwd)/docs/working/TASK-GATETEST"
if [ ! -e "$REPO_WORKING" ]; then
  # Create a minimal task dir inside docs/working for this test
  mkdir -p "$REPO_WORKING"
  touch "$REPO_WORKING/plan.md"
  created_gate_test=1
else
  created_gate_test=0
fi

if sh "$PLANGATE_BIN" exec TASK-GATETEST 2>&1 | grep -q 'C-3 gate not cleared'; then
  printf '[PASS] exec: missing approvals/c3.json → C-3 gate not cleared\n'
  pass=$((pass + 1))
else
  printf '[FAIL] exec: expected "C-3 gate not cleared" error\n'
  fail=$((fail + 1))
fi

# Cleanup
if [ "${created_gate_test:-0}" -eq 1 ]; then
  rm -rf "$REPO_WORKING"
fi
rm -rf "$TMPDIR_TASK"

# ── extras 進行マーカー / 所要時間計測 / ウォッチドッグ（失敗の属性化）────
# 目的: CI の job timeout で殺されても「どの ta-NN で止まったか」がログから
#   一意に分かるようにする（従来はマーカーが無く犯人が特定できなかった）。
# 採らない方式とその根拠: extras は `. "$extra"` で **現在のシェルに source**
#   され pass / fail / register_cleanup / PG_HARNESS_SOURCED を共有する。実測で
#   tests/extras/ta-*.sh は全ファイルが共有カウンタを直接更新している
#   （git grep -lE '(pass|fail)=\$\(\((pass|fail) \+ 1\)\)' origin/main -- 'tests/extras/ta-*.sh'）。
#   よって per-file の `timeout` ・サブシェル隔離は集計を壊すため採用しない。
#   代わりに (1) source 直前の進行マーカー (2) 事後の所要時間レポート
#   (3) 別プロセスの監視役による超過警告（既定は警告のみ）で属性化する。
PG_EXTRA_TOP_SLOW="${PG_EXTRA_TOP_SLOW:-10}"                 # 0 で所要時間レポートを無効化
PG_EXTRA_WATCHDOG_SEC="${PG_EXTRA_WATCHDOG_SEC:-300}"        # 0 でウォッチドッグを無効化
PG_EXTRA_WATCHDOG_ACTION="${PG_EXTRA_WATCHDOG_ACTION:-warn}" # warn | kill
PG_EXTRA_WATCHDOG_POLL="${PG_EXTRA_WATCHDOG_POLL:-5}"        # 監視役のポーリング間隔（秒）

_PG_RUN_TIMINGS=""
_PG_RUN_FAILED=""
_PG_RUN_COUNT=0
_PG_RUN_WALL=0
_PG_RUN_STATE=""
_PG_RUN_WD_PID=""
_PG_RUN_BASE_FAIL=$fail

# 監視役（別プロセス）: 進行状態ファイルを定期的に読み、閾値を超えた
# ファイル名を stderr へ出す。既定（warn）では何も kill せず実行意味論を変えない。
_pg_run_watchdog() {
  _wd_state=$1
  _wd_limit=$2
  _wd_target=$3
  _wd_poll=$4
  _wd_seen=""
  while [ -f "$_wd_state" ]; do
    sleep "$_wd_poll"
    [ -f "$_wd_state" ] || break
    _wd_line=$(cat "$_wd_state" 2>/dev/null || true)
    [ -n "$_wd_line" ] || continue
    _wd_start=${_wd_line%% *}
    _wd_name=${_wd_line#* }
    case "$_wd_start" in "" | *[!0-9]*) continue ;; esac
    _wd_el=$(($(date +%s) - _wd_start))
    if [ "$_wd_el" -ge "$_wd_limit" ] && [ "$_wd_seen" != "$_wd_name" ]; then
      _wd_seen=$_wd_name
      printf '[extras] !! WATCHDOG: %s has been running %ss (limit %ss) - stall candidate\n' \
        "$_wd_name" "$_wd_el" "$_wd_limit" >&2
      if [ "$PG_EXTRA_WATCHDOG_ACTION" = "kill" ]; then
        printf '[extras] !! WATCHDOG: aborting run (PG_EXTRA_WATCHDOG_ACTION=kill)\n' >&2
        kill -TERM "$_wd_target" 2>/dev/null || true
      fi
    fi
  done
}

# ── Extras: tests/extras/ta-*.sh を順番に source（Issue #170）─────────────────────
# 新規 TA-NN を追加するときは tests/extras/ にファイルを置くだけでよい。
# 本体（このファイル）の編集は不要 → PBI 連続実装時の衝突を回避。
#
# extras に「harness から source されている」ことを明示するシグナルを渡す（#877 F3）。
# export しない: export すると extras が起動した子プロセスまで harness 実行と
# 誤判定し、standalone fallback（pass / fail / register_cleanup の自前定義）に
# 入らず壊れる。
PG_HARNESS_SOURCED=1
if [ -d "$EXTRAS_DIR" ]; then
  _PG_RUN_T0=$(date +%s)
  if [ "$PG_EXTRA_WATCHDOG_SEC" -gt 0 ] 2>/dev/null; then
    _PG_RUN_STATE=$(mktemp "${TMPDIR:-/tmp}/pg-extras-progress.XXXXXX" 2>/dev/null || true)
  fi
  if [ -n "$_PG_RUN_STATE" ]; then
    register_cleanup "$_PG_RUN_STATE"
    _pg_run_watchdog "$_PG_RUN_STATE" "$PG_EXTRA_WATCHDOG_SEC" "$$" "$PG_EXTRA_WATCHDOG_POLL" &
    _PG_RUN_WD_PID=$!
  fi
  for extra in "$EXTRAS_DIR"/ta-*.sh; do
    # POSIX glob: マッチ無しのときリテラル文字列が返るため存在チェック
    [ -f "$extra" ] || continue
    _pg_run_name=$(basename "$extra")
    _pg_run_fail0=$fail
    _pg_run_start=$(date +%s)
    [ -z "$_PG_RUN_STATE" ] ||
      printf '%s %s\n' "$_pg_run_start" "$_pg_run_name" >"$_PG_RUN_STATE"
    printf '\n[extras] >>> %s (start t+%ss)\n' "$_pg_run_name" "$((_pg_run_start - _PG_RUN_T0))"
    # shellcheck source=/dev/null
    . "$extra"
    _pg_run_dur=$(($(date +%s) - _pg_run_start))
    _pg_run_delta=$((fail - _pg_run_fail0))
    printf '[extras] <<< %s done in %ss (new failures: %s)\n' \
      "$_pg_run_name" "$_pg_run_dur" "$_pg_run_delta"
    _PG_RUN_TIMINGS="${_PG_RUN_TIMINGS}${_pg_run_dur} ${_pg_run_name}
"
    if [ "$_pg_run_delta" -gt 0 ]; then
      _PG_RUN_FAILED="${_PG_RUN_FAILED}${_pg_run_delta} ${_pg_run_name}
"
    fi
    _PG_RUN_COUNT=$((_PG_RUN_COUNT + 1))
  done
  _PG_RUN_WALL=$(($(date +%s) - _PG_RUN_T0))
  [ -z "$_PG_RUN_STATE" ] || rm -f "$_PG_RUN_STATE"
  if [ -n "$_PG_RUN_WD_PID" ]; then
    # 状態ファイルは上で削除済み（監視役は自力でも終了する）。ここで確実に停止し、
    # `wait` の stderr を捨ててシェルのジョブ終了通知（"Terminated"）を抑止する。
    kill "$_PG_RUN_WD_PID" 2>/dev/null || true
    wait "$_PG_RUN_WD_PID" 2>/dev/null || true
    _PG_RUN_WD_PID=""
  fi
fi

# extras が register_cleanup で登録した一時パスを一括削除（#530-3 / trap 非依存）
_pg_drain_cleanup

# ── extras 所要時間レポート（遅い順）/ 失敗のファイル属性化 ─────────
if [ -n "$_PG_RUN_TIMINGS" ] && [ "$PG_EXTRA_TOP_SLOW" -gt 0 ] 2>/dev/null; then
  printf '\n=== extras timing: slowest %s of %s files (extras wall %ss) ===\n' \
    "$PG_EXTRA_TOP_SLOW" "$_PG_RUN_COUNT" "$_PG_RUN_WALL"
  printf '%s' "$_PG_RUN_TIMINGS" | sort -rn | head -n "$PG_EXTRA_TOP_SLOW" |
    while IFS=' ' read -r _pg_run_rep_sec _pg_run_rep_name; do
      printf '  %5ss  %s\n' "$_pg_run_rep_sec" "$_pg_run_rep_name"
    done
fi

if [ -n "$_PG_RUN_FAILED" ]; then
  printf '\n=== extras with failures ===\n'
  printf '%s' "$_PG_RUN_FAILED" |
    while IFS=' ' read -r _pg_run_rep_cnt _pg_run_rep_name; do
      printf '  %s: %s failing check(s)\n' "$_pg_run_rep_name" "$_pg_run_rep_cnt"
    done
fi

printf '\n'
printf 'Results: %d passed, %d failed\n' "$pass" "$fail"

# ── GitHub Actions の Step Summary（存在する環境でのみ）───────────────
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    printf '### plangate test suite\n\n'
    printf '%s\n' "- result: **$pass passed, $fail failed**"
    printf '%s\n' "- base (pre-extras) failures: $_PG_RUN_BASE_FAIL"
    printf '%s\n\n' "- extras: $_PG_RUN_COUNT files, ${_PG_RUN_WALL}s wall"
    if [ -n "$_PG_RUN_FAILED" ]; then
      printf '#### failing extras\n\n| file | failing checks |\n| --- | ---: |\n'
      printf '%s' "$_PG_RUN_FAILED" |
        while IFS=' ' read -r _pg_run_sum_cnt _pg_run_sum_name; do
          printf '| `%s` | %s |\n' "$_pg_run_sum_name" "$_pg_run_sum_cnt"
        done
      printf '\n'
    fi
    if [ -n "$_PG_RUN_TIMINGS" ] && [ "$PG_EXTRA_TOP_SLOW" -gt 0 ] 2>/dev/null; then
      printf '#### slowest extras (top %s)\n\n| file | seconds |\n| --- | ---: |\n' "$PG_EXTRA_TOP_SLOW"
      printf '%s' "$_PG_RUN_TIMINGS" | sort -rn | head -n "$PG_EXTRA_TOP_SLOW" |
        while IFS=' ' read -r _pg_run_sum_sec _pg_run_sum_name; do
          printf '| `%s` | %s |\n' "$_pg_run_sum_name" "$_pg_run_sum_sec"
        done
      printf '\n'
    fi
  } >>"$GITHUB_STEP_SUMMARY" 2>/dev/null || true
fi

if [ "$fail" -gt 0 ]; then
  exit 1
fi
