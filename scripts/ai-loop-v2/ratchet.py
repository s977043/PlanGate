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

from decision_core import DecisionError, _canonical_path, decide

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


class _ManifestIndeterminate(RatchetError):
    """The actual delta cannot be derived; ``str(exc)`` is the reason code."""


class _NonCanonicalPath(RatchetError):
    """A changed path is not canonical, so scope cannot be proven."""


PATTERN_REQUIRED_FIELDS = (
    "pattern_id",
    "pattern_version",
    "classifier_digest",
    "source_set_digest",
)


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
    if not isinstance(source["run_evidence"], dict):
        raise RatchetError("RunEvidence")
    if not source["run_id"] or source["run_evidence"].get("run_id") != source["run_id"]:
        raise RatchetError("source run_id does not match RunEvidence run_id")
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


def _index_components(manifest):
    components = manifest.get("components")
    if not isinstance(components, list):
        raise _ManifestIndeterminate("MANIFEST_COMPONENT_IDENTITY")
    index = {}
    for item in components:
        component_id = item.get("component_id") if isinstance(item, dict) else None
        # A dict keyed by component_id keeps only the last entry, so a
        # duplicate could shadow a changed component.
        if not isinstance(component_id, str) or not component_id or component_id in index:
            raise _ManifestIndeterminate("MANIFEST_COMPONENT_IDENTITY")
        index[component_id] = item
    return index


def _component_paths(component):
    paths = component.get("paths")
    # A changed component without paths would make the scope check vacuous
    # (``all([])`` is True), so it is not evidence of staying in scope.
    if not isinstance(paths, list) or not paths:
        raise _ManifestIndeterminate("COMPONENT_PATHS_MISSING")
    return paths


def observed_component_delta(baseline, candidate):
    """Derive the actual harness delta from the two manifests.

    For every changed component the paths of BOTH sides are counted, so a
    protected component relocated under ``allowed_paths`` is still seen on
    its baseline path. Every counted path must be canonical
    (``decision_core._canonical_path``): ``fnmatch``'s ``*`` crosses ``/``,
    so ``harness/verifiers/../../x`` would otherwise match
    ``harness/verifiers/*`` while resolving elsewhere.
    """
    before = _index_components(baseline)
    after = _index_components(candidate)
    deltas = []
    changed_paths = set()
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
        for side in (left, right):
            if side is None:
                continue
            for path in _component_paths(side):
                try:
                    changed_paths.add(_canonical_path(path))
                except DecisionError as exc:
                    raise _NonCanonicalPath(str(exc)) from exc
    return deltas, sorted(changed_paths)


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


def _scope_patterns_intersect(declared, protected):
    def prefix(pattern):
        indexes = [
            index for token in ("*", "?", "[")
            if (index := pattern.find(token)) >= 0
        ]
        return pattern[:min(indexes)] if indexes else pattern

    for left in declared:
        for right in protected:
            if fnmatch.fnmatch(left, right) or fnmatch.fnmatch(right, left):
                return True
            left_prefix = prefix(left)
            right_prefix = prefix(right)
            if (
                left_prefix.startswith(right_prefix)
                or right_prefix.startswith(left_prefix)
            ):
                return True
    return False


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
            # The simulated delivery artifact's change set comes from the
            # sealed fixture (digest-bound). The Decision Engine rejects an
            # empty or non-canonical change set, which surfaces as ERROR.
            changed_paths=list(fixture.get("changed_paths") or []),
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

    # The paired fixtures are only trustworthy if the sealed plan pins both
    # of their digests; otherwise the digest loop below would never see them.
    fixture_digests = sealed_plan.get("fixture_digests") or {}
    known_id = sealed_plan.get("known_bad_fixture_id")
    negative_id = sealed_plan.get("negative_control_fixture_id")
    if (
        not known_id
        or not negative_id
        or known_id not in fixture_digests
        or negative_id not in fixture_digests
        or sealed_plan.get("required_activation", "influenced_decision")
        not in ACTIVATION
    ):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["EVALUATION_PLAN_INCOMPLETE"],
        )
    # An absent or empty protected set would make every protected-authority
    # check below vacuously pass.
    protected_paths = sealed_plan.get("protected_paths")
    if (
        not isinstance(protected_paths, list)
        or not protected_paths
        or not all(isinstance(p, str) and p for p in protected_paths)
    ):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["EVALUATION_PLAN_INCOMPLETE"],
        )

    fixtures = bundle.get("fixtures") or {}
    for fixture_id, expected_digest in fixture_digests.items():
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

    instance_tuples = [
        (
            ref["run_id"],
            ref["event_ref"],
            ref["failure_record_ref"],
            ref["run_evidence_ref"],
        )
        for ref in actual_instances
    ]
    # A Candidate without a source failure has no provenance, and a repeated
    # failure instance would be counted twice as independent evidence.
    if not actual_instances or len(set(instance_tuples)) != len(instance_tuples):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["SOURCE_INSTANCE_BINDING"],
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
    if any(pattern.get(field) in (None, "") for field in PATTERN_REQUIRED_FIELDS):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["PATTERN_SNAPSHOT_INCOMPLETE"],
        )
    if pattern.get("source_set_digest") != compute_source_set_digest(
        actual_instances
    ):
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["SOURCE_SET_DIGEST"],
        )

    try:
        deltas, changed_paths = observed_component_delta(
            baseline, candidate_manifest
        )
    except _NonCanonicalPath:
        return _finish(
            bundle,
            sealed_plan,
            "FAIL",
            ["NON_CANONICAL_CHANGED_PATH"],
            policy_verdict="HUMAN_REQUIRED",
        )
    except _ManifestIndeterminate as exc:
        return _finish(bundle, sealed_plan, "INCONCLUSIVE", [str(exc)])
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
    if _scope_patterns_intersect(allowed_paths, protected_paths):
        return _finish(
            bundle,
            sealed_plan,
            "FAIL",
            ["DECLARED_SCOPE_INTERSECTS_PROTECTED_AUTHORITY"],
            policy_verdict="HUMAN_REQUIRED",
            deltas=deltas,
            changed_paths=changed_paths,
        )
    # Protected authority is checked on the actual delta before the
    # allowed-paths subset check: a changed path on a protected surface is
    # reported as such even when it is also outside allowed_paths (e.g. a
    # protected component relocated under allowed_paths is seen on its
    # baseline path).
    if _paths_intersect(changed_paths, protected_paths):
        return _finish(
            bundle,
            sealed_plan,
            "FAIL",
            ["PROTECTED_AUTHORITY_CHANGED"],
            policy_verdict="HUMAN_REQUIRED",
            deltas=deltas,
            changed_paths=changed_paths,
        )
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
    # A control that already fails on the baseline cannot show that the
    # Candidate preserved valid completions.
    if paired["negative_control"]["baseline"]["outcome"] != "MERGE_READY":
        return _finish(
            bundle,
            sealed_plan,
            "INCONCLUSIVE",
            ["NEGATIVE_CONTROL_BASELINE_INVALID"],
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
