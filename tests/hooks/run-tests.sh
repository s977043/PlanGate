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
PLAN_OK_NAME="TASK-HOOKTEST05"     # plan.md あり（EH-1）
PLAN_NONE_NAME="TASK-HOOKTEST06"    # plan.md なし（EH-1）
HASH_OK_NAME="TASK-HOOKTEST07"      # plan.md sha256 が c3.plan_hash と一致（EH-3）
HASH_TAMPERED_NAME="TASK-HOOKTEST08" # plan.md が改変、c3.plan_hash と不一致（EH-3）

cleanup_dirs() {
  for n in "$TASK_HAS_C3_NAME" "$TASK_NO_C3_NAME" "$LOOP_OK_NAME" "$LOOP_OVER_NAME" \
           "$PLAN_OK_NAME" "$PLAN_NONE_NAME" "$HASH_OK_NAME" "$HASH_TAMPERED_NAME"; do
    rm -rf "$REPO_ROOT/docs/working/$n"
  done
}
trap cleanup_dirs EXIT INT TERM

cleanup_dirs  # idempotent in case a previous run left artifacts

mkdir -p "$REPO_ROOT/docs/working/$TASK_HAS_C3_NAME/approvals"
mkdir -p "$REPO_ROOT/docs/working/$TASK_NO_C3_NAME"
mkdir -p "$REPO_ROOT/docs/working/$LOOP_OK_NAME"
mkdir -p "$REPO_ROOT/docs/working/$LOOP_OVER_NAME"
mkdir -p "$REPO_ROOT/docs/working/$PLAN_OK_NAME"
mkdir -p "$REPO_ROOT/docs/working/$PLAN_NONE_NAME"
mkdir -p "$REPO_ROOT/docs/working/$HASH_OK_NAME/approvals"
mkdir -p "$REPO_ROOT/docs/working/$HASH_TAMPERED_NAME/approvals"
cp "$FIXTURES_DIR/has-c3/approvals/c3.json" "$REPO_ROOT/docs/working/$TASK_HAS_C3_NAME/approvals/c3.json"

# EH-1 fixture: plan.md exists (PLAN_OK), plan.md absent (PLAN_NONE)
printf '# Sample plan\n' >"$REPO_ROOT/docs/working/$PLAN_OK_NAME/plan.md"
# PLAN_NONE has no plan.md

# EH-3 fixture: build a plan.md, compute its sha256, and write a c3.json with matching plan_hash
echo "# fixture plan for EH-3" >"$REPO_ROOT/docs/working/$HASH_OK_NAME/plan.md"
if command -v sha256sum >/dev/null 2>&1; then
  HASH_OK_SHA=$(sha256sum "$REPO_ROOT/docs/working/$HASH_OK_NAME/plan.md" | awk '{print $1}')
else
  HASH_OK_SHA=$(shasum -a 256 "$REPO_ROOT/docs/working/$HASH_OK_NAME/plan.md" | awk '{print $1}')
fi
cat >"$REPO_ROOT/docs/working/$HASH_OK_NAME/approvals/c3.json" <<EOF_C3OK
{
  "task_id": "TASK-9999",
  "phase": "C-3",
  "c3_status": "APPROVED",
  "approved_by": "fixture",
  "approved_at": "2026-05-01T00:00:00Z",
  "plan_hash": "sha256:$HASH_OK_SHA"
}
EOF_C3OK

# Tampered fixture: plan.md changes after c3.json was recorded (recorded hash points to OLD content)
echo "# fixture plan ORIGINAL" >"$REPO_ROOT/docs/working/$HASH_TAMPERED_NAME/plan.md"
if command -v sha256sum >/dev/null 2>&1; then
  HASH_OLD_SHA=$(sha256sum "$REPO_ROOT/docs/working/$HASH_TAMPERED_NAME/plan.md" | awk '{print $1}')
else
  HASH_OLD_SHA=$(shasum -a 256 "$REPO_ROOT/docs/working/$HASH_TAMPERED_NAME/plan.md" | awk '{print $1}')
fi
cat >"$REPO_ROOT/docs/working/$HASH_TAMPERED_NAME/approvals/c3.json" <<EOF_C3TAMP
{
  "task_id": "TASK-9998",
  "phase": "C-3",
  "c3_status": "APPROVED",
  "approved_by": "fixture",
  "approved_at": "2026-05-01T00:00:00Z",
  "plan_hash": "sha256:$HASH_OLD_SHA"
}
EOF_C3TAMP
# Now tamper the plan.md so its sha256 no longer matches plan_hash
echo "# fixture plan TAMPERED" >"$REPO_ROOT/docs/working/$HASH_TAMPERED_NAME/plan.md"

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

# ---- check-plan-exists.sh (EH-1) ----
note "check-plan-exists.sh (EH-1)"

# plan.md exists → PASS
out=$(PLANGATE_HOOK_TASK=$PLAN_OK_NAME sh "$HOOKS_DIR/check-plan-exists.sh" 2>&1 || true)
assert_contains "EH-1: plan exists → continue:true" '"continue":true' "$out"

# plan.md absent, default → warning + continue:true
out=$(PLANGATE_HOOK_TASK=$PLAN_NONE_NAME sh "$HOOKS_DIR/check-plan-exists.sh" 2>&1 || true)
assert_contains "EH-1: no plan default → continue:true" '"continue":true' "$out"
assert_contains "EH-1: no plan default → emits WARNING" 'WARNING' "$out"

# plan.md absent, strict → block
out=$(PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=$PLAN_NONE_NAME sh "$HOOKS_DIR/check-plan-exists.sh" 2>&1 || true)
assert_contains "EH-1: strict + no plan → continue:false" '"continue":false' "$out"

# bypass with no plan → continue:true
out=$(PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=$PLAN_NONE_NAME sh "$HOOKS_DIR/check-plan-exists.sh" 2>&1 || true)
assert_contains "EH-1: bypass overrides strict" '"continue":true' "$out"

# ---- check-plan-hash.sh (EH-3) ----
note "check-plan-hash.sh (EH-3)"

# matching hash → PASS
out=$(sh "$HOOKS_DIR/check-plan-hash.sh" "$HASH_OK_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "matches"; then
  printf '[PASS] EH-3: matching plan_hash → exit 0 + matches\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-3: matching plan_hash (rc=%d, out=%s)\n' "$rc" "$out"
  fail=$((fail + 1))
fi

# mismatched hash, default → warning + exit 0
out=$(sh "$HOOKS_DIR/check-plan-hash.sh" "$HASH_TAMPERED_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "WARNING"; then
  printf '[PASS] EH-3: mismatch default → exit 0 + WARNING\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-3: mismatch default (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# mismatched hash, strict → exit 1
PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-plan-hash.sh" "$HASH_TAMPERED_NAME" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ]; then
  printf '[PASS] EH-3: mismatch strict → exit 1\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-3: mismatch strict (rc=%d, expected 1)\n' "$rc"
  fail=$((fail + 1))
fi

# bypass overrides strict
out=$(PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-plan-hash.sh" "$HASH_TAMPERED_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "BYPASS"; then
  printf '[PASS] EH-3: bypass overrides strict\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-3: bypass behavior (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# ---- Setup fixtures for EH-4 / EH-5 / EH-6 (Issue #169 Session B) ----
TC_OK_NAME="TASK-HOOKTEST09"
TC_NONE_NAME="TASK-HOOKTEST10"
EV_OK_NAME="TASK-HOOKTEST11"
EV_NONE_NAME="TASK-HOOKTEST12"
FF_TASK="TASK-HOOKTEST-FF"
PARENT_PBI="PBI-9999"

cleanup_extra() {
  for n in "$TC_OK_NAME" "$TC_NONE_NAME" "$EV_OK_NAME" "$EV_NONE_NAME" "$FF_TASK"; do
    rm -rf "$REPO_ROOT/docs/working/$n"
  done
  rm -rf "$REPO_ROOT/docs/working/$PARENT_PBI"
}
cleanup_extra

mkdir -p "$REPO_ROOT/docs/working/$TC_OK_NAME" "$REPO_ROOT/docs/working/$TC_NONE_NAME"
cp "$FIXTURES_DIR/test-cases-exists/test-cases.md" "$REPO_ROOT/docs/working/$TC_OK_NAME/test-cases.md"
mkdir -p "$REPO_ROOT/docs/working/$EV_OK_NAME/evidence"
mkdir -p "$REPO_ROOT/docs/working/$EV_NONE_NAME/evidence"  # exists but empty
cp "$FIXTURES_DIR/evidence-ok/evidence/verification.md" "$REPO_ROOT/docs/working/$EV_OK_NAME/evidence/verification.md"

# EH-6: 子 PBI YAML 設置（fixture）
mkdir -p "$REPO_ROOT/docs/working/$PARENT_PBI/children"
cp "$FIXTURES_DIR/forbidden-parent/PBI-9999/children/PBI-9999-01.yaml" "$REPO_ROOT/docs/working/$PARENT_PBI/children/PBI-9999-01.yaml"

# 既存の trap に extras cleanup を追加
trap "cleanup_dirs; cleanup_extra" EXIT INT TERM

# ---- check-test-cases.sh (EH-4) ----
note "check-test-cases.sh (EH-4)"

out=$(sh "$HOOKS_DIR/check-test-cases.sh" "$TC_OK_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q PASS; then
  printf '[PASS] EH-4: test-cases.md present → exit 0 + PASS\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-4: present (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

out=$(sh "$HOOKS_DIR/check-test-cases.sh" "$TC_NONE_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q WARNING; then
  printf '[PASS] EH-4: missing default → exit 0 + WARNING\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-4: missing default (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-test-cases.sh" "$TC_NONE_NAME" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ]; then
  printf '[PASS] EH-4: missing strict → exit 1\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-4: missing strict (rc=%d, expected 1)\n' "$rc"
  fail=$((fail + 1))
fi

# ---- check-verification-evidence.sh (EH-5) ----
note "check-verification-evidence.sh (EH-5)"

out=$(sh "$HOOKS_DIR/check-verification-evidence.sh" "$EV_OK_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q PASS; then
  printf '[PASS] EH-5: verification present → PASS\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-5: present (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

out=$(sh "$HOOKS_DIR/check-verification-evidence.sh" "$EV_NONE_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q WARNING; then
  printf '[PASS] EH-5: empty evidence default → exit 0 + WARNING\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-5: empty default (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-verification-evidence.sh" "$EV_NONE_NAME" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ]; then
  printf '[PASS] EH-5: empty strict → exit 1\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-5: empty strict (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# ---- check-forbidden-files.sh (EH-6) ----
note "check-forbidden-files.sh (EH-6)"

# allowed file 編集 → continue:true
out=$(PLANGATE_HOOK_TASK=$FF_TASK PLANGATE_HOOK_FILE=src/foo/bar.ts sh "$HOOKS_DIR/check-forbidden-files.sh" 2>&1 || true)
assert_contains "EH-6: allowed file → continue:true" '"continue":true' "$out"

# forbidden file 編集 default → continue:true + WARNING
out=$(PLANGATE_HOOK_TASK=$FF_TASK PLANGATE_HOOK_FILE=src/auth/login.ts sh "$HOOKS_DIR/check-forbidden-files.sh" 2>&1 || true)
assert_contains "EH-6: forbidden default → continue:true (warn)" '"continue":true' "$out"
assert_contains "EH-6: forbidden default → emits WARNING" 'WARNING' "$out"

# forbidden file 編集 strict → continue:false
out=$(PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=$FF_TASK PLANGATE_HOOK_FILE=src/auth/login.ts sh "$HOOKS_DIR/check-forbidden-files.sh" 2>&1 || true)
assert_contains "EH-6: forbidden strict → continue:false" '"continue":false' "$out"

# bypass overrides strict
out=$(PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=$FF_TASK PLANGATE_HOOK_FILE=src/auth/login.ts sh "$HOOKS_DIR/check-forbidden-files.sh" 2>&1 || true)
assert_contains "EH-6: bypass overrides strict" '"continue":true' "$out"

# task_id なし → SKIP（false-positive guard、continue:true）
out=$(PLANGATE_HOOK_FILE=src/auth/login.ts sh "$HOOKS_DIR/check-forbidden-files.sh" 2>&1 || true)
assert_contains "EH-6: no task → SKIP / continue:true" '"continue":true' "$out"

# ---- Setup fixtures for EH-7 / EHS-1 (Issue #169 Session C) ----
BOTH_APPR_NAME="TASK-HOOKTEST13"   # c3 + c4 両方 APPROVED
C3_ONLY_NAME="TASK-HOOKTEST14"     # c3 のみ APPROVED, c4 不在
NO_APPR_NAME="TASK-HOOKTEST15"     # 両方なし
V3_EXISTS_NAME="TASK-HOOKTEST16"   # review-external.md あり
V3_NONE_NAME="TASK-HOOKTEST17"     # review-external.md なし

cleanup_session_c() {
  for n in "$BOTH_APPR_NAME" "$C3_ONLY_NAME" "$NO_APPR_NAME" "$V3_EXISTS_NAME" "$V3_NONE_NAME"; do
    rm -rf "$REPO_ROOT/docs/working/$n"
  done
}
cleanup_session_c

mkdir -p "$REPO_ROOT/docs/working/$BOTH_APPR_NAME/approvals"
cp "$FIXTURES_DIR/both-approvals/c3.json" "$REPO_ROOT/docs/working/$BOTH_APPR_NAME/approvals/c3.json"
cp "$FIXTURES_DIR/both-approvals/c4-approval.json" "$REPO_ROOT/docs/working/$BOTH_APPR_NAME/approvals/c4-approval.json"

mkdir -p "$REPO_ROOT/docs/working/$C3_ONLY_NAME/approvals"
cp "$FIXTURES_DIR/both-approvals/c3.json" "$REPO_ROOT/docs/working/$C3_ONLY_NAME/approvals/c3.json"
# c4 不在

mkdir -p "$REPO_ROOT/docs/working/$NO_APPR_NAME/approvals"  # 空ディレクトリ

mkdir -p "$REPO_ROOT/docs/working/$V3_EXISTS_NAME"
cp "$FIXTURES_DIR/v3-review-exists/review-external.md" "$REPO_ROOT/docs/working/$V3_EXISTS_NAME/review-external.md"

mkdir -p "$REPO_ROOT/docs/working/$V3_NONE_NAME"  # review-external.md なし

# 既存 trap に session C cleanup を追加
trap "cleanup_dirs; cleanup_extra; cleanup_session_c" EXIT INT TERM

# ---- check-merge-approvals.sh (EH-7) ----
note "check-merge-approvals.sh (EH-7)"

out=$(sh "$HOOKS_DIR/check-merge-approvals.sh" "$BOTH_APPR_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "PASS"; then
  printf '[PASS] EH-7: both APPROVED → exit 0 + PASS\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-7: both APPROVED (rc=%d, out=%s)\n' "$rc" "$out"
  fail=$((fail + 1))
fi

out=$(sh "$HOOKS_DIR/check-merge-approvals.sh" "$C3_ONLY_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q WARNING; then
  printf '[PASS] EH-7: c4 missing default → exit 0 + WARNING\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-7: c4 missing default (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-merge-approvals.sh" "$NO_APPR_NAME" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ]; then
  printf '[PASS] EH-7: no approvals strict → exit 1\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-7: no approvals strict (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

out=$(PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-merge-approvals.sh" "$NO_APPR_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q BYPASS; then
  printf '[PASS] EH-7: bypass overrides strict\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-7: bypass behavior (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# ---- check-v3-review.sh (EHS-1) ----
note "check-v3-review.sh (EHS-1)"

# review-external.md あり、mode=standard → PASS
out=$(PLANGATE_HOOK_MODE=standard sh "$HOOKS_DIR/check-v3-review.sh" "$V3_EXISTS_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q PASS; then
  printf '[PASS] EHS-1: review-external present (standard) → PASS\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EHS-1: review-external present (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# review-external.md なし、mode=standard default → exit 0 + WARNING
out=$(PLANGATE_HOOK_MODE=standard sh "$HOOKS_DIR/check-v3-review.sh" "$V3_NONE_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q WARNING; then
  printf '[PASS] EHS-1: missing standard default → exit 0 + WARNING\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EHS-1: missing default (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# review-external.md なし、mode=high-risk strict → exit 1
PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_MODE=high-risk sh "$HOOKS_DIR/check-v3-review.sh" "$V3_NONE_NAME" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ]; then
  printf '[PASS] EHS-1: missing strict (high-risk) → exit 1\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EHS-1: missing strict (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# review-external.md なし、mode=light → SKIP（必須化されない）
out=$(PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_MODE=light sh "$HOOKS_DIR/check-v3-review.sh" "$V3_NONE_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q SKIP; then
  printf '[PASS] EHS-1: light mode → SKIP regardless of strict\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EHS-1: light mode skip (rc=%d, out=%s)\n' "$rc" "$out"
  fail=$((fail + 1))
fi

# bypass overrides strict
out=$(PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_MODE=critical sh "$HOOKS_DIR/check-v3-review.sh" "$V3_NONE_NAME" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q BYPASS; then
  printf '[PASS] EHS-1: bypass overrides strict (critical mode)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EHS-1: bypass behavior (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# ---- check-metrics-privacy.sh (EH-8) ----
note "check-metrics-privacy.sh (EH-8)"

PRIVACY_FIXTURE_GOOD="$FIXTURES_DIR/check-metrics-privacy/good/sample.json"
PRIVACY_FIXTURE_BAD_FORBIDDEN="$FIXTURES_DIR/check-metrics-privacy/bad-forbidden/sample.json"
PRIVACY_EVENTS_PATH="docs/working/_metrics/events.ndjson"

# good fixture (Allowed fields only) → PASS
out=$(PLANGATE_HOOK_FILES="$PRIVACY_FIXTURE_GOOD" sh "$HOOKS_DIR/check-metrics-privacy.sh" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "PASS"; then
  printf '[PASS] EH-8: good fixture (allowed fields only) → PASS\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-8: good fixture (rc=%d, out=%s)\n' "$rc" "$out"
  fail=$((fail + 1))
fi

# bad fixture with forbidden fields → default WARNING
out=$(PLANGATE_HOOK_FILES="$PRIVACY_FIXTURE_BAD_FORBIDDEN" sh "$HOOKS_DIR/check-metrics-privacy.sh" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "WARNING"; then
  printf '[PASS] EH-8: bad fixture default → exit 0 + WARNING\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-8: bad default (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# bad fixture, strict → BLOCK exit 1
PLANGATE_HOOK_FILES="$PRIVACY_FIXTURE_BAD_FORBIDDEN" PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-metrics-privacy.sh" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ]; then
  printf '[PASS] EH-8: bad fixture strict → exit 1 (BLOCK)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-8: bad strict (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# events.ndjson 単一引数 → BLOCK (events is forbidden in staging)
PLANGATE_HOOK_FILES="$PRIVACY_EVENTS_PATH" PLANGATE_HOOK_STRICT=1 sh "$HOOKS_DIR/check-metrics-privacy.sh" >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 1 ]; then
  printf '[PASS] EH-8: events.ndjson staged + strict → exit 1\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-8: events.ndjson strict (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# bypass overrides strict
out=$(PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="$PRIVACY_FIXTURE_BAD_FORBIDDEN" sh "$HOOKS_DIR/check-metrics-privacy.sh" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q BYPASS; then
  printf '[PASS] EH-8: bypass overrides strict\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-8: bypass (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

# no files (empty staging) → PASS
out=$(PLANGATE_HOOK_FILES="" sh "$HOOKS_DIR/check-metrics-privacy.sh" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q PASS; then
  printf '[PASS] EH-8: empty staging → PASS\n'
  pass=$((pass + 1))
else
  printf '[FAIL] EH-8: empty staging (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -gt 0 ] && exit 1 || exit 0
