#!/usr/bin/env python3
"""test_run_evidence.py — RunEvidence 決定論 producer のテスト（TASK-0874 / #874）。

契約正本: docs/workflows/ai-loop/run-evidence-contract.md §3。

本ファイルは TDD の RED から積む。T-11（決定論 / TC-10〜TC-12）が最初のブロックで、
供給元マッピング・unavailable 区別・legacy 互換・privacy・adapter は後続タスクが
同じファイルに追記する。

実行: python3 scripts/ai-loop/test_run_evidence.py
対応 TC（本ファイル現時点）: TC-10 / TC-11 / TC-12
"""
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
PRODUCER = HERE / "run_evidence.py"

sys.path.insert(0, str(HERE))
import delivery  # noqa: E402
import plan_package  # noqa: E402
import test_plan_package as tpp  # noqa: E402

NOW = "2100-01-01T00:00:00Z"
STARTED_AT = "2099-12-31T00:00:00Z"
HEAD = "abcdef1234567890abcdef1234567890abcdef12"
SRC = "abc1234"
PR = 940
RUN_ID = "20260804T000000Z-abcdef1"
REPOSITORY = "plangate"


def _setup(tmp):
    """producer の入力ソース（Plan Package + c3-prime + record.jsonl）を作る。"""
    task_dir = tpp._make_task_dir(tmp)
    rec = plan_package.build_c3_prime(
        task_dir, task_id="TASK-9999", source_sha=SRC, target_sha=SRC,
        verdicts={"model_a": "approve", "model_b": "approve"},
        reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
        decision="AUTO_APPROVED", policy_ref="p@v4",
        issued_at=NOW, issued_by="arbiter-v0.1")
    (task_dir / "approvals").mkdir(exist_ok=True)
    (task_dir / "approvals" / "c3.json").write_text(
        plan_package.serialize_c3_prime(rec), encoding="utf-8")
    entries = [
        {"kind": "state", "state": "MERGE_READY", "head_sha": HEAD,
         "pr_number": PR, "reasons": []},
        {"kind": "receipt", "action_id": "a1", "action_kind": "repair_ci",
         "pr_number": PR, "round": 1},
        {"kind": "merge_ready", "record": {
            "pr_number": PR, "head_sha": HEAD,
            "check_summary": {"ci": "success"},
            "review_disposition": {"F-1": "resolved"},
            "round": 1, "plan_hash": rec["plan_hash"]}},
    ]
    delivery.append_entries(delivery.record_path(task_dir), entries, NOW)
    runs_dir = pathlib.Path(tmp) / "ai-loop-runs"
    runs_dir.mkdir()
    return task_dir, runs_dir, rec


def _args(task_dir, runs_dir, *, omit=()):
    argv = [str(task_dir)]
    injected = {
        "--now": NOW,
        "--started-at": STARTED_AT,
        "--repository": REPOSITORY,
        "--run-id": RUN_ID,
        "--pr-number": str(PR),
    }
    for flag, value in injected.items():
        if flag in omit:
            continue
        argv += [flag, value]
    if "--runs-dir" not in omit:
        argv += ["--runs-dir", str(runs_dir)]
    return argv


def _produce(task_dir, runs_dir, *, omit=()):
    """producer を subprocess で実行し (returncode, stdout_bytes, stderr) を返す。

    argv は先頭 sys.executable のリテラル list（check_exec_boundary.py の
    ARGV_HEAD / ARGV_UNRESOLVED 不変条件。`[...] + args` の BinOp は静的追跡不能
    として fail-closed になるため star-unpack で組む）。
    """
    cp = subprocess.run([sys.executable, str(PRODUCER),
                         *_args(task_dir, runs_dir, omit=omit)], capture_output=True)
    return cp.returncode, cp.stdout, cp.stderr.decode("utf-8", "replace")


def _reorder_json_file(path):
    """JSON ファイルのキー挿入順を反転して書き戻す（内容は同値）。"""
    p = pathlib.Path(path)
    data = json.loads(p.read_text(encoding="utf-8"))
    p.write_text(json.dumps(dict(reversed(list(data.items()))), ensure_ascii=False),
                 encoding="utf-8")


def _reorder_jsonl_file(path):
    p = pathlib.Path(path)
    out = []
    for line in p.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        out.append(json.dumps(dict(reversed(list(row.items()))), ensure_ascii=False))
    p.write_text("\n".join(out) + "\n", encoding="utf-8")


class DeterminismTests(unittest.TestCase):
    """T-11 / AC-2 決定論（TC-10 / TC-11 / TC-12）。"""

    def test_tc10_same_input_twice_is_byte_identical(self):
        # TC-10: 同一入力 + 同一注入値で 2 回生成 → byte 完全一致
        # （改行・キー順・インデントまで一致）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc1, out1, err1 = _produce(task_dir, runs_dir)
            rc2, out2, err2 = _produce(task_dir, runs_dir)
            self.assertEqual(rc1, 0, err1)
            self.assertEqual(rc2, 0, err2)
            self.assertEqual(out1, out2, "2 回の生成結果が byte 一致しない")
            self.assertTrue(out1.endswith(b"\n"), "末尾改行が無い（serialization 契約）")

    def test_tc10_serialization_matches_c3_prime_form(self):
        # serialization は plan_package.serialize_c3_prime() と byte 互換
        # （ensure_ascii=False / indent=2 / sort_keys=True / 末尾 "\n"）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc, out, err = _produce(task_dir, runs_dir)
            self.assertEqual(rc, 0, err)
            text = out.decode("utf-8")
            data = json.loads(text)
            expected = json.dumps(data, ensure_ascii=False, indent=2,
                                  sort_keys=True) + "\n"
            self.assertEqual(text, expected)

    def test_tc11_input_key_order_does_not_change_output(self):
        # TC-11: 入力 dict のキー挿入順序を入れ替えても出力は TC-10 と byte 一致。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc1, baseline, err1 = _produce(task_dir, runs_dir)
            self.assertEqual(rc1, 0, err1)
            _reorder_json_file(task_dir / "approvals" / "c3.json")
            _reorder_jsonl_file(delivery.record_path(task_dir))
            rc2, shuffled, err2 = _produce(task_dir, runs_dir)
            self.assertEqual(rc2, 0, err2)
            self.assertEqual(baseline, shuffled,
                             "入力のキー挿入順序で出力が変わる（sort_keys=True 違反）")

    def test_tc12_missing_injected_values_are_errors(self):
        # TC-12: --now 未指定はエラー。fail-closed な注入値 4 つを全数検査する
        # （--pr-number だけは未注入でもエラーにならない = unavailable に倒す）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            for flag in ("--now", "--started-at", "--repository", "--run-id"):
                with self.subTest(missing=flag):
                    rc, out, err = _produce(task_dir, runs_dir, omit=(flag,))
                    self.assertNotEqual(rc, 0,
                                        f"{flag} 未注入なのに成功した（now() 内部参照の疑い）")
                    self.assertIn(flag.lstrip("-").replace("-", ""),
                                  err.lower().replace("-", "").replace("_", ""),
                                  f"stderr に {flag} の欠落が示されない: {err}")

    def test_tc12_producer_never_reads_the_clock(self):
        # TC-12（ソース走査）: producer のソースに datetime.now / time.time /
        # utcnow が 0 件（delivery.py の純判定器ソース走査 TC と同型）。
        # コメント・docstring を除いた実コードを AST で検査する。
        import ast
        src = PRODUCER.read_text(encoding="utf-8")
        tree = ast.parse(src)
        banned_attrs = {"now", "utcnow", "time", "monotonic", "today"}
        banned_modules = {"time", "datetime", "random", "uuid", "socket", "subprocess"}
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names:
                    self.assertNotIn(a.name.split(".")[0], banned_modules,
                                     f"非決定的モジュールを import している: {a.name}")
            if isinstance(node, ast.ImportFrom) and node.module:
                self.assertNotIn(node.module.split(".")[0], banned_modules,
                                 f"非決定的モジュールを import している: {node.module}")
            if isinstance(node, ast.Attribute):
                self.assertNotIn(node.attr, banned_attrs,
                                 f"時刻・乱数由来の属性参照がある: .{node.attr}")
        # 文字列としての残存も併せて固定（動的呼び出しの抜け道を塞ぐ）
        body = re.sub(r'"""(?:.|\n)*?"""', "", src)
        body = re.sub(r"#.*", "", body)
        for token in ("datetime.now", "time.time", "utcnow"):
            self.assertNotIn(token, body, f"{token} がソースに残っている")

    def test_tc12_pr_number_is_not_fail_closed(self):
        # --pr-number は未注入でもエラーにしない（unavailable に倒す注入値）。
        # 0 に倒すと delivery._completed_rounds(entries, None) の戻り値 0 が
        # 「修理 0 回」として下流を汚染する（契約 §3-2）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc, out, err = _produce(task_dir, runs_dir, omit=("--pr-number",))
            self.assertEqual(rc, 0, f"--pr-number 未注入で失敗した: {err}")


if __name__ == "__main__":
    unittest.main()
