#!/bin/sh
# check-committed-memory-pollution.sh — コミット済み SSoT に AI memory 汚染がないか検査
#
# pre-commit hook (scripts/hooks/check-ai-memory-pollution.sh) は staged 変更のみを
# 検査するため、既にコミット済みの汚染（例: AGENTS.md に過去混入した
# <claude-mem-context> ブロック）は検知できない。本スクリプトは CI 用に
# 対象ファイル全体をスキャンし、コミット済み汚染の残存を検出する（#452）。
#
# Usage: sh scripts/check-committed-memory-pollution.sh [--warn-only]
# Exit: 0=クリーン, 1=汚染検出（--warn-only 時は常に 0）

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WARN_ONLY=0
[ "${1:-}" = "--warn-only" ] && WARN_ONLY=1

# 検査対象 SSoT
TARGETS="AGENTS.md CLAUDE.md"
# AI memory ツール（claude-mem 等）が自動挿入する汚染パターン
PATTERN='<claude-mem-context>|</claude-mem-context>|get_observations|mem-search skill'

found=0
for f in $TARGETS; do
  [ -f "$REPO_ROOT/$f" ] || continue
  if grep -nE "$PATTERN" "$REPO_ROOT/$f" >/dev/null 2>&1; then
    printf '[mem-pollution] %s に AI memory 汚染パターンを検出:\n' "$f"
    grep -nE "$PATTERN" "$REPO_ROOT/$f" | sed 's/^/  /'
    found=1
  fi
done

if [ "$found" = "0" ]; then
  printf '[mem-pollution] OK: コミット済み SSoT に汚染なし\n'
  exit 0
fi

printf '\n除去方法: 該当 SSoT から <claude-mem-context>...</claude-mem-context> ブロックを削除してください。\n'
[ "$WARN_ONLY" = "1" ] && { printf '[mem-pollution] --warn-only: 継続\n'; exit 0; }
exit 1
