#!/bin/sh
# check-branch-not-merged.sh — push 前ガード（振り返り #2 / 2026-06-16）
# 「マージ削除済ブランチを push で誤再作成」を防ぐ。
#
# 現ブランチ名に対応する PR が既に MERGED かつ remote ブランチが削除済みの場合に警告して
# 非ゼロ終了する。push 直前に実行（pre-push hook or 手動）。
#
# Usage: sh scripts/check-branch-not-merged.sh [branch]
# Exit: 0=安全（新規/未マージ）, 1=マージ済ブランチの再作成リスク（要確認）
set -eu

BR="${1:-$(git rev-parse --abbrev-ref HEAD)}"
case "$BR" in main|master|HEAD) exit 0 ;; esac
command -v gh >/dev/null 2>&1 || { printf '[branch-guard] gh 未導入のためスキップ\n'; exit 0; }

# remote に同名ブランチが存在するか
if git ls-remote --exit-code --heads origin "$BR" >/dev/null 2>&1; then
  exit 0   # remote に存在 = 通常の push（再作成ではない）
fi

# remote に無い → この head の PR が MERGED 済みなら「マージ後に削除されたブランチ」
_state=$(gh pr list --state all --head "$BR" --json state --jq '.[0].state // empty' 2>/dev/null || true)
if [ "$_state" = "MERGED" ]; then
  printf '[branch-guard] BLOCK: ブランチ "%s" は既に MERGED され remote 削除済みです。\n' "$BR" >&2
  printf '  この push はマージ済ブランチを再作成します（振り返り #2 の再発）。\n' >&2
  printf '  修正は main 起点の follow-up ブランチに切り直してください:\n' >&2
  printf '    git fetch origin && git checkout -b fix/<topic> origin/main\n' >&2
  exit 1
fi
exit 0
