#!/usr/bin/env python3
import copy
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from run_event import (  # noqa: E402
    EventParseError,
    StreamContractError,
    finalize_event,
    validate_append,
    validate_event_draft,
    validate_stream,
)


H = "sha256:" + "1" * 64
P = "sha256:" + "2" * 64
SOURCE = "3" * 40
CTX = {
    "run_id": "run-test-001",
    "harness_manifest_ref": H,
    "plan_hash": P,
    "source_sha": SOURCE,
    "revision": 0,
}


def draft(event_type, payload, evidence_refs=None):
    return {
        "schema_version": "1",
        "event_type": event_type,
        "payload": payload,
        "evidence_refs": list(evidence_refs or []),
    }


def event(event_type, payload, seq, *, revision=0, evidence_refs=None, ctx=None):
    bound = dict(CTX if ctx is None else ctx)
    bound["revision"] = revision
    return finalize_event(draft(event_type, payload, evidence_refs), bound, seq)


def base_stream():
    e1 = event(
        "plan_contract_bound",
        {
            "contract_ref": "loop-contract:test",
            "acceptance_refs": ["ac:delivery"],
            "allowed_scope": ["src/**"],
            "required_verifiers": ["deterministic.tests"],
            "budget": {"max_repair_rounds": 2},
            "task_profile": "test",
        },
        1,
    )
    return [e1]


class EventDraftTests(unittest.TestCase):
    def test_accepts_valid_draft(self):
        d = draft(
            "verification_recorded",
            {
                "verification_ref": "v1",
                "verifier_id": "deterministic.tests",
                "kind": "deterministic",
                "status": "fail",
                "bound_artifact_ref": "sha256:" + "a" * 64,
            },
            ["test:failure"],
        )
        out = validate_event_draft(d)
        self.assertEqual(out["event_type"], "verification_recorded")

    def test_rejects_authoritative_sequence_in_draft(self):
        d = draft("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64})
        d["event_seq"] = 7
        with self.assertRaises(EventParseError):
            validate_event_draft(d)

    def test_rejects_authoritative_ref_in_draft(self):
        d = draft("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64})
        d["event_ref"] = "sha256:" + "f" * 64
        with self.assertRaises(EventParseError):
            validate_event_draft(d)

    def test_rejects_unknown_payload_key(self):
        d = draft(
            "verification_recorded",
            {
                "verification_ref": "v1",
                "verifier_id": "deterministic.tests",
                "kind": "deterministic",
                "status": "fail",
                "bound_artifact_ref": "sha256:" + "a" * 64,
                "surprise": True,
            },
        )
        with self.assertRaises(EventParseError):
            validate_event_draft(d)

    def test_rejects_privacy_sensitive_key(self):
        d = draft(
            "worker_completed",
            {
                "worker_attempt_ref": "w1",
                "artifact_ref": "sha256:" + "a" * 64,
                "raw_transcript": "do not persist",
            },
        )
        with self.assertRaises(EventParseError):
            validate_event_draft(d)

    def test_finalize_is_deterministic(self):
        d = draft("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64})
        a = finalize_event(d, CTX, 2)
        b = finalize_event(d, CTX, 2)
        self.assertEqual(a, b)
        self.assertTrue(a["event_ref"].startswith("sha256:"))


class StreamValidationTests(unittest.TestCase):
    def test_first_event_must_be_seq_one(self):
        e = event("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64}, 2)
        with self.assertRaises(StreamContractError):
            validate_stream([e])

    def test_first_event_must_bind_plan_contract(self):
        e = event("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64}, 1)
        with self.assertRaises(StreamContractError):
            validate_stream([e])

    def test_sequence_gap_rejected(self):
        s = base_stream()
        e3 = event("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64}, 3)
        with self.assertRaises(StreamContractError):
            validate_stream(s + [e3])

    def test_duplicate_sequence_rejected(self):
        s = base_stream()
        e1b = event("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64}, 1)
        with self.assertRaises(StreamContractError):
            validate_stream(s + [e1b])

    def test_event_seq_is_independent_from_revision(self):
        s = base_stream()
        e2 = event(
            "verification_recorded",
            {
                "verification_ref": "v1",
                "verifier_id": "deterministic.tests",
                "kind": "deterministic",
                "status": "fail",
                "bound_artifact_ref": "sha256:" + "a" * 64,
            },
            2,
            revision=0,
        )
        validate_stream(s + [e2])

    def test_harness_drift_rejected(self):
        s = base_stream()
        ctx = dict(CTX)
        ctx["harness_manifest_ref"] = "sha256:" + "9" * 64
        e2 = event("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64}, 2, ctx=ctx)
        with self.assertRaises(StreamContractError):
            validate_stream(s + [e2])

    def test_tampered_event_ref_rejected(self):
        s = base_stream()
        e2 = event("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64}, 2)
        e2["event_ref"] = "sha256:" + "0" * 64
        with self.assertRaises(StreamContractError):
            validate_stream(s + [e2])

    def test_duplicate_accepted_event_ref_rejected(self):
        s = base_stream()
        e2 = event("worker_completed", {"worker_attempt_ref": "w1", "artifact_ref": "sha256:" + "a" * 64}, 2)
        dup = copy.deepcopy(e2)
        dup["event_seq"] = 3
        # Keeping the old ref makes the duplicate/tamper visible.
        with self.assertRaises(StreamContractError):
            validate_stream(s + [e2, dup])

    def test_decision_requires_prior_refs(self):
        s = base_stream()
        d2 = event(
            "decision_made",
            {
                "decision_ref": "d1",
                "action": "repair",
                "input_refs": ["v-missing"],
                "outcome": None,
                "stop_reasons": [],
            },
            2,
        )
        with self.assertRaises(StreamContractError):
            validate_stream(s + [d2])

    def test_decision_accepts_prior_verification_ref(self):
        s = base_stream()
        v2 = event(
            "verification_recorded",
            {
                "verification_ref": "v1",
                "verifier_id": "deterministic.tests",
                "kind": "deterministic",
                "status": "fail",
                "bound_artifact_ref": "sha256:" + "a" * 64,
            },
            2,
        )
        d3 = event(
            "decision_made",
            {
                "decision_ref": "d1",
                "action": "repair",
                "input_refs": ["v1"],
                "outcome": None,
                "stop_reasons": [],
            },
            3,
        )
        validate_stream(s + [v2, d3])

    def test_progress_requires_prior_failure_refs(self):
        s = base_stream()
        p2 = event(
            "progress_assessed",
            {
                "progress_ref": "p1",
                "previous_failure_ref": "f1",
                "current_failure_ref": "f2",
                "artifact_changed": False,
                "evidence_delta": [],
                "resolved_blockers": [],
                "introduced_blockers": [],
                "no_progress": True,
            },
            2,
        )
        with self.assertRaises(StreamContractError):
            validate_stream(s + [p2])

    def test_post_terminal_event_rejected(self):
        s = base_stream()
        d2 = event(
            "decision_made",
            {
                "decision_ref": "d1",
                "action": "stop",
                "input_refs": [s[0]["event_ref"]],
                "outcome": "MERGE_READY",
                "stop_reasons": [],
            },
            2,
        )
        e3 = event("worker_completed", {"worker_attempt_ref": "w2", "artifact_ref": "sha256:" + "b" * 64}, 3)
        with self.assertRaises(StreamContractError):
            validate_stream(s + [d2, e3])

    def test_merge_ready_with_stop_reason_rejected(self):
        with self.assertRaises(EventParseError):
            event(
                "decision_made",
                {
                    "decision_ref": "d1",
                    "action": "stop",
                    "input_refs": ["x"],
                    "outcome": "MERGE_READY",
                    "stop_reasons": ["NO_PROGRESS"],
                },
                2,
            )

    def test_escalation_without_stop_reason_rejected(self):
        with self.assertRaises(EventParseError):
            event(
                "decision_made",
                {
                    "decision_ref": "d1",
                    "action": "stop",
                    "input_refs": ["x"],
                    "outcome": "HUMAN_ESCALATED",
                    "stop_reasons": [],
                },
                2,
            )

    def test_non_stop_action_with_outcome_rejected(self):
        with self.assertRaises(EventParseError):
            event(
                "decision_made",
                {
                    "decision_ref": "d1",
                    "action": "continue",
                    "input_refs": ["x"],
                    "outcome": "MERGE_READY",
                    "stop_reasons": [],
                },
                2,
            )

    def test_validate_append_checks_current_stream_plus_candidate(self):
        s = base_stream()
        bad = event(
            "decision_made",
            {
                "decision_ref": "d1",
                "action": "repair",
                "input_refs": ["future-ref"],
                "outcome": None,
                "stop_reasons": [],
            },
            2,
        )
        with self.assertRaises(StreamContractError):
            validate_append(s, bad)


if __name__ == "__main__":
    unittest.main()
