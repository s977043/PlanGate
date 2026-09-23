#!/usr/bin/env python3
import copy
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from run_event import EventParseError, finalize_event  # noqa: E402
from run_evidence import project_run_evidence  # noqa: E402


H = "sha256:" + "1" * 64
P = "sha256:" + "2" * 64
SOURCE = "3" * 40
CTX = {
    "run_id": "run-evidence-001",
    "harness_manifest_ref": H,
    "plan_hash": P,
    "source_sha": SOURCE,
    "revision": 0,
}


def ev(event_type, payload, seq, evidence_refs=None, revision=0):
    draft = {
        "schema_version": "1",
        "event_type": event_type,
        "payload": payload,
        "evidence_refs": list(evidence_refs or []),
    }
    ctx = dict(CTX)
    ctx["revision"] = revision
    return finalize_event(draft, ctx, seq)


def partial_stream():
    return [
        ev(
            "plan_contract_bound",
            {"contract_ref": "loop-contract:test"},
            1,
        )
    ]


def terminal_stream():
    s = partial_stream()
    v2 = ev(
        "verification_recorded",
        {
            "verification_ref": "v1",
            "verifier_id": "deterministic.tests",
            "kind": "deterministic",
            "status": "pass",
            "bound_artifact_ref": "sha256:" + "a" * 64,
        },
        2,
        ["test:pass"],
    )
    c3 = ev(
        "pr_convergence_recorded",
        {
            "convergence_ref": "c1",
            "ci": "pass",
            "required_reviews": "pass",
            "blocking_threads": 0,
            "conflict": False,
            "scope": "pass",
        },
        3,
        ["pr:convergence"],
    )
    d4 = ev(
        "decision_made",
        {
            "decision_ref": "d1",
            "action": "stop",
            "input_refs": ["v1", "c1"],
            "outcome": "MERGE_READY",
            "stop_reasons": [],
            "policy_verdicts": ["ALLOW"],
        },
        4,
    )
    return s + [v2, c3, d4]


class RunEvidenceProjectionTests(unittest.TestCase):
    def test_partial_stream_projects_partial(self):
        out = project_run_evidence(partial_stream(), H)
        self.assertEqual(out["evidence_status"], "partial")
        self.assertIsNone(out["outcome"])

    def test_terminal_stream_projects_ready(self):
        out = project_run_evidence(terminal_stream(), H)
        self.assertEqual(out["evidence_status"], "ready")
        self.assertEqual(out["outcome"], "MERGE_READY")
        self.assertEqual(out["stop_reasons"], [])
        self.assertEqual(out["verification_result_refs"], ["v1"])
        self.assertEqual(out["policy_verdicts"], ["ALLOW"])

    def test_projection_is_deterministic(self):
        s = terminal_stream()
        self.assertEqual(project_run_evidence(s, H), project_run_evidence(copy.deepcopy(s), H))

    def test_readable_binding_mismatch_projects_invalid(self):
        s = terminal_stream()
        bad_h = "sha256:" + "9" * 64
        out = project_run_evidence(s, bad_h)
        self.assertEqual(out["evidence_status"], "invalid")
        self.assertEqual(out["harness_manifest_ref"], H)
        self.assertTrue(out["errors"])

    def test_tampered_event_projects_invalid(self):
        s = terminal_stream()
        s[1]["event_ref"] = "sha256:" + "0" * 64
        out = project_run_evidence(s, H)
        self.assertEqual(out["evidence_status"], "invalid")

    def test_post_terminal_event_projects_invalid(self):
        s = terminal_stream()
        extra = ev(
            "worker_completed",
            {"worker_attempt_ref": "w-late", "artifact_ref": "sha256:" + "b" * 64},
            5,
        )
        out = project_run_evidence(s + [extra], H)
        self.assertEqual(out["evidence_status"], "invalid")

    def test_malformed_stream_is_rejected_not_fabricated(self):
        with self.assertRaises(EventParseError):
            project_run_evidence([{"event_type": "worker_completed"}], H)

    def test_producer_cannot_supply_evidence_status(self):
        s = terminal_stream()
        s[1]["evidence_status"] = "ready"
        with self.assertRaises(EventParseError):
            project_run_evidence(s, H)

    def test_missing_decision_reference_projects_invalid(self):
        s = terminal_stream()
        s[-1] = ev(
            "decision_made",
            {
                "decision_ref": "d1",
                "action": "stop",
                "input_refs": ["v1", "missing"],
                "outcome": "MERGE_READY",
                "stop_reasons": [],
                "policy_verdicts": ["ALLOW"],
            },
            4,
        )
        out = project_run_evidence(s, H)
        self.assertEqual(out["evidence_status"], "invalid")
        self.assertIn("decision input", out["errors"][0])

    def test_evidence_refs_are_deduplicated_preserving_order(self):
        s = terminal_stream()
        s[1]["evidence_refs"] = ["shared", "test:pass"]
        # Finalize replacement to keep event_ref valid.
        s[1] = ev(
            "verification_recorded",
            {
                "verification_ref": "v1",
                "verifier_id": "deterministic.tests",
                "kind": "deterministic",
                "status": "pass",
                "bound_artifact_ref": "sha256:" + "a" * 64,
            },
            2,
            ["shared", "test:pass"],
        )
        s[2] = ev(
            "pr_convergence_recorded",
            {
                "convergence_ref": "c1",
                "ci": "pass",
                "required_reviews": "pass",
                "blocking_threads": 0,
                "conflict": False,
                "scope": "pass",
            },
            3,
            ["shared", "pr:convergence"],
        )
        out = project_run_evidence(s, H)
        self.assertEqual(out["evidence_refs"], ["shared", "test:pass", "pr:convergence"])


if __name__ == "__main__":
    unittest.main()
