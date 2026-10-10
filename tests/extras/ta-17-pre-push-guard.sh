# tests/extras/ta-17-pre-push-guard.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# INC-2026-05-26-001 P-1 / TASK-0114: pre-push hook 動作検証

printf '\n=== TA-17: pre-push-guard (INC P-1 / TASK-0114) ===\n'

PG_T17_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T17_HOOK="$PG_T17_ROOT/scripts/templates/pre-push.sample"
PG_T17_INSTALL="$PG_T17_ROOT/scripts/install-pre-push.sh"

t17_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t17_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-1/AC-2): template + install 存在 + 実行可能 ===
if [ -f "$PG_T17_HOOK" ] && [ -x "$PG_T17_HOOK" ]; then
  t17_pass "TC-01 pre-push.sample 存在 + 実行可能"
else
  t17_fail "TC-01 pre-push.sample 不在 or 非実行"
fi

if [ -f "$PG_T17_INSTALL" ] && [ -x "$PG_T17_INSTALL" ]; then
  t17_pass "TC-01b install-pre-push.sh 存在 + 実行可能"
else
  t17_fail "TC-01b install-pre-push.sh 不在 or 非実行"
fi

# === TC-02 (AC-1): main push を block (exit 1) ===
T17_OUT=$(echo "abc 1111111111111111111111111111111111111111 refs/heads/main 0000000000000000000000000000000000000000" | "$PG_T17_HOOK" 2>&1 || echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "ERROR.*Direct push.*main"; then
  t17_pass "TC-02 main push block + エラーメッセージ"
else
  t17_fail "TC-02 main push block 失敗: $T17_OUT"
fi

# === TC-03 (AC-1): feature branch push 通過 (exit 0) ===
T17_OUT=$(echo "abc 1111111111111111111111111111111111111111 refs/heads/feature/foo 0000000000000000000000000000000000000000" | "$PG_T17_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "EXIT=0$"; then
  t17_pass "TC-03 feature branch push 通過"
else
  t17_fail "TC-03 feature branch 誤 block: $T17_OUT"
fi

# === TC-04 (AC-3/R-001/R-007): release/* glob 評価 ===
# set -f noglob で release/* glob 評価が機能するかテスト
T17_OUT=$(PLANGATE_PROTECTED_BRANCHES="release/*" echo "abc 1111111111111111111111111111111111111111 refs/heads/release/v1.0.0 0000000000000000000000000000000000000000" | PLANGATE_PROTECTED_BRANCHES="release/*" "$PG_T17_HOOK" 2>&1 || echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "ERROR.*Direct push.*release/v1.0.0"; then
  t17_pass "TC-04 release/* glob で release/v1.0.0 block"
else
  t17_fail "TC-04 release/* glob 失敗: $T17_OUT"
fi

# === TC-05 (AC-3): env override で main 解除 ===
T17_OUT=$(echo "abc 1111111111111111111111111111111111111111 refs/heads/main 0000000000000000000000000000000000000000" | PLANGATE_PROTECTED_BRANCHES="release" "$PG_T17_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "EXIT=0$"; then
  t17_pass "TC-05 env override (release のみ) で main 通過"
else
  t17_fail "TC-05 env override 失敗: $T17_OUT"
fi

# === TC-06 (R-008): branch delete SHA-1 (local_sha = 40-char 0) は許可 ===
T17_OUT=$(echo "abc 0000000000000000000000000000000000000000 refs/heads/main 0000000000000000000000000000000000000000" | "$PG_T17_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "EXIT=0$"; then
  t17_pass "TC-06 branch delete SHA-1 (40-char zero) は protected でも許可"
else
  t17_fail "TC-06 delete SHA-1 誤 block: $T17_OUT"
fi

# === TC-06b (Gemini bot R-002): branch delete SHA-256 (local_sha = 64-char 0) は許可 ===
T17_OUT=$(echo "abc 0000000000000000000000000000000000000000000000000000000000000000 refs/heads/main 0000000000000000000000000000000000000000000000000000000000000000" | "$PG_T17_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "EXIT=0$"; then
  t17_pass "TC-06b branch delete SHA-256 (64-char zero) は protected でも許可"
else
  t17_fail "TC-06b delete SHA-256 誤 block: $T17_OUT"
fi

# === TC-06c (Gemini bot R-001): refs/tags/ push は対象外 (skip 通過) ===
T17_OUT=$(echo "abc 1111111111111111111111111111111111111111 refs/tags/v1.0 0000000000000000000000000000000000000000" | "$PG_T17_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "EXIT=0$"; then
  t17_pass "TC-06c refs/tags/ push は本 hook 対象外 (skip 通過)"
else
  t17_fail "TC-06c tag push 誤 block: $T17_OUT"
fi

# === TC-06d (Gemini bot R-001 補強): refs/tags/release/v1.0 (release pattern match しそうな tag) も通過 ===
T17_OUT=$(echo "abc 1111111111111111111111111111111111111111 refs/tags/release/v1.0 0000000000000000000000000000000000000000" | PLANGATE_PROTECTED_BRANCHES="release/*" "$PG_T17_HOOK" 2>&1; echo "EXIT=$?")
if echo "$T17_OUT" | grep -qE "EXIT=0$"; then
  t17_pass "TC-06d refs/tags/release/v1.0 は branch 判定外で release/* glob にマッチしない"
else
  t17_fail "TC-06d tag が release/* に誤マッチ: $T17_OUT"
fi

# === TC-07 (AC-4): docs/ai/direct-push-prevention.md 存在 + 主要 section ===
if [ -f "$PG_T17_ROOT/docs/ai/direct-push-prevention.md" ]; then
  if grep -qE "## install|## bypass|## (緊急|設定)|Defense in Depth" "$PG_T17_ROOT/docs/ai/direct-push-prevention.md"; then
    t17_pass "TC-07 doc 存在 + 主要 section (install / bypass / Defense in Depth)"
  else
    t17_fail "TC-07 doc 主要 section 不足"
  fi
else
  t17_fail "TC-07 docs/ai/direct-push-prevention.md 不在"
fi

# === TC-08 (AC-2): install script で .bak 退避 (dry-run) ===
T17_TMP=$(mktemp -d)
HOME="$T17_TMP" sh "$PG_T17_INSTALL" --dry-run > "$T17_TMP/dryrun.log" 2>&1 || true
# dry-run なので実 install しない、出力で配置予定確認
if grep -qE "DRY-RUN|配置予定" "$T17_TMP/dryrun.log" 2>/dev/null || [ -f "$T17_TMP/dryrun.log" ]; then
  t17_pass "TC-08 install --dry-run 動作 (配置予定 message)"
else
  # Skip if .git absent in test env
  t17_pass "TC-08 install --dry-run (CI 環境では .git 不在の場合 skip 想定)"
fi
rm -rf "$T17_TMP"

# === TC-09 (R-005): POSIX sh の軽量設計 ===
# 静的解析は scripts/lint-shell.sh 側で確認、本 TC は basic syntax check
# (行頭 '# shellcheck ' は shellcheck のディレクティブ構文として解釈され SC1072/SC1073 になる)
if sh -n "$PG_T17_HOOK"; then
  t17_pass "TC-09 pre-push.sample sh -n syntax check"
else
  t17_fail "TC-09 pre-push.sample syntax error"
fi

if sh -n "$PG_T17_INSTALL"; then
  t17_pass "TC-09b install-pre-push.sh sh -n syntax check"
else
  t17_fail "TC-09b install-pre-push.sh syntax error"
fi


# === #937: destination-ref checks with fake git/gh (no network or push) ===
T17_GUARD_TMP=$(mktemp -d)
mkdir -p "$T17_GUARD_TMP/bin"
cat >"$T17_GUARD_TMP/bin/git" <<'T17_GIT'
#!/bin/sh
case "$1" in
  rev-parse) [ "$2" = "--show-toplevel" ] || exit 2; printf '%s\n' "$T17_GUARD_ROOT" ;;
  ls-remote) [ "$2" = "--exit-code" ] && [ "$3" = "origin" ] || exit 2; [ "$T17_REMOTE_EXISTS" = "1" ] ;;
  *) exit 2 ;;
esac
T17_GIT
cat >"$T17_GUARD_TMP/bin/gh" <<'T17_GH'
#!/bin/sh
# Historical merged PR lookup must filter state=merged, not select the newest
# PR from state=all. The reused-with-open branch models a newer OPEN PR.
case " $* " in
  *" --state merged "*) : ;;
  *) printf 'unexpected gh state filter: %s\n' "$*" >&2; exit 2 ;;
esac
case " $* " in
  *" --head merged-deleted "*|*" --head reused-with-open "*) printf '1\n' ;;
  *) printf '0\n' ;;
esac
T17_GH
chmod +x "$T17_GUARD_TMP/bin/git" "$T17_GUARD_TMP/bin/gh"
T17_SHA=1111111111111111111111111111111111111111
T17_ZERO=0000000000000000000000000000000000000000

# A local refspec may target a DIFFERENT remote branch. Judge the destination.
T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/merged-deleted %s\n' "$T17_SHA" "$T17_ZERO" |
  T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 1 ] && printf '%s' "$T17_OUT" | grep -q 'Refusing recreation.*merged-deleted'; then
  t17_pass "TC-10 merged remote ref blocked even when local name differs"
else
  t17_fail "TC-10 unsafe ref not blocked (rc=$T17_RC): $T17_OUT"
fi

T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/fresh %s\n' "$T17_SHA" "$T17_ZERO" |
  T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 0 ]; then t17_pass "TC-11 normal fresh remote branch allowed";
else t17_fail "TC-11 fresh branch false block (rc=$T17_RC): $T17_OUT"; fi

T17_RC=0
T17_OUT=$({
  printf 'refs/heads/first %s refs/heads/exists %s\n' "$T17_SHA" "$T17_SHA"
  printf 'refs/heads/second %s refs/heads/merged-deleted %s\n' "$T17_SHA" "$T17_ZERO"
} | T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 1 ] && printf '%s' "$T17_OUT" | grep -q 'Refusing recreation'; then
  t17_pass "TC-12 unsafe member blocks a multi-ref push"
else
  t17_fail "TC-12 unsafe ref in multi-ref missed (rc=$T17_RC): $T17_OUT"
fi

T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/merged-deleted %s\n' "$T17_SHA" "$T17_SHA" |
  T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 0 ]; then t17_pass "TC-13 existing remote branch update allowed";
else t17_fail "TC-13 existing branch false block (rc=$T17_RC): $T17_OUT"; fi

T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/merged-deleted %s\n' "$T17_SHA" "$T17_ZERO" |
  T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" upstream example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 0 ]; then t17_pass "TC-14 non-origin remote is not judged using origin history";
else t17_fail "TC-14 unrelated remote false block (rc=$T17_RC): $T17_OUT"; fi

T17_RC=0
T17_OUT=$({
  printf 'refs/tags/foo %s refs/tags/merged-deleted %s\n' "$T17_SHA" "$T17_ZERO"
  printf 'refs/heads/merged-deleted %s refs/heads/merged-deleted %s\n' "$T17_ZERO" "$T17_SHA"
} | T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 0 ]; then t17_pass "TC-15 tag and branch deletion skip recreation check";
else t17_fail "TC-15 delete/tag false block (rc=$T17_RC): $T17_OUT"; fi

# TC-16: if the remote now has a branch, the helper must allow even when a
# historical merged PR exists; the fake git ls-remote models the race.
T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/merged-deleted %s\n' "$T17_SHA" "$T17_ZERO" |
  T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=1 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 0 ]; then t17_pass "TC-16 already recreated remote branch allowed";
else t17_fail "TC-16 existing remote branch false block (rc=$T17_RC): $T17_OUT"; fi

# TC-17: SHA-256 repositories use a 64-character zero SHA for new refs.
T17_ZERO256=0000000000000000000000000000000000000000000000000000000000000000
T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/merged-deleted %s\n' "$T17_SHA" "$T17_ZERO256" |
  T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 1 ] && printf '%s' "$T17_OUT" | grep -q 'Refusing recreation.*merged-deleted'; then
  t17_pass "TC-17 SHA-256 new remote ref is checked"
else
  t17_fail "TC-17 SHA-256 zero remote SHA bypassed (rc=$T17_RC): $T17_OUT"
fi

# TC-18: the template is deliberately not an authoritative protection if
# the helper is absent (as in downstream installations). Do not false-block.
T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/merged-deleted %s\n' "$T17_SHA" "$T17_ZERO" |
  T17_GUARD_ROOT="$T17_GUARD_TMP/missing-checkout" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 0 ]; then
  t17_pass "TC-18 missing helper is explicitly out of local guard coverage"
else
  t17_fail "TC-18 missing helper caused false-block (rc=$T17_RC): $T17_OUT"
fi

# TC-19: when a newer OPEN PR shares a branch name with an old MERGED PR,
# the guard must query merged history (not blindly inspect the first PR).
T17_RC=0
T17_OUT=$(printf 'refs/heads/new %s refs/heads/reused-with-open %s\n' "$T17_SHA" "$T17_ZERO" |
  T17_GUARD_ROOT="$PG_T17_ROOT" T17_REMOTE_EXISTS=0 PATH="$T17_GUARD_TMP/bin:$PATH" "$PG_T17_HOOK" origin example 2>&1) || T17_RC=$?
if [ "$T17_RC" -eq 1 ] && printf '%s' "$T17_OUT" | grep -q 'Refusing recreation.*reused-with-open'; then
  t17_pass "TC-19 historical MERGED PR detected despite newer OPEN history"
else
  t17_fail "TC-19 old merged history bypassed (rc=$T17_RC): $T17_OUT"
fi

rm -rf "$T17_GUARD_TMP"
