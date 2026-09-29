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
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))

from decision_core import (  # noqa: E402
    DecisionError,
    assess_progress,
    changed_paths_within_scope,
    decide,
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
            self.assertEqual(store.read_state()["revision"], 1)
            self.assertEqual(len(store.read_events()), 2)
            self.assertEqual(store.read_events()[-1]["event_type"], "state_conflict_recorded")


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


    def test_missing_required_verifier_fails_closed(self):
        with self.assertRaises(DecisionError):
            decide(
                loop_contract={"required_verifiers": ["deterministic.tests", "completion.evidence"]},
                run_state={"state": "VERIFYING"},
                verifications=[
                    {
                        "id": "v-pass",
                        "verifier_id": "deterministic.tests",
                        "kind": "deterministic",
                        "status": "pass",
                        "bound_artifact_ref": A,
                        "evidence_refs": ["test:pass"],
                    }
                ],
                failures=[],
                current_artifact_ref=A,
            )

    def test_unavailable_verifier_is_decision_provenance(self):
        result = decide(
            loop_contract={"required_verifiers": ["deterministic.tests", "completion.evidence"]},
            run_state={"state": "VERIFYING"},
            verifications=[
                {
                    "id": "v-pass",
                    "verifier_id": "deterministic.tests",
                    "kind": "deterministic",
                    "status": "pass",
                    "bound_artifact_ref": A,
                    "evidence_refs": ["test:pass"],
                },
                {
                    "id": "v-missing",
                    "verifier_id": "completion.evidence",
                    "kind": "deterministic",
                    "status": "unavailable",
                    "bound_artifact_ref": A,
                    "evidence_refs": ["verification:missing"],
                },
            ],
            failures=[],
            current_artifact_ref=A,
        )
        self.assertEqual(result["outcome"], "BLOCKED")
        self.assertEqual(result["inputs"], ["v-missing"])


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


C = "sha256:" + "c" * 64
CONVERGED = {
    "convergence": {
        "ci": "pass",
        "required_reviews": "pass",
        "blocking_threads": 0,
        "conflict": False,
        "scope": "pass",
    },
    "evidence_refs": ["pr:convergence"],
}
SCOPE = ["fixture://delivery/**"]
IN_SCOPE = ["fixture://delivery/implementation.py"]


def verification(vid, verifier_id, kind, status, artifact):
    return {
        "id": vid,
        "verifier_id": verifier_id,
        "kind": kind,
        "status": status,
        "bound_artifact_ref": artifact,
        "evidence_refs": ["evidence:" + vid],
    }


def plan_pass():
    return verification("pv1", "specification.plan", "specification", "pass", P)


class ReviewRegressionTests(unittest.TestCase):
    """Regression tests for the adversarial review of PR #1402 (major 1-5)."""

    def _fixture(self, name):
        path = REPO / "tests" / "fixtures" / "ai-loop-v2" / "delivery" / name
        return json.loads(path.read_text(encoding="utf-8"))

    def _run(self, trace):
        with tempfile.TemporaryDirectory() as tmp:
            return run_spec_fixture(trace, tmp)

    def _assert_not_merge_ready(self, fn):
        try:
            result = fn()
        except ValueError:
            return
        outcome = result.get("outcome")
        if outcome is None and "projection" in result:
            outcome = result["projection"]["outcome"]
        self.assertNotEqual(outcome, "MERGE_READY")

    def _decide(self, *, required, verifications, current, changed_paths=IN_SCOPE,
                failures=None):
        return decide(
            loop_contract={"required_verifiers": required, "allowed_scope": SCOPE},
            run_state={"state": "PR_CONVERGING", "plan_hash": P},
            verifications=verifications,
            failures=failures or [],
            current_artifact_ref=current,
            pr_convergence=CONVERGED,
            changed_paths=changed_paths,
        )

    # --- major 1: verification must not rebind the current artifact -------
    def test_verification_cannot_rebind_current_artifact(self):
        trace = self._fixture("repair-convergence.json")
        v3 = next(
            e for e in trace["events"]
            if e["type"] == "verification_recorded"
            and e["verification"]["id"] == "v3"
        )
        v3["verification"]["bound_artifact_ref"] = C
        self._assert_not_merge_ready(lambda: self._run(trace))

    # --- major 2: required verifier FAIL / stale blocks MERGE_READY -------
    def test_required_non_deterministic_fail_blocks_merge_ready(self):
        self._assert_not_merge_ready(lambda: self._decide(
            required=["specification.plan", "deterministic.tests", "independent.review"],
            verifications=[
                plan_pass(),
                verification("v1", "deterministic.tests", "deterministic", "pass", A),
                verification("v2", "independent.review", "independent_model", "fail", A),
            ],
            current=A,
        ))

    def test_required_verifier_stale_pass_blocks_merge_ready(self):
        self._assert_not_merge_ready(lambda: self._decide(
            required=["specification.plan", "deterministic.tests", "independent.review"],
            verifications=[
                plan_pass(),
                verification("v1", "independent.review", "independent_model", "pass", A),
                verification("v2", "deterministic.tests", "deterministic", "pass", B),
            ],
            current=B,
        ))

    def test_required_verifiers_all_fresh_pass_is_merge_ready(self):
        result = self._decide(
            required=["specification.plan", "deterministic.tests", "independent.review"],
            verifications=[
                plan_pass(),
                verification("v1", "deterministic.tests", "deterministic", "pass", A),
                verification("v2", "independent.review", "independent_model", "pass", A),
            ],
            current=A,
        )
        self.assertEqual(result["outcome"], "MERGE_READY")

    # --- major 3: scope must be observed and normalized -------------------
    def test_empty_or_unobserved_changed_paths_fail_closed(self):
        for paths in ([], None):
            with self.subTest(paths=paths):
                self._assert_not_merge_ready(lambda: self._decide(
                    required=["deterministic.tests"],
                    verifications=[
                        verification("v1", "deterministic.tests", "deterministic", "pass", A),
                    ],
                    current=A,
                    changed_paths=paths,
                ))

    def test_runtime_empty_changed_paths_fail_closed(self):
        trace = self._fixture("repair-convergence.json")
        change = next(e for e in trace["events"] if e["type"] == "artifact_changed")
        change["changed_paths"] = []
        self._assert_not_merge_ready(lambda: self._run(trace))

    def test_non_canonical_paths_are_rejected(self):
        for path in (
            "fixture://delivery/../../bin/plangate",
            "fixture://delivery/./implementation.py",
            "fixture://delivery//implementation.py",
            "/fixture://delivery/implementation.py",
            "fixture:///etc/passwd",
            "../fixture://delivery/implementation.py",
        ):
            with self.subTest(path=path):
                try:
                    within = changed_paths_within_scope([path], SCOPE)
                except DecisionError:
                    continue
                self.assertFalse(within)

    def test_repair_attempted_paths_are_scope_checked(self):
        trace = self._fixture("repair-convergence.json")
        change = next(e for e in trace["events"] if e["type"] == "artifact_changed")
        change["type"] = "repair_attempted"
        change["changed_paths"] = ["outside://forbidden.py"]
        change["evidence_delta"] = ["test:failure-1"]
        change["resolved_blockers"] = []
        change["introduced_blockers"] = []
        self._assert_not_merge_ready(lambda: self._run(trace))

    # --- major 4: NO_PROGRESS is observation-driven, latest FAIL is used --
    def test_no_progress_does_not_depend_on_scenario_name(self):
        trace = self._fixture("no-progress-stop.json")
        trace["scenario"] = "renamed-scenario"
        result = self._run(trace)
        self.assertEqual(result["projection"]["outcome"], "HUMAN_ESCALATED")
        self.assertEqual(result["projection"]["stop_reasons"], ["NO_PROGRESS"])

    def test_observed_progress_continues_repair_without_scenario_name(self):
        trace = self._fixture("no-progress-stop.json")
        trace["scenario"] = "progress-observed"
        repair = next(e for e in trace["events"] if e["type"] == "repair_attempted")
        repair["after_artifact_ref"] = B
        repair["changed_paths"] = IN_SCOPE
        v2 = next(
            e for e in trace["events"]
            if e["type"] == "verification_recorded"
            and e["verification"]["id"] == "v2"
        )
        v2["verification"]["bound_artifact_ref"] = B
        result = self._run(trace)
        progress = [e for e in result["events"] if e["event_type"] == "progress_assessed"]
        self.assertEqual(len(progress), 1)
        self.assertFalse(progress[0]["payload"]["progress"]["no_progress"])
        last = result["events"][-1]
        self.assertEqual(last["event_type"], "decision_made")
        self.assertEqual(last["payload"]["decision"]["action"], "repair")
        self.assertEqual(last["payload"]["decision"]["inputs"], ["v2", "f2"])
        self.assertIsNone(result["projection"]["outcome"])

    def test_repeated_fail_on_same_artifact_uses_latest_failure(self):
        result = decide(
            loop_contract={"required_verifiers": ["deterministic.tests"]},
            run_state={"state": "DIAGNOSING"},
            verifications=[
                verification("v1", "deterministic.tests", "deterministic", "fail", A),
                verification("v2", "deterministic.tests", "deterministic", "fail", A),
            ],
            failures=[
                {"id": "f1", "fingerprint": "fp", "evidence_refs": ["v1"]},
                {"id": "f2", "fingerprint": "fp", "evidence_refs": ["v2"]},
            ],
            current_artifact_ref=A,
        )
        self.assertEqual(result["action"], "repair")
        self.assertEqual(result["inputs"], ["v2", "f2"])

    # --- major 5 (mutation M2): stale deterministic PASS is not reusable --
    def test_stale_deterministic_pass_is_not_merge_ready(self):
        self._assert_not_merge_ready(lambda: self._decide(
            required=[],
            verifications=[
                verification("v1", "deterministic.tests", "deterministic", "pass", A),
            ],
            current=B,
        ))

    # --- minor: terminal outcome ends stimulus processing -----------------
    def test_stimulus_after_terminal_outcome_is_not_processed(self):
        trace = self._fixture("repair-convergence.json")
        trace["events"].append({
            "seq": 99,
            "type": "verification_recorded",
            "verification": verification(
                "v9", "deterministic.tests", "deterministic", "pass", B
            ),
        })
        result = self._run(trace)
        self.assertEqual(result["projection"]["outcome"], "MERGE_READY")
        self.assertNotIn("v9", result["projection"]["verification_result_refs"])


if __name__ == "__main__":
    unittest.main()
