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


if __name__ == "__main__":
    unittest.main()
