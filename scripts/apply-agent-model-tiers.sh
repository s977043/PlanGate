#!/bin/sh
# apply-agent-model-tiers.sh — 定型・構造化 tier 6 体に model: sonnet を適用（Human 実行）
#
# 正本: docs/ai/model-profiles.md §11（2026-06-10 ユーザー承認の 2 tier 設計）。
# .claude/agents/*.md は Hardening Override 対象のため AI は本スクリプトの作成と
# --dry-run までを担い、--apply は Human が実行する。
# plugin 配布版は sync-plugin-plangate.sh が model: inherit へ自動正規化するため
# 本適用は配布物に影響しない。
#
# 使い方:
#   sh scripts/apply-agent-model-tiers.sh --dry-run   # 変更内容の確認
#   sh scripts/apply-agent-model-tiers.sh --apply     # 適用（冪等）
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS="explorer-agent linter-fixer retrospective-analyst setup-coordinator documentation-writer skill-designer"

for a in $AGENTS; do
  f="$ROOT/.claude/agents/$a.md"
  [ -f "$f" ] || { echo "SKIP (not found): $a"; continue; }
  current="$(grep -m1 '^model:' "$f" || true)"
  if [ "$current" = "model: sonnet" ]; then
    echo "OK (already): $a"
    continue
  fi
  if [ "$MODE" = "--dry-run" ]; then
    echo "[dry-run] $a: '$current' -> 'model: sonnet'"
  elif [ "$MODE" = "--apply" ]; then
    sed -i.bak 's/^model: .*/model: sonnet/' "$f" && rm -f "$f.bak"
    echo "APPLIED: $a"
  else
    echo "usage: $0 [--dry-run|--apply]"; exit 1
  fi
done
[ "$MODE" = "--apply" ] && echo "適用完了。sh scripts/sync-plugin-plangate.sh で plugin 正規化を確認し、コミットしてください。"
exit 0
