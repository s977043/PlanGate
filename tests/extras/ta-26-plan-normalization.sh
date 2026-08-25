# tests/extras/ta-26-plan-normalization.sh
# Sourced by tests/run-tests.sh — relies on $pass / $fail / $FIXTURES_DIR
# Issue #1220: Canonical Plan normalization の機械契約を固定する。

printf '\n=== TA-26: Plan Normalization Gate contract ===\n'

PN_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PN_CHECKER="$PN_ROOT/scripts/check-plan-normalization.py"
PN_TMP="$(mktemp -d)"
trap 'rm -rf "$PN_TMP"' EXIT INT TERM

pn_write_before() {
  cat > "$PN_TMP/before.md" <<'EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす。

## Scope

- In: canonicalize plan
- Out: runtime implementation

## Global Constraints

- REQ-1 を維持する。

## Work Breakdown

- AC-1: normalize current state
- AC-2: preserve verification

## Verification Plan

- REQ-1 を検証する。
EOF
}

pn_assert_pass() {
  label=$1
  if python3 "$PN_CHECKER" --before "$PN_TMP/before.md" --after "$PN_TMP/after.md" >/dev/null 2>&1; then
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s — checker should pass\n' "$label"
    fail=$((fail + 1))
  fi
}

pn_assert_fail() {
  label=$1
  if python3 "$PN_CHECKER" --before "$PN_TMP/before.md" --after "$PN_TMP/after.md" >/dev/null 2>&1; then
    printf '[FAIL] %s — checker should reject\n' "$label"
    fail=$((fail + 1))
  else
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  fi
}

pn_write_before

cat > "$PN_TMP/after.md" <<'EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす。

## Scope

- In: canonicalize plan
- Out: runtime implementation

## Global Constraints

- REQ-1 を維持する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
EOF
pn_assert_pass "正常な Canonical Plan は PASS"

cat > "$PN_TMP/after.md" <<'EOF'
# TASK-X Plan

## Goal

AC-1 を満たす。

## Scope

- In: canonicalize plan

## Global Constraints

- REQ-1 を維持する。

## Work Breakdown

- AC-1: current canonical state を生成する

## Verification Plan

- REQ-1 を検証する。
EOF
pn_assert_fail "before の AC-2 が消えた場合は FAIL"

cat > "$PN_TMP/after.md" <<'EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす。当初は別案だったがレビューで変更した。

## Scope

- In: canonicalize plan

## Global Constraints

- REQ-1 を維持する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 を検証する。
EOF
pn_assert_fail "履歴依存表現が残る場合は FAIL"

cat > "$PN_TMP/after.md" <<'EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす。

## Scope

- In: canonicalize plan

## Global Constraints

- REQ-1 を維持する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する
EOF
pn_assert_fail "Verification Plan 欠落は FAIL"

rm -rf "$PN_TMP"
trap - EXIT INT TERM
