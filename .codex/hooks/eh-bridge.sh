#!/bin/sh
# eh-bridge.sh — Codex CLI PreToolUse hook bridge to PlanGate scripts/hooks/*.sh
#
# Reads Codex stdin JSON, extracts file path(s) from tool_input (Edit/Write or
# apply_patch), runs the named PlanGate hook with PLANGATE_HOOK_FILE /
# PLANGATE_HOOK_TASK set, translates exit code / stdout JSON to Codex's
# hookSpecificOutput {permissionDecision}.
#
# Usage:
#   echo "<json>" | .codex/hooks/eh-bridge.sh <check-script-basename>
#   e.g.   .codex/hooks/eh-bridge.sh check-plan-hash.sh
#
# Reference:
# - Claude bridge precedent: scripts/hooks/cursor-adapter.sh
# - Codex hooks spec: https://developers.openai.com/codex/hooks

set -eu

HOOK_NAME=${1:-}
if [ -z "$HOOK_NAME" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"eh-bridge: hook name missing"}}\n'
  exit 0
fi

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/$HOOK_NAME"

if [ ! -f "$HOOK_SCRIPT" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"eh-bridge: PlanGate hook %s not found"}}\n' "$HOOK_NAME"
  exit 0
fi

INPUT=$(cat)

# Extract file path(s) from Codex tool_input.
#   - Edit/Write: tool_input.file_path
#   - apply_patch: tool_input.command contains "*** Update File: <path>" /
#     "*** Add File: <path>" / "*** Delete File: <path>"
FILE_PATH=$(printf '%s' "$INPUT" | python3 -c '
import json, re, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
fp = ti.get("file_path") or ti.get("path")
if fp:
    print(fp); sys.exit(0)
cmd = ti.get("command") or ""
m = re.search(r"\*\*\* (?:Update|Add|Delete) File: (.+?)(?:\n|$)", cmd)
if m:
    print(m.group(1).strip())
' 2>/dev/null || echo "")

if [ -n "$FILE_PATH" ]; then
  export PLANGATE_HOOK_FILE="$FILE_PATH"
  case "$FILE_PATH" in
    *docs/working/TASK-*/*)
      _task=$(printf '%s\n' "$FILE_PATH" | sed -n 's|.*docs/working/\(TASK-[^/]*\)/.*|\1|p')
      if [ -n "$_task" ] && [ -z "${PLANGATE_HOOK_TASK:-}" ]; then
        export PLANGATE_HOOK_TASK="$_task"
      fi
      ;;
  esac
fi

# Run PlanGate hook. Capture exit code; stderr stays visible for debugging.
set +e
sh "$HOOK_SCRIPT" >/tmp/eh-bridge-out.$$ 2>&1
rc=$?
set -e

reason=""
if [ -f /tmp/eh-bridge-out.$$ ]; then
  reason=$(tail -n 5 /tmp/eh-bridge-out.$$ | tr '\n' ' ' | tr '"' "'" | head -c 400)
  rm -f /tmp/eh-bridge-out.$$
fi

case "$rc" in
  0)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
    ;;
  2|1)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"PlanGate %s blocked: %s"}}\n' "$HOOK_NAME" "$reason"
    ;;
  *)
    # Unknown exit code: allow but flag in reason for debugging
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"PlanGate %s rc=%d (unexpected, allowing)"}}\n' "$HOOK_NAME" "$rc"
    ;;
esac
exit 0
