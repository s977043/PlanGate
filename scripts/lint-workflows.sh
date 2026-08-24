#!/bin/sh
# lint-workflows.sh — GitHub Actions ワークフローに actionlint をかける薄いラッパ（非 HO）
#
# 設計上の約束（scripts/lint-shell.sh と同じ）:
#   1. 対象は **再帰列挙 + 明示的除外宣言**。固定 glob を並べない。
#   2. **絶対件数を契約値にしない**（件数は情報表示のみ）。
#   3. actionlint 未導入環境では **明示的に SKIP と出して rc=0**。黙って緑にしない。
#      不在自体が異常な場所（CI）では --require-tool を渡して FAIL に切り替える。
#   4. **列挙が壊れたら FAIL する**（自己検査）。対象 0 件は tool の有無・モードに
#      関わらず exit 1（--list も含む）。これが無いと「対象 0 件 -> findings 0 件
#      -> [PASS] rc=0」の恒真 PASS になる。
#
#   対象列挙は `git ls-files`＝**追跡済みファイルのみ**。未追跡の新規 workflow は
#   検査されない（CI では常に commit 済みなので実害はローカル用途に限る）。
#
#   注記: actionlint の shellcheck 連携は **既定で無効**（-shellcheck=）:
#   actionlint は run: ブロックを shellcheck に渡すが、この連携が本 repo の
#   ワークフローで **決定論的にハングする**（実測・下記）。ハングは 10 分の job
#   timeout を焼き切るだけで診断情報を残さないため、既定では無効にしている。
#
#   実測（2026-08-24 / actionlint 1.7.12 + shellcheck 0.11.0 / darwin-arm64）:
#     actionlint -no-color -oneline .github/workflows/schema-validate.yml
#       -> 60s x3 すべて timeout（rc=124）。actionlint 自身が 100% CPU で spin し、
#          子プロセスとしての shellcheck は 1 つも生成されない
#     同コマンド + -shellcheck=                      -> rc=0 / 0s
#     同コマンド（PATH から shellcheck を外す）      -> rc=0 / 0s
#     ハングする 4 workflow: check-pr-issue-link / release-docs-sync /
#       schema-validate / sync-plugin-plangate（他 6 本は 0s で完了）
#     step 単位まで切り分けると schema-validate.yml の
#       "Determine changed JSON files" の run ブロック単体で再現する
#
#   既知の残存（別 PBI）: この設定により **inline run: ブロックの shell lint は
#   行われない**。repo 内の .sh / shebang スクリプトは scripts/lint-shell.sh が
#   カバーするが、workflow に直書きされた run: は誰も lint していない。
#   恒久解は actionlint / shellcheck の版固定か upstream 修正。
#
#   PG_ACTIONLINT_SHELLCHECK=1 を渡すと連携を有効化できる（ハングしうる）。
#   その場合 SHELLCHECK_OPTS の既定値 "-S error" が使われ、
#   scripts/lint-shell.sh の gate と基準が揃う。
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
#   PG_ACTIONLINT_SHELLCHECK
#                   1 で actionlint の shellcheck 連携を有効化（既定: 無効。上記のハング）
#   SHELLCHECK_OPTS actionlint 内蔵 shellcheck へのオプション（既定: -S error）
#   PG_LINT_TIMEOUT actionlint 1 回の実行に許す秒数（既定: 120）。timeout(1) が
#                   使える環境でのみ有効。超過したら **黙って緑にせず** 診断つきで
#                   FAIL する（ハングを job timeout に焼かせない）。
#
# Exit codes:
#   0 = findings 無し / list / tool 不在（--require-tool 無し）
#   1 = findings あり / 引数エラー / --require-tool 下で tool 不在 / git 不在
#       / 列挙の自己検査に失敗（対象 0 件）/ actionlint がタイムアウト
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
  # ヘッダコメント（2 行目〜 `set -eu` の直前）を出す。行番号でアンカーしない
  # ＝ヘッダ行数が変わっても usage が黙ってズレない（行番号アンカー stale 化対策）。
  awk 'NR==1 { next } /^set -eu$/ { exit } { print }' "$0" >&2
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

# ── 列挙の自己検査（恒真 PASS 防止）──────────────────────────────
# tool 検出やモード分岐より前に置く: --list でも壊れた列挙を目視で信じないため。
if [ ! -s "$_TMP/targets" ]; then
  printf '[FAIL] lint-workflows: 対象ワークフローが 1 件も解決できなかった（列挙の壊れを疑う）\n' >&2
  _cleanup
  exit 1
fi

if [ "$MODE" = list ]; then
  printf 'note: 対象は git 追跡済みファイルのみ（未追跡の新規 workflow は検査されない）\n' >&2
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

_n=$(wc -l <"$_TMP/targets" | tr -d ' ')
printf '=== lint-workflows (actionlint) ===\n'
printf '  targets: %s workflow file(s)\n' "$_n"
printf '  excluded by declaration: %s\n' "$EXCLUSION_NOTE"
printf '  note: 対象は git 追跡済みファイルのみ（未追跡の新規 workflow は検査されない）\n'

# ── shellcheck 連携（既定 OFF。ヘッダの実測を参照）───────────────────
if [ "${PG_ACTIONLINT_SHELLCHECK:-0}" = "1" ]; then
  SC_FLAG=''
  SHELLCHECK_OPTS="${SHELLCHECK_OPTS:--S error}"
  export SHELLCHECK_OPTS
  printf '  shellcheck 連携: 有効 (SHELLCHECK_OPTS=%s) — ハングしうる\n' "$SHELLCHECK_OPTS"
else
  SC_FLAG='-shellcheck='
  printf '  shellcheck 連携: 無効 (-shellcheck=) — inline run: は lint されない\n'
  printf '           有効化: PG_ACTIONLINT_SHELLCHECK=1（既知のハングあり）\n'
fi

# ── 実行時間の上限（ハングを job timeout に焼かせない）────────────────
# timeout(1) が無い環境（macOS の素の状態等）では上限をかけられない。無いことを
# 黙って隠さず表示する。
_TIMEOUT_BIN=''
if command -v timeout >/dev/null 2>&1; then
  _TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
  _TIMEOUT_BIN=gtimeout
fi
_LIMIT="${PG_LINT_TIMEOUT:-120}"
if [ -n "$_TIMEOUT_BIN" ]; then
  printf '  timeout: %ss (%s)\n' "$_LIMIT" "$_TIMEOUT_BIN"
else
  printf '  timeout: 無効（timeout(1) が無い。ハングは検出できない）\n'
fi

# 実行部を別スクリプトへ切り出す。timeout(1) はシェル関数・パイプラインを直接
# 包めないため、パイプライン全体を 1 プロセスにしてから包む。こうすると
# timeout の 124 と xargs の「子が非ゼロ」を取り違えない。
# NUL 区切りで渡す（既定の xargs は空白・引用符を区切り/クォートと解釈するため、
# 空白入りのパスが割れて「存在しないファイル」エラーに化ける）。
cat >"$_TMP/run.sh" <<'RUNEOF'
set -eu
_targets=$1
_bin=$2
_scflag=$3
tr '\n' '\0' <"$_targets" | xargs -0 "$_bin" -no-color -oneline ${_scflag:+"$_scflag"}
RUNEOF

_rc=0
if [ -n "$_TIMEOUT_BIN" ]; then
  "$_TIMEOUT_BIN" "$_LIMIT" sh "$_TMP/run.sh" "$_TMP/targets" "$ACTIONLINT_BIN" "$SC_FLAG" \
    >"$_TMP/out" 2>&1 || _rc=$?
else
  sh "$_TMP/run.sh" "$_TMP/targets" "$ACTIONLINT_BIN" "$SC_FLAG" >"$_TMP/out" 2>&1 || _rc=$?
fi

if [ -n "$_TIMEOUT_BIN" ] && { [ "$_rc" -eq 124 ] || [ "$_rc" -eq 137 ]; }; then
  cat "$_TMP/out"
  printf '[FAIL] lint-workflows: actionlint が %ss を超えた（rc=%s）。**検査は完了していない**\n' \
    "$_LIMIT" "$_rc" >&2
  printf '       上限変更: PG_LINT_TIMEOUT=<秒>\n' >&2
  printf '       PG_ACTIONLINT_SHELLCHECK=1 を渡している場合は外して再試行する\n' >&2
  _cleanup
  exit 1
fi
[ "$_rc" -eq 0 ] || _rc=1
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
