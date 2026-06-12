#!/bin/sh
# check-approval-token-write.sh — 承認トークン系ファイルへの AI 直接書き込みを block
# TASK-0123 (#420) + TASK-0128 R-002 (Bash matcher 対応)
# hook として .claude/settings.json に登録する（Human-owned）
# 配置: scripts/ ルート（HO 外）
#
# 対応 matcher:
#   Edit|Write … PLANGATE_HOOK_FILE env もしくは stdin JSON .tool_input.file_path
#   Bash       … stdin JSON .tool_input.command 文字列中の token path + 書き込み操作を検出
#                （`cat > .../approvals/c3.json` 等の Bash 経由バイパスを塞ぐ / R-002）

set -eu

# PLANGATE_SKIP_TOKEN_GUARD=1 で全スキップ（緊急/テスト用）
if [ "${PLANGATE_SKIP_TOKEN_GUARD:-0}" = "1" ]; then
  exit 0
fi

# token path パターン（共通）
_is_token_path() {
  case "$1" in
    *maintenance.json*|*/approvals/*.json|*c3.json*|*parent-c3.json*|*parent-integration.json*) return 0 ;;
    *) return 1 ;;
  esac
}

_block() {
  printf '[EH-token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。\n' >&2
  printf '  検出: %s\n' "$1" >&2
  printf '  正規操作: bin/plangate approve <TASK>（Human TTY / TASK-0128）または bin/plangate maintenance start\n' >&2
  exit 1
}

# --- 1) Edit|Write: env 優先、無ければ stdin JSON の file_path ---
TARGET="${PLANGATE_HOOK_FILE:-}"

# stdin JSON を一度だけ読む（env で解決できない場合の補完 + Bash command 取得）
_stdin=""
if [ -z "$TARGET" ]; then
  _stdin=$(cat 2>/dev/null || true)
fi

if [ -z "$TARGET" ] && [ -n "$_stdin" ] && command -v jq >/dev/null 2>&1; then
  TARGET=$(printf '%s' "$_stdin" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null || true)
fi

if [ -n "$TARGET" ]; then
  if _is_token_path "$TARGET"; then
    _block "file_path=$TARGET"
  fi
fi

# --- 2) Bash: command 文字列を解析（R-002） ---
# Edit|Write で解決した TARGET が token でない場合や、Bash 起動時はこちら。
if [ -n "$_stdin" ] && command -v jq >/dev/null 2>&1; then
  _cmd=$(printf '%s' "$_stdin" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  if [ -n "$_cmd" ]; then
    # token path を含むか
    if _is_token_path "$_cmd"; then
      # 書き込み操作の指標を含むか（読み取り cat/grep 等の誤検知を避ける）
      case "$_cmd" in
        *'>'*|*tee*|*' cp '*|*' mv '*|*' dd '*|*'install '*|*'sed -i'*|*"open("*|*'truncate'*|*'>>'*)
          _block "Bash command writes token path: $_cmd"
          ;;
      esac
    fi
  fi
fi

exit 0
