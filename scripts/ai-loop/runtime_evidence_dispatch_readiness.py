#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """runtime_evidence_dispatch_readiness.py — pre-PBI R1 dispatch readiness (#1448).

This module evaluates evidence prerequisites for a future R1 dispatcher.

It does NOT:
- invoke an agent;
- claim V2 RunEvent activation;
- create PBI / Issue / code / approval / merge / deploy side effects.

Pre-PBI vocabulary:
- runtime_role_registered
- provider_connector_registered
- hard_read_only_enforced
- admission_binding_verified
- rollout_decision_recorded
- dispatch_ready

V2 Run activation vocabulary (selected/fired/produced_evidence/influenced_decision)
remains in RunEvent ownership and is intentionally absent here.
"""

import argparse
import copy
import hashlib
import json
import os
import pathlib
import stat
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_ingress as ingress  # noqa: E402
import runtime_evidence_investigation as investigation  # noqa: E402


OBS_DOMAIN = "plangate.runtime-pre-run-observation/v1"
REQUEST_DOMAIN = "plangate.runtime-investigation-request/v1"

MACHINE_CANDIDATE_KINDS = (
    "runtime_role_registered",
    "provider_connector_registered",
    "hard_read_only_enforced",
    "admission_binding_verified",
)

EXPECTED_SOURCE_KIND = {
    "runtime_role_registered": "runtime_probe",
    "provider_connector_registered": "runtime_probe",
    "hard_read_only_enforced": "runtime_probe",
    "admission_binding_verified": "repository_evidence",
}

VALID_VERDICTS = {"pass", "fail", "unavailable"}


class DispatchReadinessError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _verify_request(request: Any) -> list[str]:
    if not isinstance(request, dict):
        return ["request: object required"]

    errors: list[str] = []
    if request.get("domain") != REQUEST_DOMAIN:
        errors.append(f"request.domain: {REQUEST_DOMAIN} required")
    if request.get("mode") != "r1_shadow_request":
        errors.append("request.mode: r1_shadow_request required")

    claimed_hash = request.get("request_hash")
    body = copy.deepcopy(request)
    body.pop("request_hash", None)
    actual_hash = ingress._canonical_hash(body)
    if claimed_hash != actual_hash:
        errors.append("request.request_hash: canonical request hash mismatch")

    authority = request.get("authority")
    if not isinstance(authority, dict):
        errors.append("request.authority: object required")
    else:
        forbidden_true = [
            key
            for key, value in authority.items()
            if key.endswith("_allowed")
            and key not in {
                "evidence_read_allowed",
                "repository_read_allowed",
                "approved_provider_read_allowed",
                "read_only_shell_allowed",
            }
            and value is not False
        ]
        if forbidden_true:
            errors.append(
                f"request.authority: mutation/execution authority must remain false: {forbidden_true}"
            )
        if authority.get("agent_invoke_allowed") is not False:
            errors.append("request.authority.agent_invoke_allowed: false required")

    pre = request.get("pre_run_activation")
    if not isinstance(pre, dict):
        errors.append("request.pre_run_activation: object required")
    else:
        if pre.get("dispatch_allowed") is not False:
            errors.append("request.pre_run_activation.dispatch_allowed: false required")
        if pre.get("dispatched") is not False:
            errors.append("request.pre_run_activation.dispatched: false required")
        if pre.get("result_received") is not False:
            errors.append("request.pre_run_activation.result_received: false required")

    v2 = request.get("v2_run_activation")
    if not isinstance(v2, dict) or v2.get("applicable") is not False:
        errors.append("request.v2_run_activation.applicable: false required pre-PBI")

    return errors


def _safe_repo_evidence(
    repo_root: str | pathlib.Path,
    ref: Any,
    expected_sha: Any,
) -> list[str]:
    errors = ingress.pm._validate_repo_relative_ref_syntax(ref, "evidence_ref")
    if errors:
        return errors
    if not isinstance(ref, str):
        return ["evidence_ref: string required"]
    if not ref.startswith("docs/working/"):
        return ["evidence_ref: must remain under docs/working/"]
    if not isinstance(expected_sha, str) or not expected_sha.startswith("sha256:"):
        return ["evidence_sha: sha256 digest required"]

    root = pathlib.Path(repo_root).resolve()
    if not root.is_dir():
        return ["repo_root: existing directory required"]

    pure = pathlib.PurePosixPath(ref)
    target = root.joinpath(*pure.parts)

    cursor = root
    for part in pure.parts[:-1]:
        cursor = cursor / part
        if not cursor.exists() and not cursor.is_symlink():
            return [f"evidence_ref: parent missing: {cursor.relative_to(root)}"]
        mode = cursor.lstat().st_mode
        if stat.S_ISLNK(mode):
            return [f"evidence_ref: parent contains symlink: {cursor.relative_to(root)}"]
        if not stat.S_ISDIR(mode):
            return [f"evidence_ref: parent is not directory: {cursor.relative_to(root)}"]

    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(target, flags)
    except OSError as exc:
        return [f"evidence_ref: cannot open safely: {exc}"]

    try:
        mode = os.fstat(fd).st_mode
        if not stat.S_ISREG(mode):
            return ["evidence_ref: regular file required"]
        with os.fdopen(fd, "rb", closefd=True) as handle:
            fd = -1
            actual_sha = _sha256_bytes(handle.read())
    finally:
        if fd >= 0:
            os.close(fd)

    if actual_sha != expected_sha:
        return ["evidence_sha: evidence content hash mismatch"]
    return []


def _validate_observation(
    *,
    repo_root: str | pathlib.Path,
    request: dict[str, Any],
    observation: Any,
    index: int,
) -> list[str]:
    prefix = f"observations[{index}]"
    if not isinstance(observation, dict):
        return [f"{prefix}: object required"]

    errors = [
        f"{prefix}: {error}"
        for error in ingress._forbidden_input_errors(observation)
    ]

    allowed_keys = {
        "schema_version",
        "domain",
        "kind",
        "request_hash",
        "platform",
        "observed_at",
        "source_kind",
        "verdict",
        "evidence_ref",
        "evidence_sha",
        "role",
        "config_sha",
        "provider",
        "source_ref",
    }
    unknown = sorted(set(observation) - allowed_keys)
    if unknown:
        errors.append(f"{prefix}: unsupported keys: {unknown}")

    if observation.get("schema_version") != "1":
        errors.append(f"{prefix}.schema_version: 1 required")
    if observation.get("domain") != OBS_DOMAIN:
        errors.append(f"{prefix}.domain: {OBS_DOMAIN} required")

    kind = observation.get("kind")
    if kind not in MACHINE_CANDIDATE_KINDS:
        errors.append(f"{prefix}.kind: one of {list(MACHINE_CANDIDATE_KINDS)} required")
        kind = None

    if observation.get("request_hash") != request.get("request_hash"):
        errors.append(f"{prefix}.request_hash: must bind exact R1 request")

    platform = request.get("runtime_guard", {}).get("platform")
    if observation.get("platform") != platform:
        errors.append(f"{prefix}.platform: must match request runtime platform")

    if ingress.pm._parse_rfc3339(observation.get("observed_at")) is None:
        errors.append(f"{prefix}.observed_at: timezone-aware RFC3339 required")

    source_kind = observation.get("source_kind")
    if kind is not None and source_kind != EXPECTED_SOURCE_KIND[kind]:
        errors.append(
            f"{prefix}.source_kind: {EXPECTED_SOURCE_KIND[kind]} required for {kind}"
        )

    verdict = observation.get("verdict")
    if verdict not in VALID_VERDICTS:
        errors.append(f"{prefix}.verdict: one of {sorted(VALID_VERDICTS)} required")

    evidence_errors = _safe_repo_evidence(
        repo_root,
        observation.get("evidence_ref"),
        observation.get("evidence_sha"),
    )
    errors.extend(f"{prefix}: {error}" for error in evidence_errors)

    role = request.get("role", {})
    source = request.get("source", {})

    if kind in {"runtime_role_registered", "hard_read_only_enforced"}:
        if observation.get("role") != role.get("runtime_role"):
            errors.append(f"{prefix}.role: must match request runtime role")
        if observation.get("config_sha") != role.get("config_sha"):
            errors.append(f"{prefix}.config_sha: must match exact Explorer config")

    if kind == "provider_connector_registered":
        if observation.get("provider") != source.get("provider"):
            errors.append(f"{prefix}.provider: must match runtime source provider")

    if kind == "admission_binding_verified":
        if observation.get("source_ref") != source.get("source_ref"):
            errors.append(f"{prefix}.source_ref: must bind exact runtime source")

    return errors


def evaluate_dispatch_readiness(
    *,
    repo_root: str | pathlib.Path,
    request: Any,
    observations: Any,
) -> dict[str, Any]:
    errors = _verify_request(request)
    if not isinstance(observations, list):
        errors.append("observations: array required")
        observations = []

    if isinstance(request, dict):
        for index, observation in enumerate(observations):
            errors.extend(
                _validate_observation(
                    repo_root=repo_root,
                    request=request,
                    observation=observation,
                    index=index,
                )
            )

    if errors:
        raise DispatchReadinessError(errors)

    assert isinstance(request, dict)
    by_kind: dict[str, list[dict[str, Any]]] = {kind: [] for kind in MACHINE_CANDIDATE_KINDS}
    for observation in observations:
        by_kind[observation["kind"]].append(observation)

    direct: dict[str, bool] = {}
    conflicts: list[str] = []
    evidence_refs: dict[str, list[str]] = {}

    for kind in MACHINE_CANDIDATE_KINDS:
        entries = by_kind[kind]
        verdicts = {entry["verdict"] for entry in entries}
        if "pass" in verdicts and ("fail" in verdicts or "unavailable" in verdicts):
            conflicts.append(kind)
        direct[kind] = verdicts == {"pass"}
        evidence_refs[kind] = sorted({entry["evidence_ref"] for entry in entries})

    pre = request["pre_run_activation"]
    static_candidate = (
        pre.get("installed") is True
        and pre.get("read_only_declared") is True
        and pre.get("static_sandbox_candidate") is True
    )

    machine_candidate_complete = (
        static_candidate
        and all(direct.values())
        and not conflicts
    )
    requirements = {
        "static_read_only_candidate": static_candidate,
        "machine_candidate_evidence_complete": machine_candidate_complete,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "no_conflicting_observations": not conflicts,
    }

    # Repository files can prove shape/content binding, but they cannot prove that
    # a runtime actually emitted the observation or that a Human authorized rollout.
    # Those two authorities need independent verifiers/adapters; self-declared
    # source_kind strings are never sufficient.
    dispatch_ready = False

    result = {
        "schema_version": "1",
        "domain": "plangate.runtime-dispatch-readiness/v1",
        "mode": "r1_shadow_readiness",
        "request_hash": request["request_hash"],
        "source_ref": request["source"]["source_ref"],
        "platform": request["runtime_guard"]["platform"],
        "role": {
            "runtime_role": request["role"]["runtime_role"],
            "config_ref": request["role"]["config_ref"],
            "config_sha": request["role"]["config_sha"],
        },
        "provider": request["source"]["provider"],
        "requirements": requirements,
        "candidate_observations": direct,
        "evidence_refs": evidence_refs,
        "provenance": {
            "repository_content_verified": True,
            "runtime_probe_attestation_verified": False,
            "human_rollout_decision_verified": False,
            "note": (
                "repository-visible observation files are candidate evidence only; "
                "they do not authenticate their own runtime/Human provenance"
            ),
        },
        "conflicts": conflicts,
        "dispatch_ready": dispatch_ready,
        "dispatch_allowed": False,
        "dispatch_allowed_reason": (
            "candidate machine evidence cannot self-attest runtime provenance or Human rollout authority"
        ),
        "v2_run_activation": {
            "applicable": False,
            "reason": (
                "pre-PBI readiness does not emit selected/fired/"
                "produced_evidence/influenced_decision RunEvents"
            ),
        },
        "authority": {
            "agent_invoke_allowed": False,
            "pbi_write_allowed": False,
            "issue_write_allowed": False,
            "code_write_allowed": False,
            "approval_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
            "publish_allowed": False,
        },
    }
    result["result_hash"] = ingress._canonical_hash(result)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--request", required=True)
    parser.add_argument("--observations", required=True)
    args = parser.parse_args(argv)

    try:
        request = json.loads(pathlib.Path(args.request).read_text(encoding="utf-8"))
        observations = json.loads(
            pathlib.Path(args.observations).read_text(encoding="utf-8")
        )
        result = evaluate_dispatch_readiness(
            repo_root=args.repo_root,
            request=request,
            observations=observations,
        )
    except (
        OSError,
        json.JSONDecodeError,
        DispatchReadinessError,
    ) as exc:
        if isinstance(exc, DispatchReadinessError):
            for error in exc.errors:
                print(f"ERROR: {error}", file=sys.stderr)
        else:
            print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
