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

import fnmatch
import posixpath


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


def _canonical_path(path):
    """Return ``path`` if it is canonical; raise otherwise.

    ``fnmatch`` lets ``*`` cross ``/``, so a path such as
    ``fixture://delivery/../../bin/plangate`` would match
    ``fixture://delivery/**``. Only canonical, relative paths are accepted:
    no empty string, no leading ``/``, and no ``.`` / ``..`` / empty segment.
    """
    if not isinstance(path, str) or not path:
        raise DecisionError("changed_paths: empty path")
    scheme, sep, rest = path.partition("://")
    if not sep:
        scheme, rest = "", path
    if scheme and ("/" in scheme or not scheme.replace("-", "").isalnum()):
        raise DecisionError("changed_paths: invalid scheme: " + path)
    if not rest or rest.startswith("/"):
        raise DecisionError("changed_paths: absolute or empty path: " + path)
    if posixpath.normpath(rest) != rest or ".." in rest.split("/"):
        raise DecisionError("changed_paths: non-canonical path: " + path)
    return path


def changed_paths_within_scope(changed_paths, allowed_scope):
    if not isinstance(changed_paths, list) or not changed_paths:
        # An empty or unobserved change set is not evidence of being in scope.
        raise DecisionError("changed_paths")
    paths = [_canonical_path(path) for path in changed_paths]
    if not isinstance(allowed_scope, list) or not allowed_scope:
        raise DecisionError("allowed_scope")
    return all(
        any(fnmatch.fnmatch(path, pattern) for pattern in allowed_scope)
        for path in paths
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
    # The latest FAIL bound to the current artifact is the one the latest
    # FailureRecord refers to (repeated failures on one artifact).
    return next(
        (
            value
            for value in reversed(verifications)
            if value.get("kind") == "deterministic"
            and value.get("bound_artifact_ref") == artifact_ref
            and value.get("status") == "fail"
        ),
        None,
    )


def _required_verifier_state(verifications, required_verifiers):
    by_id = {}
    for value in verifications:
        by_id[value.get("verifier_id")] = value
    blocked = []
    missing = []
    for verifier_id in required_verifiers:
        value = by_id.get(verifier_id)
        if value is None:
            missing.append(verifier_id)
        elif value.get("status") in {"unavailable", "inconclusive"}:
            blocked.append(value)
    return blocked, missing


def _required_verifiers_fresh_pass(
    verifications, required_verifiers, artifact_ref, plan_hash
):
    """Every required verifier's latest result must be a PASS bound to the
    current artifact (or, for the specification verifier, to the plan)."""
    for verifier_id in required_verifiers:
        latest = next(
            (
                value for value in reversed(verifications)
                if value.get("verifier_id") == verifier_id
            ),
            None,
        )
        if latest is None or latest.get("status") != "pass":
            return False
        bound = latest.get("bound_artifact_ref")
        if latest.get("kind") == "specification":
            if plan_hash is None or bound != plan_hash:
                return False
        elif artifact_ref is None or bound != artifact_ref:
            return False
    return True


def decide(
    *,
    loop_contract,
    run_state,
    verifications,
    failures,
    current_artifact_ref,
    progress=None,
    progress_ref=None,
    pr_convergence=None,
    changed_paths=None,
):
    if not isinstance(loop_contract, dict) or not isinstance(run_state, dict):
        raise DecisionError("contract/state")
    unavailable, missing_required = _required_verifier_state(
        verifications, list(loop_contract.get("required_verifiers") or [])
    )
    if missing_required:
        raise DecisionError(
            "required verifier result missing: " + ",".join(sorted(missing_required))
        )
    if unavailable:
        return {
            "action": "stop",
            "outcome": "BLOCKED",
            "stop_reasons": ["VERIFIER_UNAVAILABLE"],
            "inputs": [value["id"] for value in unavailable],
        }

    if progress is not None and progress.get("no_progress") is True:
        inputs = []
        current_det = next(
            (
                value for value in reversed(verifications)
                if value.get("kind") == "deterministic"
                and value.get("bound_artifact_ref") == current_artifact_ref
            ),
            None,
        )
        if current_det is not None:
            inputs.append(current_det["id"])
        if failures:
            inputs.append(failures[-1]["id"])
        if progress_ref:
            inputs.append(progress_ref)
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
            if not changed_paths_within_scope(
                changed_paths, loop_contract.get("allowed_scope") or []
            ):
                raise DecisionError("changed paths outside allowed scope")
            if not _required_verifiers_fresh_pass(
                verifications,
                list(loop_contract.get("required_verifiers") or []),
                current_artifact_ref,
                run_state.get("plan_hash"),
            ):
                return {
                    "action": "continue",
                    "outcome": None,
                    "stop_reasons": [],
                    "inputs": [],
                }
            return {
                "action": "stop",
                "outcome": "MERGE_READY",
                "stop_reasons": [],
                "inputs": [fresh_pass["id"], *refs],
            }

    return {"action": "continue", "outcome": None, "stop_reasons": [], "inputs": []}
