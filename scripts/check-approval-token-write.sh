#!/bin/sh
# check-approval-token-write.sh — 承認トークン系ファイルへの AI 直接書き込みを block（EH-13）
# TASK-0123 (#420) + TASK-0128 R-002 (Bash matcher) + #546 Codex review
# + TASK-1023 (#1023) 二重無効化の封鎖:
#   - block を exit 1 → exit 2 へ（PreToolUse の block 契約。exit 1 は非 block）
#   - stdin を env target の有無に関係なく常時・独立に評価（env 供給時の stdin bypass 封鎖）
#   - jq 不在 / malformed / empty / TTY / read error は parse-unknown として fail-closed
#     （G-7=(a) Human 裁定: stdin 未供給の手実行が exit 2 になる副作用を許容。
#      診断/手実行の escape hatch は PLANGATE_SKIP_TOKEN_GUARD=1 = Human-owned）
#   - target は env → $1 fallback（現行 settings 呼出は引数なしのため $1 経路は実行時
#     dead code。契約 drift は #928 に残存）
#   - parsed-safe tool 集合は Edit / Write / MultiEdit / Bash の固定 4 種（G-8=(a)）。
#     MultiEdit は tool_input.file_path のみ評価（edits[] は評価しない / M-3）
#   - 採番: EH-13（G-6=(b)。EH-10/11 は #760/#762 予約済、EH-12 は check-git-destructive.sh）
# hook として .claude/settings.json に登録する（Human-owned）
# 配置: scripts/ ルート（HO 外）
#
# 対応 matcher:
#   Edit|Write … PLANGATE_HOOK_FILE env / $1 / stdin JSON .tool_input.file_path
#                （legacy 互換のみ top-level .file_path fallback）
#   Bash       … stdin JSON .tool_input.command 中の token path + 「書き込み意図」を検出
#                （> / cp/mv/ln/install/dd/tee/truncate/patch/apply_patch /
#                  sed -i / perl -i / python write_text・open(...,"w") /
#                  node writeFileSync / ruby File.write 等）
#                読み取り（cat / open(...).read 等）は block しない。

set -eu

# PLANGATE_SKIP_TOKEN_GUARD=1 で全スキップ（Human-owned emergency/test-only）
# 診断は出すが env の値や対象 path 等は echo しない（secret 非表示）
if [ "${PLANGATE_SKIP_TOKEN_GUARD:-0}" = "1" ]; then
  printf '[EH-13 token-guard] bypass active: PLANGATE_SKIP_TOKEN_GUARD (Human-owned emergency/test-only)\n' >&2
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
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])(cp|mv|ln|install|dd|tee|truncate|patch|apply_patch)([[:space:]]|$)' && return 0
  # sed -i / perl -i（in-place 書き込み。perl -pi / -0pi 等も -[A-Za-z]*i で捕捉）
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])(sed|perl)([[:space:]]+-[A-Za-z]*i|[[:space:]]+--in-place)' && return 0
  # python / ruby の書き込み: write_text / write_bytes / .write( （ruby File.write( を含む）
  printf '%s' "$_wc" | grep -qE 'write_text|write_bytes|\.write\(' && return 0
  # node の書き込み: fs.writeFileSync / writeFile( / appendFile
  printf '%s' "$_wc" | grep -qE 'writeFileSync|writeFile\(|appendFile' && return 0
  printf '%s' "$_wc" | grep -qE "open\([^)]*,[^)]*['\"][^'\"]*[wax+]" && return 0
  return 1
}

_block() {
  printf '[EH-13 token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。\n' >&2
  printf '  検出: %s\n' "$1" >&2
  printf '  正規操作: bin/plangate approve <TASK>（Human TTY / TASK-0128）または bin/plangate maintenance start\n' >&2
  exit 2 # t1023-block-exit
}

_parse_unknown() {
  printf '[EH-13 token-guard] BLOCK (parse-unknown): %s\n' "$1" >&2
  printf '  fail-closed 方針（TASK-1023 G-7）: PreToolUse JSON を stdin へ供給してください。\n' >&2
  printf '  診断/手実行時の escape hatch は PLANGATE_SKIP_TOKEN_GUARD=1（Human-owned）。\n' >&2
  exit 2 # t1023-parse-unknown-exit
}

# --- 1) target: env 優先、無ければ $1 fallback ---
# 注意: 現行 settings（.claude/settings.example.json）は引数なしで呼び出すため
# $1 経路は実行時 dead code（契約 docs/ai/settings-wiring-contract.md との drift は #928）。
TARGET="${PLANGATE_HOOK_FILE:-${1:-}}"
if [ -n "$TARGET" ] && _is_token_path "$TARGET"; then
  _block "target=$TARGET"
fi

# --- 2) stdin: env target の有無に関係なく常時・独立に評価（TASK-1023 defect #2 封鎖）---
if true; then # t1023-stdin-always
  # TTY は read せず即 fail-closed（read すると hook が TTY でハングする / R-027）
  if [ -t 0 ]; then _parse_unknown "stdin is a TTY (no hook payload)"; fi # t1023-tty-check
  if ! _stdin=$(cat); then _parse_unknown "stdin read failure"; fi
  if [ -z "$_stdin" ]; then _parse_unknown "empty stdin"; fi
  command -v jq >/dev/null 2>&1 || _parse_unknown "jq not available"

  # 3 値判定: protected-write / parsed-safe / parse-unknown。
  # parsed-safe の条件: hook_event_name=PreToolUse、tool_name が固定 4 種（G-8=(a)）、
  # tool_input が object、Edit/Write/MultiEdit は非空 string の file_path
  # （tool_input.file_path、legacy 互換のみ top-level .file_path）、Bash は string command。
  # 欠落・null・配列・数値・未知 tool は parse-unknown（R-026）。
  _kind=$(printf '%s' "$_stdin" | jq -r '
    if .hook_event_name != "PreToolUse" then "unknown"
    elif (.tool_input|type) != "object" then "unknown"
    elif .tool_name == "Bash" then
      (if (.tool_input.command|type) == "string" then "cmd" else "unknown" end)
    elif (.tool_name=="Edit" or .tool_name=="Write" or .tool_name=="MultiEdit") then
      (if ((.tool_input.file_path|type)=="string" and .tool_input.file_path != "")
          or ((.file_path|type)=="string" and .file_path != "") then "file" else "unknown" end)
    else "unknown" end
  ' 2>/dev/null) || _kind=""
  case "$_kind" in
    file|cmd) : ;;
    *) _parse_unknown "malformed or unsupported PreToolUse payload" ;;
  esac

  if [ "$_kind" = "file" ]; then
    if true; then # t1023-file-lane
      # MultiEdit も file_path のみで判定（edits[] やファイル内容は判定に使わない / M-3。
      # token path 文字列を本文に含む通常ファイルの編集を誤 block しないため）
      _fp=$(printf '%s' "$_stdin" | jq -r '.tool_input.file_path | if type=="string" and . != "" then . else empty end' 2>/dev/null) || _fp=""
      if [ -z "$_fp" ]; then
        _fp=$(printf '%s' "$_stdin" | jq -r '.file_path | if type=="string" and . != "" then . else empty end' 2>/dev/null) || _fp="" # t1023-legacy-fallback
      fi
      if [ -z "$_fp" ]; then _parse_unknown "no usable file_path in payload"; fi
      if _is_token_path "$_fp"; then
        _block "file_path=$_fp"
      fi
    fi
  else
    _cmd=$(printf '%s' "$_stdin" | jq -r '.tool_input.command' 2>/dev/null) || _cmd=""
    if [ -z "$_cmd" ]; then _parse_unknown "empty command"; fi
    # token path と別 write が同一 command に混在する場合も相関解析せず安全側 block
    if _is_token_path "$_cmd" && _has_write_intent "$_cmd"; then
      _block "Bash command writes token path: $_cmd"
    fi
  fi
fi

exit 0
