#!/bin/sh
# check-delegation-commit-boundary.sh — Hook EH-9: 委譲 commit/push 境界検知
#
# Claude Code PreToolUse hook（Bash の前）。委譲先サブエージェントが
# 「commit/push しない」境界（todo.md メタ delegation_commit_boundary:
# no-commit → 親が PLANGATE_DELEGATION_NOCOMMIT=1 を注入）を破って
# git commit/push 相当を実行しようとした場合に決定論検出する（#239 問題2/F2）。
#
# 信頼境界: PreToolUse では **stdin JSON tool_input.command を正本** とする。
# env PLANGATE_HOOK_CMD は CLI テスト専用（stdin 不在時のみ）。
#
# Modes（no-commit 宣言下）:
#   default                       違反は block（高 risk 恒久対処。warn は廃止）
#   PLANGATE_BYPASS_HOOK=1        常時 allow（既存慣行: bypass 最優先）
# 未宣言（PLANGATE_DELEGATION_NOCOMMIT!=1）: 常に従来動作（誤検出ゼロ）
#
# 既知制約: ユーザー定義 git alias は解決不能（exec 後検証が fail-closed
# バックストップ。todo.md メタを直接読む）。
#
# 監査: docs/working/_audit/hook-events.log（command 全文は記録せず class+hash）
#
# F2 / TASK-0073 / V-3 fix-loop 反映

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

json_escape() {
  # " \ と制御文字を最小エスケープ
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t'
}

emit_judgment() {
  decision=$1
  reason=$(json_escape "${2:-}")
  if [ "$decision" = "block" ]; then
    printf '{"continue":false,"stopReason":"%s"}\n' "$reason"
  else
    printf '{"continue":true}\n'
  fi
}

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-delegation-commit-boundary\t%s\t%s\n' \
    "$ts" "$level" "${PLANGATE_HOOK_TASK:--}" "$msg" >>"$AUDIT_LOG"
}

# bypass（既存慣行: bypass > 通常）
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  emit_judgment "allow"
  exit 0
fi

# 境界未宣言 → 従来動作（誤検出ゼロ）
if [ "${PLANGATE_DELEGATION_NOCOMMIT:-0}" != "1" ]; then
  emit_judgment "allow"
  exit 0
fi

# 対象コマンド解決: stdin JSON を正本、env は CLI テスト fallback
cmd=""
if [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
  if [ -n "$_stdin" ]; then
    if command -v jq >/dev/null 2>&1; then
      cmd=$(printf '%s' "$_stdin" | jq -r '.tool_input.command // .command // empty' 2>/dev/null | head -1)
    fi
    if [ -z "$cmd" ]; then
      cmd=$(printf '%s' "$_stdin" \
        | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    fi
  fi
fi
if [ -z "$cmd" ]; then
  cmd=${PLANGATE_HOOK_CMD:-}
fi

# 正規化: env 代入前置 / `command ` / クォート除去 を緩く吸収して判定
norm=$(printf '%s' "$cmd" \
  | tr '\t' ' ' \
  | sed "s/'//g; s/\"//g")

# git 書き込み相当 or gh merge/sync を検出（決定論。宣言下のみ到達）
# - 任意 ENV=val 前置, `command `, `git -c k=v`, `git -C path` を許容して
#   git の commit/push サブコマンドを検出
# - gh pr merge / gh repo sync も commit/push 相当として扱う
violation=0
case " $norm " in
  *" git "*)
    # git トークン以降に commit / push が現れるか（オプション跨ぎ許容）
    after=${norm#*git }
    case " $after " in
      *" commit"*|*"commit "*|*" push"*|*"push "*|*" ci "*|*" ci"*) violation=1 ;;
    esac
    ;;
esac
case " $norm " in
  *" gh pr merge"*|*" gh repo sync"*|*"gh pr merge"*) violation=1 ;;
esac
# sh -c '... git commit ...' のような二段実行
case "$norm" in
  *"sh -c "*git*commit*|*"sh -c "*git*push*|*"bash -c "*git*commit*|*"bash -c "*git*push*) violation=1 ;;
esac

if [ "$violation" = "1" ]; then
  cmd_hash=$(printf '%s' "$cmd" | { command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256; } | awk '{print $1}')
  cmd_class="git-write-or-gh-merge"
  log_event "VIOLATION" "delegated no-commit boundary violated; class=$cmd_class hash=${cmd_hash%% *}"
  emit_judgment "block" "EH-9: 委譲境界違反 — 委譲先は commit/push しない（完了フェーズは親が実施）"
  exit 0
fi

emit_judgment "allow"
exit 0
