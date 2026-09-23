#!/usr/bin/env python3
"""ai-loop V2 deterministic RunEvidence projection.

TASK-1391 / #1391.

RunEvidence is a rebuildable projection/cache. It is never accepted as the
authoritative source of Run truth.
"""

from __future__ import annotations

from typing import Any, Iterable, Mapping

from run_event import (
    EventParseError,
    StreamContractError,
    validate_stream,
)


EVIDENCE_SCHEMA_VERSION = "1"


def _dedupe(values: Iterable[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for value in values:
        if value not in seen:
            seen.add(value)
            out.append(value)
    return out


def _invalid_projection(
    events: list[dict[str, Any]],
    expected_harness_manifest_ref: str,
    error: str,
) -> dict[str, Any]:
    first = events[0] if events and isinstance(events[0], dict) else {}
    return {
        "schema_version": EVIDENCE_SCHEMA_VERSION,
        "run_id": first.get("run_id"),
        "harness_manifest_ref": first.get("harness_manifest_ref"),
        "plan_hash": first.get("plan_hash"),
        "source_sha": first.get("source_sha"),
        "outcome": None,
        "stop_reasons": [],
        "policy_verdicts": [],
        "verification_result_refs": [],
        "failure_record_refs": [],
        "evidence_refs": [],
        "event_refs": [],
        "event_count": len(events),
        "last_event_ref": None,
        "evidence_status": "invalid",
        "errors": [error],
    }


def project_run_evidence(
    events: Any,
    expected_harness_manifest_ref: str,
) -> dict[str, Any]:
    """Project accepted RunEvents into deterministic RunEvidence.

    EventParseError is deliberately not converted into RunEvidence because
    structurally unusable input is not a readable event stream.
    Readable contract/tamper violations become evidence_status=invalid.
    """
    if not isinstance(events, list) or not events:
        raise EventParseError("RunEvent stream: non-empty list required")
    if not isinstance(expected_harness_manifest_ref, str) or not expected_harness_manifest_ref:
        raise EventParseError("expected_harness_manifest_ref: non-empty string required")

    try:
        accepted = validate_stream(events)
    except EventParseError:
        raise
    except StreamContractError as exc:
        return _invalid_projection(events, expected_harness_manifest_ref, str(exc))

    first = accepted[0]
    if first["harness_manifest_ref"] != expected_harness_manifest_ref:
        return _invalid_projection(
            accepted,
            expected_harness_manifest_ref,
            "expected harness_manifest_ref does not match accepted stream",
        )

    verification_refs: list[str] = []
    failure_refs: list[str] = []
    evidence_refs: list[str] = []
    event_refs: list[str] = []
    policy_verdicts: list[str] = []
    outcome = None
    stop_reasons: list[str] = []

    for event in accepted:
        event_refs.append(event["event_ref"])
        evidence_refs.extend(event.get("evidence_refs", []))
        payload = event["payload"]

        if event["event_type"] == "verification_recorded":
            verification_refs.append(payload["verification_ref"])
        elif event["event_type"] == "failure_recorded":
            failure_refs.append(payload["failure_ref"])
        elif event["event_type"] == "decision_made":
            policy_verdicts.extend(payload.get("policy_verdicts", []))
            if payload.get("outcome") is not None:
                outcome = payload["outcome"]
                stop_reasons = list(payload["stop_reasons"])

    return {
        "schema_version": EVIDENCE_SCHEMA_VERSION,
        "run_id": first["run_id"],
        "harness_manifest_ref": first["harness_manifest_ref"],
        "plan_hash": first["plan_hash"],
        "source_sha": first["source_sha"],
        "outcome": outcome,
        "stop_reasons": stop_reasons,
        "policy_verdicts": _dedupe(policy_verdicts),
        "verification_result_refs": verification_refs,
        "failure_record_refs": failure_refs,
        "evidence_refs": _dedupe(evidence_refs),
        "event_refs": event_refs,
        "event_count": len(accepted),
        "last_event_ref": accepted[-1]["event_ref"],
        "evidence_status": "ready" if outcome is not None else "partial",
        "errors": [],
    }


__all__ = ["EVIDENCE_SCHEMA_VERSION", "project_run_evidence"]
