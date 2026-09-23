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

from decision_core import assess_progress, decide
from run_evidence import project_run_evidence
from run_state import DurableRunStore


def _draft(event_type, payload):
    return {"schema_version": "1", "event_type": event_type, "payload": payload}


def _append(store, state_name, event_type, payload):
    state = store.read_state()
    return store.transition(
        state["revision"], state_name, _draft(event_type, payload)
    )


def _spec_payload(event):
    event_type = event["type"]
    if event_type == "plan_contract_bound":
        return {
            "plan_hash": event["plan_hash"],
            "source_sha": event["source_sha"],
            "evidence_ref": event["evidence_ref"],
        }
    if event_type == "worker_completed":
        return {
            "artifact_ref": event["artifact_ref"],
            "evidence_ref": event["evidence_ref"],
        }
    if event_type == "verification_recorded":
        return {"verification": copy.deepcopy(event["verification"])}
    if event_type == "failure_recorded":
        return {"failure": copy.deepcopy(event["failure"])}
    if event_type == "artifact_changed":
        return {
            "before_artifact_ref": event["before_artifact_ref"],
            "after_artifact_ref": event["after_artifact_ref"],
            "changed_paths": copy.deepcopy(event["changed_paths"]),
            "evidence_ref": event["evidence_ref"],
        }
    if event_type == "repair_attempted":
        return {
            "before_artifact_ref": event["before_artifact_ref"],
            "after_artifact_ref": event["after_artifact_ref"],
            "changed_paths": copy.deepcopy(event.get("changed_paths", [])),
            "evidence_delta": copy.deepcopy(event["evidence_delta"]),
            "resolved_blockers": copy.deepcopy(event["resolved_blockers"]),
            "introduced_blockers": copy.deepcopy(event["introduced_blockers"]),
            "evidence_ref": event["evidence_ref"],
        }
    if event_type == "pr_convergence_recorded":
        return {
            "convergence": copy.deepcopy(event["convergence"]),
            "evidence_refs": copy.deepcopy(event["evidence_refs"]),
        }
    raise ValueError(event_type)


def run_spec_fixture(trace, root):
    if trace.get("authoritative") is not False:
        raise ValueError("only non-authoritative spec fixtures are accepted")

    binding = trace["run_binding"]
    store = DurableRunStore(root)
    store.init({
        "run_id": "fixture-" + trace["scenario"],
        "state": "PLAN_VERIFYING",
        "revision": 0,
        "harness_manifest_ref": binding["harness_manifest_ref"],
        "plan_hash": binding["plan_hash"],
        "source_sha": binding["source_sha"],
    })
    contract = copy.deepcopy(trace["loop_contract"])
    verifications = []
    failures = []
    current_artifact = None
    changed_paths = []
    repair_observation = None
    plan_verified = False

    # Stage-2 decision/progress records are oracle values only. They are not
    # supplied to the owner-backed runtime.
    stimuli = [
        event for event in trace["events"]
        if event["type"] not in {"decision_made", "progress_assessed"}
    ]

    for spec in stimuli:
        event_type = spec["type"]
        payload = _spec_payload(spec)

        if event_type == "plan_contract_bound":
            _append(store, "PLAN_VERIFYING", event_type, payload)
            continue

        if event_type == "verification_recorded":
            verification = payload["verification"]
            state_name = (
                "PLAN_VERIFYING"
                if verification["verifier_id"] == "specification.plan"
                else "VERIFYING"
            )
            _append(store, state_name, event_type, payload)
            verifications.append(verification)
            if verification["verifier_id"] == "specification.plan":
                if (
                    verification["status"] != "pass"
                    or verification["bound_artifact_ref"] != binding["plan_hash"]
                ):
                    raise ValueError("plan verification failed")
                plan_verified = True
                _append(
                    store,
                    "EXECUTING",
                    "decision_made",
                    {
                        "decision": {
                            "action": "continue",
                            "inputs": [verification["id"]],
                            "outcome": None,
                            "stop_reasons": [],
                        }
                    },
                )
            elif verification["kind"] == "deterministic":
                current_artifact = verification["bound_artifact_ref"]
            continue

        if not plan_verified:
            raise ValueError("execute before plan gate")

        if event_type == "worker_completed":
            current_artifact = payload["artifact_ref"]
            _append(store, "VERIFYING", event_type, payload)

        elif event_type == "failure_recorded":
            failures.append(payload["failure"])
            _append(store, "DIAGNOSING", event_type, payload)
            if trace["scenario"] == "no-progress-stop" and len(failures) >= 2:
                if repair_observation is None:
                    raise ValueError("missing repair observation")
                progress = assess_progress(
                    previous_failure=failures[-2],
                    current_failure=failures[-1],
                    before_artifact_ref=repair_observation["before_artifact_ref"],
                    after_artifact_ref=repair_observation["after_artifact_ref"],
                    evidence_delta=repair_observation["evidence_delta"],
                    resolved_blockers=repair_observation["resolved_blockers"],
                    introduced_blockers=repair_observation["introduced_blockers"],
                )
                _append(
                    store,
                    "DIAGNOSING",
                    "progress_assessed",
                    {"progress": progress, "id": "p1"},
                )
                decision = decide(
                    loop_contract=contract,
                    run_state=store.read_state(),
                    verifications=verifications,
                    failures=failures,
                    current_artifact_ref=current_artifact,
                    progress=progress,
                    progress_ref="p1",
                )
                _append(
                    store, "DIAGNOSING", "decision_made", {"decision": decision}
                )
            else:
                decision = decide(
                    loop_contract=contract,
                    run_state=store.read_state(),
                    verifications=verifications,
                    failures=failures,
                    current_artifact_ref=current_artifact,
                )
                _append(
                    store, "REPAIRING", "decision_made", {"decision": decision}
                )

        elif event_type == "artifact_changed":
            changed_paths = list(payload["changed_paths"])
            current_artifact = payload["after_artifact_ref"]
            _append(store, "REPAIRING", event_type, payload)

        elif event_type == "repair_attempted":
            repair_observation = payload
            current_artifact = payload["after_artifact_ref"]
            _append(store, "REPAIRING", event_type, payload)

        elif event_type == "pr_convergence_recorded":
            _append(store, "PR_CONVERGING", event_type, payload)
            decision = decide(
                loop_contract=contract,
                run_state=store.read_state(),
                verifications=verifications,
                failures=failures,
                current_artifact_ref=current_artifact,
                pr_convergence=payload,
                changed_paths=changed_paths,
            )
            _append(
                store, "PR_CONVERGING", "decision_made", {"decision": decision}
            )

        else:
            raise ValueError(event_type)

    events = store.read_events()
    projection = project_run_evidence(
        events, binding["harness_manifest_ref"]
    )
    return {
        "state": store.read_state(),
        "events": events,
        "projection": projection,
    }
