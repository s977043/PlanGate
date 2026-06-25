#!/bin/sh
# check-plan-exists.sh — Hook EH-1: plan.md なし production code 編集 block
#
# Claude Code PreToolUse hook（Edit / Write の前に呼ばれる想定）。
# stdin に hook event JSON を受け取り、stdout に judgment を返す。
#
# 検査:
#   PLANGATE_HOOK_TASK 環境変数で対象 TASK を明示。
#   docs/working/$TASK/plan.md が存在しなければ違反。
#   production path（PLANGATE_PROTECTED_PATHS、未設定時はデフォルトリスト）への
#   編集が試みられている場合のみブロック対象（path は環境変数 or 引数で受領）。
#
# Modes:
#   default                       warning + continue:true
#   PLANGATE_HOOK_STRICT=1        違反時 continue:false（block）
#   PLANGATE_BYPASS_HOOK=1        常時 continue:true（緊急 escape）
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0056

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

# production path のデフォルトパターン（編集を制限したい範囲）
DEFAULT_PROTECTED='^(CLAUDE\.md|AGENTS\.md|docs/ai/|\.claude/|bin/|schemas/|plugin/|scripts/(?!hooks/))'

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
  printf '%s\t%s\tcheck-plan-exists\t%s\t%s\n' "$ts" "$level" "${PLANGATE_HOOK_TASK:--}" "$msg" >>"$AUDIT_LOG"
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
  task_id=${1:-}
fi

# stdin fallback: env/arg なし時に tool_input.file_path から TASK-ID を抽出
if [ -z "$task_id" ] && [ ! -t 0 ]; then
  _eh1_stdin=$(cat 2>/dev/null || true)
  if [ -n "$_eh1_stdin" ]; then
    _eh1_fp=""
    if command -v jq >/dev/null 2>&1; then
      _eh1_fp=$(printf '%s' "$_eh1_stdin" \
        | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \
        | head -1 || true)
    fi
    if [ -z "$_eh1_fp" ] && command -v python3 >/dev/null 2>&1; then
      _eh1_fp=$(printf '%s' "$_eh1_stdin" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict):
        print(d.get("tool_input", {}).get("file_path") or d.get("file_path") or "")
except Exception:
    pass
' 2>/dev/null || true)
    fi
    if [ -z "$_eh1_fp" ]; then
      _eh1_fp=$(printf '%s' "$_eh1_stdin" \
        | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 \
        | sed 's/.*"\([^"]*\)"$/\1/')
    fi
    if [ -n "$_eh1_fp" ]; then
      task_id=$(printf '%s' "$_eh1_fp" \
        | grep -o 'TASK-[0-9][0-9][0-9][0-9]' \
        | head -1 || true)
    fi
  fi
fi

if [ -z "$task_id" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_TASK / arg / stdin, skipping (false-positive guard)"
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

# --- check plan.md ---
plan_file="$WORKING_DIR/$task_id/plan.md"

if [ ! -f "$plan_file" ]; then
  reason="plan.md not found: $plan_file (Hook EH-1)"
  log_event "VIOLATION" "$reason"
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    emit_judgment "block" "$reason"
    exit 0
  fi
  printf '[Hook EH-1 WARNING] %s\n' "$reason" >&2
  printf '  Hint: production code（CLAUDE.md / docs/ai/ / .claude/ / bin/ / schemas/ 等）を編集する前に %s/plan.md を作成してください。\n' "$task_id" >&2
  printf '  Set PLANGATE_HOOK_STRICT=1 to enforce, or PLANGATE_BYPASS_HOOK=1 to silence.\n' >&2
  emit_judgment "allow"
  exit 0
fi

log_event "PASS" "plan.md exists"
emit_judgment "allow"
exit 0
