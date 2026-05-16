#!/bin/sh
# verify-pr-merged.sh — PR 後処理ガード（TASK-0069 振り返り P2）
#
# PR 関連の破壊操作（ローカル/リモートブランチ削除・main 同期後の cleanup）
# の前に、対象 PR が「実マージ確定」かを検証する。
# state==MERGED かつ mergedAt/mergeCommit が non-null の三点を必須とする。
#
# Usage:
#   sh scripts/verify-pr-merged.sh <PR_NUMBER>
# Exit:
#   0  マージ確定（後処理に進んでよい）
#   1  未マージ/未確定（破壊操作を行ってはならない）
#   2  引数誤り/前提不足
#
# 背景: 2026-05-16 TASK-0069 で「マージした」発言を信用しマージ未確定の
#       まま git push origin --delete を実行し PR を未マージ CLOSE させた
#       事故の再発防止。
set -eu

pr=${1:-}
case "$pr" in
  ''|*[!0-9]*)
    printf 'Usage: %s <PR_NUMBER>\n' "$0" >&2
    exit 2
    ;;
esac

command -v gh >/dev/null 2>&1 || { printf 'error: gh CLI not found\n' >&2; exit 2; }

json=$(gh pr view "$pr" --json state,mergedAt,mergeCommit 2>/dev/null) || {
  printf 'error: gh pr view %s failed\n' "$pr" >&2
  exit 2
}

state=$(printf '%s' "$json" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')
merged_at=$(printf '%s' "$json" | sed -n 's/.*"mergedAt":"\([^"]*\)".*/\1/p')
merge_commit=$(printf '%s' "$json" | sed -n 's/.*"mergeCommit":{"oid":"\([0-9a-f]*\)".*/\1/p')

if [ "$state" = "MERGED" ] && [ -n "$merged_at" ] && [ -n "$merge_commit" ]; then
  printf '[verify-pr-merged] PR #%s MERGED (commit %s, at %s) — cleanup OK\n' \
    "$pr" "$merge_commit" "$merged_at"
  exit 0
fi

printf '[verify-pr-merged] PR #%s NOT confirmed merged (state=%s mergedAt=%s mergeCommit=%s)\n' \
  "$pr" "${state:-?}" "${merged_at:-null}" "${merge_commit:-null}" >&2
printf '  → ブランチ削除等の破壊操作を行わないこと。\n' >&2
exit 1
