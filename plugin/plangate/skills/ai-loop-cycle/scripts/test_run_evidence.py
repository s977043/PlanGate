#!/usr/bin/env python3
"""test_run_evidence.py — RunEvidence 決定論 producer のテスト（TASK-0874 / #874）。

契約正本: docs/workflows/ai-loop/run-evidence-contract.md §3。

本ファイルは TDD の RED から積む。T-11（決定論 / TC-10〜TC-12）が最初のブロックで、
供給元マッピング・unavailable 区別・legacy 互換・privacy・adapter は後続タスクが
同じファイルに追記する。

実行: python3 scripts/ai-loop/test_run_evidence.py
対応 TC（本ファイル現時点）: TC-10 〜 TC-16 / TC-18 / TC-30 / TC-31 / TC-50 /
TC-52 / TC-53 / TC-57 〜 TC-60 / TC-64
"""
from __future__ import annotations

import io
import json
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

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
HARNESS = {
    "plugin_version": "8.18.0",
    "cli_version": "0.2.0",
    "corpus_hash": "sha256:" + "0" * 64,
}
CHECKS = {"ci": "success", "lint": "success"}
FINDINGS = {"F-1": "resolved", "F-2": "rejected"}


def _entries(*, last_state="MERGE_READY", merge_ready=True, repair=True,
             plan_hash="", extra=()):
    entries = [{"kind": "state", "state": last_state, "head_sha": HEAD,
                "pr_number": PR, "reasons": []}]
    if repair:
        entries.append({"kind": "receipt", "action_id": "a1",
                        "action_kind": "repair_ci", "pr_number": PR, "round": 1})
    if merge_ready:
        entries.append({"kind": "merge_ready", "record": {
            "pr_number": PR, "head_sha": HEAD,
            "check_summary": dict(CHECKS),
            "review_disposition": dict(FINDINGS),
            "round": 1, "plan_hash": plan_hash}})
    entries.extend(extra)
    return entries


def _setup(tmp, *, decision="AUTO_APPROVED", with_record=True, merge_ready=True,
           last_state="MERGE_READY", repair=True, extra_entries=()):
    """producer の入力ソース（Plan Package + c3-prime + record.jsonl）を作る。"""
    task_dir = tpp._make_task_dir(tmp)
    rec = plan_package.build_c3_prime(
        task_dir, task_id="TASK-9999", source_sha=SRC, target_sha=SRC,
        verdicts={"model_a": "approve", "model_b": "approve"},
        reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
        decision=decision, policy_ref="p@v4",
        issued_at=NOW, issued_by="arbiter-v0.1")
    (task_dir / "approvals").mkdir(exist_ok=True)
    (task_dir / "approvals" / "c3.json").write_text(
        plan_package.serialize_c3_prime(rec), encoding="utf-8")
    if with_record:
        delivery.append_entries(
            delivery.record_path(task_dir),
            _entries(last_state=last_state, merge_ready=merge_ready, repair=repair,
                     plan_hash=rec["plan_hash"], extra=extra_entries),
            NOW)
    runs_dir = pathlib.Path(tmp) / "ai-loop-runs"
    runs_dir.mkdir(exist_ok=True)
    return task_dir, runs_dir, rec


def _args(task_dir, runs_dir, *, omit=()):
    argv = [str(task_dir)]
    injected = {
        "--now": NOW,
        "--started-at": STARTED_AT,
        "--repository": REPOSITORY,
        "--run-id": RUN_ID,
        "--pr-number": str(PR),
        # harness_version は 3 値 object の注入（契約 §2 #10 / §4-1・AC-12）。
        # 未注入は fail-closed だが「run 中に変化しない」ことの比較対象が
        # 必要なため --harness-version-end を別に持つ（TC-30 / TC-31）。
        "--harness-version": json.dumps(HARNESS, sort_keys=True),
    }
    for flag, value in injected.items():
        if flag in omit:
            continue
        argv += [flag, value]
    if "--runs-dir" not in omit:
        argv += ["--runs-dir", str(runs_dir)]
    return argv


def _produce(task_dir, runs_dir, *, omit=(), extra=()):
    """producer を subprocess で実行し (returncode, stdout_bytes, stderr) を返す。

    argv は先頭 sys.executable のリテラル list（check_exec_boundary.py の
    ARGV_HEAD / ARGV_UNRESOLVED 不変条件。`[...] + args` の BinOp は静的追跡不能
    として fail-closed になるため star-unpack で組む）。
    """
    cp = subprocess.run([sys.executable, str(PRODUCER),
                         *_args(task_dir, runs_dir, omit=omit), *extra],
                        capture_output=True)
    return cp.returncode, cp.stdout, cp.stderr.decode("utf-8", "replace")


def _produce_inproc(task_dir, runs_dir, *, omit=(), extra=()):
    """producer を同一プロセスで実行する（monkeypatch 検証用 / TC-40 / TC-63）。"""
    import run_evidence
    out, err = io.StringIO(), io.StringIO()
    argv = ["run_evidence.py", *_args(task_dir, runs_dir, omit=omit), *extra]
    with redirect_stdout(out), redirect_stderr(err):
        rc = run_evidence.main(argv)
    return rc, out.getvalue(), err.getvalue()


def _ev(test, task_dir, runs_dir, *, extra=()):
    rc, out, err = _produce(task_dir, runs_dir, extra=extra)
    test.assertEqual(rc, 0, f"producer が失敗した: {err}")
    return json.loads(out.decode("utf-8"))


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


class FieldMappingTests(unittest.TestCase):
    """T-12 / AC-3 供給元マッピング（TC-13 / TC-14 / TC-15 / TC-16 / TC-50 / TC-64）。"""

    def test_tc13_c3_json_fields_are_carried(self):
        # TC-13: plan_hash / source_sha / c3_prime_decision_ref ← approvals/c3.json
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir)
            self.assertEqual(ev["plan_hash"], rec["plan_hash"])
            self.assertEqual(ev["source_sha"], rec["source_sha"])
            ref = ev["c3_prime_decision_ref"]
            self.assertEqual(set(ref), {"path", "plan_package_hash"})
            self.assertEqual(ref["plan_package_hash"], rec["plan_package_hash"])
            self.assertTrue(ref["path"].endswith(f"{task_dir.name}/approvals/c3.json"))
            self.assertFalse(ref["path"].startswith("/"), "repo 相対でない")

    def test_tc14_final_head_sha_and_ci_outcomes_come_from_record(self):
        # TC-14: final_head_sha == merge_ready entry の record.head_sha /
        # ci_outcomes は check_summary の全 check 名（件数を len() で照合）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir)
            self.assertEqual(ev["final_head_sha"], HEAD)
            self.assertEqual(len(ev["ci_outcomes"]), len(CHECKS))
            names = {o["name"] for o in ev["ci_outcomes"]}
            self.assertEqual(names, set(CHECKS))

    def test_tc15_review_findings_and_repair_rounds(self):
        # TC-15: review_findings は review_disposition の全 finding id /
        # repair_rounds は delivery._completed_rounds() の戻り値と一致
        # （producer 側で再実装せず import して照合する）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir)
            ids = {f["id"] for f in ev["review_findings"]}
            self.assertLessEqual(set(FINDINGS), ids)
            entries = delivery.load_entries(delivery.record_path(task_dir))
            self.assertEqual(ev["repair_rounds"],
                             delivery._completed_rounds(entries, PR))

    def test_tc16_human_escalated_state_is_not_rounded_to_merge_ready(self):
        # TC-16: 最終 kind=state が HUMAN_ESCALATED → terminal_state も
        # HUMAN_ESCALATED。human_interventions[] が非空。MERGE_READY にならない。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(
                tmp, last_state="HUMAN_ESCALATED", merge_ready=False)
            ev = _ev(self, task_dir, runs_dir)
            self.assertEqual(ev["terminal_state"], "HUMAN_ESCALATED")
            self.assertNotEqual(ev["terminal_state"], "MERGE_READY")
            self.assertTrue(ev["human_interventions"],
                            "human_interventions が空（介入が記録されていない）")

    def test_tc50_routing_is_bound_to_the_same_run_id(self):
        # TC-50: routing_decisions キーが存在し Phase 1 は unavailable。
        # かつ同一 EV 内で plan_hash / final_head_sha / terminal_state と
        # 同じ run_id に結合されている（AC-3 の結合を Phase 1 で示せる唯一の形）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir)
            self.assertIn("routing_decisions", ev)
            self.assertEqual(ev["routing_decisions"], "unavailable")
            self.assertEqual(ev["run_id"], RUN_ID)
            self.assertEqual(ev["plan_hash"], rec["plan_hash"])
            self.assertEqual(ev["final_head_sha"], HEAD)
            self.assertEqual(ev["terminal_state"], "MERGE_READY")

    def test_tc64_unresolvable_pr_number_is_unavailable_not_zero(self):
        # TC-64: kind=merge_ready が無く PR 番号を解決できない → repair_rounds は
        # unavailable。0 にしない（_completed_rounds(entries, None) は例外にならず
        # 0 を返すため、0 に倒すと「修理 0 回」として下流を汚染する）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(
                tmp, merge_ready=False, last_state="HUMAN_ESCALATED")
            entries = delivery.load_entries(delivery.record_path(task_dir))
            self.assertEqual(delivery._completed_rounds(entries, None), 0,
                             "前提: PR 未解決でも例外にならず 0 が返る")
            ev = _ev(self, task_dir, runs_dir)
            self.assertEqual(ev["repair_rounds"], "unavailable")
            self.assertNotEqual(ev["repair_rounds"], 0)
            for f in ("ci_outcomes", "review_findings"):
                self.assertEqual(ev[f], "unavailable", f)

    def test_tc64_injected_pr_number_alone_does_not_materialize_rounds(self):
        # --pr-number の注入だけを根拠に repair_rounds を実値化しない。
        # 受理器は kind=merge_ready の record.pr_number からしか PR を再解決
        # できないため、注入値で実値化すると受理器が再計算照合できず
        # 「生成側の自己申告を信頼する」構造になる（契約 §3-2 の cross-check 解釈）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(
                tmp, merge_ready=False, last_state="HUMAN_ESCALATED")
            ev = _ev(self, task_dir, runs_dir)      # --pr-number は注入済み
            self.assertEqual(ev["repair_rounds"], "unavailable")

    def test_pr_number_cross_check_mismatch_is_fail_closed(self):
        # 注入 --pr-number が record の PR と食い違う場合は fail-closed。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc, _out, err = _produce(task_dir, runs_dir,
                                     omit=("--pr-number",),
                                     extra=("--pr-number", "1"))
            self.assertNotEqual(rc, 0, "PR 番号不一致が素通りした")
            self.assertIn("pr", err.lower())


class TerminalStateMappingTests(unittest.TestCase):
    """T-16 / D3 正規化マッピング（TC-57 / TC-58 / TC-59）。"""

    def test_tc57_merge_ready_requires_a_physical_merge_ready_entry(self):
        # TC-57 正側: kind=merge_ready entry の物理存在のみが唯一の条件。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            self.assertEqual(_ev(self, task_dir, runs_dir)["terminal_state"],
                             "MERGE_READY")

    def test_tc57_merge_ready_candidate_is_not_rounded_up(self):
        # TC-57 対の負側: 最終 kind=state が MERGE_READY_CANDIDATE でも
        # kind=merge_ready entry が無ければ MERGE_READY に丸めない
        # （丸めると未収束 run が下流の学習母集団 / promotion 入力に混入する）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(
                tmp, last_state="MERGE_READY_CANDIDATE", merge_ready=False)
            rc, out, err = _produce(task_dir, runs_dir)
            self.assertNotEqual(rc, 0,
                                f"非終端 run で EV を発行した: {out!r}")
            self.assertIn("MERGE_READY_CANDIDATE", err)

    def test_tc58_blocked_emits_ev_with_delivery_fields_unavailable(self):
        # TC-58: c3.json の decision=BLOCKED は record.jsonl 自体が存在しない。
        # EV は発行するが delivery 層 4 フィールドは unavailable（ダミー sha /
        # 空文字 / 0 で埋めない）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, decision="BLOCKED",
                                              with_record=False)
            ev = _ev(self, task_dir, runs_dir)
            self.assertEqual(ev["terminal_state"], "BLOCKED")
            for f in ("final_head_sha", "ci_outcomes", "review_findings",
                      "repair_rounds"):
                self.assertEqual(ev[f], "unavailable", f)
            self.assertNotEqual(ev["repair_rounds"], 0)

    def test_tc59_non_terminal_states_do_not_emit_evidence(self):
        # TC-59: 非終端 7 状態（STATES 7 + EXITS 2 − MERGE_READY − HUMAN_ESCALATED）
        # を parametrized で全数。1 件でも 3 値を返したら FAIL。
        non_terminal = sorted((set(delivery.STATES) | set(delivery.EXITS))
                              - {"MERGE_READY", "HUMAN_ESCALATED"})
        self.assertEqual(len(non_terminal), 7, non_terminal)
        with tempfile.TemporaryDirectory() as tmp:
            for state in non_terminal:
                with self.subTest(state=state):
                    task_dir, runs_dir, _rec = _setup(
                        tmp + f"/{state}", last_state=state, merge_ready=False)
                    rc, out, err = _produce(task_dir, runs_dir)
                    self.assertNotEqual(rc, 0, f"{state} で EV を発行した: {out!r}")
                    self.assertIn(state, err)

    def test_tc41_decision_is_not_trusted_blindly(self):
        # TC-41: c3.json の decision=HUMAN_ESCALATED は record を生成するが
        # terminal_state は HUMAN_ESCALATED。MERGE_READY に倒さない。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, decision="HUMAN_ESCALATED",
                                              merge_ready=False,
                                              last_state="WAITING_FOR_CHECKS")
            ev = _ev(self, task_dir, runs_dir)
            self.assertEqual(ev["terminal_state"], "HUMAN_ESCALATED")


class UnavailableSemanticsTests(unittest.TestCase):
    """T-13 / unavailable と 0・空配列の区別（TC-52 / TC-53 / TC-30 / TC-31）。"""

    def test_tc52_unsupplied_is_unavailable_and_explicit_empty_is_empty(self):
        # TC-52: routing_decisions 未供給 = "unavailable" ≠ 明示供給の []。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            unsupplied = _ev(self, task_dir, runs_dir)["routing_decisions"]
            supplied = _ev(self, task_dir, runs_dir,
                           extra=("--routing-decisions", "[]"))["routing_decisions"]
            self.assertEqual(unsupplied, "unavailable")
            self.assertEqual(supplied, [])
            self.assertNotEqual(unsupplied, supplied,
                                "unavailable を空配列で埋めている（fail-open）")

    def test_tc53_unknown_record_kind_is_escalated_not_swallowed(self):
        # TC-53: delivery.assess() が生成しない kind（実在例: notice）を
        # 握り潰さず escalation に記録する。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, extra_entries=(
                {"kind": "notice", "action_id": "a1", "action_kind": "repair_ci",
                 "pr_number": PR},))
            ev = _ev(self, task_dir, runs_dir)
            kinds = {e["kind"] for e in ev["escalation"]}
            details = {e["detail"] for e in ev["escalation"]}
            self.assertIn("unknown_record_kind", kinds,
                          f"未知 kind が escalation に無い: {ev['escalation']}")
            self.assertIn("notice", details)

    def test_tc30_harness_version_stable_across_the_run(self):
        # TC-30: 開始時注入 == 終了時注入 → そのまま格納・exit 0。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir,
                     extra=("--harness-version-end", json.dumps(HARNESS)))
            self.assertEqual(ev["harness_version"], HARNESS)

    def test_tc31_harness_version_drift_is_fail_closed(self):
        # TC-31: 開始時 X / 終了時 Y（≠X）→ エラー。警告に降格しない。
        # 3 値それぞれの変化を全数検査する（AC-12 は 3 値すべてを見る）。
        drifts = {
            "plugin_version": "8.19.0",
            "cli_version": "0.3.0",
            "corpus_hash": "sha256:" + "1" * 64,
        }
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            for key, value in drifts.items():
                with self.subTest(changed=key):
                    end = dict(HARNESS)
                    end[key] = value
                    rc, _out, err = _produce(
                        task_dir, runs_dir,
                        extra=("--harness-version-end", json.dumps(end)))
                    self.assertNotEqual(rc, 0, f"{key} の変化が素通りした")
                    self.assertIn("harness_version", err)
                    self.assertIn(value, err, "変化後の値が stderr に出ない")
                    self.assertIn(HARNESS[key], err, "変化前の値が stderr に出ない")

    def test_harness_version_is_fail_closed_when_not_injected(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc, _out, err = _produce(task_dir, runs_dir,
                                     omit=("--harness-version",))
            self.assertNotEqual(rc, 0)
            self.assertIn("harness-version", err)


class ObservationTests(unittest.TestCase):
    """T-17 / AC-5 observation と cause_hypothesis の分離（TC-18）。"""

    def test_tc18_cause_hypothesis_is_not_auto_generated(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir)
            self.assertIsNone(ev["cause_hypothesis"],
                              "producer が推定を自動生成している（AC-5 違反）")
            self.assertTrue(ev["observation"], "observation が空")

    def test_injected_cause_hypothesis_is_stored(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir,
                     extra=("--cause-hypothesis", "lint rule drift"))
            self.assertEqual(ev["cause_hypothesis"], "lint rule drift")


class DeterminismCorpusTests(unittest.TestCase):
    """T-12 / TC-60 quality_metrics は当該 run で閉じる指標のみ。"""

    def test_tc60_adding_an_arbiter_record_does_not_change_the_output(self):
        # TC-60: runs_dir に record を 1 件足しても EV は byte 一致。
        # corpus 集計値を quality_metrics に載せると壊れる不変条件。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc1, before, err1 = _produce(task_dir, runs_dir)
            self.assertEqual(rc1, 0, err1)
            (runs_dir / "zzz-extra.json").write_text(json.dumps({
                "decision": "AUTO_APPROVED", "issued_by": "arbiter-v0.1",
                "policy_ref": "p@v4", "target_sha": SRC, "timestamp": NOW,
                "run": {"run_id": "other-run", "round_index": 1},
            }, sort_keys=True), encoding="utf-8")
            rc2, after, err2 = _produce(task_dir, runs_dir)
            self.assertEqual(rc2, 0, err2)
            self.assertEqual(before, after,
                             "corpus の増減で EV が変わる（AC-2 / 決定論違反）")

    def test_tc60_quality_metrics_has_no_corpus_aggregate(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir)
            qm = ev["quality_metrics"]
            self.assertEqual(set(qm), {"first_pass", "rounds"}, qm)
            for banned in ("decision_counts", "round_distribution", "hotl_health",
                           "first_pass_rate"):
                self.assertNotIn(banned, json.dumps(ev),
                                 f"corpus 集計値 {banned} が EV に載っている")


class C3PrimeReverificationTests(unittest.TestCase):
    """T-26 / AC-14 §4 全規則の fail-closed 再検証（TC-40 / TC-41）。"""

    @staticmethod
    def _tamper(task_dir, key, value):
        path = task_dir / "approvals" / "c3.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data[key] = value
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2,
                                   sort_keys=True) + "\n", encoding="utf-8")

    def test_tc40_stale_plan_hash_is_fail_closed(self):
        # TC-40: c3.json の plan_hash を現 plan.md と不一致にすると生成拒否。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            self._tamper(task_dir, "plan_hash", "sha256:" + "0" * 64)
            rc, _out, err = _produce(task_dir, runs_dir)
            self.assertNotEqual(rc, 0, "stale plan_hash が素通りした")
            self.assertIn("plan_hash", err)

    def test_tc40_binding_failure_is_fail_closed_for_non_auto_approved(self):
        # §6-5 の解釈（decision 値だけは terminal_state の供給元として扱う）が
        # 束縛検証の穴にならないこと。decision=BLOCKED では c3prime_verify が
        # decision 判定で return するため後段（plan_hash / artifact_hashes /
        # plan_package_hash / reviewer snapshot）が未検証のまま残る。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, decision="BLOCKED",
                                              with_record=False)
            self._tamper(task_dir, "plan_hash", "sha256:" + "0" * 64)
            rc, _out, err = _produce(task_dir, runs_dir)
            self.assertNotEqual(rc, 0, "BLOCKED 経由で改竄 plan_hash が素通りした")
            self.assertIn("plan_hash", err)

    def test_tc40_plan_package_hash_tamper_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, decision="HUMAN_ESCALATED",
                                              merge_ready=False,
                                              last_state="HUMAN_ESCALATED")
            self._tamper(task_dir, "plan_package_hash", "sha256:" + "1" * 64)
            rc, _out, err = _produce(task_dir, runs_dir)
            self.assertNotEqual(rc, 0, "改竄 plan_package_hash が素通りした")
            self.assertIn("plan_package_hash", err)

    def test_tc40_producer_calls_c3prime_verify(self):
        # TC-40（構造）: producer は c3prime_verify.main() を経由して再検証する
        # （検証ロジックを再実装しない）。monkeypatch で呼び出しを固定する。
        import c3prime_verify
        import run_evidence
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            calls = []
            real = c3prime_verify.main

            def _spy(argv):
                calls.append(list(argv))
                return real(argv)

            c3prime_verify.main = _spy
            try:
                rc, _out, err = _produce_inproc(task_dir, runs_dir)
            finally:
                c3prime_verify.main = real
            self.assertEqual(rc, 0, err)
            self.assertTrue(calls, "c3prime_verify.main() が呼ばれていない")
            self.assertIn(str(task_dir), calls[0])
            self.assertIs(run_evidence.delivery.c3prime_verify, c3prime_verify)

    def test_legacy_c3_json_does_not_emit_evidence(self):
        # legacy（approval_kind 無し）の c3.json からは EV を発行しない。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            path = task_dir / "approvals" / "c3.json"
            path.write_text(json.dumps(
                {"c3_status": "APPROVED", "plan_hash": "sha256:" + "0" * 64},
                sort_keys=True), encoding="utf-8")
            rc, _out, err = _produce(task_dir, runs_dir)
            self.assertNotEqual(rc, 0)
            self.assertIn("legacy", err)


class C3PrimeContractDocTests(unittest.TestCase):
    """T-25 / AC-14 c3-prime-contract §7 への additive 追記（TC-38 / TC-39）。"""

    DOC = "docs/workflows/ai-loop/c3-prime-contract.md"

    @staticmethod
    def _sections(text):
        sections, key = {}, "_head"
        for line in text.splitlines():
            if line.startswith("## "):
                key = line[3:].strip()
                sections[key] = []
            else:
                sections.setdefault(key, []).append(line)
        return {k: "\n".join(v) for k, v in sections.items()}

    def test_tc38_consumer_section_lists_the_five_fields(self):
        doc = (REPO / self.DOC).read_text(encoding="utf-8")
        section = self._sections(doc).get("7. #873（delivery.py）への引き渡し", "")
        self.assertIn("#874", section, "§7 に #874 consumer 節が無い")
        for field in ("task_id", "decision", "source_sha", "plan_hash",
                      "plan_package_hash"):
            self.assertIn(f"`{field}`", section, f"§7 の #874 節に {field} が無い")

    def test_tc39_only_section_7_changed(self):
        # git show は読み取り専用 git サブコマンド allowlist に含まれる
        # （check_exec_boundary.py 不変条件 3）。
        cp = subprocess.run(["git", "show", f"origin/main:{self.DOC}"],
                            cwd=str(REPO), capture_output=True, text=True)
        if cp.returncode != 0:
            self.skipTest(f"origin/main を解決できない: {cp.stderr.strip()}")
        old = self._sections(cp.stdout)
        new = self._sections((REPO / self.DOC).read_text(encoding="utf-8"))
        self.assertEqual(set(old), set(new), "節の追加・削除が発生している")
        target = "7. #873（delivery.py）への引き渡し"
        for key in sorted(old):
            if key == target:
                continue
            self.assertEqual(old[key], new[key],
                             f"§7 以外の節が変更されている: {key}")
        self.assertTrue(new[target].startswith(old[target]),
                        "§7 が additive でない（既存行が改変されている）")


class AcceptanceRoundTripTests(unittest.TestCase):
    """T-18 / producer 出力を受理器が partial（exit 11）で受理する。"""

    def _verify(self, ev_bytes, task_dir, tmp):
        path = pathlib.Path(tmp) / "ev.json"
        path.write_bytes(ev_bytes)
        cp = subprocess.run([sys.executable, str(HERE / "run_evidence_verify.py"),
                             str(path), str(task_dir)], capture_output=True, text=True)
        return cp.returncode, cp.stderr

    def test_producer_output_is_partial_with_listed_unavailable_fields(self):
        # Phase 1 は known-unavailable により exit 0 に到達しない（契約 §5-1）。
        # exit 11 で unavailable フィールド名が stderr に全数列挙されること。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            rc, out, err = _produce(task_dir, runs_dir)
            self.assertEqual(rc, 0, err)
            vrc, verr = self._verify(out, task_dir, tmp)
            self.assertEqual(vrc, 11, f"受理器の exit が 11 でない: {verr}")
            for f in ("routing_decisions", "replan_count", "cost_metrics"):
                self.assertIn(f, verr, f"stderr に {f} が列挙されない: {verr}")

    def test_blocked_output_is_partial_too(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, decision="BLOCKED",
                                              with_record=False)
            rc, out, err = _produce(task_dir, runs_dir)
            self.assertEqual(rc, 0, err)
            vrc, verr = self._verify(out, task_dir, tmp)
            self.assertEqual(vrc, 11, verr)
            for f in ("final_head_sha", "ci_outcomes", "review_findings",
                      "repair_rounds", "quality_metrics"):
                self.assertIn(f, verr, f"stderr に {f} が列挙されない: {verr}")


FORBIDDEN_KEYS = (
    "file_path", "file_paths", "stack_trace", "stacktrace", "command_output",
    "stdout", "stderr", "raw_response", "raw_request", "api_key",
    "user_prompt", "system_prompt", "prompt_text", "absolute_path",
)
COMMENT_URL = "https://github.com/s977043/PlanGate/pull/940#issuecomment-5140067809"


class PrivacyTests(unittest.TestCase):
    """T-22 / AC-6（TC-19 / TC-20 / TC-21 / TC-51 / TC-63 / TC-65）。"""

    def test_tc19_forbidden_keys_never_reach_the_output(self):
        # TC-19: 禁止キー 14 個を含む events を入力しても出力に 0 件。
        # 握り潰さず入力側の異常として escalation に記録する。
        polluted = {"kind": "notice", "action_id": "a1"}
        for key in FORBIDDEN_KEYS:
            polluted[key] = "x"
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, extra_entries=(polluted,))
            rc, out, err = _produce(task_dir, runs_dir)
            self.assertEqual(rc, 0, err)
            text = out.decode("utf-8")
            ev = json.loads(text)
            for key in FORBIDDEN_KEYS:
                self.assertNotIn(f'"{key}"', text, f"禁止キー {key} が出力に現れた")
            details = {e["detail"] for e in ev["escalation"]}
            for key in FORBIDDEN_KEYS:
                self.assertIn(f"record.jsonl: {key}", details,
                              f"{key} が escalation に記録されていない")

    def test_tc20_absolute_evidence_ref_is_rejected(self):
        # TC-20: evidence_refs に絶対パスを注入 → reject
        # （metrics-privacy.md §5「絶対パスは FORBIDDEN」）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            for ref in ("/Users/foo/bar.json", "/var/folders/x/y.json"):
                with self.subTest(ref=ref):
                    rc, _out, err = _produce(task_dir, runs_dir,
                                             extra=("--evidence-ref", ref))
                    self.assertNotEqual(rc, 0, f"絶対パス {ref} が素通りした")
                    self.assertIn("絶対パス", err)
                    # 入力側で reject する（出力側の最終検査に頼らない）
                    self.assertIn("--evidence-ref", err, err)

    def test_tc20_relative_evidence_ref_is_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            ev = _ev(self, task_dir, runs_dir,
                     extra=("--evidence-ref", "docs/working/x/y.json"))
            self.assertIn("docs/working/x/y.json", ev["evidence_refs"])
            for ref in ev["evidence_refs"]:
                self.assertFalse(ref.startswith("/"), ref)

    def test_tc21_output_extension_must_be_json(self):
        # TC-21: .jsonl は EH-8 の走査対象（*.json|*.ndjson）に**マッチしない**ため
        # privacy 検査を素通りする。拡張子を .json に固定する。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            bad = pathlib.Path(tmp) / "ev.jsonl"
            rc, _out, err = _produce(task_dir, runs_dir, extra=("--out", str(bad)))
            self.assertNotEqual(rc, 0, ".jsonl 出力が通った")
            self.assertIn(".json", err)
            self.assertFalse(bad.exists(), "reject したのにファイルを書いている")
            good = pathlib.Path(tmp) / "ev.json"
            rc, out, err = _produce(task_dir, runs_dir, extra=("--out", str(good)))
            self.assertEqual(rc, 0, err)
            self.assertTrue(good.is_file())
            self.assertEqual(out, b"", "--out 指定時に stdout へも書いている")

    def test_tc51_account_identifiers_are_reduced_to_numbers(self):
        # TC-51: 実 record 由来の comment_url（owner 名 + URL）を保存せず
        # PR 番号 / コメント ID へ還元する（U-5 の C-3 結論）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, extra_entries=(
                {"kind": "notice", "action_id": "a1", "action_kind": "repair_ci",
                 "pr_number": PR, "comment_url": COMMENT_URL},))
            rc, out, err = _produce(task_dir, runs_dir)
            self.assertEqual(rc, 0, err)
            text = out.decode("utf-8")
            for token in ("github.com", "s977043", "https://", "PlanGate/pull"):
                self.assertNotIn(token, text, f"account 由来の値 {token} が残っている")
            self.assertIn("pr:940", text, "PR 番号へ還元されていない")
            self.assertIn("comment:5140067809", text, "コメント ID へ還元されていない")

    def test_tc51_account_keys_in_input_are_escalated(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, extra_entries=(
                {"kind": "notice", "action_id": "a1", "login": "someone",
                 "github_user": "someone"},))
            ev = _ev(self, task_dir, runs_dir)
            kinds = {e["kind"] for e in ev["escalation"]}
            self.assertIn("privacy_account_key", kinds, ev["escalation"])
            self.assertNotIn("someone", json.dumps(ev))

    def test_tc65_absolute_paths_in_any_field_are_zero(self):
        # TC-65: evidence_refs 以外の任意フィールドに絶対パスが載る経路
        # （state entry の reasons → observation）でも出力に 0 件。
        # EH-8 はキー名の grep のみで値を見ないため producer 側が唯一の防御線。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, extra_entries=(
                {"kind": "state", "state": "MERGE_READY", "head_sha": HEAD,
                 "pr_number": PR,
                 "reasons": ["/Users/foo/x.json が壊れている",
                             "/var/folders/ab/tmpX/y.json"]},))
            rc, out, err = _produce(task_dir, runs_dir)
            self.assertEqual(rc, 0, err)
            ev = json.loads(out.decode("utf-8"))
            for path, key, value in _walk_values(ev):
                if isinstance(value, str):
                    self.assertNotRegex(value, r"(^/|/Users/)",
                                        f"{path} に絶対パスが残っている: {value!r}")
            self.assertIn("privacy_absolute_path",
                          {e["kind"] for e in ev["escalation"]},
                          "絶対パスの還元が escalation に記録されていない")

    def test_tc51_account_handles_in_values_are_redacted(self):
        # @handle は EH-8 の禁止キーにも URL 検出にも掛からない第 3 の経路。
        # producer が還元しないと出力側の最終検査で fail-closed になり、
        # 「reviewer が @someone を書いた run」だけ EV が発行できなくなる。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp, extra_entries=(
                {"kind": "state", "state": "MERGE_READY", "head_sha": HEAD,
                 "pr_number": PR, "reasons": ["@someone のレビュー待ち"]},))
            ev = _ev(self, task_dir, runs_dir)
            self.assertNotIn("@someone", json.dumps(ev, ensure_ascii=False))
            self.assertIn("privacy_account_handle",
                          {e["kind"] for e in ev["escalation"]}, ev["escalation"])

    def test_output_privacy_backstop_detects_every_violation_class(self):
        # 出力側の最終検査（fail-closed の最後の砦）を直接叩く。
        # 上流の還元が効いている限り本経路は発火しないため、単体で検出力を固定する。
        import run_evidence
        cases = {
            "forbidden_key": {"escalation": [{"kind": "x", "stdout": "y"}]},
            "account_key": {"human_interventions": [{"login": "someone"}]},
            "absolute_value": {"observation": "/Users/foo/x.json"},
            "url_value": {"observation": COMMENT_URL},
        }
        for label, record in cases.items():
            with self.subTest(case=label):
                self.assertTrue(run_evidence.check_output_privacy(record),
                                f"{label} を検出できていない")
        self.assertEqual(run_evidence.check_output_privacy(
            {"observation": "terminal_state=MERGE_READY"}), [])

    def test_tc63_producer_opens_only_the_allowlisted_sources(self):
        # TC-63: producer 実行中に open される全パスが task_dir / runs_dir 配下
        # （AC-6 の「要求しない」側）。transcript / session log / CoT / 環境変数 /
        # ネットワーク / 外部プロセスを読まないことを monkeypatch + ソース走査で固定。
        import builtins
        import run_evidence
        opened = []
        real_open = builtins.open
        real_read_text = pathlib.Path.read_text

        def _spy_open(file, *a, **kw):
            opened.append(str(file))
            return real_open(file, *a, **kw)

        def _spy_read_text(self, *a, **kw):
            opened.append(str(self))
            return real_read_text(self, *a, **kw)

        with tempfile.TemporaryDirectory() as tmp:
            task_dir, runs_dir, _rec = _setup(tmp)
            builtins.open = _spy_open
            pathlib.Path.read_text = _spy_read_text
            try:
                rc, _out, err = _produce_inproc(task_dir, runs_dir)
            finally:
                builtins.open = real_open
                pathlib.Path.read_text = real_read_text
            self.assertEqual(rc, 0, err)
            self.assertTrue(opened, "1 ファイルも open していない（spy が効いていない）")
            allowed = (str(pathlib.Path(task_dir).resolve()),
                       str(pathlib.Path(runs_dir).resolve()))
            for path in opened:
                resolved = str(pathlib.Path(path).resolve())
                self.assertTrue(resolved.startswith(allowed),
                                f"allowlist 外を open した: {path}")
            self.assertIs(run_evidence.UNAVAILABLE, "unavailable")

    def test_tc63_producer_source_has_no_environment_or_network_access(self):
        import ast
        src = PRODUCER.read_text(encoding="utf-8")
        tree = ast.parse(src)
        banned_modules = {"os", "urllib", "http", "requests", "socket",
                          "subprocess", "importlib", "shutil"}
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names:
                    self.assertNotIn(a.name.split(".")[0], banned_modules, a.name)
            if isinstance(node, ast.ImportFrom) and node.module:
                self.assertNotIn(node.module.split(".")[0], banned_modules,
                                 node.module)
        # docstring / コメントは「読まない」と宣言する記述を含むため実コードのみ検査。
        body = re.sub(r'"""(?:.|\n)*?"""', "", src)
        body = re.sub(r"#.*", "", body)
        for token in ("environ", "getenv", "transcript", "session_log",
                      "session-log"):
            self.assertNotIn(token, body, f"{token} が producer の実コードに現れる")


def _walk_values(node, prefix=""):
    if isinstance(node, dict):
        for key in sorted(node):
            path = f"{prefix}.{key}" if prefix else key
            yield path, key, node[key]
            yield from _walk_values(node[key], path)
    elif isinstance(node, list):
        for i, item in enumerate(node):
            path = f"{prefix}[{i}]"
            yield path, None, item
            yield from _walk_values(item, path)


class LegacyClassificationTests(unittest.TestCase):
    """T-19 / AC-15 legacy 4 分類（TC-42 / TC-43 / TC-44 / TC-45 / TC-54）。"""

    RUNS = REPO / "docs" / "working" / "ai-loop-runs"

    @staticmethod
    def _classify(runs_dir):
        import run_evidence
        return run_evidence.classify_records(runs_dir)

    @staticmethod
    def _write(runs_dir, name, payload):
        path = pathlib.Path(runs_dir) / name
        if isinstance(payload, str):
            path.write_text(payload, encoding="utf-8")
        else:
            path.write_text(json.dumps(payload, sort_keys=True), encoding="utf-8")

    def test_tc42_real_corpus_matches_metrics_py(self):
        # TC-42: 実データ 28 件で metrics.py --format json の現行出力と一致。
        # metrics.py は import せず（不変対象への依存を増やさない）別実装の
        # 同値性を subprocess の実出力で確認する。
        cp = subprocess.run([sys.executable, str(HERE / "metrics.py"),
                             "--format", "json"], capture_output=True, text=True)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        expected = json.loads(cp.stdout)
        got = self._classify(self.RUNS)
        for key in ("legacy_count", "invalid_run_meta_count", "run_count",
                    "skipped_count", "total_records"):
            self.assertEqual(got[key], expected[key], f"{key} が metrics.py と不一致")
        self.assertEqual(got["legacy_count"], 25)
        self.assertEqual(got["run_count"], 3)
        self.assertEqual(got["invalid_run_meta_count"], 0)
        self.assertEqual(got["skipped_count"], 0)

    def test_tc43_identity_holds_and_is_not_vacuous(self):
        # TC-43: total_records == legacy + invalid_meta + run。
        # 右辺と同じ式で左辺を作ると恒等式が空振りするため、loaded_records を
        # 「ファイルから読めた record 数」として独立に数えて突き合わせる。
        got = self._classify(self.RUNS)
        self.assertEqual(
            got["total_records"],
            len(got["legacy_records"]) + len(got["invalid_meta_records"])
            + len(got["run_records"]))
        self.assertEqual(got["loaded_records"],
                         got["total_records"] + got["round_index_skipped"])
        self.assertEqual(got["loaded_records"], 28)

    def test_tc54_run_count_is_distinct_run_ids_not_record_count(self):
        # TC-54: 1 run に 2 record を持つ合成入力で run_count と len(run_records)
        # が別物であることを固定する（実データ 28 件では偶然一致し検出できない）。
        with tempfile.TemporaryDirectory() as tmp:
            for i in (1, 2):
                self._write(tmp, f"r{i}.json", {
                    "decision": "AUTO_APPROVED",
                    "run": {"run_id": "same-run", "round_index": i}})
            got = self._classify(tmp)
            self.assertEqual(len(got["run_records"]), 2)
            self.assertEqual(got["run_count"], 1)
            self.assertNotEqual(got["run_count"], len(got["run_records"]))
            self.assertEqual(got["total_records"],
                             len(got["legacy_records"])
                             + len(got["invalid_meta_records"])
                             + len(got["run_records"]))

    def test_tc44_broken_inputs_are_skipped_with_a_reason(self):
        # TC-44: 破損 JSON / 非 dict / decision 欠落 / 不正 round_index。
        # いずれも例外で落ちず理由文字列付きで skipped に入る（fail-silent 禁止）。
        with tempfile.TemporaryDirectory() as tmp:
            self._write(tmp, "a-broken.json", "{not json")
            self._write(tmp, "b-nonobject.json", [1, 2])
            self._write(tmp, "c-nodecision.json", {"issued_by": "x"})
            self._write(tmp, "d-badround.json", {
                "decision": "AUTO_APPROVED",
                "run": {"run_id": "r", "round_index": "1"}})
            got = self._classify(tmp)
            self.assertEqual(got["skipped_count"], 4, got["skipped"])
            for item in got["skipped"]:
                self.assertTrue(item["reason"], f"理由が空: {item}")
                self.assertFalse(item["file"].startswith("/"),
                                 f"skipped.file が絶対パス: {item['file']}")
                self.assertNotIn("/Users/", item["file"])

    def test_tc44_legacy_and_invalid_meta_are_separated(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._write(tmp, "a-legacy.json", {"decision": "AUTO_APPROVED"})
            self._write(tmp, "b-invalid.json",
                        {"decision": "AUTO_APPROVED", "run": {"run_id": ""}})
            self._write(tmp, "c-run.json", {
                "decision": "AUTO_APPROVED",
                "run": {"run_id": "r1", "round_index": 1}})
            got = self._classify(tmp)
            self.assertEqual(got["legacy_count"], 1)
            self.assertEqual(got["invalid_run_meta_count"], 1)
            self.assertEqual(got["run_count"], 1)

    def test_tc45_existing_arbiter_records_are_untouched(self):
        # TC-45: RunEvidence は arbiter record の後継ではなく上位 artifact。
        # 分類・生成を実行しても既存 28 件を 1 バイトも変更しない。
        self._classify(self.RUNS)
        cp = subprocess.run(["git", "status", "--porcelain", "--",
                             "docs/working/ai-loop-runs/"],
                            cwd=str(REPO), capture_output=True, text=True)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(cp.stdout.strip(), "",
                         f"ai-loop-runs/ に差分が出ている: {cp.stdout}")

    def test_classifier_does_not_import_metrics(self):
        # metrics.py は不変対象。依存を増やさず導出規則のみ転写する。
        import ast
        src = PRODUCER.read_text(encoding="utf-8")
        for node in ast.walk(ast.parse(src)):
            if isinstance(node, ast.Import):
                for a in node.names:
                    self.assertNotEqual(a.name, "metrics")
            if isinstance(node, ast.ImportFrom):
                self.assertNotEqual(node.module, "metrics")


def _evidences(n, *, harness=None):
    """adapter 入力用の EV 群（run_id だけが異なる同型 run）。"""
    evs = []
    for i in range(n):
        ev = {
            "run_id": f"run-{i:02d}",
            "task_id": "TASK-9999",
            "harness_version": dict(harness or HARNESS),
            "observation": "terminal_state=MERGE_READY; repair_rounds=1",
            "cause_hypothesis": None,
            "terminal_state": "MERGE_READY",
        }
        evs.append(ev)
    return evs


class ShadowCandidateAdapterTests(unittest.TestCase):
    """T-28 / AC-7 / AC-8（TC-23 / TC-24 / TC-25 / TC-26 / TC-33）。"""

    @staticmethod
    def _adapt(evs):
        import run_evidence
        return run_evidence.to_shadow_candidate_input(evs)

    def test_tc23_three_runs_produce_a_candidate_input(self):
        evs = _evidences(3)
        got = self._adapt(evs)
        self.assertEqual(got["status"], "ok", got)
        self.assertEqual(len(got["source_run_ids"]), 3)
        self.assertEqual(got["source_run_ids"], [e["run_id"] for e in evs])

    def test_tc25_uses_the_measured_spelling(self):
        got = self._adapt(_evidences(3))
        self.assertIn("source_run_ids", got)
        self.assertIn("baseline_version", got)
        # baseline_harness_version という綴りは repo にも issue にも 0 件。
        self.assertNotIn("baseline_harness_version", got)
        self.assertNotIn("baseline_harness_version",
                         PRODUCER.read_text(encoding="utf-8"))

    def test_tc26_baseline_version_matches_and_mixed_is_rejected(self):
        got = self._adapt(_evidences(3))
        self.assertEqual(got["baseline_version"], HARNESS)
        mixed = _evidences(3)
        mixed[1]["harness_version"] = dict(HARNESS, cli_version="9.9.9")
        rejected = self._adapt(mixed)
        self.assertEqual(rejected["status"], "mixed_baseline", rejected)
        self.assertNotIn("baseline_version", rejected)

    def test_tc33_two_runs_are_insufficient(self):
        for n in (0, 1, 2):
            with self.subTest(count=n):
                got = self._adapt(_evidences(n))
                self.assertEqual(got["status"], "insufficient_evidence", got)
                self.assertNotIn("source_run_ids", got)

    def test_candidate_id_is_deterministic(self):
        first = self._adapt(_evidences(3))
        second = self._adapt(list(reversed(_evidences(3))))
        self.assertEqual(first["candidate_id"], second["candidate_id"],
                         "同じ run 集合から異なる candidate_id が出る")

    def test_tc24_adapters_have_no_io(self):
        # TC-24: adapter は EV 以外の I/O を持たない（AC-7 の構造保証）。
        # ソース走査（関数本体に open / read_text / Path が無い）+ monkeypatch。
        import ast
        import builtins
        import run_evidence
        names = ("to_shadow_candidate_input", "to_promotion_provenance",
                 "to_improvement_task_descriptor", "to_paired_replay",
                 "apply_canary_rollback")
        tree = ast.parse(PRODUCER.read_text(encoding="utf-8"))
        found = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name in names:
                found.add(node.name)
                for sub in ast.walk(node):
                    if isinstance(sub, ast.Attribute):
                        self.assertNotIn(sub.attr,
                                         {"read_text", "read_bytes", "write_text",
                                          "glob", "is_file", "is_dir", "iterdir"},
                                         f"{node.name} が I/O を持つ")
                    if isinstance(sub, ast.Name):
                        self.assertNotIn(sub.id, {"open", "Path", "pathlib"},
                                         f"{node.name} が I/O を持つ")
        self.assertEqual(found, set(names), f"未実装の adapter: {set(names) - found}")

        def _boom(*a, **kw):
            raise AssertionError("adapter がファイルを open した")

        real_open = builtins.open
        builtins.open = _boom
        try:
            candidate = run_evidence.to_shadow_candidate_input(_evidences(3))
            run_evidence.to_promotion_provenance(dict(candidate, blocked_by=[]))
            run_evidence.to_improvement_task_descriptor(candidate)
        finally:
            builtins.open = real_open


class PromotionProvenanceAdapterTests(unittest.TestCase):
    """T-29 / T-30 / AC-9 / AC-10 / AC-11 / AC-13（TC-27〜TC-29 / TC-34〜TC-37 / TC-55）。"""

    @staticmethod
    def _candidate(**kw):
        import run_evidence
        base = run_evidence.to_shadow_candidate_input(_evidences(3))
        base.update(kw)
        return base

    @staticmethod
    def _provenance(candidate, decision="approve", **kw):
        import run_evidence
        return run_evidence.to_promotion_provenance(candidate, decision, **kw)

    def test_tc28_trust_ledger_keys_and_evidence_count(self):
        candidate = self._candidate(blocked_by=[])
        got = self._provenance(candidate)
        for key in ("candidate_id", "decision", "promoted_to", "evidence_count",
                    "canary_scope", "rollback_count", "improvement_refs"):
            self.assertIn(key, got, key)
        self.assertEqual(got["evidence_count"], len(candidate["source_run_ids"]))
        self.assertEqual(got["decision"], "approve")

    def test_tc29_improvement_refs_are_traceable_in_both_directions(self):
        candidate = self._candidate(blocked_by=[])
        got = self._provenance(candidate,
                               improvement_refs=("940", "7b229223b21a407"))
        kinds = {r["kind"] for r in got["improvement_refs"]}
        self.assertEqual(kinds, {"pr", "commit"}, got["improvement_refs"])
        for ref in got["improvement_refs"]:
            self.assertNotIn("http", ref["ref"])
        # candidate_id → improvement_refs / improvement_refs → source_run_ids
        self.assertEqual(got["candidate_id"], candidate["candidate_id"])
        self.assertEqual(got["source_run_ids"], candidate["source_run_ids"])

    def test_improvement_refs_reject_urls_and_absolute_paths(self):
        candidate = self._candidate(blocked_by=[])
        for bad in (COMMENT_URL, "/Users/foo/x", "not-a-ref!"):
            with self.subTest(ref=bad):
                with self.assertRaises(Exception):
                    self._provenance(candidate, improvement_refs=(bad,))

    def test_tc36_non_empty_blocked_by_is_blocked(self):
        got = self._provenance(self._candidate(blocked_by=["issue-866"]))
        self.assertEqual(got["decision"], "BLOCKED", got)
        self.assertNotIn(got["decision"], ("approve", "approve_with_conditions"))
        self.assertIsNone(got["promoted_to"])

    def test_tc55_missing_blocked_by_key_is_blocked(self):
        candidate = self._candidate()
        self.assertNotIn("blocked_by", candidate,
                         "adapter が blocked_by を勝手に埋めている（fail-open）")
        self.assertEqual(self._provenance(candidate)["decision"], "BLOCKED")

    def test_explicit_empty_blocked_by_proceeds(self):
        got = self._provenance(self._candidate(blocked_by=[]))
        self.assertEqual(got["decision"], "approve")

    def test_tc37_no_issue_number_is_hardcoded(self):
        src = PRODUCER.read_text(encoding="utf-8")
        self.assertEqual(len(re.findall(r"#86[0-9]", src)), 0,
                         "issue 番号がハードコードされている（CLOSE 時に stale 化する）")

    def test_tc27_improvement_task_goes_through_the_normal_gates(self):
        import run_evidence
        descriptor = run_evidence.to_improvement_task_descriptor(
            self._candidate(blocked_by=[]))
        self.assertIs(descriptor["plan_package_required"], True)
        self.assertIs(descriptor["c3_prime_required"], True)
        self.assertIs(descriptor["merge_by_ai"], False)
        self.assertEqual(set(descriptor),
                         set(run_evidence.IMPROVEMENT_TASK_KEYS))
        for bypass in ("skip_c3", "auto_merge", "skip_plan", "force_merge",
                       "bypass_gate"):
            self.assertNotIn(bypass, descriptor)
            self.assertNotIn(bypass, run_evidence.IMPROVEMENT_TASK_KEYS)

    def test_tc34_paired_replay_keeps_the_two_sides_disjoint(self):
        import run_evidence
        candidate = self._candidate(blocked_by=[])
        baseline = _evidences(3)
        challengers = [dict(e, run_id=f"cand-{i}") for i, e in enumerate(_evidences(3))]
        got = run_evidence.to_paired_replay(candidate, baseline, challengers,
                                            grader_ref="grader:v1",
                                            activation_check="check:v1")
        self.assertEqual(got["candidate_id"], candidate["candidate_id"])
        self.assertIn("grader_ref", got)
        self.assertIn("activation_check", got)
        self.assertFalse(set(got["baseline_run_ids"])
                         & set(got["candidate_run_ids"]),
                         "baseline と candidate に同一 run を数えている")
        overlapped = run_evidence.to_paired_replay(candidate, baseline, baseline)
        self.assertEqual(overlapped["status"], "overlapping_runs", overlapped)

    def test_tc35_failed_canary_rolls_the_candidate_back(self):
        import run_evidence
        candidate = self._candidate(blocked_by=[], status="approved",
                                    rollback_count=0)
        rolled = run_evidence.apply_canary_rollback(
            candidate, {"result": "failed", "canary_scope": "scope-a"})
        self.assertEqual(rolled["status"], "rolled_back")
        self.assertNotEqual(rolled["status"], "approved")
        self.assertEqual(rolled["rollback_count"], 1)
        self.assertEqual(candidate["rollback_count"], 0, "入力を破壊している")
        passed = run_evidence.apply_canary_rollback(
            candidate, {"result": "passed", "canary_scope": "scope-a"})
        self.assertEqual(passed["status"], "approved")
        self.assertEqual(passed["rollback_count"], 0)


FIXTURE_DIR = REPO / "tests" / "fixtures" / "run-evidence"
FIXTURE_NAMES = (
    "fx-01-first-pass",
    "fx-02-ci-repair",
    "fx-03-review-repair",
    "fx-04-human-escalated",
    "fx-05-blocked",
    "fx-06-routing-escalation",
    "fx-07-tampered-expected-errors",
    "fx-08-shadow-candidate-input",
    "fx-09-paired-replay",
    "fx-10-canary-rollback",
)
FX_COMMENT_URL = "https://github.com/s977043/PlanGate/pull/940#issuecomment-5140067809"

#: fixture 7（受理器の期待エラー列）。受理された record ではない。
#: ケースごとに期待 exit を一意に固定する（「1 または 10」のような二値を残さない）。
FX07 = {
    "_note": "expected errors for the RunEvidence verifier (not an accepted record)",
    "cases": [
        {
            "case": "tampered_plan_hash",
            "mutation": {"field": "plan_hash", "kind": "one_char_rewrite"},
            "expected_exit": 1,
            "expected_reason_contains": "plan_hash",
        },
        {
            "case": "tampered_repair_rounds",
            "mutation": {"field": "repair_rounds", "kind": "replace", "value": 99},
            "expected_exit": 1,
            "expected_reason_contains": "repair_rounds",
        },
        {
            "case": "partial_unavailable",
            "mutation": {"field": "routing_decisions", "kind": "unavailable"},
            "expected_exit": 11,
            "expected_reason_contains": "routing_decisions",
        },
    ],
}


def _fx_entries(name, plan_hash):
    """fixture ごとの record.jsonl entries（入力 events は test 内で構築する）。"""
    state = {"kind": "state", "state": "MERGE_READY", "head_sha": HEAD,
             "pr_number": PR, "reasons": []}
    merge_ready = {"kind": "merge_ready", "record": {
        "pr_number": PR, "head_sha": HEAD, "check_summary": {"CI": "success"},
        "review_disposition": {}, "round": 1, "plan_hash": plan_hash}}
    notice = {"kind": "notice", "action_id": "a1", "action_kind": "repair_ci",
              "pr_number": PR, "head_sha": HEAD, "comment_url": FX_COMMENT_URL}
    if name == "fx-01-first-pass":
        return [state, merge_ready]
    if name == "fx-02-ci-repair":
        # 入力形状は実在の record.jsonl（intent / notice / receipt）に照らす。
        return [
            {"kind": "intent", "action_id": "a1", "action_kind": "repair_ci",
             "payload": {"failed_checks": ["Markdown lint"], "head_sha": HEAD,
                         "pr_number": PR, "round": 1, "taxonomy": "code"}},
            notice,
            {"kind": "receipt", "action_id": "a1", "action_kind": "repair_ci",
             "pr_number": PR, "round": 1, "head_sha": HEAD},
            state,
            {"kind": "merge_ready", "record": {
                "pr_number": PR, "head_sha": HEAD,
                "check_summary": {"Markdown lint": "success"},
                "review_disposition": {}, "round": 1, "plan_hash": plan_hash}},
        ]
    if name == "fx-03-review-repair":
        return [
            {"kind": "receipt", "action_id": "a2", "action_kind": "repair_review",
             "pr_number": PR, "round": 1, "finding_type": "F-2"},
            state,
            {"kind": "merge_ready", "record": {
                "pr_number": PR, "head_sha": HEAD,
                "check_summary": {"CI": "success"},
                "review_disposition": {"F-1": "resolved"},
                "round": 1, "plan_hash": plan_hash}},
        ]
    if name == "fx-04-human-escalated":
        return [{"kind": "state", "state": "HUMAN_ESCALATED", "head_sha": HEAD,
                 "pr_number": PR, "reasons": ["reviewer が判断を要求"]}]
    if name == "fx-06-routing-escalation":
        return [notice,
                {"kind": "state", "state": "HUMAN_ESCALATED", "head_sha": HEAD,
                 "pr_number": PR, "reasons": ["routing escalation"]}]
    raise AssertionError(f"未知の fixture: {name}")


def _fx_produce(tmp, name, index):
    """fixture 1〜6 の EV を producer で生成して bytes で返す。"""
    decision = "BLOCKED" if name == "fx-05-blocked" else "AUTO_APPROVED"
    with_record = name != "fx-05-blocked"
    task_dir = tpp._make_task_dir(pathlib.Path(tmp) / name)
    rec = plan_package.build_c3_prime(
        task_dir, task_id="TASK-9999", source_sha=SRC, target_sha=SRC,
        verdicts={"model_a": "approve", "model_b": "approve"},
        reviewer_evidence={"model_a": "r#a", "model_b": "r#b"},
        decision=decision, policy_ref="p@v4",
        issued_at=NOW, issued_by="arbiter-v0.1")
    (task_dir / "approvals").mkdir(exist_ok=True)
    (task_dir / "approvals" / "c3.json").write_text(
        plan_package.serialize_c3_prime(rec), encoding="utf-8")
    if with_record:
        delivery.append_entries(delivery.record_path(task_dir),
                                _fx_entries(name, rec["plan_hash"]), NOW)
    runs_dir = pathlib.Path(tmp) / name / "ai-loop-runs"
    runs_dir.mkdir(parents=True, exist_ok=True)
    argv = [str(task_dir),
            "--now", NOW, "--started-at", STARTED_AT,
            "--repository", REPOSITORY, "--run-id", f"run-{index:02d}",
            "--harness-version", json.dumps(HARNESS, sort_keys=True),
            "--runs-dir", str(runs_dir)]
    if name != "fx-05-blocked":
        argv += ["--pr-number", str(PR)]
    cp = subprocess.run([sys.executable, str(PRODUCER), *argv],
                        capture_output=True)
    if cp.returncode != 0:
        raise AssertionError(
            f"{name} の生成に失敗: {cp.stderr.decode('utf-8', 'replace')}")
    return cp.stdout, task_dir


def regenerate_fixtures(dest):
    """golden fixture 10 件を決定論的に再生成する（入力 events は test 内で構築）。"""
    import run_evidence
    dest = pathlib.Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        evs = []
        for index, name in enumerate(FIXTURE_NAMES[:6], start=1):
            payload, _task_dir = _fx_produce(tmp, name, index)
            (dest / f"{name}.json").write_bytes(payload)
            evs.append(json.loads(payload.decode("utf-8")))
    (dest / "fx-07-tampered-expected-errors.json").write_text(
        run_evidence.serialize(FX07), encoding="utf-8")
    candidate = run_evidence.to_shadow_candidate_input(evs[:3])
    (dest / "fx-08-shadow-candidate-input.json").write_text(
        run_evidence.serialize(candidate), encoding="utf-8")
    challengers = [dict(e, run_id=f"cand-{e['run_id']}") for e in evs[:3]]
    replay = run_evidence.to_paired_replay(
        candidate, evs[:3], challengers,
        grader_ref="grader:independent-v1", activation_check="activation:v1")
    (dest / "fx-09-paired-replay.json").write_text(
        run_evidence.serialize(replay), encoding="utf-8")
    rolled = run_evidence.apply_canary_rollback(
        dict(candidate, status="approved", rollback_count=0, blocked_by=[]),
        {"result": "failed", "canary_scope": "canary:scope-a"})
    provenance = run_evidence.to_promotion_provenance(
        rolled, "approve", improvement_refs=("940",))
    (dest / "fx-10-canary-rollback.json").write_text(
        run_evidence.serialize({"candidate": rolled, "provenance": provenance}),
        encoding="utf-8")
    return sorted(p.name for p in dest.glob("*.json"))


class FixtureTests(unittest.TestCase):
    """T-32 / AC-16 golden fixture 10 件（TC-48 / TC-58）。"""

    def test_tc48_ten_goldens_are_byte_identical_after_regeneration(self):
        committed = sorted(FIXTURE_DIR.glob("*.json"))
        self.assertEqual(len(committed), 10,
                         f"fixture が 10 件でない: {[p.name for p in committed]}")
        self.assertEqual([p.stem for p in committed], list(FIXTURE_NAMES))
        with tempfile.TemporaryDirectory() as tmp:
            regenerate_fixtures(tmp)
            for path in committed:
                with self.subTest(fixture=path.name):
                    fresh = (pathlib.Path(tmp) / path.name).read_bytes()
                    self.assertEqual(path.read_bytes(), fresh,
                                     f"{path.name} が再生成結果と byte 一致しない")

    def test_fixture_terminal_states(self):
        expected = {
            "fx-01-first-pass": "MERGE_READY",
            "fx-02-ci-repair": "MERGE_READY",
            "fx-03-review-repair": "MERGE_READY",
            "fx-04-human-escalated": "HUMAN_ESCALATED",
            "fx-05-blocked": "BLOCKED",
            "fx-06-routing-escalation": "HUMAN_ESCALATED",
        }
        for name, state in expected.items():
            with self.subTest(fixture=name):
                ev = json.loads((FIXTURE_DIR / f"{name}.json")
                                .read_text(encoding="utf-8"))
                self.assertEqual(ev["terminal_state"], state)
                self.assertEqual(ev["routing_decisions"], "unavailable")

    def test_tc58_blocked_fixture_has_eight_unavailable_fields(self):
        # 契約 §5-1: (a) Phase 1 固定 3 + (b) terminal_state 依存 5 = 8。
        # 当初 test-cases.md は 7 と書いていたが quality_metrics の従属を
        # 数えていなかった（実装で確定・契約 doc を是正済み）。
        ev = json.loads((FIXTURE_DIR / "fx-05-blocked.json")
                        .read_text(encoding="utf-8"))
        unavailable = sorted(k for k, v in ev.items() if v == "unavailable")
        self.assertEqual(unavailable, [
            "ci_outcomes", "cost_metrics", "final_head_sha", "quality_metrics",
            "repair_rounds", "replan_count", "review_findings",
            "routing_decisions"])
        self.assertEqual(len(unavailable), 8)

    def test_fixtures_are_accepted_as_partial(self):
        # fixture 1〜6 の受理器 exit はすべて 11（Phase 1 は exit 0 に到達しない）。
        with tempfile.TemporaryDirectory() as tmp:
            for index, name in enumerate(FIXTURE_NAMES[:6], start=1):
                with self.subTest(fixture=name):
                    payload, task_dir = _fx_produce(tmp, name, index)
                    self.assertEqual(
                        payload, (FIXTURE_DIR / f"{name}.json").read_bytes())
                    ev_path = pathlib.Path(tmp) / name / "ev.json"
                    ev_path.write_bytes(payload)
                    cp = subprocess.run(
                        [sys.executable, str(HERE / "run_evidence_verify.py"),
                         str(ev_path), str(task_dir)],
                        capture_output=True, text=True)
                    self.assertEqual(cp.returncode, 11,
                                     f"{name}: exit {cp.returncode} / {cp.stderr}")

    def test_tc48_fixture_07_expected_errors_are_reproduced(self):
        # fixture 7 は「期待エラー列」。ケースごとに期待 exit が一意であること。
        spec = json.loads((FIXTURE_DIR / "fx-07-tampered-expected-errors.json")
                          .read_text(encoding="utf-8"))
        exits = [c["expected_exit"] for c in spec["cases"]]
        self.assertNotIn(0, exits, "tampered / partial が exit 0 を期待している")
        with tempfile.TemporaryDirectory() as tmp:
            payload, task_dir = _fx_produce(tmp, "fx-01-first-pass", 1)
            base = json.loads(payload.decode("utf-8"))
            for case in spec["cases"]:
                with self.subTest(case=case["case"]):
                    ev = json.loads(json.dumps(base))
                    field = case["mutation"]["field"]
                    kind = case["mutation"]["kind"]
                    if kind == "one_char_rewrite":
                        value = ev[field]
                        ev[field] = value[:-1] + ("0" if value[-1] != "0" else "1")
                    elif kind == "replace":
                        ev[field] = case["mutation"]["value"]
                    else:
                        ev[field] = "unavailable"
                    path = pathlib.Path(tmp) / "case.json"
                    path.write_text(json.dumps(ev, sort_keys=True), encoding="utf-8")
                    cp = subprocess.run(
                        [sys.executable, str(HERE / "run_evidence_verify.py"),
                         str(path), str(task_dir)], capture_output=True, text=True)
                    self.assertEqual(cp.returncode, case["expected_exit"],
                                     f"{case['case']}: {cp.stderr}")
                    self.assertIn(case["expected_reason_contains"], cp.stderr)

    def test_fixtures_validate_against_the_schema(self):
        # schema を唯一の正として fixture 1〜6 を検証する。
        # jsonschema は CI に必ずあるとは限らないため、未導入環境では skip する
        # （本 TC は test-cases.md の 65 TC には含まれない追加検証）。
        try:
            import jsonschema
        except ImportError:                       # pragma: no cover
            self.skipTest("jsonschema 未導入の環境")
        schema = json.loads(
            (REPO / "docs" / "schemas" / "run-evidence.schema.json")
            .read_text(encoding="utf-8"))
        for name in FIXTURE_NAMES[:6]:
            with self.subTest(fixture=name):
                ev = json.loads((FIXTURE_DIR / f"{name}.json")
                                .read_text(encoding="utf-8"))
                jsonschema.validate(ev, schema)

    def test_fixtures_have_no_forbidden_keys(self):
        for path in sorted(FIXTURE_DIR.glob("*.json")):
            raw = path.read_text(encoding="utf-8")
            for key in FORBIDDEN_KEYS:
                self.assertNotIn(f'"{key}"', raw, f"{path.name} に禁止キー {key}")
            for token in ("github.com", "s977043", "/Users/"):
                self.assertNotIn(token, raw, f"{path.name} に {token}")


if __name__ == "__main__":
    unittest.main()
