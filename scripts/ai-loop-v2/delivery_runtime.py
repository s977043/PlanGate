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
from run_event import digest
from run_evidence import UnusableStreamError, project_run_evidence
from run_state import DurableRunStore

_DECISION_VERDICTS = {"pass": "pass", "fail": "fail"}


def _draft(event_type, payload):
    return {"schema_version": "1", "event_type": event_type, "payload": payload}


def _append(store, state_name, event_type, payload):
    state = store.read_state()
    return store.transition(
        state["revision"], state_name, _draft(event_type, payload)
    )


def _verdicts(required_verifiers, verifications):
    verdicts = {}
    for verifier_id in required_verifiers:
        latest = next(
            (value for value in reversed(verifications) if value["verifier_id"] == verifier_id),
            None,
        )
        if latest is not None:
            verdicts[verifier_id] = _DECISION_VERDICTS.get(latest["status"], "unavailable")
    return verdicts


def _spec_payload(event, contract):
    event_type = event["type"]
    if event_type == "plan_contract_bound":
        return {
            "loop_contract_ref": digest(contract),
            "required_verifiers": list(contract["required_verifiers"]),
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
            "observed_artifact_ref": event.get("observed_artifact_ref"),
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
    # current_artifact may only be moved by worker_completed /
    # artifact_changed / repair_attempted. A verification never rebinds it.
    current_artifact = None
    # Union of observed changed paths. None means "not observed yet"; the
    # decision core fails closed on an unobserved or empty change set.
    changed_paths = None
    repair_observation = None
    plan_verified = False
    progress_count = 0
    terminal = False
    contract_bound_seq = None

    # Stage-2 decision/progress records are oracle values only. They are not
    # supplied to the owner-backed runtime.
    stimuli = [
        event for event in trace["events"]
        if event["type"] not in {"decision_made", "progress_assessed"}
    ]

    def _observe_paths(paths):
        nonlocal changed_paths
        merged = list(changed_paths or [])
        for path in paths:
            if path not in merged:
                merged.append(path)
        changed_paths = merged

    def _record_decision(state_name, decided_in_state, decision):
        nonlocal terminal
        decision = dict(
            decision,
            input_last_event_seq=len(store.read_events()),
            contract_bound_seq=contract_bound_seq,
            decided_in_state=decided_in_state,
            failure_fingerprints=list(dict.fromkeys(f["fingerprint"] for f in failures)),
            verdicts=_verdicts(contract["required_verifiers"], verifications),
        )
        if current_artifact is not None:
            decision["artifact_ref"] = current_artifact
        elif decision.get("outcome") == "MERGE_READY":
            raise ValueError("MERGE_READY without current artifact")
        _append(store, state_name, "decision_made", {"decision": decision})
        if decision.get("outcome") is not None:
            terminal = True

    for spec in stimuli:
        if terminal:
            # A terminal outcome ends the run; later stimuli are not processed.
            break
        event_type = spec["type"]
        payload = _spec_payload(spec, contract)

        if event_type == "plan_contract_bound":
            _, bound_event = _append(store, "PLAN_VERIFYING", event_type, payload)
            contract_bound_seq = bound_event["event_seq"]
            continue

        if event_type == "verification_recorded":
            verification = payload["verification"]
            if (
                verification["verifier_id"] != "specification.plan"
                and verification["bound_artifact_ref"] != current_artifact
            ):
                # Stale / detached verification: it is not bound to the
                # artifact the Worker actually produced.
                raise ValueError(
                    "verification not bound to current artifact: "
                    + verification["id"]
                )
            is_plan = verification["verifier_id"] == "specification.plan"
            plan_passed = (
                is_plan
                and verification["status"] == "pass"
                and verification["bound_artifact_ref"] == binding["plan_hash"]
            )
            if plan_passed:
                state_name = "EXECUTING"
            elif is_plan:
                state_name = "PLAN_VERIFYING"
            else:
                state_name = "VERIFYING"
            _append(store, state_name, event_type, payload)
            verifications.append(verification)
            if is_plan:
                if not plan_passed:
                    raise ValueError("plan verification failed")
                plan_verified = True
            continue

        if not plan_verified:
            raise ValueError("execute before plan gate")

        if event_type == "worker_completed":
            current_artifact = payload["artifact_ref"]
            _append(store, "VERIFYING", event_type, payload)

        elif event_type == "failure_recorded":
            failures.append(payload["failure"])
            _append(store, "DIAGNOSING", event_type, payload)
            if len(failures) >= 2 and repair_observation is not None:
                progress_count += 1
                progress_ref = "p%d" % progress_count
                progress = assess_progress(
                    previous_failure=failures[-2],
                    current_failure=failures[-1],
                    before_artifact_ref=repair_observation["before_artifact_ref"],
                    after_artifact_ref=repair_observation["after_artifact_ref"],
                    evidence_delta=repair_observation["evidence_delta"],
                    resolved_blockers=repair_observation["resolved_blockers"],
                    introduced_blockers=repair_observation["introduced_blockers"],
                )
                # The observation is consumed: a later failure needs a new one.
                repair_observation = None
                _append(
                    store,
                    "DIAGNOSING",
                    "progress_assessed",
                    {"progress": progress, "id": progress_ref},
                )
                decision = decide(
                    loop_contract=contract,
                    run_state=store.read_state(),
                    verifications=verifications,
                    failures=failures,
                    current_artifact_ref=current_artifact,
                    progress=progress,
                    progress_ref=progress_ref,
                )
                _record_decision(
                    "DIAGNOSING" if decision["outcome"] else "REPAIRING",
                    "DIAGNOSING",
                    decision,
                )
            else:
                decision = decide(
                    loop_contract=contract,
                    run_state=store.read_state(),
                    verifications=verifications,
                    failures=failures,
                    current_artifact_ref=current_artifact,
                )
                _record_decision("REPAIRING", "DIAGNOSING", decision)

        elif event_type == "artifact_changed":
            _observe_paths(payload["changed_paths"])
            current_artifact = payload["after_artifact_ref"]
            _append(store, "REPAIRING", event_type, payload)

        elif event_type == "repair_attempted":
            repair_observation = payload
            _observe_paths(payload["changed_paths"])
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
            _record_decision("PR_CONVERGING", "PR_CONVERGING", decision)

        else:
            raise ValueError(event_type)

    events = store.read_events()
    try:
        projection = project_run_evidence(
            events, binding["harness_manifest_ref"]
        )
    except UnusableStreamError as exc:
        raise ValueError("delivery produced no usable event stream") from exc
    return {
        "state": store.read_state(),
        "events": events,
        "projection": projection,
    }
