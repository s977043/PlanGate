#!/bin/sh
# EH-13 probe for issue #1110. Reads command strings from a file (one per line, base64-encoded)
# to avoid the very false positive under investigation.
ROOT="${PG_ROOT:-$(git rev-parse --show-toplevel)}"
GUARD="${PG_GUARD:-$ROOT/scripts/check-approval-token-write.sh}"
CASES="$1"
i=0
while IFS= read -r b64; do
  [ -z "$b64" ] && continue
  i=$((i + 1))
  cmd=$(printf '%s' "$b64" | base64 -d)
  payload=$(CMD="$cmd" python3 -c 'import json,os; print(json.dumps({
  "hook_event_name":"PreToolUse","tool_name":"Bash",
  "tool_input":{"command":os.environ["CMD"]},"session_id":"probe"}))')
  rc=0
  out=$(printf '%s' "$payload" | env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 sh "$GUARD" 2>&1) || rc=$?
  printf '### case %s\ncmd: %s\nrc=%s\n%s\n\n' "$i" "$cmd" "$rc" "$out"
done < "$CASES"
