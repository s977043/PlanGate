#!/bin/sh
# check-version-bump.sh — 配布物の変更に version bump が伴っているかを機械検出する (#1257)
#
# 背景 (#1257 実測 / origin/main = ecfef5b):
#   `/plugin update` は version が変わらなければ no-op。よって version を bump
#   しない限り、配布系 PR を何本マージしても consumer には 1 件も届かない。
#   実測では 45 commits / 配布系 PR 9 本が未配布のまま、宣言 version は据え置きの
#   8.21.0 だった。さらに同じ `8.21.0` を名乗る payload が 3 種類存在した。
#
# 提供する 2 つのゲート:
#   --bump   plugin/plangate/** に差分がある range で version が bump されているか
#   --parity version 宣言箇所 (正本: scripts/_version_sites.py) が全て同値か
#            併せて宣言テーブルの網羅性 (走査との同値照合) も検査する
#
# Usage:
#   sh scripts/check-version-bump.sh --parity [--root DIR]
#   sh scripts/check-version-bump.sh --bump --base <ref> [--head <ref>] [--root DIR]
#
# Exit:
#   0 = OK / 1 = 違反 / 2 = 使い方エラー / 3 = 検証不能 (= 検査していない。0 で装わない)
#
# 出力は分岐固有の reason トークンを必ず 1 つ含む (tests/extras/README.md P-1/P-3):
#   VERSION_PARITY_OK / VERSION_PARITY_MISMATCH / VERSION_SITE_MISSING
#   VERSION_SITE_UNDECLARED / VERSION_SITE_STALE / VERSION_SITES_COMPLETE
#   VERSION_BUMP_OK_NO_PLUGIN_DIFF / VERSION_BUMP_OK_BUMPED / VERSION_BUMP_MISSING
#   VERSION_BASE_UNRESOLVED / VERSION_GIT_ABSENT / VERSION_PYTHON_ABSENT

set -eu

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$SELF_DIR/.." && pwd)"
SITES_PY="$SELF_DIR/_version_sites.py"
# bump ゲートの監視対象 (issue #1257 In scope)
WATCH_PATH="plugin/plangate"
# bump 判定に使う version の代表点 (parity ゲートが 4 箇所の同値を保証する)
VERSION_FILE="plugin/plangate/.claude-plugin/plugin.json"

MODE=""
BASE=""
HEAD="HEAD"

usage() {
  printf 'Usage: %s --parity [--root DIR]\n' "$0" >&2
  printf '       %s --bump --base <ref> [--head <ref>] [--root DIR]\n' "$0" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --parity) MODE=parity ;;
    --bump) MODE=bump ;;
    --base) shift; BASE="${1:-}" ;;
    --head) shift; HEAD="${1:-}" ;;
    --root) shift; ROOT="$(CDPATH= cd -- "${1:-.}" && pwd)" ;;
    -h|--help) usage; exit 0 ;;
    *) printf '[version-bump] unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
  shift
done

[ -n "$MODE" ] || { usage; exit 2; }

command -v python3 >/dev/null 2>&1 || {
  printf '[version-bump] VERSION_PYTHON_ABSENT: python3 が必要です\n' >&2
  exit 3
}
[ -f "$SITES_PY" ] || {
  printf '[version-bump] VERSION_PYTHON_ABSENT: %s が見つかりません\n' "$SITES_PY" >&2
  exit 3
}

_read_version_at() {
  # $1 = ref。ref 時点の VERSION_FILE から version を読む (空 = 取得不能)
  git -C "$ROOT" show "$1:$VERSION_FILE" 2>/dev/null | python3 -c \
    'import json,sys
try:
    print(json.load(sys.stdin).get("version",""))
except Exception:
    print("")' 2>/dev/null || printf ''
}

if [ "$MODE" = "parity" ]; then
  rc=0
  python3 "$SITES_PY" verify-sites --root "$ROOT" || rc=$?
  if [ "$rc" != "0" ]; then
    printf '[version-bump] 宣言テーブル (scripts/_version_sites.py DECLARED_SITES) と実 manifest が乖離しています\n' >&2
    exit "$rc"
  fi
  rc=0
  python3 "$SITES_PY" parity --root "$ROOT" || rc=$?
  if [ "$rc" != "0" ]; then
    printf '[version-bump] version 宣言箇所の値が一致していません (同一 version で payload が分岐する原因 / #1257)\n' >&2
  fi
  exit "$rc"
fi

# --- bump ゲート -------------------------------------------------------------
[ -n "$BASE" ] || { printf '[version-bump] --bump には --base が必須です\n' >&2; usage; exit 2; }

command -v git >/dev/null 2>&1 || {
  printf '[version-bump] VERSION_GIT_ABSENT: git が必要です\n' >&2
  exit 3
}
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
  printf '[version-bump] VERSION_GIT_ABSENT: %s は git repo ではありません\n' "$ROOT" >&2
  exit 3
}

_base_sha=""
_base_sha=$(git -C "$ROOT" rev-parse --verify --quiet "$BASE^{commit}" 2>/dev/null) || _base_sha=""
_head_sha=""
_head_sha=$(git -C "$ROOT" rev-parse --verify --quiet "$HEAD^{commit}" 2>/dev/null) || _head_sha=""
if [ -z "$_base_sha" ] || [ -z "$_head_sha" ]; then
  # shallow clone (actions/checkout の既定 fetch-depth=1) ではここに来る。
  # rc=3 = 「検査していない」。0 で成功を装わない。
  printf '[version-bump] VERSION_BASE_UNRESOLVED: base=%s head=%s を解決できません (shallow clone では fetch-depth: 0 が必要)\n' \
    "$BASE" "$HEAD" >&2
  exit 3
fi

_merge_base=""
_merge_base=$(git -C "$ROOT" merge-base "$_base_sha" "$_head_sha" 2>/dev/null) || _merge_base=""
[ -n "$_merge_base" ] || _merge_base="$_base_sha"

_changed=""
_changed=$(git -C "$ROOT" diff --name-only "$_merge_base" "$_head_sha" -- "$WATCH_PATH" 2>/dev/null) || _changed=""

if [ -z "$_changed" ]; then
  printf '[version-bump] VERSION_BUMP_OK_NO_PLUGIN_DIFF: %s に差分なし (%s..%s)\n' \
    "$WATCH_PATH" "$_merge_base" "$_head_sha"
  exit 0
fi

_base_ver=$(_read_version_at "$_merge_base")
_head_ver=$(_read_version_at "$_head_sha")

if [ -z "$_head_ver" ]; then
  printf '[version-bump] VERSION_SITE_MISSING: %s から version を読めません (head=%s)\n' \
    "$VERSION_FILE" "$_head_sha" >&2
  exit 1
fi

if [ "$_base_ver" != "$_head_ver" ]; then
  printf '[version-bump] VERSION_BUMP_OK_BUMPED: %s -> %s\n' "$_base_ver" "$_head_ver"
  exit 0
fi

_count=$(printf '%s\n' "$_changed" | grep -c . || true)
printf '[version-bump] VERSION_BUMP_MISSING: %s に %s ファイルの差分があるのに version が %s のままです\n' \
  "$WATCH_PATH" "$_count" "$_head_ver" >&2
printf '%s\n' "$_changed" | sed 's/^/  - /' >&2
printf '  version が変わらないと /plugin update は no-op になり、consumer に 1 件も届きません (#1257)。\n' >&2
printf '  version 同期マップ (docs/release-process.md) の全箇所を同時に bump してください。\n' >&2
exit 1
