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
        self.assertEqual(provenance["policy_ref"], "auto-approve-lite-clean@v1")
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
    """TC-11: POLICY_REF が @v1 へ改版されていること（allowed_paths 必須化・fail-closed機械化）。"""

    def test_tc11_policy_ref_is_v1(self):
        self.assertEqual(arbiter.POLICY_REF, "auto-approve-lite-clean@v1")

    def test_tc11_provenance_policy_ref_is_v1(self):
        data = _base_input()
        provenance, _ = arbiter.arbitrate(data)
        self.assertEqual(provenance["policy_ref"], "auto-approve-lite-clean@v1")


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


if __name__ == "__main__":
    unittest.main(verbosity=2)
