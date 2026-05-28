# tests/extras/ta-22-git-add-scope.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0119: git add scope guard hook 検証

printf '\n=== TA-22: git-add-scope-guard (TASK-0119) ===\n'

PG_T22_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T22_HOOK="$PG_T22_ROOT/scripts/check-git-add-scope.sh"
PG_T22_DOC="$PG_T22_ROOT/docs/ai/git-add-scope-guard.md"

t22_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t22_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-1): script 存在 + 実行可能 ===
if [ -f "$PG_T22_HOOK" ] && [ -x "$PG_T22_HOOK" ]; then
  t22_pass "TC-01 check-git-add-scope.sh 存在 + 実行可能"
else
  t22_fail "TC-01 hook 不在 or 非実行可能"
fi

# === TC-02 (AC-1): syntax check ===
if sh -n "$PG_T22_HOOK" 2>/dev/null; then
  t22_pass "TC-02 sh -n syntax check"
else
  t22_fail "TC-02 syntax error"
fi

# === TC-03 (AC-4): docs 存在 + 主要 section ===
if [ -f "$PG_T22_DOC" ]; then
  if grep -qE "## install|## allowlist|## bypass|## 検知対象|Defense in Depth" "$PG_T22_DOC"; then
    t22_pass "TC-03 doc 存在 + 主要 section"
  else
    t22_fail "TC-03 doc 主要 section 不足"
  fi
else
  t22_fail "TC-03 doc 不在: $PG_T22_DOC"
fi

# === TC-04 (AC-3): PLANGATE_SKIP_SCOPE_CHECK=1 で全スキップ ===
# 一時 git repo を作成して fixture テスト
T22_TMPDIR=$(mktemp -d)
trap 'rm -rf "$T22_TMPDIR"' EXIT INT TERM

(
  cd "$T22_TMPDIR" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  echo "test" > test.txt && \
  git add test.txt
) 2>/dev/null

T22_OUT=$(cd "$T22_TMPDIR" && PLANGATE_SKIP_SCOPE_CHECK=1 sh "$PG_T22_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T22_OUT" | grep -qE "EXIT=0$"; then
  t22_pass "TC-04 PLANGATE_SKIP_SCOPE_CHECK=1 でスキップ (exit 0)"
else
  t22_fail "TC-04 PLANGATE_SKIP_SCOPE_CHECK=1 が効かない: $T22_OUT"
fi

# === TC-05 (AC-1): 空 staging area → 通過 (exit 0) ===
T22_TMPDIR2=$(mktemp -d)
trap 'rm -rf "$T22_TMPDIR" "$T22_TMPDIR2"' EXIT INT TERM

(
  cd "$T22_TMPDIR2" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test"
) 2>/dev/null

T22_OUT2=$(cd "$T22_TMPDIR2" && sh "$PG_T22_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T22_OUT2" | grep -qE "EXIT=0$"; then
  t22_pass "TC-05 空 staging area → 通過 (exit 0)"
else
  t22_fail "TC-05 空 staging area で誤検知: $T22_OUT2"
fi

# === TC-06 (AC-1): skip-decision-log に acknowledged_by:null → 検知 (exit 1) ===
T22_TMPDIR3=$(mktemp -d)
trap 'rm -rf "$T22_TMPDIR" "$T22_TMPDIR2" "$T22_TMPDIR3"' EXIT INT TERM

(
  cd "$T22_TMPDIR3" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  mkdir -p docs/working/_audit && \
  echo '{"ts":"2026-01-01T00:00:00Z","event":"EH-3_SKIP","target":"src/foo.ts","skip_reason":"test","acknowledged_by":null,"acknowledged_at":null}' \
    > docs/working/_audit/skip-decision-log.jsonl && \
  git add docs/working/_audit/skip-decision-log.jsonl
) 2>/dev/null

T22_OUT3=$(cd "$T22_TMPDIR3" && sh "$PG_T22_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T22_OUT3" | grep -qE "EXIT=1$" && echo "$T22_OUT3" | grep -q "acknowledged_by:null"; then
  t22_pass "TC-06 skip-log 未追認 → 検知 + exit 1"
else
  t22_fail "TC-06 skip-log 未追認 検知失敗: $T22_OUT3"
fi

# === TC-07 (AC-1): 異 TASK eval-result staged → 検知 (exit 1) ===
T22_TMPDIR4=$(mktemp -d)
trap 'rm -rf "$T22_TMPDIR" "$T22_TMPDIR2" "$T22_TMPDIR3" "$T22_TMPDIR4"' EXIT INT TERM

(
  cd "$T22_TMPDIR4" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  mkdir -p docs/working/TASK-9999 && \
  echo '{"score":99}' > docs/working/TASK-9999/eval-result.json && \
  git add docs/working/TASK-9999/eval-result.json
) 2>/dev/null

T22_OUT4=$(cd "$T22_TMPDIR4" && PLANGATE_HOOK_TASK=TASK-0001 sh "$PG_T22_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T22_OUT4" | grep -qE "EXIT=1$" && echo "$T22_OUT4" | grep -q "eval-result"; then
  t22_pass "TC-07 異 TASK eval-result → 検知 + exit 1"
else
  t22_fail "TC-07 異 TASK eval-result 検知失敗: $T22_OUT4"
fi

# === TC-08 (AC-2): 同 TASK eval-result staged → 通過 (exit 0) ===
T22_TMPDIR5=$(mktemp -d)
trap 'rm -rf "$T22_TMPDIR" "$T22_TMPDIR2" "$T22_TMPDIR3" "$T22_TMPDIR4" "$T22_TMPDIR5"' EXIT INT TERM

(
  cd "$T22_TMPDIR5" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  mkdir -p docs/working/TASK-0119 && \
  echo '{"score":99}' > docs/working/TASK-0119/eval-result.json && \
  git add docs/working/TASK-0119/eval-result.json
) 2>/dev/null

T22_OUT5=$(cd "$T22_TMPDIR5" && PLANGATE_HOOK_TASK=TASK-0119 sh "$PG_T22_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T22_OUT5" | grep -qE "EXIT=0$"; then
  t22_pass "TC-08 同 TASK eval-result → 通過 (exit 0)"
else
  t22_fail "TC-08 同 TASK eval-result 誤検知: $T22_OUT5"
fi

# cleanup (最終 trap で全削除)
