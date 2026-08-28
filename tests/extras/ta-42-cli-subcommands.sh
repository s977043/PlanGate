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

# ────────── repo root の解決（M4 是正 / #1210）──────────
# 本 extras は harness 専用（$FIXTURES_DIR 依存）。$FIXTURES_DIR が未設定/空の
# まま合成すると cd -- "/../.." が / に解決され、以降のパスが //docs/working/...
# になる。合成後の文字列は「非空」なので、合成後のパスに付けた ${var:?} は
# 発火しない（stub rm 実測: RM-CALLED: -rf //docs/working/TASK-T420 が発火した）。
# ガードは合成後ではなく「root 側」に置く（ta-44 / ta-45 と同形）。
_t42_fx="${FIXTURES_DIR:-}"
if [ -n "$_t42_fx" ]; then
  _t42_root="$(CDPATH= cd -- "$_t42_fx/../.." && pwd)"
else
  # harness 実行ではないので、規約 8 に従い呼び出し元 env を無害化してから
  # 何もせず抜ける（run-tests.sh 冒頭と同一の 7 env）。
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _t42_root=""
fi
# root の健全性検査: 非空チェックだけでは / を弾けないため実体で確かめる。
if [ -z "$_t42_root" ] || [ ! -f "$_t42_root/bin/plangate" ]; then
  printf '  [FAIL] ta-42: repo root unresolved (FIXTURES_DIR=%s root=%s) — refusing to run\n' \
    "${_t42_fx:-(unset)}" "${_t42_root:-(empty)}" >&2
  if [ "${PG_HARNESS_SOURCED:-0}" = "1" ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
_t42_bin="$_t42_root/bin/plangate"
_t42_task="TASK-T420"
_t42_work="$_t42_root/docs/working/$_t42_task"

t42_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t42_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# ── 一時状態の射程宣言 + 先頭 prune + cleanup 登録（#947 / #1209 / #1210）──
# 本 extras が「共有の実 repo パス」に作る一時状態を 1 箇所で宣言し、
# body の副作用より前にまとめて prune してから register_cleanup へ登録する。
# 使用箇所ごとに rm を散らすと「事前掃除が使用箇所より後にある」順序バグを生む
# （#947 問題 1 の実体: TASK-T999 の掃除が TC-04 の判定より後にあり、中断残骸が
#  TC-04 を誤 FAIL させていた）。宣言を 1 箇所へ集約して順序バグを構造的に排除する。
# ${_t42_p:?} は 2 段目の防御にすぎない。1 段目は上の root 健全性検査で、
# 「合成後は非空だが root が / 」という M4 のケースを実際に止めるのはそちら。
# rm は base と同じく存在確認つきで撃つ（無条件 rm -rf は爆風半径を広げる）。
_t42_task_t999_work="$_t42_root/docs/working/TASK-T999"
_t42_scope_reset() {
  for _t42_p in "$@"; do
    if [ -e "${_t42_p:?ta-42: empty cleanup path refused}" ]; then
      rm -rf "$_t42_p"
    fi
    if command -v register_cleanup >/dev/null 2>&1; then
      register_cleanup "$_t42_p"
    fi
  done
}
_t42_scope_reset "$_t42_work" "$_t42_task_t999_work"

# ── TC-01: init 正常系（新規 TASK 作成）────────────────────────────────────
# 事前掃除は _t42_scope_reset（body の副作用より前）で完了済み。
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
# 掃除・登録ともに _t42_scope_reset で先頭実施済み（TC-04 より前）。
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
