#!/bin/sh
# check-approval-token-write.sh — 承認トークン系ファイルへの AI 直接書き込みを block
# TASK-0123 (#420) + TASK-0128 R-002 (Bash matcher) + #546 Codex review (書込検出強化/読み取り誤検知解消)
# hook として .claude/settings.json に登録する（Human-owned）
# 配置: scripts/ ルート（HO 外）
#
# 対応 matcher:
#   Edit|Write … PLANGATE_HOOK_FILE env もしくは stdin JSON .tool_input.file_path
#   Bash       … stdin JSON .tool_input.command 中の token path + 「書き込み意図」を検出
#                （cat>/tee/cp/mv/ln/install/dd/truncate/sed -i/python write_text・open(...,"w") 等）
#                読み取り（cat/open(...).read 等）は block しない。

set -eu

# PLANGATE_SKIP_TOKEN_GUARD=1 で全スキップ（緊急/テスト用）
if [ "${PLANGATE_SKIP_TOKEN_GUARD:-0}" = "1" ]; then
  exit 0
fi

_is_token_path() {
  case "$1" in
    *maintenance.json*|*/approvals/*.json|*c3.json*|*parent-c3.json*|*parent-integration.json*) return 0 ;;
    *) return 1 ;;
  esac
}

# Bash コマンド文字列に「書き込み意図」があるか（読み取りは false を返す）
_has_write_intent() {
  _wc="$1"
  # リダイレクト > / >>
  printf '%s' "$_wc" | grep -q '>' && return 0
  # 書き込み系コマンドが語境界で出現（行頭・; & | ( 直後・空白区切り）
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])(cp|mv|ln|install|dd|tee|truncate)([[:space:]]|$)' && return 0
  # sed -i（in-place 書き込み）
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])sed([[:space:]]+-[A-Za-z]*i|[[:space:]]+--in-place)' && return 0
  # python の書き込み: write_text / write_bytes / .write( / open(..., "w|a|x|+")
  printf '%s' "$_wc" | grep -qE 'write_text|write_bytes|\.write\(' && return 0
  printf '%s' "$_wc" | grep -qE "open\([^)]*,[^)]*['\"][^'\"]*[wax+]" && return 0
  return 1
}

_block() {
  printf '[EH-token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。\n' >&2
  printf '  検出: %s\n' "$1" >&2
  printf '  正規操作: bin/plangate approve <TASK>（Human TTY / TASK-0128）または bin/plangate maintenance start\n' >&2
  exit 1
}

# --- 1) Edit|Write: env 優先、無ければ stdin JSON の file_path ---
TARGET="${PLANGATE_HOOK_FILE:-}"
_stdin=""
if [ -z "$TARGET" ]; then
  _stdin=$(cat 2>/dev/null || true)
fi
if [ -z "$TARGET" ] && [ -n "$_stdin" ] && command -v jq >/dev/null 2>&1; then
  TARGET=$(printf '%s' "$_stdin" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null || true)
fi
if [ -n "$TARGET" ] && _is_token_path "$TARGET"; then
  _block "file_path=$TARGET"
fi

# --- 2) Bash: command 文字列を解析（token path かつ 書き込み意図） ---
if [ -n "$_stdin" ] && command -v jq >/dev/null 2>&1; then
  _cmd=$(printf '%s' "$_stdin" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  if [ -n "$_cmd" ] && _is_token_path "$_cmd" && _has_write_intent "$_cmd"; then
    _block "Bash command writes token path: $_cmd"
  fi
fi

exit 0
