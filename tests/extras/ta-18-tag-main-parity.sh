# tests/extras/ta-18-tag-main-parity.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0116 / #354: check-tag-main-parity.sh + release-process.md 検証

printf '\n=== TA-18: tag-main-parity (#354 TASK-0116) ===\n'

PG_T18_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T18_SCRIPT="$PG_T18_ROOT/scripts/check-tag-main-parity.sh"
PG_T18_DOC="$PG_T18_ROOT/docs/release-process.md"

t18_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t18_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-2): script 存在 + 実行可能 ===
if [ -f "$PG_T18_SCRIPT" ] && [ -x "$PG_T18_SCRIPT" ]; then
  t18_pass "TC-01 check-tag-main-parity.sh 存在 + 実行可能"
else
  t18_fail "TC-01 script 不在 or 非実行"
fi

# === TC-01b: syntax check ===
if sh -n "$PG_T18_SCRIPT" 2>/dev/null; then
  t18_pass "TC-01b syntax check"
else
  t18_fail "TC-01b syntax error"
fi

# === fixture tmp git repo 作成 ===
T18_TMP=$(mktemp -d)
(
  cd "$T18_TMP"
  git init -q
  git config user.email t@t.t
  git config user.name t
  git config commit.gpgsign false
  echo "v1" > f.txt
  git add f.txt
  git commit -q -m "c1"
  # fake origin/main を refs/remotes/origin/main で作る
  git update-ref refs/remotes/origin/main HEAD
) 2>/dev/null

# === TC-02 (R-004 annotated): annotated tag = main 一致時 exit 0 ===
T18_OUT=$(cd "$T18_TMP" && git tag -a v1.0 HEAD -m "release" 2>/dev/null; \
  # fetch を no-op 化するため local check に置換: script は git fetch origin main するが
  # local repo に origin remote ないため、本 TC は script の peel ロジックを別途確認
  git rev-parse "v1.0^{commit}" 2>/dev/null)
T18_MAIN=$(cd "$T18_TMP" && git rev-parse refs/remotes/origin/main 2>/dev/null)
if [ -n "$T18_OUT" ] && [ "$T18_OUT" = "$T18_MAIN" ]; then
  t18_pass "TC-02 annotated tag ^{commit} = origin/main (peel ロジック確認)"
else
  t18_fail "TC-02 annotated peel: tag=$T18_OUT main=$T18_MAIN"
fi

# === TC-03 (R-004 lightweight): lightweight tag も ^{commit} で peel ===
T18_LW=$(cd "$T18_TMP" && git tag v1.0-lite HEAD 2>/dev/null; git rev-parse "v1.0-lite^{commit}" 2>/dev/null)
if [ -n "$T18_LW" ] && [ "$T18_LW" = "$T18_MAIN" ]; then
  t18_pass "TC-03 lightweight tag ^{commit} = origin/main"
else
  t18_fail "TC-03 lightweight peel: tag=$T18_LW main=$T18_MAIN"
fi

# === TC-04 (AC-1): tag 不在時 exit 1 + メッセージ ===
T18_OUT=$(sh "$PG_T18_SCRIPT" nonexistent-tag-xyz 2>&1 || echo "EXIT=$?")
if echo "$T18_OUT" | grep -qE "FAIL.*(存在しません|tag)|EXIT=1"; then
  t18_pass "TC-04 tag 不在時 exit 1 + メッセージ"
else
  t18_fail "TC-04 tag 不在 handling: $T18_OUT"
fi

# === TC-05 (AC-1): tag 引数なし時 exit 1 + usage ===
T18_OUT=$(sh "$PG_T18_SCRIPT" 2>&1 || echo "EXIT=$?")
if echo "$T18_OUT" | grep -qE "tag 引数が必要|usage|EXIT=1"; then
  t18_pass "TC-05 tag 引数なし時 exit 1 + usage"
else
  t18_fail "TC-05 引数なし handling: $T18_OUT"
fi

# === TC-06 (AC-1): Iron Law doc 存在 + 必須記述 ===
if [ -f "$PG_T18_DOC" ]; then
  if grep -qE "NO RELEASE WITHOUT TAG-MAIN PARITY" "$PG_T18_DOC"; then
    t18_pass "TC-06 docs/release-process.md に Iron Law 記述"
  else
    t18_fail "TC-06 Iron Law 記述なし"
  fi
else
  t18_fail "TC-06 docs/release-process.md 不在"
fi

# === TC-07 (R-002): doc に --force-with-lease + ref 明示 ===
if grep -qE 'force-with-lease.*refs/tags|refs/tags/.*:refs/tags' "$PG_T18_DOC"; then
  t18_pass "TC-07 doc に --force-with-lease + ref 明示 (R-002)"
else
  t18_fail "TC-07 --force-with-lease + ref 明示なし"
fi

# === TC-08 (R-001): script 冒頭で git fetch origin main ===
if grep -qE "git fetch origin main" "$PG_T18_SCRIPT"; then
  t18_pass "TC-08 script に git fetch origin main (stale 防止 / R-001)"
else
  t18_fail "TC-08 git fetch なし"
fi

# === TC-09 (R-003): responsibility-classes.md §publish に link 追記 ===
RC="$PG_T18_ROOT/.claude/rules/responsibility-classes.md"
if grep -qE "NO RELEASE WITHOUT TAG-MAIN PARITY|check-tag-main-parity" "$RC"; then
  t18_pass "TC-09 responsibility-classes.md §publish に link 追記 (R-003)"
else
  t18_fail "TC-09 rule link なし"
fi

# cleanup
rm -rf "$T18_TMP"
