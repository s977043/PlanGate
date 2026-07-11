#!/usr/bin/env python3
"""test_metrics.py — metrics.py の unittest カバレッジ（外部依存なし）。

実行: python3 scripts/ai-loop/test_metrics.py
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import metrics  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
REAL_RUNS_DIR = REPO_ROOT / "docs" / "working" / "ai-loop-runs"
SCRIPT_PATH = pathlib.Path(__file__).resolve().parent / "metrics.py"


def _write(dir_path: pathlib.Path, name: str, payload) -> None:
    (dir_path / name).write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def _legacy_record(decision="AUTO_APPROVED", target_sha="aaa0001"):
    return {
        "boundary_check": "clean",
        "class_check": "no-merge",
        "decision": decision,
        "issued_by": "arbiter-v0.1",
        "lite_check": True,
        "policy_ref": "auto-approve-lite-clean@v0",
        "target_sha": target_sha,
        "timestamp": "2026-07-02T21:29:46Z",
        "w_check": {
            "model_a": "approve",
            "model_b": "approve",
            "model_c": "approve",
            "model_d": "approve",
            "severity": "low",
        },
    }


def _run_record(run_id, round_index, decision, target_sha, reject_category=None, repair_action=None):
    record = _legacy_record(decision=decision, target_sha=target_sha)
    if reject_category is not None:
        record["w_check"]["reject_category"] = reject_category
    run_meta = {"run_id": run_id, "round_index": round_index, "task_id": "TASK-0809"}
    if repair_action is not None:
        run_meta["repair_action"] = repair_action
    record["run"] = run_meta
    return record


class TestNewSchemaFirstPass(unittest.TestCase):
    """新形式 fixture で first-pass rate を厳密一致で検証する。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        # run-A: 1 ラウンドで AUTO_APPROVED -> first_pass=true
        _write(
            self.runs_dir,
            "run-A-r1.json",
            _run_record("run-A", 1, "AUTO_APPROVED", "aaa0001"),
        )

        # run-B: reject x2 -> AUTO_APPROVED (3 ラウンド目) -> first_pass=false
        _write(
            self.runs_dir,
            "run-B-r1.json",
            _run_record("run-B", 1, "HUMAN_ESCALATED", "bbb0001", reject_category="logic"),
        )
        _write(
            self.runs_dir,
            "run-B-r2.json",
            _run_record(
                "run-B", 2, "HUMAN_ESCALATED", "bbb0002",
                reject_category="test_shortage", repair_action="add missing unit tests",
            ),
        )
        _write(
            self.runs_dir,
            "run-B-r3.json",
            _run_record("run-B", 3, "AUTO_APPROVED", "bbb0003"),
        )

        # run-C: 1 ラウンドで HUMAN_ESCALATED -> first_pass=false (escalate)
        _write(
            self.runs_dir,
            "run-C-r1.json",
            _run_record("run-C", 1, "HUMAN_ESCALATED", "ccc0001", reject_category="documentation"),
        )

        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_run_count(self):
        self.assertEqual(self.report["run_count"], 3)

    def test_first_pass_rate_exact(self):
        # run-A: first_pass True / run-B: False / run-C: False -> 1/3
        self.assertEqual(self.report["first_pass"]["numerator"], 1)
        self.assertEqual(self.report["first_pass"]["denominator"], 3)
        self.assertAlmostEqual(self.report["first_pass"]["rate"], 1 / 3)

    def test_round_distribution(self):
        dist = self.report["round_distribution"]
        # run-A:1round, run-B:3rounds, run-C:1round
        self.assertEqual(dist.get(1), 2)
        self.assertEqual(dist.get(3), 1)

    def test_decision_counts(self):
        counts = self.report["decision_counts"]
        self.assertEqual(counts["AUTO_APPROVED"], 2)
        self.assertEqual(counts["HUMAN_ESCALATED"], 3)
        self.assertEqual(counts.get("BLOCKED", 0), 0)

    def test_failure_category_breakdown(self):
        breakdown = self.report["failure_category_breakdown"]
        self.assertEqual(breakdown.get("logic"), 1)
        self.assertEqual(breakdown.get("test_shortage"), 1)
        self.assertEqual(breakdown.get("documentation"), 1)


class TestLegacyExclusion(unittest.TestCase):
    """run メタ無しの legacy record は集計母数から除外され、除外件数が明示される。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        _write(self.runs_dir, "legacy-1.json", _legacy_record(target_sha="leg0001"))
        _write(self.runs_dir, "legacy-2.json", _legacy_record(target_sha="leg0002"))
        _write(
            self.runs_dir,
            "run-A-r1.json",
            _run_record("run-A", 1, "AUTO_APPROVED", "aaa0001"),
        )

        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_legacy_count_reported(self):
        self.assertEqual(self.report["legacy_count"], 2)

    def test_run_count_excludes_legacy(self):
        self.assertEqual(self.report["run_count"], 1)

    def test_first_pass_denominator_excludes_legacy(self):
        self.assertEqual(self.report["first_pass"]["denominator"], 1)

    def test_total_records_includes_legacy(self):
        self.assertEqual(self.report["total_records"], 3)

    def test_markdown_mentions_legacy_count(self):
        md = metrics.render_markdown(self.report)
        self.assertIn("legacy record 2 件", md)


class TestCorruptedJsonSkip(unittest.TestCase):
    """破損 JSON は skip され、skip 理由と件数が出力に含まれ、exit 0 となる。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        _write(
            self.runs_dir,
            "run-A-r1.json",
            _run_record("run-A", 1, "AUTO_APPROVED", "aaa0001"),
        )
        (self.runs_dir / "broken.json").write_text("{ not valid json", encoding="utf-8")

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_skip_reported_in_report(self):
        report = metrics.collect(self.runs_dir)
        self.assertEqual(report["skipped_count"], 1)
        self.assertEqual(len(report["skipped"]), 1)
        self.assertIn("broken.json", report["skipped"][0]["file"])
        self.assertTrue(report["skipped"][0]["reason"])

    def test_cli_exit_zero_with_corrupted_file(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(self.runs_dir)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("skip", result.stdout.lower())


class TestMissingRunsDir(unittest.TestCase):
    """--runs-dir が不在の場合は exit 1 + 明示メッセージ。"""

    def test_cli_exit_one_with_message(self):
        missing_dir = pathlib.Path(tempfile.gettempdir()) / "metrics-does-not-exist-xyz"
        if missing_dir.exists():
            import shutil

            shutil.rmtree(missing_dir)
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(missing_dir)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertTrue(result.stderr.strip())
        self.assertIn(str(missing_dir), result.stderr)


class TestJsonFormatStructure(unittest.TestCase):
    """--format json の構造検証（キー実在）。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)
        _write(
            self.runs_dir,
            "run-A-r1.json",
            _run_record("run-A", 1, "AUTO_APPROVED", "aaa0001"),
        )
        _write(self.runs_dir, "legacy-1.json", _legacy_record(target_sha="leg0001"))

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_json_output_keys(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(self.runs_dir), "--format", "json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        for key in (
            "total_records",
            "legacy_count",
            "run_count",
            "first_pass",
            "decision_counts",
            "round_distribution",
            "failure_category_breakdown",
            "skipped_count",
            "skipped",
        ):
            self.assertIn(key, payload)
        self.assertIn("numerator", payload["first_pass"])
        self.assertIn("denominator", payload["first_pass"])
        self.assertIn("rate", payload["first_pass"])


class TestRealDataIntegration(unittest.TestCase):
    """実 record（リポジトリ実データ）に対して実行し、落ちずに legacy 件数を返す。"""

    def test_real_data_runs_without_crash(self):
        if not REAL_RUNS_DIR.exists():
            self.skipTest(f"real runs dir not found: {REAL_RUNS_DIR}")

        expected_total = len(list(REAL_RUNS_DIR.glob("*.json")))

        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(REAL_RUNS_DIR), "--format", "json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)

        # 現行スキーマの実データは 'run' メタを一切持たないため、全件 legacy 扱い。
        # 件数はハードコードせず、実データ件数を動的に数えて比較する
        # (record 件数は将来の run 追加で変わりうるため)。
        self.assertEqual(payload["total_records"], expected_total)
        self.assertEqual(payload["legacy_count"], expected_total)
        self.assertEqual(payload["run_count"], 0)


if __name__ == "__main__":
    unittest.main()
