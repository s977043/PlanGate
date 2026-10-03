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


class AdmissionTests(unittest.TestCase):
    def _signal(self, **overrides):
        signal = {
            "signal_id": "SIG-001",
            "source_ref": "docs/working/ai-loop-runs/20260707T073726Z-e752626-run010-final.json",
            "source_kind": "existing_behavior",
            "claim_class": "observed",
            "statement": "Reviewer reported a test shortage.",
            "disposition": "actionable",
            "target_layer": "delivery",
            "candidate_problem": "A reviewer test-shortage signal needs follow-up delivery work.",
        }
        signal.update(overrides)
        return signal

    def test_actionable_observed_signal_materializes(self):
        result = pm.admit_signal(self._signal())
        self.assertEqual(result["decision"], "materialize")
        self.assertEqual(result["next"], "pbi_materializer")
        self.assertTrue(result["proposal_only"])
        self.assertFalse(result["write_allowed"])
        self.assertFalse(result["close_allowed"])
        self.assertFalse(result["suppression_allowed"])

    def test_observed_informational_signal_is_no_action_proposal(self):
        result = pm.admit_signal(
            self._signal(
                claim_class="observed",
                disposition="informational",
                candidate_problem=None,
            )
        )
        self.assertEqual(result["decision"], "no_action")
        self.assertEqual(result["next"], "record_evaluation_only")
        self.assertFalse(result["close_allowed"])

    def test_reported_informational_signal_requires_discovery(self):
        result = pm.admit_signal(
            self._signal(
                claim_class="reported",
                disposition="informational",
                candidate_problem=None,
            )
        )
        self.assertEqual(result["decision"], "discover_more")
        self.assertEqual(result["next"], "bounded_discovery")

    def test_inferred_actionable_signal_routes_to_discovery(self):
        result = pm.admit_signal(
            self._signal(claim_class="inferred")
        )
        self.assertEqual(result["decision"], "discover_more")
        self.assertEqual(result["next"], "bounded_discovery")

    def test_ambiguous_signal_routes_to_discovery(self):
        result = pm.admit_signal(
            self._signal(disposition="ambiguous", candidate_problem=None)
        )
        self.assertEqual(result["decision"], "discover_more")

    def test_actionable_without_candidate_problem_routes_to_discovery(self):
        result = pm.admit_signal(
            self._signal(candidate_problem=None)
        )
        self.assertEqual(result["decision"], "discover_more")

    def test_harness_signal_delegates_to_candidate_evolution(self):
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.admit_signal(self._signal(target_layer="harness"))
        self.assertTrue(any("#874/#869" in e for e in ctx.exception.errors))

    def test_private_admission_signal_is_rejected(self):
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.admit_signal(self._signal(raw_transcript="secret"))
        self.assertTrue(any("privacy" in e for e in ctx.exception.errors))


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
        self.assertTrue(
            report["evaluation_contract"]["historical_live_oracle_repository_visibility_enforced"]
        )
        self.assertTrue(
            report["evaluation_contract"]["source_oracle_artifact_separation_enforced"]
        )
        self.assertTrue(
            report["evaluation_contract"]["live_shadow_capture_metadata_enforced"]
        )
        self.assertFalse(
            report["evaluation_contract"]["live_shadow_label_alone_sufficient"]
        )
        self.assertTrue(
            report["evaluation_contract"]["live_shadow_run_evidence_binding_enforced"]
        )
        self.assertTrue(
            report["evaluation_contract"]["run_evidence_schema_revalidated"]
        )
        self.assertTrue(
            report["evaluation_contract"]["runtime_head_to_run_evidence_binding_enforced"]
        )
        self.assertFalse(
            report["evaluation_contract"]["run_evidence_task_binding_reverified"]
        )
        self.assertEqual(
            report["evaluation_contract"]["run_evidence_task_binding_owner"],
            "caller_or_run_evidence_verifier",
        )
        self.assertFalse(
            report["evaluation_contract"]["oracle_independence_enforced"]
        )
        self.assertEqual(
            report["evaluation_contract"]["oracle_independence_owner"],
            "caller_or_independent_reviewer",
        )
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
        historical["expected"]["oracle_ref"] = (
            "docs/working/TASK-1442/evidence/pbi-materializer-shadow/"
            "historical-replay-oracle.md#HR-010"
        )
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
        case["expected"]["oracle_ref"] = (
            "docs/working/TASK-1442/evidence/pbi-materializer-shadow/"
            "historical-replay-oracle.md#HR-010"
        )
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([case])
        self.assertTrue(any("#874/#869" in e for e in ctx.exception.errors))

    def test_historical_replay_requires_existing_oracle_artifact(self):
        historical_ref = "docs/working/ai-loop-runs/20260707T073726Z-e752626-run010-final.json"
        case = self._case(
            "historical-oracle-missing",
            "test",
            evidence_class="historical_replay",
            evidence_refs=[historical_ref],
        )
        case["payload"]["claims"][0]["source_ref"] = historical_ref
        case["payload"]["claims"][0]["source_kind"] = "existing_behavior"
        case["payload"]["requirements"] = []
        case["expected"]["oracle_ref"] = (
            "docs/working/TASK-1442/evidence/pbi-materializer-shadow/missing-oracle.md"
        )
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([case])
        self.assertTrue(any("repository source does not exist" in e for e in ctx.exception.errors))

    def test_historical_replay_oracle_cannot_be_source_evidence_itself(self):
        historical_ref = "docs/working/ai-loop-runs/20260707T073726Z-e752626-run010-final.json"
        case = self._case(
            "historical-self-oracle",
            "test",
            evidence_class="historical_replay",
            evidence_refs=[historical_ref],
        )
        case["payload"]["claims"][0]["source_ref"] = historical_ref
        case["payload"]["claims"][0]["source_kind"] = "existing_behavior"
        case["payload"]["requirements"] = []
        case["expected"]["oracle_ref"] = historical_ref
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_shadow_batch([case])
        self.assertTrue(any("oracle artifact must be distinct" in e for e in ctx.exception.errors))



class AdmissionBatchEvaluationTests(unittest.TestCase):
    def _case(
        self,
        case_ref,
        split,
        decision,
        *,
        evidence_class="synthetic_fixture",
        evidence_refs=None,
        signal_overrides=None,
    ):
        signal = {
            "signal_id": f"SIG-{case_ref}",
            "source_ref": "docs/working/ai-loop-runs/20260707T055726Z-7703b50-run006-final.json",
            "source_kind": "existing_behavior",
            "claim_class": "observed",
            "statement": "Clean run with no follow-up signal.",
            "disposition": "informational",
            "target_layer": "delivery",
            "candidate_problem": None,
        }
        if signal_overrides:
            signal.update(signal_overrides)
        return {
            "case_ref": case_ref,
            "split": split,
            "evidence_class": evidence_class,
            "evidence_refs": [] if evidence_refs is None else list(evidence_refs),
            "signal": signal,
            "expected": {
                "oracle_ref": f"docs/working/TASK-1442/{case_ref}.md",
                "admission_decision": decision,
            },
        }

    def test_admission_batch_reports_no_action_and_materialize_coverage(self):
        no_action = self._case("train-no-action", "train", "no_action")
        materialize = self._case(
            "test-materialize",
            "test",
            "materialize",
            signal_overrides={
                "statement": "Reviewer found a test shortage.",
                "disposition": "actionable",
                "candidate_problem": "Reviewer test-shortage signal needs follow-up work.",
            },
        )
        report = pm.evaluate_admission_batch([no_action, materialize])
        self.assertEqual(report["metrics"]["overall"]["accuracy"], 1.0)
        self.assertTrue(report["coverage"]["no_action_coverage"])
        self.assertTrue(report["coverage"]["materialize_coverage"])
        self.assertFalse(report["coverage"]["discover_more_coverage"])
        self.assertFalse(report["coverage"]["decision_coverage_complete"])
        self.assertFalse(report["write_allowed"])
        self.assertFalse(report["close_allowed"])
        self.assertFalse(report["suppression_allowed"])
        self.assertFalse(report["rollout_evidence"]["write_review_eligible"])
        self.assertIn(
            "admission_decision_coverage_incomplete",
            report["rollout_evidence"]["write_review_blockers"],
        )

    def test_admission_batch_requires_test_split(self):
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.evaluate_admission_batch([
                self._case("train-only", "train", "no_action")
            ])
        self.assertTrue(any("test split" in e for e in ctx.exception.errors))

    def test_admission_batch_mismatch_is_visible(self):
        case = self._case("test-mismatch", "test", "materialize")
        report = pm.evaluate_admission_batch([case])
        self.assertEqual(report["metrics"]["test"]["accuracy"], 0.0)
        self.assertEqual(report["cases"][0]["status"], "mismatch")
        self.assertEqual(report["cases"][0]["actual"], "no_action")
        self.assertEqual(report["cases"][0]["expected"], "materialize")

    def test_admission_batch_keeps_oracle_independence_unproven(self):
        case = self._case("test-oracle", "test", "no_action")
        report = pm.evaluate_admission_batch([case])
        self.assertTrue(
            report["evaluation_contract"]["live_shadow_capture_metadata_enforced"]
        )
        self.assertFalse(
            report["evaluation_contract"]["live_shadow_label_alone_sufficient"]
        )
        self.assertTrue(
            report["evaluation_contract"]["live_shadow_run_evidence_binding_enforced"]
        )
        self.assertTrue(
            report["evaluation_contract"]["runtime_head_to_run_evidence_binding_enforced"]
        )
        self.assertFalse(
            report["evaluation_contract"]["run_evidence_task_binding_reverified"]
        )
        self.assertFalse(
            report["evaluation_contract"]["oracle_independence_enforced"]
        )
        self.assertFalse(
            report["evaluation_contract"]["holdout_isolation_enforced"]
        )
        self.assertFalse(
            report["evaluation_contract"]["generalization_claim_allowed"]
        )


class LiveShadowRunEvidenceBindingTests(unittest.TestCase):
    def _setup_bound_case(self, root, **capture_overrides):
        (root / "docs").mkdir(parents=True, exist_ok=True)
        (root / "scripts").mkdir(parents=True, exist_ok=True)
        evidence_dir = root / "docs/working/TASK-9999/evidence"
        evidence_dir.mkdir(parents=True, exist_ok=True)

        capture_ref = "docs/working/TASK-9999/evidence/live-capture.json"
        ev_ref = "docs/working/TASK-9999/evidence/run-evidence.json"

        fixture = (
            HERE.parent.parent
            / "tests/fixtures/run-evidence/fx-01-first-pass.json"
        )
        ev = json.loads(fixture.read_text(encoding="utf-8"))

        signal = {
            "signal_id": "SIG-LIVE-001",
            "source_ref": "TASK-9999/delivery/record.jsonl",
            "source_kind": "existing_behavior",
            "claim_class": "observed",
            "statement": "Live delivery signal captured before RunEvidence finalization.",
            "disposition": "actionable",
            "target_layer": "delivery",
            "candidate_problem": "Preserve the live signal as follow-up work.",
        }
        capture_args = {
            "task_id": ev["task_id"],
            "run_id": ev["run_id"],
            "captured_at": "2099-12-31T12:00:00Z",
            "runtime_head_sha": ev["final_head_sha"],
            "capture_ref": capture_ref,
            "signal": signal,
        }
        capture_args.update(capture_overrides)
        capture = pm.build_passive_shadow_capture(**capture_args)

        ev["evidence_refs"] = list(ev["evidence_refs"]) + [capture_ref]
        (root / capture_ref).write_text(
            json.dumps(capture, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        (root / ev_ref).write_text(
            json.dumps(ev, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        case = {
            "evidence_class": "live_shadow",
            "live_capture": {
                "capture_ref": capture_ref,
                "run_evidence_ref": ev_ref,
            },
        }
        return case, [capture_ref, ev_ref], capture, ev, capture_ref, ev_ref

    def test_bound_live_capture_is_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            case, refs, _capture, _ev, _cap_ref, _ev_ref = self._setup_bound_case(root)
            errors = pm._validate_live_shadow_capture(
                case, "case", refs, authority_root=root
            )
            self.assertEqual(errors, [])

    def test_run_evidence_must_include_capture_ref(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            case, refs, _capture, ev, capture_ref, ev_ref = self._setup_bound_case(root)
            ev["evidence_refs"] = [
                ref for ref in ev["evidence_refs"] if ref != capture_ref
            ]
            (root / ev_ref).write_text(
                json.dumps(ev, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            errors = pm._validate_live_shadow_capture(
                case, "case", refs, authority_root=root
            )
            self.assertTrue(any("must include capture_ref" in e for e in errors))

    def test_runtime_head_must_match_run_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            case, refs, capture, _ev, capture_ref, _ev_ref = self._setup_bound_case(root)
            capture["runtime_head_sha"] = "0" * 40
            (root / capture_ref).write_text(
                json.dumps(capture, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            errors = pm._validate_live_shadow_capture(
                case, "case", refs, authority_root=root
            )
            self.assertTrue(any("final_head_sha" in e for e in errors))

    def test_capture_time_must_be_inside_run_window(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            case, refs, _capture, _ev, _cap_ref, _ev_ref = self._setup_bound_case(
                root,
                captured_at="2100-01-02T00:00:00Z",
            )
            errors = pm._validate_live_shadow_capture(
                case, "case", refs, authority_root=root
            )
            self.assertTrue(any("inside RunEvidence" in e for e in errors))

    def test_run_evidence_schema_is_revalidated(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            case, refs, _capture, ev, _cap_ref, ev_ref = self._setup_bound_case(root)
            del ev["terminal_state"]
            (root / ev_ref).write_text(
                json.dumps(ev, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            errors = pm._validate_live_shadow_capture(
                case, "case", refs, authority_root=root
            )
            self.assertTrue(any("schema" in e and "terminal_state" in e for e in errors))

    def test_passive_capture_has_no_write_close_suppression_or_oracle_authority(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _case, _refs, capture, _ev, _cap_ref, _ev_ref = self._setup_bound_case(root)
            self.assertEqual(capture["mode"], "passive_shadow_capture")
            self.assertFalse(capture["authority"]["write_allowed"])
            self.assertFalse(capture["authority"]["close_allowed"])
            self.assertFalse(capture["authority"]["suppression_allowed"])
            self.assertFalse(capture["authority"]["oracle_attached"])
            self.assertTrue(capture["signal_hash"].startswith("sha256:"))

    def test_passive_capture_rejects_invalid_upstream_source_ref(self):
        signal = {
            "signal_id": "SIG-BAD-REF",
            "source_ref": "../outside.json",
            "source_kind": "existing_behavior",
            "claim_class": "observed",
            "statement": "Invalid upstream ref",
            "disposition": "actionable",
            "target_layer": "delivery",
            "candidate_problem": "Should be rejected",
        }
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.build_passive_shadow_capture(
                task_id="TASK-9999",
                run_id="run-live",
                captured_at="2026-10-03T04:00:00Z",
                runtime_head_sha="a" * 40,
                capture_ref="docs/working/TASK-9999/evidence/capture.json",
                signal=signal,
            )
        self.assertTrue(any("absolute/traversal ref rejected" in e for e in ctx.exception.errors))

    def test_passive_capture_rejects_self_sourced_signal(self):
        capture_ref = "docs/working/TASK-9999/evidence/capture.json"
        signal = {
            "signal_id": "SIG-SELF",
            "source_ref": capture_ref,
            "source_kind": "existing_behavior",
            "claim_class": "observed",
            "statement": "Self sourced",
            "disposition": "actionable",
            "target_layer": "delivery",
            "candidate_problem": "Should be rejected",
        }
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.build_passive_shadow_capture(
                task_id="TASK-9999",
                run_id="run-live",
                captured_at="2026-10-03T04:00:00Z",
                runtime_head_sha="a" * 40,
                capture_ref=capture_ref,
                signal=signal,
            )
        self.assertTrue(any("cannot cite its own capture_ref" in e for e in ctx.exception.errors))

    def test_passive_capture_rejects_harness_signal(self):
        signal = {
            "signal_id": "SIG-H",
            "source_ref": "docs/working/TASK-9999/evidence/capture.json",
            "source_kind": "run_evidence",
            "claim_class": "observed",
            "statement": "Harness signal",
            "disposition": "actionable",
            "target_layer": "harness",
            "candidate_problem": "Harness problem",
        }
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.build_passive_shadow_capture(
                task_id="TASK-9999",
                run_id="run-live",
                captured_at="2026-10-03T04:00:00Z",
                runtime_head_sha="a" * 40,
                capture_ref="docs/working/TASK-9999/evidence/capture.json",
                signal=signal,
            )
        self.assertTrue(any("#874/#869" in e for e in ctx.exception.errors))


class WriteReviewAssessmentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "docs/reports").mkdir(parents=True)
        (self.root / "docs/reviews").mkdir(parents=True)
        (self.root / "scripts").mkdir()
        (self.root / "docs/reviews/oracle.md").write_text(
            "# Independent oracle review\n",
            encoding="utf-8",
        )
        (self.root / "docs/reviews/holdout.md").write_text(
            "# Isolated holdout review\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def _materialization_report(self, **overrides):
        cases = [
            {
                "case_ref": "M-CREATE",
                "evidence_class": "live_shadow",
                "status": "match",
                "actual_decision": "create_new",
                "actual_readiness_route": "future_run",
            },
            {
                "case_ref": "M-UPDATE",
                "evidence_class": "live_shadow",
                "status": "match",
                "actual_decision": "update_existing",
                "actual_readiness_route": "future_run",
            },
            {
                "case_ref": "M-LINK",
                "evidence_class": "live_shadow",
                "status": "match",
                "actual_decision": "link_only",
                "actual_readiness_route": "future_run",
            },
        ]
        report = {
            "mode": "shadow_evaluation",
            "write_allowed": False,
            "automatic_promotion": False,
            "metrics": {"overall": {"errors": 0}},
            "rollout_evidence": {
                "live_shadow_cases": 3,
                "observed_decisions": [
                    "create_new",
                    "link_only",
                    "update_existing",
                ],
            },
            "cases": cases,
        }
        report.update(overrides)
        return report

    def _admission_report(self, **overrides):
        cases = [
            {
                "case_ref": "A-MATERIALIZE",
                "evidence_class": "live_shadow",
                "status": "match",
                "actual": "materialize",
            },
            {
                "case_ref": "A-NO-ACTION",
                "evidence_class": "live_shadow",
                "status": "match",
                "actual": "no_action",
            },
            {
                "case_ref": "A-DISCOVER",
                "evidence_class": "live_shadow",
                "status": "match",
                "actual": "discover_more",
            },
        ]
        report = {
            "mode": "admission_evaluation",
            "write_allowed": False,
            "close_allowed": False,
            "suppression_allowed": False,
            "automatic_promotion": False,
            "metrics": {"overall": {"errors": 0}},
            "rollout_evidence": {"live_shadow_cases": 3},
            "coverage": {
                "decision_coverage_complete": True,
                "observed_admission_decisions": [
                    "discover_more",
                    "materialize",
                    "no_action",
                ],
            },
            "cases": cases,
        }
        report.update(overrides)
        return report

    def _persist_reports(self, assessment):
        (self.root / assessment["materialization_report_ref"]).write_text(
            json.dumps(
                assessment["materialization_report"],
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )
        (self.root / assessment["admission_report_ref"]).write_text(
            json.dumps(
                assessment["admission_report"],
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )

    def _assessment(self, **context_overrides):
        context = {
            "design_dependency_finalized": True,
            "latest_full_test_green": True,
            "generalization_claim_requested": False,
            "independent_oracle_review_ref": "docs/reviews/oracle.md",
            "isolated_holdout_review_ref": None,
        }
        context.update(context_overrides)
        assessment = {
            "materialization_report": self._materialization_report(),
            "materialization_report_ref": "docs/reports/materialization.json",
            "admission_report": self._admission_report(),
            "admission_report_ref": "docs/reports/admission.json",
            "context": context,
        }
        self._persist_reports(assessment)
        return assessment

    def _assess(self, assessment):
        self._persist_reports(assessment)
        return pm.assess_write_review_readiness(
            assessment,
            authority_root=self.root,
        )

    def test_review_ready_never_grants_write_authority(self):
        result = self._assess(self._assessment())
        self.assertTrue(result["write_review_ready"])
        self.assertEqual(result["blockers"], [])
        self.assertFalse(result["write_allowed"])
        self.assertFalse(result["close_allowed"])
        self.assertFalse(result["suppression_allowed"])
        self.assertFalse(result["automatic_promotion"])
        self.assertTrue(result["authority"]["review_only"])
        self.assertFalse(result["authority"]["merge_authority"])
        self.assertFalse(
            result["authority"]["report_artifact_authorship_verified"]
        )
        self.assertTrue(
            result["report_refs"]["materialization_report_hash"].startswith(
                "sha256:"
            )
        )

    def test_current_missing_live_evidence_and_dependencies_block_review(self):
        assessment = self._assessment(
            design_dependency_finalized=False,
            latest_full_test_green=False,
            independent_oracle_review_ref=None,
        )
        for case in assessment["materialization_report"]["cases"]:
            case["evidence_class"] = "historical_replay"
        assessment["materialization_report"]["rollout_evidence"][
            "live_shadow_cases"
        ] = 0
        for case in assessment["admission_report"]["cases"]:
            case["evidence_class"] = "historical_replay"
        assessment["admission_report"]["rollout_evidence"][
            "live_shadow_cases"
        ] = 0
        assessment["admission_report"]["coverage"][
            "decision_coverage_complete"
        ] = True
        result = self._assess(assessment)
        self.assertFalse(result["write_review_ready"])
        for blocker in (
            "design_dependency_not_finalized",
            "latest_full_test_not_green",
            "materialization_live_shadow_not_observed",
            "admission_live_shadow_not_observed",
            "admission_decision_coverage_incomplete",
            "independent_oracle_review_missing",
        ):
            self.assertIn(blocker, result["blockers"])

    def test_materialization_decision_coverage_is_required(self):
        assessment = self._assessment()
        assessment["materialization_report"]["cases"] = [
            assessment["materialization_report"]["cases"][0]
        ]
        assessment["materialization_report"]["rollout_evidence"][
            "live_shadow_cases"
        ] = 1
        assessment["materialization_report"]["rollout_evidence"][
            "observed_decisions"
        ] = ["create_new"]
        result = self._assess(assessment)
        self.assertFalse(result["write_review_ready"])
        self.assertEqual(
            result["evidence_summary"]["missing_materialization_decisions"],
            ["link_only", "update_existing"],
        )
        self.assertIn(
            "materialization_decision_coverage_incomplete",
            result["blockers"],
        )

    def test_evaluator_errors_block_review(self):
        assessment = self._assessment()
        assessment["admission_report"]["cases"].append(
            {
                "case_ref": "A-ERROR",
                "evidence_class": "historical_replay",
                "status": "error",
            }
        )
        assessment["admission_report"]["metrics"]["overall"]["errors"] = 1
        result = self._assess(assessment)
        self.assertFalse(result["write_review_ready"])
        self.assertIn("admission_evaluator_errors_present", result["blockers"])

    def test_generalization_claim_requires_holdout_review_ref(self):
        result = self._assess(
            self._assessment(generalization_claim_requested=True)
        )
        self.assertFalse(result["write_review_ready"])
        self.assertIn("isolated_holdout_review_missing", result["blockers"])

    def test_generalization_claim_can_be_review_ready_with_existing_holdout_ref(self):
        result = self._assess(
            self._assessment(
                generalization_claim_requested=True,
                isolated_holdout_review_ref="docs/reviews/holdout.md",
            )
        )
        self.assertTrue(result["write_review_ready"])
        self.assertFalse(result["write_allowed"])

    def test_report_with_write_authority_is_rejected(self):
        assessment = self._assessment()
        assessment["materialization_report"]["write_allowed"] = True
        with self.assertRaises(pm.MaterializationError) as ctx:
            self._assess(assessment)
        self.assertTrue(
            any("write_allowed: false required" in e for e in ctx.exception.errors)
        )

    def test_embedded_report_must_match_repository_artifact(self):
        assessment = self._assessment()
        assessment["materialization_report"]["rollout_evidence"][
            "live_shadow_cases"
        ] = 99
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.assess_write_review_readiness(
                assessment,
                authority_root=self.root,
            )
        self.assertTrue(
            any(
                "stored report does not match embedded report" in e
                for e in ctx.exception.errors
            )
        )




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
