#!/bin/sh
# tests/hooks/run-tests.sh — Hook unit tests
# Issue #157 / TASK-0048

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
HOOKS_DIR="$REPO_ROOT/scripts/hooks"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures/hooks"

pass=0
fail=0

note() { printf '\n=== %s ===\n' "$1"; }

assert_contains() {
  label=$1
  needle=$2
  haystack=$3
  case "$haystack" in
    *"$needle"*)
      printf '[PASS] %s\n' "$label"
      pass=$((pass + 1))
      ;;
    *)
      printf '[FAIL] %s — expected to contain %s, got: %s\n' "$label" "$needle" "$haystack"
      fail=$((fail + 1))
      ;;
  esac
}

# ---- prepare real docs/working/TASK-* dirs (hooks resolve paths relative to repo root) ----
TASK_HAS_C3_NAME="TASK-HOOKTEST01"
TASK_NO_C3_NAME="TASK-HOOKTEST02"
LOOP_OK_NAME="TASK-HOOKTEST03"
LOOP_OVER_NAME="TASK-HOOKTEST04"

cleanup_dirs() {
  for n in "$TASK_HAS_C3_NAME" "$TASK_NO_C3_NAME" "$LOOP_OK_NAME" "$LOOP_OVER_NAME"; do
    rm -rf "$REPO_ROOT/docs/working/$n"
  done
}
trap cleanup_dirs EXIT INT TERM

cleanup_dirs  # idempotent in case a previous run left artifacts

mkdir -p "$REPO_ROOT/docs/working/$TASK_HAS_C3_NAME/approvals"
mkdir -p "$REPO_ROOT/docs/working/$TASK_NO_C3_NAME"
mkdir -p "$REPO_ROOT/docs/working/$LOOP_OK_NAME"
mkdir -p "$REPO_ROOT/docs/working/$LOOP_OVER_NAME"
cp "$FIXTURES_DIR/has-c3/approvals/c3.json" "$REPO_ROOT/docs/working/$TASK_HAS_C3_NAME/approvals/c3.json"

# ---- check-c3-approval.sh ----
note "check-c3-approval.sh"

# bypass mode (no task) — should allow
out=$(PLANGATE_BYPASS_HOOK=1 sh "$HOOKS_DIR/check-c3-approval.sh" 2>&1 || true)
assert_contains "bypass mode → continue:true" '"continue":true' "$out"

# default mode, task has c3 APPROVED → allow
out=$(PLANGATE_HOOK_TASK=$TASK_HAS_C3_NAME sh "$HOOKS_DIR/check-c3-approval.sh" 2>&1 || true)
assert_contains "approved task → continue:true" '"continue":true' "$out"

# default mode, no c3 → warning, but continue:true (default not strict)
out=$(PLANGATE_HOOK_TASK=$TASK_NO_C3_NAME sh "$HOOKS_DIR/check-c3-approval.sh" 2>&1 || true)
assert_contains "no c3 default → continue:true (warn only)" '"continue":true' "$out"
assert_contains "no c3 default → emits warning" 'WARNING' "$out"

# strict mode, no c3 → block
out=$(PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=$TASK_NO_C3_NAME sh "$HOOKS_DIR/check-c3-approval.sh" 2>&1 || true)
assert_contains "strict + no c3 → continue:false" '"continue":false' "$out"

# ---- check-handoff-elements.sh ----
note "check-handoff-elements.sh"

# 6 sections present → PASS
out=$(sh "$HOOKS_DIR/check-handoff-elements.sh" "$FIXTURES_DIR/handoff-complete/handoff.md" 2>&1 || true)
assert_contains "complete handoff → PASS" 'PASS' "$out"

# only 3 sections → warning (default), exit 0
if sh "$HOOKS_DIR/check-handoff-elements.sh" "$FIXTURES_DIR/handoff-incomplete/handoff.md" >/dev/null 2>&1; then
  printf '[PASS] incomplete handoff default → exit 0 (warn only)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] incomplete handoff default — should exit 0\n'
  fail=$((fail + 1))
fi

# strict + incomplete → exit 1
if PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-handoff-elements.sh" "$FIXTURES_DIR/handoff-incomplete/handoff.md" >/dev/null 2>&1; then
  printf '[FAIL] incomplete handoff strict — should exit 1\n'
  fail=$((fail + 1))
else
  printf '[PASS] incomplete handoff strict → exit 1\n'
  pass=$((pass + 1))
fi

# ---- check-fix-loop.sh ----
note "check-fix-loop.sh"

printf '3\n' >"$REPO_ROOT/docs/working/$LOOP_OK_NAME/.fix-loop-count"
printf '6\n' >"$REPO_ROOT/docs/working/$LOOP_OVER_NAME/.fix-loop-count"

# count under max → PASS
out=$(sh "$HOOKS_DIR/check-fix-loop.sh" "$LOOP_OK_NAME" 2>&1 || true)
assert_contains "fix loop 3/5 → PASS" 'PASS' "$out"

# count over max, default → warning, exit 0
if sh "$HOOKS_DIR/check-fix-loop.sh" "$LOOP_OVER_NAME" >/dev/null 2>&1; then
  printf '[PASS] fix loop 6 default → exit 0 (warn only)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] fix loop 6 default — should exit 0\n'
  fail=$((fail + 1))
fi

# strict + over max → exit 1
if PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-fix-loop.sh" "$LOOP_OVER_NAME" >/dev/null 2>&1; then
  printf '[FAIL] fix loop 6 strict — should exit 1\n'
  fail=$((fail + 1))
else
  printf '[PASS] fix loop 6 strict → exit 1\n'
  pass=$((pass + 1))
fi

# increment action
out=$(sh "$HOOKS_DIR/check-fix-loop.sh" "$LOOP_OK_NAME" increment 2>&1 || true)
new_count=$(cat "$REPO_ROOT/docs/working/$LOOP_OK_NAME/.fix-loop-count")
if [ "$new_count" = "4" ]; then
  printf '[PASS] increment: 3 → 4\n'
  pass=$((pass + 1))
else
  printf '[FAIL] increment: expected 4, got %s\n' "$new_count"
  fail=$((fail + 1))
fi

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -gt 0 ] && exit 1 || exit 0
