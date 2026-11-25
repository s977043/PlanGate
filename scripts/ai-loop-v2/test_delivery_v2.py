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


BOUND_PAYLOAD = {
    "loop_contract_ref": "sha256:" + "d" * 64,
    "required_verifiers": ["deterministic.tests"],
    "evidence_ref": "plan:bound",
}


def plan_event(seq=1):
    return finalize_event(
        draft("plan_contract_bound", copy.deepcopy(BOUND_PAYLOAD)),
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
                        "verification_ref": "v-missing",
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
        return draft("plan_contract_bound", copy.deepcopy(BOUND_PAYLOAD))

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


# --- TASK-1391 Phase 1B (plan Revision 2.5, test-cases.md Revision 2〜2.5) ---

import run_event as RE  # noqa: E402
import run_evidence as REV  # noqa: E402
from unittest import mock  # noqa: E402
from run_event import digest, validate_append, validate_event_draft  # noqa: E402

L_REF = BOUND_PAYLOAD["loop_contract_ref"]
P2 = "sha256:" + "e" * 64
S2 = "4" * 40
PASSED = {
    "ci": "pass",
    "required_reviews": "pass",
    "blocking_threads": 0,
    "conflict": False,
    "scope": "pass",
}


def raw_event(event_type, payload, seq, ctx=None):
    """An accepted-shaped event that skips per-event validation (load-layer input)."""
    ctx = ctx or context()
    event = {
        "schema_version": "1",
        "run_id": ctx["run_id"],
        "event_seq": seq,
        "revision": ctx.get("revision"),
        "event_type": event_type,
        "harness_manifest_ref": ctx["harness_manifest_ref"],
        "plan_hash": ctx["plan_hash"],
        "source_sha": ctx["source_sha"],
        "payload": copy.deepcopy(payload),
    }
    event["event_ref"] = digest(event)
    return event


def bound_payload(required=("deterministic.tests",), evidence="plan:bound"):
    return {
        "loop_contract_ref": L_REF,
        "required_verifiers": list(required),
        "evidence_ref": evidence,
    }


def verification_payload(vid, status="pass", artifact=B, verifier_id="deterministic.tests"):
    return {"verification": verification(vid, verifier_id, "deterministic", status, artifact)}


def convergence_payload(evidence="pr:conv", observed=B, convergence=None):
    return {
        "convergence": copy.deepcopy(convergence or PASSED),
        "observed_artifact_ref": observed,
        "evidence_refs": [evidence],
    }


def failure_payload(fid, verification_ref, evidence_refs=None):
    return {
        "failure": {
            "id": fid,
            "observation": "fail",
            "fingerprint": "fp",
            "evidence_refs": list(evidence_refs or [verification_ref]),
            "verification_ref": verification_ref,
            "cause_hypothesis": "bug",
            "repairability": "repairable",
            "result": "open",
        }
    }


def decision_payload(seq, inputs, *, outcome="MERGE_READY", action=None,
                     stop_reasons=(), bound_seq=1, state="PR_CONVERGING",
                     artifact=B, verdicts=None, fingerprints=()):
    value = {
        "action": action or ("stop" if outcome else "continue"),
        "inputs": list(inputs),
        "outcome": outcome,
        "stop_reasons": list(stop_reasons),
        "input_last_event_seq": seq - 1,
        "contract_bound_seq": bound_seq,
        "decided_in_state": state,
        "failure_fingerprints": list(fingerprints),
        "verdicts": dict(verdicts or {"deterministic.tests": "pass"}),
    }
    if artifact is not None:
        value["artifact_ref"] = artifact
    return {"decision": value}


class Stream:
    """Builds a stream; `add` finalizes, `raw` bypasses per-event validation."""

    def __init__(self):
        self.events = []
        self.ctx = context()

    @property
    def next_seq(self):
        return len(self.events) + 1

    def add(self, event_type, payload, ctx=None):
        event = finalize_event(draft(event_type, payload), ctx or self.ctx, self.next_seq)
        self.events.append(event)
        return event

    def raw(self, event_type, payload, ctx=None):
        event = raw_event(event_type, payload, self.next_seq, ctx or self.ctx)
        self.events.append(event)
        return event


def merge_ready_prefix():
    """bound(1) -> worker(2) -> v1 PASS(3) -> convergence(4). Decision goes at 5."""
    s = Stream()
    s.add("plan_contract_bound", bound_payload())
    s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
    s.add("verification_recorded", verification_payload("v1"))
    s.add("pr_convergence_recorded", convergence_payload())
    return s


def merge_ready_stream():
    s = merge_ready_prefix()
    s.add("decision_made", decision_payload(s.next_seq, ["v1", "pr:conv"]))
    return s


class Phase1BLayerMixin:
    def assert_append_rejects(self, events):
        with self.assertRaises(EventContractError):
            validate_append(events[:-1], events[-1])

    def assert_load_invalid(self, events):
        self.assertEqual(project_run_evidence(events, H)["evidence_status"], "invalid")

    def assert_both_reject(self, events):
        self.assert_append_rejects(events)
        self.assert_load_invalid(events)

    def assert_both_accept(self, events, status=None):
        validate_append(events[:-1], events[-1])
        projection = project_run_evidence(events, H)
        self.assertNotEqual(projection["evidence_status"], "invalid", projection)
        if status is not None:
            self.assertEqual(projection["evidence_status"], status)

    def assert_draft_rejected(self, event_type, payload):
        with self.assertRaises(EventContractError):
            validate_event_draft(draft(event_type, payload))


class Phase1BSegmentTests(Phase1BLayerMixin, unittest.TestCase):
    """P1B-1 / P1B-2 / P1B-3 (EV-11〜15, EV-13a, EV-21a, EV-29, EV-30)."""

    def _replan_stream(self, ctx2):
        s = merge_ready_prefix()
        s.events.pop()  # drop convergence; re-bind first
        s.add("plan_contract_bound", bound_payload(evidence="plan:bound-2"), ctx2)
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:2"}, ctx2)
        s.add("verification_recorded", verification_payload("v2"), ctx2)
        s.add("pr_convergence_recorded", convergence_payload(), ctx2)
        s.add(
            "decision_made",
            decision_payload(s.next_seq, ["v2", "pr:conv"], bound_seq=4),
            ctx2,
        )
        return s

    def test_ev11_second_bound_opens_new_segment(self):
        ctx2 = dict(context(), plan_hash=P2, source_sha=S2)
        s = self._replan_stream(ctx2)
        self.assert_both_accept(s.events, "ready")

    def test_ev12_second_bound_cannot_change_manifest(self):
        ctx2 = dict(context(), plan_hash=P2, source_sha=S2,
                    harness_manifest_ref="sha256:" + "9" * 64)
        s = self._replan_stream(ctx2)
        self.assert_both_reject(s.events)

    def test_ev13_contract_bound_seq_must_be_latest_bound(self):
        ctx2 = dict(context(), plan_hash=P2, source_sha=S2)
        s = self._replan_stream(ctx2)
        last = s.events.pop()
        s.raw("decision_made", dict(last["payload"], decision=dict(
            last["payload"]["decision"], contract_bound_seq=1)), ctx2)
        self.assert_both_reject(s.events)

    def test_ev13a_binding_drift_without_bound_is_invalid(self):
        s = Stream()
        s.add("plan_contract_bound", bound_payload())
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"},
              dict(context(), plan_hash=P2))
        self.assert_both_reject(s.events)

    def test_ev14_draft_binding_keys_rejected_at_any_depth(self):
        validate_event_draft(draft("plan_contract_bound", bound_payload()))
        for key, value in (("plan_hash", P), ("source_sha", S),
                           ("run_id", "run-1"), ("harness_manifest_ref", H),
                           ("revision", 0)):
            with self.subTest(key=key):
                self.assert_draft_rejected(
                    "plan_contract_bound", dict(bound_payload(), **{key: value}))
        nested = verification_payload("v1")
        nested["verification"]["plan_hash"] = P
        self.assert_draft_rejected("verification_recorded", nested)

    def test_ev15_binding_only_from_bound_context(self):
        bad = dict(draft("plan_contract_bound", bound_payload()), plan_hash=P)
        with self.assertRaises(EventContractError):
            validate_event_draft(bad)

    def test_ev21a_contract_bound_seq_only_in_decision(self):
        payload = {"artifact_ref": B, "evidence_ref": "worker:1", "contract_bound_seq": 1}
        self.assert_draft_rejected("worker_completed", payload)
        s = Stream()
        s.add("plan_contract_bound", bound_payload())
        s.raw("worker_completed", payload)
        self.assert_load_invalid(s.events)

    def test_ev29_input_last_event_seq_must_be_adjacent(self):
        s = merge_ready_prefix()
        payload = decision_payload(s.next_seq, ["v1", "pr:conv"])
        payload["decision"]["input_last_event_seq"] = s.next_seq - 2
        s.raw("decision_made", payload)
        self.assert_both_reject(s.events)

    def test_ev30_adjacent_input_last_event_seq_is_accepted(self):
        self.assert_both_accept(merge_ready_stream().events, "ready")


class Phase1BPayloadTests(Phase1BLayerMixin, unittest.TestCase):
    """P1B-4 / P1B-5 / P1B-9 / P1B-10 payload shapes (EV-16〜20, EV-31〜33a, EV-18a/b)."""

    def _load_with(self, event_type, payload):
        s = Stream()
        s.add("plan_contract_bound", bound_payload())
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v1"))
        s.raw(event_type, payload)
        return s.events

    def _reject_both(self, event_type, payload):
        self.assert_draft_rejected(event_type, payload)
        self.assert_load_invalid(self._load_with(event_type, payload))

    def test_ev16_bound_payload_shape(self):
        validate_event_draft(draft("plan_contract_bound", bound_payload()))
        too_many = ["verifier.%d" % i for i in range(17)]
        cases = {
            "missing loop_contract_ref": {k: v for k, v in bound_payload().items()
                                          if k != "loop_contract_ref"},
            "bad loop_contract_ref": dict(bound_payload(), loop_contract_ref="x"),
            "missing required_verifiers": {k: v for k, v in bound_payload().items()
                                           if k != "required_verifiers"},
            "empty required_verifiers": bound_payload(required=()),
            "duplicate required_verifiers": bound_payload(required=("a", "a")),
            "over MAX_REQUIRED_VERIFIERS": bound_payload(required=too_many),
        }
        for label, payload in cases.items():
            with self.subTest(label):
                self.assert_draft_rejected("plan_contract_bound", payload)
                s = Stream()
                s.raw("plan_contract_bound", payload)
                self.assert_load_invalid(s.events)

    def test_ev17_failure_verification_ref(self):
        missing = failure_payload("f1", "v1")
        del missing["failure"]["verification_ref"]
        self._reject_both("failure_recorded", missing)
        for label, ref in (("unknown", "v-missing"), ("not a verification", "worker:1")):
            with self.subTest(label):
                payload = failure_payload("f1", ref, evidence_refs=["v1"])
                events = self._load_with("failure_recorded", payload)
                self.assert_both_reject(events)
        future = Stream()
        future.add("plan_contract_bound", bound_payload())
        future.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        future.add("verification_recorded", verification_payload("v1"))
        future.add("failure_recorded", failure_payload("f1", "v2", evidence_refs=["v1"]))
        future.add("verification_recorded", verification_payload("v2"))
        self.assert_load_invalid(future.events)

    def test_pj19_failure_verification_ref_checked_on_load(self):
        events = self._load_with("failure_recorded",
                                 failure_payload("f1", "v-missing", evidence_refs=["v1"]))
        self.assertEqual(validate_stream_status(events), "invalid")

    def test_ev18_convergence_observed_artifact_ref_required(self):
        payload = convergence_payload()
        del payload["observed_artifact_ref"]
        self._reject_both("pr_convergence_recorded", payload)

    def test_ev18a_observed_ref_inside_convergence_rejected(self):
        payload = convergence_payload()
        del payload["observed_artifact_ref"]
        payload["convergence"]["observed_artifact_ref"] = B
        self._reject_both("pr_convergence_recorded", payload)

    def test_ev18b_observed_ref_at_top_level_accepted(self):
        events = self._load_with("pr_convergence_recorded", convergence_payload())
        self.assert_both_accept(events)

    def test_ev19_ev31a_convergence_domain(self):
        bad = {
            "ci": "passed", "required_reviews": "ok", "scope": "maybe",
            "blocking_threads": True, "conflict": 0,
        }
        for key, value in bad.items():
            with self.subTest(key=key):
                self._reject_both("pr_convergence_recorded", convergence_payload(
                    convergence=dict(PASSED, **{key: value})))
        with self.subTest("negative threads"):
            self._reject_both("pr_convergence_recorded", convergence_payload(
                convergence=dict(PASSED, blocking_threads=-1)))
        with self.subTest("freshness field"):
            self._reject_both("pr_convergence_recorded",
                              dict(convergence_payload(), observed_at="2026-11-26T00:00:00Z"))

    def test_ev31_convergence_domain_accepts_valid_values(self):
        for convergence in (PASSED, dict(PASSED, ci="fail", required_reviews="fail",
                                         blocking_threads=3, conflict=True, scope="fail"),
                            dict(PASSED, ci="pending")):
            with self.subTest(convergence=convergence):
                self.assert_both_accept(self._load_with(
                    "pr_convergence_recorded", convergence_payload(convergence=convergence)))

    def test_ev20_ev33a_blockers_shape(self):
        base = {"observed_artifact_ref": B, "blockers": ["check:ci"],
                "evidence_refs": ["blockers:1"]}
        cases = {
            "duplicate": dict(base, blockers=["a", "a"]),
            "non-list": dict(base, blockers="a"),
            "non-string": dict(base, blockers=[1]),
            "missing ref": {k: v for k, v in base.items() if k != "observed_artifact_ref"},
            "bad ref": dict(base, observed_artifact_ref="x"),
            "empty evidence": dict(base, evidence_refs=[]),
            "hypothesis key": dict(base, cause_hypothesis="flaky"),
        }
        for label, payload in cases.items():
            with self.subTest(label):
                self._reject_both("blockers_observed", payload)

    def test_ev33_empty_blocker_snapshot_accepted(self):
        payload = {"observed_artifact_ref": B, "blockers": [], "evidence_refs": ["blockers:1"]}
        self.assert_both_accept(self._load_with("blockers_observed", payload))

    def test_policy_verdict_shape(self):
        base = {"verdict": "AUTO_APPROVED", "observed_artifact_ref": B,
                "evidence_refs": ["policy:1"]}
        self.assert_both_accept(self._load_with("policy_verdict_recorded", base))
        cases = {
            "verdict": dict(base, verdict="APPROVED"),
            "ref": dict(base, observed_artifact_ref="x"),
            "empty evidence": dict(base, evidence_refs=[]),
            "duplicate evidence": dict(base, evidence_refs=["p", "p"]),
            "extra key": dict(base, observed_at="now"),
        }
        for label, payload in cases.items():
            with self.subTest(label):
                self._reject_both("policy_verdict_recorded", payload)


def validate_stream_status(events):
    return project_run_evidence(events, H)["evidence_status"]


class Phase1BDecisionTests(Phase1BLayerMixin, unittest.TestCase):
    """P1B-7 (EV-21〜23, EV-32/32a/32b, EV-28j/l/m, EV-34)."""

    def _with_decision(self, mutate):
        s = merge_ready_prefix()
        payload = decision_payload(s.next_seq, ["v1", "pr:conv"])
        mutate(payload["decision"])
        s.raw("decision_made", payload)
        return s.events

    def test_ev21_ev32_decision_key_set(self):
        for key in ("input_last_event_seq", "contract_bound_seq", "decided_in_state",
                    "failure_fingerprints", "verdicts", "action", "inputs"):
            with self.subTest(missing=key):
                self.assert_both_reject(self._with_decision(lambda d, k=key: d.pop(k)))
        with self.subTest("extra key"):
            self.assert_both_reject(self._with_decision(lambda d: d.update(extra=1)))

    def test_ev32a_ev32b_decision_domains(self):
        cases = {
            "EXECUTING": lambda d: d.update(decided_in_state="EXECUTING"),
            "PLAN_VERIFYING": lambda d: d.update(decided_in_state="PLAN_VERIFYING"),
            "verdict ok": lambda d: d.update(verdicts={"deterministic.tests": "ok"}),
            "fingerprints dup": lambda d: d.update(failure_fingerprints=["fp", "fp"]),
            "bool seq": lambda d: d.update(input_last_event_seq=True),
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                self.assert_both_reject(self._with_decision(mutate))

    def test_ev28j_merge_ready_requires_artifact_ref(self):
        self.assert_both_reject(self._with_decision(lambda d: d.pop("artifact_ref")))

    def _non_terminal_decision(self, artifact):
        s = Stream()
        s.add("plan_contract_bound", bound_payload())
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v1", status="fail"))
        s.add("failure_recorded", failure_payload("f1", "v1"))
        payload = decision_payload(
            s.next_seq, ["v1", "f1"], outcome=None, action="repair",
            state="DIAGNOSING", artifact=artifact,
            verdicts={"deterministic.tests": "fail"}, fingerprints=["fp"])
        s.raw("decision_made", payload)
        return s.events

    def test_ev28l_non_merge_ready_decision_artifact_ref_optional(self):
        self.assert_both_accept(self._non_terminal_decision(None), "partial")

    def test_ev28m_non_merge_ready_decision_artifact_ref_form(self):
        self.assert_both_reject(self._non_terminal_decision("not-a-ref"))

    def test_ev23_inputs_must_include_refs_after_prior_decision(self):
        events = self._non_terminal_decision(B)
        s = Stream()
        s.events = events
        s.add("pr_convergence_recorded", convergence_payload())
        s.raw("decision_made", decision_payload(
            s.next_seq, ["v1"], outcome=None, action="continue", artifact=B))
        self.assert_both_reject(s.events)

    def test_ev22_input_refs_count_rechecked_at_append_only(self):
        import limits
        self.assertEqual(RE.MAX_INPUT_REFS, limits.MAX_INPUT_REFS)
        events = merge_ready_stream().events
        with mock.patch.object(RE, "MAX_INPUT_REFS", 1):
            with self.assertRaises(EventContractError):
                validate_append(events[:-1], events[-1])
            # EV-34: append-only checks are not re-applied on load.
            validate_stream(events)
            self.assertEqual(validate_stream_status(events), "ready")

    @unittest.skip("#1623 待ち（H-10 = c）: MAX_DECISION_EVENT_BYTES が limits.py に入った後に外す")
    def test_ev22_decision_event_bytes_rechecked_at_append_only(self):
        import limits
        self.assertEqual(RE.MAX_DECISION_EVENT_BYTES, limits.MAX_DECISION_EVENT_BYTES)
        events = merge_ready_stream().events
        size = len(RE.canonical_bytes(events[-1]))
        with mock.patch.object(RE, "MAX_DECISION_EVENT_BYTES", size - 1):
            with self.assertRaises(EventContractError):
                validate_append(events[:-1], events[-1])
            validate_stream(events)


class Phase1BReadyTests(Phase1BLayerMixin, unittest.TestCase):
    """P1B-6 / D-5 / D-8 (PJ-12〜18, PJ-21, EV-28a/c/d/e/g/i/n)."""

    def test_pj18_complete_merge_ready_is_ready(self):
        self.assertEqual(validate_stream_status(merge_ready_stream().events), "ready")

    def test_pj21_unfinished_stream_is_partial(self):
        self.assertEqual(validate_stream_status(merge_ready_prefix().events), "partial")

    def test_pj12_merge_ready_without_bound_is_invalid(self):
        s = Stream()
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v1"))
        s.add("pr_convergence_recorded", convergence_payload())
        s.raw("decision_made", decision_payload(s.next_seq, ["v1", "pr:conv"]))
        self.assert_both_reject(s.events)

    def test_pj13_missing_required_verifier_is_invalid(self):
        s = Stream()
        s.add("plan_contract_bound",
              bound_payload(required=("deterministic.tests", "independent.review")))
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v1"))
        s.add("pr_convergence_recorded", convergence_payload())
        s.raw("decision_made", decision_payload(s.next_seq, ["v1", "pr:conv"]))
        self.assert_both_reject(s.events)

    def test_pj14_verification_before_latest_bound_does_not_count(self):
        s = Stream()
        s.add("plan_contract_bound", bound_payload())
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v1"))
        s.add("plan_contract_bound", bound_payload(evidence="plan:bound-2"))
        s.add("pr_convergence_recorded", convergence_payload())
        s.raw("decision_made", decision_payload(s.next_seq, ["v1", "pr:conv"], bound_seq=4))
        self.assert_both_reject(s.events)

    def test_pj16_blocked_without_bound_is_terminal_unready(self):
        s = Stream()
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v1", status="unavailable"))
        s.add("decision_made", decision_payload(
            s.next_seq, ["v1"], outcome="BLOCKED", stop_reasons=["VERIFIER_UNAVAILABLE"],
            state="VERIFYING", verdicts={"deterministic.tests": "unavailable"}))
        self.assertEqual(validate_stream_status(s.events), "terminal_unready")

    def test_pj17_human_escalated_missing_verifier_is_terminal_unready(self):
        s = Stream()
        s.add("plan_contract_bound",
              bound_payload(required=("deterministic.tests", "independent.review")))
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v1", status="fail"))
        s.add("failure_recorded", failure_payload("f1", "v1"))
        s.add("decision_made", decision_payload(
            s.next_seq, ["v1", "f1"], outcome="HUMAN_ESCALATED",
            stop_reasons=["NO_PROGRESS"], state="DIAGNOSING",
            verdicts={"deterministic.tests": "fail"}, fingerprints=["fp"]))
        self.assertEqual(validate_stream_status(s.events), "terminal_unready")

    def _merge_ready_after(self, *extra):
        s = merge_ready_prefix()
        for event_type, payload in extra:
            s.add(event_type, payload)
        inputs = ["v1", "pr:conv"]
        s.raw("decision_made", decision_payload(s.next_seq, inputs))
        return s

    def test_ev28a_policy_denied_or_human_required_blocks_merge_ready(self):
        for verdict in ("DENIED", "HUMAN_REQUIRED"):
            with self.subTest(verdict=verdict):
                s = self._merge_ready_after(("policy_verdict_recorded", {
                    "verdict": verdict, "observed_artifact_ref": B,
                    "evidence_refs": ["policy:1"]}))
                self.assert_both_reject(s.events)

    def test_ev28c_non_pass_convergence_blocks_merge_ready(self):
        for key, value in (("ci", "fail"), ("required_reviews", "fail"),
                           ("blocking_threads", 1), ("conflict", True), ("scope", "fail")):
            with self.subTest(key=key):
                s = self._merge_ready_after(("pr_convergence_recorded", convergence_payload(
                    evidence="pr:conv-2", convergence=dict(PASSED, **{key: value}))))
                self.assert_both_reject(s.events)

    def test_ev28d_non_empty_blockers_block_merge_ready(self):
        s = self._merge_ready_after(("blockers_observed", {
            "observed_artifact_ref": B, "blockers": ["check:ci"],
            "evidence_refs": ["blockers:1"]}))
        self.assert_both_reject(s.events)

    def test_ev28e_merge_ready_without_convergence_is_invalid(self):
        s = merge_ready_prefix()
        s.events.pop()
        s.raw("decision_made", decision_payload(s.next_seq, ["v1"]))
        self.assert_both_reject(s.events)

    def test_ev28g_observed_ref_must_match_merge_ready_artifact(self):
        cases = {
            "convergence": ("pr_convergence_recorded",
                            convergence_payload(evidence="pr:conv-2", observed=C)),
            "policy": ("policy_verdict_recorded", {
                "verdict": "AUTO_APPROVED", "observed_artifact_ref": C,
                "evidence_refs": ["policy:1"]}),
            "blockers": ("blockers_observed", {
                "observed_artifact_ref": C, "blockers": [], "evidence_refs": ["blockers:1"]}),
        }
        for label, extra in cases.items():
            with self.subTest(label):
                self.assert_both_reject(self._merge_ready_after(extra).events)

    def test_ev28i_convergence_without_observed_ref_is_invalid(self):
        s = merge_ready_prefix()
        s.events.pop()
        payload = convergence_payload()
        del payload["observed_artifact_ref"]
        s.raw("pr_convergence_recorded", payload)
        s.raw("decision_made", decision_payload(s.next_seq, ["v1", "pr:conv"]))
        self.assert_both_reject(s.events)

    def test_ev28n_only_merge_ready_decision_artifact_is_compared(self):
        s = Stream()
        s.add("plan_contract_bound", bound_payload())
        s.add("worker_completed", {"artifact_ref": B, "evidence_ref": "worker:1"})
        s.add("verification_recorded", verification_payload("v0", status="fail"))
        s.add("failure_recorded", failure_payload("f1", "v0"))
        s.add("decision_made", decision_payload(
            s.next_seq, ["v0", "f1"], outcome=None, action="repair", state="DIAGNOSING",
            artifact=C, verdicts={"deterministic.tests": "fail"}, fingerprints=["fp"]))
        s.add("verification_recorded", verification_payload("v1"))
        s.add("pr_convergence_recorded", convergence_payload())
        s.add("decision_made", decision_payload(s.next_seq, ["v1", "pr:conv"]))
        self.assert_both_accept(s.events, "ready")

    def test_ev28h_policy_and_blockers_absence_still_ready_under_d9(self):
        self.assertEqual(validate_stream_status(merge_ready_stream().events), "ready")


class Phase1BProjectionTests(unittest.TestCase):
    """P1B-5 / P1B-11 (PJ-04b, PJ-11, PJ-15)."""

    def test_pj04b_unusable_input_raises(self):
        error = getattr(REV, "UnusableStreamError", None)
        self.assertIsNotNone(error)
        self.assertFalse(issubclass(error, EventContractError))
        for value in ([], "events", None, [1], [merge_ready_stream().events[0], "x"]):
            with self.subTest(value=value):
                with self.assertRaises(error):
                    project_run_evidence(value, H)

    def test_pj11_policy_verdicts_are_derived_from_events(self):
        s = merge_ready_prefix()
        event = s.add("policy_verdict_recorded", {
            "verdict": "AUTO_APPROVED", "observed_artifact_ref": B,
            "evidence_refs": ["policy:1"]})
        projection = project_run_evidence(s.events, H)
        self.assertEqual(projection["policy_verdicts"], [{
            "event_ref": event["event_ref"],
            "verdict": "AUTO_APPROVED",
            "observed_artifact_ref": B,
        }])

    def test_pj15_producer_evidence_status_is_unknown_key(self):
        payload = dict(decision_payload(5, ["v1", "pr:conv"]), evidence_status="ready")
        with self.assertRaises(EventContractError):
            validate_event_draft(draft("decision_made", payload))

    def test_ev35_unknown_event_type_fails_closed(self):
        with self.assertRaises(EventContractError):
            validate_event_draft(draft("state_conflict_v2", {}))

    def test_ev36_legacy_state_conflict_name_is_still_known(self):
        validate_event_draft(draft("state_conflict_recorded", {
            "expected_revision": 0, "actual_revision": 1, "evidence_ref": "c:1"}))


class Phase1BRuntimeTests(unittest.TestCase):
    """D-10 / D-13 / D-16 / P1B-11 on the producer (EV-28h/k/o, PJ-20, PJ-22, PJ-24)."""

    def _fixture(self, name):
        path = REPO / "tests" / "fixtures" / "ai-loop-v2" / "delivery" / name
        return json.loads(path.read_text(encoding="utf-8"))

    def _run(self, trace):
        with tempfile.TemporaryDirectory() as tmp:
            return run_spec_fixture(trace, tmp)

    def test_ev28k_ev28o_repair_path_refs_and_no_plan_gate_decision(self):
        result = self._run(self._fixture("repair-convergence.json"))
        events = result["events"]
        self.assertEqual(result["projection"]["evidence_status"], "ready")
        types = [e["event_type"] for e in events]
        plan_idx = next(i for i, e in enumerate(events)
                        if e["event_type"] == "verification_recorded"
                        and e["payload"]["verification"]["verifier_id"] == "specification.plan")
        worker_idx = types.index("worker_completed")
        self.assertNotIn("decision_made", types[plan_idx:worker_idx])
        convergence = next(e for e in events if e["event_type"] == "pr_convergence_recorded")
        final = events[-1]["payload"]["decision"]
        self.assertEqual(final["outcome"], "MERGE_READY")
        self.assertEqual(final["artifact_ref"], convergence["payload"]["observed_artifact_ref"])
        for event in events:
            if event["event_type"] == "decision_made":
                decision = event["payload"]["decision"]
                self.assertEqual(decision["input_last_event_seq"], event["event_seq"] - 1)
                self.assertIn(decision["decided_in_state"],
                              {"VERIFYING", "DIAGNOSING", "PR_CONVERGING"})

    def test_ev28l_pj22_pj24_no_progress_is_terminal_unready(self):
        trace = self._fixture("no-progress-stop.json")
        self.assertEqual(trace["expected_projection"]["evidence_status"], "terminal_unready")
        result = self._run(trace)
        self.assertEqual(result["projection"]["evidence_status"], "terminal_unready")
        for event in result["events"]:
            if event["event_type"] == "decision_made":
                self.assertNotEqual(event["payload"]["decision"]["outcome"], "MERGE_READY")

    def test_pj20_unusable_stream_fails_delivery(self):
        trace = self._fixture("repair-convergence.json")
        trace["events"] = []
        with self.assertRaises(ValueError):
            self._run(trace)


if __name__ == "__main__":
    unittest.main()
