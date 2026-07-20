#!/usr/bin/env python3
"""test_c3prime_verify.py — c3prime_verify.py の受理側偽造耐性テスト（#889 敵対的レビュー）。

producer（plan_package.build_c3_prime）を介さず、JSON を手で mutate した偽造 record を
受理器に直接与えて fail-closed を検証する（producer 経由テストが共有する前提を突く）。

実行: python3 scripts/ai-loop/test_c3prime_verify.py
"""
from __future__ import annotations

import copy
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
VERIFY = HERE / "c3prime_verify.py"
sys.path.insert(0, str(HERE))
import plan_package  # noqa: E402
import test_plan_package as tpp  # noqa: E402


def _build_valid(task_dir):
    (task_dir / "approvals").mkdir(exist_ok=True)
    rec = plan_package.build_c3_prime(
        task_dir, task_id="TASK-9999", source_sha="abc1234", target_sha="abc1234",
        verdicts={"model_a": "approve", "model_b": "approve"},
        reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
        decision="AUTO_APPROVED", policy_ref="p@v4",
        issued_at="2100-01-01T00:00:00Z", issued_by="arbiter-v0.1")
    (task_dir / "approvals" / "c3.json").write_text(plan_package.serialize_c3_prime(rec))
    return rec


def _run(task_dir, expected_sha=None):
    args = ["python3", str(VERIFY), str(task_dir)]
    if expected_sha is not None:
        args.append(expected_sha)
    return subprocess.run(args, capture_output=True, text=True).returncode


class C3PrimeVerifyTests(unittest.TestCase):
    def _write(self, task_dir, rec):
        (task_dir / "approvals" / "c3.json").write_text(json.dumps(rec))

    def test_valid_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            _build_valid(d)
            self.assertEqual(_run(d), 0)

    def test_expected_sha_match_and_mismatch(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            _build_valid(d)
            self.assertEqual(_run(d, "abc1234"), 0)      # 一致
            self.assertEqual(_run(d, "fff9999"), 1)      # 不一致 → BLOCK

    def test_forged_mutations_rejected(self):
        # 手 mutate による偽造 record を全パターン reject（#889 critical）
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            base = _build_valid(d)

            def check(label, mutate):
                rec = copy.deepcopy(base)
                mutate(rec)
                self._write(d, rec)
                self.assertEqual(_run(d), 1, f"{label} が reject されない")

            check("c3_status 混入", lambda r: r.update({"c3_status": "APPROVED"}))
            check("未知トップレベルキー", lambda r: r.update({"evil": "x"}))
            check("task_id 欠落", lambda r: r.pop("task_id"))
            check("phase 欠落", lambda r: r.pop("phase"))
            check("phase 不正", lambda r: r.update({"phase": "C-3"}))
            check("c1_evidence_ref 欠落", lambda r: r.pop("c1_evidence_ref"))
            check("policy_ref 空文字", lambda r: r.update({"policy_ref": ""}))
            check("issued_at 欠落", lambda r: r.pop("issued_at"))
            check("decision 契約外", lambda r: r.update({"decision": "unknown"}))
            check("非 AUTO decision", lambda r: r.update({"decision": "HUMAN_ESCALATED"}))
            check("task_id 形式不正", lambda r: r.update({"task_id": "TASK-99"}))
            check("source_sha 形式不正", lambda r: r.update({"source_sha": "XYZ"}))
            check("AUTO+reject 改竄",
                  lambda r: r["reviewers"]["model_a"].update({"verdict": "reject"}))
            check("snapshot hash 不一致",
                  lambda r: r["reviewers"]["model_b"].update({"plan_hash": "sha256:" + "f" * 64}))

    def test_legacy_delegated(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            (d / "approvals").mkdir()
            self._write(d, {"task_id": "TASK-9999", "phase": "C-3",
                            "c3_status": "APPROVED", "approved_by": "h",
                            "approved_at": "2026-01-01T00:00:00Z",
                            "plan_hash": "sha256:" + "0" * 64})
            self.assertEqual(_run(d), 10)

    def test_malformed_approval_kind_rejected(self):
        # approval_kind が present だが c3-prime でない値/型 → legacy 委譲でなく reject
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            (d / "approvals").mkdir()
            for bad in ([], None, 123, "c3-double-prime", ""):
                with self.subTest(bad=bad):
                    self._write(d, {"approval_kind": bad})
                    self.assertEqual(_run(d), 1)

    def test_tampered_plan_hash_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            _build_valid(d)
            (d / "plan.md").write_text((d / "plan.md").read_text() + "x")
            self.assertEqual(_run(d), 1)

    def test_r2_evidence_content_reverified(self):
        # #889 R2 critical: evidence marker を FAIL/reject へ改竄 → reject
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            base = _build_valid(d)
            ph = base["plan_hash"]
            (d / "review-self.md").write_text(f"C1-VERDICT: FAIL plan={ph}\n")
            self.assertEqual(_run(d), 1, "C1=FAIL evidence が受理された")
            (d / "review-self.md").write_text(f"C1-VERDICT: PASS plan={ph}\n")
            (d / "review-external.md").write_text(f"C2-VERDICT: reject plan={ph}\n")
            self.assertEqual(_run(d), 1, "C2=reject evidence が受理された")
            # marker ごと消す
            (d / "review-external.md").write_text("no marker at all\n")
            self.assertEqual(_run(d), 1, "marker 無し evidence が受理された")

    def test_r2_task_id_bound_to_dir(self):
        # #889 R2 high: task_id が task_dir 名と一致しなければ reject
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            base = _build_valid(d)
            rec = copy.deepcopy(base)
            rec["task_id"] = "TASK-0001"
            self._write(d, rec)
            self.assertEqual(_run(d), 1)

    def test_r2_reviewer_independence(self):
        # #889 R2 high: 両 reviewer の evidence_ref 同一（独立性偽装）→ reject
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            base = _build_valid(d)
            rec = copy.deepcopy(base)
            rec["reviewers"]["model_b"] = copy.deepcopy(rec["reviewers"]["model_a"])
            self._write(d, rec)
            self.assertEqual(_run(d), 1)

    def test_r2_nested_schema_parity(self):
        # #889 R2 medium: extra reviewer / snapshot 未知キー / issued_at 不正 / 非 string 注釈
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            base = _build_valid(d)

            def check(label, mutate):
                rec = copy.deepcopy(base)
                mutate(rec)
                self._write(d, rec)
                self.assertEqual(_run(d), 1, f"{label} が reject されない")

            check("extra reviewer",
                  lambda r: r["reviewers"].update({"model_c": copy.deepcopy(r["reviewers"]["model_a"])}))
            check("snapshot 未知キー",
                  lambda r: r["reviewers"]["model_a"].update({"evil": "x"}))
            check("issued_at 不正", lambda r: r.update({"issued_at": "not-a-date"}))
            check("非 string 注釈", lambda r: r.update({"_note": 123}))

    def test_artifact_hashes_individual_tampering(self):
        # Sonnet minor: plan.md 以外の個別 artifact 改竄 → artifact_hashes 不一致で reject
        # （L143-148 の for name in ARTIFACTS ループの回帰網。plan.md はトップレベル
        #  plan_hash チェックで先に落ちるため別ファイルで到達させる）
        for name in ("todo.md", "test-cases.md", "pbi-input.md", "review-external.md"):
            with self.subTest(artifact=name):
                with tempfile.TemporaryDirectory() as tmp:
                    d = tpp._make_task_dir(tmp)
                    _build_valid(d)
                    (d / name).write_text((d / name).read_text() + "x")
                    self.assertEqual(_run(d), 1, f"{name} 改竄が受理された")

    def test_r2_expected_sha_required_at_exec(self):
        # exec 相当（expected_sha 指定）では偽 source_sha を BLOCK
        with tempfile.TemporaryDirectory() as tmp:
            d = tpp._make_task_dir(tmp)
            _build_valid(d)  # source_sha=abc1234
            self.assertEqual(_run(d, "abc1234"), 0)
            self.assertEqual(_run(d, "9999999"), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
