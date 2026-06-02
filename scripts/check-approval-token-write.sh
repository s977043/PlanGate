#!/bin/sh
# check-approval-token-write.sh — 承認トークン系ファイルへの AI 直接書き込みを block
# TASK-0123 (#420)
# hook として .claude/settings.json に登録する（Human-owned）
# 配置: scripts/ ルート（HO 外）

set -eu

TARGET="${PLANGATE_HOOK_FILE:-}"
if [ -z "$TARGET" ]; then
  exit 0
fi

# PLANGATE_SKIP_TOKEN_GUARD=1 で全スキップ
if [ "${PLANGATE_SKIP_TOKEN_GUARD:-0}" = "1" ]; then
  exit 0
fi

# ブロック対象パターン
case "$TARGET" in
  *maintenance.json*|*/approvals/*.json|*c3.json*|*parent-c3.json*|*parent-integration.json*)
    printf "[EH-token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。
" >&2
    printf "  対象ファイル: %s
" "$TARGET" >&2
    printf "  正規操作: bin/plangate maintenance start（Human TTY）または人間が手動で発行
" >&2
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
