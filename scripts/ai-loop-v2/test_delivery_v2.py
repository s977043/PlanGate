#!/usr/bin/env python3
""":"
echo "ERROR: $0 is a Python script; use python3 $0" >&2
exit 2
":"""

from __future__ import annotations

import copy
import json
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))

from decision_core import (  # noqa: E402
    DecisionError,
    assess_progress,
    changed_paths_within_scope,
)
from delivery_runtime import run_spec_fixture  # noqa: E402
from run_evidence import project_run_evidence  # noqa: E402
from run_event import (  # noqa: E402
    EventContractError,
    finalize_event,
    validate_stream,
)
from run_state import DurableRunStore, StateConflict  # noqa: E402

H = "sha256:" + "1" * 64
P = "sha256:" + "2" * 64
S = "3" * 40
A = "sha256:" + "a" * 64
B = "sha256:" + "b" * 64


def draft(event_type, payload):
    return {"schema_version": "1", "event_type": event_type, "payload": payload}


def context(revision=0):
    return {
        "run_id": "run-1",
        "revision": revision,
        "harness_manifest_ref": H,
        "plan_hash": P,
        "source_sha": S,
    }


def plan_event(seq=1):
    return finalize_event(
        draft(
            "plan_contract_bound",
            {"plan_hash": P, "source_sha": S, "evidence_ref": "plan:bound"},
        ),
        context(),
        seq,
    )


class EventContractTests(unittest.TestCase):
    def test_canonical_event_ref_detects_tamper(self):
        event = plan_event()
        event["payload"]["evidence_ref"] = "tampered"
        with self.assertRaises(EventContractError):
            validate_stream([event])

    def test_private_payload_key_fails_closed(self):
        with self.assertRaises(EventContractError):
            finalize_event(
                {
                    "schema_version": "1",
                    "event_type": "worker_completed",
                    "payload": {
                        "artifact_ref": A,
                        "evidence_ref": "worker:1",
                        "raw_transcript": "do not persist",
                    },
                },
                context(),
                1,
            )

    def test_sequence_gap_and_binding_drift_fail(self):
        first = plan_event()
        second = finalize_event(
            draft("worker_completed", {"artifact_ref": A, "evidence_ref": "worker:1"}),
            context(1),
            2,
        )
        broken = copy.deepcopy(second)
        broken["event_seq"] = 3
        from run_event import digest
        broken["event_ref"] = digest({k: broken[k] for k in broken if k != "event_ref"})
        with self.assertRaises(EventContractError):
            validate_stream([first, broken])

    def test_failure_record_requires_prior_verification(self):
        failure = finalize_event(
            draft(
                "failure_recorded",
                {
                    "failure": {
                        "id": "f1",
                        "observation": "fail",
                        "fingerprint": "fp",
                        "evidence_refs": ["v-missing"],
                        "cause_hypothesis": "bug",
                        "repairability": "repairable",
                        "result": "open",
                    }
                },
            ),
            context(),
            1,
        )
        with self.assertRaises(EventContractError):
            validate_stream([failure])


class ProjectionTests(unittest.TestCase):
    def test_partial_and_invalid_are_receiver_derived(self):
        event = plan_event()
        partial = project_run_evidence([event], H)
        self.assertEqual(partial["evidence_status"], "partial")
        self.assertIsNone(partial["outcome"])

        tampered = copy.deepcopy(event)
        tampered["harness_manifest_ref"] = "sha256:" + "9" * 64
        invalid = project_run_evidence([tampered], H)
        self.assertEqual(invalid["evidence_status"], "invalid")


class StateStoreTests(unittest.TestCase):
    def _initial(self):
        return {
            "run_id": "run-state",
            "state": "PLAN_VERIFYING",
            "revision": 0,
            "harness_manifest_ref": H,
            "plan_hash": P,
            "source_sha": S,
        }

    def _draft(self):
        return draft(
            "plan_contract_bound",
            {"plan_hash": P, "source_sha": S, "evidence_ref": "plan:bound"},
        )

    def test_crash_windows_recover_without_duplicate_visible_effect(self):
        for failpoint in ("journal", "event", "state"):
            with self.subTest(failpoint=failpoint), tempfile.TemporaryDirectory() as tmp:
                store = DurableRunStore(tmp)
                store.init(self._initial())
                with self.assertRaises(RuntimeError):
                    store.transition(
                        0,
                        "PLAN_VERIFYING",
                        self._draft(),
                        test_fail_after=failpoint,
                    )
                recovered = DurableRunStore(tmp)
                self.assertTrue(recovered.recover())
                self.assertEqual(recovered.read_state()["revision"], 1)
                self.assertEqual(len(recovered.read_events()), 1)
                self.assertFalse(recovered.tx_path.exists())

    def test_stale_cas_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = DurableRunStore(tmp)
            store.init(self._initial())
            store.transition(0, "PLAN_VERIFYING", self._draft())
            with self.assertRaises(StateConflict):
                store.transition(0, "EXECUTING", self._draft())


class DecisionTests(unittest.TestCase):
    def test_no_progress_requires_all_meaningful_deltas_empty(self):
        f1 = {"fingerprint": "fp"}
        f2 = {"fingerprint": "fp"}
        value = assess_progress(
            previous_failure=f1,
            current_failure=f2,
            before_artifact_ref=A,
            after_artifact_ref=A,
            evidence_delta=[],
            resolved_blockers=[],
            introduced_blockers=[],
        )
        self.assertTrue(value["no_progress"])
        value = assess_progress(
            previous_failure=f1,
            current_failure=f2,
            before_artifact_ref=A,
            after_artifact_ref=A,
            evidence_delta=[],
            resolved_blockers=[],
            introduced_blockers=["new"],
        )
        self.assertFalse(value["no_progress"])

    def test_scope_is_derived_from_changed_paths(self):
        self.assertTrue(
            changed_paths_within_scope(
                ["fixture://delivery/implementation.py"],
                ["fixture://delivery/**"],
            )
        )
        self.assertFalse(
            changed_paths_within_scope(
                ["outside://forbidden.py"],
                ["fixture://delivery/**"],
            )
        )


class OwnerBackedE2ETests(unittest.TestCase):
    def _fixture(self, name):
        path = REPO / "tests" / "fixtures" / "ai-loop-v2" / "delivery" / name
        return json.loads(path.read_text(encoding="utf-8"))

    def _assert_projection_matches_oracle(self, result, trace):
        expected = trace["expected_projection"]
        actual = result["projection"]
        for key in (
            "outcome",
            "stop_reasons",
            "verification_result_refs",
            "failure_record_refs",
            "evidence_status",
        ):
            self.assertEqual(actual[key], expected[key], key)

    def test_repair_converges_to_merge_ready(self):
        trace = self._fixture("repair-convergence.json")
        with tempfile.TemporaryDirectory() as tmp:
            result = run_spec_fixture(trace, tmp)
        self._assert_projection_matches_oracle(result, trace)
        self.assertEqual(result["projection"]["outcome"], "MERGE_READY")
        self.assertFalse(any(e["event_type"] == "merge_executed" for e in result["events"]))

    def test_no_progress_stops_with_escalation(self):
        trace = self._fixture("no-progress-stop.json")
        with tempfile.TemporaryDirectory() as tmp:
            result = run_spec_fixture(trace, tmp)
        self._assert_projection_matches_oracle(result, trace)
        self.assertEqual(result["projection"]["stop_reasons"], ["NO_PROGRESS"])

    def test_fixture_decisions_are_oracle_only(self):
        trace = self._fixture("repair-convergence.json")
        for event in trace["events"]:
            if event["type"] == "decision_made":
                event["decision"] = {
                    "action": "stop",
                    "inputs": ["oracle:must-not-be-consumed"],
                    "outcome": "BLOCKED",
                    "stop_reasons": ["POLICY_DENIED"],
                }
        with tempfile.TemporaryDirectory() as tmp:
            result = run_spec_fixture(trace, tmp)
        self.assertEqual(result["projection"]["outcome"], "MERGE_READY")

    def test_out_of_scope_observed_change_is_rejected(self):
        trace = self._fixture("repair-convergence.json")
        change = next(e for e in trace["events"] if e["type"] == "artifact_changed")
        change["changed_paths"] = ["outside://forbidden.py"]
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(DecisionError):
                run_spec_fixture(trace, tmp)


if __name__ == "__main__":
    unittest.main()
