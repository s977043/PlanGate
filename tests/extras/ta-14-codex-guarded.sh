# tests/extras/ta-14-codex-guarded.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# Gap 4 / #336: scripts/codex-guarded.sh の argument parsing と pre-flight 検証

printf '\n=== TA-14: codex-guarded.sh (Gap 4 / #336) ===\n'

PG_T14_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T14_WRAPPER="$PG_T14_ROOT/scripts/codex-guarded.sh"

t14_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t14_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01: wrapper script が存在し実行可能 ===
if [ -f "$PG_T14_WRAPPER" ] && [ -x "$PG_T14_WRAPPER" ]; then
  t14_pass "TC-01 codex-guarded.sh exists and is executable"
else
  t14_fail "TC-01 codex-guarded.sh missing or not executable"
fi

# === TC-02: shell syntax check ===
if sh -n "$PG_T14_WRAPPER" 2>/dev/null; then
  t14_pass "TC-02 shell syntax OK"
else
  t14_fail "TC-02 shell syntax error"
fi

# === TC-03: --help が usage を表示 ===
_tc03_out=$("$PG_T14_WRAPPER" --help 2>&1 || true)
if printf '%s' "$_tc03_out" | grep -q "Usage:"; then
  t14_pass "TC-03 --help shows Usage line"
else
  t14_fail "TC-03 --help missing Usage line"
fi

# === TC-04: TASK ID 未指定で error 終了 (exit 1) ===
# Run from a directory that does NOT match docs/working/TASK-*/ to avoid cwd auto-detection
_tc04_rc=0
(
  cd "$PG_T14_ROOT"
  "$PG_T14_WRAPPER" >/dev/null 2>&1
) || _tc04_rc=$?
if [ "$_tc04_rc" = "1" ]; then
  t14_pass "TC-04 missing TASK ID exits with code 1"
else
  t14_fail "TC-04 missing TASK ID should exit 1, got $_tc04_rc"
fi

# === TC-05: 不正な TASK ID 形式で error 終了 (exit 1) ===
_tc05_rc=0
(
  cd "$PG_T14_ROOT"
  "$PG_T14_WRAPPER" --task "INVALID-XXX" >/dev/null 2>&1
) || _tc05_rc=$?
if [ "$_tc05_rc" = "1" ]; then
  t14_pass "TC-05 invalid TASK ID format exits with code 1"
else
  t14_fail "TC-05 invalid TASK ID should exit 1, got $_tc05_rc"
fi

# === TC-06: docs/ai/settings-wiring-contract.md に Codex parity 限界節がある ===
PG_T14_CONTRACT="$PG_T14_ROOT/docs/ai/settings-wiring-contract.md"
if [ -f "$PG_T14_CONTRACT" ] && grep -q "Codex CLI parity" "$PG_T14_CONTRACT"; then
  t14_pass "TC-06 settings-wiring-contract has Codex CLI parity section"
else
  t14_fail "TC-06 settings-wiring-contract missing Codex CLI parity section"
fi

# === TC-07: ai-dev-exec skill が codex-guarded.sh を参照 ===
PG_T14_EXEC_SKILL="$PG_T14_ROOT/.agents/skills/ai-dev-exec/SKILL.md"
if [ -f "$PG_T14_EXEC_SKILL" ] && grep -q "codex-guarded.sh" "$PG_T14_EXEC_SKILL"; then
  t14_pass "TC-07 ai-dev-exec skill references codex-guarded.sh"
else
  t14_fail "TC-07 ai-dev-exec skill missing codex-guarded.sh reference"
fi

# === TC-08: local-exec-handoff skill が codex-guarded.sh を参照 ===
PG_T14_HANDOFF_SKILL="$PG_T14_ROOT/.agents/skills/local-exec-handoff/SKILL.md"
if [ -f "$PG_T14_HANDOFF_SKILL" ] && grep -q "codex-guarded.sh" "$PG_T14_HANDOFF_SKILL"; then
  t14_pass "TC-08 local-exec-handoff skill references codex-guarded.sh"
else
  t14_fail "TC-08 local-exec-handoff skill missing codex-guarded.sh reference"
fi
