#!/bin/sh
# check-version-bump.sh — 配布物の変更に version bump が伴っているかを機械検出する (#1257)
#
# 背景 (#1257 実測 / 測定時点 origin/main = ecfef5b):
#   `/plugin update` は version が変わらなければ no-op。よって version を bump
#   しない限り、配布系 PR を何本マージしても consumer には 1 件も届かない。
#   ecfef5b 時点の実測では v8.21.0 タグ以降 45 commits / 配布系 PR 9 本が未配布の
#   まま、宣言 version は据え置きの 8.21.0 だった。さらに同じ `8.21.0` を名乗る
#   payload が 3 種類存在した。**この数値は測定時点のもので、運用で増える。**
#
# ゲートを掛ける位置 (A-2' / 2026-09-07 Human 決定):
#   * PR CI     = `--parity` のみ。git 履歴に依存せず shallow clone でも動く。
#   * リリース時 = `--bump --since-latest-tag`。`scripts/release-prep.sh --check`
#                 から呼ばれ、**最新 tag 以降**に配布物差分があるのに version が
#                 据え置きなら NOT READY にする。
#   `--bump` を PR CI に置かない理由: 直近 2 か月の実測で `plugin/plangate` に
#   触れた first-parent commit 99 件のうち 91 件が赤になる。自動同期 PR は
#   version を CHANGELOG 先頭から取るため人手が入るまで恒久的に赤になる。
#   「マージのたびに bump」ではなく「リリースのたびに bump」が実運用に合う。
#
# 提供する 2 つのゲート:
#   --bump   監視対象に差分がある range で version が bump されているか
#   --parity version 宣言箇所 (正本: scripts/version_sites.py) が全て同値か
#            併せて宣言テーブルの網羅性 (走査との同値照合) も検査する
#
# Usage:
#   sh scripts/check-version-bump.sh --parity [--root DIR]
#   sh scripts/check-version-bump.sh --bump --base <ref> [--head <ref>] [--root DIR]
#   sh scripts/check-version-bump.sh --bump --since-latest-tag [--head <ref>] [--root DIR]
#
# Exit:
#   0 = OK / 1 = 違反 / 2 = 使い方エラー / 3 = 検証不能 (= 検査していない。0 で装わない)
#
# 出力は分岐固有の reason トークンを必ず 1 つ含む (tests/extras/README.md P-1/P-3):
#   VERSION_PARITY_OK / VERSION_PARITY_MISMATCH / VERSION_SITE_MISSING
#   VERSION_SITE_UNDECLARED / VERSION_SITE_STALE / VERSION_SITES_COMPLETE
#   VERSION_BUMP_OK_NO_PLUGIN_DIFF / VERSION_BUMP_OK_BUMPED / VERSION_BUMP_MISSING
#   VERSION_BUMP_DOWNGRADE / VERSION_TAG_PAYLOAD_CONFLICT / VERSION_NO_TAG
#   VERSION_BASE_UNRESOLVED / VERSION_GIT_ABSENT / VERSION_PYTHON_ABSENT
#
# 残存脅威モデル (本ゲートが守らないもの):
#   * 監視対象は `plugin/plangate/**` のみ (#1257 In scope)。
#     `.claude-plugin/marketplace.json` だけを変える差分は bump を要求しない。
#   * `--parity` は「宣言箇所が同値か」であって「その値が実際に配布された
#     payload と対応するか」ではない。同一 version で payload が分岐する事象
#     そのものの検出は実インストール E2E (#1257 Out of scope) が担う。
#   * リリース時ゲートであるため、**マージ時点では未 bump を止めない**。
#     配布の正しさは release-prep + C-4 Human レビューとの多層で担保する。

set -eu

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$SELF_DIR/.." && pwd)"
SITES_PY="$SELF_DIR/version_sites.py"
# bump ゲートの監視対象 (issue #1257 In scope)
WATCH_PATH="plugin/plangate"
# bump 判定に使う version の代表点 (parity ゲートが 4 箇所の同値を保証する)
VERSION_FILE="plugin/plangate/.claude-plugin/plugin.json"

MODE=""
BASE=""
HEAD="HEAD"
SINCE_LATEST_TAG=0

usage() {
  printf 'Usage: %s --parity [--root DIR]\n' "$0" >&2
  printf '       %s --bump --base <ref> [--head <ref>] [--root DIR]\n' "$0" >&2
  printf '       %s --bump --since-latest-tag [--head <ref>] [--root DIR]\n' "$0" >&2
}

# 値を取る option の共通処理。値が無いまま引数列が尽きたら **rc=2 (使い方エラー)**。
# 旧実装は `shift; VAR="${1:-}"` の後の末尾 `shift` が `set -e` 下で失敗し、
# **出力ゼロ・rc=1** で落ちていた (#1257 R2 指摘)。rc=1 は「契約違反を検出した」の
# 意味なので、使い方エラーと混ざると呼び出し側が誤判定する。
_need_value() {
  # $1 = option 名, $2 = 残り引数の個数
  if [ "$2" -lt 2 ]; then
    printf '[version-bump] %s には値が必要です\n' "$1" >&2
    usage
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --parity) MODE=parity ;;
    --bump) MODE=bump ;;
    --since-latest-tag) SINCE_LATEST_TAG=1 ;;
    --base) _need_value --base $#; BASE="$2"; shift ;;
    --head) _need_value --head $#; HEAD="$2"; shift ;;
    --root) _need_value --root $#; ROOT="$(CDPATH= cd -- "$2" && pwd)"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '[version-bump] unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
  shift
done

[ -n "$MODE" ] || { usage; exit 2; }
if [ "$SINCE_LATEST_TAG" = "1" ] && [ -n "$BASE" ]; then
  printf '[version-bump] --base と --since-latest-tag は同時指定できません\n' >&2
  usage
  exit 2
fi

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
    printf '[version-bump] 宣言テーブル (scripts/version_sites.py DECLARED_SITES) と実 manifest が乖離しています\n' >&2
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
if [ -z "$BASE" ] && [ "$SINCE_LATEST_TAG" != "1" ]; then
  printf '[version-bump] --bump には --base か --since-latest-tag が必須です\n' >&2
  usage
  exit 2
fi

command -v git >/dev/null 2>&1 || {
  printf '[version-bump] VERSION_GIT_ABSENT: git が必要です\n' >&2
  exit 3
}
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
  printf '[version-bump] VERSION_GIT_ABSENT: %s は git repo ではありません\n' "$ROOT" >&2
  exit 3
}

if [ "$SINCE_LATEST_TAG" = "1" ]; then
  # リリース経路 (release-prep --check) の base 解決。
  # 「tag が 1 つも無い」は 2 通りあり、混同すると初回リリースが永久に
  # NOT READY になるか、shallow clone を黙って PASS にしてしまう:
  #   * shallow clone  → tag が fetch されていないだけ = **検査できていない** (rc=3)
  #   * 非 shallow で 0 件 → 初回リリース = 比較対象が無い (rc=0 / VERSION_NO_TAG)
  _latest_tag=""
  _latest_tag=$(git -C "$ROOT" describe --tags --abbrev=0 "$HEAD" 2>/dev/null) || _latest_tag=""
  if [ -z "$_latest_tag" ]; then
    _shallow=$(git -C "$ROOT" rev-parse --is-shallow-repository 2>/dev/null || printf 'true')
    if [ "$_shallow" = "true" ]; then
      printf '[version-bump] VERSION_BASE_UNRESOLVED: shallow clone で tag が引けません (--since-latest-tag は完全な履歴を要求します)\n' >&2
      exit 3
    fi
    printf '[version-bump] VERSION_NO_TAG: tag が 1 つも無いため比較対象なし (初回リリース)\n'
    exit 0
  fi
  BASE="$_latest_tag"
  printf '[version-bump] base = 最新 tag %s\n' "$BASE"
fi

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
  # 「変わっている」= bump とは限らない (#1257 R2 指摘)。
  # 1.1.0 -> 1.0.0 のような **downgrade** を通すと、既に tag 済みの version へ
  # 戻す revert PR が「同じ version で別 payload」= #1257 の主症状そのものを
  # 再生産する。順序比較して降格を落とす。
  _cmp=0
  _cmp=$(printf '%s\n%s\n' "$_base_ver" "$_head_ver" | python3 -c \
'import sys
def key(v):
    core = v.strip().lstrip("v").split("+")[0].split("-")[0]
    parts = []
    for token in core.split("."):
        parts.append(int(token) if token.isdigit() else -1)
    return parts
base, head = [key(line) for line in sys.stdin.read().splitlines()[:2]]
if -1 in base or -1 in head:
    print("unknown")       # 数値化できない = 比較しない (安全側で通す判断はしない)
elif head > base:
    print("up")
elif head < base:
    print("down")
else:
    print("same")' 2>/dev/null) || _cmp="unknown"

  if [ "$_cmp" = "down" ]; then
    printf '[version-bump] VERSION_BUMP_DOWNGRADE: %s -> %s は降格です\n' "$_base_ver" "$_head_ver" >&2
    printf '  既に配布済みの version へ戻すと「同じ version で別 payload」(#1257 の主症状) を再生産します。\n' >&2
    exit 1
  fi
  if [ "$_cmp" = "unknown" ]; then
    printf '[version-bump] VERSION_BASE_UNRESOLVED: version を比較できません (base=%s head=%s)\n' \
      "$_base_ver" "$_head_ver" >&2
    exit 3
  fi

  # bump 先が **既に tag として発行済み** で、その tag 時点の配布物と中身が違う場合も
  # 「同じ version で別 payload」になる。tag が無ければこの検査は素通り (これから
  # 発行する新 version が通常経路)。
  #
  # ただし head が **その tag の祖先**なら発火させない。リリース準備コミット
  # （version を X に上げた時点。tag はまだ無い）を、後から tag が打たれた状態で
  # 再検査するとここに来るが、それは「tag へ向かう途中の履歴」であって
  # 別 payload を配る事象ではない（実測: 33d8de8 = v8.21.0 準備コミット）。
  if git -C "$ROOT" rev-parse --verify --quiet "refs/tags/v$_head_ver" >/dev/null 2>&1 &&
     ! git -C "$ROOT" merge-base --is-ancestor "$_head_sha" "refs/tags/v$_head_ver" 2>/dev/null; then
    if ! git -C "$ROOT" diff --quiet "refs/tags/v$_head_ver" "$_head_sha" -- "$WATCH_PATH" 2>/dev/null; then
      printf '[version-bump] VERSION_TAG_PAYLOAD_CONFLICT: version %s は tag v%s として発行済みですが、配布物が tag 時点と一致しません\n' \
        "$_head_ver" "$_head_ver" >&2
      printf '  同じ version 文字列で別 payload を配ることになります (#1257)。新しい version を採ってください。\n' >&2
      exit 1
    fi
  fi

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
