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
#      差し替えて**実ネットワーク / 実プロセス起動に一切到達しない**。
#      加えて (11)(12) で **失敗経路**も 1 本通す（R2 B2-1 / B2-3）:
#      rc≠0 の repair push は receipt されず、Executor が積んだ理由コードと
#      orphan receipt が次 run の snapshot へ合流して `HUMAN_ESCALATED` に至る
#      （`apply_escalation_flags` / `escalation_flags` / `filter_unexecuted` /
#      `safe_reconcile` の**非テスト呼び出し元**をここで確保する）
#   4. AC-7 の 3 点再確認（TC-14 3 ファイル 0 行差分 / TC-15 57 テスト OK /
#      TC-16 contract byte 一致）。TC-14 は base ref を要するため、無い環境では
#      **[WARN] で「3 点中 2 点しか検証されていない」ことを明示**する（無音 SKIP
#      にしない / R2 B2-2）
#   5. TC-E8: `sync-plugin-plangate.sh` の for ループ側と case 側の basename
#      集合が一致すること（片方漏れは `git diff --quiet plugin/` では検出されない）
#   6. TC-E9: その allowlist が `scripts/ai-loop/` の **実体**を網羅すること
#      （両方に載っていないファイルは TC-E8 をすり抜け、導入先だけ壊れる / #1173）
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
    """`gh_exec.PushResult` 互換。`pushed` は **push が成功したか**（R2 B2-1）。"""

    def __init__(self, rc=0):
        self.pushed = rc == 0
        self.argv = ("git", "push")
        self.result = FakeProc(rc, "")


class FakeGh:
    """Collector / Executor 双方の I/O 注入点を 1 つで賄う fixture。"""

    Denied = gh_exec.Denied

    def __init__(self, *, head_sha, checks, reviews, contexts=("ci",),
                 changed=("scripts/ai-loop/sandbox_a.py",), mergeable=True,
                 ancestry_rc=0, pr_head=None, push_rc=0):
        self.head_sha = head_sha
        self.checks = list(checks)
        self.reviews = list(reviews)
        self.contexts = tuple(contexts)
        self.changed = tuple(changed)
        self.mergeable = mergeable
        self.ancestry_rc = ancestry_rc
        self.pr_head = pr_head or head_sha
        self.push_rc = push_rc
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
        return FakePush(self.push_rc)

    @property
    def write_calls(self):
        return len(self.comment_calls) + len(self.push_calls)


def check_run(name, sha, conclusion, status="completed"):
    return {"id": abs(hash((name, sha, conclusion))) % 10 ** 7, "name": name,
            "head_sha": sha, "status": status, "conclusion": conclusion,
            "completed_at": "2100-01-01T00:00:00Z"}


def review(state, sha, association="MEMBER", login="human"):
    """R1 B-7: `reduce_review()` は権限不明の APPROVED を候補にしない。"""
    return {"id": 1, "state": state, "commit_id": sha,
            "submitted_at": "2100-01-01T00:00:00Z",
            "user": {"login": login}, "author_association": association}


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


def collect(fake, *, ci_log_text="", findings=(), record_path=None):
    """`findings` は**明示供給**する（未供給は `findings_unavailable` / R1 B-4）。"""
    FAKES.append(fake)
    return collector.collect(
        task_id=TASK, repo=REPO, pr_number=PR, source_sha=SRC,
        plan_text=PLAN_TEXT, record_path=record_path or RECORD,
        ci_log_text=ci_log_text, findings=list(findings), gh=fake)


def assess_cli(snapshot, tag, target_dir=None):
    """`delivery.py assess` を**実物のまま** in-process で呼ぶ（subprocess を使わない）。"""
    path = pathlib.Path(TMP) / ("snapshot-%s.json" % tag)
    path.write_text(json.dumps(snapshot, indent=2, sort_keys=True), encoding="utf-8")
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        rc = delivery.main(["delivery.py", "assess",
                            "--task-dir", str(target_dir or task_dir),
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

# R1 B-1: `dod_reevaluate` は実測根拠（evidence_ref）を必須入力にした。
ctx2 = executor.ExecContext(repo=REPO, branch=BRANCH, task_dir=task_dir, now=NOW,
                            gh=fake2, repair_commit_sha=H2,
                            evidence_ref="docs/working/%s/evidence/dod.md" % TASK)
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

# --- AC-6 Executor 側の実証（R2 B2-3）------------------------------------
# 「算出されるが誰も消費しない値」を作らないための **非テスト呼び出し元**を
# ここで 1 本通す: `reconciler.filter_unexecuted()` / `safe_reconcile()` /
# `escalation_flags()`（orphan 昇格）/ `executor.apply_escalation_flags()`。
# 実証する事実 = 「**Executor が積んだ**理由コードが次 run の snapshot へ合流し
# `HUMAN_ESCALATED` に到達する」（AC-6 は Collector 側の素通しだけでは
# 半分しか固定されない）。
ESC_ROOT = str(pathlib.Path(TMP) / "esc")
esc_dir = tpp._make_task_dir(ESC_ROOT)
(esc_dir / "approvals").mkdir(exist_ok=True)
esc_c3 = plan_package.build_c3_prime(
    esc_dir, task_id=TASK, source_sha=SRC, target_sha=SRC,
    verdicts={"model_a": "approve", "model_b": "approve"},
    reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
    decision="AUTO_APPROVED", policy_ref="p@v4",
    issued_at=NOW, issued_by="arbiter-v0.1")
(esc_dir / "approvals" / "c3.json").write_text(
    plan_package.serialize_c3_prime(esc_c3), encoding="utf-8")
ESC_RECORD = delivery.record_path(esc_dir)

# (a) CI 失敗 → repair_ci。push は **rc≠0 で失敗**（B2-1 の rc 検査が効くこと）
fake_e1 = FakeGh(head_sha=H1, checks=[check_run("ci", H1, "failure")],
                 reviews=[review("APPROVED", H1)], push_rc=1)
snap_e1 = collect(fake_e1, ci_log_text="curl: API rate limit exceeded for runner",
                  record_path=ESC_RECORD)
esc_r1 = assess_cli(snap_e1, "e1", esc_dir)
emit("esc_round1_actions", ",".join(sorted(a["action_kind"] for a in esc_r1["actions"])))
esc_pending = reconciler.filter_unexecuted(
    esc_r1["actions"], delivery.load_entries(ESC_RECORD))
emit("esc_pending_actions", len(esc_pending))
esc_ctx = executor.ExecContext(repo=REPO, branch=BRANCH, task_dir=esc_dir, now=NOW,
                               gh=fake_e1, repair_commit_sha=H2)
esc_rep = executor.execute_actions(esc_pending, esc_ctx)
emit("esc_exec_statuses", ",".join(o.status for o in esc_rep.outcomes))
emit("esc_push_failed_flag",
     int(any(f.startswith(executor.FLAG_PUSH_FAILED)
             for f in esc_rep.escalation_flags)))
emit("esc_receipts_after_failed_push",
     len([e for e in delivery.load_entries(ESC_RECORD)
          if e.get("kind") == "receipt"]))

# (b) 記録なき実行（intent の無い receipt）も同じ 1 点へ合流させる
delivery.append_entries(ESC_RECORD, [{
    "kind": "receipt", "action_id": "sha256:orphan", "action_kind": "repair_ci",
    "pr_number": PR, "head_sha": H1, "round": 1,
    "result_ref": "adopted:%s" % H2}], NOW)
esc_recon, esc_recon_err = reconciler.safe_reconcile(esc_dir, pr_number=PR)
emit("esc_recon_ok", int(esc_recon_err is None))
emit("esc_orphans", len(esc_recon.orphan_receipts))

# (c) 次 run の snapshot へ合流 → HUMAN_ESCALATED（合流前は終端でないこと）
fake_e2 = FakeGh(head_sha=H2, checks=[check_run("ci", H2, "success")],
                 reviews=[review("APPROVED", H2)])
snap_e2 = collect(fake_e2, record_path=ESC_RECORD)
emit("esc_snap2_flags", len(snap_e2["escalation_flags"]))
emit("esc_before_state", assess_cli(snap_e2, "e2", esc_dir)["state"])
esc_merged = executor.apply_escalation_flags(
    snap_e2, list(esc_rep.escalation_flags) + list(
        reconciler.escalation_flags(esc_recon)))
emit("esc_merged_flags", len(esc_merged["escalation_flags"]))
esc_after = assess_cli(esc_merged, "e3", esc_dir)
emit("esc_after_state", esc_after["state"])
emit("esc_reason_carries_executor_flag",
     int(any(executor.FLAG_PUSH_FAILED in str(r)
             for r in esc_after.get("reasons") or [])))
emit("esc_reason_carries_orphan",
     int(any(reconciler.FLAG_ORPHAN_RECEIPT in str(r)
             for r in esc_after.get("reasons") or [])))

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

    # (11) rc≠0 の push は成功扱いにならない（R2 B2-1 / 不可逆作用の失敗検査）
    if [ "$(_t57_kv esc_pending_actions)" = "1" ] \
      && [ "$(_t57_kv esc_exec_statuses)" = "failed" ] \
      && [ "$(_t57_kv esc_push_failed_flag)" = "1" ] \
      && [ "$(_t57_kv esc_receipts_after_failed_push)" = "0" ]; then
      t57_pass "E2E: rc≠0 の repair push は failed 扱い（receipt 0 件 = 次 run で同一 intent が再要求される）"
    else
      t57_fail "E2E: push 失敗が成功として receipt された（status=$(_t57_kv esc_exec_statuses) receipts=$(_t57_kv esc_receipts_after_failed_push)）"
    fi

    # (12) AC-6 Executor 側: 積んだ理由コードが次 run snapshot 経由で HUMAN_ESCALATED へ
    if [ "$(_t57_kv esc_recon_ok)" = "1" ] \
      && [ "$(_t57_kv esc_orphans)" = "1" ] \
      && [ "$(_t57_kv esc_snap2_flags)" = "0" ] \
      && [ "$(_t57_kv esc_before_state)" != "HUMAN_ESCALATED" ] \
      && [ "$(_t57_kv esc_merged_flags)" -ge 2 ] \
      && [ "$(_t57_kv esc_after_state)" = "HUMAN_ESCALATED" ] \
      && [ "$(_t57_kv esc_reason_carries_executor_flag)" = "1" ] \
      && [ "$(_t57_kv esc_reason_carries_orphan)" = "1" ]; then
      t57_pass "E2E(AC-6): Executor の flag + orphan receipt → 次 run snapshot → HUMAN_ESCALATED（合流前は $(_t57_kv esc_before_state)）"
    else
      t57_fail "E2E(AC-6): Executor 側の escalation 接続が成立しない（before=$(_t57_kv esc_before_state) after=$(_t57_kv esc_after_state) merged_flags=$(_t57_kv esc_merged_flags)）"
    fi
  fi

  # ── 4. AC-7: delivery.py / c3_contract.py / c3prime_verify.py が不変 ────
  _t57_ac7_files="scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py"

  # (a) TC-14: main との差分 0 行
  #     base ref が無い checkout では**実行できない**。この場合に無音 [SKIP] に
  #     すると「AC-7 は ta-57 と CI 双方で機械検証される」という宣言と実態が
  #     ずれる（R2 B2-2）。fail は増やさず（CI を落とさず）、**3 点中 2 点しか
  #     検証されていない環境であることを出力に明示**する。
  #     実測（2026-07-31）: `.github/workflows/test.yml` の `actions/checkout` は
  #     `fetch-depth` 未指定（既定 1）で、`pull_request` イベントでは
  #     `origin/main` も `main` も存在しない → PR 時 CI では本検査は走らない。
  #
  #     さらに **base ref が HEAD と同一 commit に解決する場合も検出力を持たない**。
  #     `git diff --stat HEAD -- <path>` は常に 0 行差分を返すため、実際には
  #     1000 行超を変更したファイルでも PASS してしまう（vacuous な PASS）。
  #     push-to-main の CI では `actions/checkout` が `origin/main` を HEAD と
  #     同じ SHA に作るため、この条件に該当する。上と同じ R2 B2-2 の方針で、
  #     **無音で通すのではなく [WARN] 経路へ落として未検証であることを明示**する。
  #     したがって 3 点が揃うのは **base ref が HEAD と異なる checkout**（＝
  #     ローカルの feature branch 実行）に限られる。
  _t57_base=""
  _t57_head=$(git -C "$PG_T57_ROOT" rev-parse HEAD 2>/dev/null || printf '')
  for _t57_ref in origin/main main; do
    if git -C "$PG_T57_ROOT" rev-parse --verify --quiet "$_t57_ref" >/dev/null 2>&1; then
      # base ref が HEAD と同一 commit なら差分は常に空 = 検出力ゼロ。採用しない。
      _t57_refsha=$(git -C "$PG_T57_ROOT" rev-parse "$_t57_ref" 2>/dev/null || printf '')
      if [ -n "$_t57_head" ] && [ "$_t57_refsha" = "$_t57_head" ]; then
        continue
      fi
      _t57_base="$_t57_ref"
      break
    fi
  done
  if [ -z "$_t57_base" ]; then
    printf '  [WARN] TC-14 / AC-7 差分検査は **未実行**: HEAD と異なる base ref (origin/main / main) が無い checkout\n' >&2
    printf '  [WARN]   → この環境で機械検証された AC-7 は 3 点中 2 点（TC-15 / TC-16）のみ。TC-14（差分 0 行）は未検証\n' >&2
    printf '  [WARN]   → base ref 不在（PR 時 CI: checkout の fetch-depth 既定 1）または base ref == HEAD（push-to-main の CI）では検出力を持たないため\n' >&2
    printf '  [WARN]   → 3 点が揃うのは base ref が HEAD と異なる checkout（ローカルの feature branch 実行）\n' >&2
  else
    _t57_rc=0
    # shellcheck disable=SC2086
    _t57_diff=$(git -C "$PG_T57_ROOT" diff --stat "$_t57_base" -- $_t57_ac7_files 2>&1) || _t57_rc=$?
    if [ "$_t57_rc" -eq 0 ] && [ -z "$_t57_diff" ]; then
      t57_pass "TC-14 / AC-7: delivery.py / c3_contract.py / c3prime_verify.py が $_t57_base から 0 行差分"
    else
      t57_fail "TC-14 / AC-7: 判定エンジン 3 ファイルに差分がある (rc=$_t57_rc): $_t57_diff"
    fi
  fi

  # (b) TC-15: test_delivery.py が 57 tests で OK（件数も条件に入れる）
  _t57_log="$_t57_tmp/test_delivery.log"
  _t57_rc=0
  python3 "$PG_T57_AILOOP/test_delivery.py" >"$_t57_log" 2>&1 || _t57_rc=$?
  _t57_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t57_log" | head -1)
  [ -n "$_t57_n" ] || _t57_n=0
  if [ "$_t57_rc" -eq 0 ] && grep -q '^OK' "$_t57_log" && [ "$_t57_n" -eq 57 ]; then
    t57_pass "TC-15 / AC-7: test_delivery.py（Ran 57 tests / OK）"
  else
    t57_fail "TC-15 / AC-7: test_delivery.py が 57 tests OK でない（rc=${_t57_rc} / ran=${_t57_n}）"
  fi

  # (c) TC-16: doc ↔ contract の byte 一致（ta-56 と同一方式）
  _t57_doc="$PG_T57_ROOT/docs/workflows/ai-loop/delivery-state-machine.md"
  _t57_emit="$_t57_tmp/contract.json"
  _t57_docblock="$_t57_tmp/docblock.json"
  python3 "$PG_T57_AILOOP/delivery.py" contract > "$_t57_emit" 2>/dev/null
  sed -n '/<!-- contract:begin -->/,/<!-- contract:end -->/p' "$_t57_doc" \
    | sed '1d;$d' | sed '1d;$d' > "$_t57_docblock"
  if cmp -s "$_t57_emit" "$_t57_docblock"; then
    t57_pass "TC-16 / AC-7: delivery-state-machine.md の contract ブロックが byte 一致（drift なし）"
  else
    t57_fail "TC-16 / AC-7: contract ブロックが emit と不一致（drift）"
  fi

  # ── 5. TC-E8: sync 列挙の片方漏れ検出（R-011 / R2 B2-5）─────────────────
  # `sync-plugin-plangate.sh` は「コピー元の for ループ」と「plugin 側の残置を
  # 許可する case」の **2 箇所**に同じ basename 集合を持つ。片方だけに追加すると
  #   - for だけ  → コピーされるが case で削除され、次回 sync で復活…を繰り返す
  #   - case だけ → そもそもコピーされない
  # のいずれも `git diff --quiet plugin/` は clean になり CI が検出しない。
  # 一度限りの手動照合（T-39）ではなく、2 集合の差分 0 を毎回機械検査する。
  _t57_sync="$PG_T57_ROOT/scripts/sync-plugin-plangate.sh"
  if [ ! -f "$_t57_sync" ]; then
    t57_fail "TC-E8: sync-plugin-plangate.sh が見つからない"
  else
    _t57_for="$_t57_tmp/sync-for.txt"
    _t57_case="$_t57_tmp/sync-case.txt"
    # shellcheck disable=SC2016  # `$AI_LOOP_SCRIPTS_DIR` は展開せず literal で照合する
    grep 'for _f in "\$AI_LOOP_SCRIPTS_DIR/' "$_t57_sync" \
      | grep -o '[A-Za-z0-9_]*\.py' | sort -u > "$_t57_for"
    grep '^ *arbiter\.py|' "$_t57_sync" \
      | grep -o '[A-Za-z0-9_]*\.py' | sort -u > "$_t57_case"
    _t57_n=$(wc -l < "$_t57_for" | tr -d ' ')
    if [ "$_t57_n" -gt 0 ] && cmp -s "$_t57_for" "$_t57_case"; then
      t57_pass "TC-E8: sync-plugin-plangate.sh の for ループ側と case 側の basename 集合が一致（${_t57_n} 本）"
    else
      t57_fail "TC-E8: sync 列挙の片方漏れ（for=${_t57_n} 本 / 差分: $(diff "$_t57_for" "$_t57_case" | tr '\n' ' ')）"
    fi
  fi

  # ── 6. TC-E9: allowlist と scripts/ai-loop/ の **実体** を照合（#1173）────
  # TC-E8 は for↔case の**相互一致**しか見ない。したがって「両方に載っていない
  # ファイル」は検査をすり抜け、plugin 導入先だけ ImportError / FileNotFoundError
  # になるのに CI は緑になる（実測: #1173 で discovery.py / test_discovery.py が
  # 非配布のまま bundled 側 test_check_exec_boundary.py を 2 件 error にしていた）。
  # ここでは allowlist を **ディレクトリの実体**と突き合わせ、次を FAIL にする:
  #   UNDECLARED          実在するが allowlist にも非配布宣言にも無い（載せ忘れ）
  #   REASON_MISSING      非配布宣言に issue 参照（#NNNN）形式の reason が無い
  #   STALE_IN_ALLOWLIST  非配布宣言なのに allowlist にも載っている
  #   STALE_MISSING       非配布宣言のファイルが実在しない
  # 総件数は契約にしない（集合の差分だけで判定する / #1162 の時限爆弾を作らない）。
  #
  # 非配布宣言: 1 行 1 件・`<basename> reason: <理由（#NNNN を必須で含む）>`。
  # 現在 0 件（#1173 で discovery.py / test_discovery.py は配布側へ是正済み）。
  # 宣言 0 件でも検出力が空振りにならないよう、(b) で監査器そのものを合成入力で
  # 6 ケース自己検査する。
  _T57_NONDIST_DECL=''

  _t57_audit="$_t57_tmp/allowlist_audit.py"
  cat > "$_t57_audit" <<'PY_T57_AUDIT'
import re
import sys


def audit(real, allow, decl_text):
    problems = []
    declared = {}
    for line in decl_text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split(None, 1)
        name = parts[0]
        reason = parts[1] if len(parts) > 1 else ''
        declared[name] = reason
        if not re.search(r'#[0-9]+', reason):
            problems.append(
                'REASON_MISSING %s (reason に issue 参照 #NNNN が無い: %r)'
                % (name, reason))
    for name in sorted(set(real) - set(allow) - set(declared)):
        problems.append(
            'UNDECLARED %s (scripts/ai-loop/ に実在するが allowlist にも '
            '非配布宣言にも無い — plugin 導入先で欠落する)' % name)
    for name in sorted(set(declared) & set(allow)):
        problems.append(
            'STALE_IN_ALLOWLIST %s (非配布と宣言されているが allowlist に '
            '載っている — 宣言を削除すること)' % name)
    for name in sorted(set(declared) - set(real)):
        problems.append(
            'STALE_MISSING %s (非配布宣言のファイルが実在しない — '
            '宣言を削除すること)' % name)
    return problems


def _read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def _lines(path):
    return [x.strip() for x in _read(path).splitlines() if x.strip()]


def main(argv):
    real, allow, decl = argv[1], argv[2], argv[3]
    problems = audit(_lines(real), _lines(allow), _read(decl))
    for p in problems:
        sys.stdout.write(p + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
PY_T57_AUDIT

  # (a) 本番判定: 実体 × allowlist（for ループ側）× 非配布宣言
  _t57_real="$_t57_tmp/ai-loop-real.txt"
  _t57_decl="$_t57_tmp/ai-loop-nondist.txt"
  printf '%s\n' "$_T57_NONDIST_DECL" > "$_t57_decl"
  for _t57_p in "$PG_T57_AILOOP"/*.py; do
    [ -f "$_t57_p" ] || continue
    basename "$_t57_p"
  done | sort -u > "$_t57_real"
  _t57_n=$(grep -c . "$_t57_real" 2>/dev/null || printf '0')
  if [ ! -s "${_t57_for:-/nonexistent}" ]; then
    t57_fail "TC-E9: allowlist（TC-E8 の for ループ抽出）が空 — 抽出パターンが実装とずれた可能性"
  elif [ "${_t57_n:-0}" -eq 0 ]; then
    t57_fail "TC-E9: scripts/ai-loop/ に .py が 1 本も見つからない（測定対象が空 = 偽 PASS 経路）"
  else
    _t57_out="$_t57_tmp/audit.out"
    _t57_rc=0
    python3 "$_t57_audit" "$_t57_real" "$_t57_for" "$_t57_decl" > "$_t57_out" 2>&1 || _t57_rc=$?
    if [ "$_t57_rc" -eq 0 ]; then
      t57_pass "TC-E9: allowlist が scripts/ai-loop/ の実体を網羅（実体 ${_t57_n} 本 / 非配布宣言との差分 0）"
    else
      t57_fail "TC-E9: allowlist と実体の乖離 — $(tr '\n' ' ' < "$_t57_out")"
    fi
  fi

  # (b) 監査器の自己検査（宣言 0 件でも検出力が空振りにならないことの実証）
  _t57_selfcheck() {
    _sc_name="$1"; _sc_real="$2"; _sc_allow="$3"; _sc_decl="$4"; _sc_expect="$5"
    printf '%s' "$_sc_real" > "$_t57_tmp/sc-real.txt"
    printf '%s' "$_sc_allow" > "$_t57_tmp/sc-allow.txt"
    printf '%s' "$_sc_decl" > "$_t57_tmp/sc-decl.txt"
    _sc_rc=0
    _sc_out=$(python3 "$_t57_audit" "$_t57_tmp/sc-real.txt" "$_t57_tmp/sc-allow.txt" \
      "$_t57_tmp/sc-decl.txt" 2>&1) || _sc_rc=$?
    if [ "$_sc_expect" = "OK" ]; then
      if [ "$_sc_rc" -eq 0 ]; then
        t57_pass "TC-E9 self: ${_sc_name}（期待どおり違反なし）"
      else
        t57_fail "TC-E9 self: $_sc_name — 違反なしを期待したが検出: $(printf '%s' "$_sc_out" | tr '\n' ' ')"
      fi
    else
      if [ "$_sc_rc" -ne 0 ] && printf '%s' "$_sc_out" | grep -q "$_sc_expect"; then
        t57_pass "TC-E9 self: ${_sc_name}（$_sc_expect を検出）"
      else
        t57_fail "TC-E9 self: $_sc_name — $_sc_expect を期待したが rc=$_sc_rc / out=$(printf '%s' "$_sc_out" | tr '\n' ' ')"
      fi
    fi
  }
  _t57_selfcheck 'allowlist 完全一致は PASS' 'a.py
b.py
' 'a.py
b.py
' '' 'OK'
  _t57_selfcheck '新規ファイルが未宣言なら FAIL' 'a.py
b.py
new.py
' 'a.py
b.py
' '' 'UNDECLARED'
  _t57_selfcheck '理由付き非配布宣言があれば PASS' 'a.py
skip.py
' 'a.py
' 'skip.py reason: PoC のため非配布 (#1173)
' 'OK'
  _t57_selfcheck 'issue 参照の無い reason は FAIL' 'a.py
skip.py
' 'a.py
' 'skip.py reason: とりあえず除外
' 'REASON_MISSING'
  _t57_selfcheck '宣言と allowlist の二重掲載は FAIL' 'a.py
' 'a.py
' 'a.py reason: 非配布 (#1173)
' 'STALE_IN_ALLOWLIST'
  _t57_selfcheck '実在しないファイルの宣言は FAIL' 'a.py
' 'a.py
' 'gone.py reason: 非配布 (#1173)
' 'STALE_MISSING'

  # (c) CI 層のみ: 非配布宣言が参照する issue が OPEN であること
  #     （CLOSED = 除外の根拠が消えたのに除外だけ残っている状態）。
  #     `tests/extras/` はオフライン実行される前提のため gh 不在 / 非 CI では
  #     判定しない。常時層は (a) の REASON_MISSING（形式検査）が担保する。
  _t57_declc=$(grep -v '^[[:space:]]*#' "$_t57_decl" 2>/dev/null | grep -c . || printf '0')
  if [ "${_t57_declc:-0}" -gt 0 ]; then
    if [ "${PG_T57_ISSUE_STATE:-${CI:-0}}" != "0" ] \
       && [ "${PG_T57_ISSUE_STATE:-${CI:-0}}" != "false" ] \
       && command -v gh >/dev/null 2>&1; then
      grep -v '^[[:space:]]*#' "$_t57_decl" | grep . > "$_t57_tmp/decl-lines.txt"
      : > "$_t57_tmp/decl-bad.txt"
      while IFS= read -r _dl; do
        _t57_num=$(printf '%s' "$_dl" | grep -o '#[0-9][0-9]*' | head -1 | tr -d '#')
        [ -n "$_t57_num" ] || continue
        _t57_state=$(gh issue view "$_t57_num" --json state -q .state 2>/dev/null || true)
        case "$_t57_state" in
          OPEN) : ;;
          '') printf '  [WARN] TC-E9 issue 状態: #%s を照会できない（gh 認証 / ネットワーク）\n' "$_t57_num" ;;
          *) printf '#%s=%s\n' "$_t57_num" "$_t57_state" >> "$_t57_tmp/decl-bad.txt" ;;
        esac
      done < "$_t57_tmp/decl-lines.txt"
      if [ -s "$_t57_tmp/decl-bad.txt" ]; then
        t57_fail "TC-E9: 非配布宣言の根拠 issue が OPEN でない — $(tr '\n' ' ' < "$_t57_tmp/decl-bad.txt")（除外の根拠が失効している）"
      else
        t57_pass "TC-E9: 非配布宣言の根拠 issue はすべて OPEN"
      fi
    else
      printf '  [INFO] TC-E9 issue 状態検査は CI 層のみ（PG_T57_ISSUE_STATE=1 かつ gh 利用可で実行）\n'
    fi
  fi

  # ── 後片付け（trap 非依存 / register_cleanup と二重化）──────────────────
  rm -rf "$_t57_tmp"
  unset _t57_tmp _t57_e2e _t57_e2e_err _t57_log _t57_bnd _t57_n _t57_rc \
        _t57_base _t57_ref _t57_diff _t57_doc _t57_emit _t57_docblock \
        _t57_ac7_files _t57_mod _t57_path _t57_sync _t57_for _t57_case \
        2>/dev/null || true
fi
