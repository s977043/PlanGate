# tests/extras/ta-22-git-add-scope.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0119: git add scope guard hook 検証

printf '\n=== TA-22: git-add-scope-guard (TASK-0119) ===\n'

PG_T22_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T22_HOOK="$PG_T22_ROOT/scripts/check-git-add-scope.sh"
PG_T22_DOC="$PG_T22_ROOT/docs/ai/git-add-scope-guard.md"

t22_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t22_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# 一時ディレクトリを1個だけ作成し、サブディレクトリで各 TC を分離
PG_T22_TMPBASE=$(mktemp -d)
# #530-3: bare trap は source 連鎖で後続 extras に上書きされ発火保証されないため、
# 共有 register_cleanup（run-tests.sh）でハーネス末尾に一括 drain させる（trap 非依存）。
register_cleanup "$PG_T22_TMPBASE"

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

# ヘルパー: hook を実行し出力と exit code を返す
# dash + set -e 対応: hook が exit 1 の場合でも set -e が伝播しないよう || で捕捉
# 使用方法: t22_run_hook <dir> [ENV=val ...] で実行
# 結果: PG_T22_LAST_OUT (hook stdout+stderr), PG_T22_LAST_RC (exit code)
t22_run_hook() {
  _t22_dir="$1"; shift
  PG_T22_LAST_RC=0
  PG_T22_LAST_OUT=$(cd "$_t22_dir" && "$@" 2>&1) || PG_T22_LAST_RC=$?
}

# === TC-04 (AC-3): PLANGATE_SKIP_SCOPE_CHECK=1 で全スキップ ===
PG_T22_D04="$PG_T22_TMPBASE/tc04"
mkdir -p "$PG_T22_D04"
(
  cd "$PG_T22_D04" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  echo "test" > test.txt && \
  git add test.txt
) 2>/dev/null || true
t22_run_hook "$PG_T22_D04" env PLANGATE_SKIP_SCOPE_CHECK=1 sh "$PG_T22_HOOK"
if [ "$PG_T22_LAST_RC" = "0" ]; then
  t22_pass "TC-04 PLANGATE_SKIP_SCOPE_CHECK=1 でスキップ (exit 0)"
else
  t22_fail "TC-04 PLANGATE_SKIP_SCOPE_CHECK=1 が効かない (rc=$PG_T22_LAST_RC): $PG_T22_LAST_OUT"
fi

# === TC-05 (AC-1): 空 staging area → 通過 (exit 0) ===
PG_T22_D05="$PG_T22_TMPBASE/tc05"
mkdir -p "$PG_T22_D05"
(
  cd "$PG_T22_D05" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test"
) 2>/dev/null || true
t22_run_hook "$PG_T22_D05" sh "$PG_T22_HOOK"
if [ "$PG_T22_LAST_RC" = "0" ]; then
  t22_pass "TC-05 空 staging area → 通過 (exit 0)"
else
  t22_fail "TC-05 空 staging area で誤検知 (rc=$PG_T22_LAST_RC): $PG_T22_LAST_OUT"
fi

# === TC-06 (AC-1): skip-decision-log に acknowledged_by:null → 検知 (exit 1) ===
PG_T22_D06="$PG_T22_TMPBASE/tc06"
mkdir -p "$PG_T22_D06"
(
  cd "$PG_T22_D06" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  mkdir -p docs/working/_audit && \
  printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","event":"EH-3_SKIP","target":"src/foo.ts","skip_reason":"test","acknowledged_by":null,"acknowledged_at":null}' \
    > docs/working/_audit/skip-decision-log.jsonl && \
  git add docs/working/_audit/skip-decision-log.jsonl
) 2>/dev/null || true
t22_run_hook "$PG_T22_D06" sh "$PG_T22_HOOK"
if [ "$PG_T22_LAST_RC" = "1" ] && printf '%s' "$PG_T22_LAST_OUT" | grep -q "acknowledged_by:null"; then
  t22_pass "TC-06 skip-log 未追認 → 検知 + exit 1"
else
  t22_fail "TC-06 skip-log 未追認 検知失敗 (rc=$PG_T22_LAST_RC): $PG_T22_LAST_OUT"
fi

# === TC-07 (AC-1): 異 TASK eval-result staged → 検知 (exit 1) ===
PG_T22_D07="$PG_T22_TMPBASE/tc07"
mkdir -p "$PG_T22_D07"
(
  cd "$PG_T22_D07" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  mkdir -p docs/working/TASK-9999 && \
  printf '%s\n' '{"score":99}' > docs/working/TASK-9999/eval-result.json && \
  git add docs/working/TASK-9999/eval-result.json
) 2>/dev/null || true
t22_run_hook "$PG_T22_D07" env PLANGATE_HOOK_TASK=TASK-0001 sh "$PG_T22_HOOK"
if [ "$PG_T22_LAST_RC" = "1" ] && printf '%s' "$PG_T22_LAST_OUT" | grep -q "eval-result"; then
  t22_pass "TC-07 異 TASK eval-result → 検知 + exit 1"
else
  t22_fail "TC-07 異 TASK eval-result 検知失敗 (rc=$PG_T22_LAST_RC): $PG_T22_LAST_OUT"
fi

# === TC-08 (AC-2): 同 TASK eval-result staged → 通過 (exit 0) ===
PG_T22_D08="$PG_T22_TMPBASE/tc08"
mkdir -p "$PG_T22_D08"
(
  cd "$PG_T22_D08" && \
  git init -q && \
  git config user.email "test@test.com" && \
  git config user.name "test" && \
  mkdir -p docs/working/TASK-0119 && \
  printf '%s\n' '{"score":99}' > docs/working/TASK-0119/eval-result.json && \
  git add docs/working/TASK-0119/eval-result.json
) 2>/dev/null || true
t22_run_hook "$PG_T22_D08" env PLANGATE_HOOK_TASK=TASK-0119 sh "$PG_T22_HOOK"
if [ "$PG_T22_LAST_RC" = "0" ]; then
  t22_pass "TC-08 同 TASK eval-result → 通過 (exit 0)"
else
  t22_fail "TC-08 同 TASK eval-result 誤検知 (rc=$PG_T22_LAST_RC): $PG_T22_LAST_OUT"
fi

# cleanup は run-tests.sh 末尾の _pg_drain_cleanup が register_cleanup 登録分を一括実行
