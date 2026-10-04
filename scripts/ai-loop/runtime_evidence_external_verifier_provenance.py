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

__doc__ = """Validate candidate provenance for an externally executed R1 verifier.

This layer consumes the #1471 external-verifier receipt result and a separate
external provenance receipt that names an immutable verifier workflow identity,
binary digest, execution id, and per-run challenge.

The expected identity/challenge values are caller supplied and therefore remain
candidate policy inputs. This module performs no cryptographic verification and
cannot prove that the named verifier is independently administered. All strong
runtime, Human, and dispatch authority remains false.
"""

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import stat
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_receipt as upstream  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-external-verifier-provenance/v1"
CONTRACT_STAGE = "r1-external-verifier-provenance-candidate-v1"
RECEIPT_DOMAIN = "plangate.runtime-r1-external-verifier-provenance-input/v1"
RECEIPT_STAGE = "r1-external-verifier-provenance-input-v1"
MAX_JSON_BYTES = 2 * 1024 * 1024
MAX_VALIDITY_SECONDS = 15 * 60
MAX_FUTURE_SKEW_SECONDS = 60

HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
OPAQUE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/@+-]{0,255}$")
WORKFLOW_REF_RE = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*/"
    r"\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml@[0-9a-f]{40}$"
)

AUTHORITY_KEYS = {
    "agent_invoke_allowed",
    "code_write_allowed",
    "approval_write_allowed",
    "merge_allowed",
    "deploy_allowed",
}

UPSTREAM_KEYS = {
    "schema_version", "domain", "contract_stage", "request_hash", "config_sha",
    "provider", "platform", "capture_id", "command_candidate_result_hash",
    "command_candidate_file_sha256", "external_receipt_file_sha256",
    "verification_nonce", "issued_at", "expires_at", "verifier_id",
    "verifier_version", "verifier_binary_sha256", "receipt_structure_verified",
    "receipt_candidate_binding_verified", "receipt_content_addressed",
    "receipt_nonce_binding_verified", "receipt_freshness_verified",
    "receipt_artifact_digest_binding_candidate",
    "receipt_attestation_verify_exit_success_candidate",
    "receipt_claims_authenticated", "gh_attestation_cli_execution_verified",
    "artifact_digest_cryptographically_verified",
    "attestation_signature_cryptographically_verified",
    "signer_certificate_identity_verified",
    "verified_timestamp_cryptographically_verified",
    "signer_workflow_policy_verified", "source_digest_policy_verified",
    "self_hosted_runner_denial_verified", "independent_admin_boundary_verified",
    "independent_verifier_execution_attested", "managed_hook_root_attested",
    "same_run_identity_verified", "codex_jsonl_runtime_correlation_verified",
    "hard_read_only_enforced", "runtime_probe_attestation_verified",
    "human_rollout_decision_verified", "dispatch_ready", "dispatch_allowed",
    "verification_limit", "authority", "result_hash",
}

UPSTREAM_TRUE_FIELDS = (
    "receipt_structure_verified",
    "receipt_candidate_binding_verified",
    "receipt_content_addressed",
    "receipt_nonce_binding_verified",
    "receipt_freshness_verified",
    "receipt_artifact_digest_binding_candidate",
    "receipt_attestation_verify_exit_success_candidate",
)

UPSTREAM_FALSE_FIELDS = (
    "receipt_claims_authenticated",
    "gh_attestation_cli_execution_verified",
    "artifact_digest_cryptographically_verified",
    "attestation_signature_cryptographically_verified",
    "signer_certificate_identity_verified",
    "verified_timestamp_cryptographically_verified",
    "signer_workflow_policy_verified",
    "source_digest_policy_verified",
    "self_hosted_runner_denial_verified",
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

PROVENANCE_KEYS = {
    "schema_version", "domain", "contract_stage", "request_hash", "config_sha",
    "provider", "platform", "capture_id",
    "external_verifier_result_hash", "external_verifier_result_file_sha256",
    "external_receipt_file_sha256", "verification_nonce",
    "verifier_id", "verifier_version", "verifier_binary_sha256",
    "verifier_issuer", "verifier_workflow_ref", "execution_id", "challenge_id",
    "issued_at", "expires_at", "provenance_receipt_hash",
}


class ExternalVerifierProvenanceError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _strict_json_loads(raw: bytes, field: str) -> Any:
    if len(raw) > MAX_JSON_BYTES:
        raise ExternalVerifierProvenanceError([f"{field}: exceeds JSON byte limit"])
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ExternalVerifierProvenanceError([f"{field}: UTF-8 required"]) from exc

    def pairs_hook(pairs):
        out = {}
        for key, value in pairs:
            if key in out:
                raise ExternalVerifierProvenanceError(
                    [f"{field}: duplicate JSON key {key!r}"]
                )
            out[key] = value
        return out

    def reject_constant(value: str):
        raise ExternalVerifierProvenanceError(
            [f"{field}: non-finite JSON number {value!r} not allowed"]
        )

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs_hook,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise ExternalVerifierProvenanceError([f"{field}: invalid JSON"]) from exc


def _require_external_regular_file(path, *, repo_root, field) -> bytes:
    root = pathlib.Path(repo_root).resolve()
    source = pathlib.Path(path)
    if not source.is_absolute():
        raise ExternalVerifierProvenanceError([f"{field}: absolute path required"])
    if not source.parent.is_dir() or source.parent.resolve() != source.parent:
        raise ExternalVerifierProvenanceError(
            [f"{field}: parent must exist and not traverse symlinks"]
        )
    if not source.exists():
        raise ExternalVerifierProvenanceError([f"{field}: file must exist"])
    mode = source.lstat().st_mode
    if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
        raise ExternalVerifierProvenanceError(
            [f"{field}: regular non-symlink file required"]
        )
    target = source.resolve()
    try:
        target.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False
    if inside_repo:
        raise ExternalVerifierProvenanceError(
            [f"{field}: verifier provenance artifact must stay outside repository"]
        )
    raw = source.read_bytes()
    if len(raw) > MAX_JSON_BYTES:
        raise ExternalVerifierProvenanceError([f"{field}: exceeds JSON byte limit"])
    return raw


def _parse_rfc3339(value: Any) -> dt.datetime | None:
    if not isinstance(value, str):
        return None
    text = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        return None
    return parsed.astimezone(dt.timezone.utc)


def _validate_authority(value: Any, field: str, errors: list[str]) -> None:
    if not isinstance(value, dict) or set(value) != AUTHORITY_KEYS:
        errors.append(f"{field}: exact authority key set required")
        return
    if any(value.get(key) is not False for key in AUTHORITY_KEYS):
        errors.append(f"{field}: all authority values must remain false")


def _validate_upstream(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["external_verifier_result: object required"]
    errors: list[str] = []
    if set(value) != UPSTREAM_KEYS:
        errors.append("external_verifier_result: exact #1471 key set required")
    if value.get("schema_version") != "1":
        errors.append("external_verifier_result.schema_version: 1 required")
    if value.get("domain") != upstream.DOMAIN:
        errors.append("external_verifier_result.domain: exact #1471 domain required")
    if value.get("contract_stage") != upstream.CONTRACT_STAGE:
        errors.append("external_verifier_result.contract_stage: exact #1471 stage required")

    for field in (
        "request_hash", "config_sha", "command_candidate_result_hash",
        "command_candidate_file_sha256", "external_receipt_file_sha256",
        "verifier_binary_sha256", "result_hash",
    ):
        raw = value.get(field)
        if not isinstance(raw, str) or HASH_RE.fullmatch(raw) is None:
            errors.append(f"external_verifier_result.{field}: valid SHA-256 required")

    provider = value.get("provider")
    if not isinstance(provider, str) or ingress.PROVIDER_RE.fullmatch(provider) is None:
        errors.append("external_verifier_result.provider: bounded identifier required")
    if value.get("platform") != "codex":
        errors.append("external_verifier_result.platform: codex required")
    for field in ("capture_id", "verifier_id", "verifier_version"):
        raw = value.get(field)
        if not isinstance(raw, str) or OPAQUE_RE.fullmatch(raw) is None:
            errors.append(f"external_verifier_result.{field}: bounded identifier required")
    nonce = value.get("verification_nonce")
    if not isinstance(nonce, str) or upstream.NONCE_RE.fullmatch(nonce) is None:
        errors.append("external_verifier_result.verification_nonce: exact #1471 nonce shape required")

    for field in UPSTREAM_TRUE_FIELDS:
        if value.get(field) is not True:
            errors.append(f"external_verifier_result.{field}: true required")
    for field in UPSTREAM_FALSE_FIELDS:
        if value.get(field) is not False:
            errors.append(f"external_verifier_result.{field}: false required")

    _validate_authority(value.get("authority"), "external_verifier_result.authority", errors)
    body = dict(value)
    claimed_hash = body.pop("result_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("external_verifier_result.result_hash: canonical hash mismatch")
    return errors


def _validate_upstream_freshness(
    value: dict[str, Any],
    now: dt.datetime,
) -> list[str]:
    errors: list[str] = []
    issued = _parse_rfc3339(value.get("issued_at"))
    expires = _parse_rfc3339(value.get("expires_at"))
    if issued is None:
        errors.append("external_verifier_result.issued_at: timezone-aware RFC3339 required")
    if expires is None:
        errors.append("external_verifier_result.expires_at: timezone-aware RFC3339 required")
    if issued is not None and expires is not None:
        if expires <= issued:
            errors.append("external_verifier_result.expires_at: must be after issued_at")
        elif (expires - issued).total_seconds() > upstream.MAX_VALIDITY_SECONDS:
            errors.append(
                "external_verifier_result: #1471 validity window exceeds upstream limit"
            )
        if issued > now + dt.timedelta(seconds=upstream.MAX_FUTURE_SKEW_SECONDS):
            errors.append("external_verifier_result.issued_at: too far in the future")
        if now > expires:
            errors.append("external_verifier_result: stale/expired #1471 result")
    return errors


def _validate_provenance(
    value: Any,
    *,
    upstream_value: dict[str, Any],
    upstream_file_sha256: str,
    expected_verifier_issuer: str,
    expected_verifier_workflow_ref: str,
    expected_verifier_binary_sha256: str,
    expected_challenge_id: str,
    now: dt.datetime,
) -> list[str]:
    if not isinstance(value, dict):
        return ["provenance_receipt: object required"]
    errors = [
        f"provenance_receipt privacy: {error}"
        for error in ingress._forbidden_input_errors(value)
    ]
    if set(value) != PROVENANCE_KEYS:
        errors.append("provenance_receipt: exact key set required")
    if value.get("schema_version") != "1":
        errors.append("provenance_receipt.schema_version: 1 required")
    if value.get("domain") != RECEIPT_DOMAIN:
        errors.append(f"provenance_receipt.domain: {RECEIPT_DOMAIN} required")
    if value.get("contract_stage") != RECEIPT_STAGE:
        errors.append(f"provenance_receipt.contract_stage: {RECEIPT_STAGE} required")

    bindings = {
        "request_hash": upstream_value.get("request_hash"),
        "config_sha": upstream_value.get("config_sha"),
        "provider": upstream_value.get("provider"),
        "platform": upstream_value.get("platform"),
        "capture_id": upstream_value.get("capture_id"),
        "external_verifier_result_hash": upstream_value.get("result_hash"),
        "external_verifier_result_file_sha256": upstream_file_sha256,
        "external_receipt_file_sha256": upstream_value.get("external_receipt_file_sha256"),
        "verification_nonce": upstream_value.get("verification_nonce"),
        "verifier_id": upstream_value.get("verifier_id"),
        "verifier_version": upstream_value.get("verifier_version"),
        "verifier_binary_sha256": upstream_value.get("verifier_binary_sha256"),
    }
    for field, expected in bindings.items():
        if value.get(field) != expected:
            errors.append(f"provenance_receipt.{field}: exact #1471 binding required")

    issuer = value.get("verifier_issuer")
    if not isinstance(issuer, str) or OPAQUE_RE.fullmatch(issuer) is None:
        errors.append("provenance_receipt.verifier_issuer: bounded identity required")
    if issuer != expected_verifier_issuer:
        errors.append("provenance_receipt.verifier_issuer: expected identity mismatch")

    workflow = value.get("verifier_workflow_ref")
    if not isinstance(workflow, str) or WORKFLOW_REF_RE.fullmatch(workflow) is None:
        errors.append("provenance_receipt.verifier_workflow_ref: immutable workflow@sha required")
    if workflow != expected_verifier_workflow_ref:
        errors.append("provenance_receipt.verifier_workflow_ref: expected identity mismatch")

    binary = value.get("verifier_binary_sha256")
    if binary != expected_verifier_binary_sha256:
        errors.append("provenance_receipt.verifier_binary_sha256: expected digest mismatch")
    if not isinstance(binary, str) or HASH_RE.fullmatch(binary) is None:
        errors.append("provenance_receipt.verifier_binary_sha256: valid SHA-256 required")

    for field in ("execution_id",):
        raw = value.get(field)
        if not isinstance(raw, str) or OPAQUE_RE.fullmatch(raw) is None:
            errors.append(f"provenance_receipt.{field}: bounded identifier required")

    challenge = value.get("challenge_id")
    if not isinstance(challenge, str) or HASH_RE.fullmatch(challenge) is None:
        errors.append("provenance_receipt.challenge_id: valid SHA-256 required")
    if challenge != expected_challenge_id:
        errors.append("provenance_receipt.challenge_id: exact run challenge required")

    issued = _parse_rfc3339(value.get("issued_at"))
    expires = _parse_rfc3339(value.get("expires_at"))
    if issued is None:
        errors.append("provenance_receipt.issued_at: timezone-aware RFC3339 required")
    if expires is None:
        errors.append("provenance_receipt.expires_at: timezone-aware RFC3339 required")
    if issued is not None and expires is not None:
        if expires <= issued:
            errors.append("provenance_receipt.expires_at: must be after issued_at")
        elif (expires - issued).total_seconds() > MAX_VALIDITY_SECONDS:
            errors.append(
                f"provenance_receipt: validity window must be <= {MAX_VALIDITY_SECONDS}s"
            )
        if issued > now + dt.timedelta(seconds=MAX_FUTURE_SKEW_SECONDS):
            errors.append("provenance_receipt.issued_at: too far in the future")
        if now >= expires:
            errors.append("provenance_receipt: stale/expired receipt")

    body = dict(value)
    claimed_hash = body.pop("provenance_receipt_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("provenance_receipt.provenance_receipt_hash: canonical hash mismatch")
    return errors


def verify_provenance_bytes(
    *,
    external_verifier_result_raw: bytes,
    provenance_receipt_raw: bytes,
    expected_verifier_issuer: str,
    expected_verifier_workflow_ref: str,
    expected_verifier_binary_sha256: str,
    expected_challenge_id: str,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    upstream_value = _strict_json_loads(
        external_verifier_result_raw, "external_verifier_result"
    )
    provenance_value = _strict_json_loads(
        provenance_receipt_raw, "provenance_receipt"
    )
    errors = _validate_upstream(upstream_value)
    current = now or dt.datetime.now(dt.timezone.utc)
    if current.tzinfo is None or current.utcoffset() is None:
        errors.append("now: timezone-aware datetime required")
    elif isinstance(upstream_value, dict):
        current_utc = current.astimezone(dt.timezone.utc)
        errors.extend(_validate_upstream_freshness(upstream_value, current_utc))
        errors.extend(
            _validate_provenance(
                provenance_value,
                upstream_value=upstream_value,
                upstream_file_sha256=_sha256_bytes(external_verifier_result_raw),
                expected_verifier_issuer=expected_verifier_issuer,
                expected_verifier_workflow_ref=expected_verifier_workflow_ref,
                expected_verifier_binary_sha256=expected_verifier_binary_sha256,
                expected_challenge_id=expected_challenge_id,
                now=current_utc,
            )
        )
    if errors:
        raise ExternalVerifierProvenanceError(errors)

    assert isinstance(upstream_value, dict)
    assert isinstance(provenance_value, dict)
    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": upstream_value["request_hash"],
        "config_sha": upstream_value["config_sha"],
        "provider": upstream_value["provider"],
        "platform": upstream_value["platform"],
        "capture_id": upstream_value["capture_id"],
        "external_verifier_result_hash": upstream_value["result_hash"],
        "external_verifier_result_file_sha256": _sha256_bytes(external_verifier_result_raw),
        "external_receipt_file_sha256": upstream_value["external_receipt_file_sha256"],
        "verification_nonce": upstream_value["verification_nonce"],
        "verifier_id": upstream_value["verifier_id"],
        "verifier_version": upstream_value["verifier_version"],
        "verifier_binary_sha256": upstream_value["verifier_binary_sha256"],
        "verifier_issuer": provenance_value["verifier_issuer"],
        "verifier_workflow_ref": provenance_value["verifier_workflow_ref"],
        "execution_id": provenance_value["execution_id"],
        "challenge_id": provenance_value["challenge_id"],
        "issued_at": provenance_value["issued_at"],
        "expires_at": provenance_value["expires_at"],
        "provenance_receipt_hash": provenance_value["provenance_receipt_hash"],
        "external_verifier_result_binding_verified": True,
        "provenance_receipt_structure_verified": True,
        "provenance_receipt_content_addressed": True,
        "immutable_verifier_identity_binding_candidate": True,
        "run_challenge_binding_candidate": True,
        "freshness_window_candidate": True,
        "same_challenge_replay_prevented": False,
        "provenance_receipt_signature_verified": False,
        "crypto_verifier_binary_verified": False,
        "receipt_claims_authenticated": False,
        "gh_attestation_cli_execution_verified": False,
        "artifact_digest_cryptographically_verified": False,
        "attestation_signature_cryptographically_verified": False,
        "signer_certificate_identity_verified": False,
        "signer_workflow_policy_verified": False,
        "source_digest_policy_verified": False,
        "self_hosted_runner_denial_verified": False,
        "independent_admin_boundary_verified": False,
        "independent_verifier_execution_attested": False,
        "managed_hook_root_attested": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "exact #1471 result bytes, immutable verifier identity expectation, binary digest, "
            "run challenge, and bounded freshness are validated; the provenance receipt is not "
            "cryptographically authenticated and caller-supplied expectations do not prove "
            "independent administration or one-time challenge consumption"
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


def verify_provenance_files(
    *,
    repo_root,
    external_verifier_result_path,
    provenance_receipt_path,
    expected_verifier_issuer,
    expected_verifier_workflow_ref,
    expected_verifier_binary_sha256,
    expected_challenge_id,
    now=None,
) -> dict[str, Any]:
    upstream_raw = _require_external_regular_file(
        external_verifier_result_path,
        repo_root=repo_root,
        field="external_verifier_result",
    )
    provenance_raw = _require_external_regular_file(
        provenance_receipt_path,
        repo_root=repo_root,
        field="provenance_receipt",
    )
    return verify_provenance_bytes(
        external_verifier_result_raw=upstream_raw,
        provenance_receipt_raw=provenance_raw,
        expected_verifier_issuer=expected_verifier_issuer,
        expected_verifier_workflow_ref=expected_verifier_workflow_ref,
        expected_verifier_binary_sha256=expected_verifier_binary_sha256,
        expected_challenge_id=expected_challenge_id,
        now=now,
    )


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--external-verifier-result", required=True)
    parser.add_argument("--provenance-receipt", required=True)
    parser.add_argument("--expected-verifier-issuer", required=True)
    parser.add_argument("--expected-verifier-workflow-ref", required=True)
    parser.add_argument("--expected-verifier-binary-sha256", required=True)
    parser.add_argument("--expected-challenge-id", required=True)
    args = parser.parse_args(argv)
    try:
        result = verify_provenance_files(
            repo_root=args.repo_root,
            external_verifier_result_path=args.external_verifier_result,
            provenance_receipt_path=args.provenance_receipt,
            expected_verifier_issuer=args.expected_verifier_issuer,
            expected_verifier_workflow_ref=args.expected_verifier_workflow_ref,
            expected_verifier_binary_sha256=args.expected_verifier_binary_sha256,
            expected_challenge_id=args.expected_challenge_id,
        )
    except ExternalVerifierProvenanceError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
