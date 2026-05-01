#!/bin/sh
# PlanGate CLI test suite
# Usage: sh tests/run-tests.sh

set -eu

PLANGATE_BIN="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/bin/plangate"
FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/fixtures"

pass=0
fail=0

assert_pass() {
  label=$1
  shift
  if "$@" >/dev/null; then
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s — expected PASS but got FAIL\n' "$label"
    fail=$((fail + 1))
  fi
}

assert_fail() {
  label=$1
  shift
  if ! "$@" >/dev/null; then
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s — expected FAIL but got PASS\n' "$label"
    fail=$((fail + 1))
  fi
}

printf '=== plangate validate --dir ===\n'

assert_pass "complete-task: all artifacts + valid c3.json → PASS" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/complete-task"

assert_fail "missing-approval: no approvals/c3.json → FAIL" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/missing-approval"

assert_fail "stale-plan-hash: plan.md modified after approval → FAIL" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/stale-plan-hash"

assert_fail "broken-pbi: pbi-input.md missing → FAIL" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/broken-pbi"

printf '\n=== TA-01: validate --mode ===\n'

# complete-task has plan.md, todo.md, test-cases.md, review-self.md + valid c3.json
# standard.yaml c3 requires: [plan, todo, test_cases, review_self] — no pbi-input.md
assert_pass "validate --mode standard: complete-task passes" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/complete-task" --mode standard

# missing-approval has no approvals/c3.json → FAIL regardless of mode
assert_fail "validate --mode standard: missing-approval fails" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/missing-approval" --mode standard

assert_fail "validate --mode unknown-xyz: non-existent mode returns error" \
  sh "$PLANGATE_BIN" validate --dir "$FIXTURES_DIR/complete-task" --mode unknown-xyz

printf '\n=== TA-02: review command ===\n'

assert_fail "review: no args shows usage (exit 1)" \
  sh "$PLANGATE_BIN" review

# Verify that the usage text is emitted to stderr
if sh "$PLANGATE_BIN" review 2>&1 | grep -q 'Usage'; then
  printf '[PASS] review: no args emits Usage text\n'
  pass=$((pass + 1))
else
  printf '[FAIL] review: no args — Usage text not found\n'
  fail=$((fail + 1))
fi

printf '\n=== TA-03: exec command gate enforcement ===\n'

# Create a temporary task dir without approvals/c3.json to test gate enforcement
TMPDIR_TASK="$(dirname "$FIXTURES_DIR")/tmp-working"
mkdir -p "$TMPDIR_TASK"

# Temporarily point plangate_working_dir at our tmp dir by creating TASK-GATETEST
GATE_TASK_DIR="$TMPDIR_TASK/TASK-GATETEST"
mkdir -p "$GATE_TASK_DIR"
touch "$GATE_TASK_DIR/plan.md"

# exec requires PLANGATE_WORKING_DIR override — we need to run it with modified path.
# Since bin/plangate computes plangate_working_dir from its own location, we use a
# wrapper that symlinks docs/working/TASK-GATETEST to our temp dir.
REPO_WORKING="$(CDPATH= cd -- "$(dirname "$FIXTURES_DIR")/.." && pwd)/docs/working/TASK-GATETEST"
if [ ! -e "$REPO_WORKING" ]; then
  # Create a minimal task dir inside docs/working for this test
  mkdir -p "$REPO_WORKING"
  touch "$REPO_WORKING/plan.md"
  created_gate_test=1
else
  created_gate_test=0
fi

if sh "$PLANGATE_BIN" exec TASK-GATETEST 2>&1 | grep -q 'C-3 gate not cleared'; then
  printf '[PASS] exec: missing approvals/c3.json → C-3 gate not cleared\n'
  pass=$((pass + 1))
else
  printf '[FAIL] exec: expected "C-3 gate not cleared" error\n'
  fail=$((fail + 1))
fi

# Cleanup
if [ "${created_gate_test:-0}" -eq 1 ]; then
  rm -rf "$REPO_WORKING"
fi
rm -rf "$TMPDIR_TASK"

printf '\n=== TA-04: check-pr-issue-link.sh ===\n'

PR_LINK_SCRIPT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/scripts/check-pr-issue-link.sh"
PR_LINK_FIXTURES="$FIXTURES_DIR/check-pr-issue-link"

run_pr_link_fixture() {
  fixture_dir=$1
  expected=$2
  label=$3
  out=$(sh "$PR_LINK_SCRIPT" \
    --body-file "$fixture_dir/body.txt" \
    --labels-file "$fixture_dir/labels.txt" \
    --changed-files "$fixture_dir/changed-files.txt" 2>&1) || {
    printf '[FAIL] %s — script exited non-zero: %s\n' "$label" "$out"
    fail=$((fail + 1))
    return
  }
  case "$out" in
    "$expected"*)
      printf '[PASS] %s — got %s\n' "$label" "$expected"
      pass=$((pass + 1))
      ;;
    *)
      printf '[FAIL] %s — expected prefix %s, got: %s\n' "$label" "$expected" "$out"
      fail=$((fail + 1))
      ;;
  esac
}

run_pr_link_fixture "$PR_LINK_FIXTURES/pass" "PASS" "pass: closes #N present"
run_pr_link_fixture "$PR_LINK_FIXTURES/warn" "WARN" "warn: no closing keyword"
run_pr_link_fixture "$PR_LINK_FIXTURES/skip-label" "SKIP" "skip-label: documentation label"
run_pr_link_fixture "$PR_LINK_FIXTURES/skip-marker" "SKIP" "skip-marker: HTML comment marker"

printf '\n=== TA-05: validate-schemas (Issue #158) ===\n'

if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  SCHEMA_FIXTURES="$FIXTURES_DIR/schema-validate"

  if sh "$PLANGATE_BIN" validate-schemas "$SCHEMA_FIXTURES/valid/c3.json" >/dev/null 2>&1; then
    printf '[PASS] valid/c3.json passes c3-approval schema\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] valid/c3.json — expected PASS\n'
    fail=$((fail + 1))
  fi

  if ! sh "$PLANGATE_BIN" validate-schemas "$SCHEMA_FIXTURES/invalid/c3.json" >/dev/null 2>&1; then
    printf '[PASS] invalid/c3.json fails c3-approval schema (exit non-zero)\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] invalid/c3.json — expected FAIL\n'
    fail=$((fail + 1))
  fi

  if sh "$PLANGATE_BIN" validate-schemas 2>&1 | grep -q 'Usage'; then
    printf '[PASS] validate-schemas: no args emits Usage text\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] validate-schemas: usage text missing\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] validate-schemas suite — jsonschema package not installed (CI will install it)\n'
fi

printf '\n=== TA-06: hooks (Issue #157) ===\n'

HOOK_TESTS_SCRIPT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/hooks/run-tests.sh"
if [ -f "$HOOK_TESTS_SCRIPT" ]; then
  # 子テストの結果を取り込む（自前で pass/fail カウンタを進める）
  if sh "$HOOK_TESTS_SCRIPT" >/dev/null 2>&1; then
    printf '[PASS] tests/hooks/run-tests.sh — all hook unit tests\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] tests/hooks/run-tests.sh — see "sh tests/hooks/run-tests.sh" output\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] tests/hooks/run-tests.sh not found\n'
fi

printf '\n=== TA-07: eval-runner (Issue #156) ===\n'

if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  EVAL_FIXTURE="$FIXTURES_DIR/eval-runner/sample-task"
  EVAL_TASK_NAME="TASK-9990"
  EVAL_TASK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/docs/working/$EVAL_TASK_NAME"

  cleanup_eval() { rm -rf "$EVAL_TASK_DIR"; }
  trap cleanup_eval EXIT INT TERM

  cleanup_eval
  mkdir -p "$EVAL_TASK_DIR/approvals"
  cp "$EVAL_FIXTURE/handoff.md" "$EVAL_TASK_DIR/handoff.md"
  cp "$EVAL_FIXTURE/approvals/c3.json" "$EVAL_TASK_DIR/approvals/c3.json"

  if sh "$PLANGATE_BIN" eval "$EVAL_TASK_NAME" --no-write >/dev/null 2>&1; then
    printf '[PASS] eval: sample task → exit 0 (no blockers)\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] eval: sample task — expected exit 0\n'
    fail=$((fail + 1))
  fi

  out=$(sh "$PLANGATE_BIN" eval "$EVAL_TASK_NAME" --no-write 2>&1 || true)
  case "$out" in
    *"AC coverage"*)
      printf '[PASS] eval: stdout contains AC coverage line\n'
      pass=$((pass + 1))
      ;;
    *)
      printf '[FAIL] eval: stdout missing AC coverage line\n'
      fail=$((fail + 1))
      ;;
  esac

  if sh "$PLANGATE_BIN" eval 2>&1 | grep -q 'Usage'; then
    printf '[PASS] eval: no args emits Usage text\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] eval: usage text missing\n'
    fail=$((fail + 1))
  fi

  cleanup_eval
  trap - EXIT INT TERM
else
  printf '[SKIP] eval-runner suite — jsonschema not installed\n'
fi

printf '\n'
printf 'Results: %d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
