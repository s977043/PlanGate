#!/bin/sh
# gh-pin-account.sh — plangate 作業時に gh CLI active account を s977043 に固定
#
# 背景: retrospective 2026-05-01 P-1 — plangate での作業中に gh CLI の active
# account が想定外に kominem-unilabo へ切り戻る現象（本セッションで 4 回以上発生）。
# 共有 mutation（pr merge / pr comment / issue create）が 403 で失敗する原因。
#
# Usage:
#   sh scripts/gh-pin-account.sh                      # デフォルト: s977043
#   PLANGATE_GH_USER=other-user sh scripts/gh-pin-account.sh
#
# Exit code:
#   0  正しいユーザーに切り替え済み（または既に正しい状態）
#   1  gh CLI 不在 / 該当ユーザーが logged-in に存在しない
#   2  切り替え試行が失敗（権限エラー等）
#
# Issue #171 / TASK-0052

set -eu

DESIRED_USER=${PLANGATE_GH_USER:-s977043}

if ! command -v gh >/dev/null 2>&1; then
  printf 'gh-pin-account: gh CLI not installed, skipping\n' >&2
  exit 1
fi

# 現在の active account を取得（gh CLI バージョン差異を考慮した複数戦略）
current=$(gh api user --jq .login 2>/dev/null || true)
if [ -z "$current" ]; then
  # Fallback: gh auth status から抽出
  current=$(gh auth status 2>&1 | grep -B1 "Active account: true" | grep -oE "account [^ ]+" | awk '{print $2}' | head -1 || true)
fi

if [ "$current" = "$DESIRED_USER" ]; then
  printf 'gh-pin-account: already pinned to %s\n' "$DESIRED_USER"
  exit 0
fi

# 該当ユーザーが logged-in 一覧にあるか確認
if ! gh auth status 2>&1 | grep -q "account $DESIRED_USER"; then
  printf 'gh-pin-account: %s is not in `gh auth status` (run: gh auth login -u %s)\n' "$DESIRED_USER" "$DESIRED_USER" >&2
  exit 1
fi

# 切り替え実行
if gh auth switch -u "$DESIRED_USER" >/dev/null 2>&1; then
  printf 'gh-pin-account: switched to %s\n' "$DESIRED_USER"
  exit 0
fi

printf 'gh-pin-account: failed to switch to %s\n' "$DESIRED_USER" >&2
exit 2
