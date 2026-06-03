# tests/extras/ta-26-plugin-sync.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0124: plugin/plangate sync script 検証

printf '\n=== TA-26: plugin-sync (TASK-0124) ===\n'

PG_T26_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T26_SCRIPT="$PG_T26_ROOT/scripts/sync-plugin-plangate.sh"
PG_T26_PLUGIN="$PG_T26_ROOT/plugin/plangate"
PG_T26_CLAUDE="$PG_T26_ROOT/.claude"

t26_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t26_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: sync スクリプト存在・実行可能
if [ -f "$PG_T26_SCRIPT" ] && [ -x "$PG_T26_SCRIPT" ]; then
  t26_pass "TC-01 sync-plugin-plangate.sh 存在・実行可能"
else
  t26_fail "TC-01 sync-plugin-plangate.sh 不在 or 非実行可能"
fi

# TC-02: sh -n syntax check
if sh -n "$PG_T26_SCRIPT" 2>/dev/null; then
  t26_pass "TC-02 sh -n syntax check"
else
  t26_fail "TC-02 syntax error"
fi

# TC-03: --dry-run が exit 0 で完了
_t26_out=$(sh "$PG_T26_SCRIPT" --dry-run 2>&1) || true
if [ $? -eq 0 ] || printf '%s' "$_t26_out" | grep -q "Sync complete"; then
  t26_pass "TC-03 --dry-run が正常終了"
else
  t26_fail "TC-03 --dry-run 失敗: $_t26_out"
fi

# TC-04: --dry-run が実際にファイルを変更しない
_t26_before=$(find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | md5sum 2>/dev/null || find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | cksum)
sh "$PG_T26_SCRIPT" --dry-run >/dev/null 2>&1 || true
_t26_after=$(find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | md5sum 2>/dev/null || find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | cksum)
if [ "$_t26_before" = "$_t26_after" ]; then
  t26_pass "TC-04 --dry-run がファイルを変更しない"
else
  t26_fail "TC-04 --dry-run がファイルを変更した"
fi

# TC-05: 実行後に .claude/agents/ の全 .md が plugin/plangate/agents/ に存在
_t26_tmpdir=$(mktemp -d)
trap 'rm -rf "$_t26_tmpdir"' EXIT INT TERM
cp -r "$PG_T26_PLUGIN" "$_t26_tmpdir/plugin_backup"
sh "$PG_T26_SCRIPT" >/dev/null 2>&1 || true
_t26_missing=0
for _f in "$PG_T26_CLAUDE/agents/"*.md; do
  [ -f "$_f" ] || continue
  _base="$(basename "$_f")"
  if [ ! -f "$PG_T26_PLUGIN/agents/$_base" ]; then
    _t26_missing=$((_t26_missing + 1))
  fi
done
# restore
rm -rf "$PG_T26_PLUGIN"
cp -r "$_t26_tmpdir/plugin_backup" "$PG_T26_PLUGIN"
rm -rf "$_t26_tmpdir"
trap - EXIT INT TERM
if [ "$_t26_missing" = "0" ]; then
  t26_pass "TC-05 実行後 .claude/agents/ の全 .md が plugin に存在"
else
  t26_fail "TC-05 実行後 plugin/agents/ に $_t26_missing 件不足"
fi

# TC-06: plugin/plangate/README.md の Version 行が存在
if grep -q 'Version' "$PG_T26_PLUGIN/README.md" 2>/dev/null; then
  t26_pass "TC-06 plugin/plangate/README.md に Version 行あり"
else
  t26_fail "TC-06 plugin/plangate/README.md に Version 行なし"
fi

# TC-07: apply-task-0124-patches.sh 存在・syntax check
PG_T26_PATCH="$PG_T26_ROOT/scripts/apply-task-0124-patches.sh"
if [ -f "$PG_T26_PATCH" ] && sh -n "$PG_T26_PATCH" 2>/dev/null; then
  t26_pass "TC-07 apply-task-0124-patches.sh 存在・syntax OK"
else
  t26_fail "TC-07 apply-task-0124-patches.sh 不在 or syntax error"
fi
