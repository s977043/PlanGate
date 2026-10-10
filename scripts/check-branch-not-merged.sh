#!/bin/sh
# check-branch-not-merged.sh — push 前ガード（振り返り #2 / 2026-06-16）
# 「マージ削除済ブランチを push で誤再作成」を防ぐ。
#
# 現ブランチ名に対応する PR が既に MERGED かつ remote ブランチが削除済みの場合に警告して
# 非ゼロ終了する。push 直前に実行（pre-push hook or 手動）。
#
# Usage: sh scripts/check-branch-not-merged.sh [branch]
# Exit: 0=ローカルhookはpushを妨げない（未検証/WARNも含む）, 1=MERGED+remote削除済の再作成をblock
#       0 は「安全を証明した」を意味しない。認可・安全性の正本はremote保護ポリシー。
set -eu

BR="${1:-$(git rev-parse --abbrev-ref HEAD)}"
case "$BR" in main|master|HEAD) exit 0 ;; esac
command -v gh >/dev/null 2>&1 || { printf '[branch-guard] gh 未導入のためスキップ\n'; exit 0; }

# remote に同名ブランチが存在するか
if git ls-remote --exit-code origin "refs/heads/$BR" >/dev/null 2>&1; then
  exit 0   # remote に存在 = 通常の push（再作成ではない）
fi

# remote に無い → 同名ブランチの MERGED PR が 1 件でもあれば再作成を block。
# all の先頭 1 件だけを見ると、後から作られた OPEN/CLOSED PR が先頭となり
# 過去の MERGED 履歴を見逃す。--state merged で正確に照会する。
if _merged_count=$(gh pr list --state merged --head "$BR" --limit 1 --json number --jq 'length' 2>/dev/null); then
  # An invalid response is NOT evidence that no merged PR exists.
  case "$_merged_count" in
    0|1) ;;
    *) printf '[branch-guard] WARN: unexpected GitHub PR history response for "%s"; cannot verify\n' "$BR" >&2; exit 0 ;;
  esac
else
  # Local pre-push checks are advisory. Do not silently report success on
  # auth/API/network failures; the remote rules are the actual authority.
  printf '[branch-guard] WARN: GitHub PR history unavailable for "%s"; cannot verify\n' "$BR" >&2
  exit 0
fi
if [ "$_merged_count" = "1" ]; then
  printf '[branch-guard] BLOCK: ブランチ "%s" は既に MERGED され remote 削除済みです。\n' "$BR" >&2
  printf '  この push はマージ済ブランチを再作成します（振り返り #2 の再発）。\n' >&2
  printf '  修正は main 起点の follow-up ブランチに切り直してください:\n' >&2
  printf '    git fetch origin && git checkout -b fix/<topic> origin/main\n' >&2
  exit 1
fi
exit 0
