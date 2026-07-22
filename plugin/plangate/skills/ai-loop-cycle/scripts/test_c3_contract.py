"""c3_contract.py の契約固定テスト（TASK-0896）。

対象は共通層の純関数境界値と定数契約のみ。偽造 record 14 パターンの受理器
統合テストは test_c3prime_verify.py に残置する（pbi-input Unknowns 確定）。
"""
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import c3_contract  # noqa: E402


class ConstantContractTests(unittest.TestCase):
    """契約定数の値固定（コミット a: 移行前実装との byte 同一を将来にわたり固定）。"""

    def test_artifacts(self):
        self.assertEqual(c3_contract.ARTIFACTS, (
            "pbi-input.md", "plan.md", "todo.md", "test-cases.md",
            "review-self.md", "review-external.md",
        ))

    def test_decisions_verdicts(self):
        self.assertEqual(c3_contract.VALID_DECISIONS,
                         ("AUTO_APPROVED", "HUMAN_ESCALATED", "BLOCKED"))
        self.assertEqual(c3_contract.VALID_VERDICTS, ("approve", "reject"))

    def test_snapshot_keys(self):
        self.assertEqual(c3_contract.SNAPSHOT_KEYS, (
            "verdict", "plan_hash", "source_sha", "plan_package_hash", "evidence_ref"))

    def test_record_keys(self):
        self.assertEqual(c3_contract.RECORD_REQUIRED_KEYS, (
            "task_id", "approval_kind", "phase", "decision", "source_sha", "plan_hash",
            "plan_package_hash", "artifact_hashes", "c1_evidence_ref", "c2_evidence_ref",
            "reviewers", "policy_ref", "issued_at", "issued_by",
        ))
        self.assertEqual(c3_contract.RECORD_OPTIONAL_KEYS, ("derived_loopspec_hash",))
        self.assertEqual(
            c3_contract.RECORD_ALLOWED_KEYS,
            set(c3_contract.RECORD_REQUIRED_KEYS) | set(c3_contract.RECORD_OPTIONAL_KEYS))

    def test_plan_package_keys(self):
        self.assertEqual(c3_contract.PLAN_PACKAGE_REQUIRED_KEYS, (
            "plan_hash", "source_sha", "plan_package_hash",
            "c1_evidence_ref", "c2_evidence_ref", "reviewers",
        ))

    def test_trio_keys(self):
        self.assertEqual(c3_contract.TRIO_KEYS,
                         ("plan_hash", "source_sha", "plan_package_hash"))


class ConsumerAliasTests(unittest.TestCase):
    """3 消費者が c3_contract の定数を参照している（is 同一 = 別定義でない）。"""

    def test_plan_package_aliases(self):
        import plan_package
        self.assertIs(plan_package.ARTIFACTS, c3_contract.ARTIFACTS)
        self.assertIs(plan_package.VALID_DECISIONS, c3_contract.VALID_DECISIONS)
        self.assertIs(plan_package.VALID_VERDICTS, c3_contract.VALID_VERDICTS)

    def test_c3prime_verify_aliases(self):
        import c3prime_verify
        self.assertIs(c3prime_verify.ARTIFACTS, c3_contract.ARTIFACTS)
        self.assertIs(c3prime_verify.VALID_DECISIONS, c3_contract.VALID_DECISIONS)
        self.assertIs(c3prime_verify.VALID_VERDICTS, c3_contract.VALID_VERDICTS)
        self.assertIs(c3prime_verify.SNAPSHOT_KEYS, c3_contract.SNAPSHOT_KEYS)
        self.assertIs(c3prime_verify.REQUIRED_KEYS, c3_contract.RECORD_REQUIRED_KEYS)
        self.assertIs(c3prime_verify.OPTIONAL_KEYS, c3_contract.RECORD_OPTIONAL_KEYS)
        self.assertEqual(c3prime_verify.ALLOWED_KEYS, c3_contract.RECORD_ALLOWED_KEYS)

    def test_arbiter_aliases(self):
        import arbiter
        self.assertIs(arbiter.PLAN_PACKAGE_REQUIRED_KEYS,
                      c3_contract.PLAN_PACKAGE_REQUIRED_KEYS)
        self.assertIs(arbiter.SNAPSHOT_REQUIRED_KEYS, c3_contract.SNAPSHOT_KEYS)



class HashTests(unittest.TestCase):
    """hash ヘルパーの境界値（コミット b）。"""

    def test_canonical_hash_deterministic_and_order_independent(self):
        import hashlib as _h
        expected = "sha256:" + _h.sha256(b'{"a":1,"b":2}').hexdigest()
        self.assertEqual(c3_contract.canonical_hash({"a": 1, "b": 2}), expected)
        self.assertEqual(c3_contract.canonical_hash({"b": 2, "a": 1}), expected)

    def test_canonical_hash_empty(self):
        import hashlib as _h
        self.assertEqual(c3_contract.canonical_hash({}),
                         "sha256:" + _h.sha256(b"{}").hexdigest())

    def test_sha256_of_file_detects_one_byte_change(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p1 = pathlib.Path(d) / "a.md"
            p2 = pathlib.Path(d) / "b.md"
            p1.write_bytes(b"plan body\n")
            p2.write_bytes(b"plan bodY\n")
            h1 = c3_contract.sha256_of_file(p1)
            self.assertTrue(h1.startswith("sha256:") and len(h1) == 71)
            self.assertEqual(h1, c3_contract.sha256_of_file(p1))
            self.assertNotEqual(h1, c3_contract.sha256_of_file(p2))

def _snap(**over):
    base = {"verdict": "approve", "plan_hash": "sha256:aa", "source_sha": "bbb",
            "plan_package_hash": "sha256:cc", "evidence_ref": "docs/x.md"}
    base.update(over)
    return base


def _container():
    return {"plan_hash": "sha256:aa", "source_sha": "bbb", "plan_package_hash": "sha256:cc"}


class SnapshotTrioTests(unittest.TestCase):
    """check_snapshot_trio の理由リスト契約（コミット c）。"""

    def test_ok_both_modes(self):
        rv = {"model_a": _snap(evidence_ref="docs/a.md"), "model_b": _snap(evidence_ref="docs/b.md")}
        self.assertEqual(c3_contract.check_snapshot_trio(_container(), rv, strict_keys=True), [])
        self.assertEqual(c3_contract.check_snapshot_trio(_container(), rv, strict_keys=False), [])

    def test_missing_snapshot_and_non_dict(self):
        for rv in ({}, None, {"model_a": _snap()}, {"model_a": "str", "model_b": _snap()}):
            for strict in (True, False):
                reasons = c3_contract.check_snapshot_trio(_container(), rv, strict_keys=strict)
                self.assertTrue(reasons, f"rv={rv!r} strict={strict}")

    def test_empty_value(self):
        rv = {"model_a": _snap(plan_hash=""), "model_b": _snap()}
        for strict in (True, False):
            reasons = c3_contract.check_snapshot_trio(_container(), rv, strict_keys=strict)
            self.assertEqual(len(reasons), 1)
            self.assertIn("model_a", reasons[0])

    def test_trio_mismatch_each_key(self):
        for key in c3_contract.TRIO_KEYS:
            rv = {"model_a": _snap(**{key: "sha256:tampered"}), "model_b": _snap()}
            for strict in (True, False):
                reasons = c3_contract.check_snapshot_trio(_container(), rv, strict_keys=strict)
                self.assertTrue(any(f"model_a.{key}" in r for r in reasons),
                                f"key={key} strict={strict}: {reasons}")

    def test_extra_key_asymmetry_preserved(self):
        # #889 R2 由来の意図的非対称の両側固定（TASK-0896 R-005 / TC-6）
        rv = {"model_a": _snap(extra="x"), "model_b": _snap()}
        self.assertTrue(c3_contract.check_snapshot_trio(_container(), rv, strict_keys=True))
        self.assertEqual(c3_contract.check_snapshot_trio(_container(), rv, strict_keys=False), [])

    def test_container_none_values_do_not_pass(self):
        # container 側 None と snapshot 側の値ありは不一致（None==None 偶然一致は
        # 空値検査が先に落とすため通過しない）
        rv = {"model_a": _snap(), "model_b": _snap()}
        reasons = c3_contract.check_snapshot_trio({}, rv, strict_keys=False)
        self.assertTrue(reasons)

    def test_reason_order_contract(self):
        # 順序契約（R-004）: reviewer 順（model_a → model_b)、reviewer 内は
        # キー集合 → 空値 → 三つ組の検査順。複合異常で固定する。
        rv = {"model_a": _snap(verdict=""),
              "model_b": _snap(plan_hash="sha256:tampered")}
        reasons = c3_contract.check_snapshot_trio(_container(), rv, strict_keys=False)
        self.assertEqual(len(reasons), 2)
        self.assertIn("model_a", reasons[0])
        self.assertIn("キー欠落または空値", reasons[0])
        self.assertIn("model_b.plan_hash", reasons[1])

    def test_representative_wording_regression(self):
        # 代表文言の回帰固定（R-004: 先頭要素が外部へ出るため文言を固定）
        rv = {"model_a": _snap(extra="x"), "model_b": _snap()}
        strict = c3_contract.check_snapshot_trio(_container(), rv, strict_keys=True)
        self.assertEqual(strict[0], "reviewers.model_a の snapshot キーが規定 5 キーと不一致")
        rv2 = {"model_a": _snap(source_sha="zzz"), "model_b": _snap()}
        trio = c3_contract.check_snapshot_trio(_container(), rv2, strict_keys=False)
        self.assertEqual(
            trio[0],
            "reviewers.model_a.source_sha がトップレベル値と不一致"
            "（同一 Plan Package を観ていない = AC-5 違反）")

    def test_purity_no_io(self):
        # I/O 封じ純粋性（R-003 / AC-3）: open を封じても純関数群は成功する
        import builtins
        real_open = builtins.open
        real_read_bytes = pathlib.Path.read_bytes

        def _blocked(*a, **k):
            raise AssertionError("I/O in pure function")
        builtins.open = _blocked
        pathlib.Path.read_bytes = _blocked
        try:
            rv = {"model_a": _snap(evidence_ref="a"), "model_b": _snap(evidence_ref="b")}
            self.assertEqual(c3_contract.check_snapshot_trio(_container(), rv, strict_keys=True), [])
            self.assertTrue(c3_contract.canonical_hash({"k": 1}).startswith("sha256:"))
        finally:
            builtins.open = real_open
            pathlib.Path.read_bytes = real_read_bytes

    def test_arbiter_does_not_touch_io_layer(self):
        # AC-6 回帰検査: arbiter のコードが sha256_of_file を参照・呼出しない
        # （コメント/docstring の言及は許容するため AST の属性・名前参照で検査）
        import ast
        import arbiter
        src = pathlib.Path(arbiter.__file__).read_text(encoding="utf-8")
        for node in ast.walk(ast.parse(src)):
            if isinstance(node, ast.Attribute):
                self.assertNotEqual(node.attr, "sha256_of_file")
            if isinstance(node, ast.Name):
                self.assertNotEqual(node.id, "sha256_of_file")


if __name__ == "__main__":
    unittest.main()
