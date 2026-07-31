#!/usr/bin/env python3
"""test_executor.py — executor.py（唯一の外部書き込み層 / AC-3・AC-5・R-005・R-021）の unittest。

実行: python3 scripts/ai-loop/test_executor.py

契約正本: docs/working/TASK-0917/plan.md
  「R-005（repair push が C-4 承認を stale にする）への対処」
  「外部作用の実行順序と二重作用の封じ込め（R-021 反映 / C-3 論点）」
  Work Breakdown Step 6 / todo.md T-27・T-28・T-51。
カバー: test-cases.md
  TC-07（同一 action_id 再実行で二重作用しない）
  TC-08（canonical_hash の import 再利用・独自実装ゼロ）
  TC-09b（外部作用後・receipt 前の中断 → pre-check で二重 push しない）
  TC-E6（通知コメント失敗 → 握り潰さず escalation / push 回数 0）

設計上の注意:
- **実ネットワークに出ない**。`gh_exec` は fixture（`FakeGh`）を注入して差し替え、
  `subprocess` は一度も呼ばれない（本ファイルは `check_exec_boundary.py` の検査
  対象であり `subprocess` を import しない）。
- 変異注入は **monkeypatch / 一時オブジェクト / mktemp サンドボックス**のみで行い、
  作業ツリーのファイルは 1 バイトも書き換えない。
- `delivery.py` は main の実物を呼ぶ（AC-7: 一行も変更しない）。
"""

from __future__ import annotations

import ast
import hashlib
import json
import pathlib
import shutil
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import c3_contract  # noqa: E402
import collector  # noqa: E402  finding_type 定数表の単一の置き場（T-51）
import delivery  # noqa: E402  判定エンジン / record I/O の実物（AC-7: 変更しない）
import executor  # noqa: E402
import gh_exec  # noqa: E402  Denied / 例外型の単一定義

REPO = "s977043/plangate"
PR = 917
TASK = "TASK-0917"
BRANCH = "feat/task-0917-delivery"
OLD = "1" * 40  # 承認済み head（= expected_parent_sha）
NEW = "2" * 40  # repair commit
OTHER = "3" * 40
NOW = "2026-07-31T00:00:00Z"


# ---------------------------------------------------------------------------
# fixture: gh_exec の差し替え（実ネットワークに出ない）
# ---------------------------------------------------------------------------

class FakeProc:
    """`subprocess.CompletedProcess` の最小互換。"""

    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class FakePush:
    """`gh_exec.PushResult` の最小互換。

    `pushed` は **実際に push が成功したか**。`gh_exec.push_pr_head()` は
    `git push` の rc が非 0 のとき `pushed=False` を返す（R2 B2-1）ため、
    fixture も同じ意味論に揃える。
    """

    def __init__(self, argv=("git", "push"), rc=0):
        self.pushed = rc == 0
        self.argv = tuple(argv)
        self.result = FakeProc(rc, "")


class FakeGh:
    """`gh_exec` モジュールの差し替え。**呼び出し回数を記録する spy**。

    `Denied` は実物を再輸出する（`except gh_exec.Denied` が効くこと）。
    """

    Denied = gh_exec.Denied

    def __init__(self, *, pr_head=OLD, comment_rc=0, comment_url=None,
                 ancestor_rc=None, push_error=None, push_rc=0, ancestry=None):
        self.pr_head = pr_head
        self.comment_rc = comment_rc
        self.comment_url = comment_url or f"https://github.com/{REPO}/pull/{PR}#c1"
        self.ancestor_rc = ancestor_rc
        #: `(ancestor, descendant)` → rc。個別指定が無い組は `ancestor_rc` へ委ねる。
        self.ancestry = dict(ancestry or {})
        self.push_error = push_error
        self.push_rc = push_rc
        self.gh_calls = []
        self.git_calls = []
        self.comment_calls = []
        self.push_calls = []

    # --- 読み取り系 -------------------------------------------------------
    def run_gh(self, args, *, repo, cwd=None):
        self.gh_calls.append(tuple(args))
        if args[:2] == ["pr", "view"]:
            return FakeProc(0, json.dumps({"headRefOid": self.pr_head,
                                           "headRefName": BRANCH,
                                           "baseRefName": "main"}))
        raise AssertionError(f"想定外の gh 呼び出し: {args}")

    def run_git(self, args, *, cwd=None):
        self.git_calls.append(tuple(args))
        if args[:2] == ["merge-base", "--is-ancestor"]:
            key = (args[2], args[3])
            if key in self.ancestry:
                return FakeProc(self.ancestry[key], "")
            if self.ancestor_rc is not None:
                return FakeProc(self.ancestor_rc, "")
            # 既定: 祖先関係なし（= 未適用）
            return FakeProc(1, "")
        raise AssertionError(f"想定外の git 呼び出し: {args}")

    # --- 書き込み系 -------------------------------------------------------
    def comment_pr(self, *, repo, pr_number, body, cwd=None):
        self.comment_calls.append({"pr": pr_number, "body": body})
        if self.comment_rc != 0:
            return FakeProc(self.comment_rc, "", "gh: comment failed")
        return FakeProc(0, self.comment_url + "\n")

    def push_pr_head(self, *, repo, branch, expected_parent_sha, cwd=None):
        self.push_calls.append({"branch": branch,
                                "expected_parent_sha": expected_parent_sha})
        if self.push_error is not None:
            raise self.push_error
        return FakePush(rc=self.push_rc)

    @property
    def write_calls(self) -> int:
        return len(self.comment_calls) + len(self.push_calls)


# ---------------------------------------------------------------------------
# helper
# ---------------------------------------------------------------------------

def _action(kind, payload):
    """`delivery.py` と**同一の**規則で action を組み立てる（テスト側で再実装しない）。"""
    body = dict(payload)
    body["action_kind"] = kind
    return {"action_kind": kind, "action_id": delivery.action_id(body), **payload}


def _intent(action):
    return {"kind": "intent", "action_id": action["action_id"],
            "action_kind": action["action_kind"],
            "payload": {k: v for k, v in action.items()
                        if k not in ("action_id", "action_kind")}}


class SandboxCase(unittest.TestCase):
    """mktemp サンドボックス（作業ツリーを 1 バイトも書き換えない）。"""

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="plangate-test-executor-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.task_dir = self.tmp / TASK
        self.task_dir.mkdir(parents=True)

    def record(self):
        return delivery.record_path(self.task_dir)

    def entries(self):
        return delivery.load_entries(self.record())

    def seed(self, entries):
        delivery.append_entries(self.record(), entries, NOW)

    def ctx(self, gh, **kw):
        params = {"repo": REPO, "branch": BRANCH, "task_dir": self.task_dir,
                  "now": NOW, "gh": gh, "repair_commit_sha": NEW}
        params.update(kw)
        return executor.ExecContext(**params)


# ---------------------------------------------------------------------------
# 6 種の action_kind（新設ゼロ）
# ---------------------------------------------------------------------------

class TestActionKinds(SandboxCase):

    def test_action_kinds_are_exactly_the_six_from_delivery(self):
        """`delivery.py` が発行しうる 6 種と**完全一致**（新 action_kind を作らない）。"""
        source = (HERE / "delivery.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        emitted = set()
        for node in ast.walk(tree):
            if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                    and node.func.id == "_action" and node.args):
                first = node.args[0]
                if isinstance(first, ast.Constant) and isinstance(first.value, str):
                    emitted.add(first.value)
                elif isinstance(first, ast.Name):
                    emitted.update({"repair_review", "record_disposition"})
        self.assertEqual(set(executor.ACTION_KINDS), emitted)
        self.assertEqual(len(executor.ACTION_KINDS), 6)

    def test_notify_kinds_are_a_subset_and_no_new_kind_is_invented(self):
        self.assertEqual(set(executor.NOTIFY_KINDS), {"repair_ci", "repair_review"})
        self.assertTrue(set(executor.NOTIFY_KINDS) <= set(executor.ACTION_KINDS))
        self.assertTrue(set(executor.PUSH_KINDS) <= set(executor.ACTION_KINDS))
        self.assertEqual(set(executor.PUSH_KINDS), set(delivery.REPAIR_KINDS))

    def test_unknown_action_kind_is_refused_without_any_external_effect(self):
        gh = FakeGh()
        action = {"action_kind": "merge_pr", "action_id": "x", "pr_number": PR,
                  "head_sha": OLD}
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(gh.write_calls, 0)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertTrue(any(f.startswith(executor.FLAG_UNKNOWN_ACTION_KIND)
                            for f in report.escalation_flags))

    def test_all_six_kinds_execute_and_record_receipts(self):
        gh = FakeGh()
        actions = [
            _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                  "taxonomy": "code", "failed_checks": ["CI"]}),
            _action("resolve_conflict", {"pr_number": PR, "head_sha": OLD, "round": 1}),
            _action("repair_review", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                      "finding_id": "F-1", "finding_type": "security",
                                      "severity": "critical"}),
            _action("record_disposition", {"pr_number": PR, "head_sha": OLD,
                                           "finding_id": "F-2",
                                           "finding_type": "readability",
                                           "severity": "minor"}),
            _action("feedback_loop_referral", {"pr_number": PR, "head_sha": OLD,
                                               "finding_type": "security"}),
            _action("dod_reevaluate", {"pr_number": PR, "head_sha": OLD}),
        ]
        self.seed([_intent(a) for a in actions])
        ctx = self.ctx(gh, base_sha=OTHER, evidence_ref="docs/evidence/f2.md")
        report = executor.execute_actions(actions, ctx)
        self.assertEqual([o.status for o in report.outcomes],
                         [executor.STATUS_EXECUTED] * 6)
        receipts = {e["action_id"] for e in self.entries() if e["kind"] == "receipt"}
        self.assertEqual(receipts, {a["action_id"] for a in actions})
        # 通知コメントは NOTIFY_KINDS のみが出す。さらに repair_ci /
        # repair_review は **同一 push**（同じ pr/head/repair_commit_sha）を
        # 告げるため run 内で 1 件に集約される（R1 B-13）。
        self.assertEqual(len(gh.comment_calls), 1)
        # push は 3 種の repair kind のみ
        self.assertEqual(len(gh.push_calls), 3)


# ---------------------------------------------------------------------------
# R-021: 実行順序（通知コメント → pre-check → push → receipt）
# ---------------------------------------------------------------------------

class TestOrdering(SandboxCase):

    def _repair_ci(self):
        return _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                     "taxonomy": "code", "failed_checks": ["CI"]})

    def test_comment_is_emitted_before_push(self):
        """R-021 ①: 通知コメントは repair push より **先**に打たれる。"""
        order = []
        gh = FakeGh()
        real_comment, real_push = gh.comment_pr, gh.push_pr_head

        def spy_comment(**kw):
            order.append("comment")
            return real_comment(**kw)

        def spy_push(**kw):
            order.append("push")
            return real_push(**kw)

        gh.comment_pr, gh.push_pr_head = spy_comment, spy_push
        action = self._repair_ci()
        self.seed([_intent(action)])
        executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(order, ["comment", "push"])

    def test_comment_failure_blocks_push_and_escalates(self):
        """TC-E6: コメント失敗 → 握り潰さず escalation・push 回数 0・receipt 無し。"""
        gh = FakeGh(comment_rc=1)
        action = self._repair_ci()
        self.seed([_intent(action)])
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(len(gh.push_calls), 0)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertFalse(report.outcomes[0].pushed)
        self.assertTrue(any(f.startswith(executor.FLAG_COMMENT_FAILED)
                            for f in report.escalation_flags))
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])

    def test_receipt_records_comment_url_as_result_ref(self):
        """R-005 案②: receipt に comment URL を `result_ref` として記録する。"""
        gh = FakeGh(comment_url=f"https://github.com/{REPO}/pull/{PR}#issuecomment-1")
        action = self._repair_ci()
        self.seed([_intent(action)])
        executor.execute_actions([action], self.ctx(gh))
        receipt = next(e for e in self.entries() if e["kind"] == "receipt")
        parts = executor.parse_result_ref(receipt["result_ref"])
        self.assertEqual(parts[executor.PART_COMMENT], gh.comment_url)
        self.assertEqual(parts[executor.PART_ADOPTED], NEW)

    def test_notification_body_is_deterministic_and_carries_both_shas(self):
        action = self._repair_ci()
        body_a = executor.notification_body(action=action, old_sha=OLD, new_sha=NEW)
        body_b = executor.notification_body(action=action, old_sha=OLD, new_sha=NEW)
        self.assertEqual(body_a, body_b)
        self.assertIn(OLD, body_a)
        self.assertIn(NEW, body_a)
        self.assertIn(action["action_id"], body_a)

    def test_missing_repair_commit_blocks_comment_and_push(self):
        """入力不足は **コメントより前**に落とす（余分なコメントすら残さない）。"""
        gh = FakeGh()
        action = self._repair_ci()
        self.seed([_intent(action)])
        report = executor.execute_actions([action],
                                          self.ctx(gh, repair_commit_sha=None))
        self.assertEqual(gh.write_calls, 0)
        self.assertTrue(any(f.startswith(executor.FLAG_MISSING_INPUT)
                            for f in report.escalation_flags))


# ---------------------------------------------------------------------------
# TC-07 / TC-09b: 冪等（AC-3）
# ---------------------------------------------------------------------------

class TestIdempotence(SandboxCase):

    def _repair_ci(self):
        return _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                     "taxonomy": "code", "failed_checks": ["CI"]})

    def test_tc07_receipted_action_causes_no_external_effect(self):
        """TC-07: intent + receipt 済みの同一 action_id を再投入 → gh は一度も呼ばれない。"""
        action = self._repair_ci()
        gh1 = FakeGh()
        self.seed([_intent(action)])
        executor.execute_actions([action], self.ctx(gh1))
        before = len(self.entries())

        gh2 = FakeGh()
        report = executor.execute_actions([action], self.ctx(gh2))
        self.assertEqual(gh2.write_calls, 0)
        self.assertEqual(len(gh2.gh_calls) + len(gh2.git_calls), 0)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_ALREADY_RECEIPTED)
        self.assertEqual(len(self.entries()), before)  # receipt の重複追記なし

    def test_tc09b_precheck_skips_push_when_already_applied(self):
        """TC-09b: intent あり / receipt なし / push は既に PR に反映済み。"""
        action = self._repair_ci()
        self.seed([_intent(action)])
        # PR head が expected_parent_sha より進んでおり、かつ祖先関係が成立
        gh = FakeGh(pr_head=NEW, ancestor_rc=0)
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(len(gh.push_calls), 0)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_SKIPPED)
        receipts = [e for e in self.entries() if e["kind"] == "receipt"]
        self.assertEqual(len(receipts), 1)  # receipt のみが記録される

    def test_precheck_does_not_skip_when_head_equals_expected_parent(self):
        """`merge-base --is-ancestor X X` は exit 0（自分自身も祖先）。

        「PR head と一致するか」の判定を落とすと **常に skip** になり repair が
        永久に push されない。等値ガードが効いていることを固定する。
        """
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh = FakeGh(pr_head=OLD, ancestor_rc=0)
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(len(gh.push_calls), 1)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_EXECUTED)

    def test_comment_is_not_reposted_for_the_same_action_id(self):
        """R-021 ③: 同一 action_id 由来のコメントは再投稿しない（notice entry で追跡）。"""
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh1 = FakeGh(comment_rc=0)
        # push だけ失敗させ、notice は残るが receipt は残らない状態を作る
        gh1.push_error = gh_exec.Denied(gh_exec.REASON_PRECHECK, "テスト用")
        executor.execute_actions([action], self.ctx(gh1))
        self.assertEqual(len(gh1.comment_calls), 1)
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])

        gh2 = FakeGh(comment_rc=0)
        executor.execute_actions([action], self.ctx(gh2))
        self.assertEqual(len(gh2.comment_calls), 0)  # 再投稿しない
        self.assertEqual(len(gh2.push_calls), 1)

    def test_push_failure_is_escalated_and_no_receipt_is_written(self):
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh = FakeGh(push_error=gh_exec.Denied(gh_exec.REASON_PRECHECK, "not ff"))
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertTrue(any(f.startswith(executor.FLAG_PUSH_FAILED)
                            for f in report.escalation_flags))
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])


# ---------------------------------------------------------------------------
# 変異注入（検出力の実証）
# ---------------------------------------------------------------------------

class TestMutationDetection(SandboxCase):

    def _repair_ci(self):
        return _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                     "taxonomy": "code", "failed_checks": ["CI"]})

    def test_mutation_push_before_comment_leaves_irreversible_effect(self):
        """変異①（R-021 の順序反転）: push → comment にすると
        「push 成功・comment 失敗・receipt 無し」= **不可逆作用が残る**。"""
        action = self._repair_ci()
        self.seed([_intent(action)])

        # 実装（正）: コメント失敗 → push 0 回
        gh_real = FakeGh(comment_rc=1)
        executor.execute_actions([action], self.ctx(gh_real))
        self.assertEqual(len(gh_real.push_calls), 0)
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])

        # 変異体（誤）: 先に push してからコメント
        gh_mut = FakeGh(comment_rc=1)
        ctx = self.ctx(gh_mut)
        pushed = executor.perform_push(action, ctx)      # 順序反転を模した呼び出し
        comment = executor.perform_comment(action, ctx)
        self.assertTrue(pushed.pushed)                   # 不可逆作用が発生
        self.assertFalse(comment.ok)                     # そのあとコメントが失敗
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])
        self.assertGreater(len(gh_mut.push_calls), len(gh_real.push_calls))

    def test_mutation_dropping_precheck_causes_double_push_on_resume(self):
        """変異②（pre-check 削除）: 祖先判定 skip を外すと resume で二重 push。"""
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh_real = FakeGh(pr_head=NEW, ancestor_rc=0)
        executor.execute_actions([action], self.ctx(gh_real))
        self.assertEqual(len(gh_real.push_calls), 0)

        # 変異体は **別サンドボックス**（receipt 済み早期 return と混ざらないように）
        mutant_dir = self.tmp / "mutant"
        mutant_dir.mkdir()
        delivery.append_entries(delivery.record_path(mutant_dir),
                                [_intent(action)], NOW)
        gh_mut = FakeGh(pr_head=NEW, ancestor_rc=0)
        original = executor.push_already_applied
        try:
            executor.push_already_applied = lambda *a, **k: (False, None)  # 変異注入
            executor.execute_actions([action],
                                     self.ctx(gh_mut, task_dir=mutant_dir))
        finally:
            executor.push_already_applied = original
        self.assertEqual(len(gh_mut.push_calls), 1)  # 既に反映済みなのに再 push

    def test_mutation_reimplementing_canonical_hash_breaks_receipt_matching(self):
        """変異④（canonical_hash 独自実装）: action_id が変わり receipt 突合が壊れる。"""
        action = self._repair_ci()
        payload = {k: v for k, v in action.items() if k != "action_id"}
        official = c3_contract.canonical_hash(payload)
        self.assertEqual(action["action_id"], official)

        # 独自実装（sort_keys=True だが separators 既定 = 空白入り）
        naive = "sha256:" + hashlib.sha256(
            json.dumps(payload, sort_keys=True).encode("utf-8")).hexdigest()
        self.assertNotEqual(naive, official)

        self.seed([_intent(action)])
        gh = FakeGh()
        executor.execute_actions([action], self.ctx(gh))
        receipts = {e["action_id"] for e in self.entries() if e["kind"] == "receipt"}
        self.assertIn(official, receipts)
        self.assertNotIn(naive, receipts)

    def test_tc08_no_reimplementation_of_canonical_hash_in_executor(self):
        """TC-08: `executor.py` に sha256 / json.dumps(sort_keys=...) の独自記述が無い。"""
        source = (HERE / "executor.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        imported = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(a.name for a in node.names)
        self.assertIn("c3_contract", imported)
        for node in ast.walk(tree):
            if isinstance(node, ast.Attribute):
                self.assertNotEqual(node.attr, "sha256",
                                    "canonical_hash を再実装している")
            if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                    and node.func.attr == "dumps"):
                for kw in node.keywords:
                    self.assertNotEqual(kw.arg, "sort_keys",
                                        "canonical_hash を再実装している")


# ---------------------------------------------------------------------------
# T-51: finding_type 語彙（Collector アダプタと同一定数表）
# ---------------------------------------------------------------------------

class TestFindingTypeVocabulary(SandboxCase):

    def test_executor_imports_the_vocabulary_from_collector(self):
        """定数表の置き場は `collector.py`・`executor.py` は import する（新規モジュール無し）。"""
        source = (HERE / "executor.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        imported = {a.name for node in ast.walk(tree)
                    if isinstance(node, ast.Import) for a in node.names}
        self.assertIn("collector", imported)
        self.assertIs(executor.FINDING_TYPE_VOCABULARY,
                      collector.FINDING_TYPE_VOCABULARY)

    def test_out_of_vocabulary_finding_type_is_refused_before_any_write(self):
        gh = FakeGh()
        action = _action("repair_review", {"pr_number": PR, "head_sha": OLD,
                                           "round": 1, "finding_id": "F-1",
                                           "finding_type": "sec",  # 語彙外
                                           "severity": "critical"})
        self.seed([_intent(action)])
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(gh.write_calls, 0)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertTrue(any(f.startswith(executor.FLAG_FINDING_TYPE_VOCABULARY)
                            for f in report.escalation_flags))

    def test_repair_review_receipt_carries_the_canonical_finding_type(self):
        gh = FakeGh()
        action = _action("repair_review", {"pr_number": PR, "head_sha": OLD,
                                           "round": 1, "finding_id": "F-1",
                                           "finding_type": "security",
                                           "severity": "critical"})
        self.seed([_intent(action)])
        executor.execute_actions([action], self.ctx(gh))
        receipt = next(e for e in self.entries() if e["kind"] == "receipt")
        self.assertEqual(receipt["finding_type"], "security")
        self.assertIn(receipt["finding_type"], collector.FINDING_TYPE_VOCABULARY)


# ---------------------------------------------------------------------------
# result_ref convention / escalation_flags の受け渡し
# ---------------------------------------------------------------------------

class TestResultRefConvention(unittest.TestCase):

    def test_roundtrip(self):
        ref = executor.build_result_ref(((executor.PART_ADOPTED, NEW),
                                         (executor.PART_COMMENT, "https://x/y#1")))
        self.assertEqual(executor.parse_result_ref(ref),
                         {executor.PART_ADOPTED: NEW,
                          executor.PART_COMMENT: "https://x/y#1"})

    def test_parse_is_tolerant_of_unknown_and_empty(self):
        self.assertEqual(executor.parse_result_ref(""), {})
        self.assertEqual(executor.parse_result_ref(None), {})
        self.assertEqual(executor.parse_result_ref("freeform text"), {})

    def test_url_with_colon_survives_roundtrip(self):
        url = "https://github.com/o/r/pull/1#issuecomment-2"
        ref = executor.build_result_ref(((executor.PART_COMMENT, url),))
        self.assertEqual(executor.parse_result_ref(ref)[executor.PART_COMMENT], url)

    def test_apply_escalation_flags_appends_without_duplicates(self):
        snap = {"escalation_flags": ["a"]}
        out = executor.apply_escalation_flags(snap, ["a", "b"])
        self.assertEqual(out["escalation_flags"], ["a", "b"])
        self.assertEqual(snap["escalation_flags"], ["a"])  # 元を破壊しない


# ---------------------------------------------------------------------------
# AC-5: executor.py 自体が gh_exec 以外の外部作用を持たない
# ---------------------------------------------------------------------------

class TestExecBoundary(unittest.TestCase):

    def test_executor_has_no_exec_tokens(self):
        import check_exec_boundary as ceb
        source = (HERE / "executor.py").read_text(encoding="utf-8")
        self.assertEqual(ceb.check_source("executor.py", source), [])

    def test_executor_only_writes_through_gh_exec(self):
        """外部書き込みは `comment_pr` / `push_pr_head` の 2 経路のみ。"""
        tree = ast.parse((HERE / "executor.py").read_text(encoding="utf-8"))
        attrs = {node.attr for node in ast.walk(tree)
                 if isinstance(node, ast.Attribute)}
        self.assertTrue({"comment_pr", "push_pr_head"} <= attrs)
        for forbidden in ("check_call", "Popen", "urlopen", "system"):
            self.assertNotIn(forbidden, attrs)


# ---------------------------------------------------------------------------
# R1 是正の検出力（B-1 / B-5 / B-10 / B-12 / B-13）
# ---------------------------------------------------------------------------

class TestEvidenceRequiredInputs(SandboxCase):
    """B-1 / B-5: `dod_reevaluate` / `record_disposition` は `evidence_ref` 必須。"""

    def _dod(self):
        return _action("dod_reevaluate", {"pr_number": PR, "head_sha": OLD})

    def _disposition(self):
        return _action("record_disposition", {
            "pr_number": PR, "head_sha": OLD, "finding_id": "F-2",
            "finding_type": "readability", "severity": "minor"})

    def test_dod_reevaluate_without_evidence_is_refused(self):
        """B-1: 必須入力ゼロの rubber stamp を作らせない（receipt も書かない）。"""
        gh = FakeGh()
        action = self._dod()
        self.seed([_intent(action)])
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertEqual(gh.write_calls, 0)
        self.assertEqual([e for e in self.entries()
                          if e["kind"] == "receipt"], [])
        self.assertTrue(any(f.startswith(executor.FLAG_MISSING_INPUT)
                            for f in report.escalation_flags))

    def test_dod_reevaluate_receipt_carries_evidence(self):
        gh = FakeGh()
        action = self._dod()
        self.seed([_intent(action)])
        ctx = self.ctx(gh, evidence_ref="docs/evidence/dod.md")
        report = executor.execute_actions([action], ctx)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_EXECUTED)
        receipt = [e for e in self.entries() if e["kind"] == "receipt"][0]
        self.assertEqual(
            collector.receipt_evidence_ref(receipt["result_ref"]),
            "docs/evidence/dod.md")
        self.assertTrue(collector.derive_dod_evaluated(
            self.entries(), PR, OLD))

    def test_record_disposition_does_not_fall_back_to_repair_commit(self):
        """B-5: 記録要求（minor/info）を 1 個の repair SHA で `adopted` 化しない。"""
        gh = FakeGh()
        action = self._disposition()
        self.seed([_intent(action)])
        # repair_commit_sha は ctx 既定で入っている（NEW）。それでも拒否する。
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertEqual(report.outcomes[0].reason,
                         f"{executor.FLAG_MISSING_INPUT}:record_disposition:"
                         "evidence_ref")
        self.assertEqual(gh.write_calls, 0)

    def test_record_disposition_with_evidence_is_rejected_disposition(self):
        gh = FakeGh()
        action = self._disposition()
        self.seed([_intent(action)])
        ctx = self.ctx(gh, evidence_ref="docs/evidence/f2.md")
        executor.execute_actions([action], ctx)
        receipt = [e for e in self.entries() if e["kind"] == "receipt"][0]
        parsed = executor.parse_result_ref(receipt["result_ref"])
        self.assertEqual(parsed.get(executor.PART_REJECTED),
                         "docs/evidence/f2.md")
        self.assertNotIn(executor.PART_ADOPTED, parsed)
        self.assertEqual(parsed.get(executor.PART_FINDING), "F-2")

    def test_repair_review_records_finding_to_commit_correspondence(self):
        """B-5: `adopted` に finding_id を併記し、どの指摘の commit かを残す。"""
        gh = FakeGh()
        action = _action("repair_review", {
            "pr_number": PR, "head_sha": OLD, "round": 1,
            "finding_id": "F-1", "finding_type": "security",
            "severity": "critical"})
        self.seed([_intent(action)])
        executor.execute_actions([action], self.ctx(gh))
        receipt = [e for e in self.entries() if e["kind"] == "receipt"][0]
        parsed = executor.parse_result_ref(receipt["result_ref"])
        self.assertEqual(parsed[executor.PART_ADOPTED], NEW)
        self.assertEqual(parsed[executor.PART_FINDING], "F-1")


class TestActionIdMutationIsKilled(SandboxCase):
    """B-10 変異①: `verify_action_id()` を常に True にすると検出力が消える。"""

    def test_tampered_action_id_causes_no_external_effect(self):
        gh = FakeGh()
        action = _action("repair_ci", {"pr_number": PR, "head_sha": OLD,
                                       "round": 1, "taxonomy": "code",
                                       "failed_checks": ["CI"]})
        self.seed([_intent(action)])
        tampered = dict(action)
        head = tampered["action_id"]
        # 1 文字だけ書き換える（末尾の hex を別の hex へ）
        tampered["action_id"] = head[:-1] + ("0" if head[-1] != "0" else "1")
        self.assertNotEqual(tampered["action_id"], action["action_id"])
        self.assertFalse(executor.verify_action_id(tampered))

        report = executor.execute_actions([tampered], self.ctx(gh))
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertEqual(gh.write_calls, 0,
                         "捏造された action_id で外部作用が発生した")
        self.assertEqual([e for e in self.entries()
                          if e["kind"] in ("receipt", "notice")], [])
        self.assertTrue(any(f.startswith(executor.FLAG_ACTION_ID_MISMATCH)
                            for f in report.escalation_flags))

    def test_mutation_always_true_verifier_lets_it_through(self):
        """検出力の実証: `verify_action_id` を常に True にすると push が起きる。"""
        gh = FakeGh()
        action = _action("repair_ci", {"pr_number": PR, "head_sha": OLD,
                                       "round": 1, "taxonomy": "code",
                                       "failed_checks": ["CI"]})
        self.seed([_intent(action)])
        tampered = dict(action)
        tampered["action_id"] = tampered["action_id"][:-1] + "0"

        original = executor.verify_action_id
        executor.verify_action_id = lambda _action: True
        try:
            executor.execute_actions([tampered], self.ctx(gh))
        finally:
            executor.verify_action_id = original
        self.assertGreater(gh.write_calls, 0,
                           "変異が外部作用を起こさないなら本テストは検出力を持たない")


class TestFailPreservesPriorFlags(SandboxCase):
    """B-12: `_fail()` が先行 `escalation_flag` を落とさない。"""

    def test_ancestry_unknown_and_push_failure_yield_two_flags(self):
        gh = FakeGh(pr_head=OTHER, ancestor_rc=128,   # 祖先判定不能
                    push_error=RuntimeError("boom"))  # push 失敗
        action = _action("repair_ci", {"pr_number": PR, "head_sha": OLD,
                                       "round": 1, "taxonomy": "code",
                                       "failed_checks": ["CI"]})
        self.seed([_intent(action)])
        report = executor.execute_actions([action], self.ctx(gh))
        outcome = report.outcomes[0]
        self.assertEqual(outcome.status, executor.STATUS_FAILED)
        self.assertEqual(len(outcome.escalation_flags), 2, outcome.escalation_flags)
        self.assertTrue(any(f.startswith(executor.FLAG_ANCESTRY_UNKNOWN)
                            for f in outcome.escalation_flags))
        self.assertTrue(any(f.startswith(executor.FLAG_PUSH_FAILED)
                            for f in outcome.escalation_flags))
        # 次 run の snapshot へ両方が伝播する（AC-6 接続点）
        merged = executor.apply_escalation_flags({"escalation_flags": []},
                                                 report.escalation_flags)
        self.assertEqual(len(merged["escalation_flags"]), 2)


class TestNoticeDeduplication(SandboxCase):
    """B-13: 同一 push を告げる通知は run 内で 1 件に集約する。"""

    def _repair_review(self, finding_id):
        return _action("repair_review", {
            "pr_number": PR, "head_sha": OLD, "round": 1,
            "finding_id": finding_id, "finding_type": "security",
            "severity": "critical"})

    def test_multiple_repair_reviews_post_one_comment(self):
        gh = FakeGh()
        actions = [self._repair_review(f"F-{i}") for i in range(1, 4)]
        self.seed([_intent(a) for a in actions])
        report = executor.execute_actions(actions, self.ctx(gh))
        self.assertEqual([o.status for o in report.outcomes],
                         [executor.STATUS_EXECUTED] * 3)
        self.assertEqual(len(gh.comment_calls), 1,
                         "同一 push の通知が finding 数だけ並んだ")
        # 3 件とも同じコメント URL を receipt に載せる（監査の一貫性）
        urls = {executor.parse_result_ref(o.result_ref).get(executor.PART_COMMENT)
                for o in report.outcomes}
        self.assertEqual(urls, {gh.comment_url})

    def test_different_push_target_posts_a_new_comment(self):
        """`repair_commit_sha` が変われば別の push なので通知は再投稿する。"""
        gh = FakeGh()
        first = self._repair_review("F-1")
        self.seed([_intent(first)])
        executor.execute_actions([first], self.ctx(gh))
        self.assertEqual(len(gh.comment_calls), 1)

        second = self._repair_review("F-2")
        self.seed([_intent(second)])
        executor.execute_actions([second], self.ctx(gh, repair_commit_sha=OTHER))
        self.assertEqual(len(gh.comment_calls), 2)

    def test_mutation_action_id_key_reposts_per_finding(self):
        """検出力の実証: 抑止キーを `action_id` に戻すと N 件投稿される。

        旧実装（`notice_urls()` を `action_id` で引く）をそのまま再現する。
        `action_id` は finding ごとに異なるため、同じ push を告げる同内容の
        コメントが finding 数だけ並ぶ。
        """
        gh = FakeGh()
        actions = [self._repair_review(f"F-{i}") for i in range(1, 4)]
        self.seed([_intent(a) for a in actions])

        original_key, original_index = executor.notice_key, executor.notice_index
        executor.notice_key = lambda action, _sha: action["action_id"]
        executor.notice_index = executor.notice_urls
        try:
            executor.execute_actions(actions, self.ctx(gh))
        finally:
            executor.notice_key = original_key
            executor.notice_index = original_index
        self.assertEqual(len(gh.comment_calls), 3)


# ---------------------------------------------------------------------------
# R2 B2-1: comment（可逆）と push（不可逆）の失敗検査は対称であること
# ---------------------------------------------------------------------------

class TestFailureCheckSymmetry(SandboxCase):
    """可逆なコメントだけ rc を検査し、不可逆な push を無検査にしない。

    非対称だと push 失敗が `STATUS_EXECUTED` + receipt になり、`delivery.py` の
    `actions = [a for a in actions if a["action_id"] not in receipts]` により
    **当該 intent が二度と再要求されない**（修正が反映されないまま「repair 済み」
    として loop が進む）。
    """

    def _repair_ci(self):
        return _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                     "taxonomy": "code", "failed_checks": ["CI"]})

    def test_both_helpers_report_rc_in_the_same_shape(self):
        """`perform_comment()` と `perform_push()` は同じ形で rc を返す。"""
        action = self._repair_ci()
        ctx = self.ctx(FakeGh(comment_rc=7, push_rc=9))
        comment = executor.perform_comment(action, ctx)
        push = executor.perform_push(action, ctx)
        self.assertFalse(comment.ok)
        self.assertEqual(comment.reason, "rc=7")
        self.assertFalse(push.pushed)
        self.assertEqual(push.reason, "rc=9")

    def test_push_rc_failure_writes_no_receipt_and_escalates(self):
        """rc≠0 の push → `STATUS_FAILED` / receipt 0 件 / `escalation_flags` あり。"""
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh = FakeGh(push_rc=1)
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(len(gh.push_calls), 1)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_FAILED)
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])
        self.assertTrue(any(f.startswith(executor.FLAG_PUSH_FAILED)
                            for f in report.escalation_flags),
                        report.escalation_flags)

    def test_comment_and_push_failures_are_treated_identically(self):
        """同じ「rc≠0」でも comment 失敗と push 失敗が同じ帰結になる（対称性）。"""
        results = {}
        for label, gh in (("comment", FakeGh(comment_rc=1)),
                          ("push", FakeGh(push_rc=1))):
            with self.subTest(failed=label):
                sandbox = self.tmp / f"sym-{label}"
                sandbox.mkdir()
                action = self._repair_ci()
                delivery.append_entries(delivery.record_path(sandbox),
                                        [_intent(action)], NOW)
                report = executor.execute_actions(
                    [action], self.ctx(gh, task_dir=sandbox))
                entries = delivery.load_entries(delivery.record_path(sandbox))
                results[label] = (
                    report.outcomes[0].status,
                    len([e for e in entries if e["kind"] == "receipt"]),
                    bool(report.escalation_flags))
        self.assertEqual(results["comment"], results["push"], results)
        self.assertEqual(results["push"], (executor.STATUS_FAILED, 0, True))

    def test_mutation_unchecked_push_rc_writes_a_receipt(self):
        """検出力の実証: `perform_push()` の rc 検査を外すと receipt が書かれる。

        是正前の実装（`push_pr_head()` の返り値を見ず常に成功とみなす）を
        monkeypatch で再現し、**同じ rc≠0 の push** に対して判定が反転する
        （receipt 0 件 → 1 件）ことを示す。作業ツリーは書き換えない。
        """
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh_real = FakeGh(push_rc=1)
        executor.execute_actions([action], self.ctx(gh_real))
        self.assertEqual([e for e in self.entries() if e["kind"] == "receipt"], [])

        mutant_dir = self.tmp / "mutant-push-rc"
        mutant_dir.mkdir()
        delivery.append_entries(delivery.record_path(mutant_dir),
                                [_intent(action)], NOW)
        gh_mut = FakeGh(push_rc=1)
        original = executor.perform_push
        try:
            # 変異体: 返り値を検査せず常に成功（= B2-1 是正前の挙動）
            executor.perform_push = lambda *a, **k: executor.PushOutcome(True)
            report = executor.execute_actions(
                [action], self.ctx(gh_mut, task_dir=mutant_dir))
        finally:
            executor.perform_push = original
        mutant_entries = delivery.load_entries(delivery.record_path(mutant_dir))
        self.assertEqual(report.outcomes[0].status, executor.STATUS_EXECUTED)
        self.assertEqual(
            len([e for e in mutant_entries if e["kind"] == "receipt"]), 1,
            "rc 無検査の変異体で receipt が書かれない = テストが空振り")


# ---------------------------------------------------------------------------
# R2 B2-4: pre-check は repair commit そのものの到達可能性で判定する
# ---------------------------------------------------------------------------

class TestPrecheckRepairReachability(SandboxCase):
    """snapshot 採取後に**無関係な commit** が head に載ったケースを skip しない。

    `push_already_applied()` が `expected_parent_sha` の祖先性しか見ないと、
    無関係な commit が 1 つ載っただけで「repair 済み」と誤判定して
    `STATUS_SKIPPED` + receipt を記録し、**当該 repair が永久に push されない**。
    """

    def _repair_ci(self):
        return _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                     "taxonomy": "code", "failed_checks": ["CI"]})

    def _unrelated_head_gh(self):
        """head=OTHER（無関係 commit）。OLD は祖先だが repair(NEW) は未到達。"""
        return FakeGh(pr_head=OTHER, ancestry={(OLD, OTHER): 0, (NEW, OTHER): 1})

    def test_unrelated_commit_on_head_does_not_skip_the_push(self):
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh = self._unrelated_head_gh()
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(len(gh.push_calls), 1, "無関係 commit で repair が skip された")
        self.assertEqual(report.outcomes[0].status, executor.STATUS_EXECUTED)
        self.assertNotIn(executor.PART_SKIPPED,
                         executor.parse_result_ref(report.outcomes[0].result_ref))

    def test_repair_commit_reachable_still_skips(self):
        """repair commit が head から到達可能なら従来どおり skip（正側の維持）。"""
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh = FakeGh(pr_head=NEW, ancestry={(OLD, NEW): 0, (NEW, NEW): 0})
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(len(gh.push_calls), 0)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_SKIPPED)

    def test_unresolved_repair_ancestry_is_flagged_and_pushed(self):
        """repair commit の祖先性が判定不能 → 握り潰さず flag を積んで push を試みる。"""
        action = self._repair_ci()
        self.seed([_intent(action)])
        gh = FakeGh(pr_head=OTHER, ancestry={(OLD, OTHER): 0, (NEW, OTHER): 2})
        report = executor.execute_actions([action], self.ctx(gh))
        self.assertEqual(len(gh.push_calls), 1)
        self.assertTrue(any("repair_commit_ancestry_unresolved" in f
                            for f in report.escalation_flags),
                        report.escalation_flags)

    def test_mutation_parent_only_precheck_skips_forever(self):
        """検出力の実証: 旧判定（`expected_parent_sha` の祖先性のみ）は skip する。"""
        action = self._repair_ci()
        self.seed([_intent(action)])

        def legacy(act, ctx):
            head, reason = executor.fetch_pr_head_sha(ctx)
            if head is None:
                return None, reason
            if head == act.get("head_sha"):
                return False, None
            verdict = executor.is_ancestor(ctx, act.get("head_sha"), head)
            if verdict is None:
                return None, "ancestry_unresolved"
            return bool(verdict), None

        gh_mut = self._unrelated_head_gh()
        original = executor.push_already_applied
        try:
            executor.push_already_applied = legacy
            report = executor.execute_actions([action], self.ctx(gh_mut))
        finally:
            executor.push_already_applied = original
        self.assertEqual(len(gh_mut.push_calls), 0)
        self.assertEqual(report.outcomes[0].status, executor.STATUS_SKIPPED)
        # 旧判定では receipt が書かれ、以後この repair は再要求されない
        self.assertEqual(
            len([e for e in self.entries() if e["kind"] == "receipt"]), 1)


# ---------------------------------------------------------------------------
# R2 B2-3: receipt 済み判定の単一化（Executor / Reconciler 共用）
# ---------------------------------------------------------------------------

class TestReceiptPredicateIsSingleSourced(SandboxCase):

    def test_is_receipted_is_the_only_rule(self):
        action = _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                       "taxonomy": "code", "failed_checks": ["CI"]})
        entries = [_intent(action)]
        receipts = executor.receipt_ids(entries)
        self.assertFalse(executor.is_receipted(action, receipts))
        entries.append({"kind": "receipt", "action_id": action["action_id"]})
        self.assertTrue(executor.is_receipted(action,
                                              executor.receipt_ids(entries)))
        self.assertFalse(executor.is_receipted("文字列", {"x"}))  # 非 dict は False

    def test_reconciler_delegates_to_the_same_predicate(self):
        """`reconciler.filter_unexecuted()` は独自判定を持たない（drift 防止）。"""
        import reconciler  # noqa: PLC0415  依存の向きは reconciler → executor
        action = _action("repair_ci", {"pr_number": PR, "head_sha": OLD, "round": 1,
                                       "taxonomy": "code", "failed_checks": ["CI"]})
        entries = [_intent(action),
                   {"kind": "receipt", "action_id": action["action_id"]}]
        self.assertEqual(reconciler.filter_unexecuted([action], entries), [])

        original = executor.is_receipted
        try:
            executor.is_receipted = lambda a, r: False  # 変異注入
            self.assertEqual(reconciler.filter_unexecuted([action], entries),
                             [action])
        finally:
            executor.is_receipted = original


if __name__ == "__main__":
    unittest.main(verbosity=2)
