#!/bin/sh
# scripts/add-codeql-workflow.sh — CodeQL SAST ワークフロー追加 (Scorecard #7)
#
# .github/workflows/codeql.yml は HO 対象のため AI が本スクリプトを生成し、
# --apply は Human が実行する。
#
# 使い方:
#   sh scripts/add-codeql-workflow.sh --dry-run
#   sh scripts/add-codeql-workflow.sh --apply

set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/.github/workflows/codeql.yml"

# Pin SHA (actions/checkout@v4 / github/codeql-action@v3)
CHECKOUT_V4_SHA="11bd71901bbe5b1630ceea73d27597364c9af683"
CODEQL_V3_SHA="dd903d2e4f5405488e5ef1422510ee31c8b32357"

CONTENT="name: CodeQL

# Scorecard #7 SAST: Python コードを CodeQL で静的解析する。
# スクリプト類 (scripts/*.py) を対象。シェルスクリプトは対象外。

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '30 5 * * 1'  # 毎週月曜 05:30 UTC

permissions:
  contents: read

jobs:
  analyze:
    name: Analyze (python)
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write

    steps:
      - name: Checkout
        uses: actions/checkout@${CHECKOUT_V4_SHA} # v4
        with:
          fetch-depth: 2

      - name: Initialize CodeQL
        uses: github/codeql-action/init@${CODEQL_V3_SHA} # v3
        with:
          languages: python
          queries: security-extended

      - name: Autobuild
        uses: github/codeql-action/autobuild@${CODEQL_V3_SHA} # v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@${CODEQL_V3_SHA} # v3
        with:
          category: '/language:python'
"

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] .github/workflows/codeql.yml を以下の内容で作成します:\n\n'
  printf '%s\n' "$CONTENT"
  exit 0
elif [ "$MODE" = "--apply" ]; then
  if [ -f "$TARGET" ]; then
    printf 'SKIP: %s は既に存在します\n' "$TARGET"
    exit 0
  fi
  printf '%s\n' "$CONTENT" > "$TARGET"
  printf 'APPLIED: %s を作成しました\n' "$TARGET"
else
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2
  exit 1
fi
