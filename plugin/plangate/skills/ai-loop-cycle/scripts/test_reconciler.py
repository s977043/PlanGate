#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """test_reconciler.py — reconciler.py（AC-3 冪等 / D3 findings 再構成）+ AC-6 接続点 +
TC-40 の unittest。

実行: python3 scripts/ai-loop/test_reconciler.py

契約正本: docs/working/TASK-0917/plan.md 論点 D3（`findings[]` / `conflict_resolution`）/
Work Breakdown Step 7 / todo.md T-29・T-30・T-31・T-32・T-51。
カバー: test-cases.md
  TC-07 / TC-08 / TC-09 / TC-09b（AC-3: 冪等）
  TC-12 / TC-13（AC-6: opaque reason code の素通しと state entry の残存）
  TC-40（`finding_type` 語彙の同一性と `id` の決定論 / R-034）
  TC-E5（`record.jsonl` 破損）
  T-31 統合（Collector → assess → Executor → receipt → Reconciler の 1 周）

設計上の注意:
- **実ネットワークに出ない**。`gh_exec` は fixture（`LoopGh`）を注入して差し替え、
  `subprocess` は一度も呼ばれない。
- `delivery.py` は main の実物を呼ぶ（AC-7: 一行も変更しない）。
- 変異注入は **monkeypatch / 一時オブジェクト / mktemp サンドボックス**のみで行い、
  作業ツリーのファイルは 1 バイトも書き換えない。
"""

import ast
import copy
import json
import pathlib
import shutil
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import c3_contract  # noqa: E402
import collector  # noqa: E402
import delivery  # noqa: E402  判定エンジンの実物（AC-7: 変更しない）
import executor  # noqa: E402
import reconciler  # noqa: E402

REPO = "s977043/plangate"
PR = 917
TASK = "TASK-0917"
BRANCH = "feat/task-0917-delivery"
BASE_REF = "main"
SRC = "a" * 40                     # c3-prime の source_sha
H1 = "1" * 40                      # 初期 head
H2 = "2" * 40                      # repair 後 head
H3 = "3" * 40
NOW = "2026-07-31T00:00:00Z"
TOUCHED = "scripts/ai-loop/executor.py"

PLAN_TEXT = f"""# EXECUTION PLAN — TASK-0917

## Files / Components to Touch

| # | ファイル | 種別 |
|---|---------|------|
| 1 | `{TOUCHED}` | 新設 |

## Testing Strategy
"""


# ---------------------------------------------------------------------------
# fixture: Collector と Executor の両方に応答する gh_exec 差し替え
# ---------------------------------------------------------------------------

class FakeProc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class FakePush:
    def __init__(self):
        self.pushed = True
        self.argv = ("git", "push", "origin", f"HEAD:refs/heads/{BRANCH}")
        self.result = FakeProc(0, "")


def check_run(name, *, head_sha, conclusion="success", status="completed", cid=1):
    return {"id": cid, "name": name, "head_sha": head_sha, "status": status,
            "conclusion": conclusion, "completed_at": "2026-07-31T00:00:00Z"}


def review(state, sha, *, at="2026-07-31T00:00:00Z", login="human",
           association="MEMBER"):
    """REST の review 1 件。`author_association` / `user.login` を持つ（R1 B-7）。

    `reduce_review()` は権限不明の `APPROVED` を候補にしない（fail-closed）ため、
    fixture は実 REST と同じく両フィールドを供給する。
    """
    return {"id": 1, "state": state, "commit_id": sha, "submitted_at": at,
            "user": {"login": login}, "author_association": association}


class LoopGh:
    """Collector の REST GET 4 本 + 読み取り系 git + Executor の書き込み 2 経路。

    `push_pr_head()` は **PR head を進める**（実 PR 収束の 1 周を fixture 上で再現）。
    """

    Denied = executor.gh_exec.Denied

    def __init__(self, *, head_sha=H1, checks=None, reviews=None,
                 required=("CI",), mergeable=True, changed=(TOUCHED,),
                 ancestry_ok=True):
        self.head_sha = head_sha
        self.checks = list(checks or [])
        self.reviews = list(reviews or [])
        self.required = list(required)
        self.mergeable = mergeable
        self.changed = list(changed)
        self.ancestry_ok = ancestry_ok
        self.comment_calls = []
        self.push_calls = []
        self.next_head = None

    # --- 読み取り ---------------------------------------------------------
    def run_gh(self, args, *, repo, cwd=None):
        if args[:2] == ["pr", "view"]:
            return FakeProc(0, json.dumps({"headRefOid": self.head_sha,
                                           "headRefName": BRANCH,
                                           "baseRefName": BASE_REF}))
        if args[0] != "api":
            raise AssertionError(f"想定外の gh 呼び出し: {args}")
        endpoint = args[1]
        if endpoint == f"repos/{REPO}/pulls/{PR}":
            return FakeProc(0, json.dumps({
                "mergeable": self.mergeable,
                "head": {"sha": self.head_sha},
                "base": {"ref": BASE_REF}}))
        if endpoint.startswith(f"repos/{REPO}/commits/"):
            sha = endpoint.split("/commits/")[1].split("/")[0]
            runs = [c for c in self.checks if c["head_sha"] == sha]
            return FakeProc(0, json.dumps({"check_runs": runs}))
        if endpoint.startswith(f"repos/{REPO}/pulls/{PR}/reviews"):
            return FakeProc(0, json.dumps(self.reviews))
        if endpoint.startswith(f"repos/{REPO}/rules/branches/"):
            return FakeProc(0, json.dumps([{
                "type": "required_status_checks",
                "parameters": {"required_status_checks":
                               [{"context": n} for n in self.required]}}]))
        raise AssertionError(f"想定外の endpoint: {endpoint}")

    def run_git(self, args, *, cwd=None):
        if args[:2] == ["diff", "--name-only"]:
            return FakeProc(0, "\n".join(self.changed) + "\n")
        if args[:2] == ["merge-base", "--is-ancestor"]:
            ancestor, descendant = args[2], args[3]
            if ancestor == SRC:
                return FakeProc(0 if self.ancestry_ok else 1, "")
            # Executor の pre-check: 一致しない head へ進んでいれば祖先とみなす
            return FakeProc(0 if ancestor != descendant else 0, "")
        raise AssertionError(f"想定外の git 呼び出し: {args}")

    # --- 書き込み ---------------------------------------------------------
    def comment_pr(self, *, repo, pr_number, body, cwd=None):
        self.comment_calls.append(body)
        url = f"https://github.com/{REPO}/pull/{PR}#issuecomment-{len(self.comment_calls)}"
        return FakeProc(0, url + "\n")

    def push_pr_head(self, *, repo, branch, expected_parent_sha, cwd=None):
        self.push_calls.append(expected_parent_sha)
        if self.next_head:
            self.head_sha = self.next_head
            self.next_head = None
        return FakePush()


# ---------------------------------------------------------------------------
# 共通ヘルパ
# ---------------------------------------------------------------------------

def _action(kind, payload):
    body = dict(payload)
    body["action_kind"] = kind
    return {"action_kind": kind, "action_id": delivery.action_id(body), **payload}


def _intent(action):
    return {"kind": "intent", "action_id": action["action_id"],
            "action_kind": action["action_kind"],
            "payload": {k: v for k, v in action.items()
                        if k not in ("action_id", "action_kind")}}


class SandboxCase(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="plangate-test-reconciler-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.task_dir = self.tmp / TASK
        self.task_dir.mkdir(parents=True)

    def record(self):
        return delivery.record_path(self.task_dir)

    def entries(self):
        return delivery.load_entries(self.record())

    def seed(self, entries, task_dir=None):
        delivery.append_entries(delivery.record_path(task_dir or self.task_dir),
                                entries, NOW)

    def ctx(self, gh, **kw):
        params = {"repo": REPO, "branch": BRANCH, "task_dir": self.task_dir,
                  "now": NOW, "gh": gh}
        params.update(kw)
        return executor.ExecContext(**params)


# ---------------------------------------------------------------------------
# AC-3: 冪等（intent ↔ receipt 突合）
# ---------------------------------------------------------------------------

class TestIdempotence(SandboxCase):

    def _repair(self):
        return _action("repair_ci", {"pr_number": PR, "head_sha": H1, "round": 1,
                                     "taxonomy": "code", "failed_checks": ["CI"]})

    def test_tc09_intent_without_receipt_is_pending(self):
        """TC-09: 外部作用**前**の中断 → 当該 action は pending（再要求される）。"""
        action = self._repair()
        self.seed([_intent(action)])
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        self.assertEqual(state.pending, (action["action_id"],))
        self.assertFalse(reconciler.is_applied(action["action_id"], state.entries))

    def test_receipted_action_is_applied_and_not_pending(self):
        action = self._repair()
        self.seed([_intent(action)])
        gh = LoopGh(head_sha=H1)
        executor.execute_actions([action],
                                 self.ctx(gh, repair_commit_sha=H2))
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        self.assertEqual(state.pending, ())
        self.assertTrue(reconciler.is_applied(action["action_id"], state.entries))

    def test_tc07_filter_unexecuted_removes_receipted_actions(self):
        """TC-07: 同一 `action_id` の再実行で二重作用しない（Executor へ渡す前に落ちる）。"""
        action = self._repair()
        self.seed([_intent(action)])
        gh = LoopGh(head_sha=H1)
        executor.execute_actions([action], self.ctx(gh, repair_commit_sha=H2))
        remaining = reconciler.filter_unexecuted([action], self.entries())
        self.assertEqual(remaining, [])

        gh2 = LoopGh(head_sha=H1)
        executor.execute_actions(remaining, self.ctx(gh2, repair_commit_sha=H2))
        self.assertEqual(len(gh2.push_calls) + len(gh2.comment_calls), 0)

    def test_orphan_receipt_is_reported_not_swallowed(self):
        """intent の無い receipt は「記録なき実行」の兆候として明示する。"""
        self.seed([{"kind": "receipt", "action_id": "sha256:deadbeef",
                    "action_kind": "repair_ci", "pr_number": PR,
                    "head_sha": H1, "round": 1, "result_ref": "adopted:" + H2}])
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        self.assertEqual(state.orphan_receipts, ("sha256:deadbeef",))

    def test_orphan_receipt_is_promoted_to_an_escalation_flag(self):
        """R2 B2-3: `orphan_receipts` を算出しただけで終わらせない。

        `Reconciliation` に載せるだけでは誰も消費しないため、
        `escalation_flags()` で理由コードへ昇格させ、
        `executor.apply_escalation_flags()` 経由で `delivery.assess()` の
        優先度 1（`escalation_flags` → `HUMAN_ESCALATED`）に届かせる。
        """
        self.seed([{"kind": "receipt", "action_id": "sha256:deadbeef",
                    "action_kind": "repair_ci", "pr_number": PR,
                    "head_sha": H1, "round": 1, "result_ref": "adopted:" + H2}])
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        flags = reconciler.escalation_flags(state)
        self.assertEqual(
            flags, (f"{reconciler.FLAG_ORPHAN_RECEIPT}:sha256:deadbeef",))

        snapshot = executor.apply_escalation_flags({"escalation_flags": []}, flags)
        self.assertEqual(snapshot["escalation_flags"], list(flags))

    def test_pending_intent_is_not_promoted(self):
        """receipt 待ちの intent（正常な resume 経路）は escalate しない。"""
        action = self._repair()
        self.seed([_intent(action)])
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        self.assertEqual(state.pending, (action["action_id"],))
        self.assertEqual(reconciler.escalation_flags(state), ())

    def test_orphan_flag_reaches_human_escalated(self):
        """昇格した理由コードが `delivery.assess()` を `HUMAN_ESCALATED` にする。"""
        gh = LoopGh(head_sha=H1, checks=[check_run("CI", head_sha=H1)],
                    reviews=[review("APPROVED", H1)])
        snapshot = collector.collect(task_id=TASK, repo=REPO, pr_number=PR,
                                     source_sha=SRC, plan_text=PLAN_TEXT,
                                     record_path=self.record(), findings=[], gh=gh)
        self.assertEqual(snapshot["escalation_flags"], [])
        clean = delivery.assess(copy.deepcopy(snapshot), self.entries())["state"]
        self.assertNotEqual(clean, "HUMAN_ESCALATED")

        self.seed([{"kind": "receipt", "action_id": "sha256:deadbeef",
                    "action_kind": "repair_ci", "pr_number": PR,
                    "head_sha": H1, "round": 1, "result_ref": "adopted:" + H2}])
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        merged = executor.apply_escalation_flags(
            snapshot, reconciler.escalation_flags(state))
        self.assertEqual(delivery.assess(merged, self.entries())["state"],
                         "HUMAN_ESCALATED")

    def test_mutation_dropping_promotion_hides_the_orphan(self):
        """検出力の実証: 昇格を外す（空 tuple 固定）と orphan が判定へ届かない。"""
        self.seed([{"kind": "receipt", "action_id": "sha256:deadbeef",
                    "action_kind": "repair_ci", "pr_number": PR,
                    "head_sha": H1, "round": 1, "result_ref": "adopted:" + H2}])
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        original = reconciler.escalation_flags
        try:
            reconciler.escalation_flags = lambda _s: ()   # 変異注入（是正前）
            merged = executor.apply_escalation_flags(
                {"escalation_flags": []}, reconciler.escalation_flags(state))
        finally:
            reconciler.escalation_flags = original
        self.assertEqual(merged["escalation_flags"], [])
        self.assertTrue(state.orphan_receipts)  # 兆候は出ているのに届かない

    def test_tc08_action_id_reuses_canonical_hash(self):
        """TC-08: `reconciler.py` は `c3_contract.canonical_hash` を import 再利用する。"""
        payload = {"pr_number": PR, "head_sha": H1, "round": 1,
                   "action_kind": "repair_ci", "taxonomy": "code",
                   "failed_checks": ["CI"]}
        self.assertEqual(reconciler.action_id(payload),
                         c3_contract.canonical_hash(payload))
        source = (HERE / "reconciler.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        imported = {a.name for node in ast.walk(tree)
                    if isinstance(node, ast.Import) for a in node.names}
        self.assertIn("c3_contract", imported)
        for node in ast.walk(tree):
            if isinstance(node, ast.Attribute):
                self.assertNotEqual(node.attr, "sha256")
            if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                    and node.func.attr == "dumps"):
                for kw in node.keywords:
                    self.assertNotEqual(kw.arg, "sort_keys")

    def test_mutation_reimplemented_hash_breaks_receipt_matching(self):
        """変異④: `action_id` を独自実装にすると receipt 突合が壊れる。"""
        action = self._repair()
        self.seed([_intent(action)])
        gh = LoopGh(head_sha=H1)
        executor.execute_actions([action], self.ctx(gh, repair_commit_sha=H2))
        entries = self.entries()
        self.assertTrue(reconciler.is_applied(action["action_id"], entries))

        mutant = dict(action)
        mutant["action_id"] = "sha256:" + "0" * 64  # 別実装が返す値を模す
        self.assertFalse(reconciler.is_applied(mutant["action_id"], entries))
        self.assertEqual(reconciler.filter_unexecuted([mutant], entries), [mutant])


# ---------------------------------------------------------------------------
# D3: result_ref convention → disposition / conflict_resolution 再構成
# ---------------------------------------------------------------------------

class TestReconstruction(SandboxCase):

    def test_adopted_convention_reconstructs_disposition(self):
        action = _action("repair_review", {"pr_number": PR, "head_sha": H1,
                                           "round": 1, "finding_id": "F-abc",
                                           "finding_type": "security",
                                           "severity": "critical"})
        self.seed([_intent(action)])
        gh = LoopGh(head_sha=H1)
        executor.execute_actions([action], self.ctx(gh, repair_commit_sha=H2))
        dispositions = reconciler.reconstruct_dispositions(self.entries(), PR)
        self.assertEqual(dispositions["F-abc"], {"kind": "adopted",
                                                 "repair_commit": H2})
        finding = {"id": "F-abc", "finding_type": "security", "severity": "critical"}
        applied = reconciler.apply_dispositions([finding], dispositions)
        self.assertTrue(delivery._resolved(applied[0]))

    def test_rejected_convention_reconstructs_disposition(self):
        action = _action("record_disposition", {"pr_number": PR, "head_sha": H1,
                                                "finding_id": "F-min",
                                                "finding_type": "readability",
                                                "severity": "minor"})
        self.seed([_intent(action)])
        gh = LoopGh(head_sha=H1)
        executor.execute_actions(
            [action], self.ctx(gh, evidence_ref="docs/working/TASK-0917/evidence/f.md"))
        dispositions = reconciler.reconstruct_dispositions(self.entries(), PR)
        self.assertEqual(dispositions["F-min"]["kind"], "rejected")
        self.assertTrue(dispositions["F-min"]["evidence_ref"])

    def test_conflict_resolution_needs_all_three_points(self):
        """R-026: 三点が揃うときのみ出力（常時出力は恒久 `CONFLICT` を生む）。"""
        action = _action("resolve_conflict", {"pr_number": PR, "head_sha": H1,
                                              "round": 1})
        self.seed([_intent(action)])
        gh = LoopGh(head_sha=H1)
        self.assertIsNone(reconciler.reconstruct_conflict_resolution(
            self.entries(), PR))
        executor.execute_actions([action],
                                 self.ctx(gh, repair_commit_sha=H2, base_sha=H3))
        cr = reconciler.reconstruct_conflict_resolution(self.entries(), PR)
        self.assertEqual(cr, {"base_sha": H3, "head_sha": H1, "result_sha": H2})

    def test_partial_result_ref_does_not_fabricate_conflict_resolution(self):
        self.seed([{"kind": "receipt", "action_id": "sha256:x",
                    "action_kind": "resolve_conflict", "pr_number": PR,
                    "head_sha": H1, "round": 1, "result_ref": "adopted:" + H2}])
        self.assertIsNone(reconciler.reconstruct_conflict_resolution(
            self.entries(), PR))

    def test_other_pr_receipts_are_not_mixed_in(self):
        self.seed([{"kind": "receipt", "action_id": "sha256:y",
                    "action_kind": "repair_review", "pr_number": 999,
                    "head_sha": H1, "round": 1, "finding_type": "security",
                    "result_ref": "adopted:" + H2}])
        self.assertEqual(reconciler.reconstruct_dispositions(self.entries(), PR), {})

    def test_tce5_broken_record_is_not_swallowed(self):
        """TC-E5: `record.jsonl` 破損は握り潰さず `RecordError`（append-only を壊さない）。"""
        path = self.record()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('{"kind": "intent"}\n{ broken\n', encoding="utf-8")
        with self.assertRaises(delivery.RecordError):
            reconciler.reconcile(self.task_dir, pr_number=PR)
        state, error = reconciler.safe_reconcile(self.task_dir, pr_number=PR)
        self.assertIsNone(state)
        self.assertIn("record.jsonl", error)
        # 破損ファイルを書き直していない（append-only 契約）
        self.assertEqual(path.read_text(encoding="utf-8"),
                         '{"kind": "intent"}\n{ broken\n')


# ---------------------------------------------------------------------------
# TC-40: finding_type 語彙の同一性と id の決定論（R-034）
# ---------------------------------------------------------------------------

RAW_FINDING = {"finding": "認可チェック漏れ", "severity": "critical",
               "evidence": "diff L10", "location": f"{TOUCHED}:10",
               "category": "security"}


class TestFindingTypeVocabulary(SandboxCase):

    def _snapshot(self, findings, *, escalation=()):
        return {
            "task_id": TASK, "pr_number": PR, "head_sha": H1,
            "source_sha_ancestry": True, "mergeable": "MERGEABLE",
            "checks": [{"name": "CI", "sha": H1, "conclusion": "success"}],
            "review": {"state": "approved", "sha": H1},
            "findings": findings, "changed_files": [TOUCHED],
            "allowed_paths": [TOUCHED], "escalation_flags": list(escalation),
            "dod_evaluated": True,
        }

    def _seed_repair_review_receipt(self, finding_type):
        action = _action("repair_review", {"pr_number": PR, "head_sha": H1,
                                           "round": 1, "finding_id": "F-old",
                                           "finding_type": finding_type,
                                           "severity": "critical"})
        self.seed([_intent(action)])
        gh = LoopGh(head_sha=H1)
        executor.execute_actions([action], self.ctx(gh, repair_commit_sha=H2))
        return action

    def test_tc40_positive_same_vocabulary_detects_recurrence(self):
        """正側: receipt と同語彙の未解消 finding → `REVIEW_REPAIR` +
        `feedback_loop_referral`。"""
        self._seed_repair_review_receipt("security")
        findings = collector.adapt_findings([RAW_FINDING])
        self.assertEqual(findings[0]["finding_type"], "security")
        result = delivery.assess(self._snapshot(findings), self.entries())
        self.assertEqual(result["state"], "REVIEW_REPAIR")
        kinds = {a["action_kind"] for a in result["actions"]}
        self.assertIn("feedback_loop_referral", kinds)

    def test_tc40_negative_vocabulary_drift_makes_recurrence_fail_open(self):
        """負側（変異注入）: アダプタ側の語彙を別語彙にすると集合積が空になり
        `feedback_loop_referral` が出ない（= 恒久 fail-open の実証）。"""
        self._seed_repair_review_receipt("security")
        original = collector.normalize_finding_type
        try:
            collector.normalize_finding_type = lambda value: "sec"  # 変異注入
            findings = collector.adapt_findings([RAW_FINDING])
        finally:
            collector.normalize_finding_type = original
        self.assertEqual(findings[0]["finding_type"], "sec")
        result = delivery.assess(self._snapshot(findings), self.entries())
        kinds = {a["action_kind"] for a in result["actions"]}
        self.assertNotIn("feedback_loop_referral", kinds)
        self.assertEqual(
            delivery._past_repair_finding_types(self.entries(), PR), {"security"})

    def test_tc40_id_is_deterministic_across_runs(self):
        first = collector.adapt_findings([RAW_FINDING])
        second = collector.adapt_findings([copy.deepcopy(RAW_FINDING)])
        self.assertEqual(first[0]["id"], second[0]["id"])
        self.assertTrue(first[0]["id"].startswith(collector.FINDING_ID_PREFIX))

    def test_tc40_id_ignores_severity_changes(self):
        """severity は run 間で揺れるため `id` の導出キーに含めない。"""
        shifted = dict(RAW_FINDING, severity="major")
        self.assertEqual(collector.adapt_finding(RAW_FINDING)["id"],
                         collector.adapt_finding(shifted)["id"])

    def test_tc40_negative_unstable_id_keeps_unresolved_hard(self):
        """負側: `id` が run ごとに変わる実装では disposition 突合が壊れ
        `MERGE_READY` に到達しない。"""
        finding = collector.adapt_finding(RAW_FINDING)
        dispositions = {finding["id"]: {"kind": "adopted", "repair_commit": H2}}
        resolved = reconciler.apply_dispositions([finding], dispositions)
        self.assertEqual(delivery.assess(self._snapshot(resolved), [])["state"],
                         "MERGE_READY")

        unstable = dict(finding, id=finding["id"] + "-run2")  # 変異注入
        broken = reconciler.apply_dispositions([unstable], dispositions)
        self.assertFalse(delivery._resolved(broken[0]))
        self.assertEqual(delivery.assess(self._snapshot(broken), [])["state"],
                         "REVIEW_REPAIR")

    def test_vocabulary_is_the_single_constant_table(self):
        self.assertIs(executor.FINDING_TYPE_VOCABULARY,
                      collector.FINDING_TYPE_VOCABULARY)
        self.assertIn("security", collector.FINDING_TYPE_VOCABULARY)
        self.assertNotIn("sec", collector.FINDING_TYPE_VOCABULARY)
        for value in ("SECURITY", " security ", "セキュリティ"):
            self.assertEqual(collector.normalize_finding_type(value), "security")
        self.assertEqual(collector.normalize_finding_type("未知の観点"), "other")


# ---------------------------------------------------------------------------
# T-32 / AC-6: opaque reason code の素通しと state entry の残存
# ---------------------------------------------------------------------------

class TestLoopControlContract(SandboxCase):
    """TC-12 / TC-13。**語彙の妥当性は検証しない**（enum は #894 が決める）。"""

    def _collect(self, gh, **kw):
        # `findings` は明示的に空リストを供給する（未供給は
        # `findings_unavailable` に倒れる契約 / R1 B-4）。
        kw.setdefault("findings", [])
        return collector.collect(task_id=TASK, repo=REPO, pr_number=PR,
                                 source_sha=SRC, plan_text=PLAN_TEXT,
                                 record_path=self.record(), gh=gh, **kw)

    def test_tc12_opaque_reason_code_reaches_human_escalated_and_record(self):
        reason = "loop_control:budget_exceeded"
        gh = LoopGh(head_sha=H1,
                    checks=[check_run("CI", head_sha=H1)],
                    reviews=[review("APPROVED", H1)])
        snapshot = executor.apply_escalation_flags(self._collect(gh), [reason])
        self.assertEqual(snapshot["escalation_flags"], [reason])

        result = delivery.assess(snapshot, self.entries())
        self.assertEqual(result["state"], "HUMAN_ESCALATED")
        delivery.append_entries(self.record(), result["new_entries"], NOW)
        text = self.record().read_text(encoding="utf-8")
        self.assertIn(reason, text)
        states = [e for e in self.entries() if e["kind"] == "state"]
        self.assertEqual(len(states), 1)
        self.assertEqual(states[0]["state"], "HUMAN_ESCALATED")

    def test_tc13_two_consecutive_failing_runs_leave_distinguishable_entries(self):
        """TC-13: pre-check 失敗が連続する 2 run のいずれでも state entry が残る。"""
        empty = self.tmp / "no-run"
        empty.mkdir()
        self.assertEqual(delivery.load_entries(delivery.record_path(empty)), [])

        for head in (H1, H2):
            gh = LoopGh(head_sha=head,
                        checks=[check_run("CI", head_sha=head)],
                        reviews=[review("APPROVED", head)])
            # required checks の取得を失敗させる = pre-check 失敗（fail-closed）
            gh.required = []

            def fail_rules(args, *, repo, cwd=None, _gh=gh):
                if args[0] == "api" and "/rules/branches/" in args[1]:
                    return FakeProc(1, "", "HTTP 403: rate limit")
                return LoopGh.run_gh(_gh, args, repo=repo, cwd=cwd)

            gh.run_gh = fail_rules
            snapshot = self._collect(gh)
            self.assertTrue(any(f.startswith(
                collector.FLAG_REQUIRED_CHECKS_FETCH_FAILED)
                for f in snapshot["escalation_flags"]))
            result = delivery.assess(snapshot, self.entries())
            self.assertEqual(result["state"], "HUMAN_ESCALATED")
            delivery.append_entries(self.record(), result["new_entries"], NOW)

        states = [e for e in self.entries() if e["kind"] == "state"]
        self.assertEqual(len(states), 2)
        self.assertEqual({s["head_sha"] for s in states}, {H1, H2})
        # 「何も起きていない run」との区別（0 件 vs 2 件）
        self.assertEqual(delivery.load_entries(delivery.record_path(empty)), [])

    def test_executor_flags_are_opaque_strings_passed_through(self):
        """Executor が積む理由コードも同じ 1 点（`escalation_flags`）で合流する。"""
        action = {"action_kind": "merge_pr", "action_id": "x", "pr_number": PR,
                  "head_sha": H1}
        report = executor.execute_actions([action],
                                          self.ctx(LoopGh(head_sha=H1)))
        self.assertTrue(report.escalation_flags)
        snapshot = executor.apply_escalation_flags(
            {"escalation_flags": []}, report.escalation_flags)
        self.assertEqual(snapshot["escalation_flags"],
                         list(report.escalation_flags))


# ---------------------------------------------------------------------------
# T-31: Collector → assess → Executor → receipt → Reconciler の 1 周
# ---------------------------------------------------------------------------

class TestFullLoop(SandboxCase):

    def _collect(self, gh, findings=(), conflict_resolution=None):
        return collector.collect(
            task_id=TASK, repo=REPO, pr_number=PR, source_sha=SRC,
            plan_text=PLAN_TEXT, record_path=self.record(), gh=gh,
            findings=findings, conflict_resolution=conflict_resolution)

    def _assess(self, snapshot):
        result = delivery.assess(snapshot, self.entries())
        delivery.append_entries(self.record(), result["new_entries"], NOW)
        return result

    def test_ci_failure_to_merge_ready_in_one_loop(self):
        # --- run 1: CI 失敗 → CHECKS_FAILED → repair_ci -----------------
        gh = LoopGh(head_sha=H1,
                    checks=[check_run("CI", head_sha=H1, conclusion="failure")],
                    reviews=[review("APPROVED", H1)])
        self.seed([{"kind": "ci_taxonomy", "source": "manual", "pr_number": PR,
                    "head_sha": H1, "taxonomy": "code"}])
        snap1 = self._collect(gh)
        self.assertEqual(snap1["escalation_flags"], [])
        result1 = self._assess(snap1)
        self.assertEqual(result1["state"], "CHECKS_FAILED")
        actions = reconciler.filter_unexecuted(result1["actions"], self.entries())
        self.assertEqual([a["action_kind"] for a in actions], ["repair_ci"])

        gh.next_head = H2  # push で head が進む
        report = executor.execute_actions(actions,
                                          self.ctx(gh, repair_commit_sha=H2))
        self.assertEqual([o.status for o in report.outcomes],
                         [executor.STATUS_EXECUTED])
        self.assertEqual(len(gh.comment_calls), 1)   # R-005 通知が 1 件
        self.assertEqual(len(gh.push_calls), 1)
        self.assertEqual(gh.head_sha, H2)

        # --- run 2: 最新 head で再評価 → minor finding の記録要求 --------
        gh.checks.append(check_run("CI", head_sha=H2, conclusion="success", cid=2))
        gh.reviews.append(review("APPROVED", H2, at="2026-07-31T01:00:00Z"))
        raw = {"finding": "変数名が不明瞭", "severity": "minor",
               "evidence": "L1", "location": f"{TOUCHED}:1", "category": "可読性"}
        findings = collector.adapt_findings([raw])
        snap2 = self._collect(gh, findings=findings)
        self.assertEqual(snap2["head_sha"], H2)
        self.assertEqual(snap2["escalation_flags"], [])
        result2 = self._assess(snap2)
        self.assertEqual(result2["state"], "REVIEW_REPAIR")
        actions = reconciler.filter_unexecuted(result2["actions"], self.entries())
        self.assertEqual([a["action_kind"] for a in actions], ["record_disposition"])
        executor.execute_actions(
            actions, self.ctx(gh, evidence_ref="docs/working/TASK-0917/evidence/x.md"))
        self.assertEqual(len(gh.push_calls), 1)  # 記録要求では push しない

        # --- run 3: Reconciler が disposition を再構成 → CANDIDATE -------
        state = reconciler.reconcile(self.task_dir, pr_number=PR)
        resolved = reconciler.apply_dispositions(findings, state.dispositions)
        self.assertTrue(delivery._resolved(resolved[0]))
        snap3 = self._collect(gh, findings=resolved)
        result3 = self._assess(snap3)
        self.assertEqual(result3["state"], "MERGE_READY_CANDIDATE")
        actions = reconciler.filter_unexecuted(result3["actions"], self.entries())
        self.assertEqual([a["action_kind"] for a in actions], ["dod_reevaluate"])
        executor.execute_actions(
            actions, self.ctx(gh, evidence_ref="docs/working/TASK-0917/evidence/dod.md"))

        # --- run 4: DoD 判定済み → MERGE_READY（終端）--------------------
        snap4 = self._collect(gh, findings=resolved)
        self.assertTrue(snap4["dod_evaluated"])
        result4 = self._assess(snap4)
        self.assertEqual(result4["state"], "MERGE_READY")
        self.assertEqual(result4["actions"], [])
        self.assertEqual(result4["record"]["head_sha"], H2)

        # --- 冪等: 同じ run をもう一度回しても外部作用ゼロ ---------------
        pushes, comments = len(gh.push_calls), len(gh.comment_calls)
        again = delivery.assess(self._collect(gh, findings=resolved), self.entries())
        executor.execute_actions(
            reconciler.filter_unexecuted(again["actions"], self.entries()),
            self.ctx(gh))
        self.assertEqual((len(gh.push_calls), len(gh.comment_calls)),
                         (pushes, comments))
        # merge / approve / close は一度も組み立てられていない
        self.assertEqual(delivery.TRANSITIONS["MERGE_READY"], [])

    def test_resume_after_push_without_receipt_does_not_double_push(self):
        """TC-09b の 1 周版: push 済み・receipt 未記録で中断 → resume で二重 push しない。"""
        gh = LoopGh(head_sha=H1,
                    checks=[check_run("CI", head_sha=H1, conclusion="failure")],
                    reviews=[review("APPROVED", H1)])
        self.seed([{"kind": "ci_taxonomy", "source": "manual", "pr_number": PR,
                    "head_sha": H1, "taxonomy": "code"}])
        result = self._assess(self._collect(gh))
        action = result["actions"][0]

        # 中断の再現: push だけ済ませ receipt を書かない
        gh.next_head = H2
        gh.push_pr_head(repo=REPO, branch=BRANCH, expected_parent_sha=H1)
        self.assertEqual(len(gh.push_calls), 1)
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])

        # resume: 同一 intent が再要求され、pre-check が二重 push を封じる
        remaining = reconciler.filter_unexecuted([action], self.entries())
        self.assertEqual(len(remaining), 1)
        report = executor.execute_actions(remaining,
                                          self.ctx(gh, repair_commit_sha=H2))
        self.assertEqual(len(gh.push_calls), 1)  # 増えていない
        self.assertEqual(report.outcomes[0].status, executor.STATUS_SKIPPED)
        self.assertEqual(len(self.entries()) and
                         len([e for e in self.entries() if e["kind"] == "receipt"]), 1)


# ---------------------------------------------------------------------------
# AC-5: reconciler.py は外部作用を持たない
# ---------------------------------------------------------------------------

class TestExecBoundary(unittest.TestCase):

    def test_reconciler_has_no_exec_tokens(self):
        import check_exec_boundary as ceb
        source = (HERE / "reconciler.py").read_text(encoding="utf-8")
        self.assertEqual(ceb.check_source("reconciler.py", source), [])

    def test_reconciler_never_calls_gh_exec(self):
        tree = ast.parse((HERE / "reconciler.py").read_text(encoding="utf-8"))
        attrs = {node.attr for node in ast.walk(tree)
                 if isinstance(node, ast.Attribute)}
        for forbidden in ("run_gh", "run_git", "comment_pr", "push_pr_head"):
            self.assertNotIn(forbidden, attrs)


if __name__ == "__main__":
    unittest.main(verbosity=2)
