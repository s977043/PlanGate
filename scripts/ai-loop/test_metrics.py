#!/usr/bin/env python3
"""test_metrics.py — metrics.py の unittest カバレッジ（外部依存なし）。

実行: python3 scripts/ai-loop/test_metrics.py
"""

from __future__ import annotations

import json
import os
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
        # 一意な一時ディレクトリを作り、その中の非存在サブパスを "不在 runs-dir"
        # として使う（固定名を共有 tmp 直下に作ると並列実行で他プロセスと競合
        # しうるため。mkdtemp が一意 dir を保証し、サブパスは常に非存在）。
        base = tempfile.mkdtemp()
        missing_dir = pathlib.Path(base) / "does-not-exist"
        try:
            result = subprocess.run(
                [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(missing_dir)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertTrue(result.stderr.strip())
            self.assertIn(str(missing_dir), result.stderr)
        finally:
            os.rmdir(base)


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

        # 実データは 'run' メタ付き record（#780 Slice D 後半以降の dogfooding
        # run）と、run メタを持たない旧形式 record が混在しうる（#749 実測時点で
        # 26 件中 1 件が run メタ付きに移行済み）。件数はハードコードせず、
        # legacy_count + run_count（+ invalid_run_meta_count、実測 0）が
        # total_records に一致するという不変条件のみを検証する（brittle な
        # 「全件 legacy」固定断定は将来の run 追加で必ず崩れるため撤去）。
        self.assertEqual(payload["total_records"], expected_total)
        self.assertEqual(
            payload["legacy_count"] + payload["run_count"] + payload.get("invalid_run_meta_count", 0),
            expected_total,
        )
        self.assertGreaterEqual(payload["legacy_count"], 0)
        self.assertGreaterEqual(payload["run_count"], 0)


class TestInvalidRunId(unittest.TestCase):
    """run_id が非空文字列でない record は run 扱いせず invalid_run_meta_count に計上する。

    レビュー指摘（major）: falsy run_id（None / "" / 空白のみ）が同一キーへ
    誤集約され first-pass rate を実態より高く歪める問題の回帰テスト。
    """

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        # invalid: run_id=None / run_id="" / run_id="  "（空白のみ）
        rec_none = _run_record("placeholder", 1, "AUTO_APPROVED", "inv0001")
        rec_none["run"]["run_id"] = None
        _write(self.runs_dir, "invalid-none.json", rec_none)

        rec_empty = _run_record("placeholder", 1, "AUTO_APPROVED", "inv0002")
        rec_empty["run"]["run_id"] = ""
        _write(self.runs_dir, "invalid-empty.json", rec_empty)

        rec_blank = _run_record("placeholder", 1, "AUTO_APPROVED", "inv0003")
        rec_blank["run"]["run_id"] = "  "
        _write(self.runs_dir, "invalid-blank.json", rec_blank)

        # valid run 1 件（first_pass=false になるよう escalate にする）
        _write(
            self.runs_dir,
            "run-V-r1.json",
            _run_record("run-V", 1, "HUMAN_ESCALATED", "vvv0001", reject_category="logic"),
        )

        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_invalid_run_meta_count(self):
        self.assertEqual(self.report["invalid_run_meta_count"], 3)

    def test_invalid_not_counted_as_legacy(self):
        # invalid run meta は legacy（run キー自体が無い）と区別する
        self.assertEqual(self.report["legacy_count"], 0)

    def test_run_count_excludes_invalid(self):
        # invalid 3 件が同一キーへ誤集約されて run_count に混ざらないこと
        self.assertEqual(self.report["run_count"], 1)

    def test_first_pass_not_polluted(self):
        # 誤集約バグでは AUTO_APPROVED の invalid 群が first_pass を押し上げていた
        self.assertEqual(self.report["first_pass"]["denominator"], 1)
        self.assertEqual(self.report["first_pass"]["numerator"], 0)

    def test_markdown_mentions_invalid_count(self):
        md = metrics.render_markdown(self.report)
        self.assertIn("invalid run meta 3 件", md)

    def test_json_includes_invalid_count(self):
        payload = json.loads(metrics.render_json(self.report))
        self.assertEqual(payload["invalid_run_meta_count"], 3)


class TestRoundIndexTypeMix(unittest.TestCase):
    """round_index の型不正（int 以外）record は skip へ回し、他集計は継続する。

    レビュー指摘（major）: 同一 run 内に "1"(str) と 2(int) が混在すると sort の
    TypeError で traceback 終了し exit code 契約から逸脱する問題の回帰テスト。
    """

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        # run-X: round_index="1"(str・不正) と 2(int・正常) の混在
        rec_str = _run_record("run-X", 1, "HUMAN_ESCALATED", "xxx0001", reject_category="logic")
        rec_str["run"]["round_index"] = "1"
        _write(self.runs_dir, "run-X-r1-strindex.json", rec_str)

        _write(
            self.runs_dir,
            "run-X-r2.json",
            _run_record("run-X", 2, "AUTO_APPROVED", "xxx0002"),
        )

        # bool は int のサブクラスだが round_index としては不正（type(x) is int で除外）
        rec_bool = _run_record("run-Y", 1, "AUTO_APPROVED", "yyy0001")
        rec_bool["run"]["round_index"] = True
        _write(self.runs_dir, "run-Y-r1-boolindex.json", rec_bool)

        # 健全な run 1 件
        _write(
            self.runs_dir,
            "run-Z-r1.json",
            _run_record("run-Z", 1, "AUTO_APPROVED", "zzz0001"),
        )

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_no_uncaught_typeerror(self):
        # TypeError で落ちず report が返ること
        report = metrics.collect(self.runs_dir)
        self.assertIsInstance(report, dict)

    def test_bad_round_index_records_skipped_with_reason(self):
        report = metrics.collect(self.runs_dir)
        self.assertEqual(report["skipped_count"], 2)
        reasons = " / ".join(item["reason"] for item in report["skipped"])
        self.assertIn("round_index", reasons)
        skipped_files = " / ".join(item["file"] for item in report["skipped"])
        self.assertIn("run-X-r1-strindex.json", skipped_files)
        self.assertIn("run-Y-r1-boolindex.json", skipped_files)

    def test_run_survives_with_remaining_records(self):
        # 当該 record のみ除外・run 全体は残る（run-X は r2 のみで存続）
        report = metrics.collect(self.runs_dir)
        self.assertEqual(report["run_count"], 2)  # run-X + run-Z
        # run-X は round_index=2 の 1 record のみ -> first_pass=false
        # run-Z は round_index=1 AUTO -> first_pass=true
        self.assertEqual(report["first_pass"]["numerator"], 1)
        self.assertEqual(report["first_pass"]["denominator"], 2)

    def test_cli_exit_zero(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(self.runs_dir)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("skip", result.stdout.lower())


class TestDuplicateRoundIndex(unittest.TestCase):
    """同一 run 内の round_index 重複は warnings として明示し、集計は継続する。

    レビュー指摘（minor）: 重複があると round 数が過大計上されるため検知を明示。
    """

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        _write(
            self.runs_dir,
            "run-X-r1a.json",
            _run_record("run-X", 1, "HUMAN_ESCALATED", "xxx0001", reject_category="logic"),
        )
        _write(
            self.runs_dir,
            "run-X-r1b.json",
            _run_record("run-X", 1, "AUTO_APPROVED", "xxx0002"),
        )

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_warning_emitted(self):
        report = metrics.collect(self.runs_dir)
        self.assertEqual(len(report["warnings"]), 1)
        self.assertIn("run-X", report["warnings"][0])
        self.assertIn("duplicate round_index 1", report["warnings"][0])

    def test_aggregation_continues(self):
        report = metrics.collect(self.runs_dir)
        self.assertEqual(report["run_count"], 1)
        self.assertEqual(report["decision_counts"]["HUMAN_ESCALATED"], 1)
        self.assertEqual(report["decision_counts"]["AUTO_APPROVED"], 1)

    def test_json_output_contains_warnings(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(self.runs_dir), "--format", "json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)
        self.assertIn("warnings", payload)
        self.assertTrue(any("duplicate round_index" in w for w in payload["warnings"]))


class TestFirstPassMissingRoundIndex(unittest.TestCase):
    """first_pass 判定は sort 先頭でなく round_index==1 を明示探索する。

    gemini 指摘（high）: round_index 欠落レコード（0 扱い）が同一 run に混在
    すると sort 先頭が欠落レコードになり、実 round_index==1 が AUTO_APPROVED
    でも first_pass を取りこぼす回帰テスト。
    """

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        # run-A: round_index 欠落レコード（sort 先頭に来る=0 扱い）+ round 1 AUTO
        rec_missing = _run_record("run-A", 99, "HUMAN_ESCALATED", "aaa0000", reject_category="logic")
        del rec_missing["run"]["round_index"]  # 欠落 -> 0 扱いで sort 先頭
        _write(self.runs_dir, "run-A-missing.json", rec_missing)
        _write(
            self.runs_dir,
            "run-A-r1.json",
            _run_record("run-A", 1, "AUTO_APPROVED", "aaa0001"),
        )

        # run-B: round 2 から始まる（round_index==1 が存在しない）
        _write(
            self.runs_dir,
            "run-B-r2.json",
            _run_record("run-B", 2, "AUTO_APPROVED", "bbb0002"),
        )
        _write(
            self.runs_dir,
            "run-B-r3.json",
            _run_record("run-B", 3, "AUTO_APPROVED", "bbb0003"),
        )

        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_first_pass_counts_actual_round1_despite_missing(self):
        # run-A は round_index==1 が AUTO -> first_pass=true（欠落 sort 先頭に惑わされない）
        # run-B は round_index==1 が不在 -> first_pass=false（分子に入らない）
        self.assertEqual(self.report["first_pass"]["numerator"], 1)

    def test_run_without_round1_still_in_denominator(self):
        # 「round 1 が無い run は first-pass ではない」が分母には run として含む
        self.assertEqual(self.report["first_pass"]["denominator"], 2)
        self.assertEqual(self.report["run_count"], 2)


class TestSpecialCharPathGlob(unittest.TestCase):
    """runs_dir にブラケット等特殊文字が含まれても *.json を正しく拾う。

    gemini 指摘（medium）: glob.glob(str(...)) はパスの [ ] をワイルドカードと
    誤解釈する。Path.glob 移行の回帰テスト。
    """

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        # 親 tmp の下に [test] ディレクトリを作る（ブラケットは glob 特殊文字）
        self.runs_dir = pathlib.Path(self.tmpdir.name) / "[test]runs"
        self.runs_dir.mkdir(parents=True)

        _write(
            self.runs_dir,
            "run-A-r1.json",
            _run_record("run-A", 1, "AUTO_APPROVED", "aaa0001"),
        )
        _write(self.runs_dir, "legacy-1.json", _legacy_record(target_sha="leg0001"))

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_collect_finds_json_in_bracket_path(self):
        report = metrics.collect(self.runs_dir)
        self.assertEqual(report["total_records"], 2)
        self.assertEqual(report["run_count"], 1)
        self.assertEqual(report["legacy_count"], 1)

    def test_cli_finds_json_in_bracket_path(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--runs-dir", str(self.runs_dir), "--format", "json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["total_records"], 2)
        self.assertEqual(payload["run_count"], 1)


class TestHotlHealthRates(unittest.TestCase):
    """escalate_rate / human_intervention_rate を decision_counts から厳密一致で検証する。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        # decision_counts = {AUTO_APPROVED: 8, HUMAN_ESCALATED: 2, BLOCKED: 1}
        for i in range(8):
            _write(
                self.runs_dir,
                f"run-auto-{i}.json",
                _run_record(f"run-auto-{i}", 1, "AUTO_APPROVED", f"a{i:04d}"),
            )
        for i in range(2):
            _write(
                self.runs_dir,
                f"run-esc-{i}.json",
                _run_record(f"run-esc-{i}", 1, "HUMAN_ESCALATED", f"e{i:04d}"),
            )
        _write(
            self.runs_dir,
            "run-blocked-0.json",
            _run_record("run-blocked-0", 1, "BLOCKED", "b0000"),
        )

        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_escalate_rate_exact(self):
        escalate = self.report["hotl_health"]["escalate_rate"]
        self.assertEqual(escalate["count"], 2)
        self.assertEqual(escalate["total"], 11)
        self.assertAlmostEqual(escalate["rate"], 2 / 11)

    def test_human_intervention_rate_exact(self):
        intervention = self.report["hotl_health"]["human_intervention_rate"]
        self.assertEqual(intervention["count"], 3)
        self.assertEqual(intervention["total"], 11)
        self.assertAlmostEqual(intervention["rate"], 3 / 11)


class TestHotlReversal(unittest.TestCase):
    """reversal_rate: 途中 reject → 最終 round AUTO_APPROVED の run 割合を検証する。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)

        # run-reversed: round1=BLOCKED -> round2=AUTO_APPROVED (reversed=true)
        _write(
            self.runs_dir,
            "run-reversed-r1.json",
            _run_record("run-reversed", 1, "BLOCKED", "r0001"),
        )
        _write(
            self.runs_dir,
            "run-reversed-r2.json",
            _run_record("run-reversed", 2, "AUTO_APPROVED", "r0002"),
        )

        # run-clean: 全 round AUTO_APPROVED (reversed=false・非対象)
        _write(
            self.runs_dir,
            "run-clean-r1.json",
            _run_record("run-clean", 1, "AUTO_APPROVED", "c0001"),
        )

        # run-unresolved: 最終 round も HUMAN_ESCALATED のまま (reversed=false・未収束)
        _write(
            self.runs_dir,
            "run-unresolved-r1.json",
            _run_record("run-unresolved", 1, "BLOCKED", "u0001"),
        )
        _write(
            self.runs_dir,
            "run-unresolved-r2.json",
            _run_record("run-unresolved", 2, "HUMAN_ESCALATED", "u0002"),
        )

        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_reversed_run_counted(self):
        reversal = self.report["hotl_health"]["reversal"]
        self.assertEqual(reversal["reversed_runs"], 1)

    def test_all_auto_approved_run_not_reversed(self):
        # run-clean は非対象（途中 reject が無い）なので reversed_runs=1 のまま
        reversal = self.report["hotl_health"]["reversal"]
        self.assertEqual(reversal["reversed_runs"], 1)

    def test_unresolved_run_not_reversed(self):
        # run-unresolved は最終 round が HUMAN_ESCALATED のまま（未収束）なので不算入
        reversal = self.report["hotl_health"]["reversal"]
        self.assertEqual(reversal["run_count"], 3)
        self.assertEqual(reversal["reversed_runs"], 1)
        self.assertAlmostEqual(reversal["rate"], 1 / 3)


class TestHotlReversalZeroRuns(unittest.TestCase):
    """run_count=0 の場合、reversal.rate は None を返す。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)
        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_reversal_rate_none_when_no_runs(self):
        reversal = self.report["hotl_health"]["reversal"]
        self.assertEqual(reversal["run_count"], 0)
        self.assertEqual(reversal["reversed_runs"], 0)
        self.assertIsNone(reversal["rate"])


class TestHotlHealthRegression(unittest.TestCase):
    """hotl_health 追加が既存フィールドを一切変更しないことを回帰確認する。"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runs_dir = pathlib.Path(self.tmpdir.name)
        _write(
            self.runs_dir,
            "run-A-r1.json",
            _run_record("run-A", 1, "AUTO_APPROVED", "aaa0001"),
        )
        self.report = metrics.collect(self.runs_dir)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_existing_keys_still_present(self):
        for key in (
            "total_records",
            "legacy_count",
            "invalid_run_meta_count",
            "run_count",
            "first_pass",
            "decision_counts",
            "round_distribution",
            "failure_category_breakdown",
            "warnings",
            "skipped_count",
            "skipped",
        ):
            self.assertIn(key, self.report)

    def test_markdown_mentions_hotl_health(self):
        md = metrics.render_markdown(self.report)
        self.assertIn("HOTL健全性", md)


if __name__ == "__main__":
    unittest.main()
