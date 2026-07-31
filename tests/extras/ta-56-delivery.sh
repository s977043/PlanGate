# tests/extras/ta-56-delivery.sh
# Sourced by tests/run-tests.sh
# TASK-0873 (#873): MERGE_READY 状態機械（scripts/ai-loop/delivery.py）の E2E。
# 正本: docs/workflows/ai-loop/delivery-state-machine.md。
#
# 構成:
#   1. test_delivery.py 単体テスト（fixture 10 対応 + 偽造/欠落/冪等系）を CI 実行経路に乗せる
#   2. sandbox 実走: c3-prime AUTO_APPROVED → CHECKS_FAILED → 最小アクション実行
#      スタブ（要求 intent を読んで receipt + snapshot 更新）→ MERGE_READY（R-004）
#   3. resume 冪等: 同一 snapshot の再 assess で record 差分ゼロ（AC-10 / TC-15）
#   4. doc↔contract byte 一致（delivery-state-machine.md の契約ブロック drift 検出 / TC-12）
#   5. 純判定器ソース走査: merge 経路 + ネットワーク/プロセス実行トークン 0 件（AC-12 / R-007 / TC-18）

printf '\n=== TA-56: delivery state machine (issue #873) ===\n'

PG_T56_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T56_DELIVERY="$PG_T56_ROOT/scripts/ai-loop/delivery.py"
t56_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t56_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

if [ ! -f "$PG_T56_DELIVERY" ]; then
  printf '  [FAIL] scripts/ai-loop/delivery.py が存在しない\n' >&2
  fail=$((fail + 1))
elif ! command -v python3 >/dev/null 2>&1; then
  printf '  [SKIP] python3 不在\n'
else
  # 1. 単体テスト
  if python3 "$PG_T56_ROOT/scripts/ai-loop/test_delivery.py" >/dev/null 2>&1; then
    t56_pass "test_delivery.py 単体テスト（57 テスト・R1/R2 回帰含む）"
  else
    t56_fail "test_delivery.py 単体テスト FAIL"
  fi

  # 2〜3. sandbox 実走（repair 反復 + resume 冪等）
  _t56_tmp=$(mktemp -d)
  register_cleanup "$_t56_tmp"
  if python3 - "$PG_T56_ROOT" "$_t56_tmp" <<'PYEOF'
import json, pathlib, sys
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
h1, h2 = "a" * 40, "b" * 40
base = {
    "task_id": "TASK-9999", "pr_number": 1, "head_sha": h1,
    "source_sha_ancestry": True, "mergeable": "MERGEABLE",
    "checks": [{"name": "ci", "sha": h1, "conclusion": "failure"}],
    "review": {"state": "pending", "sha": h1},
    "findings": [], "changed_files": ["scripts/x.py"],
    "allowed_paths": ["scripts/"], "escalation_flags": [],
    "dod_evaluated": True, "ci_failure_taxonomy": "code",
}
(pathlib.Path(tmp) / "snap1.json").write_text(json.dumps(base))
green = dict(base)
green["head_sha"] = h2
green["checks"] = [{"name": "ci", "sha": h2, "conclusion": "success"}]
green["review"] = {"state": "approved", "sha": h2}
green.pop("ci_failure_taxonomy")
(pathlib.Path(tmp) / "snap2.json").write_text(json.dumps(green))
PYEOF
  then
    _t56_task="$_t56_tmp/TASK-9999"
    _t56_now="2100-01-01T00:00:00Z"

    # フェーズ 1: CI failure → CHECKS_FAILED + repair intent
    _t56_out="$_t56_tmp/out1.json"
    if python3 "$PG_T56_DELIVERY" assess --task-dir "$_t56_task" \
        --snapshot "$_t56_tmp/snap1.json" --expected-sha abc1234 --now "$_t56_now" > "$_t56_out" 2>/dev/null \
      && grep -q '"state": "CHECKS_FAILED"' "$_t56_out"; then
      t56_pass "sandbox: CI failure → CHECKS_FAILED + repair 要求"
    else
      t56_fail "sandbox: CHECKS_FAILED に遷移しない"
    fi

    # 最小アクション実行スタブ（R-004）: 要求 intent を読み、修正を実行した体で
    # receipt を刻む（実 PR/gh consumer は V2 — 実行と再評価入力の供給のみ模す）
    _t56_aid=$(python3 -c "import json,sys; print(json.load(open('$_t56_out'))['actions'][0]['action_id'])" 2>/dev/null)
    if [ -n "$_t56_aid" ] && python3 "$PG_T56_DELIVERY" receipt --task-dir "$_t56_task" \
        --action-id "$_t56_aid" --result-ref "evidence/repair-1.log" \
        --now "$_t56_now" >/dev/null 2>&1; then
      t56_pass "sandbox: 実行スタブが receipt を記録（intent → receipt）"
    else
      t56_fail "sandbox: receipt 記録に失敗"
    fi

    # フェーズ 2: 新 head 全 green → MERGE_READY（round=1 が record に残る）
    _t56_out2="$_t56_tmp/out2.json"
    if python3 "$PG_T56_DELIVERY" assess --task-dir "$_t56_task" \
        --snapshot "$_t56_tmp/snap2.json" --expected-sha abc1234 --now "$_t56_now" > "$_t56_out2" 2>/dev/null \
      && grep -q '"state": "MERGE_READY"' "$_t56_out2" \
      && grep -q '"round": 1' "$_t56_out2" \
      && grep -q '"plan_hash": "sha256:' "$_t56_out2"; then
      t56_pass "sandbox: repair 反復後 MERGE_READY（round + plan_hash 刻印）"
    else
      t56_fail "sandbox: MERGE_READY に到達しない"
    fi

    # merge_ready record が record.jsonl に残る（AC-11）
    if grep -q '"kind": "merge_ready"' "$_t56_task/delivery/record.jsonl" 2>/dev/null || \
       grep -q '"kind":"merge_ready"' "$_t56_task/delivery/record.jsonl" 2>/dev/null; then
      t56_pass "record.jsonl に merge_ready record（6 フィールド）"
    else
      t56_fail "record.jsonl に merge_ready record がない"
    fi

    # resume 冪等（AC-10）: 同一 snapshot 再 assess → record 差分ゼロ
    _t56_lines_before=$(wc -l < "$_t56_task/delivery/record.jsonl")
    python3 "$PG_T56_DELIVERY" assess --task-dir "$_t56_task" \
      --snapshot "$_t56_tmp/snap2.json" --expected-sha abc1234 --now "$_t56_now" >/dev/null 2>&1
    _t56_lines_after=$(wc -l < "$_t56_task/delivery/record.jsonl")
    if [ "$_t56_lines_before" = "$_t56_lines_after" ]; then
      t56_pass "resume 冪等: 再 assess で record 差分ゼロ"
    else
      t56_fail "resume 冪等が破れている ($_t56_lines_before → $_t56_lines_after)"
    fi

    # legacy c3.json → BLOCK（R-009: ai-loop Delivery は c3-prime 必須）
    printf '{"task_id":"TASK-9999","phase":"C-3","c3_status":"APPROVED","plan_hash":"sha256:%064d"}' 0 \
      > "$_t56_task/approvals/c3.json"
    _t56_rc=0; python3 "$PG_T56_DELIVERY" assess --task-dir "$_t56_task" \
      --snapshot "$_t56_tmp/snap2.json" --expected-sha abc1234 --now "$_t56_now" >/dev/null 2>&1 || _t56_rc=$?
    if [ "$_t56_rc" = "3" ]; then
      t56_pass "legacy c3.json → exit 3 (BLOCK)"
    else
      t56_fail "legacy c3.json が BLOCK されない (rc=$_t56_rc)"
    fi
  else
    t56_fail "sandbox TASK 生成に失敗（plan_package.py import 不可）"
  fi

  # 4. doc↔contract byte 一致（TC-12）
  _t56_doc="$PG_T56_ROOT/docs/workflows/ai-loop/delivery-state-machine.md"
  _t56_emit="$_t56_tmp/contract.json"
  _t56_docblock="$_t56_tmp/docblock.json"
  python3 "$PG_T56_DELIVERY" contract > "$_t56_emit" 2>/dev/null
  sed -n '/<!-- contract:begin -->/,/<!-- contract:end -->/p' "$_t56_doc" \
    | sed '1d;$d' | sed '1d;$d' > "$_t56_docblock"
  if cmp -s "$_t56_emit" "$_t56_docblock"; then
    t56_pass "doc↔contract byte 一致（drift なし）"
  else
    t56_fail "delivery-state-machine.md の契約ブロックが contract emit と不一致（drift）"
  fi

  # 5. 純判定器ソース走査（AC-12 / R-007）。check-delegation-commit-boundary.sh 様式
  _t56_viol=""
  for _t56_tok in 'gh pr merge' 'merge_pull_request' 'subprocess' 'os.system' \
                  'urllib' 'socket' 'http.client' 'requests'; do
    if grep -q "$_t56_tok" "$PG_T56_DELIVERY" 2>/dev/null; then
      _t56_viol="$_t56_viol $_t56_tok"
    fi
  done
  if [ -z "$_t56_viol" ]; then
    t56_pass "純判定器ソース走査: 禁止トークン 0 件（merge 経路 / ネットワーク / プロセス実行）"
  else
    t56_fail "delivery.py に禁止トークン:$_t56_viol"
  fi

  # MERGED 遷移の不在（AC-12 二重ガード）
  if python3 "$PG_T56_DELIVERY" contract 2>/dev/null | grep -q '"MERGED"'; then
    t56_fail "contract に MERGED が含まれる（NO MERGE BY AI 違反）"
  else
    t56_pass "contract に MERGED 遷移なし（NO MERGE BY AI）"
  fi
fi
