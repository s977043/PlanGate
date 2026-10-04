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

__doc__ = """Validate a bounded external-verifier receipt candidate for R1 evidence.

This #1468 slice is intentionally a consumer-only contract. It can prove that a
receipt has a closed schema, exact command-candidate binding, bounded freshness,
a one-time challenge binding, and no replay in a caller-supplied consumed set.

It cannot prove that the receipt was genuinely issued by an independently
administered verifier. Therefore every cryptographic / independent-admin /
runtime / Human / dispatch authority flag remains false until a separately
reviewed signature/provenance verifier establishes that trust root.
"""

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import sys
from typing import Any, Iterable

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_codex_probe_candidate as probe  # noqa: E402
import runtime_evidence_github_attestation_receipt as fileio  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-external-verifier-receipt/v1"
CONTRACT_STAGE = "r1-external-verifier-receipt-candidate-v1"
EXTERNAL_RECEIPT_DOMAIN = "plangate.independent-runtime-verifier-receipt/v1"
MAX_JSON_BYTES = 256 * 1024
MAX_RECEIPT_TTL_SECONDS = 15 * 60
TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
RECEIPT_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")

AUTHORITY_KEYS = {
    "agent_invoke_allowed",
    "code_write_allowed",
    "approval_write_allowed",
    "merge_allowed",
    "deploy_allowed",
}

COMMAND_RESULT_KEYS = {
    "schema_version",
    "domain",
    "contract_stage",
    "request_hash",
    "config_sha",
    "provider",
    "platform",
    "capture_id",
    "candidate_receipt_hash",
    "capture_manifest_hash",
    "capture_manifest_file_sha256",
    "attestation_repo",
    "signer_repo",
    "signer_workflow",
    "source_digest",
    "signer_digest",
    "source_ref",
    "oidc_issuer",
    "predicate_type",
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
    "verification_limit",
    "authority",
    "result_hash",
}

COMMAND_REQUIRED_TRUE = {
    "exact_verifier_policy_bound_candidate",
    "gh_attestation_verify_exit_success_candidate",
    "capture_manifest_artifact_binding_candidate",
    "signer_workflow_policy_requested_candidate",
    "source_digest_policy_requested_candidate",
    "signer_digest_policy_requested_candidate",
    "self_hosted_runner_denial_requested_candidate",
}

STRONG_VERIFICATION_FIELDS = {
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
}

EXTERNAL_CLAIM_KEYS = {
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
}

EXTERNAL_RECEIPT_KEYS = {
    "schema_version",
    "domain",
    "receipt_id",
    "request_hash",
    "config_sha",
    "provider",
    "platform",
    "capture_id",
    "command_candidate_hash",
    "capture_manifest_file_sha256",
    "attestation_repo",
    "signer_repo",
    "signer_workflow",
    "source_digest",
    "signer_digest",
    "source_ref",
    "challenge_hash",
    "issued_at",
    "expires_at",
    "claims",
    "receipt_hash",
}


class ExternalVerifierReceiptError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _decode_json(raw: bytes, *, field: str) -> Any:
    if len(raw) > MAX_JSON_BYTES:
        raise ExternalVerifierReceiptError(
            [f"{field}: file exceeds {MAX_JSON_BYTES} byte limit"]
        )
    try:
        return fileio._decode_json_bytes(raw, field=field, max_bytes=MAX_JSON_BYTES)
    except fileio.GitHubAttestationReceiptError as exc:
        raise ExternalVerifierReceiptError(exc.errors) from exc


def _parse_time(value: Any, field: str) -> dt.datetime:
    if not isinstance(value, str) or TIME_RE.fullmatch(value) is None:
        raise ExternalVerifierReceiptError(
            [f"{field}: UTC timestamp YYYY-MM-DDTHH:MM:SSZ required"]
        )
    try:
        parsed = dt.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise ExternalVerifierReceiptError([f"{field}: invalid UTC timestamp"]) from exc
    return parsed.replace(tzinfo=dt.timezone.utc)


def _validate_hash(value: Any, field: str, errors: list[str]) -> None:
    if not isinstance(value, str) or probe.HASH_RE.fullmatch(value) is None:
        errors.append(f"{field}: sha256:<64 lowercase hex> required")


def _validate_command_candidate(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["command_candidate: object required"]
    errors: list[str] = []
    unknown = sorted(set(value) - COMMAND_RESULT_KEYS)
    missing = sorted(COMMAND_RESULT_KEYS - set(value))
    if unknown:
        errors.append(f"command_candidate: unsupported keys: {unknown}")
    if missing:
        errors.append(f"command_candidate: missing keys: {missing}")

    if value.get("schema_version") != "1":
        errors.append("command_candidate.schema_version: 1 required")
    if value.get("domain") != command.DOMAIN:
        errors.append("command_candidate.domain: exact #1470 domain required")
    if value.get("contract_stage") != command.CONTRACT_STAGE:
        errors.append("command_candidate.contract_stage: exact #1470 stage required")
    if value.get("platform") != "codex":
        errors.append("command_candidate.platform: codex required")

    for field in (
        "request_hash",
        "config_sha",
        "candidate_receipt_hash",
        "capture_manifest_hash",
        "capture_manifest_file_sha256",
    ):
        _validate_hash(value.get(field), f"command_candidate.{field}", errors)

    provider = value.get("provider")
    if not isinstance(provider, str) or ingress.PROVIDER_RE.fullmatch(provider) is None:
        errors.append("command_candidate.provider: provider-neutral identifier required")

    body = dict(value)
    claimed_hash = body.pop("result_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("command_candidate.result_hash: canonical hash mismatch")

    for field in COMMAND_REQUIRED_TRUE:
        if value.get(field) is not True:
            errors.append(f"command_candidate.{field}: true required")
    for field in STRONG_VERIFICATION_FIELDS:
        if value.get(field) is not False:
            errors.append(f"command_candidate.{field}: false required")

    authority = value.get("authority")
    if not isinstance(authority, dict) or set(authority) != AUTHORITY_KEYS:
        errors.append("command_candidate.authority: exact key set required")
    elif any(authority.get(field) is not False for field in AUTHORITY_KEYS):
        errors.append("command_candidate.authority: all values must remain false")
    return errors


def _validate_external_receipt(
    receipt: Any,
    *,
    command_candidate: dict[str, Any],
    expected_challenge_hash: str,
    observed_at: str,
    consumed_receipt_hashes: Iterable[str],
) -> list[str]:
    if not isinstance(receipt, dict):
        return ["external_receipt: object required"]
    errors: list[str] = []
    unknown = sorted(set(receipt) - EXTERNAL_RECEIPT_KEYS)
    missing = sorted(EXTERNAL_RECEIPT_KEYS - set(receipt))
    if unknown:
        errors.append(f"external_receipt: unsupported keys: {unknown}")
    if missing:
        errors.append(f"external_receipt: missing keys: {missing}")

    if receipt.get("schema_version") != "1":
        errors.append("external_receipt.schema_version: 1 required")
    if receipt.get("domain") != EXTERNAL_RECEIPT_DOMAIN:
        errors.append("external_receipt.domain: exact external-verifier domain required")

    receipt_id = receipt.get("receipt_id")
    if not isinstance(receipt_id, str) or RECEIPT_ID_RE.fullmatch(receipt_id) is None:
        errors.append("external_receipt.receipt_id: bounded opaque id required")

    for field in (
        "request_hash",
        "config_sha",
        "command_candidate_hash",
        "capture_manifest_file_sha256",
        "challenge_hash",
    ):
        _validate_hash(receipt.get(field), f"external_receipt.{field}", errors)

    if (
        not isinstance(expected_challenge_hash, str)
        or probe.HASH_RE.fullmatch(expected_challenge_hash) is None
    ):
        errors.append("expected_challenge_hash: valid SHA-256 required")
    elif receipt.get("challenge_hash") != expected_challenge_hash:
        errors.append("external_receipt.challenge_hash: exact expected challenge required")

    bindings = {
        "request_hash": "request_hash",
        "config_sha": "config_sha",
        "provider": "provider",
        "platform": "platform",
        "capture_id": "capture_id",
        "command_candidate_hash": "result_hash",
        "capture_manifest_file_sha256": "capture_manifest_file_sha256",
        "attestation_repo": "attestation_repo",
        "signer_repo": "signer_repo",
        "signer_workflow": "signer_workflow",
        "source_digest": "source_digest",
        "signer_digest": "signer_digest",
        "source_ref": "source_ref",
    }
    for receipt_field, command_field in bindings.items():
        if receipt.get(receipt_field) != command_candidate.get(command_field):
            errors.append(
                f"external_receipt.{receipt_field}: exact command-candidate binding required"
            )

    claims = receipt.get("claims")
    if not isinstance(claims, dict) or set(claims) != EXTERNAL_CLAIM_KEYS:
        errors.append("external_receipt.claims: exact claim key set required")
    elif any(claims.get(field) is not True for field in EXTERNAL_CLAIM_KEYS):
        errors.append("external_receipt.claims: all external claims must be true")

    body = dict(receipt)
    claimed_hash = body.pop("receipt_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("external_receipt.receipt_hash: canonical hash mismatch")

    seen: set[str] = set()
    for item in consumed_receipt_hashes:
        if not isinstance(item, str) or probe.HASH_RE.fullmatch(item) is None:
            errors.append("consumed_receipt_hashes: every value must be a valid SHA-256")
            continue
        seen.add(item)
    if isinstance(claimed_hash, str) and claimed_hash in seen:
        errors.append("external_receipt.receipt_hash: replay detected")

    try:
        issued = _parse_time(receipt.get("issued_at"), "external_receipt.issued_at")
        expires = _parse_time(receipt.get("expires_at"), "external_receipt.expires_at")
        observed = _parse_time(observed_at, "observed_at")
    except ExternalVerifierReceiptError as exc:
        errors.extend(exc.errors)
    else:
        ttl = (expires - issued).total_seconds()
        if ttl <= 0:
            errors.append("external_receipt: expires_at must be after issued_at")
        elif ttl > MAX_RECEIPT_TTL_SECONDS:
            errors.append(
                f"external_receipt: TTL must be <= {MAX_RECEIPT_TTL_SECONDS} seconds"
            )
        if observed < issued:
            errors.append("external_receipt: observed_at precedes issued_at")
        if observed >= expires:
            errors.append("external_receipt: receipt is stale/expired")
    return errors


def verify_candidate_bytes(
    *,
    command_candidate_raw: bytes,
    external_receipt_raw: bytes,
    expected_challenge_hash: str,
    observed_at: str,
    consumed_receipt_hashes: Iterable[str] = (),
) -> dict[str, Any]:
    command_candidate = _decode_json(
        command_candidate_raw,
        field="command_candidate",
    )
    external_receipt = _decode_json(
        external_receipt_raw,
        field="external_receipt",
    )

    errors = _validate_command_candidate(command_candidate)
    if isinstance(command_candidate, dict):
        errors.extend(
            _validate_external_receipt(
                external_receipt,
                command_candidate=command_candidate,
                expected_challenge_hash=expected_challenge_hash,
                observed_at=observed_at,
                consumed_receipt_hashes=consumed_receipt_hashes,
            )
        )
    else:
        errors.append("external_receipt: cannot bind invalid command candidate")
    if errors:
        raise ExternalVerifierReceiptError(errors)

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": command_candidate["request_hash"],
        "config_sha": command_candidate["config_sha"],
        "provider": command_candidate["provider"],
        "platform": command_candidate["platform"],
        "capture_id": command_candidate["capture_id"],
        "command_candidate_hash": command_candidate["result_hash"],
        "capture_manifest_file_sha256": command_candidate[
            "capture_manifest_file_sha256"
        ],
        "external_receipt_hash": external_receipt["receipt_hash"],
        "external_receipt_file_sha256": _sha256_bytes(external_receipt_raw),
        "challenge_hash": external_receipt["challenge_hash"],
        "issued_at": external_receipt["issued_at"],
        "expires_at": external_receipt["expires_at"],
        "observed_at": observed_at,
        "exact_command_candidate_binding_verified_candidate": True,
        "external_receipt_self_hash_verified_candidate": True,
        "external_claim_set_complete_candidate": True,
        "challenge_binding_verified_candidate": True,
        "freshness_window_verified_candidate": True,
        "replay_absence_verified_candidate": True,
        "external_receipt_signature_verified": False,
        "external_receipt_origin_verified": False,
        "gh_attestation_cli_execution_verified": False,
        "artifact_digest_cryptographically_verified": False,
        "attestation_signature_cryptographically_verified": False,
        "signer_certificate_identity_verified": False,
        "verified_timestamp_cryptographically_verified": False,
        "signer_workflow_policy_verified": False,
        "source_digest_policy_verified": False,
        "self_hosted_runner_denial_verified": False,
        "capture_manifest_artifact_attestation_verified": False,
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
            "receipt structure, content binding, one-time challenge, bounded freshness, "
            "and caller-supplied replay absence are validated, but the repository has "
            "not authenticated the receipt signature/origin or independently attested "
            "the verifier execution; all strong authority remains false"
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
    parser.add_argument("--command-candidate", required=True)
    parser.add_argument("--external-receipt", required=True)
    parser.add_argument("--expected-challenge-hash", required=True)
    parser.add_argument("--observed-at", required=True)
    parser.add_argument("--consumed-receipt-hash", action="append", default=[])
    args = parser.parse_args(argv)

    try:
        command_raw = fileio.load_raw_bytes(
            args.command_candidate,
            repo_root=args.repo_root,
            field="command_candidate",
            max_bytes=MAX_JSON_BYTES,
        )
        receipt_raw = fileio.load_raw_bytes(
            args.external_receipt,
            repo_root=args.repo_root,
            field="external_receipt",
            max_bytes=MAX_JSON_BYTES,
        )
        result = verify_candidate_bytes(
            command_candidate_raw=command_raw,
            external_receipt_raw=receipt_raw,
            expected_challenge_hash=args.expected_challenge_hash,
            observed_at=args.observed_at,
            consumed_receipt_hashes=args.consumed_receipt_hash,
        )
    except (
        fileio.GitHubAttestationReceiptError,
        ExternalVerifierReceiptError,
    ) as exc:
        errors = getattr(exc, "errors", [str(exc)])
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
