#!/usr/bin/env python3
"""delivery.py（MERGE_READY 状態機械 / TASK-0873・#873）の単体テスト。

test-cases 正本: docs/working/TASK-0873/test-cases.md（TC 番号は同文書と対応）。
producer 非依存の手組み snapshot / record で判定エンジンを検証し、
CLI 統合（c3-prime 入口再検証）は実 task_dir sandbox で検証する。
"""
from __future__ import annotations

import io
import json
import pathlib
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import delivery  # noqa: E402
import plan_package  # noqa: E402
import test_plan_package as tpp  # noqa: E402

NOW = "2100-01-01T00:00:00Z"
H1 = "a" * 40
H2 = "b" * 40


def _snap(**over):
    """有効な基準 snapshot（TC の入力はここからの差分で表現する）。"""
    base = {
        "task_id": "TASK-9999",
        "pr_number": 123,
        "head_sha": H1,
        "source_sha_ancestry": True,
        "mergeable": "MERGEABLE",
        "checks": [{"name": "ci", "sha": H1, "conclusion": "success"}],
        "review": {"state": "approved", "sha": H1},
        "findings": [],
        "changed_files": ["scripts/ai-loop/delivery.py"],
        "allowed_paths": ["scripts/ai-loop/", "tests/extras/", "docs/workflows/ai-loop/"],
        "escalation_flags": [],
        "dod_evaluated": True,
    }
    base.update(over)
    return base


def _finding(fid="F-1", ftype="lint", severity="major", disposition=None):
    return {"id": fid, "finding_type": ftype, "severity": severity,
            "disposition": disposition}


def _receipt(kind, round_, action_id="x" * 8, ftype=None, pr=123, head=H1):
    e = {"kind": "receipt", "action_id": action_id, "action_kind": kind,
         "pr_number": pr, "head_sha": head, "round": round_,
         "result_ref": "evidence/r.log"}
    if ftype is not None:
        e["finding_type"] = ftype
    return e


class AssessStateTests(unittest.TestCase):
    """TC-01/02/03/06/07/14/22/23 — 遷移判定。"""

    def test_tc01_ci_pending_waits(self):
        r = delivery.assess(_snap(checks=[{"name": "ci", "sha": H1, "conclusion": "pending"}]), [])
        self.assertEqual(r["state"], "WAITING_FOR_CHECKS")
        self.assertNotEqual(r["state"], "MERGE_READY")

    def test_tc02_review_pending_waits(self):
        r = delivery.assess(_snap(review={"state": "pending", "sha": H1}), [])
        self.assertEqual(r["state"], "WAITING_FOR_REVIEW")

    def test_tc03_ci_fail_code_then_green(self):
        r1 = delivery.assess(_snap(
            checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
            ci_failure_taxonomy="code"), [])
        self.assertEqual(r1["state"], "CHECKS_FAILED")
        kinds = [a["action_kind"] for a in r1["actions"]]
        self.assertIn("repair_ci", kinds)
        self.assertEqual(r1["actions"][0]["round"], 1)
        # repair 後: 新 head で全 green + review 着弾 + disposition なし → MERGE_READY
        entries = [_receipt("repair_ci", 1)]
        r2 = delivery.assess(_snap(
            head_sha=H2,
            checks=[{"name": "ci", "sha": H2, "conclusion": "success"}],
            review={"state": "approved", "sha": H2}), entries)
        self.assertEqual(r2["state"], "MERGE_READY")
        self.assertEqual(r2["record"]["round"], 1)
        # 負側 (R-001): 旧 head の green では MERGE_READY にならない
        r3 = delivery.assess(_snap(
            head_sha=H2,
            checks=[{"name": "ci", "sha": H1, "conclusion": "success"}],
            review={"state": "approved", "sha": H2}), entries)
        self.assertEqual(r3["state"], "WAITING_FOR_CHECKS")
        # 負側 (R-001): review 未着弾では MERGE_READY にならない
        r4 = delivery.assess(_snap(
            head_sha=H2,
            checks=[{"name": "ci", "sha": H2, "conclusion": "success"}],
            review={"state": "pending", "sha": H2}), entries)
        self.assertEqual(r4["state"], "WAITING_FOR_REVIEW")

    def test_tc06_stale_ci_on_old_sha(self):
        r = delivery.assess(_snap(
            head_sha=H2,
            checks=[{"name": "ci", "sha": H1, "conclusion": "success"}],
            review={"state": "approved", "sha": H2}), [])
        self.assertEqual(r["state"], "WAITING_FOR_CHECKS")

    def test_tc07_conflict_and_resolution(self):
        r1 = delivery.assess(_snap(mergeable="CONFLICTING"), [])
        self.assertEqual(r1["state"], "CONFLICT")
        self.assertIn("resolve_conflict", [a["action_kind"] for a in r1["actions"]])
        # 三点照合欠落 → 解消と認めない（fail-closed で CONFLICT のまま）
        r2 = delivery.assess(_snap(
            mergeable="MERGEABLE",
            conflict_resolution={"base_sha": H1, "head_sha": H2, "result_sha": ""}), [])
        self.assertEqual(r2["state"], "CONFLICT")
        # 三点照合つき解消 → CI/review 再評価が強制される（旧 head の checks は stale）
        r3 = delivery.assess(_snap(
            head_sha=H2,
            mergeable="MERGEABLE",
            conflict_resolution={"base_sha": H1, "head_sha": H2, "result_sha": H2},
            checks=[{"name": "ci", "sha": H1, "conclusion": "success"}]), [])
        self.assertEqual(r3["state"], "WAITING_FOR_CHECKS")

    def test_tc14_plan_deviation_exec_return(self):
        r = delivery.assess(_snap(changed_files=["bin/plangate"]), [])
        self.assertEqual(r["state"], "EXEC_RETURN")
        self.assertIn("bin/plangate", json.dumps(r["reasons"]))

    def test_tc22_same_type_recurrence_referral(self):
        entries = [_receipt("repair_review", 1, ftype="lint")]
        r = delivery.assess(_snap(findings=[_finding(ftype="lint")]), entries)
        self.assertEqual(r["state"], "REVIEW_REPAIR")
        self.assertIn("feedback_loop_referral", [a["action_kind"] for a in r["actions"]])

    def test_tc23_candidate_not_shortcut(self):
        resolved_minor = _finding(severity="minor",
                                  disposition={"kind": "rejected", "evidence_ref": "e.log"})
        r1 = delivery.assess(_snap(findings=[resolved_minor], dod_evaluated=False), [])
        self.assertEqual(r1["state"], "MERGE_READY_CANDIDATE")
        self.assertIn("dod_reevaluate", [a["action_kind"] for a in r1["actions"]])
        r2 = delivery.assess(_snap(findings=[resolved_minor], dod_evaluated=True), [])
        self.assertEqual(r2["state"], "MERGE_READY")


class EscalationTests(unittest.TestCase):
    """TC-08/09/13/21/E1/E3 + escalation_flags — fail-closed 系。"""

    def test_priority1_escalation_flags(self):
        r = delivery.assess(_snap(escalation_flags=["touches_ho"]), [])
        self.assertEqual(r["state"], "HUMAN_ESCALATED")

    def test_tc08_round_limit(self):
        entries = [_receipt("repair_ci", 1), _receipt("repair_ci", 2), _receipt("repair_ci", 3)]
        r = delivery.assess(_snap(
            checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
            ci_failure_taxonomy="code"), entries)
        self.assertEqual(r["state"], "HUMAN_ESCALATED")

    def test_tcE1_round3_still_allowed(self):
        entries = [_receipt("repair_ci", 1), _receipt("repair_ci", 2)]
        r = delivery.assess(_snap(
            checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
            ci_failure_taxonomy="code"), entries)
        self.assertEqual(r["state"], "CHECKS_FAILED")
        self.assertEqual(r["actions"][0]["round"], 3)

    def test_tc09_tc13_taxonomy(self):
        for tax in ("code", "flaky", "environment"):
            r = delivery.assess(_snap(
                checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
                ci_failure_taxonomy=tax), [])
            self.assertEqual(r["state"], "CHECKS_FAILED", tax)
        for tax in ("permission", "unknown", "totally-bogus", None):
            r = delivery.assess(_snap(
                checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
                ci_failure_taxonomy=tax), [])
            self.assertEqual(r["state"], "HUMAN_ESCALATED", tax)

    def test_tc21_tcE3_ancestry_fail_closed(self):
        for val in (False, None):
            r = delivery.assess(_snap(source_sha_ancestry=val), [])
            self.assertEqual(r["state"], "HUMAN_ESCALATED", repr(val))
            self.assertNotEqual(r["state"], "MERGE_READY")


class DispositionTests(unittest.TestCase):
    """TC-04/05/E4 — review disposition 追跡。"""

    def test_tc04_major_repair_then_resolved(self):
        r1 = delivery.assess(_snap(findings=[_finding()]), [])
        self.assertEqual(r1["state"], "REVIEW_REPAIR")
        self.assertIn("repair_review", [a["action_kind"] for a in r1["actions"]])
        resolved = _finding(disposition={"kind": "adopted", "repair_commit": "c" * 7})
        r2 = delivery.assess(_snap(head_sha=H2,
                                   checks=[{"name": "ci", "sha": H2, "conclusion": "success"}],
                                   review={"state": "approved", "sha": H2},
                                   findings=[resolved]), [])
        self.assertEqual(r2["state"], "MERGE_READY")

    def test_tc05_rejected_requires_evidence(self):
        no_ev = _finding(disposition={"kind": "rejected", "evidence_ref": ""})
        r1 = delivery.assess(_snap(findings=[no_ev]), [])
        self.assertEqual(r1["state"], "REVIEW_REPAIR")
        with_ev = _finding(disposition={"kind": "rejected", "evidence_ref": "e.log"})
        r2 = delivery.assess(_snap(findings=[with_ev]), [])
        self.assertEqual(r2["state"], "MERGE_READY")

    def test_tcE4_one_unresolved_blocks(self):
        fs = [
            _finding("F-1", disposition={"kind": "adopted", "repair_commit": "c" * 7}),
            _finding("F-2", disposition={"kind": "rejected", "evidence_ref": "e.log"}),
            _finding("F-3", severity="minor"),
        ]
        r = delivery.assess(_snap(findings=fs), [])
        self.assertNotEqual(r["state"], "MERGE_READY")
        self.assertNotEqual(r["state"], "MERGE_READY_CANDIDATE")


class IdempotencyTests(unittest.TestCase):
    """TC-10/15/16/E5/E6 — stable action ID・intent/receipt・record。"""

    def _record_path(self, tmp):
        return pathlib.Path(tmp) / "delivery" / "record.jsonl"

    def test_tc10_same_snapshot_twice_no_dup(self):
        snap = _snap(checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
                     ci_failure_taxonomy="code")
        r1 = delivery.assess(snap, [])
        entries = list(r1["new_entries"])
        r2 = delivery.assess(snap, entries)
        self.assertEqual(r2["new_entries"], [])
        self.assertEqual([a["action_id"] for a in r1["actions"]],
                         [a["action_id"] for a in r2["actions"]])

    def test_tc10_distinct_findings_not_suppressed(self):
        snap = _snap(findings=[_finding("F-1"), _finding("F-2", ftype="typo")])
        r = delivery.assess(snap, [])
        ids = [a["action_id"] for a in r["actions"] if a["action_kind"] == "repair_review"]
        self.assertEqual(len(ids), 2)
        self.assertEqual(len(set(ids)), 2)

    def test_tcE5_intent_without_receipt_rerequested(self):
        snap = _snap(checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
                     ci_failure_taxonomy="code")
        r1 = delivery.assess(snap, [])
        entries = list(r1["new_entries"])  # intent のみ・receipt なし
        r2 = delivery.assess(snap, entries)
        self.assertEqual(len(r2["actions"]), 1)  # 再要求される（実行ゼロ回に終わらない）
        self.assertEqual(r2["new_entries"], [])  # record は重複しない

    def test_tcE6_receipt_suppresses(self):
        snap = _snap(checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
                     ci_failure_taxonomy="code")
        r1 = delivery.assess(snap, [])
        aid = r1["actions"][0]["action_id"]
        entries = list(r1["new_entries"]) + [
            {"kind": "receipt", "action_id": aid, "action_kind": "repair_ci",
             "round": 1, "result_ref": "evidence/r.log"}]
        r2 = delivery.assess(snap, entries)
        self.assertEqual([a for a in r2["actions"] if a["action_id"] == aid], [])

    def test_tc16_merge_ready_record_fields(self):
        r = delivery.assess(_snap(), [])
        self.assertEqual(r["state"], "MERGE_READY")
        rec = r["record"]
        for key in ("pr_number", "head_sha", "check_summary", "review_disposition",
                    "round", "plan_hash"):
            self.assertIn(key, rec, key)
        # raw log 本文を含めない: check_summary は name→conclusion のみ
        self.assertEqual(rec["check_summary"], {"ci": "success"})

    def test_tc15_append_idempotent_on_disk(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._record_path(tmp)
            snap = _snap(checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
                         ci_failure_taxonomy="code")
            r1 = delivery.assess(snap, [])
            n1 = delivery.append_entries(path, r1["new_entries"], NOW)
            self.assertGreater(n1, 0)
            before = path.read_text(encoding="utf-8")
            entries = delivery.load_entries(path)
            r2 = delivery.assess(snap, entries)
            n2 = delivery.append_entries(path, r2["new_entries"], NOW)
            self.assertEqual(n2, 0)
            self.assertEqual(path.read_text(encoding="utf-8"), before)


class ContractTests(unittest.TestCase):
    """TC-11/17/18(unit 相当) — 機械可読契約・NO MERGE。"""

    def test_tc11_contract_deterministic(self):
        self.assertEqual(delivery.contract_json(), delivery.contract_json())
        data = json.loads(delivery.contract_json())
        self.assertEqual(data["terminal"], "MERGE_READY")

    def test_tc17_no_merged_transition(self):
        dump = json.dumps(delivery.contract_dict())
        self.assertNotIn("MERGED", dump)
        self.assertEqual(delivery.TRANSITIONS["MERGE_READY"], [])

    def test_tc18_pure_verdict_source(self):
        src = (pathlib.Path(delivery.__file__)).read_text(encoding="utf-8")
        for token in ("subprocess", "os.system", "urllib", "socket",
                      "http.client", "requests", "gh pr merge", "merge_pull_request"):
            self.assertNotIn(token, src, token)


class SnapshotValidationTests(unittest.TestCase):
    """TC-E2 — 壊れた snapshot は fail-closed（対象キー名を明示）。"""

    def test_empty_snapshot(self):
        reasons = delivery.validate_snapshot({})
        self.assertTrue(reasons)
        self.assertIn("head_sha", json.dumps(reasons))

    def test_type_mismatch(self):
        reasons = delivery.validate_snapshot(_snap(pr_number="123"))
        self.assertIn("pr_number", json.dumps(reasons))

    def test_assess_raises_on_invalid(self):
        with self.assertRaises(delivery.SnapshotError):
            delivery.assess({}, [])


def _make_approved_task(tmp):
    d = tpp._make_task_dir(tmp)  # TASK-9999
    (d / "approvals").mkdir(exist_ok=True)
    rec = plan_package.build_c3_prime(
        d, task_id="TASK-9999", source_sha="abc1234", target_sha="abc1234",
        verdicts={"model_a": "approve", "model_b": "approve"},
        reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
        decision="AUTO_APPROVED", policy_ref="p@v4",
        issued_at="2100-01-01T00:00:00Z", issued_by="arbiter-v0.1")
    (d / "approvals" / "c3.json").write_text(plan_package.serialize_c3_prime(rec))
    return d


class CliIntegrationTests(unittest.TestCase):
    """TC-19/20 + legacy BLOCK（R-009）+ receipt CLI — c3-prime 入口再検証。"""

    def _run(self, argv):
        # assess は expected-sha 必須（A-08）。未指定なら c3-prime source_sha に
        # 一致する既定値を注入（fixture の build_c3_prime source_sha="abc1234"）。
        if len(argv) > 1 and argv[1] == "assess" and "--expected-sha" not in argv:
            argv = argv + ["--expected-sha", "abc1234"]
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = delivery.main(argv)
        return rc, out.getvalue(), err.getvalue()

    def _snap_file(self, d, snap):
        p = pathlib.Path(d) / "snapshot.json"
        p.write_text(json.dumps(snap), encoding="utf-8")
        return str(p)

    def test_valid_record_assess_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            sf = self._snap_file(tmp, _snap())
            rc, out, _ = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", sf, "--now", NOW])
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(out)["state"], "MERGE_READY")
            record = json.loads(out)["record"]
            self.assertTrue(record["plan_hash"].startswith("sha256:"))

    def test_tc19_non_auto_approved_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            c3 = d / "approvals" / "c3.json"
            data = json.loads(c3.read_text())
            data["decision"] = "HUMAN_ESCALATED"
            c3.write_text(json.dumps(data, indent=2, sort_keys=True))
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", self._snap_file(tmp, _snap()),
                                    "--now", NOW])
            self.assertEqual(rc, 3)
            self.assertIn("BLOCK", err)

    def test_tc20_tampered_record_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            with open(d / "plan.md", "a", encoding="utf-8") as f:
                f.write("x")  # stale 改竄
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", self._snap_file(tmp, _snap()),
                                    "--now", NOW])
            self.assertEqual(rc, 3)
            # 改竄は evidence stale（marker の plan hash 照合）が先に検出する。
            # どちらの経路でも「plan.md との不一致 → BLOCK」の契約は同一。
            self.assertIn("stale", err)
            self.assertIn("plan", err)

    def test_legacy_c3_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            (d / "approvals" / "c3.json").write_text(
                '{"task_id":"TASK-9999","phase":"C-3","c3_status":"APPROVED",'
                '"plan_hash":"sha256:%s"}' % ("0" * 64))
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", self._snap_file(tmp, _snap()),
                                    "--now", NOW])
            self.assertEqual(rc, 3)
            self.assertIn("legacy", err)

    def test_expected_sha_mismatch_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", self._snap_file(tmp, _snap()),
                                    "--expected-sha", "f" * 40, "--now", NOW])
            self.assertEqual(rc, 3)

    def test_invalid_snapshot_exit2(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", self._snap_file(tmp, {}),
                                    "--now", NOW])
            self.assertEqual(rc, 2)
            self.assertIn("head_sha", err)

    def test_receipt_flow_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            sf = self._snap_file(tmp, _snap(
                checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
                ci_failure_taxonomy="code"))
            rc, out, _ = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", sf, "--now", NOW])
            self.assertEqual(rc, 0)
            aid = json.loads(out)["actions"][0]["action_id"]
            rc, _, _ = self._run(["delivery", "receipt", "--task-dir", str(d),
                                  "--action-id", aid, "--result-ref", "evidence/r.log",
                                  "--now", NOW])
            self.assertEqual(rc, 0)
            record = d / "delivery" / "record.jsonl"
            n_lines = len(record.read_text().splitlines())
            rc, _, _ = self._run(["delivery", "receipt", "--task-dir", str(d),
                                  "--action-id", aid, "--result-ref", "evidence/r.log",
                                  "--now", NOW])
            self.assertEqual(rc, 0)
            self.assertEqual(len(record.read_text().splitlines()), n_lines)
            # receipt 済みアクションは次 assess で要求されない
            rc, out, _ = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", sf, "--now", NOW])
            self.assertEqual(rc, 0)
            self.assertEqual(
                [a for a in json.loads(out)["actions"] if a["action_id"] == aid], [])

    def test_receipt_unknown_action_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            rc, _, err = self._run(["delivery", "receipt", "--task-dir", str(d),
                                    "--action-id", "sha256:" + "0" * 64,
                                    "--result-ref", "e", "--now", NOW])
            self.assertEqual(rc, 2)

    def test_a01_cross_task_snapshot_blocked(self):
        # A-01/B-03: 別 TASK の snapshot をこの承認へ流し込めない
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            sf = self._snap_file(tmp, _snap(task_id="TASK-0001"))
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", sf, "--now", NOW])
            self.assertEqual(rc, 3)
            self.assertIn("task_id", err)

    def test_a08_missing_expected_sha_exit2(self):
        # A-08: expected-sha 未指定は受理しない（_run の自動注入を回避して検証）
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            sf = self._snap_file(tmp, _snap())
            out, err = io.StringIO(), io.StringIO()
            with redirect_stdout(out), redirect_stderr(err):
                rc = delivery.main(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", sf, "--now", NOW])
            self.assertEqual(rc, 2)
            self.assertIn("expected-sha", err.getvalue())

    def test_b04_broken_record_fail_closed(self):
        # B-04: 壊れた record.jsonl は生 traceback でなく制御された BLOCK
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            rp = d / "delivery" / "record.jsonl"
            rp.parent.mkdir(parents=True, exist_ok=True)
            rp.write_text('{"kind": "state"\nNOT JSON{{{\n', encoding="utf-8")
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", self._snap_file(tmp, _snap()),
                                    "--now", NOW])
            self.assertEqual(rc, 3)
            self.assertIn("壊れ", err)

    def test_a05_forged_entry_id_fail_closed(self):
        # A-05: 予測 entry_id を先行投入して append を抑止する手を封じる
        with tempfile.TemporaryDirectory() as tmp:
            d = _make_approved_task(tmp)
            rp = d / "delivery" / "record.jsonl"
            rp.parent.mkdir(parents=True, exist_ok=True)
            # entry_id が本体と不一致な行 → load 時に fail-closed
            rp.write_text(json.dumps({"entry_id": "forged", "kind": "junk"}) + "\n",
                          encoding="utf-8")
            rc, _, err = self._run(["delivery", "assess", "--task-dir", str(d),
                                    "--snapshot", self._snap_file(tmp, _snap()),
                                    "--now", NOW])
            self.assertEqual(rc, 3)
            self.assertIn("entry_id", err)


class R1RegressionTests(unittest.TestCase):
    """R1 敵対レビュー（A-01〜A-08 / B-01〜B-05）の純関数レベル回帰。"""

    def test_b01_unknown_mergeable_rejected_at_validation(self):
        for val in ("unknown", "garbage", "dirty", "blocked"):
            reasons = delivery.validate_snapshot(_snap(mergeable=val))
            self.assertIn("mergeable", json.dumps(reasons), val)

    def test_b01_unknown_mergeable_not_merge_ready(self):
        # UNKNOWN（GitHub 計算中）は enum 内だが MERGEABLE でない → conflict 側
        r = delivery.assess(_snap(mergeable="UNKNOWN"), [])
        self.assertNotEqual(r["state"], "MERGE_READY")
        self.assertEqual(r["state"], "CONFLICT")

    def test_b02_unknown_severity_rejected_at_validation(self):
        for val in ("blocker", "P0", "showstopper"):
            reasons = delivery.validate_snapshot(_snap(
                findings=[_finding(severity=val)]))
            self.assertIn("severity", json.dumps(reasons), val)

    def test_b02_unknown_disposition_kind_rejected(self):
        reasons = delivery.validate_snapshot(_snap(
            findings=[_finding(disposition={"kind": "wontfix"})]))
        self.assertTrue(reasons)

    def test_a03_path_boundary_not_prefix(self):
        # scripts/foo は scripts/foobar.py にマッチしない
        r = delivery.assess(_snap(allowed_paths=["scripts/foo"],
                                  changed_files=["scripts/foobar.py"]), [])
        self.assertEqual(r["state"], "EXEC_RETURN")
        # ディレクトリ許可（末尾 /）は配下にマッチ
        r2 = delivery.assess(_snap(allowed_paths=["scripts/foo/"],
                                   changed_files=["scripts/foo/x.py"]), [])
        self.assertNotEqual(r2["state"], "EXEC_RETURN")

    def test_a06_unrelated_pr_receipt_not_counted(self):
        # 別 PR の repair_review receipt は recurrence / round に混ざらない
        other = _receipt("repair_review", 1, ftype="security", pr=999)
        r = delivery.assess(_snap(findings=[_finding(ftype="security")]), [other])
        self.assertEqual(r["state"], "REVIEW_REPAIR")
        # recurrence 扱いされない → feedback_loop_referral は出ない
        self.assertNotIn("feedback_loop_referral",
                         [a["action_kind"] for a in r["actions"]])
        # 同一 PR の receipt なら recurrence 扱い
        same = _receipt("repair_review", 1, ftype="security", pr=123)
        r2 = delivery.assess(_snap(findings=[_finding(ftype="security")]), [same])
        self.assertIn("feedback_loop_referral",
                      [a["action_kind"] for a in r2["actions"]])

    def test_a06_round_pr_scoped(self):
        # 別 PR の round=3 receipt は round 上限に影響しない
        other = _receipt("repair_ci", 3, pr=999)
        r = delivery.assess(_snap(
            checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
            ci_failure_taxonomy="code"), [other])
        self.assertEqual(r["state"], "CHECKS_FAILED")  # round 1 扱い（escalate しない）
        self.assertEqual(r["actions"][0]["round"], 1)

    def test_a05_string_round_ignored(self):
        # 文字列 round / 負値 round は集計対象外
        junk = {"kind": "receipt", "action_kind": "repair_ci", "pr_number": 123,
                "round": "3", "action_id": "z"}
        r = delivery.assess(_snap(
            checks=[{"name": "ci", "sha": H1, "conclusion": "failure"}],
            ci_failure_taxonomy="code"), [junk])
        self.assertEqual(r["actions"][0]["round"], 1)

    def test_b2_11_disposition_recorded_content_is_c4_scope(self):
        # R2 B2-11: rejected+evidence_ref の finding は resolved 扱いで MERGE_READY
        # に到達する（記録の存在を機械保証）。evidence_ref 内容の真正性は C-4 の
        # 責務（doc §5 で明文化）。全 disposition が record に残ることを保証。
        fs = [{"id": f"F-{i}", "finding_type": "logic", "severity": "major",
               "disposition": {"kind": "rejected", "evidence_ref": f"e-{i}.log"}}
              for i in range(3)]
        r = delivery.assess(_snap(findings=fs), [])
        self.assertEqual(r["state"], "MERGE_READY")
        # review_disposition に全 finding が残り C-4 で追跡可能
        self.assertEqual(set(r["record"]["review_disposition"]), {"F-0", "F-1", "F-2"})

    def test_b2_path_boundary_empty_and_root(self):
        # 空文字 / "/" のみの allowed は誤許可しない（fail-closed 寄り）
        self.assertFalse(delivery._path_allowed("scripts/x.py", [""]))
        self.assertFalse(delivery._path_allowed("scripts/x.py", ["/"]))
        self.assertFalse(delivery._path_allowed("anything", ["/"]))

    def test_a07_contract_matches_stateless(self):
        # MERGE_READY のみ終端。非終端は全状態へ到達可（stateless の正直な表現）
        t = delivery.TRANSITIONS
        self.assertEqual(t["MERGE_READY"], [])
        for s in ("CHECKS_FAILED", "CONFLICT", "WAITING_FOR_CHECKS"):
            self.assertIn("MERGE_READY", t[s])
            self.assertIn("MERGE_READY_CANDIDATE", t[s])


class RiverReviewFixTests(unittest.TestCase):
    """RV-1/RV-3/RV-4（River Review 2026-07-23）— conclusion allowlist と監査束縛。"""

    def test_rv1_terminal_failure_conclusions_are_failed_not_pending(self):
        # cancelled / timed_out 等は pending 扱い（livelock）にせず failed 群へ
        for concl in ("cancelled", "timed_out", "action_required",
                      "startup_failure"):
            r = delivery.assess(_snap(
                checks=[{"name": "ci", "sha": H1, "conclusion": concl}],
                ci_failure_taxonomy="code"), [])
            self.assertEqual(r["state"], "CHECKS_FAILED", concl)
            self.assertIn("repair_ci",
                          [a["action_kind"] for a in r["actions"]], concl)

    def test_rv1_terminal_failure_with_unverifiable_taxonomy_escalates(self):
        r = delivery.assess(_snap(
            checks=[{"name": "ci", "sha": H1, "conclusion": "cancelled"}]), [])
        self.assertEqual(r["state"], "HUMAN_ESCALATED")

    def test_rv1_unknown_conclusion_escalates_fail_closed(self):
        r = delivery.assess(_snap(
            checks=[{"name": "ci", "sha": H1, "conclusion": "totally_new"}]), [])
        self.assertEqual(r["state"], "HUMAN_ESCALATED")
        self.assertTrue(any("未知の check conclusion" in x for x in r["reasons"]))

    def test_rv1_skipped_and_neutral_do_not_block_green(self):
        r = delivery.assess(_snap(checks=[
            {"name": "ci", "sha": H1, "conclusion": "success"},
            {"name": "sync", "sha": H1, "conclusion": "skipped"},
            {"name": "lint", "sha": H1, "conclusion": "neutral"}]), [])
        self.assertEqual(r["state"], "MERGE_READY")

    def test_rv3_priority_order_declares_unverifiable_before_recurrence(self):
        order = delivery.PRIORITY_ORDER
        self.assertLess(order.index("unknown_check_conclusion"),
                        order.index("round_limit"))
        self.assertLess(order.index("taxonomy_unverifiable"),
                        order.index("same_type_recurrence"))

    def test_rv4_state_entry_bound_to_pr_number(self):
        r = delivery.assess(_snap(), [])
        states = [e for e in r["new_entries"] if e.get("kind") == "state"]
        self.assertTrue(states)
        self.assertEqual(states[0]["pr_number"], 123)


if __name__ == "__main__":
    unittest.main(verbosity=2)
