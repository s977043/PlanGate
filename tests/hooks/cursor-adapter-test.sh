#!/bin/sh
# cursor-adapter-test.sh — Cursor hook adapter smoke tests
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ADAPTER="$ROOT/scripts/hooks/cursor-adapter.sh"
TASK_DIR="$ROOT/docs/working/TASK-CURSOR-HOOKTEST"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -x "$ADAPTER" ] || fail "cursor-adapter.sh not executable"

# bypass → allow
OUT=$(printf '{"tool_input":{"file_path":"bin/plangate"}}' | \
  PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_TASK=TASK-CURSOR-HOOKTEST \
  sh "$ADAPTER" check-c3-approval.sh)
echo "$OUT" | grep -q '"permission":"allow"' || fail "bypass should allow"

# missing c3 + strict → deny
mkdir -p "$TASK_DIR"
rm -f "$TASK_DIR/approvals/c3.json"
OUT=$(printf '{"tool_input":{"file_path":"bin/plangate"}}' | \
  PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=TASK-CURSOR-HOOKTEST \
  sh "$ADAPTER" check-c3-approval.sh)
echo "$OUT" | grep -q '"permission":"deny"' || fail "strict without c3 should deny"

# task id inferred from path
OUT=$(printf '{"tool_input":{"file_path":"docs/working/TASK-CURSOR-HOOKTEST/pbi-input.md"}}' | \
  PLANGATE_HOOK_STRICT=1 sh "$ADAPTER" check-c3-approval.sh)
echo "$OUT" | grep -q '"permission":"deny"' || fail "should infer TASK from path"

printf 'PASS: cursor-adapter (%s)\n' "$ADAPTER"
