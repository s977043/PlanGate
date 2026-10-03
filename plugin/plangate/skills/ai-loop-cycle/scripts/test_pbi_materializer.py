#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """test_pbi_materializer.py — #1442 feedback/Evidence -> PBI materializer tests.

Run:
    python3 scripts/ai-loop/test_pbi_materializer.py
"""

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


class MaterializationFixtures(unittest.TestCase):
    def test_01_run_evidence_failure_creates_delivery_follow_up(self):
        result = pm.materialize(_payload(), [])
        self.assertEqual(result["decision"]["decision"], "create_new")
        self.assertEqual(result["readiness"]["route"], "future_run")
        self.assertEqual(result["readiness"]["current_run_effect"], "none")

    def test_02_same_source_problem_with_semantic_delta_updates_existing(self):
        existing = _existing(acceptance_criteria=["AC-OLD"])
        result = pm.materialize(_payload(), [existing])
        self.assertEqual(result["decision"]["decision"], "update_existing")
        self.assertFalse(result["decision"]["requires_replan"])

    def test_03_same_semantics_links_only(self):
        result = pm.materialize(_payload(), [_existing()])
        self.assertEqual(result["decision"]["decision"], "link_only")
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
        payload["requirements"][0]["acceptance_basis"] = "explicit_decision"
        payload["requirements"][0]["basis_ref"] = "decision:D-1"
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

    def test_14_raw_transcript_key_is_rejected(self):
        payload = _payload(raw_transcript="secret conversation")
        with self.assertRaises(pm.MaterializationError) as ctx:
            pm.materialize(payload, [])
        self.assertTrue(any("privacy" in e for e in ctx.exception.errors))


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
