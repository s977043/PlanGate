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
import hashlib
import json
import re
from typing import Any

from limits import MAX_INPUT_REFS, MAX_REF_CHARS, MAX_REQUIRED_VERIFIERS

SCHEMA_VERSION = "1"
ALLOWED_OUTCOMES = {"MERGE_READY", "HUMAN_ESCALATED", "BLOCKED"}
ALLOWED_STOP_REASONS = {
    "NO_PROGRESS", "REPEATED_FAILURE", "OSCILLATION", "BUDGET_EXHAUSTED",
    "POLICY_DENIED", "VERIFIER_UNAVAILABLE", "REQUIREMENT_CONFLICT",
    "STATE_CONFLICT", "HUMAN_REJECTED",
}
ALLOWED_ACTIONS = {"continue", "repair", "replan", "stop"}
ALLOWED_VERIFICATION = {"pass", "fail", "unavailable", "inconclusive"}
ALLOWED_KINDS = {"deterministic", "specification", "independent_model", "policy"}
ALLOWED_POLICY_VERDICTS = {"AUTO_APPROVED", "HUMAN_REQUIRED", "DENIED"}
ALLOWED_DECIDED_IN_STATES = {"VERIFYING", "DIAGNOSING", "PR_CONVERGING"}
ALLOWED_DECISION_VERDICTS = {"pass", "fail", "unavailable"}
CONVERGENCE_DOMAINS = {
    "ci": {"pass", "fail", "pending"},
    "required_reviews": {"pass", "fail"},
    "scope": {"pass", "fail"},
}
DECISION_REQUIRED_KEYS = {
    "action", "inputs", "outcome", "stop_reasons", "input_last_event_seq",
    "contract_bound_seq", "decided_in_state", "failure_fingerprints", "verdicts",
}
DECISION_OPTIONAL_KEYS = {"artifact_ref"}
BINDING_KEYS = {"run_id", "harness_manifest_ref", "plan_hash", "source_sha", "revision"}
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")
FORBIDDEN_KEYS = {
    "raw_transcript", "transcript", "chain_of_thought", "hidden_cot",
    "hidden_reasoning", "oauth_token", "api_key", "token", "password",
    "secret", "authorization",
}
EVENT_PAYLOAD_KEYS = {
    "plan_contract_bound": {"loop_contract_ref", "required_verifiers", "evidence_ref"},
    "worker_completed": {"artifact_ref", "evidence_ref"},
    "verification_recorded": {"verification"},
    "failure_recorded": {"failure"},
    "artifact_changed": {
        "before_artifact_ref", "after_artifact_ref", "changed_paths", "evidence_ref",
    },
    "repair_attempted": {
        "before_artifact_ref", "after_artifact_ref", "changed_paths",
        "evidence_delta", "resolved_blockers", "introduced_blockers", "evidence_ref",
    },
    "progress_assessed": {"progress", "id"},
    "pr_convergence_recorded": {"convergence", "observed_artifact_ref", "evidence_refs"},
    "policy_verdict_recorded": {"verdict", "observed_artifact_ref", "evidence_refs"},
    "blockers_observed": {"observed_artifact_ref", "blockers", "evidence_refs"},
    "decision_made": {"decision"},
    "state_conflict_recorded": {"expected_revision", "actual_revision", "evidence_ref"},
}
COMMON_ACCEPTED_KEYS = {
    "schema_version", "run_id", "event_seq", "revision", "event_type",
    "harness_manifest_ref", "plan_hash", "source_sha", "payload", "event_ref",
}


class EventContractError(ValueError):
    pass


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical_bytes(value)).hexdigest()


def _walk_keys(node: Any):
    if isinstance(node, dict):
        for key, value in node.items():
            yield key
            yield from _walk_keys(value)
    elif isinstance(node, list):
        for value in node:
            yield from _walk_keys(value)


def _reject_private(node: Any) -> None:
    bad = sorted({
        key for key in _walk_keys(node)
        if isinstance(key, str) and key.lower() in FORBIDDEN_KEYS
    })
    if bad:
        raise EventContractError("forbidden/private keys: " + ",".join(bad))


def _validate_sha256(value, label):
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise EventContractError(label)


def _reject_binding_keys(payload) -> None:
    bad = sorted({key for key in _walk_keys(payload) if key in BINDING_KEYS})
    if bad:
        raise EventContractError("binding keys in payload: " + ",".join(bad))


def _validate_unique_strings(value, label, *, non_empty):
    if (
        not isinstance(value, list)
        or (non_empty and not value)
        or not all(isinstance(item, str) and item for item in value)
        or len(set(value)) != len(value)
    ):
        raise EventContractError(label)


def _validate_non_empty_string(value, label):
    if not isinstance(value, str) or not value:
        raise EventContractError(label)


def _validate_decision(value) -> None:
    if not isinstance(value, dict) or not (
        DECISION_REQUIRED_KEYS <= set(value) <= DECISION_REQUIRED_KEYS | DECISION_OPTIONAL_KEYS
    ):
        raise EventContractError("decision keys")
    if value["action"] not in ALLOWED_ACTIONS:
        raise EventContractError("decision")
    _validate_unique_strings(value["inputs"], "decision inputs", non_empty=False)
    if value["outcome"] is not None and value["outcome"] not in ALLOWED_OUTCOMES:
        raise EventContractError("outcome")
    if (
        not isinstance(value["stop_reasons"], list)
        or any(reason not in ALLOWED_STOP_REASONS for reason in value["stop_reasons"])
    ):
        raise EventContractError("stop_reasons")
    if value["outcome"] == "MERGE_READY" and value["stop_reasons"]:
        raise EventContractError("MERGE_READY reasons")
    if value["outcome"] in {"HUMAN_ESCALATED", "BLOCKED"} and not value["stop_reasons"]:
        raise EventContractError("terminal reasons")
    if type(value["input_last_event_seq"]) is not int or value["input_last_event_seq"] < 0:
        raise EventContractError("input_last_event_seq")
    if type(value["contract_bound_seq"]) is not int or value["contract_bound_seq"] < 1:
        raise EventContractError("contract_bound_seq")
    if value["decided_in_state"] not in ALLOWED_DECIDED_IN_STATES:
        raise EventContractError("decided_in_state")
    _validate_unique_strings(
        value["failure_fingerprints"], "failure_fingerprints", non_empty=False
    )
    verdicts = value["verdicts"]
    if not isinstance(verdicts, dict) or any(
        not isinstance(key, str) or not key or verdict not in ALLOWED_DECISION_VERDICTS
        for key, verdict in verdicts.items()
    ):
        raise EventContractError("verdicts")
    if value["outcome"] == "MERGE_READY" or "artifact_ref" in value:
        _validate_sha256(value.get("artifact_ref"), "decision artifact_ref")


def _validate_payload(event_type: str, payload: dict) -> None:
    _reject_binding_keys(payload)
    if event_type == "plan_contract_bound":
        _validate_sha256(payload.get("loop_contract_ref"), "loop_contract_ref")
        verifiers = payload.get("required_verifiers")
        _validate_unique_strings(verifiers, "required_verifiers", non_empty=True)
        if len(verifiers) > MAX_REQUIRED_VERIFIERS or any(
            not verifier.isascii() or len(verifier) > MAX_REF_CHARS for verifier in verifiers
        ):
            raise EventContractError("required_verifiers")
        _validate_non_empty_string(payload.get("evidence_ref"), "bound evidence_ref")
    elif event_type == "worker_completed":
        _validate_sha256(payload.get("artifact_ref"), "artifact_ref")
    elif event_type == "verification_recorded":
        value = payload.get("verification")
        required = {
            "id", "verifier_id", "kind", "status",
            "bound_artifact_ref", "evidence_refs",
        }
        if not isinstance(value, dict) or set(value) != required:
            raise EventContractError("verification keys")
        if value["kind"] not in ALLOWED_KINDS or value["status"] not in ALLOWED_VERIFICATION:
            raise EventContractError("verification enum")
        _validate_sha256(value["bound_artifact_ref"], "bound_artifact_ref")
        if not isinstance(value["evidence_refs"], list):
            raise EventContractError("verification evidence_refs")
    elif event_type == "failure_recorded":
        value = payload.get("failure")
        required = {
            "id", "observation", "fingerprint", "evidence_refs", "verification_ref",
            "cause_hypothesis", "repairability", "result",
        }
        if not isinstance(value, dict) or set(value) != required:
            raise EventContractError("failure keys")
        if not value["observation"] or not value["fingerprint"] or not isinstance(value["evidence_refs"], list):
            raise EventContractError("failure")
        _validate_non_empty_string(value["verification_ref"], "failure verification_ref")
    elif event_type in {"artifact_changed", "repair_attempted"}:
        _validate_sha256(payload.get("before_artifact_ref"), "before_artifact_ref")
        _validate_sha256(payload.get("after_artifact_ref"), "after_artifact_ref")
        if (
            "changed_paths" in payload
            and (
                not isinstance(payload["changed_paths"], list)
                or not all(isinstance(path, str) for path in payload["changed_paths"])
            )
        ):
            raise EventContractError("changed_paths")
        if event_type == "repair_attempted":
            for key in ("evidence_delta", "resolved_blockers", "introduced_blockers"):
                if not isinstance(payload.get(key), list):
                    raise EventContractError(key)
    elif event_type == "progress_assessed":
        value = payload.get("progress")
        required = {
            "previous_failure_fingerprint", "current_failure_fingerprint",
            "artifact_changed", "evidence_delta", "resolved_blockers",
            "introduced_blockers", "no_progress",
        }
        if not isinstance(value, dict) or set(value) != required:
            raise EventContractError("progress keys")
        if type(value["artifact_changed"]) is not bool or type(value["no_progress"]) is not bool:
            raise EventContractError("progress bool")
        for key in ("evidence_delta", "resolved_blockers", "introduced_blockers"):
            if not isinstance(value[key], list):
                raise EventContractError(key)
    elif event_type == "pr_convergence_recorded":
        value = payload.get("convergence")
        required = {"ci", "required_reviews", "blocking_threads", "conflict", "scope"}
        if not isinstance(value, dict) or set(value) != required:
            raise EventContractError("convergence keys")
        for key, domain in CONVERGENCE_DOMAINS.items():
            if value[key] not in domain:
                raise EventContractError("convergence " + key)
        if type(value["blocking_threads"]) is not int or value["blocking_threads"] < 0:
            raise EventContractError("convergence blocking_threads")
        if type(value["conflict"]) is not bool:
            raise EventContractError("convergence conflict")
        _validate_sha256(payload.get("observed_artifact_ref"), "convergence observed_artifact_ref")
        _validate_unique_strings(payload.get("evidence_refs"), "convergence evidence", non_empty=True)
    elif event_type == "policy_verdict_recorded":
        if payload.get("verdict") not in ALLOWED_POLICY_VERDICTS:
            raise EventContractError("policy verdict")
        _validate_sha256(payload.get("observed_artifact_ref"), "policy observed_artifact_ref")
        _validate_unique_strings(payload.get("evidence_refs"), "policy evidence", non_empty=True)
    elif event_type == "blockers_observed":
        _validate_sha256(payload.get("observed_artifact_ref"), "blockers observed_artifact_ref")
        _validate_unique_strings(payload.get("blockers"), "blockers", non_empty=False)
        _validate_unique_strings(payload.get("evidence_refs"), "blockers evidence", non_empty=True)
    elif event_type == "decision_made":
        _validate_decision(payload.get("decision"))
    elif event_type == "state_conflict_recorded":
        if type(payload.get("expected_revision")) is not int or type(payload.get("actual_revision")) is not int:
            raise EventContractError("revision conflict")


def validate_event_draft(draft: dict) -> dict:
    if not isinstance(draft, dict):
        raise EventContractError("draft must be object")
    _reject_private(draft)
    if set(draft) - {"schema_version", "event_type", "payload"}:
        raise EventContractError("draft contains authoritative/unknown keys")
    if draft.get("schema_version") != SCHEMA_VERSION:
        raise EventContractError("schema_version")
    event_type = draft.get("event_type")
    if event_type not in EVENT_PAYLOAD_KEYS:
        raise EventContractError("event_type")
    payload = draft.get("payload")
    if not isinstance(payload, dict) or set(payload) - EVENT_PAYLOAD_KEYS[event_type]:
        raise EventContractError("payload keys")
    _validate_payload(event_type, payload)
    return copy.deepcopy(draft)


def finalize_event(draft: dict, bound_context: dict, event_seq: int) -> dict:
    draft = validate_event_draft(draft)
    if type(event_seq) is not int or event_seq < 1:
        raise EventContractError("event_seq")
    required = {"run_id", "harness_manifest_ref", "plan_hash", "source_sha"}
    if not isinstance(bound_context, dict) or not required.issubset(bound_context):
        raise EventContractError("bound context missing")
    _validate_sha256(bound_context["harness_manifest_ref"], "harness_manifest_ref")
    _validate_sha256(bound_context["plan_hash"], "plan_hash")
    if COMMIT_RE.fullmatch(str(bound_context["source_sha"])) is None:
        raise EventContractError("source_sha")
    event = {
        "schema_version": SCHEMA_VERSION,
        "run_id": bound_context["run_id"],
        "event_seq": event_seq,
        "revision": bound_context.get("revision"),
        "event_type": draft["event_type"],
        "harness_manifest_ref": bound_context["harness_manifest_ref"],
        "plan_hash": bound_context["plan_hash"],
        "source_sha": bound_context["source_sha"],
        "payload": copy.deepcopy(draft["payload"]),
    }
    event["event_ref"] = digest(event)
    return validate_event(event)


def validate_event(event: dict) -> dict:
    if not isinstance(event, dict):
        raise EventContractError("event")
    _reject_private(event)
    if set(event) != COMMON_ACCEPTED_KEYS:
        raise EventContractError("accepted event keys")
    if event.get("schema_version") != SCHEMA_VERSION:
        raise EventContractError("schema_version")
    if type(event.get("event_seq")) is not int or event["event_seq"] < 1:
        raise EventContractError("event_seq")
    if event.get("revision") is not None and type(event["revision"]) is not int:
        raise EventContractError("revision")
    if not isinstance(event.get("run_id"), str) or not event["run_id"]:
        raise EventContractError("run_id")
    _validate_sha256(event.get("harness_manifest_ref"), "harness_manifest_ref")
    _validate_sha256(event.get("plan_hash"), "plan_hash")
    if COMMIT_RE.fullmatch(str(event.get("source_sha"))) is None:
        raise EventContractError("source_sha")
    event_type = event.get("event_type")
    if event_type not in EVENT_PAYLOAD_KEYS:
        raise EventContractError("event_type")
    payload = event.get("payload")
    if not isinstance(payload, dict) or set(payload) - EVENT_PAYLOAD_KEYS[event_type]:
        raise EventContractError("payload keys")
    _validate_payload(event_type, payload)
    expected = digest({key: event[key] for key in event if key != "event_ref"})
    if event.get("event_ref") != expected:
        raise EventContractError("event_ref mismatch")
    return copy.deepcopy(event)


def _registered_refs(event: dict):
    payload = event["payload"]
    event_type = event["event_type"]
    refs = []
    if payload.get("evidence_ref"):
        refs.append(payload["evidence_ref"])
    refs += list(payload.get("evidence_refs") or [])
    if payload.get("id"):
        refs.append(payload["id"])
    if event_type == "verification_recorded":
        refs.append(payload["verification"]["id"])
    if event_type == "failure_recorded":
        refs.append(payload["failure"]["id"])
    return refs


def _latest(segment, event_type):
    return next((event for event in reversed(segment) if event["event_type"] == event_type), None)


def _validate_merge_ready(bound, segment, decision) -> None:
    if bound is None:
        raise EventContractError("MERGE_READY without plan_contract_bound")
    verified = {
        event["payload"]["verification"]["verifier_id"]
        for event in segment
        if event["event_type"] == "verification_recorded"
    }
    missing = set(bound["payload"]["required_verifiers"]) - verified
    if missing:
        raise EventContractError("MERGE_READY without required verifiers: " + ",".join(sorted(missing)))
    convergence = _latest(segment, "pr_convergence_recorded")
    if convergence is None:
        raise EventContractError("MERGE_READY without pr_convergence_recorded")
    value = convergence["payload"]["convergence"]
    if (
        value["ci"] != "pass"
        or value["required_reviews"] != "pass"
        or value["blocking_threads"] != 0
        or value["conflict"] is not False
        or value["scope"] != "pass"
    ):
        raise EventContractError("MERGE_READY with non-pass convergence")
    policy = _latest(segment, "policy_verdict_recorded")
    if policy is not None and policy["payload"]["verdict"] in {"DENIED", "HUMAN_REQUIRED"}:
        raise EventContractError("MERGE_READY with policy " + policy["payload"]["verdict"])
    blockers = _latest(segment, "blockers_observed")
    if blockers is not None and blockers["payload"]["blockers"]:
        raise EventContractError("MERGE_READY with blockers")
    for observed in (convergence, policy, blockers):
        if observed is not None and observed["payload"]["observed_artifact_ref"] != decision["artifact_ref"]:
            raise EventContractError("MERGE_READY observed_artifact_ref mismatch")


def validate_stream(events: list[dict]) -> list[dict]:
    if not isinstance(events, list) or not events:
        raise EventContractError("events")
    clean = [validate_event(event) for event in events]
    refs = {}
    verification_ids = set()
    terminal_seen = False
    base = clean[0]
    segment_binding = (base["plan_hash"], base["source_sha"])
    bound = None
    segment = []
    last_decision_seq = None
    for expected_seq, event in enumerate(clean, start=1):
        event_type = event["event_type"]
        if event["event_seq"] != expected_seq:
            raise EventContractError("event_seq must be contiguous from 1")
        if any(event[key] != base[key] for key in ("run_id", "harness_manifest_ref")):
            raise EventContractError("binding drift")
        if event_type == "plan_contract_bound":
            segment_binding = (event["plan_hash"], event["source_sha"])
        elif (event["plan_hash"], event["source_sha"]) != segment_binding:
            raise EventContractError("binding drift")
        if event["event_ref"] in refs:
            raise EventContractError("duplicate event_ref")
        if terminal_seen:
            raise EventContractError("event after terminal")
        if event_type == "failure_recorded":
            failure = event["payload"]["failure"]
            for ref in failure["evidence_refs"]:
                if ref not in refs:
                    raise EventContractError(f"failure evidence missing/future: {ref}")
            if failure["verification_ref"] not in verification_ids:
                raise EventContractError(
                    "failure verification_ref missing/future: " + failure["verification_ref"]
                )
        if event_type == "decision_made":
            decision = event["payload"]["decision"]
            for ref in decision["inputs"]:
                if ref not in refs:
                    raise EventContractError(f"decision input missing/future: {ref}")
            if decision["input_last_event_seq"] != event["event_seq"] - 1:
                raise EventContractError("input_last_event_seq must be event_seq - 1")
            if bound is not None and decision["contract_bound_seq"] != bound["event_seq"]:
                raise EventContractError("contract_bound_seq must be the latest bound")
            if last_decision_seq is not None and not any(
                refs[ref] > last_decision_seq for ref in decision["inputs"]
            ):
                raise EventContractError("decision inputs predate the previous decision")
            last_decision_seq = event["event_seq"]
            if decision["outcome"] is not None:
                terminal_seen = True
            if decision["outcome"] == "MERGE_READY":
                _validate_merge_ready(bound, segment, decision)
        for ref in _registered_refs(event):
            if not isinstance(ref, str) or not ref or ref in refs:
                raise EventContractError("duplicate/empty evidence ref")
            refs[ref] = event["event_seq"]
        refs[event["event_ref"]] = event["event_seq"]
        if event_type == "verification_recorded":
            verification_ids.add(event["payload"]["verification"]["id"])
        if event_type == "plan_contract_bound":
            bound = event
            segment = []
        else:
            segment.append(event)
    return clean


def _validate_append_only(candidate: dict) -> None:
    event = validate_event(candidate)
    if event["event_type"] == "decision_made":
        decision = event["payload"]["decision"]
        if len(decision["inputs"]) > MAX_INPUT_REFS:
            raise EventContractError("decision inputs exceed MAX_INPUT_REFS")
        if decision["input_last_event_seq"] != event["event_seq"] - 1:
            raise EventContractError("input_last_event_seq must be event_seq - 1")


def validate_append(current_stream: list[dict], candidate: dict) -> list[dict]:
    _validate_append_only(candidate)
    return validate_stream([*current_stream, candidate])
