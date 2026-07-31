# tests/extras/ta-57-pr-convergence.sh
# Sourced by tests/run-tests.sh
# TASK-0917 (#917): 実 PR 収束レーン（Collector / Executor / Reconciler）の E2E。
# 正本: docs/working/TASK-0917/plan.md Work Breakdown Step 8 / test-cases.md TC-10。
#
# 構成:
#   1. 新規 unit test の実行導線（R-020）— `tests/run-tests.sh` は python を一切
#      呼ばず `ta-*.sh` を glob source するだけであり、`test_plan_package.py` は
#      ta-55 / ta-56 から fixture helper として import されるだけで**本体は一度も
#      実行されない**。したがって 7 モジュールを 1 モジュール 1 PASS 行で起動する。
#      判定は exit 0 だけに依存させず **`OK` と実行件数（Ran N tests）** を確認し、
#      件数 0 を PASS にしない（内部 FAIL が exit code に出ない経路を塞ぐ）
#   2. 実行系境界検査（`check_exec_boundary.py` が clean / exit 0）
#   3. fixture E2E 1 周（TC-10）: Collector → `delivery.assess()` → Executor →
#      `delivery.py receipt` → Reconciler を CI 失敗 → repair → 最新 head 再評価
#      → MERGE_READY まで通す。`delivery.py` は実物を呼び、`gh_exec` は fake へ
#      差し替えて**実ネットワーク / 実プロセス起動に一切到達しない**
#   4. AC-7 の 3 点再確認（3 ファイル 0 行差分 / 57 テスト OK / contract byte 一致）
#
# 隔離・後片付け（tests/extras/README.md §隔離・後始末の規約）:
#   trap は張らない（source 連鎖で上書きされ発火が保証されないため）。
#   `register_cleanup` 登録 + **末尾の明示 rm -rf** の二重で sandbox を回収する。

printf '\n=== TA-57: PR convergence lane (issue #917) ===\n'

PG_T57_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T57_AILOOP="$PG_T57_ROOT/scripts/ai-loop"
t57_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t57_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

if ! command -v python3 >/dev/null 2>&1; then
  printf '  [SKIP] python3 不在\n'
else
  _t57_tmp=$(mktemp -d)
  register_cleanup "$_t57_tmp"

  # ── 1. 新規 unit test の実行導線（R-020 / 1 モジュール 1 PASS 行）──────────
  # exit 0 のみを条件にしない: `OK` の存在と `Ran N tests` の N >= 1 を併せて要求する。
  _t57_unit() {
    _t57_mod="$1"
    _t57_path="$PG_T57_AILOOP/$_t57_mod"
    if [ ! -f "$_t57_path" ]; then
      t57_fail "unit: $_t57_mod が存在しない"
      return 0
    fi
    _t57_log="$_t57_tmp/unit-$_t57_mod.log"
    _t57_rc=0
    python3 "$_t57_path" >"$_t57_log" 2>&1 || _t57_rc=$?
    # unittest は "Ran N tests in Xs" / "Ran 1 test in Xs" の 2 形を出す
    _t57_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t57_log" | head -1)
    [ -n "$_t57_n" ] || _t57_n=0
    if [ "$_t57_rc" -eq 0 ] && grep -q '^OK' "$_t57_log" && [ "$_t57_n" -gt 0 ]; then
      t57_pass "unit: ${_t57_mod}（Ran ${_t57_n} tests / OK）"
    else
      t57_fail "unit: ${_t57_mod}（rc=${_t57_rc} / ran=${_t57_n} / OK 行なし）"
    fi
  }

  _t57_unit test_gh_exec.py
  _t57_unit test_check_exec_boundary.py
  _t57_unit test_collector.py
  _t57_unit test_ci_taxonomy.py
  _t57_unit test_executor.py
  _t57_unit test_reconciler.py
  _t57_unit test_plan_package.py

  # ── 2. 実行系境界検査（AC-5）────────────────────────────────────────────
  _t57_bnd="$_t57_tmp/boundary.log"
  _t57_rc=0
  python3 "$PG_T57_AILOOP/check_exec_boundary.py" >"$_t57_bnd" 2>&1 || _t57_rc=$?
  if [ "$_t57_rc" -eq 0 ] && grep -q 'clean' "$_t57_bnd"; then
    t57_pass "check_exec_boundary.py: clean / exit 0（$(head -1 "$_t57_bnd")）"
  else
    t57_fail "check_exec_boundary.py が clean でない (rc=$_t57_rc): $(head -1 "$_t57_bnd")"
  fi

  # ── 3. fixture E2E 1 周（TC-10）────────────────────────────────────────
  # sandbox 内で c3-prime を発行し、Collector → assess → Executor → receipt →
  # Reconciler を 3 ラウンド回す。結果は key=value の 1 行 1 事実で受け取る。
  _t57_e2e="$_t57_tmp/e2e.out"
  _t57_e2e_err="$_t57_tmp/e2e.err"
  _t57_rc=0
  python3 - "$PG_T57_ROOT" "$_t57_tmp/e2e" >"$_t57_e2e" 2>"$_t57_e2e_err" <<'PYEOF' || _t57_rc=$?
import io
import json
import pathlib
import sys
from contextlib import redirect_stdout, redirect_stderr

ROOT, TMP = sys.argv[1], sys.argv[2]
pathlib.Path(TMP).mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(pathlib.Path(ROOT) / "scripts" / "ai-loop"))

import collector                  # noqa: E402
import delivery                   # noqa: E402  判定エンジンの実物（AC-7: 変更しない）
import executor                   # noqa: E402
import reconciler                 # noqa: E402
import gh_exec                    # noqa: E402
import plan_package               # noqa: E402
import test_plan_package as tpp   # noqa: E402  sandbox Plan Package 生成の再利用

REPO = "s977043/plangate"
PR = 9999
TASK = "TASK-9999"
BRANCH = "feat/task-9999-sandbox"
SRC = "abc1234"
H1 = "1" * 40   # 承認時の head（CI 失敗）
H2 = "2" * 40   # repair 後の head（全 green）
NOW = "2100-01-01T00:00:00Z"

OUT = []


def emit(key, value):
    OUT.append("%s=%s" % (key, value))


class _NoProcess:
    """`gh_exec` の唯一の subprocess 呼び出し地点を封じる（実ネットワーク不到達）。"""

    calls = 0

    @staticmethod
    def run(*args, **kwargs):
        _NoProcess.calls += 1
        raise AssertionError("real subprocess.run が呼ばれた: %r" % (args,))


gh_exec.subprocess = _NoProcess


class FakeProc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class FakePush:
    def __init__(self):
        self.pushed = True
        self.argv = ("git", "push")
        self.result = FakeProc(0, "")


class FakeGh:
    """Collector / Executor 双方の I/O 注入点を 1 つで賄う fixture。"""

    Denied = gh_exec.Denied

    def __init__(self, *, head_sha, checks, reviews, contexts=("ci",),
                 changed=("scripts/ai-loop/sandbox_a.py",), mergeable=True,
                 ancestry_rc=0, pr_head=None):
        self.head_sha = head_sha
        self.checks = list(checks)
        self.reviews = list(reviews)
        self.contexts = tuple(contexts)
        self.changed = tuple(changed)
        self.mergeable = mergeable
        self.ancestry_rc = ancestry_rc
        self.pr_head = pr_head or head_sha
        self.gh_calls = []
        self.git_calls = []
        self.comment_calls = []
        self.push_calls = []

    # --- 読み取り系 -----------------------------------------------------
    def run_gh(self, args, *, repo=None, cwd=None):
        args = list(args)
        self.gh_calls.append(tuple(args))
        if args[:1] == ["api"]:
            endpoint = args[1] if len(args) > 1 else ""
            if "/check-runs" in endpoint:
                return FakeProc(0, json.dumps(
                    {"total_count": len(self.checks), "check_runs": self.checks}))
            if "/reviews" in endpoint:
                return FakeProc(0, json.dumps(self.reviews))
            if "/rules/branches/" in endpoint:
                return FakeProc(0, json.dumps([{
                    "type": "required_status_checks",
                    "parameters": {"required_status_checks":
                                   [{"context": c} for c in self.contexts]},
                }]))
            return FakeProc(0, json.dumps(
                {"number": PR, "mergeable": self.mergeable,
                 "head": {"sha": self.head_sha}, "base": {"ref": "main"}}))
        if args[:2] == ["pr", "view"]:
            return FakeProc(0, json.dumps({"headRefOid": self.pr_head,
                                           "headRefName": BRANCH,
                                           "baseRefName": "main"}))
        raise AssertionError("fixture 未定義の gh 呼び出し: %r" % (args,))

    def run_git(self, args, *, cwd=None):
        args = list(args)
        self.git_calls.append(tuple(args))
        if args[:1] == ["diff"]:
            return FakeProc(0, "".join(p + "\n" for p in self.changed))
        if args[:2] == ["merge-base", "--is-ancestor"]:
            return FakeProc(self.ancestry_rc, "")
        raise AssertionError("fixture 未定義の git 呼び出し: %r" % (args,))

    # --- 書き込み系（fixture 上でのみ成立。実 PR には出ない）-------------
    def comment_pr(self, *, repo, pr_number, body, cwd=None):
        self.comment_calls.append({"pr": pr_number, "body": body})
        return FakeProc(0, "https://github.com/%s/pull/%d#issuecomment-1\n"
                        % (repo, pr_number))

    def push_pr_head(self, *, repo, branch, expected_parent_sha, cwd=None):
        self.push_calls.append({"branch": branch,
                                "expected_parent_sha": expected_parent_sha})
        return FakePush()

    @property
    def write_calls(self):
        return len(self.comment_calls) + len(self.push_calls)


def check_run(name, sha, conclusion, status="completed"):
    return {"id": abs(hash((name, sha, conclusion))) % 10 ** 7, "name": name,
            "head_sha": sha, "status": status, "conclusion": conclusion,
            "completed_at": "2100-01-01T00:00:00Z"}


def review(state, sha):
    return {"id": 1, "state": state, "commit_id": sha,
            "submitted_at": "2100-01-01T00:00:00Z"}


# --- Plan Package 6 要素 + c3-prime（sandbox）----------------------------
task_dir = tpp._make_task_dir(TMP)
(task_dir / "approvals").mkdir(exist_ok=True)
c3 = plan_package.build_c3_prime(
    task_dir, task_id=TASK, source_sha=SRC, target_sha=SRC,
    verdicts={"model_a": "approve", "model_b": "approve"},
    reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
    decision="AUTO_APPROVED", policy_ref="p@v4",
    issued_at=NOW, issued_by="arbiter-v0.1")
(task_dir / "approvals" / "c3.json").write_text(
    plan_package.serialize_c3_prime(c3), encoding="utf-8")
PLAN_TEXT = (task_dir / "plan.md").read_text(encoding="utf-8")
RECORD = delivery.record_path(task_dir)

FAKES = []


def collect(fake, *, ci_log_text=""):
    FAKES.append(fake)
    return collector.collect(
        task_id=TASK, repo=REPO, pr_number=PR, source_sha=SRC,
        plan_text=PLAN_TEXT, record_path=RECORD, ci_log_text=ci_log_text,
        gh=fake)


def assess_cli(snapshot, tag):
    """`delivery.py assess` を**実物のまま** in-process で呼ぶ（subprocess を使わない）。"""
    path = pathlib.Path(TMP) / ("snapshot-%s.json" % tag)
    path.write_text(json.dumps(snapshot, indent=2, sort_keys=True), encoding="utf-8")
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        rc = delivery.main(["delivery.py", "assess", "--task-dir", str(task_dir),
                            "--snapshot", str(path), "--now", NOW,
                            "--expected-sha", SRC])
    if rc != 0:
        raise AssertionError("assess rc=%s stderr=%s" % (rc, err.getvalue()))
    return json.loads(out.getvalue())


def record_lines():
    if not RECORD.exists():
        return 0
    return len(RECORD.read_text(encoding="utf-8").splitlines())


# --- Round 1: CI failure → CHECKS_FAILED → repair_ci ---------------------
fake1 = FakeGh(head_sha=H1, checks=[check_run("ci", H1, "failure")],
               reviews=[review("APPROVED", H1)])
snap1 = collect(fake1, ci_log_text="curl: API rate limit exceeded for runner")
emit("snap1_head", snap1["head_sha"])
emit("snap1_checks_bound", int(bool(snap1["checks"])
                               and all(c["sha"] == H1 for c in snap1["checks"])))
emit("snap1_review_sha", snap1["review"]["sha"])
emit("snap1_raw_evidence", len(snap1.get(collector.RAW_CHECK_RUNS_KEY) or []))
emit("snap1_required", ",".join(snap1.get(collector.REQUIRED_CHECKS_KEY) or []))
emit("snap1_taxonomy", snap1.get("ci_failure_taxonomy"))
emit("snap1_flags", len(snap1["escalation_flags"]))
emit("snap1_valid", int(delivery.validate_snapshot(snap1) == []))

r1 = assess_cli(snap1, "1")
emit("round1_state", r1["state"])
emit("round1_actions", ",".join(sorted(a["action_kind"] for a in r1["actions"])))

ctx1 = executor.ExecContext(repo=REPO, branch=BRANCH, task_dir=task_dir, now=NOW,
                            gh=fake1, repair_commit_sha=H2)
rep1 = executor.execute_actions(r1["actions"], ctx1)
emit("exec1_statuses", ",".join(o.status for o in rep1.outcomes))
emit("exec1_comments", len(fake1.comment_calls))
emit("exec1_pushes", len(fake1.push_calls))
emit("exec1_flags", len(rep1.escalation_flags))
emit("exec1_adopted", int(rep1.outcomes[0].result_ref.startswith("adopted:%s" % H2)
                          if rep1.outcomes else 0))

rc1 = reconciler.reconcile(task_dir, pr_number=PR)
emit("recon1_intents", len(rc1.intents))
emit("recon1_receipts", len(rc1.receipts))
emit("recon1_pending", len(rc1.pending))

# --- Round 2: 最新 head 再評価 → MERGE_READY_CANDIDATE -------------------
fake2 = FakeGh(head_sha=H2, checks=[check_run("ci", H2, "success")],
               reviews=[review("APPROVED", H2)])
snap2 = collect(fake2)
emit("snap2_head", snap2["head_sha"])
emit("snap2_dod", int(snap2["dod_evaluated"]))
r2 = assess_cli(snap2, "2")
emit("round2_state", r2["state"])
emit("round2_actions", ",".join(sorted(a["action_kind"] for a in r2["actions"])))

ctx2 = executor.ExecContext(repo=REPO, branch=BRANCH, task_dir=task_dir, now=NOW,
                            gh=fake2, repair_commit_sha=H2)
rep2 = executor.execute_actions(r2["actions"], ctx2)
emit("exec2_statuses", ",".join(o.status for o in rep2.outcomes))
emit("exec2_writes", fake2.write_calls)

# --- Round 3: DoD 充足 → MERGE_READY ------------------------------------
fake3 = FakeGh(head_sha=H2, checks=[check_run("ci", H2, "success")],
               reviews=[review("APPROVED", H2)])
snap3 = collect(fake3)
emit("snap3_dod", int(snap3["dod_evaluated"]))
r3 = assess_cli(snap3, "3")
emit("round3_state", r3["state"])
_record = r3.get("record") or {}
emit("round3_round", _record.get("round"))
emit("round3_plan_hash", int(str(_record.get("plan_hash") or "").startswith("sha256:")))
_body = RECORD.read_text(encoding="utf-8")
emit("merge_ready_entry", int('"kind": "merge_ready"' in _body
                              or '"kind":"merge_ready"' in _body))

# --- resume 冪等: 同一 snapshot 再 assess → record 差分ゼロ --------------
_before = record_lines()
r3b = assess_cli(snap3, "3")
_after = record_lines()
emit("resume_state", r3b["state"])
emit("resume_delta", _after - _before)

# --- 外部作用の実測（実ネットワーク / 実プロセス起動に到達しない）--------
emit("real_subprocess_calls", _NoProcess.calls)
emit("fake_gh_calls", sum(len(f.gh_calls) for f in FAKES))
emit("fake_write_calls", sum(f.write_calls for f in FAKES))

rc3 = reconciler.reconcile(task_dir, pr_number=PR)
emit("recon3_pending", len(rc3.pending))

print("\n".join(OUT))
PYEOF

  _t57_kv() { sed -n "s/^$1=//p" "$_t57_e2e" | head -1; }

  if [ "$_t57_rc" -ne 0 ]; then
    t57_fail "E2E fixture 実走が失敗 (rc=$_t57_rc): $(tail -3 "$_t57_e2e_err" | tr '\n' ' ')"
  else
    # (1) Collector: head SHA 束縛 + raw evidence 同梱 + required_checks（AC-1/2/9）
    if [ "$(_t57_kv snap1_checks_bound)" = "1" ] \
      && [ "$(_t57_kv snap1_review_sha)" = "$(_t57_kv snap1_head)" ] \
      && [ "$(_t57_kv snap1_raw_evidence)" -gt 0 ] \
      && [ "$(_t57_kv snap1_required)" = "ci" ] \
      && [ "$(_t57_kv snap1_flags)" = "0" ] \
      && [ "$(_t57_kv snap1_valid)" = "1" ]; then
      t57_pass "E2E: Collector が head SHA 束縛 snapshot を生成（raw evidence / required_checks 同梱・flags 0）"
    else
      t57_fail "E2E: Collector snapshot が期待どおりでない（$(_t57_kv snap1_flags) flags / valid=$(_t57_kv snap1_valid)）"
    fi

    # (2) round1: CI 失敗 → CHECKS_FAILED + repair_ci
    if [ "$(_t57_kv round1_state)" = "CHECKS_FAILED" ] \
      && [ "$(_t57_kv round1_actions)" = "repair_ci" ] \
      && [ "$(_t57_kv snap1_taxonomy)" = "environment" ]; then
      t57_pass "E2E: CI 失敗 → CHECKS_FAILED + repair_ci 要求（taxonomy は ci_taxonomy.py 供給）"
    else
      t57_fail "E2E: round1 が CHECKS_FAILED/repair_ci にならない（state=$(_t57_kv round1_state) actions=$(_t57_kv round1_actions)）"
    fi

    # (3) Executor: 通知コメント → repair push → receipt
    if [ "$(_t57_kv exec1_statuses)" = "executed" ] \
      && [ "$(_t57_kv exec1_comments)" = "1" ] \
      && [ "$(_t57_kv exec1_pushes)" = "1" ] \
      && [ "$(_t57_kv exec1_flags)" = "0" ] \
      && [ "$(_t57_kv exec1_adopted)" = "1" ]; then
      t57_pass "E2E: Executor が repair を実行（通知コメント 1 → push 1 → receipt / result_ref に adopted）"
    else
      t57_fail "E2E: Executor の実行結果が期待外（status=$(_t57_kv exec1_statuses) comments=$(_t57_kv exec1_comments) pushes=$(_t57_kv exec1_pushes)）"
    fi

    # (4) Reconciler: intent ↔ receipt 突合
    if [ "$(_t57_kv recon1_intents)" = "1" ] \
      && [ "$(_t57_kv recon1_receipts)" = "1" ] \
      && [ "$(_t57_kv recon1_pending)" = "0" ]; then
      t57_pass "E2E: Reconciler が intent↔receipt を突合（pending 0）"
    else
      t57_fail "E2E: Reconciler の突合が不成立（intents=$(_t57_kv recon1_intents) receipts=$(_t57_kv recon1_receipts) pending=$(_t57_kv recon1_pending)）"
    fi

    # (5) round2: 最新 head で再評価 → MERGE_READY_CANDIDATE
    if [ "$(_t57_kv snap2_head)" != "$(_t57_kv snap1_head)" ] \
      && [ "$(_t57_kv round2_state)" = "MERGE_READY_CANDIDATE" ] \
      && [ "$(_t57_kv round2_actions)" = "dod_reevaluate" ] \
      && [ "$(_t57_kv snap2_dod)" = "0" ]; then
      t57_pass "E2E: repair 後の最新 head で再評価 → MERGE_READY_CANDIDATE（終端に短絡しない）"
    else
      t57_fail "E2E: round2 が MERGE_READY_CANDIDATE にならない（state=$(_t57_kv round2_state)）"
    fi

    # (6) round2 Executor: dod_reevaluate は外部書き込みゼロで receipt
    if [ "$(_t57_kv exec2_statuses)" = "executed" ] \
      && [ "$(_t57_kv exec2_writes)" = "0" ]; then
      t57_pass "E2E: dod_reevaluate は外部書き込み 0 件で receipt（不要な PR 作用を出さない）"
    else
      t57_fail "E2E: dod_reevaluate の実行が期待外（status=$(_t57_kv exec2_statuses) writes=$(_t57_kv exec2_writes)）"
    fi

    # (7) round3: MERGE_READY 到達
    if [ "$(_t57_kv snap3_dod)" = "1" ] \
      && [ "$(_t57_kv round3_state)" = "MERGE_READY" ] \
      && [ "$(_t57_kv round3_round)" = "1" ] \
      && [ "$(_t57_kv round3_plan_hash)" = "1" ]; then
      t57_pass "E2E: repair 反復後 MERGE_READY に到達（round 1 + plan_hash 刻印）"
    else
      t57_fail "E2E: MERGE_READY に到達しない（state=$(_t57_kv round3_state) round=$(_t57_kv round3_round)）"
    fi

    # (8) merge_ready record が record.jsonl に残る
    if [ "$(_t57_kv merge_ready_entry)" = "1" ] \
      && [ "$(_t57_kv recon3_pending)" = "0" ]; then
      t57_pass "E2E: record.jsonl に merge_ready record（未 receipt の intent 0）"
    else
      t57_fail "E2E: merge_ready record / pending intent が期待外"
    fi

    # (9) resume 冪等
    if [ "$(_t57_kv resume_state)" = "MERGE_READY" ] \
      && [ "$(_t57_kv resume_delta)" = "0" ]; then
      t57_pass "E2E: resume 冪等（同一 snapshot 再 assess で record 差分ゼロ）"
    else
      t57_fail "E2E: resume 冪等が破れている（delta=$(_t57_kv resume_delta)）"
    fi

    # (10) 実ネットワーク / 実プロセス起動に到達しない
    if [ "$(_t57_kv real_subprocess_calls)" = "0" ] \
      && [ "$(_t57_kv fake_gh_calls)" -gt 0 ] \
      && [ "$(_t57_kv fake_write_calls)" -gt 0 ]; then
      t57_pass "E2E: 実 subprocess 起動 0 件（gh 呼び出しは fixture $(_t57_kv fake_gh_calls) 件のみ = 実ネットワーク不到達）"
    else
      t57_fail "E2E: 実行系境界が破れている（real_subprocess=$(_t57_kv real_subprocess_calls)）"
    fi
  fi

  # ── 4. AC-7: delivery.py / c3_contract.py / c3prime_verify.py が不変 ────
  _t57_ac7_files="scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py"

  # (a) main との差分 0 行（base ref が無い CI checkout では SKIP）
  _t57_base=""
  for _t57_ref in origin/main main; do
    if git -C "$PG_T57_ROOT" rev-parse --verify --quiet "$_t57_ref" >/dev/null 2>&1; then
      _t57_base="$_t57_ref"
      break
    fi
  done
  if [ -z "$_t57_base" ]; then
    printf '  [SKIP] AC-7 差分検査: base ref (origin/main / main) が無い checkout\n'
  else
    _t57_rc=0
    # shellcheck disable=SC2086
    _t57_diff=$(git -C "$PG_T57_ROOT" diff --stat "$_t57_base" -- $_t57_ac7_files 2>&1) || _t57_rc=$?
    if [ "$_t57_rc" -eq 0 ] && [ -z "$_t57_diff" ]; then
      t57_pass "AC-7: delivery.py / c3_contract.py / c3prime_verify.py が $_t57_base から 0 行差分"
    else
      t57_fail "AC-7: 判定エンジン 3 ファイルに差分がある (rc=$_t57_rc): $_t57_diff"
    fi
  fi

  # (b) test_delivery.py が 57 tests で OK（件数も条件に入れる）
  _t57_log="$_t57_tmp/test_delivery.log"
  _t57_rc=0
  python3 "$PG_T57_AILOOP/test_delivery.py" >"$_t57_log" 2>&1 || _t57_rc=$?
  _t57_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t57_log" | head -1)
  [ -n "$_t57_n" ] || _t57_n=0
  if [ "$_t57_rc" -eq 0 ] && grep -q '^OK' "$_t57_log" && [ "$_t57_n" -eq 57 ]; then
    t57_pass "AC-7: test_delivery.py（Ran 57 tests / OK）"
  else
    t57_fail "AC-7: test_delivery.py が 57 tests OK でない（rc=${_t57_rc} / ran=${_t57_n}）"
  fi

  # (c) doc ↔ contract の byte 一致（ta-56 と同一方式）
  _t57_doc="$PG_T57_ROOT/docs/workflows/ai-loop/delivery-state-machine.md"
  _t57_emit="$_t57_tmp/contract.json"
  _t57_docblock="$_t57_tmp/docblock.json"
  python3 "$PG_T57_AILOOP/delivery.py" contract > "$_t57_emit" 2>/dev/null
  sed -n '/<!-- contract:begin -->/,/<!-- contract:end -->/p' "$_t57_doc" \
    | sed '1d;$d' | sed '1d;$d' > "$_t57_docblock"
  if cmp -s "$_t57_emit" "$_t57_docblock"; then
    t57_pass "AC-7: delivery-state-machine.md の contract ブロックが byte 一致（drift なし）"
  else
    t57_fail "AC-7: contract ブロックが emit と不一致（drift）"
  fi

  # ── 後片付け（trap 非依存 / register_cleanup と二重化）──────────────────
  rm -rf "$_t57_tmp"
  unset _t57_tmp _t57_e2e _t57_e2e_err _t57_log _t57_bnd _t57_n _t57_rc \
        _t57_base _t57_ref _t57_diff _t57_doc _t57_emit _t57_docblock \
        _t57_ac7_files _t57_mod _t57_path 2>/dev/null || true
fi
