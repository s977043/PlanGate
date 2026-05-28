# tests/extras/ta-23-gh-account-pin.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0120 / Session Retro Try #2: gh account pinning wrapper 検証

printf '\n=== TA-23: gh-account-pin wrapper (TASK-0120) ===\n'

PG_T23_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T23_WRAP="$PG_T23_ROOT/scripts/gh-s977043.sh"
PG_T23_DOC="$PG_T23_ROOT/docs/ai/github-account-pinning.md"

t23_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t23_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-1): ラッパ存在 + 実行可能 + switch ロジック ===
if [ -f "$PG_T23_WRAP" ] && [ -x "$PG_T23_WRAP" ]; then
  t23_pass "TC-01 gh-s977043.sh 存在 + 実行可能"
else
  t23_fail "TC-01 wrapper 不在 or 非実行"
fi

if grep -q 'gh auth switch --user s977043' "$PG_T23_WRAP" 2>/dev/null; then
  t23_pass "TC-01b switch ロジック (gh auth switch --user s977043) 検出"
else
  t23_fail "TC-01b switch ロジック未検出"
fi

# === TC-02 (AC-2): 冪等 (既に s977043 なら skip) ===
if grep -q 'DESIRED_USER' "$PG_T23_WRAP" 2>/dev/null && \
   grep -qE 'current.*!=|!=.*DESIRED_USER' "$PG_T23_WRAP" 2>/dev/null; then
  t23_pass "TC-02 冪等ロジック (current != DESIRED_USER 時のみ switch) 検出"
else
  t23_fail "TC-02 冪等ロジック未検出"
fi

# === TC-03 (AC-3) + TC-04 (AC-4): doc + 責務整理 ===
if [ -f "$PG_T23_DOC" ] && grep -qE '^## 運用' "$PG_T23_DOC" 2>/dev/null; then
  t23_pass "TC-03 doc 存在 + 運用 section"
else
  t23_fail "TC-03 doc or 運用 section 不在"
fi

if grep -qE '^## 責務整理' "$PG_T23_DOC" 2>/dev/null && \
   grep -q 'gh-pin-account' "$PG_T23_DOC" 2>/dev/null; then
  t23_pass "TC-04 SessionStart hook (gh-pin-account) との責務整理記述"
else
  t23_fail "TC-04 責務整理記述 不在"
fi

# === TC-06 (AC-6): syntax check ===
if sh -n "$PG_T23_WRAP" 2>/dev/null; then
  t23_pass "TC-06 sh -n syntax OK"
else
  t23_fail "TC-06 syntax error"
fi

# 動作: gh CLI 不在シミュレートで exit 127 (PATH を空にして実行)
t23_tmp_out=$(PATH="/nonexistent" "$PG_T23_WRAP" pr list 2>&1 || true)
if printf '%s' "$t23_tmp_out" | grep -q 'gh CLI not installed'; then
  t23_pass "TC-06b gh 不在時 error メッセージ"
else
  t23_fail "TC-06b gh 不在時の挙動が想定外: $t23_tmp_out"
fi
