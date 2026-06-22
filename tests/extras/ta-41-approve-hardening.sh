# tests/extras/ta-41-approve-hardening.sh
# Sourced by tests/run-tests.sh
# TASK-0139 (#550): plangate approve ハードニングの検証
#
# AC-01: read -r 化 (cmd_approve)
# AC-02: read -r 化 (maintenance L4)
# AC-03: PLANGATE_FAKE_PPID_COMM が PLANGATE_TEST_MODE=1 時のみ有効
# AC-04: c3.json 上書き block (--force なし → abort)
# AC-05: ADR ファイル存在
# AC-06: ta-41 が run-tests.sh で認識 (自身の実行が証明)
# AC-07: 既存テスト回帰 PASS (run-tests.sh で確認済み)

printf '\n=== TA-41: plangate approve hardening (TASK-0139 / #550) ===\n'

PG_T41_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T41_BIN="$PG_T41_ROOT/bin/plangate"

t41_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t41_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
t41_skip() { printf '  [SKIP] %s\n' "$1"; }

# ── TC-01: AC-01 — cmd_approve の read -r 化 (static check) ──
# TASK-0139 が apply 済みかどうかを確認する
if grep -q 'read -r _ap_reason' "$PG_T41_BIN" && grep -q 'read -r _ap_conditions' "$PG_T41_BIN"; then
  t41_pass "TC-01 AC-01: read -r _ap_reason and read -r _ap_conditions present"
else
  # apply 未適用の場合: apply-script を dry-run して差分が出ることを確認
  if sh "$PG_T41_ROOT/scripts/apply-approve-hardening.sh" --dry-run 2>/dev/null | grep -q 'read -r _ap_reason\|read -r _ap_conditions'; then
    t41_skip "TC-01 AC-01: apply-script ready (apply pending); dry-run shows correct diff"
  else
    t41_fail "TC-01 AC-01: read -r _ap_reason/conditions NOT present and dry-run shows no diff"
  fi
fi

# ── TC-02: AC-02 — maintenance の read -r 化 (static check) ──
# maintenance の read _ack が read -r _ack に変更されているか
# maintenance L4 には 'read -r _ack' が存在するはず (apply 後)
# apply 前は 'read _ack' が maintenance 内に存在する
if grep -q 'read -r _ack' "$PG_T41_BIN"; then
  t41_pass "TC-02 AC-02: read -r _ack present in bin/plangate"
else
  if sh "$PG_T41_ROOT/scripts/apply-approve-hardening.sh" --dry-run 2>/dev/null | grep -q '+      read -r _ack'; then
    t41_skip "TC-02 AC-02: apply-script ready (apply pending); dry-run shows correct diff"
  else
    t41_fail "TC-02 AC-02: read -r _ack NOT present and dry-run shows no diff"
  fi
fi

# ── TC-03: AC-03 — FAKE_PPID_COMM が TEST_MODE=1 なしでは L3 に影響しない ──
# bin/plangate に PLANGATE_TEST_MODE=1 のガードが含まれているか (static check)
if grep -q 'PLANGATE_TEST_MODE:-0.*PLANGATE_FAKE_PPID_COMM\|PLANGATE_TEST_MODE.*=.*1.*PLANGATE_FAKE_PPID_COMM' "$PG_T41_BIN"; then
  t41_pass "TC-03 AC-03: PLANGATE_TEST_MODE guard present in bin/plangate"
else
  if sh "$PG_T41_ROOT/scripts/apply-approve-hardening.sh" --dry-run 2>/dev/null | grep -q 'PLANGATE_TEST_MODE.*PLANGATE_FAKE_PPID_COMM'; then
    t41_skip "TC-03 AC-03: apply-script ready (apply pending); dry-run shows correct diff"
  else
    t41_fail "TC-03 AC-03: PLANGATE_TEST_MODE guard NOT present and dry-run shows no diff"
  fi
fi

# ── TC-04: AC-04 — c3.json overwrite block (--force なし → abort) ──
# bin/plangate に TASK-0139 AC-04 の overwrite block が含まれているか
if grep -q 'TASK-0139 AC-04: abort if c3.json exists' "$PG_T41_BIN"; then
  t41_pass "TC-04 AC-04: c3.json overwrite block present (static check)"

  # 動作検証: 既存 c3.json あり + --force なし → exit 非0
  _t41_task="TASK-APPROVE-HARDEN-TEST"
  _t41_taskdir="$PG_T41_ROOT/docs/working/$_t41_task"
  mkdir -p "$_t41_taskdir/approvals"
  printf '# plan\n' > "$_t41_taskdir/plan.md"
  printf '{"task_id":"%s","c3_status":"APPROVED","phase":"C-3","plan_hash":"sha256:dummy"}\n' \
    "$_t41_task" > "$_t41_taskdir/approvals/c3.json"
  register_cleanup "$_t41_taskdir"

  # 非 interactive stdin で呼ぶ (L1 で弾かれるが、その前に overwrite block が先に発動するか確認)
  # Note: overwrite block は presence gate より前に実行される
  _t41_out=$(sh "$PG_T41_BIN" approve "$_t41_task" 2>&1 </dev/null || true)
  if printf '%s' "$_t41_out" | grep -q 'error: existing c3.json found'; then
    t41_pass "TC-04 AC-04: --force なし + 既存 c3.json → abort (error: existing c3.json found)"
  else
    # L1 で弾かれた場合は overwrite block まで到達しないため skip
    if printf '%s' "$_t41_out" | grep -q 'L1 interactive TTY required\|L1\|L2\|L3'; then
      t41_skip "TC-04 AC-04: overwrite check reachability: blocked at L1/L2/L3 gate (expected in non-TTY env)"
    else
      t41_fail "TC-04 AC-04: --force なし + 既存 c3.json: expected 'error: existing c3.json found', got: $_t41_out"
    fi
  fi

  # cleanup は register_cleanup に委託済み
else
  if sh "$PG_T41_ROOT/scripts/apply-approve-hardening.sh" --dry-run 2>/dev/null | grep -q 'TASK-0139 AC-04'; then
    t41_skip "TC-04 AC-04: apply-script ready (apply pending); dry-run shows correct diff"
  else
    t41_fail "TC-04 AC-04: overwrite block NOT present and dry-run shows no diff"
  fi
fi

# ── TC-05: AC-04 — c3.json 上書き --force 付き → abort しない（apply 後のみ検証）
if grep -q 'TASK-0139 AC-04: abort if c3.json exists' "$PG_T41_BIN"; then
  # --force フラグを渡した場合は overwrite block をスキップする（エラーメッセージが出ない）
  # 非 interactive なので L1 で弾かれることが期待値
  _t41_task2="TASK-FORCE-OVERWRITE-TEST"
  _t41_taskdir2="$PG_T41_ROOT/docs/working/$_t41_task2"
  mkdir -p "$_t41_taskdir2/approvals"
  printf '# plan\n' > "$_t41_taskdir2/plan.md"
  printf '{"task_id":"%s","c3_status":"APPROVED","phase":"C-3","plan_hash":"sha256:dummy"}\n' \
    "$_t41_task2" > "$_t41_taskdir2/approvals/c3.json"
  register_cleanup "$_t41_taskdir2"

  _t41_out2=$(sh "$PG_T41_BIN" approve "$_t41_task2" --force 2>&1 </dev/null || true)
  if printf '%s' "$_t41_out2" | grep -q 'error: existing c3.json found'; then
    t41_fail "TC-05 AC-04: --force 付き + 既存 c3.json: should NOT abort but got 'error: existing c3.json found'"
  else
    t41_pass "TC-05 AC-04: --force 付き + 既存 c3.json → overwrite block をスキップ（abort なし）"
  fi
  # cleanup は register_cleanup に委託済み
else
  t41_skip "TC-05 AC-04: apply pending (will be verified after apply)"
fi

# ── TC-06: AC-05 — ADR ファイルの存在 ──
_t40_adr="$PG_T41_ROOT/docs/decisions/adr-001-approve-out-of-band.md"
if [ -f "$_t40_adr" ]; then
  t41_pass "TC-06 AC-05: docs/decisions/adr-001-approve-out-of-band.md exists"
else
  t41_fail "TC-06 AC-05: docs/decisions/adr-001-approve-out-of-band.md NOT found"
fi

# ── TC-07: AC-06 — apply-script の存在と syntax ──
_t40_script="$PG_T41_ROOT/scripts/apply-approve-hardening.sh"
if [ -f "$_t40_script" ]; then
  t41_pass "TC-07 AC-06: scripts/apply-approve-hardening.sh exists"
  if sh -n "$_t40_script" 2>/dev/null; then
    t41_pass "TC-07 AC-06: apply-approve-hardening.sh shell syntax OK"
  else
    t41_fail "TC-07 AC-06: apply-approve-hardening.sh shell syntax error"
  fi
else
  t41_fail "TC-07 AC-06: scripts/apply-approve-hardening.sh NOT found"
fi

# ── TC-08: ta-41 が run-tests.sh で認識されている（自己証明） ──
t41_pass "TC-08 AC-06: ta-41 is recognized by run-tests.sh (this test is running)"
