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

import json
import pathlib
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
import sys

if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import pbi_live_shadow_collector as collector  # noqa: E402


class LiveShadowCollectorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "scripts").mkdir()
        self.source_ref = "TASK-9999/delivery/record.jsonl"
        source = self.root / self.source_ref
        source.parent.mkdir(parents=True)
        source.write_text(
            '{"kind":"state","state":"MERGE_READY"}\n',
            encoding="utf-8",
        )
        self.signal = {
            "signal_id": "SIG-COLLECT-001",
            "source_ref": self.source_ref,
            "source_kind": "existing_behavior",
            "claim_class": "observed",
            "statement": "Completed run has no new PBI-worthy finding.",
            "disposition": "informational",
            "target_layer": "delivery",
            "candidate_problem": None,
        }
        self.capture_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/capture.json"
        )
        self.packet_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/review-packet.json"
        )
        self.run_evidence_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/run-evidence.json"
        )

    def tearDown(self):
        self.tmp.cleanup()

    def _collect_capture(self):
        return collector.collect_capture(
            repo_root=self.root,
            signal=self.signal,
            task_id="TASK-9999",
            run_id="run-01",
            captured_at="2099-12-31T12:00:00Z",
            runtime_head_sha="abcdef1234567890abcdef1234567890abcdef12",
            capture_ref=self.capture_ref,
        )

    def _write_bound_run_evidence(self, *, include_capture=True, include_source=True):
        fixture = (
            HERE.parent.parent
            / "tests/fixtures/run-evidence/fx-01-first-pass.json"
        )
        record = json.loads(fixture.read_text(encoding="utf-8"))
        refs = list(record["evidence_refs"])
        if include_source and self.source_ref not in refs:
            refs.append(self.source_ref)
        if include_capture and self.capture_ref not in refs:
            refs.append(self.capture_ref)
        record["evidence_refs"] = refs
        target = self.root / self.run_evidence_ref
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True)
            + "\n",
            encoding="utf-8",
        )
        return record

    def test_capture_is_create_or_reuse_identical_and_authority_limited(self):
        result = self._collect_capture()
        target = self.root / self.capture_ref
        self.assertTrue(target.is_file())
        stored = json.loads(target.read_text(encoding="utf-8"))
        self.assertEqual(stored["mode"], "passive_shadow_capture")
        self.assertFalse(stored["authority"]["write_allowed"])
        self.assertFalse(stored["authority"]["close_allowed"])
        self.assertFalse(stored["authority"]["suppression_allowed"])
        self.assertFalse(stored["authority"]["oracle_attached"])
        self.assertTrue(result["authority"]["evidence_create_allowed"])
        self.assertFalse(result["authority"]["overwrite_allowed"])
        self.assertTrue(result["authority"]["idempotent_reuse_allowed"])
        self.assertFalse(result["authority"]["pbi_write_allowed"])
        self.assertFalse(result["authority"]["issue_write_allowed"])
        self.assertFalse(result["artifact_reused"])

        before = target.read_bytes()
        retry = self._collect_capture()
        self.assertTrue(retry["artifact_reused"])
        self.assertEqual(target.read_bytes(), before)

    def test_capture_output_must_stay_in_task_live_shadow_namespace(self):
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_capture(
                repo_root=self.root,
                signal=self.signal,
                task_id="TASK-9999",
                run_id="run-01",
                captured_at="2099-12-31T12:00:00Z",
                runtime_head_sha="abcdef1234567890abcdef1234567890abcdef12",
                capture_ref="docs/working/TASK-9999/evidence/capture.json",
            )
        self.assertIn("pbi-live-shadow", str(ctx.exception))

    def test_capture_rejects_missing_upstream_source(self):
        (self.root / self.source_ref).unlink()
        with self.assertRaises(collector.CollectorError) as ctx:
            self._collect_capture()
        self.assertIn("repository source does not exist", str(ctx.exception))

    def test_capture_rejects_symlinked_output_parent(self):
        base = (
            self.root
            / "docs/working/TASK-9999/evidence/pbi-live-shadow"
        )
        base.parent.mkdir(parents=True, exist_ok=True)
        outside = self.root / "outside"
        outside.mkdir()
        base.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(collector.CollectorError) as ctx:
            self._collect_capture()
        self.assertIn("symlink", str(ctx.exception))

    def test_existing_leaf_symlink_is_never_followed_or_replaced(self):
        target = self.root / self.capture_ref
        target.parent.mkdir(parents=True, exist_ok=True)
        outside = self.root / "outside.json"
        outside.write_text('{"sentinel":true}\n', encoding="utf-8")
        target.symlink_to(outside)

        with self.assertRaises(collector.CollectorError) as ctx:
            self._collect_capture()

        self.assertIn("safe regular file", str(ctx.exception))
        self.assertTrue(target.is_symlink())
        self.assertEqual(
            outside.read_text(encoding="utf-8"),
            '{"sentinel":true}\n',
        )

    def test_review_packet_revalidates_binding_and_attaches_no_oracle(self):
        self._collect_capture()
        self._write_bound_run_evidence()
        result = collector.collect_review_packet(
            repo_root=self.root,
            capture_ref=self.capture_ref,
            run_evidence_ref=self.run_evidence_ref,
            packet_ref=self.packet_ref,
        )
        target = self.root / self.packet_ref
        packet = json.loads(target.read_text(encoding="utf-8"))

        self.assertEqual(packet["mode"], "pbi_live_shadow_review_packet")
        self.assertEqual(packet["actual"]["admission_decision"], "no_action")
        self.assertTrue(packet["review_contract"]["independent_review_required"])
        self.assertFalse(packet["review_contract"]["oracle_attached"])
        self.assertFalse(packet["review_contract"]["expected_decision_attached"])
        self.assertFalse(packet["review_contract"]["quality_acceptance_decided"])
        self.assertFalse(packet["authority"]["pbi_write_allowed"])
        self.assertFalse(packet["authority"]["issue_write_allowed"])
        self.assertFalse(packet["authority"]["merge_allowed"])
        self.assertEqual(result["actual_admission_decision"], "no_action")
        self.assertTrue(result["review_required"])

    def test_review_packet_rejects_unbound_capture(self):
        self._collect_capture()
        self._write_bound_run_evidence(include_capture=False)
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_review_packet(
                repo_root=self.root,
                capture_ref=self.capture_ref,
                run_evidence_ref=self.run_evidence_ref,
                packet_ref=self.packet_ref,
            )
        self.assertIn("capture_ref", str(ctx.exception))

    def test_review_packet_reuses_identical_artifact(self):
        self._collect_capture()
        self._write_bound_run_evidence()
        first = collector.collect_review_packet(
            repo_root=self.root,
            capture_ref=self.capture_ref,
            run_evidence_ref=self.run_evidence_ref,
            packet_ref=self.packet_ref,
        )
        self.assertFalse(first["artifact_reused"])
        before = (self.root / self.packet_ref).read_bytes()
        retry = collector.collect_review_packet(
            repo_root=self.root,
            capture_ref=self.capture_ref,
            run_evidence_ref=self.run_evidence_ref,
            packet_ref=self.packet_ref,
        )
        self.assertTrue(retry["artifact_reused"])
        self.assertEqual((self.root / self.packet_ref).read_bytes(), before)

    def test_existing_different_capture_content_fails_closed(self):
        self._collect_capture()
        target = self.root / self.capture_ref
        value = json.loads(target.read_text(encoding="utf-8"))
        value["run_id"] = "run-tampered"
        target.write_text(
            json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            self._collect_capture()
        self.assertIn("different content", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
