#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """test_ci_taxonomy.py — ci_taxonomy.py（AC-8 `ci_failure_taxonomy` の供給主体）の unittest。

実行: python3 scripts/ai-loop/test_ci_taxonomy.py

契約正本: docs/working/TASK-0917/plan.md 論点 D3 `ci_failure_taxonomy` 行
カバー: test-cases.md TC-17（manual entry を正とする）/ TC-18（狭い自動 allowlist =
`environment` のみ・`code` を機械が断定しない）/ TC-19（未該当は taxonomy を出力
しない → `delivery.py` の既存 fail-closed `HUMAN_ESCALATED` に委ねる）。

設計上の注意:
- **外部作用ゼロ**。ネットワークもプロセス起動も行わない（`record.jsonl` の
  読み取りのみ。本ファイル自身も `check_exec_boundary.py` の検査対象）。
- 変異注入は **allowlist（rule table）の差し替え**で行い、作業ツリーのファイルは
  1 バイトも書き換えない。
"""

import json
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import ci_taxonomy  # noqa: E402
import delivery  # noqa: E402  enum / record 契約の単一定義（本テストでは読むだけ）

PR = 917
H1 = "1111111111111111111111111111111111111111"
H2 = "2222222222222222222222222222222222222222"

ENV_LOGS = (
    "Error: You have exceeded a secondary rate limit. Please wait.",
    "npm ERR! network read ECONNRESET",
    "The runner has received a shutdown signal.",
)

UNKNOWN_LOGS = (
    "FAILED tests/test_foo.py::test_bar - AssertionError: 1 != 2",
    "SyntaxError: invalid syntax",
    "",
    "flaky test suspected by a human reading the log",
    "exit code 1",
)


def _manual(taxonomy, head_sha=H1, pr_number=PR, source=ci_taxonomy.MANUAL_SOURCE):
    entry = {
        "kind": ci_taxonomy.MANUAL_ENTRY_KIND,
        "pr_number": pr_number,
        "head_sha": head_sha,
        "taxonomy": taxonomy,
    }
    if source is not None:
        entry["source"] = source
    return entry


def _write_record(tmp, entries):
    path = pathlib.Path(tmp) / "delivery" / "record.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for e in entries:
            f.write(json.dumps(e, ensure_ascii=False, sort_keys=True) + "\n")
    return path


# ---------------------------------------------------------------------------
# TC-17: manual entry を正とする
# ---------------------------------------------------------------------------

class ManualEntryTests(unittest.TestCase):

    def test_manual_entry_is_returned(self):
        for tax in delivery.VALID_TAXONOMY_REPAIR:
            with self.subTest(taxonomy=tax):
                self.assertEqual(
                    ci_taxonomy.resolve_taxonomy(entries=[_manual(tax)],
                                                 pr_number=PR, head_sha=H1),
                    tax)

    def test_manual_wins_over_auto_classification(self):
        # 自動分類が environment を出す log でも manual の code が優先される。
        self.assertEqual(
            ci_taxonomy.resolve_taxonomy(entries=[_manual("code")], pr_number=PR,
                                         head_sha=H1, log_text=ENV_LOGS[0]),
            "code")

    def test_latest_manual_entry_wins(self):
        entries = [_manual("flaky"), _manual("code")]
        self.assertEqual(
            ci_taxonomy.resolve_taxonomy(entries=entries, pr_number=PR, head_sha=H1),
            "code")

    def test_manual_entry_bound_to_other_head_is_ignored(self):
        # 旧 head の manual entry を現 head に流用しない（AC-1 と同型の head 束縛）。
        self.assertIsNone(
            ci_taxonomy.resolve_taxonomy(entries=[_manual("code", head_sha=H2)],
                                         pr_number=PR, head_sha=H1))

    def test_manual_entry_of_other_pr_is_ignored(self):
        self.assertIsNone(
            ci_taxonomy.resolve_taxonomy(entries=[_manual("code", pr_number=PR + 1)],
                                         pr_number=PR, head_sha=H1))

    def test_non_manual_source_cannot_assert_code(self):
        # 機械が書いた entry（source != manual）を manual 経路で受理しない
        # ＝「`code` を機械が積極的に断定しない」の構造的保証。
        for source in ("auto", "collector", None, "", "MANUAL"):
            with self.subTest(source=source):
                self.assertIsNone(
                    ci_taxonomy.resolve_taxonomy(
                        entries=[_manual("code", source=source)],
                        pr_number=PR, head_sha=H1))

    def test_manual_entry_with_unknown_value_is_ignored(self):
        # enum 外は出力しない（delivery.py の fail-closed に委ねる）。
        for bad in ("infra", "CODE", "", None, 1, True, ["code"]):
            with self.subTest(bad=bad):
                self.assertIsNone(
                    ci_taxonomy.resolve_taxonomy(entries=[_manual(bad)],
                                                 pr_number=PR, head_sha=H1))

    def test_other_kinds_are_ignored(self):
        entries = [{"kind": "state", "state": "CHECKS_FAILED", "pr_number": PR,
                    "head_sha": H1, "taxonomy": "code"}]
        self.assertIsNone(
            ci_taxonomy.resolve_taxonomy(entries=entries, pr_number=PR, head_sha=H1))


# ---------------------------------------------------------------------------
# TC-18: 狭い自動 allowlist（environment のみ）
# ---------------------------------------------------------------------------

class AutoClassificationTests(unittest.TestCase):

    def test_known_environment_patterns(self):
        for log in ENV_LOGS:
            with self.subTest(log=log):
                self.assertEqual(ci_taxonomy.classify_log(log), "environment")
                self.assertEqual(
                    ci_taxonomy.resolve_taxonomy(entries=[], pr_number=PR,
                                                 head_sha=H1, log_text=log),
                    "environment")

    def test_patterns_are_case_insensitive(self):
        self.assertEqual(ci_taxonomy.classify_log("ERROR: API RATE LIMIT EXCEEDED"),
                         "environment")

    def test_no_auto_rule_yields_code_or_flaky(self):
        # allowlist の値域そのものを固定する（`code` を返す自動分類ルールが存在しない）。
        self.assertEqual({r.taxonomy for r in ci_taxonomy.AUTO_RULES}, {"environment"})

    def test_auto_output_is_always_within_delivery_enum(self):
        for log in ENV_LOGS + UNKNOWN_LOGS:
            with self.subTest(log=log):
                out = ci_taxonomy.classify_log(log)
                self.assertIn(out, (None,) + tuple(delivery.VALID_TAXONOMY_REPAIR))

    def test_valid_taxonomy_is_single_sourced_from_delivery(self):
        self.assertEqual(tuple(ci_taxonomy.VALID_TAXONOMY),
                         tuple(delivery.VALID_TAXONOMY_REPAIR))

    # --- 変異注入（検出力の実証）--------------------------------------------

    def test_mutation_empty_allowlist_removes_environment_verdict(self):
        # allowlist を空にすると environment 判定が消える = この判定が
        # allowlist に由来していることの実証（テストの空振り防止）。
        for log in ENV_LOGS:
            with self.subTest(log=log):
                self.assertIsNone(ci_taxonomy.classify_log(log, rules=()))
                self.assertIsNone(
                    ci_taxonomy.resolve_taxonomy(entries=[], pr_number=PR,
                                                 head_sha=H1, log_text=log, rules=()))

    def test_mutation_module_level_allowlist_swap(self):
        original = ci_taxonomy.AUTO_RULES
        ci_taxonomy.AUTO_RULES = ()
        try:
            self.assertIsNone(ci_taxonomy.classify_log(ENV_LOGS[0]))
        finally:
            ci_taxonomy.AUTO_RULES = original
        self.assertEqual(ci_taxonomy.classify_log(ENV_LOGS[0]), "environment")


# ---------------------------------------------------------------------------
# TC-19: 未該当は taxonomy を出力しない（fail-closed に委譲）
# ---------------------------------------------------------------------------

class NoOutputTests(unittest.TestCase):

    def test_unknown_log_without_manual_entry_yields_none(self):
        for log in UNKNOWN_LOGS:
            with self.subTest(log=log):
                self.assertIsNone(
                    ci_taxonomy.resolve_taxonomy(entries=[], pr_number=PR,
                                                 head_sha=H1, log_text=log))

    def test_snapshot_key_absent_when_unresolved(self):
        snap = {"pr_number": PR, "head_sha": H1}
        out = ci_taxonomy.apply_to_snapshot(snap, None)
        self.assertNotIn(ci_taxonomy.SNAPSHOT_KEY, out)
        # 入力 snapshot を破壊しない（純関数）。
        self.assertEqual(snap, {"pr_number": PR, "head_sha": H1})

    def test_snapshot_key_present_when_resolved(self):
        out = ci_taxonomy.apply_to_snapshot({"pr_number": PR}, "environment")
        self.assertEqual(out[ci_taxonomy.SNAPSHOT_KEY], "environment")

    def test_apply_to_snapshot_rejects_out_of_enum_value(self):
        with self.assertRaises(ValueError):
            ci_taxonomy.apply_to_snapshot({"pr_number": PR}, "infra")

    def test_unresolved_snapshot_escalates_in_delivery(self):
        # 「出力しない」が delivery.py の既存 fail-closed に接続することの実証。
        # 未知値ではなくキー欠落でも HUMAN_ESCALATED に落ちる。
        snap = ci_taxonomy.apply_to_snapshot(_failing_snapshot(), None)
        result = delivery.assess(snap, [], plan_hash="sha256:" + "0" * 64)
        self.assertEqual(result["state"], "HUMAN_ESCALATED")
        self.assertTrue(any("ci_failure_taxonomy" in r for r in result["reasons"]))

    def test_resolved_snapshot_reaches_checks_failed_in_delivery(self):
        snap = ci_taxonomy.apply_to_snapshot(_failing_snapshot(), "environment")
        result = delivery.assess(snap, [], plan_hash="sha256:" + "0" * 64)
        self.assertEqual(result["state"], "CHECKS_FAILED")


# ---------------------------------------------------------------------------
# record.jsonl 読み取り（delivery の record 契約を再利用・改竄は fail-closed）
# ---------------------------------------------------------------------------

class RecordLoadTests(unittest.TestCase):

    def test_missing_record_is_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "delivery" / "record.jsonl"
            self.assertEqual(ci_taxonomy.load_record_entries(path), [])

    def test_manual_entry_read_from_record_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = _write_record(tmp, [_manual("code")])
            entries = ci_taxonomy.load_record_entries(path)
            self.assertEqual(
                ci_taxonomy.resolve_taxonomy(entries=entries, pr_number=PR, head_sha=H1),
                "code")

    def test_corrupt_record_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "delivery" / "record.jsonl"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{not json}\n", encoding="utf-8")
            with self.assertRaises(delivery.RecordError):
                ci_taxonomy.load_record_entries(path)

    def test_tampered_entry_id_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            row = dict(_manual("code"), entry_id="sha256:" + "0" * 64)
            path = _write_record(tmp, [row])
            with self.assertRaises(delivery.RecordError):
                ci_taxonomy.load_record_entries(path)


def _failing_snapshot():
    """CI failure のある最小 snapshot（delivery.validate_snapshot の必須キー充足）。"""
    return {
        "task_id": "TASK-0917",
        "pr_number": PR,
        "head_sha": H1,
        "source_sha_ancestry": True,
        "mergeable": "MERGEABLE",
        "checks": [{"name": "ci", "sha": H1, "conclusion": "failure"}],
        "review": {"state": "approved", "sha": H1},
        "findings": [],
        "changed_files": [],
        "allowed_paths": ["scripts/ai-loop/"],
        "escalation_flags": [],
        "dod_evaluated": True,
    }


if __name__ == "__main__":
    unittest.main(verbosity=2)
