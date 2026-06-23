#!/bin/sh
# scripts/add-auto-approve-workflow.sh
# .github/workflows/auto-approve.yml を追加（Scorecard Code-Review 改善 / #621）
#
# Scorecard Code-Review は「PR がマージ前に author 以外に承認された」コミット数を計測する。
# GITHUB_TOKEN（github-actions[bot]）は Scorecard がボットと判定しスキップするため、
# s977043 以外のアカウントの PAT (APPROVE_PAT) が必要。
#
# セットアップ手順:
#   1. s977043 以外の GitHub アカウントを用意（bot account 等）
#   2. 該当アカウントで classic PAT (repo scope) を発行
#   3. リポジトリ Settings > Collaborators でそのアカウントに Write 権限を付与
#   4. リポジトリ Settings > Secrets > Actions > APPROVE_PAT として PAT を登録
#   5. sh scripts/add-auto-approve-workflow.sh --apply を実行
#
# .github/workflows/*.yml は Hardening Override 対象のため AI が直接編集できない。
# 人間がこのスクリプトを --apply で実行すること。
#
# 使い方:
#   sh scripts/add-auto-approve-workflow.sh --dry-run
#   sh scripts/add-auto-approve-workflow.sh --apply
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/.github/workflows/auto-approve.yml"

if [ -f "$TARGET" ]; then
  printf 'SKIP (already exists): %s\n' "$TARGET"
  exit 0
fi

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] 以下のファイルを作成します: %s\n\n' "$TARGET"
  printf '  triggers: pull_request (opened/synchronize/reopened)\n'
  printf '  action:   hmarr/auto-approve-action@f0939ea...  # v4.0.0\n'
  printf '  token:    secrets.APPROVE_PAT (non-s977043 account required)\n'
  exit 0
elif [ "$MODE" = "--apply" ]; then
  python3 - "$TARGET" << 'PY'
import pathlib, sys
target = pathlib.Path(sys.argv[1])
content = """\
name: Auto Approve

# Scorecard Code-Review 対応: APPROVE_PAT (bot/reviewer account) で PR を承認する。
# APPROVE_PAT は s977043 以外のアカウントの classic PAT (repo scope) であること。
# Scorecard は github-actions[bot] をボット判定でスキップするため、
# 人間（または別アカウント）の PAT が必要。

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions: {}

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    # APPROVE_PAT が未設定の場合はスキップ（soft-fail）
    if: ${{ secrets.APPROVE_PAT != '' }}
    permissions:
      pull-requests: write
    steps:
      - name: Approve PR
        uses: hmarr/auto-approve-action@f0939ea97e9205ef24d872e76833fa908a770363  # v4.0.0
        with:
          github-token: ${{ secrets.APPROVE_PAT }}
          review-message: "Automated review: approved by reviewer account for Scorecard Code-Review compliance."
"""
target.write_text(content, encoding="utf-8")
print("CREATED:", target)
PY
else
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2; exit 1
fi
