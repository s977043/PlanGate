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
    compute_source_set_digest,
    evaluate_verification_skipped,
    manifest_ref,
)


def rebind_sources(value):
    """Recompute the Candidate's source bindings from ``value["sources"]``.

    This makes the Candidate self-consistent with its sources so that a test
    reaches the provenance check it targets instead of an earlier binding
    mismatch. It deliberately does not validate run_id agreement.
    """
    refs = [
        {
            "run_id": source["run_id"],
            "event_ref": source["event_ref"],
            "failure_record_ref": canonical_digest(source["failure_record"]),
            "run_evidence_ref": canonical_digest(source["run_evidence"]),
        }
        for source in value["sources"]
    ]
    candidate_source = value["candidate"]["source"]
    candidate_source["failure_instance_refs"] = refs
    candidate_source["run_evidence_refs"] = [
        ref["run_evidence_ref"] for ref in refs
    ]
    candidate_source["pattern_snapshot"]["source_set_digest"] = (
        compute_source_set_digest(refs)
    )
    return value


def rebind_manifests(value):
    """Recompute every manifest binding after a test edits a manifest."""
    baseline_ref = manifest_ref(value["baseline_manifest"])
    value["sealed_evaluation_plan"]["baseline_manifest_ref"] = baseline_ref
    value["candidate"]["baseline_manifest_ref"] = baseline_ref
    value["candidate"]["evaluation_plan_digest"] = canonical_digest(
        value["sealed_evaluation_plan"]
    )
    value["candidate_manifest_ref"] = manifest_ref(value["candidate_manifest"])
    return value


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

    def test_declared_protected_scope_fails_before_paired_eval(self):
        value = copy.deepcopy(self.base)
        value["candidate"]["target"]["allowed_paths"].append(
            "tests/fixtures/ai-loop-v2/ratchet/**"
        )
        result = self.evaluate(value)
        self.assertEqual(result["experiment_result"]["result"], "FAIL")
        self.assertEqual(
            result["experiment_result"]["policy_verdict"], "HUMAN_REQUIRED"
        )
        self.assertIn(
            "DECLARED_SCOPE_INTERSECTS_PROTECTED_AUTHORITY",
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

    # --- bound evaluation (the test supplies its own sealed plan) ---------

    def evaluate_bound(self, value):
        bundle = copy.deepcopy(value)
        plan = bundle.pop("sealed_evaluation_plan")
        bundle.pop("expected", None)
        return evaluate_verification_skipped(bundle, plan)

    def assertResult(self, result, expected_result, reason):
        experiment = result["experiment_result"]
        self.assertEqual(experiment["result"], expected_result, experiment)
        self.assertIn(reason, experiment["reason_codes"])
        self.assertEqual(
            result["promotion_decision"]["decision"], expected_result
        )

    # --- major 1: actual delta scope ------------------------------------

    def test_non_canonical_changed_path_fails_closed(self):
        # (a) fnmatch's "*" crosses "/", so an un-normalized path can sit
        # inside allowed_paths while resolving onto a protected path.
        for path in (
            "harness/verifiers/../../scripts/ai-loop-v2/ratchet.py",
            "harness/verifiers/./completion-evidence.json",
            "harness/verifiers//completion-evidence.json",
            "/harness/verifiers/completion-evidence.json",
            "",
        ):
            with self.subTest(path=path):
                value = copy.deepcopy(self.base)
                value["candidate_manifest"]["components"][-1]["paths"] = [path]
                rebind_manifests(value)
                result = self.evaluate_bound(value)
                self.assertResult(result, "FAIL", "NON_CANONICAL_CHANGED_PATH")
                self.assertEqual(
                    result["experiment_result"]["policy_verdict"],
                    "HUMAN_REQUIRED",
                )

    def test_changed_component_without_paths_is_inconclusive(self):
        # (b) all([]) is True: a changed component that declares no paths
        # must not pass the scope check vacuously.
        for mutate in ("empty", "absent", "not_list"):
            with self.subTest(mutate=mutate):
                value = copy.deepcopy(self.base)
                component = value["candidate_manifest"]["components"][-1]
                if mutate == "empty":
                    component["paths"] = []
                elif mutate == "absent":
                    del component["paths"]
                else:
                    component["paths"] = "harness/verifiers/x.json"
                rebind_manifests(value)
                result = self.evaluate_bound(value)
                self.assertResult(
                    result, "INCONCLUSIVE", "COMPONENT_PATHS_MISSING"
                )

    def test_relocated_protected_component_is_detected(self):
        # (c) the baseline paths of a changed component count too: moving a
        # protected component under allowed_paths must not hide the change.
        value = copy.deepcopy(self.base)
        value["baseline_manifest"]["components"].append({
            "component_id": "evaluation:known-bad-fixture",
            "content_sha": "sha256:" + "1" * 64,
            "paths": ["tests/fixtures/ai-loop-v2/ratchet/known-bad.json"],
            "enabled": True,
        })
        value["candidate_manifest"]["components"].append({
            "component_id": "evaluation:known-bad-fixture",
            "content_sha": "sha256:" + "2" * 64,
            "paths": ["harness/verifiers/known-bad.json"],
            "enabled": True,
        })
        rebind_manifests(value)
        result = self.evaluate_bound(value)
        self.assertResult(result, "FAIL", "PROTECTED_AUTHORITY_CHANGED")
        self.assertIn(
            "tests/fixtures/ai-loop-v2/ratchet/known-bad.json",
            result["experiment_result"]["observed_changed_paths"],
        )

    def test_actual_delta_on_protected_path_is_protected_authority(self):
        value = copy.deepcopy(self.base)
        value["candidate_manifest"]["components"][-1]["paths"] = [
            "scripts/ai-loop-v2/ratchet.py"
        ]
        rebind_manifests(value)
        result = self.evaluate_bound(value)
        self.assertResult(result, "FAIL", "PROTECTED_AUTHORITY_CHANGED")
        self.assertEqual(
            result["experiment_result"]["policy_verdict"], "HUMAN_REQUIRED"
        )

    def test_duplicate_component_id_is_inconclusive(self):
        # A dict keyed by component_id keeps only the last entry, so a
        # duplicate can shadow a changed component.
        value = copy.deepcopy(self.base)
        shadow = copy.deepcopy(value["candidate_manifest"]["components"][0])
        shadowed = copy.deepcopy(shadow)
        shadowed["content_sha"] = "sha256:" + "3" * 64
        shadowed["paths"] = ["scripts/ai-loop-v2/ratchet.py"]
        value["candidate_manifest"]["components"][0] = shadowed
        value["candidate_manifest"]["components"].append(shadow)
        rebind_manifests(value)
        result = self.evaluate_bound(value)
        self.assertResult(
            result, "INCONCLUSIVE", "MANIFEST_COMPONENT_IDENTITY"
        )

    def test_identical_manifests_are_no_observed_delta(self):
        value = copy.deepcopy(self.base)
        value["candidate_manifest"] = copy.deepcopy(value["baseline_manifest"])
        rebind_manifests(value)
        result = self.evaluate_bound(value)
        self.assertResult(result, "INCONCLUSIVE", "NO_OBSERVED_HARNESS_DELTA")

    # --- major 2: provenance --------------------------------------------

    def test_zero_sources_is_inconclusive(self):
        value = copy.deepcopy(self.base)
        value["sources"] = []
        rebind_sources(value)
        result = self.evaluate_bound(value)
        self.assertResult(result, "INCONCLUSIVE", "SOURCE_INSTANCE_BINDING")

    def test_duplicate_failure_instance_is_inconclusive(self):
        value = copy.deepcopy(self.base)
        value["sources"] = [
            value["sources"][0], copy.deepcopy(value["sources"][0])
        ]
        rebind_sources(value)
        result = self.evaluate_bound(value)
        self.assertResult(result, "INCONCLUSIVE", "SOURCE_INSTANCE_BINDING")

    def test_source_run_id_must_match_run_evidence(self):
        value = copy.deepcopy(self.base)
        value["sources"][0]["run_id"] = "run:verification-skipped:other"
        rebind_sources(value)
        result = self.evaluate_bound(value)
        self.assertResult(result, "INCONCLUSIVE", "SOURCE_FAILURE_BINDING")

    def test_incomplete_pattern_snapshot_is_inconclusive(self):
        for field in (
            "pattern_id",
            "pattern_version",
            "classifier_digest",
            "source_set_digest",
        ):
            with self.subTest(field=field):
                value = copy.deepcopy(self.base)
                del value["candidate"]["source"]["pattern_snapshot"][field]
                result = self.evaluate_bound(value)
                self.assertResult(
                    result, "INCONCLUSIVE", "PATTERN_SNAPSHOT_INCOMPLETE"
                )

    def test_sealed_plan_must_digest_both_paired_fixtures(self):
        for fixture_key in (
            "known_bad_fixture_id",
            "negative_control_fixture_id",
        ):
            with self.subTest(fixture=fixture_key):
                value = copy.deepcopy(self.base)
                plan = value["sealed_evaluation_plan"]
                del plan["fixture_digests"][plan[fixture_key]]
                value["candidate"]["evaluation_plan_digest"] = (
                    canonical_digest(plan)
                )
                result = self.evaluate_bound(value)
                self.assertResult(
                    result, "INCONCLUSIVE", "EVALUATION_PLAN_INCOMPLETE"
                )

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
