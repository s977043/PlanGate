#!/bin/sh
# check-c3-approval.sh — Hook EH-2 / EHS-1: plan 未承認 production code 編集 block
#
# Claude Code PreToolUse hook（Edit / Write / Bash の前に呼ばれる想定）。
# stdin に hook event JSON を受け取り、stdout に judgment を返す。
#
# Modes:
#   default                       warning のみ、continue:true
#   PLANGATE_HOOK_STRICT=1        違反時 continue:false（block）
#   PLANGATE_BYPASS_HOOK=1        常時 continue:true（緊急 escape）
#
# 違反条件（簡易版）:
#   1. 編集対象パスから TASK-XXXX を導出（docs/working/TASK-XXXX/ 配下なら自身、
#      production code は環境変数 PLANGATE_HOOK_TASK で明示）
#   2. approvals/c3.json が存在しない、または c3_status != APPROVED → 違反
#
# 監査ログ: docs/working/_audit/hook-events.log（append-only）
#
# Issue #157 / TASK-0048

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

emit_judgment() {
  decision=$1
  reason=${2:-}
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
  printf '%s\t%s\tcheck-c3-approval\t%s\t%s\n' "$ts" "$level" "${PLANGATE_HOOK_TASK:--}" "$msg" >>"$AUDIT_LOG"
}

# --- bypass ---
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  emit_judgment "allow"
  exit 0
fi

# --- TASK ID resolution ---
task_id=${PLANGATE_HOOK_TASK:-}
if [ -z "$task_id" ]; then
  # 引数 1 番目があればそれを使う（テスト用）
  task_id=${1:-}
fi

# stdin fallback: env/arg なし時に tool_input.file_path から TASK-ID を抽出
if [ -z "$task_id" ] && [ ! -t 0 ]; then
  _eh2_stdin=$(cat 2>/dev/null || true)
  if [ -n "$_eh2_stdin" ]; then
    _eh2_fp=""
    if command -v jq >/dev/null 2>&1; then
      _eh2_fp=$(printf '%s' "$_eh2_stdin" \
        | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \
        | head -1 || true)
    fi
    if [ -z "$_eh2_fp" ] && command -v python3 >/dev/null 2>&1; then
      _eh2_fp=$(printf '%s' "$_eh2_stdin" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict):
        print(d.get("tool_input", {}).get("file_path") or d.get("file_path") or "")
except Exception:
    pass
' 2>/dev/null || true)
    fi
    if [ -z "$_eh2_fp" ]; then
      _eh2_fp=$(printf '%s' "$_eh2_stdin" \
        | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 \
        | sed 's/.*"\([^"]*\)"$/\1/')
    fi
    if [ -n "$_eh2_fp" ]; then
      task_id=$(printf '%s' "$_eh2_fp" \
        | grep -o 'TASK-[0-9][0-9][0-9][0-9]' \
        | head -1 || true)
    fi
  fi
fi

if [ -z "$task_id" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_TASK / arg / stdin, skipping"
  emit_judgment "allow"
  exit 0
fi

case "$task_id" in
  TASK-*) ;;
  *)
    log_event "SKIP" "invalid task_id: $task_id"
    emit_judgment "allow"
    exit 0
    ;;
esac

# --- check c3.json ---
c3_file="$WORKING_DIR/$task_id/approvals/c3.json"

if [ ! -f "$c3_file" ]; then
  reason="C-3 gate not cleared: $c3_file not found (Hook EH-2)"
  log_event "VIOLATION" "$reason"
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    emit_judgment "block" "$reason"
    exit 0
  fi
  printf '[Hook EH-2 WARNING] %s\n' "$reason" >&2
  printf 'Set PLANGATE_HOOK_STRICT=1 to enforce, or PLANGATE_BYPASS_HOOK=1 to silence.\n' >&2
  emit_judgment "allow"
  exit 0
fi

c3_status=$(python3 - "$c3_file" <<'PYC3' 2>/dev/null || true
import sys, json
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):
        print(data.get("c3_status", ""))
except Exception:
    pass
PYC3
)

if [ "$c3_status" != "APPROVED" ]; then
  reason="C-3 status is '$c3_status', not APPROVED (Hook EH-2)"
  log_event "VIOLATION" "$reason"
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    emit_judgment "block" "$reason"
    exit 0
  fi
  printf '[Hook EH-2 WARNING] %s\n' "$reason" >&2
  emit_judgment "allow"
  exit 0
fi

log_event "PASS" "c3 APPROVED"
emit_judgment "allow"
exit 0
