#!/bin/sh
# tests/fixtures/extras-mini-harness.sh
# 単一 extras を隔離実行するための最小ハーネス（#947 / #1209 / #1210）。
# tests/run-tests.sh が extras へ提供する API（pass / fail カウンタ /
# register_cleanup / _pg_drain_cleanup / FIXTURES_DIR / EXTRAS_DIR /
# PLANGATE_BIN / PG_HARNESS_SOURCED / assert_pass）だけを再現する。
# 用途は「harness-only な extras を 1 本だけ、汚れた初期状態から走らせて
# order-dependence を検出する」こと。tests/run-tests.sh 本体には触れない。
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
export FIXTURES_DIR EXTRAS_DIR PLANGATE_BIN
pass=0
fail=0
_PG_CLEAN_FILE="${PG_MINI_CLEANFILE:-/dev/null}"
_PG_CLEANUP_PATHS=""
register_cleanup() {
  for _pg_cp in "$@"; do
    [ -n "$_pg_cp" ] || continue
    _PG_CLEANUP_PATHS="$_PG_CLEANUP_PATHS $_pg_cp"
    printf "%s\\n" "$_pg_cp" >> "$_PG_CLEAN_FILE"
  done
}
_pg_drain_cleanup() {
  for _pg_cp in $_PG_CLEANUP_PATHS; do
    [ -n "$_pg_cp" ] || continue
    /bin/rm -rf "$_pg_cp" 2>/dev/null || true
  done
  _PG_CLEANUP_PATHS=""
}
assert_pass() { :; }
PG_HARNESS_SOURCED=1
. "$EXTRAS_DIR/$TARGET"
if [ "${PG_MINI_NO_DRAIN:-0}" != "1" ]; then
  _pg_drain_cleanup
fi
printf "MINI:%d:%d\\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
