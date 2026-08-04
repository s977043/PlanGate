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


def _setup(tmp, *, with_record=True, merge_ready=True, decision="AUTO_APPROVED",
           last_state="MERGE_READY"):
    """sandbox の task_dir（Plan Package 6 要素 + c3-prime + record.jsonl）を作る。

    受理器は `terminal_state` / delivery 層フィールドを **task_dir から再導出**して
    照合する（R1 C-1 / M-3 の是正）。したがって sandbox は「EV が主張する終端」と
    「c3.json の decision / record.jsonl の実体」が**整合している**必要がある。
    `decision` / `last_state` を注入可能にしたのはこのため（producer 側の
    `test_run_evidence._setup` と同じ形にそろえる）。
    """
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
        entries = [
            {"kind": "state", "state": last_state, "head_sha": HEAD,
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
        # producer の derive_quality_metrics は rounds = repair_rounds + 1。
        # 受理器が再導出照合するようになったため、合成 EV も同じ規則に従う。
        "quality_metrics": {"first_pass": False, "rounds": 2},
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

    @staticmethod
    def _blocked_ev(rec, task_dir):
        """BLOCKED run の EV（契約 §5-1: (a)3 + (b)5 = 8 件が unavailable）。"""
        ev = _partial_ev(rec, task_dir)
        ev["terminal_state"] = "BLOCKED"
        for f in ("final_head_sha", "ci_outcomes", "review_findings",
                  "repair_rounds", "quality_metrics"):
            ev[f] = "unavailable"
        return ev

    def test_blocked_ev_without_record_is_partial_with_eight_unavailable(self):
        # record.jsonl が存在しない BLOCKED run は delivery 層 4 フィールド +
        # quality_metrics が unavailable。exit 11 で、内訳は (a)3 + (b)5 = 8 件。
        # ⚠️ c3.json の decision も BLOCKED でなければならない（受理器が
        # terminal_state を c3.json / record.jsonl から再導出するため / R1 C-1）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp, with_record=False, decision="BLOCKED")
            rc, err = _run(self._blocked_ev(rec, task_dir), task_dir, tmp)
            self.assertEqual(rc, 11, err)
            for f in ("routing_decisions", "replan_count", "cost_metrics",
                      "final_head_sha", "ci_outcomes", "review_findings",
                      "repair_rounds", "quality_metrics"):
                self.assertIn(f, err, f"stderr に {f} が列挙されない: {err}")

    def test_blocked_ev_whose_c3_decision_is_not_blocked_is_ng(self):
        # 逆側: c3.json の decision が BLOCKED でないのに terminal_state=BLOCKED を
        # 名乗る EV は reject（R1 critical C-1 の本体。従来は exit 0 で通っていた）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["terminal_state"] = "BLOCKED"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, f"decision と食い違う terminal_state が通った: {err}")
            self.assertIn("terminal_state", err)

    def test_tc64_unresolvable_pr_number_must_be_unavailable_not_zero(self):
        # TC-64 の受理器側: record.jsonl は存在するが kind=merge_ready が無く
        # PR 番号を解決できないケース。delivery._completed_rounds(entries, None) は
        # 例外にならず 0 を返すため、0 を受理すると「修理 0 回」として
        # #869 の first-pass 判定を汚染する（C-2 R-C04 の fail-open 経路）。
        # 終端であること自体は最終 kind=state の HUMAN_ESCALATED で成立させる
        # （producer 側 test_tc64_... と同じ入力形状）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp, merge_ready=False,
                                   last_state="HUMAN_ESCALATED")
            entries = delivery.load_entries(delivery.record_path(task_dir))
            self.assertEqual(delivery._completed_rounds(entries, None), 0,
                             "前提: PR 未解決でも 0 が返る（例外にならない）")
            ev = _complete_ev(rec, task_dir)
            ev["terminal_state"] = "HUMAN_ESCALATED"
            ev["ci_outcomes"] = "unavailable"
            ev["review_findings"] = "unavailable"
            ev["quality_metrics"] = "unavailable"
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
            task_dir, rec = _setup(tmp, with_record=False, decision="BLOCKED")
            ev = self._blocked_ev(rec, task_dir)
            ev["final_head_sha"] = HEAD      # ← ダミー sha で埋める fail-open
            ev["repair_rounds"] = 0          # ← 0 で埋める fail-open
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, f"record.jsonl 不在で repair_rounds=0 が通った: {err}")
            self.assertIn("repair_rounds", err)
            self.assertIn("final_head_sha", err)


class RederivationTests(unittest.TestCase):
    """R1 critical C-1 / major M-3: 受理器が record.jsonl から再導出して照合する。"""

    def test_terminal_state_outside_the_contract_vocabulary_is_ng(self):
        # C-1: allowed_keys() / required_keys() は schema から**キー名しか**
        # 取り出さないため、schema の enum は従来どこからも強制されていなかった。
        # 実測（是正前）: terminal_state="WAITING_FOR_CHECKS" の EV が exit 0。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            for bogus in ("WAITING_FOR_CHECKS", "MERGE_READY_CANDIDATE",
                          "EXEC_RETURN", "banana", "", "merge_ready"):
                with self.subTest(terminal_state=bogus):
                    ev = _complete_ev(rec, task_dir)
                    ev["terminal_state"] = bogus
                    rc, err = _run(ev, task_dir, tmp)
                    self.assertEqual(rc, 1, f"{bogus!r} が受理された（{rc}）: {err}")
                    self.assertIn("terminal_state", err)

    def test_terminal_state_within_the_vocabulary_but_wrong_is_ng(self):
        # 語彙 allowlist だけでは足りない: 3 値の中で入れ替えると素通りしてしまう。
        # record に merge_ready entry があるのに HUMAN_ESCALATED を名乗る EV を弾く。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["terminal_state"] = "HUMAN_ESCALATED"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)
            self.assertIn("terminal_state", err)

    def test_m3_ci_outcomes_tamper_is_ng(self):
        # M-3: CI 失敗を success に書き換えた EV が complete で受理されていた。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            for label, value in (
                ("conclusion_rewrite", [{"name": "ci", "conclusion": "failure"}]),
                ("check_dropped", []),
                ("check_invented", [{"name": "ci", "conclusion": "success"},
                                    {"name": "ghost", "conclusion": "success"}]),
            ):
                with self.subTest(case=label):
                    ev = _complete_ev(rec, task_dir)
                    ev["ci_outcomes"] = value
                    rc, err = _run(ev, task_dir, tmp)
                    self.assertEqual(rc, 1, f"{label} が受理された（{rc}）: {err}")
                    self.assertIn("ci_outcomes", err)

    def test_m3_review_findings_tamper_is_ng(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["review_findings"] = [{"id": "F-1", "disposition": "dismissed"}]
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)
            self.assertIn("review_findings", err)

    def test_m3_quality_metrics_first_pass_tamper_is_ng(self):
        # 修理 1 回の run を first_pass=true に書き換える = #869 の学習母集団汚染。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            for label, value in (
                ("first_pass_flipped", {"first_pass": True, "rounds": 2}),
                ("rounds_reduced", {"first_pass": False, "rounds": 1}),
                ("unavailable_claimed", "unavailable"),
            ):
                with self.subTest(case=label):
                    ev = _complete_ev(rec, task_dir)
                    ev["quality_metrics"] = value
                    rc, err = _run(ev, task_dir, tmp)
                    self.assertEqual(rc, 1, f"{label} が受理された（{rc}）: {err}")
                    self.assertIn("quality_metrics", err)

    def test_rederivation_uses_the_producer_pure_functions(self):
        # 再実装しない（producer と drift させない）ことを構造で固定する。
        import run_evidence
        import run_evidence_verify as rev
        self.assertIs(rev.run_evidence, run_evidence)
        for name in ("derive_delivery_fields", "derive_quality_metrics",
                     "derive_terminal_state", "check_output_privacy", "_walk"):
            self.assertTrue(hasattr(run_evidence, name), name)


class VerifierPrivacyBackstopTests(unittest.TestCase):
    """R1 critical C-2 後半: producer を通さない EV も受理側で privacy を検査する。"""

    def test_owner_prefixed_repository_is_ng(self):
        # producer の --repository は owner 付きを reject するが、受理器には
        # 検査が無く「producer 側の検査が唯一の防御線」だった（契約 §7-3）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["repository"] = "s977043/plangate"
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, f"owner 付き repository が受理された: {err}")
            self.assertIn("repository", err)

    def test_absolute_paths_and_account_identifiers_are_ng(self):
        cases = {
            "evidence_refs_absolute": ("evidence_refs", ["/Users/user/secret.md"]),
            "observation_url": (
                "observation",
                "https://github.com/s977043/plangate/pull/941 でレビュー"),
            "observation_handle": ("observation", "@s977043 のレビュー待ち"),
            "escalation_absolute": (
                "escalation", [{"kind": "x", "detail": "/Users/user/.ssh/id_rsa"}]),
            "cause_hypothesis_absolute": ("cause_hypothesis", "/etc/passwd を読んだ"),
        }
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            for label, (key, value) in cases.items():
                with self.subTest(case=label):
                    ev = _complete_ev(rec, task_dir)
                    ev[key] = value
                    rc, err = _run(ev, task_dir, tmp)
                    self.assertEqual(rc, 1, f"{label} が受理された（{rc}）: {err}")

    def test_forbidden_key_inside_a_nested_object_is_ng(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["human_interventions"] = [{"login": "someone"}]
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 1, err)


class SchemaStructuralValidationTests(unittest.TestCase):
    """R1 major M-5: schema の type / enum / pattern / minLength を受理器が強制する。"""

    def test_type_and_pattern_violations_are_ng(self):
        cases = {
            "run_id_empty": ("run_id", ""),                       # minLength: 1
            "run_id_wrong_type": ("run_id", 1),                   # type: string
            "started_at_not_iso": ("started_at", "2026-08-05"),   # $defs/timestamp
            "schema_version_bad": ("schema_version", "banana"),   # pattern
            "repair_rounds_negative": ("repair_rounds", -1),      # minimum: 0
            "repair_rounds_string": ("repair_rounds", "1"),       # anyOf
            "harness_corpus_hash_bad": (
                "harness_version",
                {"plugin_version": "1", "cli_version": "1", "corpus_hash": "x"}),
            "cause_hypothesis_wrong_type": ("cause_hypothesis", 1),
            "escalation_item_missing_kind": ("escalation", [{"detail": "x"}]),
            "escalation_item_extra_key": (
                "escalation", [{"kind": "k", "detail": "d", "extra": "e"}]),
            "evidence_refs_wrong_item_type": ("evidence_refs", [1]),
        }
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            for label, (key, value) in cases.items():
                with self.subTest(case=label):
                    ev = _complete_ev(rec, task_dir)
                    ev[key] = value
                    rc, err = _run(ev, task_dir, tmp)
                    self.assertEqual(rc, 1, f"{label} が受理された（{rc}）: {err}")
                    self.assertIn(key, err, err)

    def test_validator_agrees_with_jsonschema_on_the_goldens(self):
        # 手書き subset validator が jsonschema と乖離していないこと。
        # jsonschema 未導入環境では skip（CI の schema-validate job だけが導入する）。
        try:
            import jsonschema
        except ImportError:                       # pragma: no cover
            self.skipTest("jsonschema 未導入の環境")
        import run_evidence_verify as rev
        fixtures = sorted(
            (REPO / "tests" / "fixtures" / "run-evidence").glob("fx-0[1-6]*.json"))
        self.assertTrue(fixtures, "golden fixture が見つからない")
        schema = _schema()
        for path in fixtures:
            with self.subTest(fixture=path.name):
                ev = json.loads(path.read_text(encoding="utf-8"))
                jsonschema.validate(ev, schema)               # 参照実装
                self.assertEqual(rev.validate_against_schema(ev, schema), [],
                                 f"{path.name} を subset validator が誤って reject")

    def test_validator_rejects_what_jsonschema_rejects(self):
        try:
            import jsonschema
        except ImportError:                       # pragma: no cover
            self.skipTest("jsonschema 未導入の環境")
        import run_evidence_verify as rev
        schema = _schema()
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            base = _complete_ev(rec, task_dir)
            mutations = (
                ("terminal_state", "WAITING_FOR_CHECKS"),
                ("repository", "s977043/plangate"),
                ("schema_version", "1"),
                ("evidence_refs", ["/abs/path.md"]),
                ("task_id", "TASK-99999"),
                ("plan_hash", "sha256:zz"),
            )
            for key, value in mutations:
                with self.subTest(field=key):
                    ev = copy.deepcopy(base)
                    ev[key] = value
                    with self.assertRaises(jsonschema.ValidationError):
                        jsonschema.validate(ev, schema)
                    self.assertTrue(rev.validate_against_schema(ev, schema),
                                    f"{key} の違反を subset validator が見逃した")

    def test_unsupported_schema_keyword_is_fail_closed(self):
        # 「解釈できない schema を黙って通す」は「検査していない」と同義。
        import run_evidence_verify as rev
        schema = {"type": "object",
                  "properties": {"x": {"type": "string", "multipleOf": 2}}}
        self.assertTrue(rev.validate_against_schema({"x": "a"}, schema))


class SchemaResolutionTests(unittest.TestCase):
    """R1 major M-4: bundled 配置での schema 解決と「起動不能」の exit 分離。"""

    def test_schema_path_falls_back_to_the_bundled_layout(self):
        import run_evidence_verify as rev
        names = [p.name for p in rev.SCHEMA_CANDIDATES]
        self.assertEqual(set(names), {"run-evidence.schema.json"})
        self.assertGreaterEqual(len(rev.SCHEMA_CANDIDATES), 2,
                                "bundled レイアウトの候補が無い")
        # 2 本目は <skill>/schemas/（scripts/ の親 = skill ルート直下）
        self.assertEqual(rev.SCHEMA_CANDIDATES[1].parent.name, "schemas")
        self.assertEqual(rev.SCHEMA_CANDIDATES[1].parent.parent,
                         rev.HERE.parent)
        self.assertTrue(rev.SCHEMA_PATH.is_file(),
                        f"schema を解決できていない: {rev.SCHEMA_PATH}")

    def test_plugin_copy_ships_the_schema_next_to_the_verifier(self):
        # 同梱漏れは導入先で**常に exit 2**（= 検査が一度も走らない）になる。
        bundled = (REPO / "plugin" / "plangate" / "skills" / "ai-loop-cycle"
                   / "schemas" / "run-evidence.schema.json")
        self.assertTrue(bundled.is_file(), f"plugin に schema が同梱されていない: {bundled}")
        self.assertEqual(json.loads(bundled.read_text(encoding="utf-8")), _schema(),
                         "同梱 schema が正本と乖離している")

    def test_unreadable_schema_exits_two_not_one(self):
        # exit 1（NG = 改竄兆候）と exit 2（起動不能）を混ぜない。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev_path = pathlib.Path(tmp) / "ev.json"
            ev_path.write_text(json.dumps(_complete_ev(rec, task_dir)),
                               encoding="utf-8")
            harness = pathlib.Path(tmp) / "boom.py"
            harness.write_text(
                "import pathlib, sys\n"
                f"sys.path.insert(0, {str(HERE)!r})\n"
                "import run_evidence_verify as rev\n"
                "rev.SCHEMA_PATH = pathlib.Path(sys.argv[3])\n"
                "sys.exit(rev.main(sys.argv[:3]))\n",
                encoding="utf-8")
            cp = subprocess.run(
                [sys.executable, str(harness), str(ev_path), str(task_dir),
                 str(pathlib.Path(tmp) / "missing.schema.json")],
                capture_output=True, text=True)
            self.assertEqual(cp.returncode, 2,
                             f"schema 不在の exit が 2 でない: {cp.stderr}")
            self.assertIn("検査を実行していない", cp.stderr)


class NestedUnavailableTests(unittest.TestCase):
    """R1 minor m-1: unavailable の全数列挙が list 内・深い階層まで届くこと。"""

    def test_unavailable_paths_walks_lists_and_deep_objects(self):
        import run_evidence_verify as rev
        data = {
            "top": "unavailable",
            "obj": {"a": "unavailable", "b": {"c": "unavailable"}},
            "arr": ["unavailable", {"d": "unavailable"}],
            "clean": "ok",
        }
        self.assertEqual(
            rev._unavailable_paths(data),
            ["arr[0]", "arr[1].d", "obj.a", "obj.b.c", "top"])

    def test_nested_unavailable_makes_the_record_partial_not_complete(self):
        # routing_decisions は受理器が再導出しない（#868 未実装）ため、
        # 入れ子 unavailable が exit 0 で通る経路がここに残っていた。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir, rec = _setup(tmp)
            ev = _complete_ev(rec, task_dir)
            ev["routing_decisions"] = [{"step": "route", "target": "unavailable"}]
            rc, err = _run(ev, task_dir, tmp)
            self.assertEqual(rc, 11, f"入れ子 unavailable が complete で通った: {err}")
            self.assertIn("routing_decisions[0].target", err)


if __name__ == "__main__":
    unittest.main()
