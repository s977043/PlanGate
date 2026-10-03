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
from unittest import mock

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
        (self.root / "docs").mkdir()
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
        self.oracle_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/oracle.json"
        )
        self.case_artifact_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/admission-case.json"
        )
        self.payload_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/materialization-payload.json"
        )
        self.existing_work_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/existing-work.json"
        )
        self.materialization_oracle_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/materialization-oracle.json"
        )
        self.materialization_case_ref = (
            "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            "run-01/materialization-case.json"
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

    def _collect_packet(self):
        self._collect_capture()
        self._write_bound_run_evidence()
        return collector.collect_review_packet(
            repo_root=self.root,
            capture_ref=self.capture_ref,
            run_evidence_ref=self.run_evidence_ref,
            packet_ref=self.packet_ref,
        )

    def _write_oracle(self, *, expected="no_action", overrides=None):
        packet = json.loads(
            (self.root / self.packet_ref).read_text(encoding="utf-8")
        )
        oracle = {
            "schema_version": 1,
            "domain": "plangate.pbi-live-shadow-admission-oracle/v1",
            "case_ref": "LIVE-ADMISSION-001",
            "packet_ref": self.packet_ref,
            "packet_hash": collector.pm._canonical_json_hash(packet),
            "reviewed_source_ref": self.source_ref,
            "reviewed_source_sha256": collector._file_sha256(
                self.root / self.source_ref
            ),
            "expected_admission_decision": expected,
            "independent_review_asserted": True,
            "maker_actual_not_consulted_asserted": True,
        }
        if overrides:
            oracle.update(overrides)
        target = self.root / self.oracle_ref
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            json.dumps(oracle, ensure_ascii=False, indent=2, sort_keys=True)
            + "\n",
            encoding="utf-8",
        )
        return oracle

    def _prepare_materialize_admission_case(self):
        self.signal["statement"] = (
            "Observed delivery evidence requires follow-up work."
        )
        self.signal["disposition"] = "actionable"
        self.signal["candidate_problem"] = (
            "Observed delivery evidence should become a follow-up PBI."
        )
        self._collect_packet()
        self._write_oracle(expected="materialize")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )

    def _write_materialization_inputs(self, *, oracle_overrides=None):
        payload = {
            "task_id": "TASK-9999",
            "title": "Live shadow follow-up",
            "author": "ai",
            "application_timing": "follow_up",
            "target_layer": "delivery",
            "goal": "Preserve observed delivery evidence as follow-up work",
            "problem": (
                "Observed delivery evidence should become a follow-up PBI."
            ),
            "source_run_refs": [self.run_evidence_ref],
            "claims": [
                {
                    "id": "CLM-LIVE-001",
                    "text": (
                        "Observed delivery evidence requires follow-up work."
                    ),
                    "source_ref": self.source_ref,
                    "source_kind": "existing_behavior",
                    "claim_class": "observed",
                    "supports": "Problem",
                }
            ],
            "requirements": [],
            "acceptance_criteria": [],
            "in_scope": ["Create a future delivery follow-up proposal"],
            "out_of_scope": ["Mutate the current run"],
            "risks": ["Live shadow remains non-authoritative"],
            "unknowns": [],
            "assumptions": [],
            "harness_candidate_ref": None,
        }
        existing_work = []
        payload_path = self.root / self.payload_ref
        payload_path.parent.mkdir(parents=True, exist_ok=True)
        payload_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)
            + "\n",
            encoding="utf-8",
        )
        existing_path = self.root / self.existing_work_ref
        existing_path.write_text(
            json.dumps(existing_work, ensure_ascii=False, indent=2, sort_keys=True)
            + "\n",
            encoding="utf-8",
        )

        admission_case = json.loads(
            (self.root / self.case_artifact_ref).read_text(encoding="utf-8")
        )
        oracle = {
            "schema_version": 1,
            "domain": "plangate.pbi-live-shadow-materialization-oracle/v1",
            "case_ref": "LIVE-MATERIALIZATION-001",
            "admission_case_ref": self.case_artifact_ref,
            "admission_case_hash": collector.pm._canonical_json_hash(
                admission_case
            ),
            "payload_ref": self.payload_ref,
            "payload_hash": collector.pm._canonical_json_hash(payload),
            "existing_work_ref": self.existing_work_ref,
            "existing_work_hash": collector.pm._canonical_json_hash(
                existing_work
            ),
            "expected": {
                "decision": "create_new",
                "matched_ref": None,
                "readiness_status": "ready",
                "readiness_route": "future_run",
            },
            "independent_review_asserted": True,
            "maker_actual_not_consulted_asserted": True,
        }
        if oracle_overrides:
            oracle.update(oracle_overrides)
        oracle_path = self.root / self.materialization_oracle_ref
        oracle_path.write_text(
            json.dumps(oracle, ensure_ascii=False, indent=2, sort_keys=True)
            + "\n",
            encoding="utf-8",
        )
        return payload, existing_work, oracle

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
        self.assertEqual(
            result["run_evidence_handoff"]["evidence_refs"],
            [self.source_ref, self.capture_ref],
        )
        self.assertEqual(
            result["run_evidence_handoff"]["cli_args"],
            [
                "--evidence-ref",
                self.source_ref,
                "--evidence-ref",
                self.capture_ref,
            ],
        )
        self.assertEqual(
            result["run_evidence_handoff"]["runtime_head_sha"],
            "abcdef1234567890abcdef1234567890abcdef12",
        )
        self.assertEqual(
            result["run_evidence_handoff"]["capture_hash"],
            result["artifact_hash"],
        )
        self.assertTrue(
            result["run_evidence_handoff"]["source_sha256"].startswith(
                "sha256:"
            )
        )
        self.assertTrue(
            result["run_evidence_handoff"]["advisory_only"]
        )
        self.assertTrue(
            result["run_evidence_handoff"][
                "must_revalidate_after_run_evidence"
            ]
        )

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

    def test_capture_rejects_symlinked_upstream_parent(self):
        source = self.root / self.source_ref
        original = self.root / "real-delivery"
        original.mkdir()
        (original / "record.jsonl").write_text(
            '{"kind":"state","state":"MERGE_READY"}\n',
            encoding="utf-8",
        )
        source.unlink()
        source.parent.rmdir()
        source.parent.symlink_to(original, target_is_directory=True)

        with self.assertRaises(collector.CollectorError) as ctx:
            self._collect_capture()
        self.assertIn("symlink path component rejected", str(ctx.exception))

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
        self.assertEqual(
            packet["domain"],
            "plangate.pbi-live-shadow-review-packet/v1",
        )
        self.assertNotIn("actual", packet)
        self.assertTrue(packet["review_contract"]["independent_review_required"])
        self.assertTrue(packet["review_contract"]["review_from_upstream_source"])
        self.assertFalse(packet["review_contract"]["actual_decision_disclosed"])
        self.assertFalse(
            packet["review_contract"]["normalized_disposition_disclosed"]
        )
        self.assertFalse(packet["review_contract"]["oracle_attached"])
        self.assertFalse(packet["review_contract"]["expected_decision_attached"])
        self.assertTrue(packet["hashes"]["source_sha256"].startswith("sha256:"))
        self.assertFalse(packet["review_contract"]["quality_acceptance_decided"])
        self.assertTrue(packet["review_contract"]["packet_blind_to_actual"])
        self.assertFalse(
            packet["review_contract"]["capture_signal_blinding_enforced"]
        )
        self.assertFalse(packet["authority"]["pbi_write_allowed"])
        self.assertFalse(packet["authority"]["issue_write_allowed"])
        self.assertFalse(packet["authority"]["merge_allowed"])
        self.assertNotIn("actual_admission_decision", result)
        self.assertFalse(result["actual_decision_disclosed"])
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


    def test_reviewed_oracle_assembles_evaluator_compatible_case(self):
        self._collect_packet()
        self._write_oracle(expected="no_action")

        result = collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )
        self.assertFalse(result["artifact_reused"])
        self.assertFalse(
            result["review_assertions"]["oracle_authorship_verified"]
        )
        self.assertFalse(result["authority"]["pbi_write_allowed"])
        self.assertFalse(result["authority"]["quality_acceptance_decided"])

        case = json.loads(
            (self.root / self.case_artifact_ref).read_text(encoding="utf-8")
        )
        self.assertEqual(case["evidence_class"], "live_shadow")
        self.assertEqual(
            case["expected"]["admission_decision"],
            "no_action",
        )
        self.assertEqual(case["expected"]["oracle_ref"], self.oracle_ref)
        self.assertIn(self.packet_ref, case["evidence_refs"])
        self.assertNotIn(self.oracle_ref, case["evidence_refs"])
        self.assertEqual(
            case["expected"]["oracle_ref"],
            self.oracle_ref,
        )

        report = collector.pm.evaluate_admission_batch(
            [case],
            authority_root=self.root,
        )
        self.assertEqual(report["cases"][0]["status"], "match")
        self.assertEqual(report["rollout_quality"]["live_case_total"], 1)

    def test_reviewed_case_reuses_identical_artifact(self):
        self._collect_packet()
        self._write_oracle()
        first = collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )
        retry = collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )
        self.assertFalse(first["artifact_reused"])
        self.assertTrue(retry["artifact_reused"])

    def test_oracle_packet_hash_mismatch_fails_closed(self):
        self._collect_packet()
        self._write_oracle(
            overrides={"packet_hash": "sha256:" + "0" * 64}
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_admission_case(
                repo_root=self.root,
                packet_ref=self.packet_ref,
                oracle_ref=self.oracle_ref,
                case_artifact_ref=self.case_artifact_ref,
            )
        self.assertIn("packet hash mismatch", str(ctx.exception))

    def test_oracle_cannot_store_maker_actual(self):
        self._collect_packet()
        self._write_oracle(
            overrides={"actual_admission_decision": "no_action"}
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_admission_case(
                repo_root=self.root,
                packet_ref=self.packet_ref,
                oracle_ref=self.oracle_ref,
                case_artifact_ref=self.case_artifact_ref,
            )
        self.assertIn("maker actual must not be stored", str(ctx.exception))

    def test_oracle_must_stay_in_task_live_shadow_namespace(self):
        self._collect_packet()
        outside_ref = "docs/reviews/oracle.json"
        packet = json.loads(
            (self.root / self.packet_ref).read_text(encoding="utf-8")
        )
        outside = self.root / outside_ref
        outside.parent.mkdir(parents=True, exist_ok=True)
        outside.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "domain": "plangate.pbi-live-shadow-admission-oracle/v1",
                    "case_ref": "LIVE-OUTSIDE",
                    "packet_ref": self.packet_ref,
                    "packet_hash": collector.pm._canonical_json_hash(packet),
                    "reviewed_source_ref": self.source_ref,
                    "reviewed_source_sha256": collector._file_sha256(
                        self.root / self.source_ref
                    ),
                    "expected_admission_decision": "no_action",
                    "independent_review_asserted": True,
                    "maker_actual_not_consulted_asserted": True,
                },
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_admission_case(
                repo_root=self.root,
                packet_ref=self.packet_ref,
                oracle_ref=outside_ref,
                case_artifact_ref=self.case_artifact_ref,
            )
        self.assertIn("pbi-live-shadow", str(ctx.exception))

    def test_oracle_privacy_violation_is_rejected(self):
        self._collect_packet()
        self._write_oracle(
            overrides={"raw_transcript": "private session text"}
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_admission_case(
                repo_root=self.root,
                packet_ref=self.packet_ref,
                oracle_ref=self.oracle_ref,
                case_artifact_ref=self.case_artifact_ref,
            )
        self.assertIn("oracle privacy", str(ctx.exception))

    def test_source_change_after_blind_packet_invalidates_oracle_binding(self):
        self._collect_packet()
        self._write_oracle()
        (self.root / self.source_ref).write_text(
            '{"kind":"state","state":"CHANGED"}\n',
            encoding="utf-8",
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_admission_case(
                repo_root=self.root,
                packet_ref=self.packet_ref,
                oracle_ref=self.oracle_ref,
                case_artifact_ref=self.case_artifact_ref,
            )
        self.assertIn("current source hash mismatch", str(ctx.exception))


    def test_inventory_zero_cases_is_not_completion(self):
        inventory = collector.inventory_live_shadow_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["evaluated_case_total"], 0)
        self.assertFalse(inventory["has_tracked_live_evidence"])
        self.assertTrue(inventory["inventory_complete"])
        self.assertEqual(
            inventory["rollout_quality"]["live_case_total"],
            0,
        )
        self.assertFalse(
            inventory["rollout_quality"]["quality_review_complete"]
        )
        self.assertFalse(
            inventory["verification_boundary"]["runtime_execution_verified"]
        )
        self.assertFalse(
            inventory["verification_boundary"]["source_preexistence_verified"]
        )
        self.assertFalse(
            inventory["coverage"]["representative_coverage_claim_allowed"]
        )
        self.assertFalse(
            inventory["coverage"]["admission_decision_coverage_complete"]
        )
        self.assertEqual(
            inventory["coverage"]["missing_admission_decisions"],
            ["discover_more", "materialize", "no_action"],
        )
        self.assertEqual(
            inventory["collection_gaps"],
            [
                "tracked_live_case_missing",
                "admission_decision_missing:discover_more",
                "admission_decision_missing:materialize",
                "admission_decision_missing:no_action",
            ],
        )
        self.assertFalse(
            inventory["coverage"]["source_kind_coverage_requirement_defined"]
        )
        self.assertFalse(
            inventory["materialization_rollout_boundary"][
                "covered_by_this_inventory"
            ]
        )
        self.assertTrue(
            inventory["materialization_rollout_boundary"][
                "materialization_case_inventory_required"
            ]
        )
        self.assertFalse(inventory["authority"]["write_allowed"])
        self.assertFalse(
            inventory["authority"]["quality_acceptance_decided"]
        )

    def test_inventory_revalidates_tracked_live_case(self):
        self._collect_packet()
        self._write_oracle(expected="no_action")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )

        inventory = collector.inventory_live_shadow_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 1)
        self.assertEqual(inventory["evaluated_case_total"], 1)
        self.assertEqual(inventory["invalid_case_total"], 0)
        self.assertTrue(inventory["has_tracked_live_evidence"])
        self.assertTrue(inventory["inventory_complete"])
        self.assertEqual(
            inventory["coverage"]["observed_admission_decisions"],
            ["no_action"],
        )
        self.assertEqual(
            inventory["coverage"]["observed_source_kinds"],
            ["existing_behavior"],
        )
        self.assertEqual(
            inventory["coverage"]["missing_admission_decisions"],
            ["discover_more", "materialize"],
        )
        self.assertEqual(
            inventory["collection_gaps"],
            [
                "admission_decision_missing:discover_more",
                "admission_decision_missing:materialize",
            ],
        )
        self.assertFalse(
            inventory["coverage"]["admission_decision_coverage_complete"]
        )
        self.assertEqual(
            inventory["rollout_quality"]["live_case_total"],
            1,
        )
        self.assertEqual(
            inventory["rollout_quality"]["materialize_false_positive_rate"],
            0.0,
        )
        self.assertIsNone(
            inventory["rollout_quality"]["materialize_false_negative_rate"]
        )

    def test_inventory_keeps_invalid_case_visible(self):
        path = (
            self.root
            / "docs/working/TASK-9998/evidence/pbi-live-shadow/"
            / "run-01/admission-case.json"
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("{not-json}\n", encoding="utf-8")

        inventory = collector.inventory_live_shadow_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["invalid_case_total"], 1)
        self.assertFalse(inventory["inventory_complete"])
        self.assertIn(
            "invalid_case_artifacts_present",
            inventory["collection_gaps"],
        )
        self.assertIn(
            "tracked_live_case_missing",
            inventory["collection_gaps"],
        )
        self.assertIn(
            "invalid JSON",
            inventory["invalid_case_artifacts"][0]["errors"][0],
        )

    def test_inventory_ignores_historical_case_outside_live_namespace(self):
        path = self.root / "docs/working/ai-loop-runs/admission-case.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "evidence_class": "live_shadow",
                    "case_ref": "FAKE-HISTORICAL",
                }
            )
            + "\n",
            encoding="utf-8",
        )
        inventory = collector.inventory_live_shadow_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["discovered_case_artifacts"], [])
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertFalse(
            inventory["verification_boundary"]["historical_promoted_to_live"]
        )

    def test_inventory_rejects_symlink_case_artifact(self):
        target = self.root / "outside-case.json"
        target.write_text("{}\n", encoding="utf-8")
        link = (
            self.root
            / "docs/working/TASK-9998/evidence/pbi-live-shadow/"
            / "run-01/admission-case.json"
        )
        link.parent.mkdir(parents=True, exist_ok=True)
        link.symlink_to(target)

        inventory = collector.inventory_live_shadow_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["invalid_case_total"], 1)
        self.assertIn(
            "symlink path component rejected",
            inventory["invalid_case_artifacts"][0]["errors"][0],
        )



    def test_inventory_rejects_cross_task_case_copy(self):
        self._collect_packet()
        self._write_oracle(expected="no_action")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )
        original = self.root / self.case_artifact_ref
        copied = (
            self.root
            / "docs/working/TASK-9998/evidence/pbi-live-shadow/"
            / "run-01/admission-case.json"
        )
        copied.parent.mkdir(parents=True, exist_ok=True)
        copied.write_bytes(original.read_bytes())
        original.unlink()

        inventory = collector.inventory_live_shadow_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["invalid_case_total"], 1)
        errors = " ".join(inventory["invalid_case_artifacts"][0]["errors"])
        self.assertIn("TASK-9998", errors)
        self.assertIn("pbi-live-shadow", errors)

    def test_inventory_rejects_all_duplicate_logical_case_ids(self):
        self._collect_packet()
        self._write_oracle(expected="no_action")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )

        original = self.root / self.case_artifact_ref
        duplicate = (
            self.root
            / "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            / "run-02/admission-case.json"
        )
        duplicate.parent.mkdir(parents=True, exist_ok=True)
        duplicate.write_bytes(original.read_bytes())

        inventory = collector.inventory_live_shadow_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["invalid_case_total"], 2)
        self.assertFalse(inventory["inventory_complete"])
        for item in inventory["invalid_case_artifacts"]:
            self.assertIn(
                "duplicate logical case_ref",
                " ".join(item["errors"]),
            )
        self.assertTrue(
            inventory["verification_boundary"][
                "duplicate_logical_case_ids_rejected"
            ]
        )



    def test_reviewed_materialization_case_is_evaluator_compatible(self):
        self._prepare_materialize_admission_case()
        self._write_materialization_inputs()

        result = collector.collect_reviewed_materialization_case(
            repo_root=self.root,
            admission_case_ref=self.case_artifact_ref,
            payload_ref=self.payload_ref,
            existing_work_ref=self.existing_work_ref,
            oracle_ref=self.materialization_oracle_ref,
            case_artifact_ref=self.materialization_case_ref,
        )
        self.assertFalse(result["artifact_reused"])
        self.assertTrue(
            result["review_assertions"][
                "admission_materialize_match_revalidated"
            ]
        )
        self.assertFalse(
            result["review_assertions"]["oracle_authorship_verified"]
        )
        self.assertFalse(result["authority"]["pbi_write_allowed"])
        self.assertFalse(result["authority"]["quality_acceptance_decided"])

        case = json.loads(
            (self.root / self.materialization_case_ref).read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(case["evidence_class"], "live_shadow")
        self.assertIn(self.case_artifact_ref, case["evidence_refs"])
        self.assertIn(self.payload_ref, case["evidence_refs"])
        self.assertIn(self.existing_work_ref, case["evidence_refs"])
        self.assertNotIn(
            self.materialization_oracle_ref,
            case["evidence_refs"],
        )
        self.assertEqual(
            case["expected"]["oracle_ref"],
            self.materialization_oracle_ref,
        )

        report = collector.pm.evaluate_shadow_batch(
            [case],
            authority_root=self.root,
        )
        self.assertEqual(report["cases"][0]["status"], "match")
        self.assertEqual(
            report["cases"][0]["actual_decision"],
            "create_new",
        )
        self.assertEqual(report["rollout_quality"]["live_case_total"], 1)
        self.assertEqual(
            report["rollout_quality"]["duplicate_false_positive_rate"],
            0.0,
        )
        self.assertIsNone(
            report["rollout_quality"]["duplicate_false_negative_rate"]
        )

    def test_materialization_case_requires_reviewed_materialize_admission(self):
        self._collect_packet()
        self._write_oracle(expected="no_action")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )
        self._write_materialization_inputs()

        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_materialization_case(
                repo_root=self.root,
                admission_case_ref=self.case_artifact_ref,
                payload_ref=self.payload_ref,
                existing_work_ref=self.existing_work_ref,
                oracle_ref=self.materialization_oracle_ref,
                case_artifact_ref=self.materialization_case_ref,
            )
        self.assertIn("reviewed materialize match required", str(ctx.exception))

    def test_materialization_oracle_payload_hash_mismatch_fails_closed(self):
        self._prepare_materialize_admission_case()
        self._write_materialization_inputs(
            oracle_overrides={"payload_hash": "sha256:" + "0" * 64}
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_materialization_case(
                repo_root=self.root,
                admission_case_ref=self.case_artifact_ref,
                payload_ref=self.payload_ref,
                existing_work_ref=self.existing_work_ref,
                oracle_ref=self.materialization_oracle_ref,
                case_artifact_ref=self.materialization_case_ref,
            )
        self.assertIn("payload_hash", str(ctx.exception))

    def test_materialization_oracle_cannot_store_maker_actual(self):
        self._prepare_materialize_admission_case()
        self._write_materialization_inputs(
            oracle_overrides={"actual_materialization_decision": "create_new"}
        )
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.collect_reviewed_materialization_case(
                repo_root=self.root,
                admission_case_ref=self.case_artifact_ref,
                payload_ref=self.payload_ref,
                existing_work_ref=self.existing_work_ref,
                oracle_ref=self.materialization_oracle_ref,
                case_artifact_ref=self.materialization_case_ref,
            )
        self.assertIn("maker actual must not be stored", str(ctx.exception))


    def test_materialization_inventory_zero_cases_is_not_completion(self):
        inventory = collector.inventory_live_materialization_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["evaluated_case_total"], 0)
        self.assertFalse(inventory["has_tracked_live_evidence"])
        self.assertTrue(inventory["inventory_complete"])
        self.assertFalse(
            inventory["coverage"]["materialization_decision_coverage_complete"]
        )
        self.assertEqual(
            inventory["coverage"]["missing_materialization_decisions"],
            ["create_new", "link_only", "update_existing"],
        )
        self.assertEqual(
            inventory["collection_gaps"],
            [
                "tracked_materialization_case_missing",
                "materialization_decision_missing:create_new",
                "materialization_decision_missing:link_only",
                "materialization_decision_missing:update_existing",
            ],
        )
        self.assertEqual(
            inventory["rollout_quality"]["live_case_total"],
            0,
        )
        self.assertFalse(
            inventory["rollout_quality"]["quality_review_complete"]
        )
        self.assertFalse(
            inventory["verification_boundary"]["runtime_execution_verified"]
        )
        self.assertFalse(inventory["authority"]["write_allowed"])

    def test_materialization_inventory_revalidates_tracked_case(self):
        self._prepare_materialize_admission_case()
        self._write_materialization_inputs()
        collector.collect_reviewed_materialization_case(
            repo_root=self.root,
            admission_case_ref=self.case_artifact_ref,
            payload_ref=self.payload_ref,
            existing_work_ref=self.existing_work_ref,
            oracle_ref=self.materialization_oracle_ref,
            case_artifact_ref=self.materialization_case_ref,
        )

        inventory = collector.inventory_live_materialization_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 1)
        self.assertEqual(inventory["evaluated_case_total"], 1)
        self.assertEqual(inventory["invalid_case_total"], 0)
        self.assertEqual(
            inventory["coverage"]["observed_materialization_decisions"],
            ["create_new"],
        )
        self.assertEqual(
            inventory["coverage"]["missing_materialization_decisions"],
            ["link_only", "update_existing"],
        )
        self.assertEqual(
            inventory["collection_gaps"],
            [
                "materialization_decision_missing:link_only",
                "materialization_decision_missing:update_existing",
            ],
        )
        self.assertEqual(
            inventory["rollout_quality"]["duplicate_false_positive_rate"],
            0.0,
        )
        self.assertIsNone(
            inventory["rollout_quality"]["duplicate_false_negative_rate"]
        )
        self.assertFalse(
            inventory["coverage"]["representative_coverage_claim_allowed"]
        )

    def test_materialization_inventory_detects_payload_drift(self):
        self._prepare_materialize_admission_case()
        self._write_materialization_inputs()
        collector.collect_reviewed_materialization_case(
            repo_root=self.root,
            admission_case_ref=self.case_artifact_ref,
            payload_ref=self.payload_ref,
            existing_work_ref=self.existing_work_ref,
            oracle_ref=self.materialization_oracle_ref,
            case_artifact_ref=self.materialization_case_ref,
        )
        payload = json.loads(
            (self.root / self.payload_ref).read_text(encoding="utf-8")
        )
        payload["goal"] = "tampered after reviewed case assembly"
        (self.root / self.payload_ref).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)
            + "\n",
            encoding="utf-8",
        )

        inventory = collector.inventory_live_materialization_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["invalid_case_total"], 1)
        self.assertIn(
            "payload_hash",
            " ".join(inventory["invalid_case_artifacts"][0]["errors"]),
        )
        self.assertIn(
            "invalid_materialization_case_artifacts_present",
            inventory["collection_gaps"],
        )

    def test_materialization_inventory_rejects_duplicate_logical_case_ids(self):
        self._prepare_materialize_admission_case()
        self._write_materialization_inputs()
        collector.collect_reviewed_materialization_case(
            repo_root=self.root,
            admission_case_ref=self.case_artifact_ref,
            payload_ref=self.payload_ref,
            existing_work_ref=self.existing_work_ref,
            oracle_ref=self.materialization_oracle_ref,
            case_artifact_ref=self.materialization_case_ref,
        )
        original = self.root / self.materialization_case_ref
        duplicate = (
            self.root
            / "docs/working/TASK-9999/evidence/pbi-live-shadow/"
            / "run-02/materialization-case.json"
        )
        duplicate.parent.mkdir(parents=True, exist_ok=True)
        duplicate.write_bytes(original.read_bytes())

        inventory = collector.inventory_live_materialization_cases(
            repo_root=self.root
        )
        self.assertEqual(inventory["tracked_live_case_total"], 0)
        self.assertEqual(inventory["invalid_case_total"], 2)
        for item in inventory["invalid_case_artifacts"]:
            self.assertIn(
                "duplicate logical case_ref",
                " ".join(item["errors"]),
            )
        self.assertTrue(
            inventory["verification_boundary"][
                "duplicate_logical_case_ids_rejected"
            ]
        )



    def test_collection_plan_zero_cases_exposes_real_run_targets(self):
        plan = collector.plan_live_shadow_collection(
            repo_root=self.root
        )
        self.assertEqual(plan["observation_gap_count"], 6)
        self.assertEqual(
            [(item["stage"], item["decision"]) for item in plan["observation_gaps"]],
            [
                ("admission", "materialize"),
                ("admission", "no_action"),
                ("admission", "discover_more"),
                ("materialization", "create_new"),
                ("materialization", "update_existing"),
                ("materialization", "link_only"),
            ],
        )
        self.assertTrue(
            all(
                item["observation_mode"] == "opportunistic_real_run_only"
                for item in plan["observation_gaps"]
            )
        )
        admission_items = [
            item for item in plan["observation_gaps"]
            if item["stage"] == "admission"
        ]
        materialization_items = [
            item for item in plan["observation_gaps"]
            if item["stage"] == "materialization"
        ]
        self.assertTrue(
            all(item["collector_path_available"] for item in admission_items)
        )
        self.assertTrue(
            all(
                item["prerequisites"] == []
                and item["prerequisites_satisfied"]
                for item in admission_items
            )
        )
        self.assertTrue(
            all(
                not item["collector_path_available"]
                and item["prerequisites"] == [
                    "reviewed_admission_materialize_case"
                ]
                and not item["prerequisites_satisfied"]
                for item in materialization_items
            )
        )
        self.assertIn(
            "tracked_admission_live_case_missing",
            plan["blockers"],
        )
        self.assertIn(
            "tracked_materialization_live_case_missing",
            plan["blockers"],
        )
        boundary = plan["policy_boundary"]
        self.assertTrue(boundary["opportunistic_observation_only"])
        self.assertFalse(
            boundary["synthetic_case_generation_for_coverage_allowed"]
        )
        self.assertFalse(boundary["historical_relabeling_allowed"])
        self.assertFalse(boundary["decision_coverage_quota_defined"])
        self.assertFalse(
            boundary["source_kind_coverage_requirement_defined"]
        )
        self.assertFalse(
            boundary["representative_coverage_claim_allowed"]
        )
        self.assertFalse(
            boundary["coverage_complete_implies_representative"]
        )
        self.assertFalse(boundary["observation_gap_is_quota"])
        self.assertFalse(
            boundary["observation_gap_is_case_generation_instruction"]
        )
        self.assertEqual(
            boundary["coverage_gap_basis"],
            "reviewed_expected_decisions",
        )
        self.assertFalse(
            boundary["maker_actual_counts_as_ground_truth_coverage"]
        )
        self.assertFalse(boundary["runtime_execution_verified"])
        self.assertFalse(
            boundary["real_runtime_observation_available_verified"]
        )
        self.assertTrue(
            all(
                item["real_runtime_observation_available"] is None
                for item in plan["observation_gaps"]
            )
        )
        self.assertEqual(
            plan["collector_path_available_gap_count"],
            3,
        )
        self.assertFalse(plan["collection_execution_blocked"])
        self.assertEqual(plan["collection_execution_status"], "available")
        self.assertEqual(
            plan["completion_blockers"],
            plan["blockers"],
        )
        self.assertEqual(
            plan["blocker_semantics"],
            "rollout_completion_not_collection_execution",
        )
        self.assertFalse(boundary["quality_acceptance_decided"])
        self.assertFalse(plan["authority"]["write_allowed"])

    def test_collection_plan_no_gaps_is_not_blocked(self):
        admission = {
            "tracked_live_case_total": 3,
            "invalid_case_total": 0,
            "has_tracked_live_evidence": True,
            "coverage": {
                "missing_reviewed_admission_decisions": [],
                "reviewed_expected_admission_decisions": [
                    "discover_more",
                    "materialize",
                    "no_action",
                ],
                "observed_admission_decisions": [
                    "discover_more",
                    "materialize",
                    "no_action",
                ],
                "observed_source_kinds": ["existing_behavior"],
            },
        }
        materialization = {
            "tracked_live_case_total": 3,
            "invalid_case_total": 0,
            "has_tracked_live_evidence": True,
            "coverage": {
                "missing_reviewed_materialization_decisions": [],
                "reviewed_expected_materialization_decisions": [
                    "create_new",
                    "link_only",
                    "update_existing",
                ],
                "observed_materialization_decisions": [
                    "create_new",
                    "link_only",
                    "update_existing",
                ],
            },
        }
        with mock.patch.object(
            collector,
            "inventory_live_shadow_cases",
            return_value=admission,
        ), mock.patch.object(
            collector,
            "inventory_live_materialization_cases",
            return_value=materialization,
        ):
            plan = collector.plan_live_shadow_collection(repo_root=self.root)

        self.assertEqual(plan["observation_gaps"], [])
        self.assertEqual(plan["observation_gap_count"], 0)
        self.assertEqual(plan["collector_path_available_gap_count"], 0)
        self.assertEqual(plan["collection_execution_status"], "not_needed")
        self.assertFalse(plan["collection_execution_blocked"])
        self.assertEqual(plan["completion_blockers"], [])

    def test_collection_plan_removes_only_observed_admission_gap(self):
        self._collect_packet()
        self._write_oracle(expected="no_action")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )

        plan = collector.plan_live_shadow_collection(
            repo_root=self.root
        )
        admission_targets = [
            item["decision"]
            for item in plan["observation_gaps"]
            if item["stage"] == "admission"
        ]
        self.assertEqual(
            admission_targets,
            ["materialize", "discover_more"],
        )
        self.assertEqual(
            plan["inventory_snapshot"]["admission"]["observed_actual_decisions"],
            ["no_action"],
        )
        self.assertEqual(
            plan["inventory_snapshot"]["admission"]["reviewed_expected_decisions"],
            ["no_action"],
        )
        self.assertEqual(
            plan["inventory_snapshot"]["admission"]["missing_reviewed_decisions"],
            ["discover_more", "materialize"],
        )
        self.assertNotIn(
            "tracked_admission_live_case_missing",
            plan["blockers"],
        )
        self.assertIn(
            "tracked_materialization_live_case_missing",
            plan["blockers"],
        )
        materialization_targets = [
            item for item in plan["observation_gaps"]
            if item["stage"] == "materialization"
        ]
        self.assertTrue(
            all(
                not item["collector_path_available"]
                and not item["prerequisites_satisfied"]
                for item in materialization_targets
            )
        )

    def test_collection_plan_unlocks_materialization_targets_after_reviewed_materialize(self):
        self._prepare_materialize_admission_case()

        plan = collector.plan_live_shadow_collection(
            repo_root=self.root
        )
        self.assertIn(
            "materialize",
            plan["inventory_snapshot"]["admission"]["reviewed_expected_decisions"],
        )
        materialization_targets = [
            item for item in plan["observation_gaps"]
            if item["stage"] == "materialization"
        ]
        self.assertEqual(len(materialization_targets), 3)
        self.assertTrue(
            all(
                item["collector_path_available"]
                and item["prerequisites_satisfied"]
                for item in materialization_targets
            )
        )
        self.assertFalse(
            plan["policy_boundary"]["observation_gap_is_quota"]
        )
        self.assertFalse(
            plan["policy_boundary"][
                "observation_gap_is_case_generation_instruction"
            ]
        )

    def test_collection_plan_does_not_count_maker_actual_as_ground_truth(self):
        self.signal.update(
            {
                "statement": "Observed signal looks actionable to the maker.",
                "disposition": "actionable",
                "candidate_problem": "Maker would materialize this signal.",
            }
        )
        self._collect_packet()
        self._write_oracle(expected="no_action")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )

        plan = collector.plan_live_shadow_collection(
            repo_root=self.root
        )
        snapshot = plan["inventory_snapshot"]["admission"]
        self.assertEqual(
            snapshot["observed_actual_decisions"],
            ["materialize"],
        )
        self.assertEqual(
            snapshot["reviewed_expected_decisions"],
            ["no_action"],
        )
        self.assertIn(
            "materialize",
            snapshot["missing_reviewed_decisions"],
        )
        admission_targets = [
            item["decision"]
            for item in plan["observation_gaps"]
            if item["stage"] == "admission"
        ]
        self.assertIn("materialize", admission_targets)
        materialization_targets = [
            item for item in plan["observation_gaps"]
            if item["stage"] == "materialization"
        ]
        self.assertTrue(
            all(
                not item["collector_path_available"]
                and not item["prerequisites_satisfied"]
                for item in materialization_targets
            )
        )
        self.assertFalse(
            plan["policy_boundary"][
                "maker_actual_counts_as_ground_truth_coverage"
            ]
        )

    def test_collection_plan_surfaces_invalid_artifact_blocker(self):
        path = (
            self.root
            / "docs/working/TASK-9998/evidence/pbi-live-shadow/"
            / "run-01/admission-case.json"
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("{not-json}\n", encoding="utf-8")

        plan = collector.plan_live_shadow_collection(
            repo_root=self.root
        )
        self.assertIn(
            "invalid_admission_case_artifacts_present",
            plan["blockers"],
        )
        self.assertEqual(
            plan["inventory_snapshot"]["admission"]["invalid_case_total"],
            1,
        )
        self.assertFalse(
            plan["policy_boundary"]["representative_coverage_claim_allowed"]
        )



    def _completion_context(self, **overrides):
        context = {
            "latest_full_test_green": True,
            "design_dependency_finalized": True,
            "generalization_claim_required": False,
            "representative_live_evidence_review_ref": None,
            "quality_review_ref": None,
            "isolated_generalization_review_ref": None,
        }
        context.update(overrides)
        return context

    def test_completion_status_prioritizes_repository_failure(self):
        status = collector.assess_live_shadow_completion(
            repo_root=self.root,
            context=self._completion_context(
                latest_full_test_green=False,
                design_dependency_finalized=False,
            ),
        )
        self.assertEqual(
            status["next_action"],
            "fix_repository_or_evidence_integrity",
        )
        self.assertIn(
            "latest_full_repository_test_not_green",
            status["blockers"]["implementation"],
        )
        self.assertFalse(status["status"]["rollout_complete"])
        self.assertFalse(
            status["status"]["automatic_write_activation_allowed"]
        )

    def test_completion_status_distinguishes_dependency_from_evidence(self):
        status = collector.assess_live_shadow_completion(
            repo_root=self.root,
            context=self._completion_context(
                design_dependency_finalized=False,
            ),
        )
        self.assertEqual(
            status["next_action"],
            "finalize_design_dependency",
        )
        self.assertIn(
            "design_dependency_not_finalized",
            status["blockers"]["dependency"],
        )
        self.assertIn(
            "real_live_admission_evidence_not_tracked",
            status["blockers"]["evidence"],
        )

    def test_completion_status_routes_to_real_live_collection(self):
        status = collector.assess_live_shadow_completion(
            repo_root=self.root,
            context=self._completion_context(),
        )
        self.assertEqual(
            status["next_action"],
            "collect_opportunistic_real_live_evidence",
        )
        self.assertEqual(
            status["repository_evidence"][
                "admission_tracked_live_case_total"
            ],
            0,
        )
        self.assertEqual(
            status["repository_evidence"][
                "materialization_tracked_live_case_total"
            ],
            0,
        )
        self.assertFalse(
            status["policy_boundary"][
                "synthetic_case_generation_for_completion_allowed"
            ]
        )
        self.assertFalse(
            status["policy_boundary"][
                "historical_relabeling_for_completion_allowed"
            ]
        )

    def test_completion_status_never_self_certifies_rollout_complete(self):
        self._collect_packet()
        self._write_oracle(expected="materialize")
        collector.collect_reviewed_admission_case(
            repo_root=self.root,
            packet_ref=self.packet_ref,
            oracle_ref=self.oracle_ref,
            case_artifact_ref=self.case_artifact_ref,
        )

        # A tracked admission case alone is still insufficient, and even a
        # future fully populated repository cannot self-authorize rollout.
        status = collector.assess_live_shadow_completion(
            repo_root=self.root,
            context=self._completion_context(
                representative_live_evidence_review_ref=(
                    "docs/working/TASK-9999/evidence/pbi-live-shadow/"
                    "representative-review.md"
                ),
                quality_review_ref=(
                    "docs/working/TASK-9999/evidence/pbi-live-shadow/"
                    "quality-review.md"
                ),
            ),
        )
        self.assertFalse(status["status"]["rollout_complete"])
        self.assertFalse(
            status["status"]["rollout_completion_machine_decidable"]
        )
        self.assertFalse(
            status["policy_boundary"]["machine_completion_decision_allowed"]
        )
        self.assertFalse(
            status["policy_boundary"]["machine_write_activation_allowed"]
        )
        self.assertFalse(
            status["caller_assertions"]["assertions_independently_verified"]
        )

    def test_completion_context_requires_boolean_contract(self):
        with self.assertRaises(collector.CollectorError) as ctx:
            collector.assess_live_shadow_completion(
                repo_root=self.root,
                context={
                    "latest_full_test_green": "yes",
                    "design_dependency_finalized": True,
                    "generalization_claim_required": False,
                },
            )
        self.assertIn(
            "latest_full_test_green: boolean required",
            str(ctx.exception),
        )



if __name__ == "__main__":
    unittest.main()
