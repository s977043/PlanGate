#!/bin/sh
# apply-task-0124-patches.sh — TASK-0124 HO ファイル変更適用スクリプト
# Human が実行: sh scripts/apply-task-0124-patches.sh [--dry-run]

set -eu
REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi
_log() { printf '[apply-task-0124] %s\n' "$1"; }
_dry() { printf '[apply-task-0124][dry-run] %s\n' "$1"; }

###############################################################################
# Patch 1: .github/workflows/sync-plugin-plangate.yml を新規作成
###############################################################################
WF_FILE="$REPO_ROOT/.github/workflows/sync-plugin-plangate.yml"

if [ -f "$WF_FILE" ]; then
  _log "SKIP (already exists): sync-plugin-plangate.yml"
else
  if [ "$DRY_RUN" = "1" ]; then
    _dry "WOULD CREATE: .github/workflows/sync-plugin-plangate.yml"
  else
    cat > "$WF_FILE" << 'YAML'
name: sync-plugin-plangate

# plugin/plangate/ を main push のたびに .claude/ と同期し、差分あり時に PR を自動作成。
# merge は Human-owned (C-4)。

on:
  push:
    branches: [main]
    paths:
      - '.claude/**'
      - '.agents/skills/**'
      - 'CHANGELOG.md'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  sync:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - name: Run sync script
        run: sh scripts/sync-plugin-plangate.sh

      - name: Check for changes
        id: diff
        run: |
          if git diff --quiet -- plugin/plangate/; then
            echo "changed=false" >> "$GITHUB_OUTPUT"
          else
            echo "changed=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Create PR if changed
        if: steps.diff.outputs.changed == 'true'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          branch="chore/plugin-sync-${{ github.run_id }}"
          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git checkout -b "$branch"
          git add plugin/plangate/
          git commit -m "chore(plugin): .claude/ → plugin/plangate/ 自動同期"
          git push origin "$branch"
          gh pr create \
            --base main \
            --head "$branch" \
            --title "chore(plugin): plugin/plangate/ 自動同期" \
            --body "push to main をトリガーに \`scripts/sync-plugin-plangate.sh\` が .claude/ との差分を検出しました。merge は Human-owned (C-4)。"
YAML
    _log "CREATED: .github/workflows/sync-plugin-plangate.yml"
  fi
fi

_log "Done. Run 'sh scripts/sync-plugin-plangate.sh' to apply the initial sync."
