"""TASK-1623 byte fixtures for the accepted event structure at 6756a597."""

import hashlib
import json

SOURCE_SHA = "6756a597a6f42a8c2a51f879e761e73717d44da9"
STOP_REASONS = [
    "NO_PROGRESS", "REPEATED_FAILURE", "OSCILLATION", "BUDGET_EXHAUSTED",
    "POLICY_DENIED", "VERIFIER_UNAVAILABLE", "REQUIREMENT_CONFLICT",
    "STATE_CONFLICT", "HUMAN_REJECTED",
]


def canonical_bytes(value):
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def worst_case_event(outcome, *, artifact, input_count):
    refs = [f"sha256:{index:064x}" for index in range(256)]
    decision = {
        "action": "continue" if outcome is None else "stop",
        "inputs": refs[:input_count],
        "outcome": outcome,
        "stop_reasons": [],
        "input_last_event_seq": 2047,
        "contract_bound_seq": 2047,
        "decided_in_state": "PR_CONVERGING",
        "failure_fingerprints": refs[input_count:],
        "verdicts": {chr(index) * 71: "unavailable" for index in range(16, 32)},
    }
    if outcome in ("BLOCKED", "HUMAN_ESCALATED"):
        # Q-2 counts duplicates toward the nine-entry limit.
        longest_reason = max(STOP_REASONS, key=lambda reason: len(canonical_bytes(reason)))
        decision["stop_reasons"] = [longest_reason] * 9
    if artifact:
        decision["artifact_ref"] = refs[0]
    event = {
        "schema_version": "1",
        "run_id": "RUN-" + "A" * 64,
        "event_seq": 2048,
        "revision": 2047,
        "event_type": "decision_made",
        "harness_manifest_ref": refs[1],
        "plan_hash": refs[2],
        "source_sha": "a" * 40,
        "payload": {"decision": decision},
    }
    event["event_ref"] = "sha256:" + hashlib.sha256(canonical_bytes(event)).hexdigest()
    return event


def byte_parts(event):
    decision = event["payload"]["decision"]
    fixed = {key: decision[key] for key in ("action", "outcome", "stop_reasons")}
    without_fixed = {key: value for key, value in decision.items() if key not in fixed}
    envelope = {**event, "payload": {"decision": {}}}

    # Both objects are nonempty, so their join replaces one brace with a comma.
    fixed_size = len(canonical_bytes(fixed)) - 1
    input_size = len(canonical_bytes(without_fixed)) - 2
    return input_size, fixed_size, len(canonical_bytes(envelope))
