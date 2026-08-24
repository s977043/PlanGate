#!/bin/sh
# lint-shell.sh — repo 全体のシェル資産に shellcheck をかける薄いラッパ（非 HO）
#
# 目的:
#   この repo はシェル資産が大半を占めるが、CI には静的解析が 1 つも無かった。
#   本スクリプトは「何を gate 対象にするか」を 1 か所に集約し、CI とローカルで
#   同じ判定を再現する。
#
# 設計上の約束:
#   1. 対象は **再帰列挙 + 明示的除外宣言**。固定 glob を並べない
#      （固定 glob は新規ディレクトリが黙って走査外になる。#1178 / ta-70 が同型の実害）。
#   2. **成長するディレクトリの絶対件数を契約値にしない**。件数は情報表示のみで
#      「N 件であること」を assert しない（無関係な PR を落とす時限爆弾になる）。
#   3. shellcheck 未導入環境では **明示的に SKIP と出して rc=0**。黙って緑にしない。
#      不在自体が異常な場所（CI）では --require-tool を渡して FAIL に切り替える。
#
# Usage:
#   sh scripts/lint-shell.sh                 # gate（-S error）。findings があれば rc=1
#   sh scripts/lint-shell.sh --gate          # 同上（明示）
#   sh scripts/lint-shell.sh --advisory      # 参考情報（-S warning）。常に rc=0
#   sh scripts/lint-shell.sh --list          # 解決した対象ファイル一覧のみ出力
#   sh scripts/lint-shell.sh --require-tool  # shellcheck 不在を FAIL 扱いにする
#   sh scripts/lint-shell.sh --help
#
# Env:
#   PG_SHELLCHECK  shellcheck の実体名 / パス（既定: shellcheck）。テストで不在経路を
#                  再現するためのシーム。
#
# Exit codes:
#   0 = gate findings 無し / advisory / list / tool 不在（--require-tool 無し）
#   1 = gate findings あり / 引数エラー / --require-tool 下で tool 不在 / git 不在
#
# 関連: scripts/lint-workflows.sh（actionlint 版）, tests/extras/ta-71-ci-static-lint.sh

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# ── 除外宣言（正本）───────────────────────────────────────────────
# ここに書かれていないパスは **すべて gate 対象**。除外は理由とセットでのみ追加する。
#
#   docs/working/**  : 過去 PBI の evidence / 使い捨て検証スクリプト。append-only の
#                      歴史資産であり「後から直す」対象ではない。gate に含めると
#                      将来の evidence 追加が無関係に CI を落とす。
_lint_shell_is_excluded() {
  case "$1" in
    docs/working/*) return 0 ;;
    *) return 1 ;;
  esac
}
EXCLUSION_NOTE='docs/working/** (過去 PBI の evidence)'

_usage() {
  sed -n '2,33p' "$0" >&2
}

# ── 引数 strict 検証 ──────────────────────────────────────────────
MODE=gate
REQUIRE_TOOL=0
for _arg in "$@"; do
  case "$_arg" in
    --gate) MODE=gate ;;
    --advisory) MODE=advisory ;;
    --list) MODE=list ;;
    --require-tool) REQUIRE_TOOL=1 ;;
    -h|--help) _usage; exit 0 ;;
    *)
      printf 'error: unknown argument: %s\n' "$_arg" >&2
      printf 'usage: sh scripts/lint-shell.sh [--gate|--advisory|--list] [--require-tool]\n' >&2
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT" || exit 1
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf 'error: %s is not a git work tree (対象列挙に git ls-files を使う)\n' "$REPO_ROOT" >&2
  exit 1
fi

_TMP=$(mktemp -d)
_cleanup() { rm -rf "$_TMP"; }

# tool 検出は列挙より前に行う（--list 以外では、対象列挙のコストを払う前に
# 不在を判定できる）。
if [ "$MODE" != list ]; then
  # ── tool 検出（不在を黙って緑にしない）──────────────────────────
  SHELLCHECK_BIN="${PG_SHELLCHECK:-shellcheck}"
  if ! command -v "$SHELLCHECK_BIN" >/dev/null 2>&1; then
    if [ "$REQUIRE_TOOL" = "1" ]; then
      printf '[FAIL] lint-shell: %s が見つからない（--require-tool 指定下では FAIL）\n' "$SHELLCHECK_BIN" >&2
      printf '       導入: brew install shellcheck / apt-get install -y shellcheck\n' >&2
      _cleanup
      exit 1
    fi
    printf '[SKIP] lint-shell: %s 未導入のため *検査していない*（rc=0 だが検証済みではない）\n' "$SHELLCHECK_BIN"
    printf '       導入: brew install shellcheck / apt-get install -y shellcheck\n'
    printf '       不在を異常扱いにするには --require-tool を渡す\n'
    _cleanup
    exit 0
  fi
fi

# ── 対象ファイルの再帰列挙 ────────────────────────────────────────
# (a) 追跡ファイルを全列挙 → (b) 除外宣言で落とす → (c) `.sh` か「1 行目が shell の
# shebang」のものを対象にする。拡張子を持たない実行スクリプト（bin/plangate,
# scripts/ai-dev-workflow）も (c) の shebang 判定で自動的に入る。
git ls-files -z >"$_TMP/all.z"

# shebang を持ちうるテキストファイルへ粗く絞る（-I はバイナリを飛ばし、-l は最初の
# マッチで打ち切る）。ここでは 1 行目に限定していない＝取りこぼさない側に倒す。
: >"$_TMP/cand"
xargs -0 grep -Il '^#!' <"$_TMP/all.z" >>"$_TMP/cand" 2>/dev/null || true
# .sh は shebang が無くても対象（tests/extras/*.sh は source 前提で shebang 無し）
tr '\0' '\n' <"$_TMP/all.z" | grep -E '\.sh$' >>"$_TMP/cand" || true

: >"$_TMP/targets"
sort -u "$_TMP/cand" >"$_TMP/cand.sorted"
while IFS= read -r _f; do
  [ -n "$_f" ] || continue
  if _lint_shell_is_excluded "$_f"; then continue; fi
  [ -f "$_f" ] || continue
  case "$_f" in
    *.sh) printf '%s\n' "$_f" >>"$_TMP/targets" ;;
    *)
      # 1 行目が shell の shebang のものだけ拾う（python / ruby / node は対象外）
      if sed -n '1p' "$_f" | grep -Eq '^#!.*[ /](sh|bash|dash|ksh)([ ]|$)'; then
        printf '%s\n' "$_f" >>"$_TMP/targets"
      fi
      ;;
  esac
done <"$_TMP/cand.sorted"

if [ "$MODE" = list ]; then
  cat "$_TMP/targets"
  _cleanup
  exit 0
fi

# ── dialect 振り分け ─────────────────────────────────────────────
# shebang の無いファイル（tests/extras/*.sh は run-tests.sh から source される断片）
# では dialect を決められず SC2148 が error として報告される。これは「shebang の
# 付け忘れ」ではなく設計（tests/extras/README.md 規約）なので、shebang の有無で
# `-s sh` を出し分ける。shebang があるファイルには何も渡さず自動判定へ委ねる。
: >"$_TMP/with-shebang"
: >"$_TMP/no-shebang"
while IFS= read -r _f; do
  [ -n "$_f" ] || continue
  if sed -n '1p' "$_f" | grep -q '^#!'; then
    printf '%s\n' "$_f" >>"$_TMP/with-shebang"
  else
    printf '%s\n' "$_f" >>"$_TMP/no-shebang"
  fi
done <"$_TMP/targets"

_n_all=$(wc -l <"$_TMP/targets" | tr -d ' ')
_n_shb=$(wc -l <"$_TMP/with-shebang" | tr -d ' ')
_n_nsb=$(wc -l <"$_TMP/no-shebang" | tr -d ' ')

if [ "$MODE" = advisory ]; then
  SEVERITY=warning
  # SC1007: `CDPATH= cd -- ...` という env-prefix 代入を「= の後ろのスペース」誤記と
  # 誤検出する。この repo は CDPATH 汚染を避けるため意図してこの書法を使っており、
  # 正しいコードに対する false positive なので advisory からも落とす。
  EXCLUDES=SC1007
else
  SEVERITY=error
  EXCLUDES=''
fi

printf '=== lint-shell (mode=%s severity=%s) ===\n' "$MODE" "$SEVERITY"
printf '  targets: %s files (with shebang: %s / sourced fragments: %s)\n' "$_n_all" "$_n_shb" "$_n_nsb"
printf '  excluded by declaration: %s\n' "$EXCLUSION_NOTE"

_sc() {
  # $1 = dialect フラグ（空文字可）。stdin = ファイル一覧。
  if [ -n "$EXCLUDES" ]; then
    # shellcheck disable=SC2086 # $1 は意図的に単語分割させる dialect フラグ
    xargs "$SHELLCHECK_BIN" $1 -S "$SEVERITY" -e "$EXCLUDES" -f gcc
  else
    # shellcheck disable=SC2086 # 同上
    xargs "$SHELLCHECK_BIN" $1 -S "$SEVERITY" -f gcc
  fi
}

_rc=0
: >"$_TMP/out"
if [ -s "$_TMP/with-shebang" ]; then
  _sc '' <"$_TMP/with-shebang" >>"$_TMP/out" 2>&1 || _rc=1
fi
if [ -s "$_TMP/no-shebang" ]; then
  _sc '-s sh' <"$_TMP/no-shebang" >>"$_TMP/out" 2>&1 || _rc=1
fi

cat "$_TMP/out"
_findings=$(grep -c 'SC[0-9]' "$_TMP/out" || true)

if [ "$MODE" = advisory ]; then
  printf '[INFO] lint-shell advisory: %s finding(s)（参考情報。gate しない）\n' "$_findings"
  _cleanup
  exit 0
fi

if [ "$_rc" -ne 0 ]; then
  printf '[FAIL] lint-shell gate: %s finding(s) at severity=%s\n' "$_findings" "$SEVERITY" >&2
  _cleanup
  exit 1
fi

printf '[PASS] lint-shell gate: 0 findings at severity=%s\n' "$SEVERITY"
_cleanup
exit 0
