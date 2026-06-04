#!/bin/sh
# check-codex-commands.sh — README/docs に実在しない codex サブコマンドが
# 「コマンド例」として含まれていないか検査する。
#
# v8.11.0 の Critical Fix（実在しない `codex plugin install` の誤記）の再発防止。
# 注記文（「〜はありません」等の説明）は許容し、コマンド例（行頭が codex の行）のみ検査する。
#
# Usage: sh scripts/check-codex-commands.sh [--warn-only]
# Exit: 0=OK, 1=invalid command example found（--warn-only 時は常に 0）

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WARN_ONLY=0
[ "${1:-}" = "--warn-only" ] && WARN_ONLY=1

cd "$REPO_ROOT"

# 検査対象（docs/working/ は作業ログなので除外）
TARGETS="README.md README_en.md docs plugin"

# 実在しない / 未実装の codex サブコマンド（コマンド例として書いてはいけない）
#   codex plugin install            — install サブコマンド自体が存在しない
#   codex plugin marketplace list   — 現行 Codex CLI で未実装
INVALID_CMDS="codex plugin install|codex plugin marketplace list"

violations=0

# 行頭（インデント可）が無効コマンドで始まる行 = コマンド例。
# 説明文中の言及（行頭が記号や文字）は除外される。
matches=$(grep -rnE "^[[:space:]]*(${INVALID_CMDS})([[:space:]]|\$)" $TARGETS 2>/dev/null \
  | grep -v "docs/working/" || true)

if [ -n "$matches" ]; then
  printf '[check-codex] 実在しない codex コマンドがコマンド例として含まれています:\n'
  printf '%s\n' "$matches"
  printf '\n有効な codex plugin サブコマンド: marketplace / help\n'
  printf '有効な marketplace サブコマンド: add / upgrade / remove / help\n'
  violations=1
fi

if [ "$violations" = "0" ]; then
  printf '[check-codex] OK: 無効な codex コマンド例なし\n'
  exit 0
fi

if [ "$WARN_ONLY" = "1" ]; then
  printf '[check-codex] --warn-only: 違反を検出しましたが継続します\n'
  exit 0
fi
exit 1
