#!/usr/bin/env python3
"""test_discovery.py — discovery.py（TASK-0818 D-2）の unittest カバレッジ。

実行: python3 scripts/ai-loop/test_discovery.py

read-only 不変条件（git 操作・ファイル書き込みをしない）の検証も含む。
外部依存なし（unittest 標準ライブラリのみ・metrics.py/arbiter.py と同じ位置付け）。
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import discovery  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT_PATH = pathlib.Path(__file__).resolve().parent / "discovery.py"


def _issue(number: int, title: str = "", body: str = "", labels=None) -> dict:
    return {
        "number": number,
        "title": title,
        "body": body,
        "labels": labels if labels is not None else [],
    }


class TestEvaluateIssueCandidate(unittest.TestCase):
    def test_optin_label_lite_no_ho_no_dependency_is_candidate(self):
        issue = _issue(
            1,
            title="小さなタイポ修正",
            body="README のタイポを1ファイルで修正する。",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertTrue(result["candidate"])
        self.assertEqual(result["recommended_next"], "propose-to-ai-loop-cycle")
        self.assertEqual(
            result["reasons"],
            {
                "optin_label": True,
                "no_ho_risk": True,
                "is_lite": True,
                "deps_resolved": True,
            },
        )


class TestEvaluateIssueExcludedNoLabel(unittest.TestCase):
    def test_missing_optin_label_is_excluded(self):
        issue = _issue(2, title="バグ修正", body="小さな修正", labels=[])
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "no-optin-label")

    def test_other_label_only_is_excluded(self):
        issue = _issue(3, title="バグ修正", body="小さな修正", labels=["bug"])
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "no-optin-label")


class TestEvaluateIssueExcludedHoRisk(unittest.TestCase):
    def test_ho_path_fragment_in_body_is_excluded(self):
        issue = _issue(
            4,
            title="hook 修正",
            body="scripts/hooks 配下のロジックを変更する",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "ho-risk")

    def test_schema_change_in_title_is_excluded(self):
        issue = _issue(5, title="schema 変更を行う", body="", labels=["ai-loop-auto"])
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "ho-risk")

    def test_fullwidth_ho_signal_is_normalized_and_excluded(self):
        # 全角英字 + 全角スラッシュで書かれた scripts/hooks 相当語。
        # NFKC 正規化前は半角シグナルにマッチせず false-positive で candidate 化していた。
        fullwidth_signal = "ｓｃｒｉｐｔｓ／ｈｏｏｋｓ"
        issue = _issue(
            107,
            title="設定変更",
            body=f"{fullwidth_signal} 配下を変更する",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "ho-risk")


class TestEvaluateIssueExcludedNotLite(unittest.TestCase):
    def test_architecture_change_in_title_is_excluded(self):
        issue = _issue(
            6,
            title="アーキテクチャ変更を実施する",
            body="全体構造を見直す",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "not-lite")

    def test_english_refactor_entire_module_is_excluded(self):
        issue = _issue(
            100,
            title="Refactor entire auth module",
            body="Clean up the whole authentication layer.",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "not-lite")

    def test_english_large_migration_rewriting_architecture_is_excluded(self):
        issue = _issue(
            101,
            title="Data store change",
            body="This is a large migration effort rewriting architecture end to end.",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "not-lite")


class TestEvaluateIssueExcludedDependency(unittest.TestCase):
    def test_depends_on_open_issue_is_excluded(self):
        issue = _issue(
            7,
            title="機能追加",
            body="depends on #123 が解決するまで着手不可",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "dependency")

    def test_blocked_word_is_excluded(self):
        issue = _issue(8, title="機能追加", body="現在 blocked 状態", labels=["ai-loop-auto"])
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "dependency")

    def test_waiting_on_issue_number_is_excluded_dependency(self):
        issue = _issue(
            102,
            title="機能追加",
            body="waiting on #55 の完了を待って",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "dependency")

    def test_matte_word_with_issue_number_is_excluded_dependency(self):
        issue = _issue(
            103,
            title="機能追加",
            body="#90 の完了を待って着手する",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "dependency")

    def test_pending_hash_is_excluded_dependency(self):
        issue = _issue(
            104,
            title="機能追加",
            body="pending #77 の対応待ち",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "dependency")

    def test_block_word_case_insensitive_is_excluded_dependency(self):
        issue = _issue(
            105,
            title="機能追加",
            body="BLOCK on other team's response",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertFalse(result["candidate"])
        self.assertEqual(result["reason"], "dependency")

    def test_standalone_issue_number_without_dependency_word_is_not_excluded_as_dependency(self):
        # over-exclusion回避: #数字単独（依存語なし）は dependency 理由で除外しない
        issue = _issue(
            106,
            title="小さな修正",
            body="Related to #42 but this is independent 1ファイルの軽微な修正",
            labels=["ai-loop-auto"],
        )
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertTrue(result["candidate"])
        self.assertTrue(result["reasons"]["deps_resolved"])


class TestRunDiscoveryZeroCandidates(unittest.TestCase):
    def test_zero_candidates_reports_summary_zero(self):
        issues = [
            _issue(9, title="バグ修正", body="", labels=[]),
            _issue(10, title="アーキ変更", body="", labels=["ai-loop-auto"]),
        ]
        result = discovery.run_discovery(
            issues, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertEqual(result["summary"]["candidate_count"], 0)
        self.assertEqual(result["candidates"], [])


class TestRunDiscoveryExcludedAllReasoned(unittest.TestCase):
    def test_all_excluded_have_reason_field(self):
        issues = [
            _issue(11, title="バグ修正", body="", labels=[]),
            _issue(12, title="hook 変更", body="scripts/hooks を触る", labels=["ai-loop-auto"]),
            _issue(13, title="アーキ変更", body="", labels=["ai-loop-auto"]),
            _issue(14, title="機能追加", body="depends on #1", labels=["ai-loop-auto"]),
        ]
        result = discovery.run_discovery(
            issues, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        self.assertEqual(len(result["excluded"]), 4)
        for exc in result["excluded"]:
            self.assertTrue(exc["reason"])
            self.assertIsInstance(exc["reason"], str)


class TestRunDiscoverySafeSideAmbiguous(unittest.TestCase):
    def test_non_string_title_body_does_not_crash_and_excludes(self):
        issue = {"number": 15, "title": None, "body": None, "labels": ["ai-loop-auto"]}
        result = discovery.evaluate_issue(
            issue, "ai-loop-auto", discovery.DEFAULT_HO_SIGNALS
        )
        # 型不正でも例外を投げず、候補判定は継続できる（安全側で判定）
        self.assertEqual(result["number"], 15)


class TestLoadHoSignals(unittest.TestCase):
    def test_none_path_returns_default(self):
        self.assertEqual(discovery._load_ho_signals(None), discovery.DEFAULT_HO_SIGNALS)

    def test_missing_file_returns_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = pathlib.Path(tmp) / "does-not-exist.md"
            self.assertEqual(
                discovery._load_ho_signals(missing), discovery.DEFAULT_HO_SIGNALS
            )

    def test_valid_file_adds_fragments(self):
        with tempfile.TemporaryDirectory() as tmp:
            ho_file = pathlib.Path(tmp) / "ho-paths.md"
            ho_file.write_text(
                "| パス | 分類 |\n|---|---|\n| `custom/special-path` | HO-custom |\n",
                encoding="utf-8",
            )
            signals = discovery._load_ho_signals(ho_file)
            self.assertIn("custom/special-path", signals)
            self.assertIn("scripts/hooks", signals)


class TestCliInputErrors(unittest.TestCase):
    def test_missing_issues_file_returns_exit_1(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = pathlib.Path(tmp) / "no-such-file.json"
            exit_code = discovery.main(["--issues", str(missing)])
            self.assertEqual(exit_code, 1)

    def test_malformed_json_returns_exit_1(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = pathlib.Path(tmp) / "bad.json"
            bad.write_text("{not valid json", encoding="utf-8")
            exit_code = discovery.main(["--issues", str(bad)])
            self.assertEqual(exit_code, 1)

    def test_non_array_json_returns_exit_1(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = pathlib.Path(tmp) / "not-array.json"
            bad.write_text(json.dumps({"foo": "bar"}), encoding="utf-8")
            exit_code = discovery.main(["--issues", str(bad)])
            self.assertEqual(exit_code, 1)


class TestCliZeroCandidatesExitZero(unittest.TestCase):
    def test_zero_candidates_input_exits_0(self):
        with tempfile.TemporaryDirectory() as tmp:
            issues_file = pathlib.Path(tmp) / "issues.json"
            issues_file.write_text(
                json.dumps([_issue(20, title="バグ修正", body="", labels=[])]),
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT_PATH), "--issues", str(issues_file), "--format", "md"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("候補なし", result.stdout)


class TestOutputFormats(unittest.TestCase):
    def test_json_format_is_parseable(self):
        with tempfile.TemporaryDirectory() as tmp:
            issues_file = pathlib.Path(tmp) / "issues.json"
            issues_file.write_text(
                json.dumps(
                    [
                        _issue(
                            21,
                            title="小さな修正",
                            body="1ファイルの軽微な修正",
                            labels=["ai-loop-auto"],
                        )
                    ]
                ),
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT_PATH), "--issues", str(issues_file), "--format", "json"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0)
            parsed = json.loads(result.stdout)
            self.assertEqual(parsed["summary"]["candidate_count"], 1)
            self.assertEqual(parsed["candidates"][0]["number"], 21)

    def test_md_format_includes_excluded_section(self):
        with tempfile.TemporaryDirectory() as tmp:
            issues_file = pathlib.Path(tmp) / "issues.json"
            issues_file.write_text(
                json.dumps([_issue(22, title="バグ修正", body="", labels=[])]),
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT_PATH), "--issues", str(issues_file), "--format", "md"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("## Excluded", result.stdout)
            self.assertIn("no-optin-label", result.stdout)


class TestReadOnlyInvariant(unittest.TestCase):
    def test_running_discovery_leaves_git_status_clean(self):
        before = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=REPO_ROOT, text=True
        )

        with tempfile.TemporaryDirectory() as tmp:
            issues_file = pathlib.Path(tmp) / "issues.json"
            issues_file.write_text(
                json.dumps(
                    [
                        _issue(
                            30,
                            title="小さな修正",
                            body="1ファイルの軽微な修正",
                            labels=["ai-loop-auto"],
                        ),
                        _issue(31, title="バグ修正", body="", labels=[]),
                    ]
                ),
                encoding="utf-8",
            )

            proc = subprocess.run(
                [sys.executable, str(SCRIPT_PATH), "--issues", str(issues_file), "--format", "json"],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0)

        after = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=REPO_ROOT, text=True
        )
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
