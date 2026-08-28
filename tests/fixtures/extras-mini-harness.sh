#!/bin/sh
# tests/fixtures/extras-mini-harness.sh
# 単一 extras を隔離実行するための最小ハーネス（#947 / #1209 / #1210）。
# 用途は「harness-only な extras を 1 本だけ、汚れた初期状態から走らせて
# order-dependence を検出する」こと。tests/run-tests.sh 本体には触れない。
#
# 再現するもの（tests/run-tests.sh と同一の挙動にそろえてある）:
#   - pass / fail カウンタ
#   - register_cleanup / _pg_drain_cleanup
#     （改行区切りで蓄積し read -r で 1 行ずつ取り出す。空白を含むパスを
#       word-splitting で壊さない = run-tests.sh:34-49 と同形）
#   - assert_pass / assert_fail（"$@" を実際に実行し pass/fail を更新する）
#   - FIXTURES_DIR / EXTRAS_DIR / PLANGATE_BIN（export しない = 本物と同じ。
#     export すると extras が起動した子プロセスまで harness 実行と誤判定する）
#   - PG_HARNESS_SOURCED=1 / 呼び出し元 env の unset 集合（7 env）
#
# 再現しないもの（本物との既知の差分。意図的に持たない）:
#   - extras ループそのもの（本ハーネスは 1 本しか source しない）
#   - 実行順序・所要時間レポート（PG_EXTRA_TOP_SLOW）
#   - watchdog（PG_EXTRA_WATCHDOG_* / 進捗ファイル）
#   - extras より前に走る base tests（plangate validate --dir 等）
#   - 最終サマリの出力形式（ここでは "MINI:<pass>:<fail>" 1 行だけ）
#
# usage: sh tests/fixtures/extras-mini-harness.sh <repo-root> <ta-NN-*.sh>
#   rc=0 全 pass / rc!=0 失敗。最終行に "MINI:<pass>:<fail>" を出力する。
#   PG_MINI_NO_DRAIN=1 で末尾の cleanup drain を抑止（残留の観測用）。
set -eu
ROOT="$1"; TARGET="$2"
unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
FIXTURES_DIR="$ROOT/tests/fixtures"
EXTRAS_DIR="$ROOT/tests/extras"
PLANGATE_BIN="$ROOT/bin/plangate"
pass=0
fail=0

# register_cleanup / _pg_drain_cleanup: 区切りは空白ではなく改行。
# 空白連結 + unquoted for ループだと "a b/keep" を登録したときに
# "a" と "b/keep" の 2 パスへ割れ、無関係なパスを消す（実測済み）。
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

PG_HARNESS_SOURCED=1
. "$EXTRAS_DIR/$TARGET"
if [ "${PG_MINI_NO_DRAIN:-0}" != "1" ]; then
  _pg_drain_cleanup
fi
printf 'MINI:%d:%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
