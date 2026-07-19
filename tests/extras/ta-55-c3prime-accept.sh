# tests/extras/ta-55-c3prime-accept.sh
# Sourced by tests/run-tests.sh
# TASK-0872 PR-2 (#872): c3-prime 受理側（scripts/ai-loop/c3prime_verify.py）の
# E2E。契約 docs/workflows/ai-loop/c3-prime-contract.md §4 の受理規則を検証する。
#
# 構成:
#   - 常時: c3prime_verify.py を直接叩き、legacy(exit 10)/valid(exit 0)/
#     tampered(exit 1)/未知 approval_kind(exit 1) を確認（非 HO・CI 常時実行）。
#   - HO 適用後のみ: bin/plangate に _plangate_c3_dispatch 配線が入っていれば
#     validate/exec の全鎖も検証する（未適用時は SKIP＝HO apply 待ち）。

printf '\n=== TA-55: c3-prime acceptance (issue #872 PR-2) ===\n'

PG_T55_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T55_VERIFY="$PG_T55_ROOT/scripts/ai-loop/c3prime_verify.py"
t55_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t55_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

if [ ! -f "$PG_T55_VERIFY" ]; then
  printf '  [FAIL] scripts/ai-loop/c3prime_verify.py が存在しない\n' >&2
  fail=$((fail + 1))
elif ! command -v python3 >/dev/null 2>&1; then
  printf '  [SKIP] python3 不在\n'
else
  # sandbox TASK dir を build_c3_prime で生成（plan_package.py を利用）
  _t55_tmp=$(mktemp -d)
  register_cleanup "$_t55_tmp"
  if python3 - "$PG_T55_ROOT" "$_t55_tmp" <<'PYEOF'
import sys, pathlib
root, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, str(pathlib.Path(root) / "scripts" / "ai-loop"))
import plan_package, test_plan_package as tpp
d = tpp._make_task_dir(tmp)  # TASK-9999
(d / "approvals").mkdir(exist_ok=True)
rec = plan_package.build_c3_prime(
    d, task_id="TASK-9999", source_sha="abc1234", target_sha="abc1234",
    verdicts={"model_a": "approve", "model_b": "approve"},
    reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
    decision="AUTO_APPROVED", policy_ref="p@v4",
    issued_at="2100-01-01T00:00:00Z", issued_by="arbiter-v0.1")
(d / "approvals" / "c3.json").write_text(plan_package.serialize_c3_prime(rec))
PYEOF
  then
    _t55_task="$_t55_tmp/TASK-9999"

    _t55_rc=0; python3 "$PG_T55_VERIFY" "$_t55_task" >/dev/null 2>&1 || _t55_rc=$?
    if [ "$_t55_rc" = "0" ]; then t55_pass "valid c3-prime → exit 0 (受理)"; else t55_fail "valid c3-prime が受理されない (rc=$_t55_rc)"; fi

    # 改竄: plan.md を 1 byte 変更 → stale で reject
    printf 'x' >> "$_t55_task/plan.md"
    _t55_rc=0; python3 "$PG_T55_VERIFY" "$_t55_task" >/dev/null 2>&1 || _t55_rc=$?
    if [ "$_t55_rc" = "1" ]; then t55_pass "plan.md 改竄 → exit 1 (stale reject)"; else t55_fail "plan.md 改竄が reject されない (rc=$_t55_rc)"; fi

    # legacy c3.json → exit 10（呼び出し側委譲）
    printf '{"task_id":"TASK-9999","phase":"C-3","c3_status":"APPROVED","approved_by":"h","approved_at":"2026-01-01T00:00:00Z","plan_hash":"sha256:%064d"}' 0 \
      > "$_t55_task/approvals/c3.json"
    _t55_rc=0; python3 "$PG_T55_VERIFY" "$_t55_task" >/dev/null 2>&1 || _t55_rc=$?
    if [ "$_t55_rc" = "10" ]; then t55_pass "legacy c3.json → exit 10 (委譲)"; else t55_fail "legacy c3.json が exit 10 にならない (rc=$_t55_rc)"; fi

    # 未知 approval_kind → exit 1
    printf '{"approval_kind":"c3-double-prime"}' > "$_t55_task/approvals/c3.json"
    _t55_rc=0; python3 "$PG_T55_VERIFY" "$_t55_task" >/dev/null 2>&1 || _t55_rc=$?
    if [ "$_t55_rc" = "1" ]; then t55_pass "未知 approval_kind → exit 1 (fail-closed)"; else t55_fail "未知 approval_kind が reject されない (rc=$_t55_rc)"; fi
  else
    t55_fail "sandbox TASK 生成に失敗（plan_package.py import 不可）"
  fi

  # HO 適用後のみ: bin/plangate 全鎖（配線が入っているときだけ）
  if grep -q '_plangate_c3_dispatch' "$PG_T55_ROOT/bin/plangate" 2>/dev/null; then
    _t55_env="$_t55_tmp/repo"
    mkdir -p "$_t55_env"
    # 別 root を偽装せず、実 bin/plangate を実 root で叩く（TASK-9999 を実 working へ
    # 置くと汚染するため、--dir でサンドボックス working を指す）
    if python3 - "$PG_T55_ROOT" "$_t55_tmp" <<'PYEOF'
import sys, pathlib
root, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, str(pathlib.Path(root) / "scripts" / "ai-loop"))
import plan_package, test_plan_package as tpp
base = pathlib.Path(tmp) / "chain"
base.mkdir(parents=True, exist_ok=True)
d = tpp._make_task_dir(str(base))  # TASK-9999
(d / "approvals").mkdir(exist_ok=True)
rec = plan_package.build_c3_prime(
    d, task_id="TASK-9999", source_sha="abc1234", target_sha="abc1234",
    verdicts={"model_a": "approve", "model_b": "approve"},
    reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
    decision="AUTO_APPROVED", policy_ref="p@v4",
    issued_at="2100-01-01T00:00:00Z", issued_by="arbiter-v0.1")
(d / "approvals" / "c3.json").write_text(plan_package.serialize_c3_prime(rec))
PYEOF
    then
      if sh "$PG_T55_ROOT/bin/plangate" validate --dir "$_t55_tmp/chain/TASK-9999" >/dev/null 2>&1; then
        t55_pass "HO 適用後: bin/plangate validate が c3-prime を受理"
      else
        t55_fail "HO 適用後: bin/plangate validate が c3-prime を受理しない"
      fi
    fi
  else
    printf '  [SKIP] bin/plangate に c3-prime 配線なし（HO apply 待ち・patches/bin-plangate.patch）\n'
  fi
fi
