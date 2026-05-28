#!/bin/sh
# gh-s977043.sh — gh 操作の直前に active account を s977043 へ強制するラッパ
#
# TASK-0120 (#... Session Retro Try #2) / Issue #171 系列
#
# 背景:
#   session 中に gh CLI の active account が想定外に別アカウントへ切り戻り、
#   共有 mutation (pr create / pr merge / GraphQL) が 403/FORBIDDEN で失敗する
#   現象が多発。SessionStart hook (gh-pin-account.sh) は session 開始時に
#   1 回だけ pin するため、session 中の drift には対応できない。
#
# 責務分界:
#   - scripts/gh-pin-account.sh (TASK-0052): SessionStart 時に 1 回 pin
#   - 本ラッパ (TASK-0120): 各 gh 操作の直前に switch を強制 (drift 対応)
#   両者は補完関係。二重 pinning にはならない (冪等: 既に desired なら skip)。
#
# Usage:
#   sh scripts/gh-s977043.sh pr create ...
#   sh scripts/gh-s977043.sh pr merge 123 --squash
#   PLANGATE_GH_USER=other sh scripts/gh-s977043.sh <gh args>   # user 上書き
#
# Exit code:
#   gh の exit code を透過 (exec)。gh 不在時のみ 127。
#
# 注: 既定ユーザーは s977043 (gh auth switch --user s977043 を内部で実行)。

set -eu

DESIRED_USER="${PLANGATE_GH_USER:-s977043}"

if ! command -v gh >/dev/null 2>&1; then
  printf 'gh-s977043: gh CLI not installed\n' >&2
  exit 127
fi

# 冪等: 既に desired account なら switch を skip (二重 pinning 回避)
current=$(gh api user --jq .login 2>/dev/null || true)
if [ "$current" != "$DESIRED_USER" ]; then
  # 既定は s977043: `gh auth switch --user s977043` 相当を実行
  if gh auth switch --user "$DESIRED_USER" >/dev/null 2>&1; then
    printf 'gh-s977043: switched to %s\n' "$DESIRED_USER" >&2
  else
    # エッジケース: 該当 user 未登録 / 権限不足環境 → warning + 続行
    printf 'gh-s977043: WARNING switch to %s failed (未登録/権限不足?), 続行\n' "$DESIRED_USER" >&2
  fi
fi

exec gh "$@"
