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

__doc__ = """test_pbi_materializer.py — #1442 feedback/Evidence -> PBI materializer tests.

Run:
    python3 scripts/ai-loop/test_pbi_materializer.py
"""

import ast
import copy
import json
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import pbi_materializer as pm  # noqa: E402


def _payload(**overrides):
    payload = {
        "task_id": "TASK-1442",
        "title": "Observed delivery failure follow-up",
        "author": "ai",
        "application_timing": "follow_up",
        "target_layer": "delivery",
        "goal": "Reduce repeated delivery failures",
        "problem": "The same verifier failure repeated in two runs",
        "source_run_refs": ["run:001"],
        "claims": [
            {
                "id": "CLM-001",
                "text": "Verifier X failed in run 001",
                "source_ref": "run-evidence:001",
                "source_kind": "run_evidence",
                "claim_class": "observed",
                "supports": "Problem",
            }
        ],
        "requirements": [
            {
                "id": "REQ-001",
                "goal_problem": "Prevent the repeated verifier failure",
                "acceptance_basis": "evidence",
                "basis_ref": "run-evidence:001",
                "related_ac": "AC-01",
            }
        ],
        "acceptance_criteria": ["AC-01: repeated verifier failure is detected"],
        "in_scope": ["Generate an evidence-backed PBI draft"],
        "out_of_scope": ["Modify the active Run"],
        "risks": ["False duplicate match"],
        "unknowns": [],
        "assumptions": ["RunEvidence is valid"],
        "harness_candidate_ref": None,
    }
    payload.update(overrides)
    return payload


def _existing(
    *,
    ref="docs/working/TASK-1400/pbi-input.md",
    source_refs=None,
    goal="Reduce repeated delivery failures",
    problem="The same verifier failure repeated in two runs",
    requirements=None,
    acceptance_criteria=None,
    bound=False,
):
    return {
        "ref": ref,
        "source_refs": source_refs if source_refs is not None else ["run-evidence:001"],
        "goal": goal,
        "problem": problem,
        "requirements": requirements
        if requirements is not None
        else ["Prevent the repeated verifier failure"],
        "acceptance_criteria": acceptance_criteria
        if acceptance_criteria is not None
        else ["AC-01: repeated verifier failure is detected"],
        "bound_to_approved_plan": bound,
    }


class TestDefinitionIntegrityTests(unittest.TestCase):
    def test_no_duplicate_test_method_names_within_a_class(self):
        tree = ast.parse(pathlib.Path(__file__).read_text(encoding="utf-8"))
        duplicates = []
        for node in tree.body:
            if not isinstance(node, ast.ClassDef):
                continue
            seen = set()
            for child in node.body:
                if not isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    continue
                if not child.name.startswith("test_"):
                    continue
                if child.name in seen:
                    duplicates.append(f"{node.name}.{child.name}")
                seen.add(child.name)
        self.assertEqual(
            duplicates,
            [],
            f"duplicate unittest method names silently override earlier tests: {duplicates}",
        )


class MaterializationFixtures(unittest.TestCase):
    def test_01_run_evidence_failure_creates_delivery_follow_up(self):
        result = pm.materialize(_payload(), [])
        self.assertEqual(result["decision"]["decision"], "create_new")
        self.assertEqual(result["proposal_kind"], "full_draft")
        self.assertFalse(result["apply_contract"]["write_allowed"])
        self.assertFalse(result["apply_contract"]["replacement_allowed"])
        self.assertIn("#### Existing Work Check", result["pbi_markdown"])
        self.assertEqual(result["readiness"]["route"], "future_run")
        self.assertEqual(result["readiness"]["current_run_effect"], "none")

    def test_02_same_source_problem_with_semantic_delta_updates_existing(self):
        existing = _existing(acceptance_criteria=["AC-OLD"])
        result = pm.materialize(_payload(), [existing])
        self.assertEqual(result["decision"]["decision"], "update_existing")
        self.assertEqual(result["proposal_kind"], "semantic_patch_proposal")
        self.assertFalse(result["decision"]["requires_replan"])
        self.assertIn(
            "update_existing is a semantic patch proposal",
            result["pbi_markdown"],
        )

    def test_03_same_semantics_links_only(self):
        result = pm.materialize(_payload(), [_existing()])
        self.assertEqual(result["decision"]["decision"], "link_only")
        self.assertEqual(result["proposal_kind"], "link_evidence_only")
        self.assertEqual(
            result["decision"]["matched_ref"],
            "docs/working/TASK-1400/pbi-input.md",
        )

    def test_04_same_source_materially_different_goal_creates_new_related(self):
        existing = _existing(
            goal="Improve onboarding",
            problem="Users cannot find the setup page",
        )
        result = pm.materialize(_payload(), [existing])
        self.assertEqual(result["decision"]["decision"], "create_new")
        self.assertIn(existing["ref"], result["decision"]["related_refs"])

    def test_05_inferred_claim_keeps_original_origin(self):
        payload = _payload(
            claims=[
                {
                    "id": "CLM-001",
                    "text": "Agent B infers the root cause from Agent A summary",
                    "source_ref": "agent-summary:B",
                    "origin_ref": "run-evidence:001",
                    "source_kind": "run_evidence",
                    "claim_class": "inferred",
                    "supports": "Problem",
                }
            ],
            requirements=[
                {
                    "id": "REQ-001",
                    "goal_problem": "Investigate inferred root cause",
                    "acceptance_basis": "evidence",
                    "basis_ref": "run-evidence:001",
                    "related_ac": "AC-01",
                }
            ],
        )
        decision_ref = "docs/working/TASK-1442/decision-log.jsonl#D-001"
        payload["claims"].append(
            {
                "id": "CLM-D1",
                "text": "Decision D-1 adopts the inferred hypothesis for investigation",
                "source_ref": decision_ref,
                "source_kind": "decision_log",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "explicit_decision"
        payload["requirements"][0]["basis_ref"] = decision_ref
        result = pm.materialize(payload, [])
        self.assertIn("inferred", result["pbi_markdown"])
        self.assertIn("Agent B infers the root cause from Agent A summary", result["pbi_markdown"])
        self.assertIn("| agent-summary:B | run-evidence:001 |", result["pbi_markdown"])

    def test_05b_inferred_only_source_cannot_be_evidence_acceptance_basis(self):
        payload = _payload(
            claims=[
                {
                    "id": "CLM-001",
                    "text": "Agent inference only",
                    "source_ref": "agent-summary:B",
                    "origin_ref": "run-evidence:001",
                    "source_kind": "run_evidence",
                    "claim_class": "inferred",
                    "supports": "Problem",
                }
            ],
            requirements=[
                {
                    "id": "REQ-001",
                    "goal_problem": "Act on inference",
                    "acceptance_basis": "evidence",
                    "basis_ref": "run-evidence:001",
                    "related_ac": "AC-01",
                }
            ],
        )
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("inferred-only" in e for e in ctx.exception.errors))

    def test_05c_explicit_decision_requires_decision_log_provenance(self):
        payload = _payload()
        payload["requirements"][0]["acceptance_basis"] = "explicit_decision"
        payload["requirements"][0]["basis_ref"] = "decision:D-404"
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("decision_log provenance" in e for e in ctx.exception.errors))

    def test_05d_policy_rule_requires_policy_provenance(self):
        payload = _payload()
        payload["requirements"][0]["acceptance_basis"] = "policy_rule"
        payload["requirements"][0]["basis_ref"] = "policy:missing"
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("policy provenance" in e for e in ctx.exception.errors))

    def test_05e_policy_rule_with_policy_provenance_is_valid(self):
        payload = _payload()
        policy_ref = "docs/ai/core-contract.md#5-decision-rules"
        payload["claims"].append(
            {
                "id": "CLM-P1",
                "text": "Policy permits this low-risk requirement decision",
                "source_ref": policy_ref,
                "source_kind": "policy",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "policy_rule"
        payload["requirements"][0]["basis_ref"] = policy_ref
        result = pm.materialize(payload, [])
        self.assertEqual(result["readiness"]["status"], "ready")

    def test_05f_fabricated_decision_log_ref_is_rejected_even_with_matching_kind(self):
        payload = _payload()
        fake_ref = "docs/working/TASK-1442/missing-decision-log.jsonl#D-404"
        payload["claims"].append(
            {
                "id": "CLM-D404",
                "text": "Fabricated decision claim",
                "source_ref": fake_ref,
                "source_kind": "decision_log",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "explicit_decision"
        payload["requirements"][0]["basis_ref"] = fake_ref
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(
            any("repository source does not exist" in e for e in ctx.exception.errors)
        )

    def test_05g_unknown_decision_id_is_rejected(self):
        payload = _payload()
        ref = "docs/working/TASK-1442/decision-log.jsonl#D-404"
        payload["claims"].append(
            {
                "id": "CLM-D404",
                "text": "Unknown decision ID",
                "source_ref": ref,
                "source_kind": "decision_log",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "explicit_decision"
        payload["requirements"][0]["basis_ref"] = ref
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("must exist exactly once" in e for e in ctx.exception.errors))

    def test_05h_policy_rule_requires_rule_fragment(self):
        payload = _payload()
        policy_ref = "docs/ai/core-contract.md"
        payload["claims"].append(
            {
                "id": "CLM-P2",
                "text": "Broad policy file reference without rule anchor",
                "source_ref": policy_ref,
                "source_kind": "policy",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "policy_rule"
        payload["requirements"][0]["basis_ref"] = policy_ref
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("policy requires a rule fragment" in e for e in ctx.exception.errors))

    def test_05i_fabricated_policy_ref_is_rejected_even_with_matching_kind(self):
        payload = _payload()
        fake_ref = "docs/ai/missing-policy.md#rule"
        payload["claims"].append(
            {
                "id": "CLM-P404",
                "text": "Fabricated policy claim",
                "source_ref": fake_ref,
                "source_kind": "policy",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "policy_rule"
        payload["requirements"][0]["basis_ref"] = fake_ref
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(
            any("repository source does not exist" in e for e in ctx.exception.errors)
        )

    def test_05j_nonexistent_policy_rule_fragment_is_rejected(self):
        payload = _payload()
        fake_ref = "docs/ai/core-contract.md#definitely-not-a-real-policy-rule"
        payload["claims"].append(
            {
                "id": "CLM-P405",
                "text": "Existing policy file but fabricated rule fragment",
                "source_ref": fake_ref,
                "source_kind": "policy",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "policy_rule"
        payload["requirements"][0]["basis_ref"] = fake_ref
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(
            any("policy rule fragment" in e and "does not exist" in e
                for e in ctx.exception.errors)
        )

    def test_05k_invalid_explicit_authority_root_does_not_fallback(self):
        payload = _payload()
        policy_ref = "docs/ai/core-contract.md#5-decision-rules"
        payload["claims"].append(
            {
                "id": "CLM-P406",
                "text": "Valid policy rule under the real repository",
                "source_ref": policy_ref,
                "source_kind": "policy",
                "claim_class": "observed",
                "supports": "REQ-001",
            }
        )
        payload["requirements"][0]["acceptance_basis"] = "policy_rule"
        payload["requirements"][0]["basis_ref"] = policy_ref
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(pm.MaterializationError) as ctx:
                pm.materialize(payload, [], authority_root=tmp)
        self.assertTrue(
            any("repository root could not be resolved" in e
                for e in ctx.exception.errors)
        )

    def test_06_same_task_plan_cannot_be_upstream_evidence(self):
        payload = _payload(
            claims=[
                {
                    "id": "CLM-001",
                    "text": "The plan says this problem exists",
                    "source_ref": "docs/working/TASK-1442/plan.md",
                    "source_kind": "existing_behavior",
                    "claim_class": "observed",
                    "supports": "Problem",
                }
            ],
            requirements=[
                {
                    "id": "REQ-001",
                    "goal_problem": "Do the work",
                    "acceptance_basis": "explicit_decision",
                    "basis_ref": "decision:D-1",
                    "related_ac": "AC-01",
                }
            ],
        )
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("circular provenance" in e for e in ctx.exception.errors))

    def test_07_ai_authored_low_risk_pbi_is_valid_without_human_author(self):
        result = pm.materialize(_payload(author="ai"), [])
        self.assertEqual(result["readiness"]["status"], "ready")
        self.assertIn("PBI author: ai", result["pbi_markdown"])

    def test_08_replan_current_delivery_routes_to_existing_replan(self):
        result = pm.materialize(
            _payload(application_timing="replan_current", target_layer="delivery"),
            [],
        )
        self.assertEqual(result["readiness"]["route"], "replan_current")
        self.assertEqual(result["readiness"]["current_run_effect"], "replan_required")

    def test_09_replan_current_harness_is_rejected(self):
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(
                _payload(
                    application_timing="replan_current",
                    target_layer="harness",
                    harness_candidate_ref="HC-1",
                ),
                [],
            )
        self.assertTrue(any("replan_current + harness" in e for e in ctx.exception.errors))

    def test_10_harness_follow_up_pending_candidate_is_draft_only(self):
        result = pm.materialize(
            _payload(
                application_timing="follow_up",
                target_layer="harness",
                harness_candidate_ref="pending",
            ),
            [],
        )
        self.assertEqual(result["readiness"]["status"], "blocked")
        self.assertEqual(result["readiness"]["route"], "harness_candidate_required")

    def test_11_harness_follow_up_with_candidate_is_ready_for_plan(self):
        result = pm.materialize(
            _payload(
                application_timing="follow_up",
                target_layer="harness",
                harness_candidate_ref="HC-1442-001",
            ),
            [],
        )
        self.assertEqual(result["readiness"]["status"], "ready")
        self.assertEqual(result["readiness"]["route"], "harness_follow_up")

    def test_12_follow_up_does_not_mutate_current_binding(self):
        binding = {
            "run_id": "run-current",
            "plan_hash": "sha256:" + "1" * 64,
            "harness_manifest_ref": "sha256:" + "2" * 64,
        }
        payload = _payload(current_run_binding=binding)
        before = copy.deepcopy(payload)
        result = pm.materialize(payload, [])
        self.assertEqual(payload, before)
        self.assertEqual(result["readiness"]["current_run_effect"], "none")

    def test_13_bound_existing_semantic_rewrite_requires_replan(self):
        existing = _existing(
            acceptance_criteria=["AC-OLD"],
            bound=True,
        )
        result = pm.materialize(_payload(), [existing])
        self.assertEqual(result["decision"]["decision"], "update_existing")
        self.assertTrue(result["decision"]["requires_replan"])
        self.assertEqual(result["readiness"]["status"], "blocked")
        self.assertEqual(
            result["readiness"]["route"],
            "bound_pbi_requires_replan",
        )

    def test_13b_bound_update_with_explicit_replan_current_uses_existing_replan(self):
        existing = _existing(
            acceptance_criteria=["AC-OLD"],
            bound=True,
        )
        result = pm.materialize(
            _payload(application_timing="replan_current"),
            [existing],
        )
        self.assertTrue(result["decision"]["requires_replan"])
        self.assertEqual(result["readiness"]["status"], "ready")
        self.assertEqual(result["readiness"]["route"], "replan_current")
        self.assertEqual(
            result["readiness"]["current_run_effect"],
            "replan_required",
        )

    def test_14_raw_transcript_key_is_rejected(self):
        payload = _payload(raw_transcript="secret conversation")
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("privacy" in e for e in ctx.exception.errors))


class DecisionEnvelopeTests(unittest.TestCase):
    def test_invalid_materialization_decision_is_rejected(self):
        decision = {
            "decision": "merge_both",
            "matched_ref": None,
            "related_refs": [],
            "requires_replan": False,
            "reason": "invalid synthetic fixture",
        }
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.plan_readiness(_payload(), decision)
        self.assertTrue(any("decision.decision" in e for e in ctx.exception.errors))


class ProvenanceBoundaryTests(unittest.TestCase):
    def test_cross_task_derived_artifact_requires_origin_ref(self):
        payload = _payload(
            claims=[
                {
                    "id": "CLM-001",
                    "text": "Another task plan restates a failure",
                    "source_ref": "docs/working/TASK-1400/plan.md",
                    "source_kind": "existing_behavior",
                    "claim_class": "reported",
                    "supports": "Problem",
                }
            ],
            requirements=[
                {
                    "id": "REQ-001",
                    "goal_problem": "Investigate repeated failure",
                    "acceptance_basis": "explicit_decision",
                    "basis_ref": "decision:D-1",
                    "related_ac": "AC-01",
                }
            ],
        )
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("derived artifact source requires" in e for e in ctx.exception.errors))


class ExistingWorkValidationTests(unittest.TestCase):
    def test_malformed_existing_work_fails_closed_instead_of_creating_duplicate(self):
        malformed = [{"ref": "", "source_refs": "not-an-array"}]
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(_payload(), malformed)
        self.assertTrue(any("existing_work[0]" in e for e in ctx.exception.errors))


    def test_equal_top_matches_fail_closed_instead_of_arbitrary_update(self):
        a = _existing(ref="docs/working/TASK-1400/pbi-input.md")
        b = _existing(ref="docs/working/TASK-1401/pbi-input.md")
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(_payload(), [a, b])
        self.assertTrue(any("ambiguous top match" in e for e in ctx.exception.errors))


class RenderingIntegrityTests(unittest.TestCase):
    def test_provenance_table_escapes_pipe_and_newline_without_losing_claim(self):
        payload = _payload()
        payload["claims"][0]["text"] = "failure | repeated\nsecond line"
        result = pm.materialize(payload, [])
        self.assertIn("failure \\| repeated<br>second line", result["pbi_markdown"])
        self.assertIn("CLM-001", result["pbi_markdown"])


class ShadowComparisonTests(unittest.TestCase):
    def test_matching_reviewed_expectation_produces_match_evidence(self):
        result = pm.materialize(_payload(), [])
        expected = {
            "oracle_ref": "docs/working/TASK-1442/review-shadow.md",
            "decision": "create_new",
            "matched_ref": None,
            "readiness_status": "ready",
            "readiness_route": "future_run",
        }
        comparison = pm.compare_shadow(result, expected)
        self.assertEqual(comparison["status"], "match")
        self.assertEqual(comparison["mismatches"], [])
        self.assertTrue(all(comparison["checks"].values()))

    def test_shadow_mismatch_lists_only_disagreeing_fields(self):
        result = pm.materialize(_payload(), [])
        expected = {
            "oracle_ref": "docs/working/TASK-1442/review-shadow.md",
            "decision": "link_only",
            "matched_ref": "docs/working/TASK-1400/pbi-input.md",
            "readiness_status": "ready",
            "readiness_route": "future_run",
        }
        comparison = pm.compare_shadow(result, expected)
        self.assertEqual(comparison["status"], "mismatch")
        self.assertEqual(
            comparison["mismatches"],
            ["decision", "matched_ref"],
        )
        self.assertNotIn("write", comparison)
        self.assertNotIn("promote", comparison)

    def test_invalid_or_private_oracle_is_rejected(self):
        result = pm.materialize(_payload(), [])
        for expected in (
            {
                "oracle_ref": "docs/working/TASK-1442/review-shadow.md",
                "decision": "merge_both",
                "matched_ref": None,
                "readiness_status": "ready",
                "readiness_route": "future_run",
            },
            {
                "oracle_ref": "https://github.com/example/private-review",
                "decision": "create_new",
                "matched_ref": None,
                "readiness_status": "ready",
                "readiness_route": "future_run",
            },
        ):
            with self.subTest(expected=expected):
                with self.assertRaises(pm.MaterializationError):
                    pm.compare_shadow(result, expected)


class ShadowBatchEvaluationTests(unittest.TestCase):
    def _case(
        self,
        case_ref,
        split,
        *,
        decision="create_new",
        matched_ref=None,
        evidence_class="synthetic_fixture",
        evidence_refs=None,
    ):
        return {
            "case_ref": case_ref,
            "split": split,
            "evidence_class": evidence_class,
            "evidence_refs": [] if evidence_refs is None else list(evidence_refs),
            "payload": _payload(),
            "existing_work": [],
            "expected": {
                "oracle_ref": f"docs/working/TASK-1442/{case_ref}.md",
                "decision": decision,
                "matched_ref": matched_ref,
                "readiness_status": "ready",
                "readiness_route": "future_run",
            },
        }

    def test_train_and_test_metrics_are_reported_separately(self):
        report = pm.evaluate_shadow_batch([
            self._case("train-01", "train"),
            self._case("test-01", "test"),
        ])
        self.assertFalse(report["write_allowed"])
        self.assertFalse(report["automatic_promotion"])
        self.assertFalse(
            report["evaluation_contract"]["holdout_isolation_enforced"]
        )
        self.assertFalse(
            report["evaluation_contract"]["generalization_claim_allowed"]
        )
        self.assertEqual(
            report["evaluation_contract"]["holdout_isolation_owner"],
            "caller_or_independent_evaluator",
        )
        self.assertEqual(
            report["evaluation_contract"]["scope"],
            "post_admission_materialization",
        )
        self.assertFalse(
            report["evaluation_contract"]["materialization_admission_evaluated"]
        )
        self.assertFalse(report["evaluation_contract"]["no_action_coverage"])
        self.assertFalse(report["rollout_evidence"]["write_review_eligible"])
        self.assertIn(
            "admission_no_action_not_evaluated",
            report["rollout_evidence"]["write_review_blockers"],
        )
        self.assertEqual(report["metrics"]["train"]["exact_match_rate"], 1.0)
        self.assertEqual(report["metrics"]["test"]["exact_match_rate"], 1.0)
        self.assertEqual(report["metrics"]["overall"]["total"], 2)

    def test_train_mismatch_does_not_hide_test_result(self):
        train = self._case(
            "train-mismatch",
            "train",
            decision="link_only",
            matched_ref="docs/working/TASK-1400/pbi-input.md",
        )
        test = self._case("test-match", "test")
        report = pm.evaluate_shadow_batch([train, test])
        self.assertEqual(report["metrics"]["train"]["exact_match_rate"], 0.0)
        self.assertEqual(report["metrics"]["test"]["exact_match_rate"], 1.0)
        self.assertEqual(report["cases"][0]["status"], "mismatch")
        self.assertEqual(report["cases"][1]["status"], "match")

    def test_train_only_batch_is_rejected(self):
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([self._case("train-only", "train")])
        self.assertTrue(any("test split" in e for e in ctx.exception.errors))

    def test_duplicate_case_ref_is_rejected(self):
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([
                self._case("duplicate", "train"),
                self._case("duplicate", "test"),
            ])
        self.assertTrue(any("duplicate" in e for e in ctx.exception.errors))

    def test_privacy_violation_rejects_batch_before_evaluation(self):
        bad = self._case("test-private", "test")
        bad["payload"]["raw_transcript"] = "forbidden"
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([bad])
        self.assertTrue(any("privacy" in e for e in ctx.exception.errors))

    def test_materialization_error_counts_as_error_without_write_authority(self):
        bad = self._case("test-error", "test")
        bad["payload"]["claims"][0]["claim_class"] = "invented"
        report = pm.evaluate_shadow_batch([bad])
        self.assertEqual(report["metrics"]["test"]["errors"], 1)
        self.assertEqual(report["metrics"]["test"]["exact_match_rate"], 0.0)
        self.assertFalse(report["write_allowed"])
        self.assertFalse(report["automatic_promotion"])


    def test_historical_replay_requires_repository_visible_evidence(self):
        case = self._case(
            "historical-missing",
            "test",
            evidence_class="historical_replay",
            evidence_refs=[],
        )
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([case])
        self.assertTrue(
            any("requires repository-visible evidence refs" in e for e in ctx.exception.errors)
        )

    def test_historical_replay_counts_separately_from_synthetic(self):
        historical_ref = "docs/working/ai-loop-runs/20260707T073726Z-e752626-run010-final.json"
        train = self._case("synthetic-train", "train")
        historical = self._case(
            "historical-test",
            "test",
            evidence_class="historical_replay",
            evidence_refs=[historical_ref],
        )
        historical["payload"]["claims"][0]["source_ref"] = historical_ref
        historical["payload"]["claims"][0]["source_kind"] = "existing_behavior"
        historical["payload"]["requirements"] = []
        report = pm.evaluate_shadow_batch([train, historical])
        self.assertEqual(report["evidence_metrics"]["synthetic_fixture"]["total"], 1)
        self.assertEqual(report["evidence_metrics"]["historical_replay"]["total"], 1)
        self.assertEqual(report["evidence_metrics"]["live_shadow"]["total"], 0)
        self.assertEqual(report["rollout_evidence"]["historical_replay_cases"], 1)
        self.assertTrue(
            report["rollout_evidence"]["synthetic_excluded_from_rollout_claim"]
        )
        self.assertEqual(
            report["rollout_evidence"]["observed_decisions"],
            ["create_new"],
        )
        self.assertEqual(
            report["rollout_evidence"]["observed_readiness_routes"],
            ["future_run"],
        )
        self.assertFalse(report["rollout_evidence"]["write_review_eligible"])

    def test_harness_historical_replay_uses_candidate_evolution_path(self):
        historical_ref = "docs/working/ai-loop-runs/20260707T073726Z-e752626-run010-final.json"
        case = self._case(
            "historical-harness",
            "test",
            evidence_class="historical_replay",
            evidence_refs=[historical_ref],
        )
        case["payload"]["target_layer"] = "harness"
        case["payload"]["harness_candidate_ref"] = "HC-TEST"
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([case])
        self.assertTrue(any("#874/#869" in e for e in ctx.exception.errors))


class DeterminismAndSearchTests(unittest.TestCase):
    def test_same_input_is_byte_stable(self):
        a = pm.materialize(_payload(), [])
        b = pm.materialize(_payload(), [])
        self.assertEqual(
            json.dumps(a, ensure_ascii=False, sort_keys=True),
            json.dumps(b, ensure_ascii=False, sort_keys=True),
        )

    def test_local_working_scan_is_read_only_and_exact(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            task = root / "TASK-1400"
            task.mkdir()
            pbi = task / "pbi-input.md"
            pbi.write_text(
                "# PBI\n"
                "Reduce repeated delivery failures\n"
                "The same verifier failure repeated in two runs\n"
                "run-evidence:001\n"
                "Prevent the repeated verifier failure\n"
                "AC-01: repeated verifier failure is detected\n",
                encoding="utf-8",
            )
            before = pbi.read_bytes()
            found = pm.scan_working_pbis(root, _payload())
            after = pbi.read_bytes()
            self.assertEqual(before, after)
            self.assertEqual(len(found), 1)
            self.assertEqual(
                found[0]["ref"],
                "docs/working/TASK-1400/pbi-input.md",
            )
            result = pm.materialize(_payload(), found)
            self.assertEqual(
                result["decision"]["matched_ref"],
                "docs/working/TASK-1400/pbi-input.md",
            )


if __name__ == "__main__":
    unittest.main()
