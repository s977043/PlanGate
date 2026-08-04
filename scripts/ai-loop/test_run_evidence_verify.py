#!/usr/bin/env python3
"""test_run_evidence_verify.py — RunEvidence 受理器の契約テスト（TASK-0874 / #874）。

契約正本: docs/workflows/ai-loop/run-evidence-contract.md §6。
schema: docs/schemas/run-evidence.schema.json

negative first。exit code 契約 4 値（0=complete / 1=NG / 10=legacy / 11=partial）を
姉妹受理器 c3prime_verify.py の意味論（10=legacy）に整合させる。

実行: python3 scripts/ai-loop/test_run_evidence_verify.py
対応 TC: TC-06 / TC-07 / TC-08 / TC-09 / TC-32 / TC-56 / TC-61 / TC-62
"""
from __future__ import annotations

import copy
import json
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
VERIFY = HERE / "run_evidence_verify.py"
SCHEMA = REPO / "docs" / "schemas" / "run-evidence.schema.json"
CONTRACT = REPO / "docs" / "workflows" / "ai-loop" / "run-evidence-contract.md"

sys.path.insert(0, str(HERE))
import delivery  # noqa: E402
import plan_package  # noqa: E402
import test_plan_package as tpp  # noqa: E402

NOW = "2100-01-01T00:00:00Z"
HEAD = "abcdef1234567890abcdef1234567890abcdef12"
SRC = "abc1234"
PR = 940


def _schema() -> dict:
    return json.loads(SCHEMA.read_text(encoding="utf-8"))


def _setup(tmp, *, with_record=True, merge_ready=True):
    """sandbox の task_dir（Plan Package 6 要素 + c3-prime + record.jsonl）を作る。"""
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
    if with_record:
        entries = [
            {"kind": "state", "state": "MERGE_READY", "head_sha": HEAD,
             "pr_number": PR, "reasons": []},
            {"kind": "receipt", "action_id": "a1", "action_kind": "repair_ci",
             "pr_number": PR, "round": 1},
        ]
        if merge_ready:
            entries.append({"kind": "merge_ready", "record": {
                "pr_number": PR, "head_sha": HEAD,
                "check_summary": {"ci": "success"},
                "review_disposition": {"F-1": "resolved"},
                "round": 1, "plan_hash": rec["plan_hash"]}})
        delivery.append_entries(delivery.record_path(task_dir), entries, NOW)
    return task_dir, rec


def _complete_ev(rec, task_dir):
    """全フィールドが available な合成 complete EV（TC-56 / TC-09 ② の入力）。"""
    return {
        "run_id": "20260804T000000Z-abcdef1",
        "task_id": "TASK-9999",
        "started_at": "2099-12-31T00:00:00Z",
        "completed_at": NOW,
        "repository": "plangate",
        "source_sha": SRC,
        "final_head_sha": HEAD,
        "plan_hash": rec["plan_hash"],
        "c3_prime_decision_ref": {
            "path": f"{task_dir.name}/approvals/c3.json",
            "plan_package_hash": rec["plan_package_hash"],
        },
        "harness_version": {
            "plugin_version": "8.18.0",
            "cli_version": "0.2.0",
            "corpus_hash": "sha256:" + "0" * 64,
        },
        "routing_decisions": [],
        "ci_outcomes": [{"name": "ci", "conclusion": "success"}],
        "review_findings": [{"id": "F-1", "disposition": "resolved"}],
        "repair_rounds": 1,
        "replan_count": 0,
        "human_interventions": [],
        "terminal_state": "MERGE_READY",
        "quality_metrics": {"first_pass": False, "rounds": 1},
        "cost_metrics": {},
        "evidence_refs": [f"{task_dir.name}/delivery/record.jsonl"],
        "schema_version": "1.0",
        "observation": "run reached MERGE_READY after 1 repair round",
        "cause_hypothesis": None,
        "escalation": [],
    }


def _partial_ev(rec, task_dir):
    """Phase 1 の producer 出力に相当する EV（known-unavailable (a) 3 件を含む）。"""
    ev = _complete_ev(rec, task_dir)
    ev["routing_decisions"] = "unavailable"
    ev["replan_count"] = "unavailable"
    ev["cost_metrics"] = "unavailable"
    return ev


def _run(ev, task_dir, tmp, name="ev.json"):
    p = pathlib.Path(tmp) / name
    p.write_text(json.dumps(ev, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                 encoding="utf-8")
    # argv 先頭は sys.executable（check_exec_boundary.py の ARGV_HEAD 不変条件。
    # "python3" 直書きは PATH 依存で実行中インタプリタと一致しない）。
    cp = subprocess.run([sys.executable, str(VERIFY), str(p), str(task_dir)],
                        capture_output=True, text=True)
    return cp.returncode, cp.stderr


class SchemaContractTests(unittest.TestCase):
    """T-5 / T-6 の機械確認（TC-01 / TC-02 / TC-03 / TC-04 / TC-05 / TC-17）。"""

    def test_tc01_schema_parses_and_is_draft_2020_12(self):
        sch = _schema()
        self.assertEqual(sch["$schema"],
                         "https://json-schema.org/draft/2020-12/schema")

    def test_tc02_id_is_the_post_promotion_url(self):
        # 昇格後の URL で先に固定する（HO patch を git mv 1 手に収める）。
        self.assertEqual(
            _schema()["$id"],
            "https://github.com/s977043/plangate/schemas/run-evidence.schema.json")

    def test_tc03_additional_properties_false_and_annotation_pattern(self):
        sch = _schema()
        self.assertIs(sch["additionalProperties"], False)
        self.assertEqual(set(sch["patternProperties"]), {"^_"})
        # {} だと {"_note": {"a": 1}} が schema を通り受理器が reject する
        # 逆向きの食い違いになる。前例 schemas/c3-prime.schema.json の実値に揃える。
        self.assertEqual(sch["patternProperties"]["^_"]["type"], "string")

    def test_tc04_required_is_21_and_covers_the_20_issue_fields(self):
        sch = _schema()
        issue_fields = [
            "run_id", "task_id", "started_at", "completed_at", "repository",
            "source_sha", "final_head_sha", "plan_hash", "c3_prime_decision_ref",
            "harness_version", "routing_decisions", "ci_outcomes", "review_findings",
            "repair_rounds", "replan_count", "human_interventions", "terminal_state",
            "quality_metrics", "cost_metrics", "evidence_refs",
        ]
        self.assertEqual(len(issue_fields), 20)
        self.assertEqual(len(sch["required"]), 21)
        self.assertEqual(set(sch["required"]), set(issue_fields) | {"schema_version"})
        # evidence_status は受理器が導出する語彙であり record に格納しない。
        self.assertNotIn("evidence_status", sch["required"])
        self.assertNotIn("evidence_status", sch["properties"])

    def test_tc05_versioning_policy_and_schema_version_required(self):
        doc = CONTRACT.read_text(encoding="utf-8")
        self.assertIn("schema_version", _schema()["required"])
        self.assertIn("versioning policy", doc)
        for token in ("#872", "#873", "#874"):
            self.assertIn(token, doc, f"3 issue 合意の {token} が契約 doc に無い")
        # 前例との非対称（c3-prime は schema_version を持たない）の明記
        self.assertIn("c3-prime.schema.json", doc)

    def test_tc17_observation_and_cause_hypothesis_are_separate_fields(self):
        props = _schema()["properties"]
        self.assertIn("observation", props)
        self.assertIn("cause_hypothesis", props)
        self.assertNotEqual(props["observation"]["type"], props["cause_hypothesis"]["type"])
        self.assertNotEqual(props["observation"]["description"],
                            props["cause_hypothesis"]["description"])

    def test_forbidden_keys_are_not_registered_in_schema_properties(self):
        # EH-8 は "key": の形だけを BLOCK する。禁止キー 14 個の一覧は契約 doc
        # （.md）側に置き、schema の properties に登録しない。
        forbidden = {
            "file_path", "file_paths", "stack_trace", "stacktrace", "command_output",
            "stdout", "stderr", "raw_response", "raw_request", "api_key",
            "user_prompt", "system_prompt", "prompt_text", "absolute_path",
        }
        raw = SCHEMA.read_text(encoding="utf-8")
        for key in sorted(forbidden):
            self.assertNotIn(f'"{key}":', raw,
                             f"禁止キー {key} が schema に JSON キーとして現れる")
        doc = CONTRACT.read_text(encoding="utf-8")
        for key in sorted(forbidden):
            self.assertIn(key, doc, f"禁止キー {key} が契約 doc に列挙されていない")


class ExitCodeContractTests(unittest.TestCase):
    """T-7 / exit code 契約 4 値の骨格（TC-06 / TC-07 / TC-32 / TC-56）。"""

    def test_tc56_synthetic_complete_ev_is_accepted(self):
        # TC-56: 全フィールド available な合成 EV は exit 0（complete）。
        # Phase 1 の producer 出力からは到達しないため、0 判定の死にコード化を
        # 合成入力で防ぐ。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            rc, err = _run(_complete_ev(rec, task_dir), task_dir, tmp)
            self.assertEqual(rc, 0, f"complete EV が受理されない: {err}")

    def test_tc07_unavailable_is_partial_not_zero(self):
        # TC-07: unavailable を含む EV は exit 11（partial）。exit 0 を返さない。
        # stderr に unavailable のフィールド名を全数列挙する。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            rc, err = _run(_partial_ev(rec, task_dir), task_dir, tmp)
            self.assertEqual(rc, 11, f"partial EV の exit が 11 でない: {err}")
            for f in ("routing_decisions", "replan_count", "cost_metrics"):
                self.assertIn(f, err, f"stderr に unavailable フィールド {f} が無い: {err}")

    def test_unchecked_harness_drift_is_partial_not_complete(self):
        # 全フィールドが available でも「AC-12 の drift 検査が未実行」であることが
        # escalation に残っている EV は complete にしない（契約 §4-1）。
        # これが無いと受理器は「検査済み EV」と「未検査 EV」を区別できず、
        # AC-12 は producer の caller が --harness-version-end を渡す善意に依存する。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["escalation"] = [{"kind": "harness_drift_unchecked",
                                 "detail": "--harness-version-end 未注入"}]
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 11, f"未検査 EV が complete 扱いされた: {err}")
            self.assertIn("harness_drift_unchecked", err)

    def test_other_escalation_kinds_do_not_block_complete(self):
        # privacy 還元・未知 kind は「検査した結果の記録」であり未検証ではない。
        # これらで complete を落とすと escalation を残す動機が消える。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["escalation"] = [{"kind": "unknown_record_kind", "detail": "notice"}]
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 0, err)

    def test_tc07_single_unavailable_field_is_partial(self):
        # TC-07 verbatim: routing_decisions だけが unavailable（他は完備）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["routing_decisions"] = "unavailable"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 11, err)
            self.assertIn("routing_decisions", err)

    def test_tc06_each_required_key_missing_is_ng(self):
        # TC-06: 必須フィールドを 1 個ずつ削除 → いずれも exit 1、
        # stderr に欠落キー名を含む。21 件を全数検査する。
        schema_required = _schema()["required"]
        self.assertEqual(len(schema_required), 21)
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            base = _complete_ev(rec, task_dir)
            for key in schema_required:
                with self.subTest(missing=key):
                    ev = copy.deepcopy(base)
                    del ev[key]
                    rc, err = _run(ev, task_dir, tmp)
                    self.assertEqual(rc, 1, f"{key} 欠落が exit 1 でない（{rc}）: {err}")
                    self.assertIn(key, err, f"stderr に欠落キー {key} が無い: {err}")

    def test_tc32_arbiter_record_is_legacy(self):
        # TC-32: 9 キー / 14 キー arbiter record を渡すと exit 10（legacy 委譲）。
        # exit 0 でも 1 でもない。値・意味は c3prime_verify.py の `return 10  # legacy`
        # と同一。
        nine = {"boundary_check": {}, "class_check": {}, "decision": "AUTO_APPROVED",
                "issued_by": "arbiter-v0.1", "lite_check": {}, "policy_ref": "p@v4",
                "target_sha": SRC, "timestamp": NOW, "w_check": {}}
        fourteen = dict(nine, gates={}, ho_paths_source="x", ho_pattern_count=1,
                        run={"run_id": "r1"}, scope_check={})
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, _rec = _setup(tmp)
            for label, record in (("9key", nine), ("14key", fourteen)):
                with self.subTest(shape=label):
                    rc, err = _run(record, task_dir, tmp)
                    self.assertEqual(rc, 10, f"{label} が legacy(10) でない（{rc}）: {err}")

    def test_real_arbiter_records_are_legacy(self):
        # 実データ（docs/working/ai-loop-runs/）も全件 legacy 判別できること。
        # glob 全件を回すため corpus が成長しても件数を書き換えずに済む。
        runs = sorted((REPO / "docs" / "working" / "ai-loop-runs").glob("*.json"))
        self.assertTrue(runs, "arbiter record が 1 件も無い")
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, _rec = _setup(tmp)
            for f in runs:
                with self.subTest(record=f.name):
                    rc, err = _run(json.loads(f.read_text(encoding="utf-8")),
                                   task_dir, tmp)
                    self.assertEqual(rc, 10, f"{f.name} が legacy(10) でない（{rc}）: {err}")

    def test_usage_error_is_ng(self):
        # 引数不足は exit 1（判定不能はすべてエラー側へ倒す）。
        cp = subprocess.run([sys.executable, str(VERIFY)], capture_output=True, text=True)
        self.assertEqual(cp.returncode, 1)
        self.assertIn("usage", cp.stderr.lower())


class TamperedAndAllowlistTests(unittest.TestCase):
    """T-8 / tampered 群 + キー allowlist + schema 束縛（TC-08 / TC-09 / TC-61 / TC-62）。"""

    def test_tc08_plan_hash_one_char_tamper_is_ng(self):
        # TC-08: sha256:+64hex の形式を保った 1 文字改変。
        # <task_dir>/approvals/c3.json を再読込して照合しなければ検出できない。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            h = ev["plan_hash"]
            last = h[-1]
            ev["plan_hash"] = h[:-1] + ("0" if last != "0" else "1")
            self.assertRegex(ev["plan_hash"], r"^sha256:[0-9a-f]{64}$")
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, f"tampered plan_hash が exit 1 でない（{rc}）: {err}")
            self.assertIn("plan_hash", err)

    def test_tc08_source_sha_tamper_is_ng(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["source_sha"] = "fff9999"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)
            self.assertIn("source_sha", err)

    def test_tc08_entry_id_tamper_in_record_is_ng(self):
        # TC-08 / Edge case: record.jsonl の entry_id 改竄。
        # delivery.load_entries() の再計算照合と同型で fail-closed。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            p = delivery.record_path(task_dir)
            lines = p.read_text(encoding="utf-8").splitlines()
            row = json.loads(lines[0])
            row["entry_id"] = "sha256:" + "0" * 64
            lines[0] = json.dumps(row, sort_keys=True, ensure_ascii=False)
            p.write_text("\n".join(lines) + "\n", encoding="utf-8")
            rc, err = _run(_complete_ev(rec, task_dir), task_dir, tmp)
            self.assertEqual(rc, 1, f"entry_id 改竄が exit 1 でない（{rc}）: {err}")
            self.assertIn("entry_id", err)

    def test_tc08_final_head_sha_tamper_is_ng(self):
        # final_head_sha を record.jsonl の再計算値と食い違わせる。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["final_head_sha"] = "f" * 40
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)
            self.assertIn("final_head_sha", err)

    def test_tc08_repair_rounds_tamper_is_ng(self):
        # repair_rounds を delivery._completed_rounds() の再計算値と食い違わせる。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["repair_rounds"] = 99
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)
            self.assertIn("repair_rounds", err)

    def test_tc08_task_id_not_bound_to_task_dir_is_ng(self):
        # task_id を task_dir 名に束縛（c3prime_verify.py の
        # `task_dir.name != task_id` 分岐の転写）。別 task の EV 流用を防ぐ。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["task_id"] = "TASK-0001"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)
            self.assertIn("task_id", err)

    def test_tc09_unknown_toplevel_key_is_ng(self):
        # TC-09 ①: 未知トップレベルキーは reject（allowlist）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["foo"] = "bar"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)
            self.assertIn("foo", err)

    def test_tc09_annotation_key_string_is_accepted(self):
        # TC-09 ②: ^_ 注釈キー（string 値）は許容。合成 complete EV なので exit 0。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["_note"] = "annotation"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 0, f"^_ string 注釈キーが受理されない: {err}")

    def test_tc09_annotation_key_non_string_is_ng(self):
        # TC-09 ③: ^_ の値が string でなければ reject
        # （c3prime_verify.py の `if k.startswith("_") and not isinstance(v, str)` と同型）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            for label, value in (("dict", {"a": 1}), ("int", 1), ("list", [1])):
                with self.subTest(value=label):
                    ev = _complete_ev(rec, task_dir)
                    ev["_note"] = value
                    rc, err = _run(ev, task_dir, tmp)
                    self.assertEqual(rc, 1, f"^_={label} が reject されない（{rc}）: {err}")
                    self.assertIn("_note", err)

    def test_tc61_required_set_is_derived_from_schema(self):
        # TC-61: 受理器は schema を唯一の正として読む。
        # required 集合をハードコードせず schema から導出していること。
        import run_evidence_verify as rev
        self.assertEqual(set(rev.required_keys()), set(_schema()["required"]))
        self.assertEqual(set(rev.allowed_keys()), set(_schema()["properties"]))

    def test_tc61_required_set_is_not_hardcoded_as_a_literal(self):
        # TC-61: required 集合そのものを受理器のリテラル列挙で持っていないこと
        # （個々のフィールド名を束縛検証で参照するのは正当。禁じたいのは
        # 「schema を書き換えても追従しない必須キー一覧」の重複定義）。
        # AST 上の list / tuple / set の文字列リテラル集合を全数走査する。
        import ast
        src = (HERE / "run_evidence_verify.py").read_text(encoding="utf-8")
        req = set(_schema()["required"])
        for node in ast.walk(ast.parse(src)):
            if isinstance(node, (ast.List, ast.Tuple, ast.Set)):
                lits = {e.value for e in node.elts
                        if isinstance(e, ast.Constant) and isinstance(e.value, str)}
                overlap = lits & req
                self.assertLess(
                    len(overlap), 5,
                    f"required キーのリテラル列挙が受理器に存在する（schema 追従が壊れる）: "
                    f"{sorted(overlap)}")

    def test_tc61_verifier_follows_schema_changes(self):
        # 「schema が唯一の正」の実証: schema を差し替えると required_keys() が追従する。
        import run_evidence_verify as rev
        real = rev.SCHEMA_PATH
        with tempfile.TemporaryDirectory() as tmp:
            alt = pathlib.Path(tmp) / "alt.schema.json"
            sch = _schema()
            sch["required"] = sorted(set(sch["required"]) | {"observation"})
            alt.write_text(json.dumps(sch), encoding="utf-8")
            rev.SCHEMA_PATH = alt
            try:
                self.assertIn("observation", rev.required_keys())
            finally:
                rev.SCHEMA_PATH = real
            self.assertNotIn("observation", rev.required_keys())

    def test_tc62_producer_output_keys_subset_of_properties(self):
        # TC-62: producer 出力キーの全集合 ⊆ schema properties ∪ ^_。
        # 全集合の唯一の列挙点は契約 doc の §2 フィールド表（plan Step 1 item 3）。
        rows = re.findall(r"^\| (\d+) \| `([a-z_0-9]+)` \|",
                          CONTRACT.read_text(encoding="utf-8"), re.M)
        doc_keys = {name for _, name in rows}
        self.assertEqual(len(rows), 24, "契約 doc の producer 出力キー表が 24 行でない")
        props = set(_schema()["properties"])
        self.assertLessEqual(doc_keys, props,
                             f"契約 doc にあり schema properties に無いキー: {doc_keys - props}")
        self.assertEqual(doc_keys, props,
                         f"1:1 でない: only-doc={doc_keys - props} only-schema={props - doc_keys}")
        # escalation の登録漏れは「最も検証が必要な EV だけが reject される」経路。
        for k in ("observation", "cause_hypothesis", "escalation"):
            self.assertIn(k, props)
        # producer 実装後は OUTPUT_KEYS も同一集合であること（T-15 以降で有効化）。
        try:
            import run_evidence
        except ImportError:
            run_evidence = None
        if run_evidence is not None and hasattr(run_evidence, "OUTPUT_KEYS"):
            self.assertEqual(set(run_evidence.OUTPUT_KEYS), props)


class BlockedTerminalStateTests(unittest.TestCase):
    """terminal_state=BLOCKED（record.jsonl 不在）の受理（TC-58 の受理器側）。"""

    def test_blocked_ev_without_record_is_partial_with_seven_unavailable(self):
        # record.jsonl が存在しない BLOCKED run は delivery 層 4 フィールドが
        # unavailable。exit 11 で、unavailable の内訳は (a)3 + (b)4 = 7 件。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp, with_record=False)
            ev = _partial_ev(rec, task_dir)
            ev["terminal_state"] = "BLOCKED"
            for f in ("final_head_sha", "ci_outcomes", "review_findings", "repair_rounds"):
                ev[f] = "unavailable"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 11, err)
            for f in ("routing_decisions", "replan_count", "cost_metrics",
                      "final_head_sha", "ci_outcomes", "review_findings", "repair_rounds"):
                self.assertIn(f, err, f"stderr に {f} が列挙されない: {err}")

    def test_tc64_unresolvable_pr_number_must_be_unavailable_not_zero(self):
        # TC-64 の受理器側: record.jsonl は存在するが kind=merge_ready が無く
        # PR 番号を解決できないケース。delivery._completed_rounds(entries, None) は
        # 例外にならず 0 を返すため、0 を受理すると「修理 0 回」として
        # #869 の first-pass 判定を汚染する（C-2 R-C04 の fail-open 経路）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp, merge_ready=False)
            entries = delivery.load_entries(delivery.record_path(task_dir))
            self.assertEqual(delivery._completed_rounds(entries, None), 0,
                             "前提: PR 未解決でも 0 が返る（例外にならない）")
            ev = _complete_ev(rec, task_dir)
            ev["repair_rounds"] = 0                    # ← 0 で埋める fail-open
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, f"PR 未解決で repair_rounds=0 が通った（{rc}）: {err}")
            self.assertIn("repair_rounds", err)
            # unavailable なら partial として受理される
            ev["repair_rounds"] = "unavailable"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 11, err)
            self.assertIn("repair_rounds", err)

    def test_blocked_ev_padded_with_dummy_sha_is_ng(self):
        # record.jsonl 不在なのに final_head_sha をダミー sha で埋めたら reject
        # （空文字・ダミー sha・0 で埋めない = fail-open 防止）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp, with_record=False)
            ev = _partial_ev(rec, task_dir)
            ev["terminal_state"] = "BLOCKED"
            ev["ci_outcomes"] = "unavailable"
            ev["review_findings"] = "unavailable"
            ev["repair_rounds"] = 0          # ← 0 で埋める fail-open
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, f"record.jsonl 不在で repair_rounds=0 が通った: {err}")
            self.assertIn("repair_rounds", err)


if __name__ == "__main__":
    unittest.main()
