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

from run_event import EventContractError, validate_stream


def _invalid(manifest_ref, reason):
    return {
        "harness_manifest_ref": manifest_ref,
        "outcome": None,
        "stop_reasons": [],
        "policy_verdicts": [],
        "verification_result_refs": [],
        "failure_record_refs": [],
        "evidence_refs": [],
        "evidence_status": "invalid",
        "invalid_reasons": [reason],
    }


def project_run_evidence(events, manifest_ref):
    try:
        clean = validate_stream(events)
    except EventContractError as exc:
        return _invalid(manifest_ref, str(exc))
    if clean[0]["harness_manifest_ref"] != manifest_ref:
        return _invalid(manifest_ref, "manifest binding mismatch")

    verification_refs = []
    failure_refs = []
    evidence_refs = []
    outcome = None
    stop_reasons = []

    def add_ref(ref):
        if isinstance(ref, str) and ref and ref not in evidence_refs:
            evidence_refs.append(ref)

    for event in clean:
        payload = event["payload"]
        event_type = event["event_type"]
        add_ref(event["event_ref"])
        if payload.get("evidence_ref"):
            add_ref(payload["evidence_ref"])
        for ref in payload.get("evidence_refs", []):
            add_ref(ref)
        if event_type == "verification_recorded":
            verification_refs.append(payload["verification"]["id"])
            for ref in payload["verification"]["evidence_refs"]:
                add_ref(ref)
        elif event_type == "failure_recorded":
            failure_refs.append(payload["failure"]["id"])
            for ref in payload["failure"]["evidence_refs"]:
                add_ref(ref)
        elif event_type == "decision_made":
            decision = payload["decision"]
            if decision["outcome"] is not None:
                outcome = decision["outcome"]
                stop_reasons = list(decision["stop_reasons"])

    return {
        "harness_manifest_ref": manifest_ref,
        "outcome": outcome,
        "stop_reasons": stop_reasons,
        "policy_verdicts": [],
        "verification_result_refs": verification_refs,
        "failure_record_refs": failure_refs,
        "evidence_refs": evidence_refs,
        "evidence_status": "ready" if outcome is not None else "partial",
        "invalid_reasons": [],
    }
