#!/usr/bin/env python3
"""test_arbiter.py — arbiter.py の unittest カバレッジ（外部依存なし）。

実行: python3 scripts/ai-loop/test_arbiter.py
"""

from __future__ import annotations

import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import arbiter  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
# ho-paths.md の配置は「リポジトリ本体（docs/ai/ai-loop/）」「配布 skill の
# bundled resources（scripts/ の隣の references/）」の 2 通りがある（issue #771
# rework）。候補を順に探索し、最初に存在したものを使う。
_HO_PATHS_CANDIDATES = (
    REPO_ROOT / "docs" / "ai" / "ai-loop" / "ho-paths.md",
    pathlib.Path(__file__).resolve().parent.parent / "references" / "ho-paths.md",
)
HO_PATHS_MD = next((p for p in _HO_PATHS_CANDIDATES if p.exists()), _HO_PATHS_CANDIDATES[0])


def _base_input(**overrides):
    data = {
        "changed_files": ["docs/workflows/ai-loop/decision-table.md"],
        "allowed_paths": ["docs/workflows/ai-loop/**"],
        "lite": {
            "size_ok": True,
            "no_new_design": True,
            "follows_pattern": True,
            "reversible": True,
        },
        "class": "no-merge",
        "verdicts": {
            "model_a": "approve",
            "model_b": "approve",
            "reject_category": None,
            "model_c": None,
            "model_d": None,
        },
        "target_sha": "abc1234",
        # #780 Slice B: priority 1.7（plan-quality gate）を既定で満たしておく。
        # これにより priority 2 以降の裁定を検証する既存 characterization test
        # 群は、gates 未対応時代の裁定と同一の結果を維持する（gates 完備は
        # escalate を追加しないための前提条件・後方互換のための既定値）。
        "gates": {"c1": "PASS", "breakdown": "pass"},
    }
    data.update(overrides)
    return data


class BoundaryCheckTests(unittest.TestCase):
    """docs/ai/ai-loop/ho-paths.md の 17 パターン各 1 ケース。"""

    def test_bin_plangate(self):
        boundary, matched = arbiter.boundary_check(["bin/plangate"])
        self.assertEqual(boundary, "touches-HO")
        self.assertEqual(matched[0]["classification"], "HO-core")

    def test_scripts_hooks(self):
        boundary, _ = arbiter.boundary_check(["scripts/hooks/check-plan-hash.sh"])
        self.assertEqual(boundary, "touches-HO")

    def test_scripts_hooks_nested(self):
        boundary, _ = arbiter.boundary_check(["scripts/hooks/sub/nested.sh"])
        self.assertEqual(boundary, "touches-HO")

    def test_schemas(self):
        boundary, _ = arbiter.boundary_check(["schemas/plan.schema.json"])
        self.assertEqual(boundary, "touches-HO")

    def test_claude_rules_md(self):
        boundary, _ = arbiter.boundary_check([".claude/rules/mode-classification.md"])
        self.assertEqual(boundary, "touches-HO")

    def test_claude_settings_star_json(self):
        boundary, _ = arbiter.boundary_check([".claude/settings.json"])
        self.assertEqual(boundary, "touches-HO")

    def test_claude_settings_local_json(self):
        boundary, _ = arbiter.boundary_check([".claude/settings.local.json"])
        self.assertEqual(boundary, "touches-HO")

    def test_claude_md(self):
        boundary, _ = arbiter.boundary_check(["CLAUDE.md"])
        self.assertEqual(boundary, "touches-HO")

    def test_agents_md(self):
        boundary, _ = arbiter.boundary_check(["AGENTS.md"])
        self.assertEqual(boundary, "touches-HO")

    def test_core_contract_md(self):
        boundary, _ = arbiter.boundary_check(["docs/ai/core-contract.md"])
        self.assertEqual(boundary, "touches-HO")

    def test_docs_ai_top_level_md(self):
        boundary, _ = arbiter.boundary_check(["docs/ai/metrics.md"])
        self.assertEqual(boundary, "touches-HO")

    def test_docs_ai_ai_loop_excluded(self):
        """docs/ai/ai-loop/ 配下は docs/ai/*.md（トップレベル）の対象外。"""
        boundary, _ = arbiter.boundary_check(["docs/ai/ai-loop/concept.md"])
        self.assertEqual(boundary, "clean")

    def test_ho_paths_md_itself(self):
        """HO 境界定義ファイル自体の変更は touches-HO（自己改変防止 / #808 consensus）。"""
        boundary, matched = arbiter.boundary_check(["docs/ai/ai-loop/ho-paths.md"])
        self.assertEqual(boundary, "touches-HO")
        self.assertEqual(matched[0]["classification"], "HO-contract")

    def test_github_workflows_yml(self):
        boundary, _ = arbiter.boundary_check([".github/workflows/ci.yml"])
        self.assertEqual(boundary, "touches-HO")

    def test_approvals_json_deep_path(self):
        """**/approvals/*.json は深いネストのパスにもマッチする（正本の既知バグ修正確認）。"""
        boundary, _ = arbiter.boundary_check(["docs/working/TASK-0123/approvals/c3.json"])
        self.assertEqual(boundary, "touches-HO")

    def test_claude_commands_md(self):
        boundary, _ = arbiter.boundary_check([".claude/commands/plan.md"])
        self.assertEqual(boundary, "touches-HO")

    def test_claude_agents_md(self):
        boundary, _ = arbiter.boundary_check([".claude/agents/orchestrator.md"])
        self.assertEqual(boundary, "touches-HO")

    def test_claude_settings_example_json(self):
        boundary, _ = arbiter.boundary_check([".claude/settings.example.json"])
        self.assertEqual(boundary, "touches-HO")

    def test_github_workflows_yaml(self):
        boundary, _ = arbiter.boundary_check([".github/workflows/ci.yaml"])
        self.assertEqual(boundary, "touches-HO")

    def test_plugin_plangate(self):
        boundary, _ = arbiter.boundary_check(["plugin/plangate/index.js"])
        self.assertEqual(boundary, "touches-HO")

    def test_clean_path(self):
        boundary, matched = arbiter.boundary_check(["scripts/ai-loop/arbiter.py"])
        self.assertEqual(boundary, "clean")
        self.assertEqual(matched, [])

    def test_ho_pattern_drift_against_source_of_truth(self):
        """実行時パースされた全パターンが ho-paths.md 本文に存在することを検証する（#809）。

        #809 により HO_PATTERNS ハードコード定数は廃止され、ho-paths.md 本文を
        実行時にパースする方式へ変更された。ドリフトは構造的に発生しなくなるが、
        パーサの抽出内容が本文の記述と食い違っていないこと（例: 注釈括弧の
        誤混入）を継続して検証する。
        """
        self.assertTrue(HO_PATHS_MD.exists(), f"正本ファイルが見つかりません: {HO_PATHS_MD}")
        content = HO_PATHS_MD.read_text(encoding="utf-8")
        patterns, source, _searched = arbiter.resolve_ho_patterns()
        self.assertIsNotNone(source, "ho-paths.md の実行時解決に失敗しました")
        self.assertGreaterEqual(len(patterns), 18, f"パース件数が想定を下回ります: {len(patterns)}")
        missing = [pattern for pattern, _classification in patterns if pattern not in content]
        self.assertEqual(
            missing,
            [],
            f"パースされたパターンが ho-paths.md 本文に見当たりません: {missing}",
        )


class LiteCheckTests(unittest.TestCase):
    def test_all_true(self):
        self.assertTrue(
            arbiter.lite_check(
                {"size_ok": True, "no_new_design": True, "follows_pattern": True, "reversible": True}
            )
        )

    def test_one_false(self):
        self.assertFalse(
            arbiter.lite_check(
                {"size_ok": True, "no_new_design": True, "follows_pattern": True, "reversible": False}
            )
        )

    def test_missing_key(self):
        """AC-8 安全側: キー欠落は false。"""
        self.assertFalse(arbiter.lite_check({"size_ok": True, "no_new_design": True, "follows_pattern": True}))

    def test_null_value(self):
        """AC-8 安全側: null は false。"""
        self.assertFalse(
            arbiter.lite_check(
                {"size_ok": True, "no_new_design": True, "follows_pattern": True, "reversible": None}
            )
        )

    def test_non_bool_value(self):
        """AC-8 安全側: 非 bool（例: 1）は false。"""
        self.assertFalse(
            arbiter.lite_check({"size_ok": True, "no_new_design": True, "follows_pattern": True, "reversible": 1})
        )

    def test_not_a_dict(self):
        self.assertFalse(arbiter.lite_check(None))
        self.assertFalse(arbiter.lite_check("not-a-dict"))


class SeverityClassificationTests(unittest.TestCase):
    def test_critical_categories(self):
        for category in ("ho_path_contact", "permission", "irreversible", "security_break"):
            with self.subTest(category=category):
                self.assertEqual(arbiter.classify_severity(category), "critical")

    def test_major_categories(self):
        for category in ("public_api", "data_integrity", "migration", "auth_change"):
            with self.subTest(category=category):
                self.assertEqual(arbiter.classify_severity(category), "major")

    def test_minor_categories(self):
        for category in ("logic", "performance", "test_shortage"):
            with self.subTest(category=category):
                self.assertEqual(arbiter.classify_severity(category), "minor")

    def test_low_categories(self):
        for category in ("documentation", "format", "naming"):
            with self.subTest(category=category):
                self.assertEqual(arbiter.classify_severity(category), "low")

    def test_unknown_category_defaults_to_critical(self):
        self.assertEqual(arbiter.classify_severity("some_unrecognized_category"), "critical")

    def test_null_category_defaults_to_critical(self):
        self.assertEqual(arbiter.classify_severity(None), "critical")


class DecisionTablePriorityTests(unittest.TestCase):
    """decision-table.md §3 priority 1〜6 の全行をカバーする。"""

    def test_priority1_touches_ho_overrides_everything(self):
        """boundary=touches-HO は lite=false・class=merge・verdict 何でも固定 escalate。"""
        data = _base_input(
            changed_files=["bin/plangate"],
            lite={"size_ok": False, "no_new_design": False, "follows_pattern": False, "reversible": False},
            **{"class": "merge"},
        )
        data["verdicts"] = {"model_a": "reject", "model_b": "reject", "reject_category": None, "model_c": None, "model_d": None}
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 1", reason)

    def test_priority2_lite_false(self):
        data = _base_input(lite={"size_ok": False, "no_new_design": True, "follows_pattern": True, "reversible": True})
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 2", reason)

    def test_priority3_class_merge(self):
        data = _base_input(**{"class": "merge"})
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 3", reason)

    def test_priority4_reject_reject(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "reject"
        data["verdicts"]["model_b"] = "reject"
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "BLOCKED")
        self.assertIn("priority 4", reason)

    def test_priority4_reject_approve(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "reject"
        data["verdicts"]["model_b"] = "approve"
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "BLOCKED")
        self.assertIn("priority 4", reason)

    def test_priority5_approve_reject_routes_to_severity(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "logic"
        data["verdicts"]["model_c"] = "approve"
        data["verdicts"]["model_d"] = "approve"
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertIn("priority 5", reason)

    def test_priority6_approve_approve(self):
        data = _base_input()
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertIn("priority 6", reason)


class PlanQualityCheckUnitTests(unittest.TestCase):
    """plan_quality_check() 単体テスト（AC-8 安全側: 欠落・null・型不一致は false）。"""

    def test_both_pass_is_true(self):
        self.assertTrue(arbiter.plan_quality_check({"c1": "PASS", "breakdown": "pass"}))

    def test_c1_fail_is_false(self):
        self.assertFalse(arbiter.plan_quality_check({"c1": "FAIL", "breakdown": "pass"}))

    def test_breakdown_split_suggested_is_false(self):
        self.assertFalse(arbiter.plan_quality_check({"c1": "PASS", "breakdown": "split-suggested"}))

    def test_gates_missing_key_is_false(self):
        self.assertFalse(arbiter.plan_quality_check({"c1": "PASS"}))
        self.assertFalse(arbiter.plan_quality_check({"breakdown": "pass"}))
        self.assertFalse(arbiter.plan_quality_check({}))

    def test_gates_none_is_false(self):
        self.assertFalse(arbiter.plan_quality_check(None))

    def test_gates_non_dict_is_false(self):
        self.assertFalse(arbiter.plan_quality_check("PASS"))
        self.assertFalse(arbiter.plan_quality_check(["PASS", "pass"]))

    def test_c1_non_string_is_false(self):
        """AC-8 安全側: 非 str（例: 123）は false。"""
        self.assertFalse(arbiter.plan_quality_check({"c1": 123, "breakdown": "pass"}))

    def test_breakdown_none_is_false(self):
        self.assertFalse(arbiter.plan_quality_check({"c1": "PASS", "breakdown": None}))

    def test_case_sensitive_mismatch_is_false(self):
        """厳密一致: "pass"（小文字）・"PASS"（大文字）以外の表記ゆれは false。"""
        self.assertFalse(arbiter.plan_quality_check({"c1": "pass", "breakdown": "pass"}))
        self.assertFalse(arbiter.plan_quality_check({"c1": "PASS", "breakdown": "PASS"}))


class PlanQualityGatePriorityTests(unittest.TestCase):
    """#780 Slice B: priority 1.7（plan-quality gate）の裁定経路テスト。

    中核原則: escalate 条件を追加するのみ。以前 auto-approve だったケースは
    gates 完備時のみ auto-approve を維持し、gates 不備は escalate に倒れる。
    """

    def test_gates_complete_reaches_auto_approve(self):
        """gates 完備 + 他 auto-approve 条件 → AUTO_APPROVED（#816 と同一裁定）。"""
        data = _base_input(gates={"c1": "PASS", "breakdown": "pass"})
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertIn("priority 6", reason)

    def test_gates_c1_fail_escalates(self):
        data = _base_input(gates={"c1": "FAIL", "breakdown": "pass"})
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 1.7", reason)
        self.assertIn("plan-quality", reason)

    def test_gates_breakdown_split_suggested_escalates(self):
        data = _base_input(gates={"c1": "PASS", "breakdown": "split-suggested"})
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 1.7", reason)

    def test_gates_missing_field_escalates_exit2_not_exit1(self):
        """gates フィールド自体が無い入力は exit 1（入力エラー）ではなく
        exit 2（HUMAN_ESCALATED）になる（後方互換の要）。"""
        data = _base_input()
        del data["gates"]
        validated = arbiter.validate_input(data)  # 入力エラーにならないことを確認
        provenance, reason = arbiter.arbitrate(validated)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 1.7", reason)
        self.assertEqual(arbiter.EXIT_CODES[provenance["decision"]], 2)

    def test_gates_null_escalates(self):
        data = _base_input(gates=None)
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 1.7", reason)

    def test_gates_c1_null_escalates(self):
        data = _base_input(gates={"c1": None, "breakdown": "pass"})
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 1.7", reason)

    def test_gates_c1_non_string_escalates(self):
        data = _base_input(gates={"c1": 123, "breakdown": "pass"})
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 1.7", reason)

    def test_touches_ho_preempts_plan_quality_gate(self):
        """HO 優先: touches-HO + gates.c1=FAIL でも boundary=touches-HO が先に確定する
        （priority 1 が priority 1.7 より先。c1 の値で上書きされない）。"""
        data = _base_input(
            changed_files=["bin/plangate"],
            allowed_paths=["bin/plangate"],
            gates={"c1": "FAIL", "breakdown": "split-suggested"},
        )
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "touches-HO")
        self.assertIn("priority 1", reason)
        self.assertNotIn("priority 1.7", reason)

    def test_scope_violation_preempts_plan_quality_gate(self):
        """scope 優先: scope 逸脱 + gates 完備でも priority 1.5（scope）が
        priority 1.7 より先に確定する。"""
        data = _base_input(
            changed_files=["scripts/unrelated/tool.py"],
            allowed_paths=["docs/workflows/ai-loop/**"],
            gates={"c1": "PASS", "breakdown": "pass"},
        )
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["scope_check"], "scope_violation")
        self.assertIn("priority 1.5", reason)
        self.assertNotIn("priority 1.7", reason)

    def test_gates_ok_but_lite_false_reaches_priority2(self):
        """gates 完備で priority 1.7 を通過した後、priority 2（lite=false）へ進む。"""
        data = _base_input(
            gates={"c1": "PASS", "breakdown": "pass"},
            lite={"size_ok": False, "no_new_design": True, "follows_pattern": True, "reversible": True},
        )
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("priority 2", reason)

    def test_gates_reason_includes_values(self):
        data = _base_input(gates={"c1": "FAIL", "breakdown": "not-pass"})
        _provenance, reason = arbiter.arbitrate(data)
        self.assertIn("c1=FAIL", reason)
        self.assertIn("breakdown=not-pass", reason)


class SeverityEscalationTests(unittest.TestCase):
    def test_severity_critical_escalates(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "security_break"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["w_check"]["severity"], "critical")

    def test_severity_major_escalates(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "auth_change"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["w_check"]["severity"], "major")

    def test_severity_unknown_category_escalates_as_critical(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "totally_unknown_category"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["w_check"]["severity"], "critical")


class CDArbitrationTests(unittest.TestCase):
    """flow-detect.md §3.3 Model C/D 裁定の 4 パターン + 欠落ケース。"""

    def _cd_input(self, model_c, model_d, reject_category="logic"):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = reject_category
        data["verdicts"]["model_c"] = model_c
        data["verdicts"]["model_d"] = model_d
        return data

    def test_cd_approve_approve(self):
        provenance, _ = arbiter.arbitrate(self._cd_input("approve", "approve"))
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")

    def test_cd_approve_reject(self):
        provenance, _ = arbiter.arbitrate(self._cd_input("approve", "reject"))
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")

    def test_cd_reject_approve(self):
        provenance, _ = arbiter.arbitrate(self._cd_input("reject", "approve"))
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")

    def test_cd_reject_reject(self):
        provenance, _ = arbiter.arbitrate(self._cd_input("reject", "reject"))
        self.assertEqual(provenance["decision"], "BLOCKED")

    def test_cd_model_c_missing_escalates(self):
        provenance, reason = arbiter.arbitrate(self._cd_input(None, "approve"))
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("欠落", reason)

    def test_cd_model_d_missing_escalates(self):
        provenance, reason = arbiter.arbitrate(self._cd_input("approve", None))
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("欠落", reason)

    def test_cd_both_missing_escalates(self):
        provenance, reason = arbiter.arbitrate(self._cd_input(None, None))
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertIn("欠落", reason)


class RejectCategoryProvenanceTests(unittest.TestCase):
    """provenance.w_check.reject_category の omit 方式配線検証（AC-1/AC-2/AC-6）。"""

    def test_reject_category_present_when_model_b_rejects(self):
        """AC-1: model_b=reject 時、w_check.reject_category が入力値と一致する。"""
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "logic"
        data["verdicts"]["model_c"] = "approve"
        data["verdicts"]["model_d"] = "approve"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["w_check"]["reject_category"], "logic")

    def test_reject_category_omitted_when_model_b_approves(self):
        """AC-2: model_b=approve 時、w_check に reject_category キーが存在しない（omit 方式）。"""
        data = _base_input()
        provenance, _ = arbiter.arbitrate(data)
        self.assertNotIn("reject_category", provenance["w_check"])

    def test_reject_category_omitted_on_inconsistent_input(self):
        """防御ガード: model_b=approve かつ reject_category に値がある不正入力でも、
        record に reject_category キーが出力されない（decision-table.md §5:
        model_b=reject 時のみ出力、の防御的保証）。
        """
        data = _base_input()
        data["verdicts"]["reject_category"] = "logic"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["w_check"]["model_b"], "approve")
        self.assertNotIn("reject_category", provenance["w_check"])

    def test_severity_wired_from_reject_category_e2e(self):
        """AC-6: arbitrate() を e2e で通した record で
        w_check.severity == classify_severity(w_check.reject_category) を確認する。

        これは配線検証（build_provenance へ reject_category が正しく渡り、
        severity フィールドと整合しているか）であり、SEVERITY_MAP の
        カテゴリ→severity マッピング妥当性そのものの検証ではない
        （マッピング妥当性は SeverityClassificationTests が担当する）。
        """
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "security_break"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(
            provenance["w_check"]["severity"],
            arbiter.classify_severity(provenance["w_check"]["reject_category"]),
        )


class ProvenanceSchemaTests(unittest.TestCase):
    def test_auto_approve_provenance_fields(self):
        data = _base_input()
        provenance, _ = arbiter.arbitrate(data)
        for field in (
            "decision",
            "issued_by",
            "policy_ref",
            "w_check",
            "target_sha",
            "boundary_check",
            "lite_check",
            "class_check",
            "scope_check",
            "timestamp",
        ):
            self.assertIn(field, provenance)
        self.assertEqual(provenance["issued_by"], "arbiter-v0.1")
        self.assertEqual(provenance["policy_ref"], "auto-approve-lite-clean@v2")
        self.assertEqual(provenance["scope_check"], "in_scope")
        self.assertEqual(provenance["w_check"]["model_a"], "approve")
        self.assertEqual(provenance["w_check"]["model_b"], "approve")
        # 決定論であることの確認（同一入力 → 同一 decision）
        provenance2, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], provenance2["decision"])


class InputValidationTests(unittest.TestCase):
    def test_missing_changed_files_raises(self):
        data = _base_input()
        del data["changed_files"]
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_invalid_class_raises(self):
        data = _base_input(**{"class": "not-a-valid-class"})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_invalid_model_a_raises(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "maybe"
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_non_dict_input_raises(self):
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(["not", "a", "dict"])

    def test_missing_allowed_paths_raises(self):
        """TC-7: allowed_paths 欠落は入力エラー（#809 必須化）。"""
        data = _base_input()
        del data["allowed_paths"]
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_empty_allowed_paths_raises(self):
        """TC-7: allowed_paths が空リストは入力エラー（非空 string リスト要件）。"""
        data = _base_input(allowed_paths=[])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_non_list_allowed_paths_raises(self):
        """TC-7: allowed_paths が非リスト（例: string）は入力エラー。"""
        data = _base_input(allowed_paths="docs/workflows/ai-loop/**")
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_non_string_item_in_allowed_paths_raises(self):
        """TC-7: allowed_paths の要素に非 string が混じる場合は入力エラー。"""
        data = _base_input(allowed_paths=["docs/workflows/ai-loop/**", 123])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)


class HoPathsResolutionTests(unittest.TestCase):
    """TC-1〜TC-4: ho-paths.md 実行時解決の優先順位 + fail-closed（#809）。"""

    def test_tc1_cli_explicit_path_takes_priority(self):
        """TC-1: --ho-paths 相当（cli_path 明示指定）は CWD/script-relative より優先される。"""
        with tempfile.TemporaryDirectory() as tmpdir:
            custom = pathlib.Path(tmpdir) / "custom-ho-paths.md"
            custom.write_text(
                "## HO パス一覧\n\n"
                "| パス | 分類 | 変更禁止理由 |\n"
                "|------|------|------------|\n"
                "| `only-in-custom/**` | HO-custom | テスト専用パターン |\n",
                encoding="utf-8",
            )
            patterns, source, searched = arbiter.resolve_ho_patterns(str(custom))
            self.assertEqual(patterns, [("only-in-custom/**", "HO-custom")])
            self.assertEqual(source, str(custom))
            self.assertEqual(searched, [str(custom)])

    def test_tc2_candidate_order_cwd_before_bundled(self):
        """TC-2: cli_path 未指定時の候補順序は (1) CWD の docs/ai/ai-loop/ho-paths.md
        → (2) スクリプト位置基準 ../references/ho-paths.md の順。
        """
        candidates = arbiter._candidate_ho_paths_sources(None)
        self.assertEqual(len(candidates), 2)
        self.assertTrue(str(candidates[0]).endswith(str(pathlib.Path("docs/ai/ai-loop/ho-paths.md"))))
        self.assertTrue(str(candidates[1]).endswith(str(pathlib.Path("references/ho-paths.md"))))

    def test_tc3_fail_closed_when_explicit_path_missing(self):
        """TC-3: 明示パスが存在しない場合、fail-closed（patterns=[], source=None）。"""
        missing_path = "/nonexistent/path/does-not-exist-ho-paths.md"
        patterns, source, searched = arbiter.resolve_ho_patterns(missing_path)
        self.assertEqual(patterns, [])
        self.assertIsNone(source)
        self.assertEqual(searched, [missing_path])

    def test_tc4_fail_closed_when_zero_parseable_rows(self):
        """TC-4: ファイルは存在するがパース可能な行が 0 件 → fail-closed。"""
        with tempfile.TemporaryDirectory() as tmpdir:
            empty_doc = pathlib.Path(tmpdir) / "empty-ho-paths.md"
            empty_doc.write_text("# HO パス一覧\n\n本文にはテーブル行が一切ない。\n", encoding="utf-8")
            patterns, source, searched = arbiter.resolve_ho_patterns(str(empty_doc))
            self.assertEqual(patterns, [])
            self.assertIsNone(source)
            self.assertEqual(searched, [str(empty_doc)])


class HoPathsTableParsingTests(unittest.TestCase):
    """TC-6: parse_ho_paths_table の注釈括弧除去・境界動作。"""

    def test_tc6_annotation_parenthetical_excluded_from_pattern(self):
        content = (
            "## HO パス一覧\n\n"
            "| パス | 分類 | 変更禁止理由 |\n"
            "|------|------|------------|\n"
            "| `docs/ai/*.md`（トップレベルの md のみ。`docs/ai/ai-loop/` 配下は対象外） "
            "| HO-contract | 理由 |\n"
        )
        patterns = arbiter.parse_ho_paths_table(content)
        self.assertEqual(patterns, [("docs/ai/*.md", "HO-contract")])

    def test_tc6_header_and_separator_rows_ignored(self):
        content = (
            "| パス | 分類 | 変更禁止理由 |\n"
            "|------|------|------------|\n"
            "| `bin/plangate` | HO-core | 理由 |\n"
        )
        patterns = arbiter.parse_ho_paths_table(content)
        self.assertEqual(patterns, [("bin/plangate", "HO-core")])

    def test_tc6_non_table_lines_ignored(self):
        content = "本文の説明文。バッククォート `example` を含むが表ではない。\n"
        patterns = arbiter.parse_ho_paths_table(content)
        self.assertEqual(patterns, [])


class FailClosedIntegrationTests(unittest.TestCase):
    """TC-5: ho-paths 未解決時、arbitrate() は verdict/lite/class を問わず全件escalate。"""

    def test_tc5_unresolved_ho_paths_escalates_regardless_of_verdicts(self):
        missing_path = "/nonexistent/path/does-not-exist-ho-paths.md"
        data = _base_input()  # approve-approve・lite 全 true・class=no-merge（本来なら auto-approve 相当）
        provenance, reason = arbiter.arbitrate(data, ho_paths_path=missing_path)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "unresolved")
        self.assertIn("fail-closed", reason)
        self.assertIn("priority 0", reason)

    def test_tc5_unresolved_ho_paths_escalates_even_with_reject_reject(self):
        """fail-closed は「厳しい裁定を優先」より前段の絶対条件。reject-reject（本来 BLOCKED）でも
        ho-paths 未解決時は HUMAN_ESCALATED（boundary 判定不能を明示する decision）を返す。
        """
        missing_path = "/nonexistent/path/does-not-exist-ho-paths.md"
        data = _base_input()
        data["verdicts"]["model_a"] = "reject"
        data["verdicts"]["model_b"] = "reject"
        provenance, _reason = arbiter.arbitrate(data, ho_paths_path=missing_path)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")


class AllowedPathsScopeTests(unittest.TestCase):
    """TC-8〜TC-10: allowed_paths 必須化・scope 逸脱 escalate・touches-HO 優先順位。"""

    def test_tc8_in_scope_change_proceeds_to_normal_evaluation(self):
        """TC-8: allowed_paths 内の変更は scope チェックを通過し通常の priority 評価へ進む。"""
        data = _base_input(allowed_paths=["docs/workflows/ai-loop/**"])
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertEqual(provenance["scope_check"], "in_scope")
        self.assertIn("priority 6", reason)

    def test_tc9_out_of_scope_change_escalates(self):
        """TC-9: changed_files が allowed_paths のどの glob にも一致しない → human escalate。"""
        data = _base_input(
            changed_files=["docs/workflows/ai-loop/decision-table.md", "scripts/unrelated/tool.py"],
            allowed_paths=["docs/workflows/ai-loop/**"],
        )
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["scope_check"], "scope_violation")
        self.assertIn("priority 1.5", reason)
        self.assertIn("scripts/unrelated/tool.py", reason)

    def test_tc10_touches_ho_overrides_even_when_allowed_paths_declares_it(self):
        """TC-10: allowed_paths に HO パスそのものを宣言していても HO escalate は免れない
        （design-philosophy.md I-1 不変条件・優先順位は touches-HO が常に先）。
        """
        data = _base_input(
            changed_files=["bin/plangate"],
            allowed_paths=["bin/plangate"],
        )
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "touches-HO")
        self.assertIn("priority 1", reason)
        self.assertNotIn("priority 1.5", reason)


class PolicyRefVersionTests(unittest.TestCase):
    """TC-11: POLICY_REF が @v1 へ改版されていること（allowed_paths 必須化・fail-closed機械化）。

    #780 Slice B で @v1 → @v2 へ再改版（gates 必須化・priority 1.7 追加）。
    """

    def test_tc11_policy_ref_is_v2(self):
        self.assertEqual(arbiter.POLICY_REF, "auto-approve-lite-clean@v2")

    def test_tc11_provenance_policy_ref_is_v2(self):
        data = _base_input()
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["policy_ref"], "auto-approve-lite-clean@v2")


class PathNormalizationSecurityTests(unittest.TestCase):
    """敵対的レビュー major 反映（#809）: パス正規化欠如による touches-HO 迂回の封鎖。

    2 層防御:
    - 第一防壁（入力段）: validate_input が正規化後 `..` 残存・絶対パス・
      空セグメント（//）を InputError（exit 1）で拒否する
    - 第二防壁（判定段）: boundary_check / check_allowed_paths がマッチ直前に
      normpath で畳み込み、`./bin/plangate` 等の変種でも HO を捕捉する。
      判定関数単体に不正パスが渡った場合も安全側（escalate 相当）に倒す
    """

    # --- 第二防壁: 正規化後マッチ（./ 変種で HO 捕捉） ---

    def test_dot_slash_prefix_variant_is_caught_as_touches_ho(self):
        """`./bin/plangate` は正規化後に bin/plangate として touches-HO 捕捉。"""
        data = _base_input(changed_files=["./bin/plangate"], allowed_paths=["**"])
        provenance, reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "touches-HO")
        self.assertIn("priority 1", reason)

    def test_boundary_check_normalizes_before_matching(self):
        boundary, matched = arbiter.boundary_check(["./bin/plangate"])
        self.assertEqual(boundary, "touches-HO")
        self.assertEqual(matched[0]["classification"], "HO-core")

    def test_interior_dotdot_collapsing_to_ho_paths_md_is_caught(self):
        """自己改変 traversal: `docs/ai/ai-loop/x/../ho-paths.md` は正規化後に
        ho-paths.md 本体として touches-HO 捕捉（clean にしない / #808 防止の維持）。
        """
        data = _base_input(
            changed_files=["docs/ai/ai-loop/x/../ho-paths.md"],
            allowed_paths=["docs/ai/ai-loop/**"],
        )
        provenance, _reason = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "touches-HO")

    def test_arbitrate_direct_call_with_root_escaping_path_is_safe_side(self):
        """validate_input を経ない arbitrate() 直呼びでも、ルート外へ抜ける
        `..` パスは安全側（escalate。AUTO_APPROVED 到達不可）に倒れる。
        """
        data = _base_input(
            changed_files=["docs/ai/ai-loop/../../../bin/plangate"],
            allowed_paths=["docs/ai/ai-loop/**"],
        )
        provenance, _reason = arbiter.arbitrate(data)
        self.assertNotEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")

    # --- 第一防壁: validate_input での拒否 ---

    def test_validate_rejects_root_escaping_traversal(self):
        data = _base_input(
            changed_files=["docs/ai/ai-loop/../../../bin/plangate"],
            allowed_paths=["docs/ai/ai-loop/**"],
        )
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_validate_rejects_empty_segment(self):
        data = _base_input(changed_files=["bin//plangate"])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_validate_rejects_absolute_path(self):
        data = _base_input(changed_files=["/etc/passwd"])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_validate_rejects_traversal_in_allowed_paths(self):
        data = _base_input(allowed_paths=["../**"])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    # --- CLI e2e: exit code 固定 ---

    def _run_main_with_stdin(self, payload):
        import io

        old_stdin = sys.stdin
        old_stdout = sys.stdout
        old_stderr = sys.stderr
        sys.stdin = io.StringIO(json.dumps(payload))
        sys.stdout = io.StringIO()
        sys.stderr = io.StringIO()
        try:
            code = arbiter.main([])
            stdout_value = sys.stdout.getvalue()
            stderr_value = sys.stderr.getvalue()
        finally:
            sys.stdin = old_stdin
            sys.stdout = old_stdout
            sys.stderr = old_stderr
        return code, stdout_value, stderr_value

    def test_e2e_traversal_exits_1_and_never_auto_approves(self):
        """再現ケース固定: traversal + narrow allowed_paths は exit 1（入力エラー）。
        AUTO_APPROVED（exit 0）に到達しないことを固定する。
        """
        data = _base_input(
            changed_files=["docs/ai/ai-loop/../../../bin/plangate"],
            allowed_paths=["docs/ai/ai-loop/**"],
        )
        code, stdout_value, stderr_value = self._run_main_with_stdin(data)
        self.assertEqual(code, 1)
        self.assertNotIn("AUTO_APPROVED", stdout_value)
        self.assertIn("入力エラー", stderr_value)
        self.assertIn("bin/plangate", stderr_value)

    def test_e2e_dot_slash_variant_escalates_exit_2(self):
        """再現ケース固定: `./bin/plangate` + allowed=** は touches-HO escalate（exit 2）。"""
        data = _base_input(changed_files=["./bin/plangate"], allowed_paths=["**"])
        code, stdout_value, _ = self._run_main_with_stdin(data)
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(stdout_value)["decision"], "HUMAN_ESCALATED")
        self.assertEqual(json.loads(stdout_value)["boundary_check"], "touches-HO")

    def test_e2e_empty_segment_exits_1(self):
        data = _base_input(changed_files=["bin//plangate"])
        code, _, stderr_value = self._run_main_with_stdin(data)
        self.assertEqual(code, 1)
        self.assertIn("入力エラー", stderr_value)

    def test_e2e_absolute_path_exits_1(self):
        data = _base_input(changed_files=["/etc/passwd"])
        code, _, stderr_value = self._run_main_with_stdin(data)
        self.assertEqual(code, 1)
        self.assertIn("入力エラー", stderr_value)

    # --- 回帰: 正規の素パスは従来どおり ---

    def test_regression_plain_ho_path_still_escalates(self):
        data = _base_input(changed_files=["bin/plangate"], allowed_paths=["bin/plangate"])
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "touches-HO")

    def test_regression_plain_ho_paths_md_still_escalates(self):
        data = _base_input(
            changed_files=["docs/ai/ai-loop/ho-paths.md"],
            allowed_paths=["docs/ai/ai-loop/**"],
        )
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "touches-HO")

    def test_regression_happy_path_still_auto_approves(self):
        data = _base_input(
            changed_files=["docs/workflows/ai-loop/example.md"],
            allowed_paths=["docs/workflows/ai-loop/**"],
        )
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertEqual(provenance["scope_check"], "in_scope")


class ScopeCheckNotEvaluatedTests(unittest.TestCase):
    """敵対的レビュー minor（Finding 3・#809）: scope 未評価経路の scope_check 明示。"""

    def test_touches_ho_record_marks_scope_not_evaluated(self):
        """touches-HO 経路（priority 1）は scope 検査より前で return するため
        scope_check == "not_evaluated"（"in_scope" と誤読させない）。
        """
        data = _base_input(changed_files=["bin/plangate"], allowed_paths=["bin/plangate"])
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["boundary_check"], "touches-HO")
        self.assertEqual(provenance["scope_check"], "not_evaluated")

    def test_fail_closed_record_marks_scope_unresolved(self):
        """fail-closed 経路（priority 0）は scope_check == "unresolved"（従来どおり）。"""
        data = _base_input()
        provenance, _ = arbiter.arbitrate(data, ho_paths_path="/nonexistent/ho-paths.md")
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["scope_check"], "unresolved")

    def test_scope_violation_record_marks_scope_violation(self):
        data = _base_input(
            changed_files=["scripts/unrelated/tool.py"],
            allowed_paths=["docs/workflows/ai-loop/**"],
        )
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["scope_check"], "scope_violation")

    def test_auto_approved_record_still_in_scope(self):
        """scope 検査を通過した AUTO_APPROVED は従来どおり scope_check == "in_scope"。"""
        data = _base_input()
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertEqual(provenance["scope_check"], "in_scope")

    def test_lite_false_after_scope_pass_is_in_scope(self):
        """lite=false（priority 2）は scope 検査通過後に評価されるため in_scope。"""
        data = _base_input(
            lite={"size_ok": False, "no_new_design": True, "follows_pattern": True, "reversible": True}
        )
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["scope_check"], "in_scope")

    def test_build_provenance_default_scope_check_is_not_evaluated(self):
        """build_provenance の scope_check 既定値は "not_evaluated"（"in_scope" ではない）。"""
        prov = arbiter.build_provenance(
            decision="HUMAN_ESCALATED",
            boundary="touches-HO",
            lite_result=True,
            class_value="no-merge",
            target_sha="abc1234",
            model_a="approve",
            model_b="approve",
        )
        self.assertEqual(prov["scope_check"], "not_evaluated")


class HoPathsProvenanceVisibilityTests(unittest.TestCase):
    """敵対的レビュー minor（Finding 2・#809）: ho-paths 出典・抽出件数の record 刻印。"""

    def test_all_records_carry_ho_paths_source_and_count(self):
        """全裁定経路の record に ho_paths_source（非 null）と ho_pattern_count（正の int）が刻まれる。"""
        scenarios = [
            ("auto_approved", _base_input()),
            ("touches_ho", _base_input(changed_files=["bin/plangate"], allowed_paths=["bin/plangate"])),
            (
                "scope_violation",
                _base_input(
                    changed_files=["scripts/unrelated/tool.py"],
                    allowed_paths=["docs/workflows/ai-loop/**"],
                ),
            ),
            (
                "lite_false",
                _base_input(
                    lite={"size_ok": False, "no_new_design": True, "follows_pattern": True, "reversible": True}
                ),
            ),
        ]
        for name, data in scenarios:
            with self.subTest(scenario=name):
                provenance, _ = arbiter.arbitrate(data)
                self.assertIn("ho_paths_source", provenance)
                self.assertIn("ho_pattern_count", provenance)
                self.assertIsNotNone(provenance["ho_paths_source"], "解決時は非 null")
                self.assertIsInstance(provenance["ho_pattern_count"], int)
                self.assertGreater(provenance["ho_pattern_count"], 0)

    def test_ho_paths_source_matches_resolved_path(self):
        data = _base_input()
        patterns, source, _searched = arbiter.resolve_ho_patterns()
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["ho_paths_source"], source)
        self.assertEqual(provenance["ho_pattern_count"], len(patterns))

    def test_fail_closed_record_has_null_source_and_zero_count(self):
        """解決不能（fail-closed）時は ho_paths_source == None・ho_pattern_count == 0。"""
        data = _base_input()
        provenance, _ = arbiter.arbitrate(data, ho_paths_path="/nonexistent/ho-paths.md")
        self.assertIsNone(provenance["ho_paths_source"])
        self.assertEqual(provenance["ho_pattern_count"], 0)

    def test_under_coverage_is_detectable_via_count(self):
        """過少網羅（1 行 ho-paths.md）を ho_pattern_count で検知できる（可視化）。"""
        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            tiny = pathlib.Path(tmpdir) / "tiny-ho-paths.md"
            tiny.write_text(
                "## HO パス一覧\n\n"
                "| パス | 分類 | 変更禁止理由 |\n"
                "|------|------|------------|\n"
                "| `bin/plangate` | HO-core | 唯一の HO パターン |\n",
                encoding="utf-8",
            )
            data = _base_input(
                changed_files=["docs/workflows/ai-loop/example.md"],
                allowed_paths=["docs/workflows/ai-loop/**"],
            )
            provenance, _ = arbiter.arbitrate(data, ho_paths_path=str(tiny))
            # boundary=clean だが ho_pattern_count=1 の過少網羅が record から読める
            self.assertEqual(provenance["boundary_check"], "clean")
            self.assertEqual(provenance["ho_pattern_count"], 1)


class GeminiSecurityHardeningTests(unittest.TestCase):
    """PR #813 gemini レビュー反映（#809）: バックスラッシュ traversal / read_text
    の ValueError / regex キャッシュ。
    """

    # --- 修正 1（security-high）: バックスラッシュ経路の traversal 封鎖 ---

    def test_backslash_traversal_rejected_in_validate(self):
        """`foo\\..\\bar`（バックスラッシュ traversal）は入力段で拒否。"""
        data = _base_input(changed_files=["foo\\..\\bar"])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_plain_backslash_rejected_in_validate(self):
        """`foo\\bar`（.. を含まない単なるバックスラッシュ区切り）も一律拒否。"""
        data = _base_input(changed_files=["foo\\bar"])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_backslash_rejected_in_allowed_paths(self):
        data = _base_input(allowed_paths=["foo\\..\\**"])
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_safe_normalized_path_flags_backslash(self):
        _norm, err = arbiter._safe_normalized_path("foo\\..\\bar")
        self.assertIsNotNone(err)
        self.assertIn("\\", err)

    def test_backslash_boundary_check_is_safe_side(self):
        """判定関数単体でも、バックスラッシュ経路は clean にせず touches-HO 相当に倒す。"""
        boundary, matched = arbiter.boundary_check(["foo\\..\\bin\\plangate"])
        self.assertEqual(boundary, "touches-HO")
        self.assertTrue(matched)

    def _run_main_with_stdin(self, payload):
        import io

        old_stdin, old_stdout, old_stderr = sys.stdin, sys.stdout, sys.stderr
        sys.stdin = io.StringIO(json.dumps(payload))
        sys.stdout = io.StringIO()
        sys.stderr = io.StringIO()
        try:
            code = arbiter.main([])
            out, err = sys.stdout.getvalue(), sys.stderr.getvalue()
        finally:
            sys.stdin, sys.stdout, sys.stderr = old_stdin, old_stdout, old_stderr
        return code, out, err

    def test_e2e_backslash_traversal_exits_1_never_auto_approves(self):
        """再現固定: バックスラッシュ traversal は exit 1（入力エラー）で
        AUTO_APPROVED / clean にならない。
        """
        data = _base_input(changed_files=["foo\\..\\bin\\plangate"], allowed_paths=["**"])
        code, out, err = self._run_main_with_stdin(data)
        self.assertEqual(code, 1)
        self.assertNotIn("AUTO_APPROVED", out)
        self.assertIn("入力エラー", err)

    # --- 修正 2（medium）: read_text の UnicodeDecodeError（ValueError）で fail-closed ---

    def test_resolve_ho_patterns_skips_undecodable_file(self):
        """不正 UTF-8 の ho-paths 明示指定 → 当該候補 skip、他候補なしで fail-closed（patterns=[]）。"""
        with tempfile.TemporaryDirectory() as tmp:
            bad = pathlib.Path(tmp) / "bad-ho-paths.md"
            bad.write_bytes(b"\xff\xfe\x00\x01 invalid utf-8 \x80\x81")
            patterns, source, searched = arbiter.resolve_ho_patterns(str(bad))
            self.assertEqual(patterns, [])
            self.assertIsNone(source)
            self.assertEqual(searched, [str(bad)])

    def test_arbitrate_fail_closed_on_undecodable_ho_paths(self):
        """不正 UTF-8 の ho-paths 指定時、arbitrate は全件 HUMAN_ESCALATED（fail-closed）。"""
        with tempfile.TemporaryDirectory() as tmp:
            bad = pathlib.Path(tmp) / "bad-ho-paths.md"
            bad.write_bytes(b"\xff\xfe\x00\x01\x80\x81\x82")
            data = _base_input()  # 本来なら AUTO_APPROVED になる happy-path 入力
            provenance, reason = arbiter.arbitrate(data, ho_paths_path=str(bad))
            self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
            self.assertEqual(provenance["boundary_check"], "unresolved")
            self.assertIn("fail-closed", reason)

    # --- 修正 3（medium・perf）: regex キャッシュ導入後も判定不変（回帰） ---

    def test_regex_cache_preserves_boundary_semantics(self):
        """キャッシュ導入後も既存 boundary 判定が全て不変であることの回帰確認。"""
        cases = [
            (["bin/plangate"], "touches-HO"),
            (["scripts/hooks/check-plan-hash.sh"], "touches-HO"),
            (["schemas/plan.schema.json"], "touches-HO"),
            ([".claude/rules/mode-classification.md"], "touches-HO"),
            (["docs/ai/ai-loop/ho-paths.md"], "touches-HO"),
            (["docs/ai/ai-loop/concept.md"], "clean"),
            (["docs/workflows/ai-loop/decision-table.md"], "clean"),
            (["plugin/plangate/index.js"], "touches-HO"),
        ]
        for changed, expected in cases:
            with self.subTest(changed=changed):
                boundary, _ = arbiter.boundary_check(changed)
                self.assertEqual(boundary, expected)

    def test_regex_cache_returns_identical_compiled_object(self):
        """同一パターンの再変換がキャッシュされ、同一 compiled regex を返す（メモ化の実証）。"""
        first = arbiter._ho_pattern_to_regex("scripts/hooks/**")
        second = arbiter._ho_pattern_to_regex("scripts/hooks/**")
        self.assertIs(first, second)


class RunMetaValidationTests(unittest.TestCase):
    """#780 Slice D 後半: 入力 `run`（任意フィールド）のバリデーション。"""

    def test_run_absent_passes_validation(self):
        data = _base_input()
        validated = arbiter.validate_input(data)
        self.assertNotIn("run", validated)

    def test_run_valid_without_repair_action_passes(self):
        data = _base_input(run={"run_id": "run-001", "round_index": 1, "task_id": "TASK-0780"})
        validated = arbiter.validate_input(data)
        self.assertEqual(validated["run"]["run_id"], "run-001")

    def test_run_valid_with_repair_action_passes(self):
        data = _base_input(
            run={
                "run_id": "run-001",
                "round_index": 2,
                "task_id": "TASK-0780",
                "repair_action": "reject 指摘に基づき修正",
            }
        )
        validated = arbiter.validate_input(data)
        self.assertEqual(validated["run"]["repair_action"], "reject 指摘に基づき修正")

    def test_run_non_dict_raises(self):
        data = _base_input(run="not-a-dict")
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_run_id_empty_string_raises(self):
        data = _base_input(run={"run_id": "", "round_index": 1, "task_id": "TASK-0780"})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_run_id_whitespace_only_raises(self):
        data = _base_input(run={"run_id": "   ", "round_index": 1, "task_id": "TASK-0780"})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_run_id_non_string_raises(self):
        data = _base_input(run={"run_id": 123, "round_index": 1, "task_id": "TASK-0780"})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_round_index_string_raises(self):
        data = _base_input(run={"run_id": "run-001", "round_index": "1", "task_id": "TASK-0780"})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_round_index_bool_raises(self):
        """round_index は bool を除外した厳密 int（bool は int のサブクラス）。"""
        data = _base_input(run={"run_id": "run-001", "round_index": True, "task_id": "TASK-0780"})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_round_index_missing_raises(self):
        data = _base_input(run={"run_id": "run-001", "task_id": "TASK-0780"})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_task_id_int_raises(self):
        data = _base_input(run={"run_id": "run-001", "round_index": 1, "task_id": 780})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_task_id_empty_string_raises(self):
        """task_id は run_id と対称に非空 str 必須（空文字は exit 1 / gemini medium）。"""
        data = _base_input(run={"run_id": "run-001", "round_index": 1, "task_id": ""})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_task_id_whitespace_only_raises(self):
        """task_id 空白のみ（strip 後空）は非空要件を満たさず exit 1（gemini medium 実測是正）。"""
        data = _base_input(run={"run_id": "run-001", "round_index": 1, "task_id": "   "})
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)

    def test_repair_action_non_string_raises(self):
        data = _base_input(
            run={"run_id": "run-001", "round_index": 1, "task_id": "TASK-0780", "repair_action": 5}
        )
        with self.assertRaises(arbiter.InputError):
            arbiter.validate_input(data)


class RunMetaProvenanceTests(unittest.TestCase):
    """#780 Slice D 後半: provenance への run 刻印（全裁定経路で additive に刻む）。"""

    RUN_META = {"run_id": "run-999", "round_index": 1, "task_id": "TASK-0780"}

    def test_run_absent_omits_run_key(self):
        """入力に run が無いときは provenance に run キー自体を刻まない
        （`run: null` を出さない）。metrics.py がこれを legacy（run キー欠落）に
        正しく分類できるようにするため（invalid_run_meta 誤計上の回避）。"""
        data = _base_input()
        self.assertNotIn("run", data)
        provenance, _ = arbiter.arbitrate(data)
        self.assertNotIn("run", provenance)

    def test_priority0_fail_closed_carries_run(self):
        data = _base_input(run=self.RUN_META)
        provenance, _ = arbiter.arbitrate(data, ho_paths_path="/nonexistent/ho-paths.md")
        self.assertEqual(provenance["boundary_check"], "unresolved")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority1_touches_ho_carries_run(self):
        data = _base_input(run=self.RUN_META, changed_files=["bin/plangate"])
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["boundary_check"], "touches-HO")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority1_5_scope_violation_carries_run(self):
        data = _base_input(run=self.RUN_META, changed_files=["out/of/scope.md"])
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["scope_check"], "scope_violation")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority2_lite_false_carries_run(self):
        data = _base_input(
            run=self.RUN_META,
            lite={
                "size_ok": False,
                "no_new_design": True,
                "follows_pattern": True,
                "reversible": True,
            },
        )
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority3_merge_carries_run(self):
        data = _base_input(run=self.RUN_META, **{"class": "merge"})
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority4_blocked_carries_run(self):
        data = _base_input(run=self.RUN_META)
        data["verdicts"]["model_a"] = "reject"
        data["verdicts"]["model_b"] = "reject"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "BLOCKED")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority5_human_escalated_carries_run(self):
        data = _base_input(run=self.RUN_META)
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "auth_change"  # severity=major
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "HUMAN_ESCALATED")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority5_cd_auto_approved_carries_run(self):
        data = _base_input(run=self.RUN_META)
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "logic"  # severity=minor
        data["verdicts"]["model_c"] = "approve"
        data["verdicts"]["model_d"] = "approve"
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_priority6_auto_approved_carries_run(self):
        data = _base_input(run=self.RUN_META)
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["decision"], "AUTO_APPROVED")
        self.assertEqual(provenance["run"], self.RUN_META)

    def test_policy_ref_unchanged_when_run_present(self):
        """run は additive provenance であり policy 改版ではない（run 追加は据え置き。
        現行ベースラインは #780 Slice B の gates 必須化で @v2 — run 起因の改版ではない）。"""
        data = _base_input(run=self.RUN_META)
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["policy_ref"], "auto-approve-lite-clean@v2")


class ArbiterMetricsIntegrationTests(unittest.TestCase):
    """#780 Slice D 後半の核心: arbiter が刻んだ run 付き record を実際に
    metrics.py（#812 消費側）へ渡し、first_pass 判定が正しく機能することを実証する。
    """

    @classmethod
    def setUpClass(cls):
        import metrics as metrics_module  # noqa: E402  (sys.path は本ファイル冒頭で設定済み)

        cls.metrics = metrics_module

    def test_first_pass_false_when_round1_rejected_then_round2_auto_approved(self):
        run_id = "run-780-int-reject-then-approve"

        round1 = _base_input(run={"run_id": run_id, "round_index": 1, "task_id": "TASK-0780"})
        round1["verdicts"]["model_a"] = "reject"
        round1["verdicts"]["model_b"] = "reject"
        arbiter.validate_input(round1)
        prov1, _ = arbiter.arbitrate(round1)
        self.assertEqual(prov1["decision"], "BLOCKED")

        round2 = _base_input(
            run={
                "run_id": run_id,
                "round_index": 2,
                "task_id": "TASK-0780",
                "repair_action": "reject 指摘（reject-reject）に基づき修正",
            }
        )
        arbiter.validate_input(round2)
        prov2, _ = arbiter.arbitrate(round2)
        self.assertEqual(prov2["decision"], "AUTO_APPROVED")

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            (tmp_path / "round1.json").write_text(json.dumps(prov1), encoding="utf-8")
            (tmp_path / "round2.json").write_text(json.dumps(prov2), encoding="utf-8")

            report = self.metrics.collect(tmp_path)

        self.assertEqual(report["run_count"], 1)
        self.assertEqual(report["legacy_count"], 0)
        self.assertEqual(report["invalid_run_meta_count"], 0)
        self.assertEqual(report["first_pass"]["denominator"], 1)
        self.assertEqual(report["first_pass"]["numerator"], 0)
        self.assertEqual(report["first_pass"]["rate"], 0.0)
        self.assertEqual(report["round_distribution"], {2: 1})

    def test_first_pass_true_when_round1_auto_approved(self):
        run_id = "run-780-int-first-pass"

        round1 = _base_input(run={"run_id": run_id, "round_index": 1, "task_id": "TASK-0780"})
        arbiter.validate_input(round1)
        prov1, _ = arbiter.arbitrate(round1)
        self.assertEqual(prov1["decision"], "AUTO_APPROVED")

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            (tmp_path / "round1.json").write_text(json.dumps(prov1), encoding="utf-8")

            report = self.metrics.collect(tmp_path)

        self.assertEqual(report["run_count"], 1)
        self.assertEqual(report["first_pass"]["numerator"], 1)
        self.assertEqual(report["first_pass"]["denominator"], 1)
        self.assertEqual(report["first_pass"]["rate"], 1.0)

    def test_run_omitted_record_is_classified_as_legacy_not_invalid_run_meta(self):
        """入力に run が無い後方互換呼び出しは provenance に run キーを刻まない
        （`run: null` を出さない）。これにより metrics.py は当該 record を
        legacy（run メタ未計装・集計対象外の正常レコード）に分類し、
        invalid_run_meta（run メタを主張するが run_id が falsy＝要注意）には
        入れない。未計装が要注意カテゴリに水増しされる問題（#780 コーディネータ
        指摘）を防ぐ。"""
        legacy = _base_input()
        self.assertNotIn("run", legacy)
        arbiter.validate_input(legacy)
        prov_legacy, _ = arbiter.arbitrate(legacy)
        self.assertNotIn("run", prov_legacy)  # run キーは刻まれない（null でもない）

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            (tmp_path / "no-run-input.json").write_text(json.dumps(prov_legacy), encoding="utf-8")

            report = self.metrics.collect(tmp_path)

        self.assertEqual(report["legacy_count"], 1)
        self.assertEqual(report["invalid_run_meta_count"], 0)
        self.assertEqual(report["run_count"], 0)
        self.assertEqual(report["first_pass"]["denominator"], 0)
        self.assertIsNone(report["first_pass"]["rate"])

    def test_round_index_origin_contract_1_counts_0_does_not(self):
        """round_index 起点契約の回帰固定（レビュー major 反映）。

        metrics.py（変更禁止・#812）は round_index==1 を初回ラウンドの sentinel
        として first_pass を判定する（`next(r for r in rounds if
        r["run"].get("round_index") == 1)`）。したがって呼び出し側は初回に
        round_index=1 を刻まねばならず、doc が誤って「0 起点」を指示すると
        成功 run が恒久的に first_pass 分子から漏れる（サイレント過小集計）。

        arbiter は round_index の値をそのまま刻む（int 検証のみ）ため、この
        テストは arbiter→metrics の実経路で「1 起点=分子に入る / 0 起点=入らない」
        を明示アサートし、doc/実装契約の再ズレを検知する。"""
        # 起点=1 の AUTO record 単独 → first_pass 分子に入る
        r1 = _base_input(run={"run_id": "run-origin-1", "round_index": 1, "task_id": "TASK-0780"})
        arbiter.validate_input(r1)
        prov1, _ = arbiter.arbitrate(r1)
        self.assertEqual(prov1["decision"], "AUTO_APPROVED")
        self.assertEqual(prov1["run"]["round_index"], 1)

        # 起点=0 の AUTO record 単独（0 起点の初回を模擬）→ 分子に入らない
        r0 = _base_input(run={"run_id": "run-origin-0", "round_index": 0, "task_id": "TASK-0780"})
        arbiter.validate_input(r0)
        prov0, _ = arbiter.arbitrate(r0)
        self.assertEqual(prov0["decision"], "AUTO_APPROVED")
        self.assertEqual(prov0["run"]["round_index"], 0)

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            (tmp_path / "origin-1.json").write_text(json.dumps(prov1), encoding="utf-8")
            (tmp_path / "origin-0.json").write_text(json.dumps(prov0), encoding="utf-8")
            report = self.metrics.collect(tmp_path)

        # 2 run とも分母（run 単位）には入るが、分子は round_index==1 の run のみ
        self.assertEqual(report["run_count"], 2)
        self.assertEqual(report["first_pass"]["denominator"], 2)
        self.assertEqual(report["first_pass"]["numerator"], 1)
        self.assertEqual(report["first_pass"]["rate"], 0.5)


class MainExitCodeTests(unittest.TestCase):
    """main() の exit code 契約（0/2/3/1）を stdin 経由で確認する。"""

    def _run_main_with_stdin(self, payload):
        import io

        old_stdin = sys.stdin
        old_stdout = sys.stdout
        old_stderr = sys.stderr
        sys.stdin = io.StringIO(json.dumps(payload) if payload is not None else "not-json")
        sys.stdout = io.StringIO()
        sys.stderr = io.StringIO()
        try:
            code = arbiter.main([])
            stdout_value = sys.stdout.getvalue()
            stderr_value = sys.stderr.getvalue()
        finally:
            sys.stdin = old_stdin
            sys.stdout = old_stdout
            sys.stderr = old_stderr
        return code, stdout_value, stderr_value

    def test_auto_approved_exit_0(self):
        code, stdout_value, _ = self._run_main_with_stdin(_base_input())
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(stdout_value)["decision"], "AUTO_APPROVED")

    def test_human_escalated_exit_2(self):
        code, _, _ = self._run_main_with_stdin(_base_input(**{"class": "merge"}))
        self.assertEqual(code, 2)

    def test_blocked_exit_3(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "reject"
        data["verdicts"]["model_b"] = "reject"
        code, _, _ = self._run_main_with_stdin(data)
        self.assertEqual(code, 3)

    def test_input_error_exit_1(self):
        code, _, stderr_value = self._run_main_with_stdin(None)
        self.assertEqual(code, 1)
        self.assertIn("入力エラー", stderr_value)




class ArbitrateCharacterizationTests(unittest.TestCase):
    """TASK-0814 R0: arbitrate() のリファクタリング（動作不変）に対する固定基準。

    全 priority 経路（0 fail-closed / 1 touches-HO / 1.5 scope_violation /
    2 lite=false / 3 class=merge / 4 verdict reject（reject-reject と
    reject-approve の両方）/ 5 approve-reject（severity critical/major、
    minor 側は C/D 裁定の 4 パターン + 欠落ケース）/ 6 approve-approve、
    加えて run メタ付き（#780 Slice D 後半・additive）を網羅する。

    各シナリオの (provenance dict, reason str) を **リファクタ前の現行コード
    で実測して固定した値** と突き合わせる。`timestamp` は実行時刻依存のため
    比較対象から除外し、`ho_paths_source` は cwd 依存の絶対パスのため
    `_NORMALIZED_HO_SOURCE` プレースホルダに正規化してから比較する
    （いずれも arbitrate() の priority 分岐ロジックとは無関係な環境依存
    フィールドであり、正規化してもバイト一致検証の意味は損なわない）。

    Python dict の等価性は JSON へ sort_keys=True でダンプした文字列の
    等価性と同値（キー集合・値が完全一致すれば同一 JSON 文字列になる）
    ため、本テストの assertEqual(dict, dict) が「record バイト一致」の
    機械証明として機能する。

    このテストが緑のまま Step 1〜3（_evaluate_signals 抽出 → priority
    テーブル化 → _require_normalized_path_list 抽出）を完了できることが
    「動作不変」の機械証明となる。
    """

    _NORMALIZED_HO_SOURCE = "<HO_PATHS_SOURCE>"

    @classmethod
    def _normalize(cls, provenance):
        normalized = dict(provenance)
        normalized.pop("timestamp", None)
        if normalized.get("ho_paths_source") is not None:
            normalized["ho_paths_source"] = cls._NORMALIZED_HO_SOURCE
        return normalized

    def _run(self, data, **kwargs):
        provenance, reason = arbiter.arbitrate(data, **kwargs)
        return self._normalize(provenance), reason

    def _assert_json_roundtrip_stable(self, provenance):
        """provenance を sort_keys=True JSON にダンプ→再ロードして元と一致
        することを確認する（「バイト一致」の直接的な機械証明の補強）。"""
        dumped = json.dumps(provenance, ensure_ascii=False, sort_keys=True)
        self.assertEqual(json.loads(dumped), provenance)

    def test_priority0_fail_closed(self):
        data = _base_input()
        provenance, reason = self._run(data, ho_paths_path="/nonexistent/ho-paths.md")
        self.assertEqual(
            provenance,
            {
                "boundary_check": "unresolved",
                "class_check": "no-merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": None,
                "ho_pattern_count": 0,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "unresolved",
                "target_sha": "abc1234",
                "w_check": {"model_a": "approve", "model_b": "approve"},
            },
        )
        self.assertEqual(
            reason,
            "priority 0: ho-paths unresolved (fail-closed)。探索パス: /nonexistent/ho-paths.md",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority1_touches_ho(self):
        data = _base_input(
            changed_files=["bin/plangate"],
            lite={"size_ok": False, "no_new_design": False, "follows_pattern": False, "reversible": False},
            **{"class": "merge"},
        )
        data["verdicts"] = {
            "model_a": "reject",
            "model_b": "reject",
            "reject_category": None,
            "model_c": None,
            "model_d": None,
        }
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "touches-HO",
                "class_check": "merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": False,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "not_evaluated",
                "target_sha": "abc1234",
                "w_check": {"model_a": "reject", "model_b": "reject"},
            },
        )
        self.assertEqual(
            reason,
            "priority 1: boundary=touches-HO（絶対条件・固定）。一致パス: bin/plangate (bin/plangate / HO-core)",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority1_5_scope_violation(self):
        data = _base_input(changed_files=["docs/other/outside.md"], allowed_paths=["docs/workflows/ai-loop/**"])
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "scope_violation",
                "target_sha": "abc1234",
                "w_check": {"model_a": "approve", "model_b": "approve"},
            },
        )
        self.assertEqual(
            reason,
            "priority 1.5: boundary=clean だが scope_violation（allowed_paths 逸脱パス: docs/other/outside.md）",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority2_lite_false(self):
        data = _base_input(lite={"size_ok": False, "no_new_design": True, "follows_pattern": True, "reversible": True})
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": False,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {"model_a": "approve", "model_b": "approve"},
            },
        )
        self.assertEqual(reason, "priority 2: boundary=clean だが lite=false（低リスク要件未充足）")
        self._assert_json_roundtrip_stable(provenance)

    def test_priority3_class_merge(self):
        data = _base_input(**{"class": "merge"})
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {"model_a": "approve", "model_b": "approve"},
            },
        )
        self.assertEqual(reason, "priority 3: class=merge（Human-owned 固定）")
        self._assert_json_roundtrip_stable(provenance)

    def test_priority4_reject_reject(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "reject"
        data["verdicts"]["model_b"] = "reject"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "BLOCKED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {"model_a": "reject", "model_b": "reject"},
            },
        )
        self.assertEqual(
            reason,
            "priority 4: verdict=reject-reject（A が設計妥当性で NG、または両者合意で NG）",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority4_reject_approve(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "reject"
        data["verdicts"]["model_b"] = "approve"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "BLOCKED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {"model_a": "reject", "model_b": "approve"},
            },
        )
        self.assertEqual(
            reason,
            "priority 4: verdict=reject-approve（A が設計妥当性で NG、または両者合意で NG）",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority6_approve_approve(self):
        data = _base_input()
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "AUTO_APPROVED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {"model_a": "approve", "model_b": "approve"},
            },
        )
        self.assertEqual(reason, "priority 6: verdict=approve-approve（合意）")
        self._assert_json_roundtrip_stable(provenance)

    def test_priority5_severity_critical(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "security_break"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {
                    "model_a": "approve",
                    "model_b": "reject",
                    "reject_category": "security_break",
                    "severity": "critical",
                },
            },
        )
        self.assertEqual(
            reason,
            "priority 5: verdict=approve-reject, severity=critical（reject_category='security_break'）→ human escalate 固定",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority5_severity_major(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "auth_change"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {
                    "model_a": "approve",
                    "model_b": "reject",
                    "reject_category": "auth_change",
                    "severity": "major",
                },
            },
        )
        self.assertEqual(
            reason,
            "priority 5: verdict=approve-reject, severity=major（reject_category='auth_change'）→ human escalate 固定",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority5_cd_missing(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "logic"
        data["verdicts"]["model_c"] = None
        data["verdicts"]["model_d"] = "approve"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {
                    "model_a": "approve",
                    "model_b": "reject",
                    "model_d": "approve",
                    "reject_category": "logic",
                    "severity": "minor",
                },
            },
        )
        self.assertEqual(
            reason,
            "priority 5: severity=minor だが model_c/model_d のいずれかが欠落 → human escalate（安全側）",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority5_cd_approve_approve(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "logic"
        data["verdicts"]["model_c"] = "approve"
        data["verdicts"]["model_d"] = "approve"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "AUTO_APPROVED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {
                    "model_a": "approve",
                    "model_b": "reject",
                    "model_c": "approve",
                    "model_d": "approve",
                    "reject_category": "logic",
                    "severity": "minor",
                },
            },
        )
        self.assertEqual(
            reason,
            "priority 5: severity=minor, C/D 裁定=approve-approve → AUTO_APPROVED",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority5_cd_reject_reject(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "logic"
        data["verdicts"]["model_c"] = "reject"
        data["verdicts"]["model_d"] = "reject"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "BLOCKED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {
                    "model_a": "approve",
                    "model_b": "reject",
                    "model_c": "reject",
                    "model_d": "reject",
                    "reject_category": "logic",
                    "severity": "minor",
                },
            },
        )
        self.assertEqual(
            reason,
            "priority 5: severity=minor, C/D 裁定=reject-reject → BLOCKED",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_priority5_cd_mixed(self):
        data = _base_input()
        data["verdicts"]["model_a"] = "approve"
        data["verdicts"]["model_b"] = "reject"
        data["verdicts"]["reject_category"] = "logic"
        data["verdicts"]["model_c"] = "approve"
        data["verdicts"]["model_d"] = "reject"
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "HUMAN_ESCALATED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {
                    "model_a": "approve",
                    "model_b": "reject",
                    "model_c": "approve",
                    "model_d": "reject",
                    "reject_category": "logic",
                    "severity": "minor",
                },
            },
        )
        self.assertEqual(
            reason,
            "priority 5: severity=minor, C/D 裁定=approve-reject → HUMAN_ESCALATED",
        )
        self._assert_json_roundtrip_stable(provenance)

    def test_with_run_meta_approve_approve(self):
        data = _base_input(run={"run_id": "run-001", "round_index": 0, "task_id": "TASK-0814", "repair_action": None})
        provenance, reason = self._run(data)
        self.assertEqual(
            provenance,
            {
                "boundary_check": "clean",
                "class_check": "no-merge",
                "decision": "AUTO_APPROVED",
                "ho_paths_source": self._NORMALIZED_HO_SOURCE,
                "ho_pattern_count": 18,
                "issued_by": "arbiter-v0.1",
                "lite_check": True,
                "policy_ref": "auto-approve-lite-clean@v2",
                "run": {
                    "repair_action": None,
                    "round_index": 0,
                    "run_id": "run-001",
                    "task_id": "TASK-0814",
                },
                "scope_check": "in_scope",
                "target_sha": "abc1234",
                "w_check": {"model_a": "approve", "model_b": "approve"},
            },
        )
        self.assertEqual(reason, "priority 6: verdict=approve-approve（合意）")
        self._assert_json_roundtrip_stable(provenance)


if __name__ == "__main__":
    unittest.main(verbosity=2)
