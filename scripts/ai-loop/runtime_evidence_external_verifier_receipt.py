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

__doc__ = """Validate a content-addressed external verifier receipt for #1468.

This layer builds on the repository-local gh attestation verify command candidate
landed by #1470. It adds replay/stale/binding checks for an external verifier
receipt without promoting that receipt into runtime authority.

The receipt itself must stay outside the repository and is verified as a GitHub
artifact-attested artifact under the same strict signer/source/self-hosted policy
used by the #1470 verifier. A successful local gh invocation remains candidate
Evidence only because the local gh binary/execution environment and independent
administrator boundary are not yet independently attested.
"""

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import stat
import sys
from typing import Any, Mapping

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import gh_exec  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command_candidate  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-external-verifier-receipt/v1"
CONTRACT_STAGE = "r1-external-verifier-receipt-candidate-v1"
RECEIPT_DOMAIN = "plangate.runtime-r1-external-verifier-receipt-input/v1"
RECEIPT_STAGE = "r1-external-verifier-receipt-input-v1"

MAX_JSON_BYTES = 2 * 1024 * 1024
MAX_VALIDITY_SECONDS = 15 * 60
MAX_FUTURE_SKEW_SECONDS = 60

NONCE_ENV = "PLANGATE_R1_EXTERNAL_VERIFIER_NONCE"
NONCE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$")
HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
OPAQUE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/@+-]{0,255}$")

AUTHORITY_KEYS = {
    "agent_invoke_allowed",
    "code_write_allowed",
    "approval_write_allowed",
    "merge_allowed",
    "deploy_allowed",
}

CANDIDATE_REQUIRED_KEYS = {
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

CANDIDATE_TRUE_FIELDS = (
    "exact_verifier_policy_bound_candidate",
    "gh_attestation_verify_exit_success_candidate",
    "capture_manifest_artifact_binding_candidate",
    "signer_workflow_policy_requested_candidate",
    "source_digest_policy_requested_candidate",
    "signer_digest_policy_requested_candidate",
    "self_hosted_runner_denial_requested_candidate",
)

CANDIDATE_FALSE_FIELDS = (
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

RECEIPT_REQUIRED_KEYS = {
    "schema_version",
    "domain",
    "contract_stage",
    "request_hash",
    "config_sha",
    "provider",
    "platform",
    "capture_id",
    "command_candidate_result_hash",
    "command_candidate_file_sha256",
    "capture_manifest_hash",
    "capture_manifest_file_sha256",
    "attestation_repo",
    "signer_repo",
    "signer_workflow",
    "source_digest",
    "signer_digest",
    "source_ref",
    "verifier_id",
    "verifier_version",
    "verifier_binary_sha256",
    "verification_nonce",
    "issued_at",
    "expires_at",
    "claimed_gh_attestation_cli_execution_verified",
    "claimed_artifact_digest_cryptographically_verified",
    "claimed_attestation_signature_cryptographically_verified",
    "claimed_signer_certificate_identity_verified",
    "claimed_verified_timestamp_cryptographically_verified",
    "claimed_signer_workflow_policy_verified",
    "claimed_source_digest_policy_verified",
    "claimed_self_hosted_runner_denial_verified",
    "claimed_independent_admin_boundary_verified",
    "claimed_independent_verifier_execution_attested",
    "claimed_runtime_probe_attestation_verified",
    "claimed_hard_read_only_enforced",
}

RECEIPT_TRUE_CLAIMS = tuple(
    key for key in RECEIPT_REQUIRED_KEYS if key.startswith("claimed_")
)


class ExternalVerifierReceiptError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _valid_hash(value: Any) -> bool:
    return isinstance(value, str) and HASH_RE.fullmatch(value) is not None


def _strict_json_loads(raw: bytes, field: str) -> Any:
    if len(raw) > MAX_JSON_BYTES:
        raise ExternalVerifierReceiptError([f"{field}: exceeds JSON byte limit"])
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ExternalVerifierReceiptError([f"{field}: UTF-8 required"]) from exc

    def pairs_hook(pairs):
        out = {}
        for key, value in pairs:
            if key in out:
                raise ExternalVerifierReceiptError(
                    [f"{field}: duplicate JSON key {key!r}"]
                )
            out[key] = value
        return out

    def reject_constant(value: str):
        raise ExternalVerifierReceiptError(
            [f"{field}: non-finite JSON number {value!r} not allowed"]
        )

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs_hook,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise ExternalVerifierReceiptError([f"{field}: invalid JSON"]) from exc


def _require_external_regular_file(
    path: str | pathlib.Path,
    *,
    repo_root: str | pathlib.Path,
    field: str,
) -> tuple[pathlib.Path, bytes]:
    root = pathlib.Path(repo_root).resolve()
    source = pathlib.Path(path)
    if not source.is_absolute():
        raise ExternalVerifierReceiptError([f"{field}: absolute path required"])
    if not source.parent.is_dir() or source.parent.resolve() != source.parent:
        raise ExternalVerifierReceiptError(
            [f"{field}: parent must exist and not traverse symlinks"]
        )
    if not source.exists():
        raise ExternalVerifierReceiptError([f"{field}: file must exist"])
    mode = source.lstat().st_mode
    if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
        raise ExternalVerifierReceiptError(
            [f"{field}: regular non-symlink file required"]
        )
    target = source.resolve()
    try:
        target.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False
    if inside_repo:
        raise ExternalVerifierReceiptError(
            [f"{field}: external verifier artifact must stay outside repository"]
        )
    raw = source.read_bytes()
    if len(raw) > MAX_JSON_BYTES:
        raise ExternalVerifierReceiptError([f"{field}: exceeds JSON byte limit"])
    return source, raw


def _validate_authority(value: Any, field: str, errors: list[str]) -> None:
    if not isinstance(value, dict) or set(value) != AUTHORITY_KEYS:
        errors.append(f"{field}: exact authority key set required")
        return
    if any(value.get(key) is not False for key in AUTHORITY_KEYS):
        errors.append(f"{field}: all authority values must remain false")


def _validate_candidate(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["command_candidate: object required"]

    errors: list[str] = []
    unknown = sorted(set(value) - CANDIDATE_REQUIRED_KEYS)
    missing = sorted(CANDIDATE_REQUIRED_KEYS - set(value))
    if unknown:
        errors.append(f"command_candidate: unsupported keys: {unknown}")
    if missing:
        errors.append(f"command_candidate: missing keys: {missing}")

    if value.get("schema_version") != "1":
        errors.append("command_candidate.schema_version: 1 required")
    if value.get("domain") != command_candidate.DOMAIN:
        errors.append("command_candidate.domain: exact #1470 domain required")
    if value.get("contract_stage") != command_candidate.CONTRACT_STAGE:
        errors.append("command_candidate.contract_stage: exact #1470 stage required")

    for field in (
        "request_hash",
        "config_sha",
        "candidate_receipt_hash",
        "capture_manifest_hash",
        "capture_manifest_file_sha256",
        "result_hash",
    ):
        if not _valid_hash(value.get(field)):
            errors.append(f"command_candidate.{field}: valid SHA-256 required")

    provider = value.get("provider")
    if not isinstance(provider, str) or ingress.PROVIDER_RE.fullmatch(provider) is None:
        errors.append("command_candidate.provider: bounded provider identifier required")
    if value.get("platform") != "codex":
        errors.append("command_candidate.platform: codex required")
    capture_id = value.get("capture_id")
    if not isinstance(capture_id, str) or OPAQUE_RE.fullmatch(capture_id) is None:
        errors.append("command_candidate.capture_id: bounded identifier required")
    if value.get("oidc_issuer") != command_candidate.OIDC_ISSUER:
        errors.append("command_candidate.oidc_issuer: exact GitHub Actions issuer required")
    if value.get("predicate_type") != "https://slsa.dev/provenance/v1":
        errors.append("command_candidate.predicate_type: SLSA provenance v1 required")
    try:
        command_candidate._validate_policy(
            attestation_repo=value.get("attestation_repo"),
            signer_repo=value.get("signer_repo"),
            signer_workflow=value.get("signer_workflow"),
            source_digest=value.get("source_digest"),
            signer_digest=value.get("signer_digest"),
            source_ref=value.get("source_ref"),
        )
    except command_candidate.IndependentAttestationVerifierError as exc:
        errors.extend(f"command_candidate.policy: {error}" for error in exc.errors)

    for field in CANDIDATE_TRUE_FIELDS:
        if value.get(field) is not True:
            errors.append(f"command_candidate.{field}: true required")
    for field in CANDIDATE_FALSE_FIELDS:
        if value.get(field) is not False:
            errors.append(
                f"command_candidate.{field}: false required before external promotion"
            )

    _validate_authority(value.get("authority"), "command_candidate.authority", errors)

    body = dict(value)
    claimed_hash = body.pop("result_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("command_candidate.result_hash: canonical hash mismatch")
    return errors


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


def _validate_receipt(
    value: Any,
    *,
    candidate_value: dict[str, Any],
    candidate_file_sha256: str,
    expected_nonce: str,
    now: dt.datetime,
) -> list[str]:
    if not isinstance(value, dict):
        return ["external_receipt: object required"]

    errors = [
        f"external_receipt privacy: {error}"
        for error in ingress._forbidden_input_errors(value)
    ]
    unknown = sorted(set(value) - RECEIPT_REQUIRED_KEYS)
    missing = sorted(RECEIPT_REQUIRED_KEYS - set(value))
    if unknown:
        errors.append(f"external_receipt: unsupported keys: {unknown}")
    if missing:
        errors.append(f"external_receipt: missing keys: {missing}")

    if value.get("schema_version") != "1":
        errors.append("external_receipt.schema_version: 1 required")
    if value.get("domain") != RECEIPT_DOMAIN:
        errors.append(f"external_receipt.domain: {RECEIPT_DOMAIN} required")
    if value.get("contract_stage") != RECEIPT_STAGE:
        errors.append(f"external_receipt.contract_stage: {RECEIPT_STAGE} required")

    for field in (
        "request_hash",
        "config_sha",
        "command_candidate_result_hash",
        "command_candidate_file_sha256",
        "capture_manifest_hash",
        "capture_manifest_file_sha256",
        "verifier_binary_sha256",
    ):
        if not _valid_hash(value.get(field)):
            errors.append(f"external_receipt.{field}: valid SHA-256 required")

    for field in ("verifier_id", "verifier_version"):
        raw = value.get(field)
        if not isinstance(raw, str) or OPAQUE_RE.fullmatch(raw) is None:
            errors.append(f"external_receipt.{field}: bounded identifier required")

    nonce = value.get("verification_nonce")
    if not isinstance(nonce, str) or NONCE_RE.fullmatch(nonce) is None:
        errors.append(
            "external_receipt.verification_nonce: 16..128 bounded characters required"
        )
    elif nonce != expected_nonce:
        errors.append("external_receipt.verification_nonce: exact expected nonce required")

    bindings = {
        "request_hash": candidate_value.get("request_hash"),
        "config_sha": candidate_value.get("config_sha"),
        "provider": candidate_value.get("provider"),
        "platform": candidate_value.get("platform"),
        "capture_id": candidate_value.get("capture_id"),
        "command_candidate_result_hash": candidate_value.get("result_hash"),
        "command_candidate_file_sha256": candidate_file_sha256,
        "capture_manifest_hash": candidate_value.get("capture_manifest_hash"),
        "capture_manifest_file_sha256": candidate_value.get(
            "capture_manifest_file_sha256"
        ),
        "attestation_repo": candidate_value.get("attestation_repo"),
        "signer_repo": candidate_value.get("signer_repo"),
        "signer_workflow": candidate_value.get("signer_workflow"),
        "source_digest": candidate_value.get("source_digest"),
        "signer_digest": candidate_value.get("signer_digest"),
        "source_ref": candidate_value.get("source_ref"),
    }
    for field, expected in bindings.items():
        if value.get(field) != expected:
            errors.append(f"external_receipt.{field}: exact candidate binding required")

    for field in RECEIPT_TRUE_CLAIMS:
        if value.get(field) is not True:
            errors.append(f"external_receipt.{field}: true claim required")

    issued = _parse_rfc3339(value.get("issued_at"))
    expires = _parse_rfc3339(value.get("expires_at"))
    if issued is None:
        errors.append("external_receipt.issued_at: timezone-aware RFC3339 required")
    if expires is None:
        errors.append("external_receipt.expires_at: timezone-aware RFC3339 required")
    if issued is not None and expires is not None:
        if expires <= issued:
            errors.append("external_receipt.expires_at: must be after issued_at")
        elif (expires - issued).total_seconds() > MAX_VALIDITY_SECONDS:
            errors.append(
                f"external_receipt: validity window must be <= {MAX_VALIDITY_SECONDS}s"
            )
        if issued > now + dt.timedelta(seconds=MAX_FUTURE_SKEW_SECONDS):
            errors.append("external_receipt.issued_at: too far in the future")
        if now > expires:
            errors.append("external_receipt: stale/expired receipt")

    return errors


def _verified_subject_digest(output: Any, expected_sha256_hex: str) -> bool:
    if not isinstance(output, list) or not output:
        return False
    for entry in output:
        if not isinstance(entry, dict):
            return False
        verification = entry.get("verificationResult")
        if not isinstance(verification, dict):
            return False
        statement = verification.get("statement")
        if not isinstance(statement, dict):
            return False
        subjects = statement.get("subject")
        if not isinstance(subjects, list) or not subjects:
            return False
        if not any(
            isinstance(subject, dict)
            and isinstance(subject.get("digest"), dict)
            and subject["digest"].get("sha256") == expected_sha256_hex
            for subject in subjects
        ):
            return False
    return True


def verify_external_receipt(
    *,
    repo_root: str | pathlib.Path,
    command_candidate_path: str | pathlib.Path,
    external_receipt_path: str | pathlib.Path,
    expected_nonce: str,
    cwd=None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    if NONCE_RE.fullmatch(expected_nonce or "") is None:
        raise ExternalVerifierReceiptError(
            ["expected_nonce: 16..128 bounded characters required"]
        )

    candidate_path, candidate_raw = _require_external_regular_file(
        command_candidate_path,
        repo_root=repo_root,
        field="command_candidate",
    )
    receipt_path, receipt_raw = _require_external_regular_file(
        external_receipt_path,
        repo_root=repo_root,
        field="external_receipt",
    )
    candidate_value = _strict_json_loads(candidate_raw, "command_candidate")
    receipt_value = _strict_json_loads(receipt_raw, "external_receipt")

    errors = _validate_candidate(candidate_value)
    current = now or dt.datetime.now(dt.timezone.utc)
    if current.tzinfo is None or current.utcoffset() is None:
        errors.append("now: timezone-aware datetime required")
    elif isinstance(candidate_value, dict):
        errors.extend(
            _validate_receipt(
                receipt_value,
                candidate_value=candidate_value,
                candidate_file_sha256=_sha256_bytes(candidate_raw),
                expected_nonce=expected_nonce,
                now=current.astimezone(dt.timezone.utc),
            )
        )
    if errors:
        raise ExternalVerifierReceiptError(errors)

    assert isinstance(candidate_value, dict)
    assert isinstance(receipt_value, dict)

    args = command_candidate.build_verify_args(
        artifact_path=receipt_path,
        attestation_repo=candidate_value["attestation_repo"],
        signer_repo=candidate_value["signer_repo"],
        signer_workflow=candidate_value["signer_workflow"],
        source_digest=candidate_value["source_digest"],
        signer_digest=candidate_value["signer_digest"],
        source_ref=candidate_value["source_ref"],
    )

    try:
        proc = gh_exec.run_gh(
            args,
            repo=candidate_value["attestation_repo"],
            cwd=cwd,
        )
    except gh_exec.Denied as exc:
        raise ExternalVerifierReceiptError(
            [f"gh_attestation_verify: allowlist denied: {exc}"]
        ) from exc

    if getattr(proc, "returncode", 1) != 0:
        raise ExternalVerifierReceiptError(
            ["gh_attestation_verify: receipt verification command failed"]
        )
    stdout = getattr(proc, "stdout", None)
    if not isinstance(stdout, str):
        raise ExternalVerifierReceiptError(
            ["gh_attestation_verify: text stdout required"]
        )
    gh_output = _strict_json_loads(
        stdout.encode("utf-8"),
        "gh_attestation_output",
    )

    receipt_sha_hex = hashlib.sha256(receipt_raw).hexdigest()
    if not _verified_subject_digest(gh_output, receipt_sha_hex):
        raise ExternalVerifierReceiptError(
            ["gh_attestation_verify: receipt artifact digest binding mismatch"]
        )

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": candidate_value["request_hash"],
        "config_sha": candidate_value["config_sha"],
        "provider": candidate_value["provider"],
        "platform": candidate_value["platform"],
        "capture_id": candidate_value["capture_id"],
        "command_candidate_result_hash": candidate_value["result_hash"],
        "command_candidate_file_sha256": _sha256_bytes(candidate_raw),
        "external_receipt_file_sha256": _sha256_bytes(receipt_raw),
        "verification_nonce": receipt_value["verification_nonce"],
        "issued_at": receipt_value["issued_at"],
        "expires_at": receipt_value["expires_at"],
        "verifier_id": receipt_value["verifier_id"],
        "verifier_version": receipt_value["verifier_version"],
        "verifier_binary_sha256": receipt_value["verifier_binary_sha256"],
        "receipt_structure_verified": True,
        "receipt_candidate_binding_verified": True,
        "receipt_content_addressed": True,
        "receipt_nonce_binding_verified": True,
        "receipt_freshness_verified": True,
        "receipt_artifact_digest_binding_candidate": True,
        "receipt_attestation_verify_exit_success_candidate": True,
        "receipt_claims_authenticated": False,
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
            "external receipt structure, exact candidate bindings, nonce/freshness, "
            "content addressing, and repository-local gh attestation command success "
            "are verified; local gh execution provenance and independent-admin signer "
            "boundary remain unattested, so receipt claims and runtime authority remain false"
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


def load_expected_nonce(env: Mapping[str, str] | None = None) -> str:
    source = os.environ if env is None else env
    value = source.get(NONCE_ENV)
    if not isinstance(value, str) or NONCE_RE.fullmatch(value) is None:
        raise ExternalVerifierReceiptError(
            [f"expected_nonce: {NONCE_ENV} is required and must be bounded"]
        )
    return value


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--command-candidate", required=True)
    parser.add_argument("--external-verifier-receipt", required=True)
    args = parser.parse_args(argv)

    try:
        result = verify_external_receipt(
            repo_root=args.repo_root,
            command_candidate_path=args.command_candidate,
            external_receipt_path=args.external_verifier_receipt,
            expected_nonce=load_expected_nonce(),
            cwd=args.repo_root,
        )
    except ExternalVerifierReceiptError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
