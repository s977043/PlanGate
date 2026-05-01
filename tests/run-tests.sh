#!/bin/sh
# PlanGate CLI test suite
# Usage: sh tests/run-tests.sh
#
# 構成:
#   - 本体（base tests）: 下記 TA-01 / TA-02 / TA-03 + plangate validate --dir
#   - 拡張テスト: tests/extras/*.sh を順次 source（Issue #170 で導入）
#     新規テストブロック追加時は tests/extras/ にファイルを置くこと。
#     詳細は tests/extras/README.md 参照。

set -eu

PLANGATE_BIN="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/bin/plangate"
FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/fixtures"
EXTRAS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/extras"

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

# ── Extras: tests/extras/*.sh を順番に source（Issue #170）─────────────────────
# 新規 TA-NN を追加するときは tests/extras/ にファイルを置くだけでよい。
# 本体（このファイル）の編集は不要 → PBI 連続実装時の衝突を回避。
if [ -d "$EXTRAS_DIR" ]; then
  for extra in "$EXTRAS_DIR"/ta-*.sh; do
    # POSIX glob: マッチ無しのときリテラル文字列が返るため存在チェック
    [ -f "$extra" ] || continue
    # shellcheck source=/dev/null
    . "$extra"
  done
fi

printf '\n'
printf 'Results: %d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
