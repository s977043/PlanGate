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
import hashlib
import json

from decision_core import DecisionError, decide

ACTIVATION = {
    "installed": 1,
    "registered": 2,
    "selected": 3,
    "fired": 4,
    "produced_evidence": 5,
    "influenced_decision": 6,
}
FORBIDDEN_KEYS = {
    "raw_transcript", "transcript", "chain_of_thought", "hidden_cot",
    "hidden_reasoning", "secret", "token", "api_key", "password",
}


class RatchetError(ValueError):
    pass


def canonical_digest(value):
    raw = json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _walk_keys(node):
    if isinstance(node, dict):
        for key, value in node.items():
            yield key
            yield from _walk_keys(value)
    elif isinstance(node, list):
        for value in node:
            yield from _walk_keys(value)


def _reject_private(node):
    bad = sorted({
        key for key in _walk_keys(node)
        if isinstance(key, str) and key.lower() in FORBIDDEN_KEYS
    })
    if bad:
        raise RatchetError("forbidden/private keys: " + ",".join(bad))


def manifest_ref(manifest):
    return canonical_digest(manifest)


def build_failure_instance(source):
    required = {"run_id", "event_ref", "failure_record", "run_evidence"}
    if not isinstance(source, dict) or not required.issubset(source):
        raise RatchetError("source failure bundle")
    failure_ref = canonical_digest(source["failure_record"])
    run_evidence_ref = canonical_digest(source["run_evidence"])
    if failure_ref not in source["run_evidence"].get("failure_record_refs", []):
        raise RatchetError("RunEvidence missing FailureRecord ref")
    return {
        "run_id": source["run_id"],
        "event_ref": source["event_ref"],
        "failure_record_ref": failure_ref,
        "run_evidence_ref": run_evidence_ref,
    }


def compute_source_set_digest(refs):
    stable = sorted(
        (
            ref["run_id"],
            ref["event_ref"],
            ref["failure_record_ref"],
            ref["run_evidence_ref"],
        )
        for ref in refs
    )
    return canonical_digest(stable)


def observed_component_delta(baseline, candidate):
    before = {item["component_id"]: item for item in baseline.get("components", [])}
    after = {item["component_id"]: item for item in candidate.get("components", [])}
    deltas = []
    changed_paths = []
    for component_id in sorted(set(before) | set(after)):
        left = before.get(component_id)
        right = after.get(component_id)
        if left == right:
            continue
        deltas.append({
            "component_id": component_id,
            "before_content_sha": left.get("content_sha") if left else None,
            "after_content_sha": right.get("content_sha") if right else None,
        })
        source = right or left
        changed_paths.extend(source.get("paths", []))
    return deltas, sorted(set(changed_paths))


def _paths_within(paths, allowed):
    return all(
        any(fnmatch.fnmatch(path, pattern) for pattern in allowed)
        for path in paths
    )


def _paths_intersect(paths, protected):
    return any(
        any(fnmatch.fnmatch(path, pattern) for pattern in protected)
        for path in paths
    )


def _completion_component(manifest):
    for component in manifest.get("components", []):
        if component.get("component_id") == "verifier:completion-evidence":
            return component
    return None


def simulate_completion(manifest, fixture):
    artifact_ref = fixture["artifact_ref"]
    verifications = [{
        "id": "v-tests-pass",
        "verifier_id": "deterministic.tests",
        "kind": "deterministic",
        "status": "pass",
        "bound_artifact_ref": artifact_ref,
        "evidence_refs": ["tests:pass"],
    }]
    required = ["deterministic.tests"]
    completion = _completion_component(manifest)
    completion_id = None
    activation_level = "registered" if completion else "installed"

    if completion and completion.get("enabled") is True:
        required.append("completion.evidence")
        completion_id = "v-completion"
        if fixture["verification_present"]:
            status = "unavailable" if completion.get("block_when_present") else "pass"
        else:
            status = "unavailable" if completion.get("enforce_missing", True) else "pass"
        verifications.append({
            "id": completion_id,
            "verifier_id": "completion.evidence",
            "kind": "deterministic",
            "status": status,
            "bound_artifact_ref": artifact_ref,
            "evidence_refs": [
                "completion:evidence-present"
                if fixture["verification_present"]
                else "completion:evidence-missing"
            ],
        })
        activation_level = "produced_evidence"

    convergence = {
        "convergence": {
            "ci": "pass",
            "required_reviews": "pass",
            "blocking_threads": 0,
            "conflict": False,
            "scope": "pass",
        },
        "evidence_refs": ["pr:convergence"],
    }
    try:
        decision = decide(
            loop_contract={
                "required_verifiers": required,
                "allowed_scope": ["harness/verifiers/**"],
            },
            run_state={"state": "PR_CONVERGING"},
            verifications=verifications,
            failures=[],
            current_artifact_ref=artifact_ref,
            pr_convergence=convergence,
            changed_paths=[],
        )
    except DecisionError as exc:
        return {
            "outcome": "ERROR",
            "stop_reasons": [],
            "decision_inputs": [],
            "activation_level": activation_level,
            "error": str(exc),
        }

    if completion_id and completion_id in decision["inputs"]:
        activation_level = "influenced_decision"
    return {
        "outcome": decision["outcome"],
        "stop_reasons": decision["stop_reasons"],
        "decision_inputs": decision["inputs"],
        "activation_level": activation_level,
    }


def measure_recurrence(observations, classifier_digest):
    eligible = [
        item for item in observations
        if item.get("classifier_digest") == classifier_digest
    ]
    matching = [item for item in eligible if item.get("matched") is True]
    return {
        "pattern_classifier_digest": classifier_digest,
        "eligible_run_count": len(eligible),
        "matching_failure_run_count": len(matching),
        "same_pattern_recurrence_rate": (
            len(matching) / len(eligible) if eligible else None
        ),
    }


def _finish(
    bundle,
    sealed_plan,
    result_value,
    reason_codes,
    *,
    policy_verdict=None,
    deltas=None,
    changed_paths=None,
    paired=None,
    activation=None,
):
    baseline = bundle.get("baseline_manifest")
    candidate_manifest = bundle.get("candidate_manifest")
    candidate = bundle.get("candidate", {})
    classifier_digest = (
        candidate.get("source", {})
        .get("pattern_snapshot", {})
        .get("classifier_digest")
    )
    recurrence = measure_recurrence(
        bundle.get("recurrence_observations", []), classifier_digest
    ) if classifier_digest else None
    experiment = {
        "candidate_id": candidate.get("candidate_id"),
        "candidate_ref": canonical_digest(candidate) if candidate else None,
        "evaluation_plan_digest": canonical_digest(sealed_plan),
        "baseline_manifest_ref": manifest_ref(baseline) if baseline else None,
        "candidate_manifest_ref": (
            manifest_ref(candidate_manifest) if candidate_manifest else None
        ),
        "observed_component_deltas": deltas or [],
        "observed_changed_paths": changed_paths or [],
        "prevention_evidence": paired or {},
        "activation": activation or {},
        "metrics": {
            "recurrence_observation": recurrence,
        },
        "result": result_value,
        "reason_codes": list(reason_codes),
    }
    if policy_verdict is not None:
        experiment["policy_verdict"] = policy_verdict
    experiment_ref = canonical_digest(experiment)
    return {
        "experiment_result": experiment,
        "promotion_decision": {
            "candidate_id": experiment["candidate_id"],
            "candidate_ref": experiment["candidate_ref"],
            "candidate_manifest_ref": experiment["candidate_manifest_ref"],
            "source_failure_instance_refs": (
                candidate.get("source", {}).get("failure_instance_refs", [])
            ),
            "experiment_result_ref": experiment_ref,
            "decision": result_value,
            "reason_codes": list(reason_codes),
            "production_promotion_executed": False,
        },
    }


def evaluate_verification_skipped(bundle, sealed_plan):
    _reject_private(bundle)
    _reject_private(sealed_plan)

    candidate = bundle.get("candidate")
    if not isinstance(candidate, dict):
        raise RatchetError("candidate")

    if candidate.get("evaluation_plan_digest") != canonical_digest(sealed_plan):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["EVALUATION_PLAN_DIGEST_MISMATCH"],
        )

    fixtures = bundle.get("fixtures") or {}
    for fixture_id, expected_digest in (
        sealed_plan.get("fixture_digests") or {}
    ).items():
        fixture = fixtures.get(fixture_id)
        if fixture is None or canonical_digest(fixture) != expected_digest:
            return _finish(
                bundle,
                sealed_plan,
                "FAIL",
                ["SEALED_FIXTURE_MUTATION"],
                policy_verdict="HUMAN_REQUIRED",
            )

    baseline = bundle.get("baseline_manifest")
    candidate_manifest = bundle.get("candidate_manifest")
    if not baseline or not candidate_manifest:
        return _finish(
            bundle, sealed_plan, "INCONCLUSIVE", ["MANIFEST_MISSING"]
        )

    baseline_ref = manifest_ref(baseline)
    candidate_ref = manifest_ref(candidate_manifest)
    if (
        candidate.get("baseline_manifest_ref") != baseline_ref
        or sealed_plan.get("baseline_manifest_ref") != baseline_ref
    ):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["BASELINE_MANIFEST_BINDING"],
        )
    if bundle.get("candidate_manifest_ref") != candidate_ref:
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["CANDIDATE_MANIFEST_BINDING"],
        )

    try:
        actual_instances = [
            build_failure_instance(source)
            for source in bundle.get("sources", [])
        ]
    except RatchetError:
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["SOURCE_FAILURE_BINDING"],
        )

    source = candidate.get("source", {})
    if source.get("failure_instance_refs") != actual_instances:
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["SOURCE_INSTANCE_BINDING"],
        )
    if source.get("run_evidence_refs") != [
        ref["run_evidence_ref"] for ref in actual_instances
    ]:
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["RUN_EVIDENCE_BINDING"],
        )
    pattern = source.get("pattern_snapshot") or {}
    if pattern.get("source_set_digest") != compute_source_set_digest(
        actual_instances
    ):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["SOURCE_SET_DIGEST"],
        )

    deltas, changed_paths = observed_component_delta(
        baseline, candidate_manifest
    )
    if not deltas:
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["NO_OBSERVED_HARNESS_DELTA"],
            deltas=deltas,
            changed_paths=changed_paths,
        )

    allowed_paths = candidate.get("target", {}).get("allowed_paths") or []
    if not _paths_within(changed_paths, allowed_paths):
        return _finish(
            bundle,
            sealed_plan,
            "FAIL",
            ["ACTUAL_DELTA_OUTSIDE_ALLOWED_PATHS"],
            policy_verdict="HUMAN_REQUIRED",
            deltas=deltas,
            changed_paths=changed_paths,
        )

    if _paths_intersect(
        changed_paths, sealed_plan.get("protected_paths") or []
    ):
        return _finish(
            bundle,
            sealed_plan,
            "FAIL",
            ["PROTECTED_AUTHORITY_CHANGED"],
            policy_verdict="HUMAN_REQUIRED",
            deltas=deltas,
            changed_paths=changed_paths,
        )

    known_id = sealed_plan["known_bad_fixture_id"]
    negative_id = sealed_plan["negative_control_fixture_id"]
    paired = {
        "known_bad": {
            "baseline": simulate_completion(
                baseline, fixtures[known_id]
            ),
            "candidate": simulate_completion(
                candidate_manifest, fixtures[known_id]
            ),
        },
        "negative_control": {
            "baseline": simulate_completion(
                baseline, fixtures[negative_id]
            ),
            "candidate": simulate_completion(
                candidate_manifest, fixtures[negative_id]
            ),
        },
    }
    candidate_known = paired["known_bad"]["candidate"]
    required_level = sealed_plan.get(
        "required_activation", "influenced_decision"
    )
    observed_level = candidate_known["activation_level"]
    activation = {
        "required_level": required_level,
        "observed_level": observed_level,
    }
    if ACTIVATION.get(observed_level, 0) < ACTIVATION[required_level]:
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["ACTIVATION_INSUFFICIENT"],
            deltas=deltas,
            changed_paths=changed_paths,
            paired=paired,
            activation=activation,
        )

    if paired["known_bad"]["baseline"]["outcome"] != "MERGE_READY":
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["BASELINE_MISS_NOT_REPRODUCED"],
            deltas=deltas,
            changed_paths=changed_paths,
            paired=paired,
            activation=activation,
        )

    if not (
        candidate_known["outcome"] == "BLOCKED"
        and "VERIFIER_UNAVAILABLE" in candidate_known["stop_reasons"]
    ):
        return _finish(
            bundle,
            sealed_plan,
            "FAIL",
            ["KNOWN_BAD_NOT_STOPPED"],
            deltas=deltas,
            changed_paths=changed_paths,
            paired=paired,
            activation=activation,
        )

    if (
        paired["negative_control"]["candidate"]["outcome"]
        != "MERGE_READY"
    ):
        return _finish(
            bundle,
            sealed_plan,
            "FAIL",
            ["NEGATIVE_CONTROL_REGRESSION"],
            deltas=deltas,
            changed_paths=changed_paths,
            paired=paired,
            activation=activation,
        )

    return _finish(
        bundle,
        sealed_plan,
        "PASS",
        [
            "KNOWN_BAD_STOPPED",
            "NEGATIVE_CONTROL_PASSED",
            "ACTIVATION_CONFIRMED",
        ],
        deltas=deltas,
        changed_paths=changed_paths,
        paired=paired,
        activation=activation,
    )
