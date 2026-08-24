#!/bin/sh
# lint-workflows.sh — GitHub Actions ワークフローに actionlint をかける薄いラッパ（非 HO）
#
# 設計上の約束（scripts/lint-shell.sh と同じ）:
#   1. 対象は **再帰列挙 + 明示的除外宣言**。固定 glob を並べない。
#   2. **絶対件数を契約値にしない**（件数は情報表示のみ）。
#   3. actionlint 未導入環境では **明示的に SKIP と出して rc=0**。黙って緑にしない。
#      不在自体が異常な場所（CI）では --require-tool を渡して FAIL に切り替える。
#
#   注記: actionlint の shellcheck 連携について:
#   actionlint は run: ブロックを shellcheck に渡す。既定では style/info まで報告するため
#   scripts/lint-shell.sh の gate（-S error）と基準がズレる。基準を揃えるため
#   SHELLCHECK_OPTS の既定値を "-S error" にしている（環境変数で上書き可能）。
#   例: SHELLCHECK_OPTS="-S warning" sh scripts/lint-workflows.sh
#
# Usage:
#   sh scripts/lint-workflows.sh                 # gate。findings があれば rc=1
#   sh scripts/lint-workflows.sh --gate          # 同上（明示）
#   sh scripts/lint-workflows.sh --list          # 対象ファイル一覧のみ出力
#   sh scripts/lint-workflows.sh --require-tool  # actionlint 不在を FAIL 扱いにする
#   sh scripts/lint-workflows.sh --help
#
# Env:
#   PG_ACTIONLINT   actionlint の実体名 / パス（既定: actionlint）
#   SHELLCHECK_OPTS actionlint 内蔵 shellcheck へのオプション（既定: -S error）
#
# Exit codes:
#   0 = findings 無し / list / tool 不在（--require-tool 無し）
#   1 = findings あり / 引数エラー / --require-tool 下で tool 不在 / git 不在
#
# 関連: scripts/lint-shell.sh, tests/extras/ta-71-ci-static-lint.sh

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# ── 除外宣言（正本）───────────────────────────────────────────────
# 現時点で除外は無い。除外を足すときは必ず理由を併記する。
_lint_wf_is_excluded() {
  case "$1" in
    *) return 1 ;;
  esac
}
EXCLUSION_NOTE='(なし)'

_usage() {
  sed -n '2,31p' "$0" >&2
}

MODE=gate
REQUIRE_TOOL=0
for _arg in "$@"; do
  case "$_arg" in
    --gate) MODE=gate ;;
    --list) MODE=list ;;
    --require-tool) REQUIRE_TOOL=1 ;;
    -h|--help) _usage; exit 0 ;;
    *)
      printf 'error: unknown argument: %s\n' "$_arg" >&2
      printf 'usage: sh scripts/lint-workflows.sh [--gate|--list] [--require-tool]\n' >&2
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT" || exit 1
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf 'error: %s is not a git work tree\n' "$REPO_ROOT" >&2
  exit 1
fi

_TMP=$(mktemp -d)
_cleanup() { rm -rf "$_TMP"; }

# ── 対象の再帰列挙 ───────────────────────────────────────────────
# .github/workflows/ 直下だけでなく配下を再帰的に拾う（将来サブディレクトリが
# 増えても走査外にならないようにする）。
: >"$_TMP/targets"
git ls-files -z -- .github/workflows >"$_TMP/all.z"
tr '\0' '\n' <"$_TMP/all.z" | grep -E '\.ya?ml$' >"$_TMP/cand" || true
while IFS= read -r _f; do
  [ -n "$_f" ] || continue
  if _lint_wf_is_excluded "$_f"; then continue; fi
  [ -f "$_f" ] || continue
  printf '%s\n' "$_f" >>"$_TMP/targets"
done <"$_TMP/cand"

if [ "$MODE" = list ]; then
  cat "$_TMP/targets"
  _cleanup
  exit 0
fi

ACTIONLINT_BIN="${PG_ACTIONLINT:-actionlint}"
if ! command -v "$ACTIONLINT_BIN" >/dev/null 2>&1; then
  if [ "$REQUIRE_TOOL" = "1" ]; then
    printf '[FAIL] lint-workflows: %s が見つからない（--require-tool 指定下では FAIL）\n' "$ACTIONLINT_BIN" >&2
    printf '       導入: brew install actionlint / https://github.com/rhysd/actionlint/releases\n' >&2
    _cleanup
    exit 1
  fi
  printf '[SKIP] lint-workflows: %s 未導入のため *検査していない*（rc=0 だが検証済みではない）\n' "$ACTIONLINT_BIN"
  printf '       導入: brew install actionlint / https://github.com/rhysd/actionlint/releases\n'
  printf '       不在を異常扱いにするには --require-tool を渡す\n'
  _cleanup
  exit 0
fi

if [ ! -s "$_TMP/targets" ]; then
  printf '[FAIL] lint-workflows: 対象ワークフローが 1 件も解決できなかった（列挙の壊れを疑う）\n' >&2
  _cleanup
  exit 1
fi

_n=$(wc -l <"$_TMP/targets" | tr -d ' ')
printf '=== lint-workflows (actionlint) ===\n'
printf '  targets: %s workflow file(s)\n' "$_n"
printf '  excluded by declaration: %s\n' "$EXCLUSION_NOTE"
printf '  SHELLCHECK_OPTS=%s\n' "${SHELLCHECK_OPTS:--S error}"

SHELLCHECK_OPTS="${SHELLCHECK_OPTS:--S error}"
export SHELLCHECK_OPTS

_rc=0
xargs "$ACTIONLINT_BIN" -no-color -oneline <"$_TMP/targets" >"$_TMP/out" 2>&1 || _rc=1
cat "$_TMP/out"
_findings=$(grep -c . "$_TMP/out" || true)

if [ "$_rc" -ne 0 ]; then
  printf '[FAIL] lint-workflows: %s finding(s)\n' "$_findings" >&2
  _cleanup
  exit 1
fi

printf '[PASS] lint-workflows: 0 findings\n'
_cleanup
exit 0
