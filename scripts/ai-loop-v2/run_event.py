#!/usr/bin/env python3
"""ai-loop V2 RunEvent contract and stream validation.

TASK-1391 / #1391.

This module intentionally owns *event semantics only*.
It does not persist events, allocate durable state, acquire locks, or perform I/O.
Durable sequence allocation / commit belongs to #1392.
"""

from __future__ import annotations

import copy
import hashlib
import json
import re
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = "1"

_SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
_COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")

_ALLOWED_VERIFICATION_STATUS = {"pass", "fail", "unavailable", "inconclusive"}
_ALLOWED_VERIFICATION_KIND = {
    "deterministic",
    "specification",
    "independent_model",
    "policy",
}
_ALLOWED_ACTIONS = {"continue", "repair", "replan", "stop"}
_ALLOWED_OUTCOMES = {
    "MERGE_READY",
    "HUMAN_ESCALATED",
    "HUMAN_REJECTED",
    "BLOCKED",
}
_ALLOWED_STOP_REASONS = {
    "NO_PROGRESS",
    "REPEATED_FAILURE",
    "OSCILLATION",
    "BUDGET_EXHAUSTED",
    "POLICY_DENIED",
    "VERIFIER_UNAVAILABLE",
    "REQUIREMENT_CONFLICT",
    "STATE_CONFLICT",
}

_FORBIDDEN_PRIVACY_KEYS = {
    "raw_transcript",
    "transcript",
    "chain_of_thought",
    "chainofthought",
    "reasoning_content",
    "hidden_reasoning",
    "api_key",
    "access_token",
    "refresh_token",
    "password",
    "secret_value",
    "credential_value",
    "authorization_header",
}

_DRAFT_KEYS = {"schema_version", "event_type", "payload", "evidence_refs"}
_EVENT_REQUIRED_KEYS = {
    "schema_version",
    "run_id",
    "event_seq",
    "event_type",
    "harness_manifest_ref",
    "payload",
    "evidence_refs",
    "event_ref",
}
_EVENT_OPTIONAL_KEYS = {"revision", "plan_hash", "source_sha"}
_CONTEXT_KEYS = {
    "run_id",
    "harness_manifest_ref",
    "revision",
    "plan_hash",
    "source_sha",
}

# Strict first-slice payload schemas. The vocabulary is intentionally bounded.
_EVENT_SPECS: dict[str, tuple[set[str], set[str]]] = {
    "plan_contract_bound": (
        {"contract_ref"},
        {
            "acceptance_refs",
            "allowed_scope",
            "required_verifiers",
            "budget",
            "task_profile",
        },
    ),
    "worker_completed": (
        {"worker_attempt_ref", "artifact_ref"},
        {"provider", "control_status"},
    ),
    "verification_recorded": (
        {
            "verification_ref",
            "verifier_id",
            "kind",
            "status",
            "bound_artifact_ref",
        },
        {"source_sha", "head_sha"},
    ),
    "failure_recorded": (
        {
            "failure_ref",
            "observation",
            "fingerprint",
            "cause_hypothesis",
            "repairability",
            "result",
        },
        set(),
    ),
    "artifact_changed": (
        {
            "change_ref",
            "before_artifact_ref",
            "after_artifact_ref",
            "changed_paths",
        },
        set(),
    ),
    "repair_attempted": (
        {
            "repair_ref",
            "before_artifact_ref",
            "after_artifact_ref",
            "evidence_delta",
            "resolved_blockers",
            "introduced_blockers",
        },
        set(),
    ),
    "progress_assessed": (
        {
            "progress_ref",
            "previous_failure_ref",
            "current_failure_ref",
            "artifact_changed",
            "evidence_delta",
            "resolved_blockers",
            "introduced_blockers",
            "no_progress",
        },
        set(),
    ),
    "pr_convergence_recorded": (
        {
            "convergence_ref",
            "ci",
            "required_reviews",
            "blocking_threads",
            "conflict",
            "scope",
        },
        set(),
    ),
    "decision_made": (
        {
            "decision_ref",
            "action",
            "input_refs",
            "outcome",
            "stop_reasons",
        },
        {"policy_verdicts"},
    ),
    "state_transitioned": (
        {
            "transition_ref",
            "from_state",
            "to_state",
            "expected_revision",
            "new_revision",
        },
        set(),
    ),
    "state_conflict": (
        {"conflict_ref", "expected_revision", "actual_revision"},
        set(),
    ),
}

_REF_FIELDS_BY_EVENT = {
    "plan_contract_bound": ("contract_ref",),
    "worker_completed": ("worker_attempt_ref",),
    "verification_recorded": ("verification_ref",),
    "failure_recorded": ("failure_ref",),
    "artifact_changed": ("change_ref",),
    "repair_attempted": ("repair_ref",),
    "progress_assessed": ("progress_ref",),
    "pr_convergence_recorded": ("convergence_ref",),
    "decision_made": ("decision_ref",),
    "state_transitioned": ("transition_ref",),
    "state_conflict": ("conflict_ref",),
}


class EventError(ValueError):
    """Base class for V2 event contract errors."""


class EventParseError(EventError):
    """Structurally unusable event/draft. No RunEvidence should be fabricated."""


class StreamContractError(EventError):
    """Readable event/stream that violates V2 contract invariants."""


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _require(condition: bool, message: str, exc=EventParseError) -> None:
    if not condition:
        raise exc(message)


def _require_string(value: Any, label: str) -> str:
    _require(isinstance(value, str) and bool(value), f"{label}: non-empty string required")
    return value


def _require_string_list(value: Any, label: str) -> list[str]:
    _require(isinstance(value, list), f"{label}: list required")
    out: list[str] = []
    seen: set[str] = set()
    for item in value:
        s = _require_string(item, f"{label}[]")
        _require(s not in seen, f"{label}: duplicate value {s!r}")
        seen.add(s)
        out.append(s)
    return out


def _require_sha256(value: Any, label: str) -> str:
    _require(isinstance(value, str) and _SHA256_RE.fullmatch(value) is not None,
             f"{label}: sha256:<64 lowercase hex> required")
    return value


def _require_commit(value: Any, label: str) -> str:
    _require(isinstance(value, str) and _COMMIT_RE.fullmatch(value) is not None,
             f"{label}: 7-40 lowercase git hex required")
    return value


def _scan_privacy(value: Any, path: str = "$") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            _require(isinstance(key, str), f"{path}: object key must be string")
            normalized = key.lower().replace("-", "_")
            _require(
                normalized not in _FORBIDDEN_PRIVACY_KEYS,
                f"{path}.{key}: privacy-sensitive field is forbidden",
            )
            _scan_privacy(child, f"{path}.{key}")
    elif isinstance(value, list):
        for idx, child in enumerate(value):
            _scan_privacy(child, f"{path}[{idx}]")


def _reject_unknown_keys(
    value: Mapping[str, Any],
    allowed: set[str],
    label: str,
) -> None:
    unknown = sorted(set(value) - allowed)
    _require(not unknown, f"{label}: unknown keys: {', '.join(unknown)}")


def _validate_payload(event_type: str, payload: Any) -> dict[str, Any]:
    _require(isinstance(payload, dict), "payload: object required")
    _scan_privacy(payload, "$.payload")
    required, optional = _EVENT_SPECS[event_type]
    missing = sorted(required - set(payload))
    _require(not missing, f"{event_type}.payload: missing keys: {', '.join(missing)}")
    _reject_unknown_keys(payload, required | optional, f"{event_type}.payload")

    p = copy.deepcopy(payload)

    if event_type == "plan_contract_bound":
        _require_string(p["contract_ref"], "contract_ref")
        if "acceptance_refs" in p:
            _require_string_list(p["acceptance_refs"], "acceptance_refs")
        if "allowed_scope" in p:
            _require_string_list(p["allowed_scope"], "allowed_scope")
        if "required_verifiers" in p:
            _require_string_list(p["required_verifiers"], "required_verifiers")
        if "budget" in p:
            _require(isinstance(p["budget"], dict), "budget: object required")
            _scan_privacy(p["budget"], "$.payload.budget")
        if "task_profile" in p:
            _require_string(p["task_profile"], "task_profile")

    elif event_type == "worker_completed":
        _require_string(p["worker_attempt_ref"], "worker_attempt_ref")
        _require_sha256(p["artifact_ref"], "artifact_ref")
        if "provider" in p:
            _require_string(p["provider"], "provider")
        if "control_status" in p:
            _require_string(p["control_status"], "control_status")

    elif event_type == "verification_recorded":
        _require_string(p["verification_ref"], "verification_ref")
        _require_string(p["verifier_id"], "verifier_id")
        _require(p["kind"] in _ALLOWED_VERIFICATION_KIND, "verification.kind: invalid")
        _require(p["status"] in _ALLOWED_VERIFICATION_STATUS, "verification.status: invalid")
        _require_sha256(p["bound_artifact_ref"], "bound_artifact_ref")
        if "source_sha" in p:
            _require_commit(p["source_sha"], "verification.source_sha")
        if "head_sha" in p:
            _require_commit(p["head_sha"], "verification.head_sha")

    elif event_type == "failure_recorded":
        for key in (
            "failure_ref",
            "observation",
            "fingerprint",
            "cause_hypothesis",
            "repairability",
            "result",
        ):
            _require_string(p[key], key)

    elif event_type == "artifact_changed":
        _require_string(p["change_ref"], "change_ref")
        _require_sha256(p["before_artifact_ref"], "before_artifact_ref")
        _require_sha256(p["after_artifact_ref"], "after_artifact_ref")
        _require_string_list(p["changed_paths"], "changed_paths")

    elif event_type == "repair_attempted":
        _require_string(p["repair_ref"], "repair_ref")
        _require_sha256(p["before_artifact_ref"], "before_artifact_ref")
        _require_sha256(p["after_artifact_ref"], "after_artifact_ref")
        for key in ("evidence_delta", "resolved_blockers", "introduced_blockers"):
            _require_string_list(p[key], key)

    elif event_type == "progress_assessed":
        _require_string(p["progress_ref"], "progress_ref")
        _require_string(p["previous_failure_ref"], "previous_failure_ref")
        _require_string(p["current_failure_ref"], "current_failure_ref")
        _require(type(p["artifact_changed"]) is bool, "artifact_changed: bool required")
        for key in ("evidence_delta", "resolved_blockers", "introduced_blockers"):
            _require_string_list(p[key], key)
        _require(type(p["no_progress"]) is bool, "no_progress: bool required")

    elif event_type == "pr_convergence_recorded":
        _require_string(p["convergence_ref"], "convergence_ref")
        _require(p["ci"] in {"pass", "fail", "unavailable"}, "ci: invalid")
        _require(
            p["required_reviews"] in {"pass", "fail", "unavailable"},
            "required_reviews: invalid",
        )
        _require(
            _is_int(p["blocking_threads"]) and p["blocking_threads"] >= 0,
            "blocking_threads: non-negative int required",
        )
        _require(type(p["conflict"]) is bool, "conflict: bool required")
        _require(p["scope"] in {"pass", "fail", "unavailable"}, "scope: invalid")

    elif event_type == "decision_made":
        _require_string(p["decision_ref"], "decision_ref")
        _require(p["action"] in _ALLOWED_ACTIONS, "decision.action: invalid")
        _require_string_list(p["input_refs"], "input_refs")
        outcome = p["outcome"]
        _require(outcome is None or outcome in _ALLOWED_OUTCOMES, "decision.outcome: invalid")
        reasons = _require_string_list(p["stop_reasons"], "stop_reasons")
        _require(all(r in _ALLOWED_STOP_REASONS for r in reasons),
                 "decision.stop_reasons: invalid reason")
        if "policy_verdicts" in p:
            _require_string_list(p["policy_verdicts"], "policy_verdicts")

        if outcome is not None:
            _require(p["action"] == "stop", "terminal outcome requires action=stop")
        else:
            _require(p["action"] != "stop" or reasons,
                     "non-terminal stop requires at least one Stop Reason")

        if outcome == "MERGE_READY":
            _require(not reasons, "MERGE_READY must not carry Stop Reason")
        elif outcome in {"HUMAN_ESCALATED", "BLOCKED"}:
            _require(bool(reasons), f"{outcome} requires Stop Reason")

    elif event_type == "state_transitioned":
        _require_string(p["transition_ref"], "transition_ref")
        _require_string(p["from_state"], "from_state")
        _require_string(p["to_state"], "to_state")
        _require(_is_int(p["expected_revision"]) and p["expected_revision"] >= 0,
                 "expected_revision: non-negative int required")
        _require(_is_int(p["new_revision"]) and p["new_revision"] >= 0,
                 "new_revision: non-negative int required")

    elif event_type == "state_conflict":
        _require_string(p["conflict_ref"], "conflict_ref")
        _require(_is_int(p["expected_revision"]) and p["expected_revision"] >= 0,
                 "expected_revision: non-negative int required")
        _require(_is_int(p["actual_revision"]) and p["actual_revision"] >= 0,
                 "actual_revision: non-negative int required")

    return p


def validate_event_draft(draft: Any) -> dict[str, Any]:
    """Validate producer-controlled EventDraft.

    Authoritative run binding, sequence and event_ref are deliberately forbidden.
    """
    _require(isinstance(draft, dict), "EventDraft: object required")
    _scan_privacy(draft)
    _reject_unknown_keys(draft, _DRAFT_KEYS, "EventDraft")
    _require(draft.get("schema_version") == SCHEMA_VERSION, "EventDraft.schema_version")
    event_type = _require_string(draft.get("event_type"), "EventDraft.event_type")
    _require(event_type in _EVENT_SPECS, f"EventDraft.event_type: unsupported {event_type!r}")
    payload = _validate_payload(event_type, draft.get("payload"))
    evidence_refs = _require_string_list(draft.get("evidence_refs", []), "evidence_refs")
    return {
        "schema_version": SCHEMA_VERSION,
        "event_type": event_type,
        "payload": payload,
        "evidence_refs": evidence_refs,
    }


def _validate_bound_context(context: Any) -> dict[str, Any]:
    _require(isinstance(context, dict), "bound_context: object required")
    _reject_unknown_keys(context, _CONTEXT_KEYS, "bound_context")
    required = {"run_id", "harness_manifest_ref", "plan_hash", "source_sha"}
    missing = sorted(required - set(context))
    _require(not missing, f"bound_context: missing keys: {', '.join(missing)}")

    out: dict[str, Any] = {
        "run_id": _require_string(context["run_id"], "run_id"),
        "harness_manifest_ref": _require_sha256(
            context["harness_manifest_ref"], "harness_manifest_ref"
        ),
        "plan_hash": _require_sha256(context["plan_hash"], "plan_hash"),
        "source_sha": _require_commit(context["source_sha"], "source_sha"),
    }
    if "revision" in context:
        _require(
            _is_int(context["revision"]) and context["revision"] >= 0,
            "revision: non-negative int required",
        )
        out["revision"] = context["revision"]
    return out


def _event_without_ref(event: Mapping[str, Any]) -> dict[str, Any]:
    return {key: copy.deepcopy(value) for key, value in event.items() if key != "event_ref"}


def canonical_event_ref(event_without_ref: Mapping[str, Any]) -> str:
    raw = json.dumps(
        event_without_ref,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def finalize_event(
    draft: Any,
    bound_context: Any,
    event_seq: int,
) -> dict[str, Any]:
    """Bind a validated EventDraft after #1392 allocates sequence/context."""
    d = validate_event_draft(draft)
    context = _validate_bound_context(bound_context)
    _require(_is_int(event_seq) and event_seq > 0, "event_seq: positive int required")

    event: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "run_id": context["run_id"],
        "event_seq": event_seq,
        "event_type": d["event_type"],
        "harness_manifest_ref": context["harness_manifest_ref"],
        "payload": d["payload"],
        "evidence_refs": d["evidence_refs"],
        "plan_hash": context["plan_hash"],
        "source_sha": context["source_sha"],
    }
    if "revision" in context:
        event["revision"] = context["revision"]
    event["event_ref"] = canonical_event_ref(event)
    return event


def validate_event(event: Any) -> dict[str, Any]:
    """Validate an already-bound RunEvent.

    Structural problems raise EventParseError. A hash mismatch is readable
    contract/tamper evidence and raises StreamContractError.
    """
    _require(isinstance(event, dict), "RunEvent: object required")
    _scan_privacy(event)
    _reject_unknown_keys(event, _EVENT_REQUIRED_KEYS | _EVENT_OPTIONAL_KEYS, "RunEvent")

    missing = sorted(_EVENT_REQUIRED_KEYS - set(event))
    _require(not missing, f"RunEvent: missing keys: {', '.join(missing)}")
    _require(event["schema_version"] == SCHEMA_VERSION, "RunEvent.schema_version")
    _require_string(event["run_id"], "run_id")
    _require(_is_int(event["event_seq"]) and event["event_seq"] > 0,
             "event_seq: positive int required")
    event_type = _require_string(event["event_type"], "event_type")
    _require(event_type in _EVENT_SPECS, f"event_type: unsupported {event_type!r}")
    _require_sha256(event["harness_manifest_ref"], "harness_manifest_ref")
    _require_sha256(event["event_ref"], "event_ref")
    _require_sha256(event["plan_hash"], "plan_hash")
    _require_commit(event["source_sha"], "source_sha")
    if "revision" in event:
        _require(_is_int(event["revision"]) and event["revision"] >= 0,
                 "revision: non-negative int required")
    _validate_payload(event_type, event["payload"])
    _require_string_list(event["evidence_refs"], "evidence_refs")

    expected = canonical_event_ref(_event_without_ref(event))
    _require(
        event["event_ref"] == expected,
        "event_ref does not match canonical accepted event",
        StreamContractError,
    )
    return copy.deepcopy(event)


def registered_refs(event: Mapping[str, Any]) -> list[str]:
    refs: list[str] = [event["event_ref"]]
    refs.extend(event.get("evidence_refs", []))
    payload = event["payload"]
    for field in _REF_FIELDS_BY_EVENT[event["event_type"]]:
        refs.append(payload[field])
    return refs


def _terminal_outcome(event: Mapping[str, Any]) -> str | None:
    if event["event_type"] != "decision_made":
        return None
    return event["payload"].get("outcome")


def _prior_ref_set(events: Sequence[Mapping[str, Any]]) -> set[str]:
    refs: set[str] = set()
    for event in events:
        for ref in registered_refs(event):
            _require(
                ref not in refs,
                f"duplicate registered reference in accepted stream: {ref}",
                StreamContractError,
            )
            refs.add(ref)
    return refs


def _validate_append_against_validated(
    current_stream: Sequence[Mapping[str, Any]],
    candidate: Mapping[str, Any],
) -> None:
    if not current_stream:
        _require(candidate["event_seq"] == 1, "first event_seq must be 1", StreamContractError)
        _require(
            candidate["event_type"] == "plan_contract_bound",
            "first event must be plan_contract_bound",
            StreamContractError,
        )
        return

    first = current_stream[0]
    last = current_stream[-1]
    _require(
        candidate["event_seq"] == last["event_seq"] + 1,
        "event_seq must be contiguous (previous + 1)",
        StreamContractError,
    )

    for key in ("run_id", "harness_manifest_ref", "plan_hash", "source_sha"):
        _require(
            candidate[key] == first[key],
            f"{key} drift within active run",
            StreamContractError,
        )

    _require(
        _terminal_outcome(last) is None,
        "cannot append event after terminal outcome",
        StreamContractError,
    )

    prior_refs = _prior_ref_set(current_stream)
    candidate_refs = registered_refs(candidate)
    candidate_ref_set: set[str] = set()
    for ref in candidate_refs:
        _require(
            ref not in candidate_ref_set,
            f"duplicate reference inside candidate event: {ref}",
            StreamContractError,
        )
        candidate_ref_set.add(ref)
        _require(
            ref not in prior_refs,
            f"duplicate registered reference: {ref}",
            StreamContractError,
        )

    payload = candidate["payload"]
    if candidate["event_type"] == "decision_made":
        for ref in payload["input_refs"]:
            _require(
                ref in prior_refs,
                f"decision input is not prior evidence: {ref}",
                StreamContractError,
            )

    if candidate["event_type"] == "progress_assessed":
        for field in ("previous_failure_ref", "current_failure_ref"):
            ref = payload[field]
            _require(
                ref in prior_refs,
                f"progress assessment references unknown prior failure: {ref}",
                StreamContractError,
            )


def validate_append(
    current_stream: Any,
    candidate_event: Any,
) -> None:
    """Validate current_stream + candidate before #1392 durable commit."""
    _require(isinstance(current_stream, list), "current_stream: list required")
    validated_current: list[dict[str, Any]] = []
    if current_stream:
        validated_current = validate_stream(current_stream)
    candidate = validate_event(candidate_event)
    _validate_append_against_validated(validated_current, candidate)


def validate_stream(events: Any) -> list[dict[str, Any]]:
    """Validate a full accepted stream and return a defensive copy."""
    _require(isinstance(events, list) and bool(events), "RunEvent stream: non-empty list required")

    accepted: list[dict[str, Any]] = []
    for raw in events:
        event = validate_event(raw)
        _validate_append_against_validated(accepted, event)
        accepted.append(event)

    # Final defensive check: one terminal outcome maximum is implied by
    # append terminality, but make it explicit for whole-stream readers.
    terminals = [e for e in accepted if _terminal_outcome(e) is not None]
    _require(
        len(terminals) <= 1,
        "multiple terminal outcomes in one run",
        StreamContractError,
    )
    if terminals:
        _require(
            terminals[0]["event_seq"] == accepted[-1]["event_seq"],
            "terminal outcome must be final event",
            StreamContractError,
        )
    return copy.deepcopy(accepted)


__all__ = [
    "EventError",
    "EventParseError",
    "StreamContractError",
    "SCHEMA_VERSION",
    "canonical_event_ref",
    "finalize_event",
    "registered_refs",
    "validate_append",
    "validate_event",
    "validate_event_draft",
    "validate_stream",
]
