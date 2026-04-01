#!/bin/sh

# Codex から Claude Code にPRレビューを委譲するラッパースクリプト
# 使い方: scripts/codex-claude-review.sh <PR番号>
#
# 注意: Codexサンドボックス内ではclaude CLIのAPI接続がブロックされるため、
# サンドボックス外（ターミナル直接 or Codex approval_policy=on-request）で実行すること。

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  echo "Usage: $0 <PR番号>" >&2
  echo "  例: $0 1356" >&2
  exit 1
fi

# PR存在確認
if ! gh pr view "$PR_NUMBER" --json number >/dev/null 2>&1; then
  echo "Error: PR #${PR_NUMBER} が見つかりません" >&2
  exit 1
fi

cd "$repo_root"

# レビュープロンプトの組み立て（heredocを使わず変数連結で構築）
NL='
'
REVIEW_PROMPT="PR #${PR_NUMBER} のコードレビューを実施してください。"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}${NL}## 手順${NL}"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}1. \`gh pr view ${PR_NUMBER}\` でPR情報を取得"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}2. \`gh pr view ${PR_NUMBER} --json mergeable,mergeStateStatus\` でコンフリクト確認"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}3. \`gh pr checks ${PR_NUMBER}\` でCIステータス確認"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}4. \`gh pr diff ${PR_NUMBER}\` で差分を取得し精読"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}5. \`.claude/rules/review-principles.md\` のレビュー原則に従いレビュー"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}6. \`.claude/rules/review-principles.md\` の構造化出力フォーマット(YAML + 人間向け要約)で結果を出力"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}${NL}## 制約${NL}"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}- コードの変更は一切行わない（読み取り専用）"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}- 日本語で回答する"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}- phpstan/phpcs/eslint/typecheck で検出可能な問題は指摘しない"
REVIEW_PROMPT="${REVIEW_PROMPT}${NL}- 推測に基づく指摘は「推測」と明記する"

# Claude Code を print モードで実行（読み取り専用）
printf '%s' "$REVIEW_PROMPT" | exec claude -p \
  --model sonnet \
  --allowedTools "Bash(gh pr view:*),Bash(gh pr diff:*),Bash(gh pr checks:*),Bash(gh run view:*),Bash(git diff:*),Bash(git log:*),Bash(git show:*),Read,Grep,Glob" \
  --disallowedTools "Edit,Write,Agent,NotebookEdit"
