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

import copy
import json
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))

from ratchet import (  # noqa: E402
    RatchetError,
    canonical_digest,
    evaluate_verification_skipped,
    manifest_ref,
)


class RatchetVerticalSliceTests(unittest.TestCase):
    def setUp(self):
        path = (
            REPO
            / "tests"
            / "fixtures"
            / "ai-loop-v2"
            / "ratchet"
            / "verification-skipped.json"
        )
        self.base = json.loads(path.read_text(encoding="utf-8"))

    def evaluate(self, value=None):
        bundle = copy.deepcopy(value or self.base)
        plan = copy.deepcopy(self.base["sealed_evaluation_plan"])
        bundle.pop("sealed_evaluation_plan", None)
        bundle.pop("expected", None)
        return evaluate_verification_skipped(bundle, plan)

    def test_happy_path_proves_full_ratchet_provenance(self):
        result = self.evaluate()
        experiment = result["experiment_result"]
        promotion = result["promotion_decision"]
        expected = self.base["expected"]
        self.assertEqual(experiment["result"], expected["experiment_result"])
        self.assertEqual(promotion["decision"], expected["promotion_decision"])
        self.assertFalse(promotion["production_promotion_executed"])
        self.assertEqual(
            experiment["activation"]["observed_level"], expected["activation"]
        )
        self.assertEqual(
            experiment["observed_changed_paths"], expected["changed_paths"]
        )
        self.assertEqual(
            experiment["prevention_evidence"]["known_bad"]["baseline"]["outcome"],
            "MERGE_READY",
        )
        self.assertEqual(
            experiment["prevention_evidence"]["known_bad"]["candidate"]["outcome"],
            "BLOCKED",
        )
        self.assertEqual(
            experiment["prevention_evidence"]["negative_control"]["candidate"]["outcome"],
            "MERGE_READY",
        )
        self.assertEqual(
            promotion["experiment_result_ref"], canonical_digest(experiment)
        )
        self.assertEqual(
            promotion["candidate_manifest_ref"], experiment["candidate_manifest_ref"]
        )
        self.assertEqual(
            promotion["source_failure_instance_refs"],
            self.base["candidate"]["source"]["failure_instance_refs"],
        )
        self.assertEqual(
            experiment["metrics"]["recurrence_observation"],
            expected["recurrence"],
        )

    def test_candidate_cannot_choose_its_evaluation_plan(self):
        value = copy.deepcopy(self.base)
        fake_plan = copy.deepcopy(value["sealed_evaluation_plan"])
        fake_plan["required_activation"] = "fired"
        value["candidate"]["evaluation_plan_digest"] = canonical_digest(fake_plan)
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "INCONCLUSIVE")
        self.assertIn(
            "EVALUATION_PLAN_DIGEST_MISMATCH",
            result["experiment_result"]["reason_codes"],
        )

    def test_sealed_fixture_mutation_fails_closed(self):
        value = copy.deepcopy(self.base)
        value["fixtures"]["incident-verification-skipped-v1"]["verification_present"] = True
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "FAIL")
        self.assertEqual(
            result["experiment_result"]["policy_verdict"], "HUMAN_REQUIRED"
        )
        self.assertIn(
            "SEALED_FIXTURE_MUTATION",
            result["experiment_result"]["reason_codes"],
        )

    def test_source_failure_payload_tamper_is_inconclusive(self):
        value = copy.deepcopy(self.base)
        value["sources"][0]["failure_record"]["observation"] += " tampered"
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "INCONCLUSIVE")
        self.assertIn(
            "SOURCE_FAILURE_BINDING",
            result["experiment_result"]["reason_codes"],
        )

    def test_source_set_digest_self_attestation_is_rejected(self):
        value = copy.deepcopy(self.base)
        value["candidate"]["source"]["pattern_snapshot"]["source_set_digest"] = (
            "sha256:" + "0" * 64
        )
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "INCONCLUSIVE")
        self.assertIn(
            "SOURCE_SET_DIGEST", result["experiment_result"]["reason_codes"]
        )

    def test_candidate_manifest_binding_is_recomputed(self):
        value = copy.deepcopy(self.base)
        value["candidate_manifest_ref"] = "sha256:" + "0" * 64
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "INCONCLUSIVE")
        self.assertIn(
            "CANDIDATE_MANIFEST_BINDING",
            result["experiment_result"]["reason_codes"],
        )

    def test_actual_delta_outside_allowed_paths_fails_closed(self):
        value = copy.deepcopy(self.base)
        component = value["candidate_manifest"]["components"][-1]
        component["paths"] = ["outside/forbidden.json"]
        value["candidate_manifest_ref"] = manifest_ref(
            value["candidate_manifest"]
        )
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "FAIL")
        self.assertEqual(
            result["experiment_result"]["policy_verdict"], "HUMAN_REQUIRED"
        )
        self.assertIn(
            "ACTUAL_DELTA_OUTSIDE_ALLOWED_PATHS",
            result["experiment_result"]["reason_codes"],
        )

    def test_protected_evaluation_surface_change_fails_closed(self):
        value = copy.deepcopy(self.base)
        value["candidate"]["target"]["allowed_paths"].append(
            "tests/fixtures/ai-loop-v2/ratchet/**"
        )
        component = value["candidate_manifest"]["components"][-1]
        component["paths"] = [
            "tests/fixtures/ai-loop-v2/ratchet/verification-skipped.json"
        ]
        value["candidate_manifest_ref"] = manifest_ref(
            value["candidate_manifest"]
        )
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "FAIL")
        self.assertIn(
            "PROTECTED_AUTHORITY_CHANGED",
            result["experiment_result"]["reason_codes"],
        )

    def test_activation_below_influenced_decision_is_inconclusive(self):
        value = copy.deepcopy(self.base)
        value["candidate_manifest"]["components"][-1]["enabled"] = False
        value["candidate_manifest_ref"] = manifest_ref(
            value["candidate_manifest"]
        )
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "INCONCLUSIVE")
        self.assertIn(
            "ACTIVATION_INSUFFICIENT",
            result["experiment_result"]["reason_codes"],
        )

    def test_baseline_miss_must_be_reproduced(self):
        value = copy.deepcopy(self.base)
        baseline_component = copy.deepcopy(
            value["candidate_manifest"]["components"][-1]
        )
        baseline_component["content_sha"] = "sha256:" + "9" * 64
        value["baseline_manifest"]["components"].append(baseline_component)
        baseline_ref = manifest_ref(value["baseline_manifest"])
        value["sealed_evaluation_plan"]["baseline_manifest_ref"] = baseline_ref
        value["candidate"]["baseline_manifest_ref"] = baseline_ref
        value["candidate"]["evaluation_plan_digest"] = canonical_digest(
            value["sealed_evaluation_plan"]
        )
        bundle = copy.deepcopy(value)
        trusted = bundle.pop("sealed_evaluation_plan")
        bundle.pop("expected", None)
        result = evaluate_verification_skipped(bundle, trusted)
        self.assertEqual(result["experiment_result"]["result"], "INCONCLUSIVE")
        self.assertIn(
            "BASELINE_MISS_NOT_REPRODUCED",
            result["experiment_result"]["reason_codes"],
        )

    def test_known_bad_not_stopped_is_fail(self):
        value = copy.deepcopy(self.base)
        value["candidate_manifest"]["components"][-1]["enforce_missing"] = False
        value["candidate_manifest_ref"] = manifest_ref(
            value["candidate_manifest"]
        )
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "FAIL")
        self.assertIn(
            "KNOWN_BAD_NOT_STOPPED",
            result["experiment_result"]["reason_codes"],
        )

    def test_negative_control_regression_is_fail(self):
        value = copy.deepcopy(self.base)
        value["candidate_manifest"]["components"][-1]["block_when_present"] = True
        value["candidate_manifest_ref"] = manifest_ref(
            value["candidate_manifest"]
        )
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "FAIL")
        self.assertIn(
            "NEGATIVE_CONTROL_REGRESSION",
            result["experiment_result"]["reason_codes"],
        )

    def test_missing_manifest_is_inconclusive(self):
        value = copy.deepcopy(self.base)
        value["candidate_manifest"] = None
        value["candidate_manifest_ref"] = None
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "INCONCLUSIVE")
        self.assertIn(
            "MANIFEST_MISSING", result["experiment_result"]["reason_codes"]
        )

    def test_occurrence_count_is_evidence_not_promotion_authority(self):
        value = copy.deepcopy(self.base)
        value["candidate"]["source"]["pattern_snapshot"]["occurrence_count"] = 999
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "PASS")

    def test_private_transcript_is_rejected(self):
        value = copy.deepcopy(self.base)
        value["candidate"]["raw_transcript"] = "must not persist"
        bundle = copy.deepcopy(value)
        plan = bundle.pop("sealed_evaluation_plan")
        bundle.pop("expected", None)
        with self.assertRaises(RatchetError):
            evaluate_verification_skipped(bundle, plan)


if __name__ == "__main__":
    unittest.main()
