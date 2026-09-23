#!/usr/bin/env python3
""":"
echo "ERROR: $0 is a Python script; use python3 $0" >&2
exit 2
":"""

from __future__ import annotations

import fnmatch


class DecisionError(ValueError):
    pass


def assess_progress(
    *,
    previous_failure,
    current_failure,
    before_artifact_ref,
    after_artifact_ref,
    evidence_delta,
    resolved_blockers,
    introduced_blockers,
):
    if not isinstance(previous_failure, dict) or not isinstance(current_failure, dict):
        raise DecisionError("failure records required")
    previous = previous_failure.get("fingerprint")
    current = current_failure.get("fingerprint")
    if not previous or not current:
        raise DecisionError("failure fingerprint required")
    for value in (evidence_delta, resolved_blockers, introduced_blockers):
        if not isinstance(value, list):
            raise DecisionError("delta list required")
    artifact_changed = before_artifact_ref != after_artifact_ref
    return {
        "previous_failure_fingerprint": previous,
        "current_failure_fingerprint": current,
        "artifact_changed": artifact_changed,
        "evidence_delta": list(evidence_delta),
        "resolved_blockers": list(resolved_blockers),
        "introduced_blockers": list(introduced_blockers),
        "no_progress": (
            previous == current
            and not artifact_changed
            and not evidence_delta
            and not resolved_blockers
            and not introduced_blockers
        ),
    }


def changed_paths_within_scope(changed_paths, allowed_scope):
    if (
        not isinstance(changed_paths, list)
        or not all(isinstance(path, str) and path for path in changed_paths)
    ):
        raise DecisionError("changed_paths")
    if not isinstance(allowed_scope, list) or not allowed_scope:
        raise DecisionError("allowed_scope")
    return all(
        any(fnmatch.fnmatch(path, pattern) for pattern in allowed_scope)
        for path in changed_paths
    )


def _fresh_deterministic_pass(verifications, artifact_ref):
    for value in reversed(verifications):
        if value.get("kind") != "deterministic":
            continue
        if value.get("bound_artifact_ref") != artifact_ref:
            continue
        return value if value.get("status") == "pass" else None
    return None


def _blocking_deterministic_fail(verifications, artifact_ref):
    return next(
        (
            value
            for value in verifications
            if value.get("kind") == "deterministic"
            and value.get("bound_artifact_ref") == artifact_ref
            and value.get("status") == "fail"
        ),
        None,
    )


def _required_unavailable(verifications, required_verifiers):
    by_id = {}
    for value in verifications:
        by_id[value.get("verifier_id")] = value
    return any(
        by_id.get(verifier_id, {}).get("status") in {"unavailable", "inconclusive"}
        for verifier_id in required_verifiers
    )


def decide(
    *,
    loop_contract,
    run_state,
    verifications,
    failures,
    current_artifact_ref,
    progress=None,
    pr_convergence=None,
    changed_paths=None,
):
    if not isinstance(loop_contract, dict) or not isinstance(run_state, dict):
        raise DecisionError("contract/state")
    if _required_unavailable(
        verifications, list(loop_contract.get("required_verifiers") or [])
    ):
        return {
            "action": "stop",
            "outcome": "BLOCKED",
            "stop_reasons": ["VERIFIER_UNAVAILABLE"],
            "inputs": [],
        }

    if progress is not None and progress.get("no_progress") is True:
        inputs = [failures[-1]["id"]] if failures else []
        return {
            "action": "stop",
            "outcome": "HUMAN_ESCALATED",
            "stop_reasons": ["NO_PROGRESS"],
            "inputs": inputs,
        }

    failure = _blocking_deterministic_fail(verifications, current_artifact_ref)
    if failure is not None:
        failure_record = failures[-1] if failures else None
        if (
            failure_record is None
            or failure["id"] not in failure_record.get("evidence_refs", [])
        ):
            raise DecisionError("blocking failure lacks FailureRecord")
        return {
            "action": "repair",
            "outcome": None,
            "stop_reasons": [],
            "inputs": [failure["id"], failure_record["id"]],
        }

    fresh_pass = _fresh_deterministic_pass(verifications, current_artifact_ref)
    if fresh_pass is not None and pr_convergence is not None:
        expected = {
            "ci": "pass",
            "required_reviews": "pass",
            "blocking_threads": 0,
            "conflict": False,
            "scope": "pass",
        }
        if pr_convergence.get("convergence") == expected:
            refs = pr_convergence.get("evidence_refs") or []
            if not refs:
                raise DecisionError("convergence evidence")
            if changed_paths is not None and not changed_paths_within_scope(
                changed_paths, loop_contract.get("allowed_scope") or []
            ):
                raise DecisionError("changed paths outside allowed scope")
            return {
                "action": "stop",
                "outcome": "MERGE_READY",
                "stop_reasons": [],
                "inputs": [fresh_pass["id"], *refs],
            }

    return {"action": "continue", "outcome": None, "stop_reasons": [], "inputs": []}
