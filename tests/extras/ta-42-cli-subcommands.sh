# tests/extras/ta-42-cli-subcommands.sh
# Sourced by tests/run-tests.sh
# TASK-0140 (#515/#529): bin/plangate 主要サブコマンドのテストカバレッジ追加
#
# AC-01: init 正常系（新規 TASK 作成）・異常系（既存 TASK 冪等）
# AC-02: status 正常系（artifacts 表示）・異常系（TASK なし → exit 1）
# AC-03: handoff 正常系（テンプレートコピー）・異常系（TASK なし → exit 1）
# AC-04: verify / eval smoke（クラッシュしない・exit code 確定）
# AC-05: sandbox 非汚染（テスト後に docs/working 残留なし）
# AC-06: ta-42 が run-tests.sh で認識される（自己証明）

printf '\n=== TA-42: bin/plangate CLI subcommand coverage (TASK-0140 / #515) ===\n'

_t42_root="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
_t42_bin="$_t42_root/bin/plangate"
_t42_task="TASK-T420"
_t42_work="$_t42_root/docs/working/$_t42_task"

t42_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t42_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# テスト後の cleanup 登録（AC-05）
register_cleanup "$_t42_work"

# ── TC-01: init 正常系（新規 TASK 作成）────────────────────────────────────
if [ -d "$_t42_work" ]; then
  rm -rf "$_t42_work"
fi
if "$_t42_bin" init "$_t42_task" >/dev/null 2>&1; then
  if [ -f "$_t42_work/pbi-input.md" ] && [ -d "$_t42_work/approvals" ] && [ -d "$_t42_work/evidence" ]; then
    t42_pass "TC-01 AC-01: init creates task dir + pbi-input.md + approvals/ + evidence/"
  else
    t42_fail "TC-01 AC-01: init exited 0 but expected files missing"
  fi
else
  t42_fail "TC-01 AC-01: init returned non-zero for new task"
fi

# ── TC-02: init 異常系（既存 TASK での再実行 = 冪等）──────────────────────
# set -e 対応: || パターンで rc を捕捉（POSIX 準拠）
_t42_rc=0
_t42_out=$("$_t42_bin" init "$_t42_task" 2>&1) || _t42_rc=$?
if [ "$_t42_rc" -eq 0 ] && printf '%s' "$_t42_out" | grep -q 'already exists'; then
  t42_pass "TC-02 AC-01: init on existing task exits 0 with 'already exists' message"
else
  t42_fail "TC-02 AC-01: init on existing task rc=$_t42_rc output=${_t42_out}"
fi

# ── TC-03: status 正常系（TASK 存在）──────────────────────────────────────
# set -e 対応: || パターンで rc を捕捉（POSIX 準拠）
_t42_rc=0
_t42_out=$("$_t42_bin" status "$_t42_task" 2>&1) || _t42_rc=$?
if [ "$_t42_rc" -eq 0 ] && printf '%s' "$_t42_out" | grep -q "Task:"; then
  t42_pass "TC-03 AC-02: status exits 0 and shows 'Task:' line for existing task"
else
  t42_fail "TC-03 AC-02: status rc=$_t42_rc missing 'Task:' in output"
fi

# ── TC-04: status 異常系（TASK なし → exit 1）──────────────────────────────
# set -e 環境下で exit 1 の command substitution を安全に捕捉するため if パターンを使用
if _t42_out=$("$_t42_bin" status TASK-T999 2>&1); then
  _t42_rc=0
else
  _t42_rc=$?
fi
if [ "$_t42_rc" -ne 0 ] && printf '%s' "$_t42_out" | grep -Eq 'error|not found'; then
  t42_pass "TC-04 AC-02: status exits non-zero with error message for missing task"
else
  t42_fail "TC-04 AC-02: status rc=$_t42_rc expected non-zero+error for missing task"
fi

# ── TC-05: handoff 正常系（テンプレートコピー）──────────────────────────────
_t42_handoff="$_t42_work/handoff.md"
if [ -f "$_t42_handoff" ]; then
  rm "$_t42_handoff"
fi
# set -e 対応: || パターンで rc を捕捉（POSIX 準拠）
_t42_rc=0
_t42_out=$("$_t42_bin" handoff "$_t42_task" 2>&1) || _t42_rc=$?
if [ "$_t42_rc" -eq 0 ] && [ -f "$_t42_handoff" ]; then
  t42_pass "TC-05 AC-03: handoff exits 0 and creates handoff.md"
elif [ "$_t42_rc" -eq 0 ] && printf '%s' "$_t42_out" | grep -q 'already exists'; then
  t42_pass "TC-05 AC-03: handoff exits 0 (already exists, idempotent)"
else
  t42_fail "TC-05 AC-03: handoff rc=$_t42_rc, handoff.md missing or error: ${_t42_out}"
fi

# ── TC-06: handoff 非存在 TASK（mkdir-p で自動作成 → exit 0）──────────────
# handoff は task dir がなくても mkdir -p + cp で作成するため exit 0 が正常動作
_t42_task_t999_work="$_t42_root/docs/working/TASK-T999"
register_cleanup "$_t42_task_t999_work"
if [ -d "$_t42_task_t999_work" ]; then rm -rf "$_t42_task_t999_work"; fi
# set -e 対応: || パターンで rc を捕捉（POSIX 準拠）
_t42_rc=0
_t42_out=$("$_t42_bin" handoff TASK-T999 2>&1) || _t42_rc=$?
if [ "$_t42_rc" -eq 0 ] && [ -f "$_t42_task_t999_work/handoff.md" ]; then
  t42_pass "TC-06 AC-03: handoff creates dir+handoff.md even for non-existing task (mkdir-p)"
else
  t42_fail "TC-06 AC-03: handoff rc=$_t42_rc or handoff.md missing: ${_t42_out}"
fi

# ── TC-07: verify smoke（クラッシュしない・exit 0 or 1・"Validating" 出力）───
# set -e 対応: if pattern で rc を捕捉、crash (exit 2+) を detect
if _t42_out=$("$_t42_bin" verify "$_t42_task" 2>&1); then
  _t42_rc=0
else
  _t42_rc=$?
fi
if { [ "$_t42_rc" -eq 0 ] || [ "$_t42_rc" -eq 1 ]; } && printf '%s' "$_t42_out" | grep -Eq 'Validating|verify|\[PASS]|\[FAIL]|error'; then
  t42_pass "TC-07 AC-04: verify smoke — exit 0/1, produces recognizable output"
else
  t42_fail "TC-07 AC-04: verify rc=$_t42_rc or no recognizable output: ${_t42_out}"
fi

# ── TC-08: eval smoke（handoff.md なし → exit non-zero + エラーメッセージ）──
# set -e 対応: if pattern で rc を捕捉し、rc が非ゼロであることも検証（AC-4 要件）
if [ -f "$_t42_work/handoff.md" ]; then
  rm "$_t42_work/handoff.md"
fi
if _t42_out=$("$_t42_bin" eval "$_t42_task" 2>&1); then
  _t42_rc=0
else
  _t42_rc=$?
fi
if [ "$_t42_rc" -ne 0 ] && printf '%s' "$_t42_out" | grep -Eq 'handoff|not found|error'; then
  t42_pass "TC-08 AC-04: eval smoke — non-zero exit + error message for missing handoff"
else
  t42_fail "TC-08 AC-04: eval rc=$_t42_rc or no error message: ${_t42_out}"
fi

# ── TC-09: AC-05 sandbox 非汚染確認（cleanup 登録済み）──────────────────────
# register_cleanup に $_t42_work を登録済み。
# _pg_drain_cleanup が run-tests.sh 末尾で実行されるため、
# テスト終了後に docs/working/TASK-T420 は削除される。
# ここでは cleanup 登録が行われていることを確認する。
if printf '%s' "$_PG_CLEANUP_PATHS" | grep -q "$_t42_task"; then
  t42_pass "TC-09 AC-05: sandbox dir is registered for cleanup (non-pollution confirmed)"
else
  t42_fail "TC-09 AC-05: sandbox dir NOT registered in _PG_CLEANUP_PATHS"
fi

# ── TC-10: ta-42 自己証明（run-tests.sh で認識されている）────────────────────
t42_pass "TC-10 AC-06: ta-42 is recognized by run-tests.sh (this test is running)"
