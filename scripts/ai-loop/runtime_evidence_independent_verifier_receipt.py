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

__doc__ = """Validate a bounded external verifier execution receipt for #1468.

This consumer binds an externally produced receipt to the exact repository-local
verification-command candidate, an immutable verifier identity, a one-run
challenge, and a short validity window.

It deliberately does NOT prove that the external verifier is independently
administered, that the receipt is cryptographically signed, or that the same
challenge has not been consumed twice. Those require an external trust root /
one-time ledger and remain separate promotion work.
"""

import argparse
import json
import pathlib
import re
import sys
from datetime import datetime, timezone
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_codex_managed_capture_manifest as managed  # noqa: E402
import runtime_evidence_codex_probe_candidate as probe  # noqa: E402
import runtime_evidence_github_attestation_receipt as attestation_receipt  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command_verifier  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-independent-verifier-receipt/v1"
CONTRACT_STAGE = "r1-independent-verifier-receipt-candidate-v1"
MAX_JSON_BYTES = 256 * 1024
MAX_RECEIPT_TTL_SECONDS = 15 * 60

OPAQUE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
IDENTITY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9:/._@+-]{0,255}$")
WORKFLOW_REF_RE = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*/"
    r"\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml@[0-9a-f]{40}$"
)
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
SOURCE_REF_RE = re.compile(r"^refs/(?:heads|tags)/[A-Za-z0-9][A-Za-z0-9._/-]*$")
UTC_SECOND_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

COMMAND_RESULT_KEYS = {
    "schema_version", "domain", "contract_stage", "request_hash", "config_sha",
    "provider", "platform", "capture_id", "candidate_receipt_hash",
    "capture_manifest_hash", "capture_manifest_file_sha256", "attestation_repo",
    "signer_repo", "signer_workflow", "source_digest", "signer_digest",
    "source_ref", "oidc_issuer", "predicate_type",
    "exact_verifier_policy_bound_candidate",
    "gh_attestation_verify_exit_success_candidate",
    "capture_manifest_artifact_binding_candidate",
    "signer_workflow_policy_requested_candidate",
    "source_digest_policy_requested_candidate",
    "signer_digest_policy_requested_candidate",
    "self_hosted_runner_denial_requested_candidate",
    "gh_attestation_cli_execution_verified",
    "artifact_digest_cryptographically_verified",
    "attestation_signature_cryptographically_verified",
    "signer_certificate_identity_verified",
    "verified_timestamp_cryptographically_verified",
    "signer_workflow_policy_verified", "source_digest_policy_verified",
    "self_hosted_runner_denial_verified",
    "capture_manifest_artifact_attestation_verified",
    "independent_admin_boundary_verified",
    "independent_verifier_execution_attested", "managed_hook_root_attested",
    "same_run_identity_verified", "codex_jsonl_runtime_correlation_verified",
    "hard_read_only_enforced", "runtime_probe_attestation_verified",
    "human_rollout_decision_verified", "dispatch_ready", "dispatch_allowed",
    "verification_limit", "authority", "result_hash",
}

RECEIPT_KEYS = {
    "schema_version", "domain", "contract_stage", "receipt_id", "challenge_id",
    "request_hash", "config_sha", "provider", "platform", "capture_id",
    "verification_command_candidate_result_hash",
    "capture_manifest_file_sha256", "attestation_repo", "signer_repo",
    "signer_workflow", "source_digest", "signer_digest", "source_ref",
    "verifier_issuer", "verifier_workflow_ref", "verifier_binary_sha256",
    "execution_id", "issued_at", "expires_at", "receipt_hash",
}

AUTHORITY_KEYS = {
    "agent_invoke_allowed", "code_write_allowed", "approval_write_allowed",
    "merge_allowed", "deploy_allowed",
}

CANDIDATE_TRUE_FIELDS = (
    "exact_verifier_policy_bound_candidate",
    "gh_attestation_verify_exit_success_candidate",
    "capture_manifest_artifact_binding_candidate",
    "signer_workflow_policy_requested_candidate",
    "source_digest_policy_requested_candidate",
    "signer_digest_policy_requested_candidate",
    "self_hosted_runner_denial_requested_candidate",
)

STRONG_FALSE_FIELDS = (
    "gh_attestation_cli_execution_verified",
    "artifact_digest_cryptographically_verified",
    "attestation_signature_cryptographically_verified",
    "signer_certificate_identity_verified",
    "verified_timestamp_cryptographically_verified",
    "signer_workflow_policy_verified",
    "source_digest_policy_verified",
    "self_hosted_runner_denial_verified",
    "capture_manifest_artifact_attestation_verified",
    "independent_admin_boundary_verified",
    "independent_verifier_execution_attested",
    "managed_hook_root_attested",
    "same_run_identity_verified",
    "codex_jsonl_runtime_correlation_verified",
    "hard_read_only_enforced",
    "runtime_probe_attestation_verified",
    "human_rollout_decision_verified",
    "dispatch_ready",
    "dispatch_allowed",
)


class IndependentVerifierReceiptError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _decode_json_bytes(raw: bytes, *, field: str) -> Any:
    if len(raw) > MAX_JSON_BYTES:
        raise IndependentVerifierReceiptError(
            [f"{field}: exceeds {MAX_JSON_BYTES} byte limit"]
        )
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise IndependentVerifierReceiptError([f"{field}: UTF-8 required"]) from exc

    def pairs_hook(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise IndependentVerifierReceiptError(
                    [f"{field}: duplicate JSON key {key!r}"]
                )
            value[key] = item
        return value

    def reject_constant(value):
        raise IndependentVerifierReceiptError(
            [f"{field}: non-finite JSON number {value!r} not allowed"]
        )

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs_hook,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise IndependentVerifierReceiptError([f"{field}: invalid JSON"]) from exc


def _parse_utc_second(value: Any, field: str) -> datetime | None:
    if not isinstance(value, str) or UTC_SECOND_RE.fullmatch(value) is None:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=timezone.utc
        )
    except ValueError:
        return None


def _validate_command_result(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["verification_command_candidate: object required"]
    errors: list[str] = []
    if set(value) != COMMAND_RESULT_KEYS:
        errors.append("verification_command_candidate: exact key set required")
    if value.get("schema_version") != "1":
        errors.append("verification_command_candidate.schema_version: 1 required")
    if value.get("domain") != command_verifier.DOMAIN:
        errors.append("verification_command_candidate.domain: exact #1470 domain required")
    if value.get("contract_stage") != command_verifier.CONTRACT_STAGE:
        errors.append(
            "verification_command_candidate.contract_stage: exact #1470 stage required"
        )

    for field in (
        "request_hash", "config_sha", "candidate_receipt_hash",
        "capture_manifest_hash", "capture_manifest_file_sha256",
    ):
        if not isinstance(value.get(field), str) or probe.HASH_RE.fullmatch(
            value[field]
        ) is None:
            errors.append(
                f"verification_command_candidate.{field}: sha256:<64 lowercase hex> required"
            )

    provider = value.get("provider")
    if not isinstance(provider, str) or ingress.PROVIDER_RE.fullmatch(provider) is None:
        errors.append(
            "verification_command_candidate.provider: bounded provider identifier required"
        )
    if value.get("platform") != "codex":
        errors.append("verification_command_candidate.platform: codex required")
    capture_id = value.get("capture_id")
    if not isinstance(capture_id, str) or managed.CAPTURE_ID_RE.fullmatch(
        capture_id
    ) is None:
        errors.append("verification_command_candidate.capture_id: bounded id required")

    if not isinstance(value.get("attestation_repo"), str) or command_verifier.REPO_RE.fullmatch(
        value["attestation_repo"]
    ) is None:
        errors.append("verification_command_candidate.attestation_repo: owner/repo required")
    if not isinstance(value.get("signer_repo"), str) or command_verifier.REPO_RE.fullmatch(
        value["signer_repo"]
    ) is None:
        errors.append("verification_command_candidate.signer_repo: owner/repo required")
    signer_repo = value.get("signer_repo")
    signer_workflow = value.get("signer_workflow")
    expected_prefix = f"{signer_repo}/.github/workflows/"
    if (
        not isinstance(signer_workflow, str)
        or not signer_workflow.startswith(expected_prefix)
        or command_verifier.WORKFLOW_FILE_RE.fullmatch(
            signer_workflow.removeprefix(expected_prefix)
        ) is None
    ):
        errors.append(
            "verification_command_candidate.signer_workflow: exact signer-repo workflow required"
        )
    for field in ("source_digest", "signer_digest"):
        if not isinstance(value.get(field), str) or SHA40_RE.fullmatch(
            value[field]
        ) is None:
            errors.append(f"verification_command_candidate.{field}: git SHA required")
    source_ref = value.get("source_ref")
    if (
        not isinstance(source_ref, str)
        or ".." in source_ref
        or SOURCE_REF_RE.fullmatch(source_ref) is None
    ):
        errors.append("verification_command_candidate.source_ref: bounded ref required")
    if value.get("oidc_issuer") != command_verifier.OIDC_ISSUER:
        errors.append(
            "verification_command_candidate.oidc_issuer: exact GitHub Actions issuer required"
        )
    if value.get("predicate_type") != attestation_receipt.EXPECTED_PREDICATE_TYPE:
        errors.append(
            "verification_command_candidate.predicate_type: exact SLSA provenance v1 required"
        )

    body = dict(value)
    claimed_hash = body.pop("result_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("verification_command_candidate.result_hash: canonical hash mismatch")

    for field in CANDIDATE_TRUE_FIELDS:
        if value.get(field) is not True:
            errors.append(f"verification_command_candidate.{field}: true required")
    for field in STRONG_FALSE_FIELDS:
        if value.get(field) is not False:
            errors.append(f"verification_command_candidate.{field}: false required")

    authority = value.get("authority")
    if not isinstance(authority, dict) or set(authority) != AUTHORITY_KEYS:
        errors.append("verification_command_candidate.authority: exact key set required")
    elif any(authority.get(field) is not False for field in AUTHORITY_KEYS):
        errors.append("verification_command_candidate.authority: all values false required")
    return errors


def _validate_receipt(
    receipt: Any,
    *,
    command_result: dict[str, Any],
    expected_challenge_id: str,
    expected_verifier_issuer: str,
    expected_verifier_workflow_ref: str,
    expected_verifier_binary_sha256: str,
    observed_at: str,
) -> list[str]:
    if not isinstance(receipt, dict):
        return ["verifier_receipt: object required"]
    errors: list[str] = []
    if set(receipt) != RECEIPT_KEYS:
        errors.append("verifier_receipt: exact key set required")
    if receipt.get("schema_version") != "1":
        errors.append("verifier_receipt.schema_version: 1 required")
    if receipt.get("domain") != DOMAIN:
        errors.append("verifier_receipt.domain: exact domain required")
    if receipt.get("contract_stage") != CONTRACT_STAGE:
        errors.append("verifier_receipt.contract_stage: exact stage required")

    for field in ("receipt_id", "execution_id"):
        item = receipt.get(field)
        if not isinstance(item, str) or OPAQUE_ID_RE.fullmatch(item) is None:
            errors.append(f"verifier_receipt.{field}: bounded opaque id required")

    challenge = receipt.get("challenge_id")
    if not isinstance(challenge, str) or probe.HASH_RE.fullmatch(challenge) is None:
        errors.append("verifier_receipt.challenge_id: sha256 challenge required")
    if expected_challenge_id != challenge:
        errors.append("verifier_receipt.challenge_id: exact run challenge required")

    exact_bindings = {
        "request_hash": "request_hash",
        "config_sha": "config_sha",
        "provider": "provider",
        "platform": "platform",
        "capture_id": "capture_id",
        "verification_command_candidate_result_hash": "result_hash",
        "capture_manifest_file_sha256": "capture_manifest_file_sha256",
        "attestation_repo": "attestation_repo",
        "signer_repo": "signer_repo",
        "signer_workflow": "signer_workflow",
        "source_digest": "source_digest",
        "signer_digest": "signer_digest",
        "source_ref": "source_ref",
    }
    for receipt_field, command_field in exact_bindings.items():
        if receipt.get(receipt_field) != command_result.get(command_field):
            errors.append(
                f"verifier_receipt.{receipt_field}: exact command-candidate binding required"
            )

    issuer = receipt.get("verifier_issuer")
    if not isinstance(issuer, str) or IDENTITY_RE.fullmatch(issuer) is None:
        errors.append("verifier_receipt.verifier_issuer: bounded identity required")
    if issuer != expected_verifier_issuer:
        errors.append("verifier_receipt.verifier_issuer: expected issuer mismatch")

    workflow_ref = receipt.get("verifier_workflow_ref")
    if not isinstance(workflow_ref, str) or WORKFLOW_REF_RE.fullmatch(
        workflow_ref
    ) is None:
        errors.append(
            "verifier_receipt.verifier_workflow_ref: immutable workflow@sha required"
        )
    if workflow_ref != expected_verifier_workflow_ref:
        errors.append("verifier_receipt.verifier_workflow_ref: expected identity mismatch")

    binary = receipt.get("verifier_binary_sha256")
    if not isinstance(binary, str) or probe.HASH_RE.fullmatch(binary) is None:
        errors.append(
            "verifier_receipt.verifier_binary_sha256: sha256 verifier digest required"
        )
    if binary != expected_verifier_binary_sha256:
        errors.append("verifier_receipt.verifier_binary_sha256: expected digest mismatch")

    issued = _parse_utc_second(receipt.get("issued_at"), "issued_at")
    expires = _parse_utc_second(receipt.get("expires_at"), "expires_at")
    observed = _parse_utc_second(observed_at, "observed_at")
    if issued is None:
        errors.append("verifier_receipt.issued_at: RFC3339 UTC seconds required")
    if expires is None:
        errors.append("verifier_receipt.expires_at: RFC3339 UTC seconds required")
    if observed is None:
        errors.append("observed_at: RFC3339 UTC seconds required")
    if issued is not None and expires is not None:
        ttl = (expires - issued).total_seconds()
        if ttl <= 0 or ttl > MAX_RECEIPT_TTL_SECONDS:
            errors.append(
                f"verifier_receipt: validity window must be 1..{MAX_RECEIPT_TTL_SECONDS}s"
            )
    if issued is not None and observed is not None and observed < issued:
        errors.append("verifier_receipt: observed_at before issued_at")
    if expires is not None and observed is not None and observed >= expires:
        errors.append("verifier_receipt: stale/expired receipt")

    body = dict(receipt)
    claimed_hash = body.pop("receipt_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("verifier_receipt.receipt_hash: canonical content hash mismatch")
    return errors


def verify_receipt_bytes(
    *,
    verification_command_candidate_raw: bytes,
    verifier_receipt_raw: bytes,
    expected_challenge_id: str,
    expected_verifier_issuer: str,
    expected_verifier_workflow_ref: str,
    expected_verifier_binary_sha256: str,
    observed_at: str,
) -> dict[str, Any]:
    command_result = _decode_json_bytes(
        verification_command_candidate_raw,
        field="verification_command_candidate",
    )
    receipt = _decode_json_bytes(
        verifier_receipt_raw,
        field="verifier_receipt",
    )
    errors = _validate_command_result(command_result)
    if isinstance(command_result, dict):
        errors.extend(
            _validate_receipt(
                receipt,
                command_result=command_result,
                expected_challenge_id=expected_challenge_id,
                expected_verifier_issuer=expected_verifier_issuer,
                expected_verifier_workflow_ref=expected_verifier_workflow_ref,
                expected_verifier_binary_sha256=expected_verifier_binary_sha256,
                observed_at=observed_at,
            )
        )
    else:
        errors.append("verifier_receipt: cannot bind invalid command candidate")
    if errors:
        raise IndependentVerifierReceiptError(errors)

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "receipt_id": receipt["receipt_id"],
        "challenge_id": receipt["challenge_id"],
        "request_hash": command_result["request_hash"],
        "config_sha": command_result["config_sha"],
        "provider": command_result["provider"],
        "platform": command_result["platform"],
        "capture_id": command_result["capture_id"],
        "verification_command_candidate_result_hash": command_result["result_hash"],
        "verifier_receipt_hash": receipt["receipt_hash"],
        "capture_manifest_file_sha256": command_result[
            "capture_manifest_file_sha256"
        ],
        "attestation_repo": command_result["attestation_repo"],
        "signer_repo": command_result["signer_repo"],
        "signer_workflow": command_result["signer_workflow"],
        "source_digest": command_result["source_digest"],
        "signer_digest": command_result["signer_digest"],
        "source_ref": command_result["source_ref"],
        "verifier_issuer": receipt["verifier_issuer"],
        "verifier_workflow_ref": receipt["verifier_workflow_ref"],
        "verifier_binary_sha256": receipt["verifier_binary_sha256"],
        "execution_id": receipt["execution_id"],
        "issued_at": receipt["issued_at"],
        "expires_at": receipt["expires_at"],
        "observed_at": observed_at,
        "external_receipt_structure_candidate": True,
        "external_receipt_content_addressed_candidate": True,
        "external_receipt_exact_binding_candidate": True,
        "immutable_verifier_identity_binding_candidate": True,
        "freshness_window_candidate": True,
        "run_challenge_binding_candidate": True,
        "cross_run_replay_binding_candidate": True,
        "same_challenge_replay_prevented": False,
        "receipt_signature_verified": False,
        "gh_attestation_cli_execution_verified": False,
        "artifact_digest_cryptographically_verified": False,
        "attestation_signature_cryptographically_verified": False,
        "signer_certificate_identity_verified": False,
        "verified_timestamp_cryptographically_verified": False,
        "signer_workflow_policy_verified": False,
        "source_digest_policy_verified": False,
        "self_hosted_runner_denial_verified": False,
        "independent_admin_boundary_verified": False,
        "independent_verifier_execution_attested": False,
        "managed_hook_root_attested": False,
        "same_run_identity_verified": False,
        "codex_jsonl_runtime_correlation_verified": False,
        "hard_read_only_enforced": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "receipt shape, canonical content hash, exact command/request/config/provider/"
            "artifact/policy binding, immutable verifier identity expectation, run challenge, "
            "and short freshness window are validated; receipt signature, independently "
            "administered execution provenance, and same-challenge one-time consumption "
            "are not proven, so cryptographic/runtime/dispatch promotion remains blocked"
        ),
        "authority": {
            "agent_invoke_allowed": False,
            "code_write_allowed": False,
            "approval_write_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }
    result["result_hash"] = ingress._canonical_hash(result)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--verification-command-candidate", required=True)
    parser.add_argument("--verifier-receipt", required=True)
    parser.add_argument("--expected-challenge-id", required=True)
    parser.add_argument("--expected-verifier-issuer", required=True)
    parser.add_argument("--expected-verifier-workflow-ref", required=True)
    parser.add_argument("--expected-verifier-binary-sha256", required=True)
    parser.add_argument("--observed-at", required=True)
    args = parser.parse_args(argv)

    try:
        command_raw = attestation_receipt.load_raw_bytes(
            args.verification_command_candidate,
            repo_root=args.repo_root,
            field="verification_command_candidate",
            max_bytes=MAX_JSON_BYTES,
        )
        receipt_raw = attestation_receipt.load_raw_bytes(
            args.verifier_receipt,
            repo_root=args.repo_root,
            field="verifier_receipt",
            max_bytes=MAX_JSON_BYTES,
        )
        result = verify_receipt_bytes(
            verification_command_candidate_raw=command_raw,
            verifier_receipt_raw=receipt_raw,
            expected_challenge_id=args.expected_challenge_id,
            expected_verifier_issuer=args.expected_verifier_issuer,
            expected_verifier_workflow_ref=args.expected_verifier_workflow_ref,
            expected_verifier_binary_sha256=args.expected_verifier_binary_sha256,
            observed_at=args.observed_at,
        )
    except (
        attestation_receipt.GitHubAttestationReceiptError,
        IndependentVerifierReceiptError,
    ) as exc:
        errors = getattr(exc, "errors", [str(exc)])
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
