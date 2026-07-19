#!/usr/bin/env python3
"""test_plan_package.py — plan_package.py の unittest カバレッジ（外部依存なし）。

実行: python3 scripts/ai-loop/test_plan_package.py

契約正本: docs/workflows/ai-loop/c3-prime-contract.md（TASK-0872 T-2）
カバー: TC-01(層2) / TC-02 / TC-03(表駆動) / TC-04 / TC-06 / TC-08a / TC-09(Unit) /
TC-11 / EC-1 / EC-3（test-cases.md の対応表参照）
"""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import plan_package  # noqa: E402

PLAN_BODY = """# EXECUTION PLAN — TASK-9999

## Goal

sandbox タスクの目的記述。

## Files / Components to Touch

**PR-1**: `scripts/ai-loop/sandbox_a.py` / `docs/workflows/ai-loop/sandbox.md`

## Testing Strategy

- Unit: sandbox
- Verification Automation: `true && echo ok`

## Mode判定

**モード**: standard
"""

REVIEW_SELF_PASS = """# C-1 セルフレビュー — TASK-9999

> 判定: **PASS**（WARN 0 件・FAIL 0 件）
"""

REVIEW_EXTERNAL_OK = """# C-2 外部レビュー結果 — TASK-9999

総合判定: approve
"""


def _make_task_dir(tmp, omit=(), empty=(), c1_text=REVIEW_SELF_PASS, c2_text=REVIEW_EXTERNAL_OK):
    """sandbox の Plan Package 6 要素を生成する。omit で欠落・empty で 0 byte を再現。"""
    task_dir = pathlib.Path(tmp) / "TASK-9999"
    task_dir.mkdir(parents=True, exist_ok=True)
    contents = {
        "pbi-input.md": "# PBI INPUT — TASK-9999\n",
        "plan.md": PLAN_BODY,
        "todo.md": "# TODO\n- [ ] T-1\n",
        "test-cases.md": "# TEST CASES\n| AC-1 | TC-01 |\n",
        "review-self.md": c1_text,
        "review-external.md": c2_text,
    }
    for name, body in contents.items():
        if name in omit:
            continue
        path = task_dir / name
        path.write_text("" if name in empty else body, encoding="utf-8")
    # evidence を plan.md より新しくする（stale でない状態が既定）
    now = 4102444800  # 2100-01-01 固定（決定論）
    for name in contents:
        p = task_dir / name
        if p.exists():
            os.utime(p, (now, now))
    for name in ("review-self.md", "review-external.md"):
        p = task_dir / name
        if p.exists():
            os.utime(p, (now + 60, now + 60))
    return task_dir


def _sha256_hex(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class TaskIdTests(unittest.TestCase):
    """TC-01 層 2: task_id 形式検証（fail-closed）。"""

    def test_valid_task_id(self):
        self.assertEqual(plan_package.validate_task_id("TASK-9999"), [])

    def test_invalid_task_ids(self):
        for bad in ("", None, "task-9999", "TASK-999", "TASK-08722", "run sandbox 説明"):
            with self.subTest(bad=bad):
                self.assertTrue(plan_package.validate_task_id(bad))


class PresenceTests(unittest.TestCase):
    """TC-02: 4 成果物 + evidence の presence gate（全数パターン）。"""

    def test_all_present_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            self.assertEqual(plan_package.check_presence(task_dir), [])

    def test_each_artifact_missing_fails(self):
        for name in ("pbi-input.md", "plan.md", "todo.md", "test-cases.md",
                     "review-self.md", "review-external.md"):
            with self.subTest(missing=name):
                with tempfile.TemporaryDirectory() as tmp:
                    task_dir = _make_task_dir(tmp, omit=(name,))
                    errors = plan_package.check_presence(task_dir)
                    self.assertTrue(errors)
                    self.assertTrue(any(name in e for e in errors),
                                    f"欠落ファイル名 {name} がエラーに含まれない: {errors}")

    def test_zero_byte_artifact_fails(self):
        # EC-1: 存在するが空 → integrity で fail-closed
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, empty=("plan.md",))
            errors = plan_package.check_presence(task_dir)
            self.assertTrue(any("plan.md" in e for e in errors))


class EvidenceTests(unittest.TestCase):
    """TC-03: C-1/C-2 × 欠落/FAIL/stale の表駆動 6 ケース + TC-04 根拠出力。"""

    def test_evidence_anomaly_table(self):
        cases = [
            ("c1-missing", dict(omit=("review-self.md",))),
            ("c2-missing", dict(omit=("review-external.md",))),
            ("c1-fail", dict(c1_text="# C-1\n> 判定: **FAIL**\n")),
            ("c2-fail", dict(c2_text="# C-2\n総合判定: reject\n")),
        ]
        for label, kwargs in cases:
            with self.subTest(case=label):
                with tempfile.TemporaryDirectory() as tmp:
                    task_dir = _make_task_dir(tmp, **kwargs)
                    errors = plan_package.check_evidence(task_dir)
                    self.assertTrue(errors, f"{label}: 単独異常で fail-closed になっていない")

    def test_evidence_stale_table(self):
        # stale: evidence の mtime が plan.md より古い（暫定実装 / plan Unknowns 準拠）
        for name in ("review-self.md", "review-external.md"):
            with self.subTest(stale=name):
                with tempfile.TemporaryDirectory() as tmp:
                    task_dir = _make_task_dir(tmp)
                    old = 946684800  # 2000-01-01
                    os.utime(task_dir / name, (old, old))
                    errors = plan_package.check_evidence(task_dir)
                    self.assertTrue(errors, f"{name} stale で fail-closed になっていない")
                    # TC-04: stale 判定根拠（ファイル名）が機械追跡可能
                    self.assertTrue(any(name in e and "stale" in e.lower() for e in errors),
                                    f"stale 根拠が出力に含まれない: {errors}")

    def test_evidence_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            self.assertEqual(plan_package.check_evidence(task_dir), [])


class HashTests(unittest.TestCase):
    """TC-09(Unit): artifact_hashes / plan_hash / plan_package_hash の契約。"""

    def test_hashes_shape_and_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            hashes = plan_package.compute_hashes(task_dir)
            self.assertEqual(set(hashes["artifact_hashes"].keys()),
                             {"pbi-input.md", "plan.md", "todo.md", "test-cases.md",
                              "review-self.md", "review-external.md"})
            # 全値が sha256: prefix + 小文字 hex（EC-3: 正規化しない前提の生成側規律）
            for v in hashes["artifact_hashes"].values():
                self.assertRegex(v, r"^sha256:[0-9a-f]{64}$")
            self.assertEqual(hashes["plan_hash"],
                             "sha256:" + _sha256_hex(task_dir / "plan.md"))
            # plan_package_hash = artifact_hashes の正規化 JSON の sha256（契約 §2）
            canon = json.dumps(hashes["artifact_hashes"], sort_keys=True,
                               separators=(",", ":")).encode("utf-8")
            self.assertEqual(hashes["plan_package_hash"],
                             "sha256:" + hashlib.sha256(canon).hexdigest())

    def test_one_byte_change_changes_package_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            before = plan_package.compute_hashes(task_dir)
            with open(task_dir / "todo.md", "a", encoding="utf-8") as f:
                f.write("x")
            after = plan_package.compute_hashes(task_dir)
            self.assertNotEqual(before["plan_package_hash"], after["plan_package_hash"])
            self.assertEqual(before["plan_hash"], after["plan_hash"])  # plan.md は不変


class DeriveLoopspecTests(unittest.TestCase):
    """TC-11: LoopSpec 決定論的派生・全必須フィールド・冪等。"""

    def test_derive_covers_all_required_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            spec = plan_package.derive_loopspec(task_dir, "TASK-9999",
                                                maker="implementation_agent",
                                                checker="qa_reviewer")
            loop = spec["loop"]
            self.assertEqual(loop["name"], "plan-first-task-9999")
            self.assertEqual(loop["trigger"]["type"], "manual")
            self.assertIn("sandbox タスクの目的記述", loop["goal"]["description"])
            self.assertEqual(loop["goal"]["exit_criteria_ref"],
                             "docs/working/TASK-9999/test-cases.md")
            self.assertEqual(loop["context"]["include"], ["plan_package", "diff", "test_results"])
            self.assertEqual(loop["context"]["exclude"], ["stale_tool_outputs"])
            self.assertEqual(loop["context"]["external_sources"], [])
            self.assertIn("scripts/ai-loop/sandbox_a.py", loop["scope"]["allowed_paths"])
            self.assertEqual(loop["actors"], {"maker": "implementation_agent",
                                              "checker": "qa_reviewer"})
            self.assertEqual(loop["verification"]["deterministic"][0]["cmd"], "true")
            self.assertEqual(loop["verification"]["review"],
                             ["requirements_fit", "architecture_consistency"])
            self.assertEqual(loop["stopping_rule"]["terminal_state_ref"], "decision-table.md")
            self.assertEqual(loop["stopping_rule"]["round_limit_ref"],
                             "execution-runbook.md §2-(7)")
            self.assertEqual(loop["memory"]["write"], ["decision_record"])
            self.assertEqual(loop["memory"]["ref"], "execution-runbook.md §2-(4)")
            self.assertEqual(loop["escalation"]["touches_ho"], "unconditional")
            self.assertEqual(loop["escalation"]["budget_ref"], "arbiter-policy.md §7")

    def test_maker_equals_checker_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            with self.assertRaises(plan_package.PlanPackageError):
                plan_package.derive_loopspec(task_dir, "TASK-9999",
                                             maker="same", checker="same")

    def test_no_files_to_touch_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            (task_dir / "plan.md").write_text(
                "# PLAN\n\n## Goal\n\nx\n\n## Testing Strategy\n\n- Verification Automation: `true`\n",
                encoding="utf-8")
            with self.assertRaises(plan_package.PlanPackageError):
                plan_package.derive_loopspec(task_dir, "TASK-9999",
                                             maker="a", checker="b")

    def test_idempotent_derivation(self):
        # シナリオ 9: 同一入力 2 回 → byte 同一
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            s1 = plan_package.derive_loopspec(task_dir, "TASK-9999", maker="a", checker="b")
            s2 = plan_package.derive_loopspec(task_dir, "TASK-9999", maker="a", checker="b")
            self.assertEqual(json.dumps(s1, sort_keys=True), json.dumps(s2, sort_keys=True))


class BuildC3PrimeTests(unittest.TestCase):
    """TC-08a: c3-prime record 生成（PR-1 Unit）+ TC-06 reviewer snapshot 照合。"""

    @staticmethod
    def _build(task_dir, **overrides):
        kwargs = dict(
            task_id="TASK-9999",
            source_sha="abc1234",
            target_sha="abc1234",
            verdicts={"model_a": "approve", "model_b": "approve"},
            reviewer_evidence={"model_a": "record#a", "model_b": "record#b"},
            decision="AUTO_APPROVED",
            policy_ref="auto-approve-lite-clean@v4",
            issued_at="2100-01-01T00:00:00Z",
            issued_by="arbiter-v0.1",
        )
        kwargs.update(overrides)
        return plan_package.build_c3_prime(task_dir, **kwargs)

    def test_valid_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            record = self._build(task_dir)
            self.assertEqual(record["approval_kind"], "c3-prime")
            self.assertEqual(record["phase"], "C-3'")
            self.assertEqual(record["decision"], "AUTO_APPROVED")
            self.assertEqual(record["task_id"], "TASK-9999")
            self.assertEqual(record["source_sha"], "abc1234")
            self.assertEqual(record["issued_at"], "2100-01-01T00:00:00Z")
            self.assertNotIn("c3_status", record)  # 契約 §5: c3_status を含めない
            self.assertRegex(record["plan_hash"], r"^sha256:[0-9a-f]{64}$")
            # TC-06: reviewer snapshot が三つ組全一致で刻印される
            for m in ("model_a", "model_b"):
                snap = record["reviewers"][m]
                self.assertEqual(snap["plan_hash"], record["plan_hash"])
                self.assertEqual(snap["source_sha"], record["source_sha"])
                self.assertEqual(snap["plan_package_hash"], record["plan_package_hash"])
                self.assertEqual(snap["verdict"], "approve")
                self.assertTrue(snap["evidence_ref"])
            self.assertIn("c1_evidence_ref", record)
            self.assertIn("c2_evidence_ref", record)

    def test_source_sha_target_sha_mismatch_rejected(self):
        # 契約 §2 R-011: source_sha != target_sha は生成拒否
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir, target_sha="fff9999")

    def test_presence_failure_blocks_build(self):
        # TC-02 接続: presence 異常時は AUTO_APPROVED record を組めない
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, omit=("todo.md",))
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir)

    def test_evidence_failure_blocks_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, c1_text="# C-1\n> 判定: **FAIL**\n")
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir)

    def test_serialization_constraint(self):
        # 契約 §5: json.dumps(indent=2, sort_keys=True) でトップレベル plan_hash 行が 1 回のみ
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            record = self._build(task_dir)
            text = plan_package.serialize_c3_prime(record)
            top_level_plan_hash = [ln for ln in text.splitlines()
                                   if ln.startswith('  "plan_hash"')]
            self.assertEqual(len(top_level_plan_hash), 1)
            self.assertNotIn('"c3_status"', text)
            self.assertEqual(json.loads(text)["approval_kind"], "c3-prime")

    def test_idempotent_build(self):
        # シナリオ 9: issued_at 注入により同一入力 2 回で byte 同一
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            r1 = self._build(task_dir)
            r2 = self._build(task_dir)
            self.assertEqual(plan_package.serialize_c3_prime(r1),
                             plan_package.serialize_c3_prime(r2))


if __name__ == "__main__":
    unittest.main(verbosity=2)
