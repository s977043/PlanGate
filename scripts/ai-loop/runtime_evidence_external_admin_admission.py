#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """Validate the candidate admission contract for an external R1 admin boundary.

This validator does not prove administrator independence. It only validates that
an externally supplied boundary descriptor is structurally separate from the
PlanGate repository, pins immutable signer/source policy, provides content-
addressed external Evidence references, and stays compatible with the #1471
external verifier receipt contract.

All strong machine/runtime/Human/dispatch promotion fields remain false until
the referenced external Evidence is independently verified.
"""

import argparse
import hashlib
import json
import pathlib
import re
import stat
import sys
import urllib.parse
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_receipt as receipt  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command_candidate  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-external-admin-admission/v1"
CONTRACT_STAGE = "r1-external-admin-admission-candidate-v1"
INPUT_DOMAIN = "plangate.runtime-r1-external-admin-boundary-input/v1"
INPUT_STAGE = "r1-external-admin-boundary-input-v1"
PLANGATE_REPO = "s977043/PlanGate"

MAX_JSON_BYTES = 512 * 1024
MIN_EVIDENCE_ITEMS = 2
MAX_EVIDENCE_ITEMS = 16
HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
REPO_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$")
OPAQUE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/@+-]{0,255}$")
HTTPS_RE = re.compile(r"^https://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+$")

AUTHORITY_KEYS = {
    "agent_invoke_allowed",
    "code_write_allowed",
    "approval_write_allowed",
    "merge_allowed",
    "deploy_allowed",
}

REQUIRED_KEYS = {
    "schema_version",
    "domain",
    "contract_stage",
    "boundary_id",
    "boundary_type",
    "attestation_repo",
    "signer_repo",
    "signer_workflow",
    "signer_digest",
    "source_digest",
    "source_ref",
    "oidc_issuer",
    "self_hosted_runner_denied",
    "admin_scope",
    "nonce_owner",
    "receipt_domain",
    "receipt_contract_stage",
    "admin_separation_evidence",
}

EVIDENCE_REQUIRED_KEYS = {"evidence_type", "uri", "sha256"}


class ExternalAdminAdmissionError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _strict_json_loads(raw: bytes, field: str) -> Any:
    if len(raw) > MAX_JSON_BYTES:
        raise ExternalAdminAdmissionError([f"{field}: exceeds JSON byte limit"])
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ExternalAdminAdmissionError([f"{field}: UTF-8 required"]) from exc

    def pairs_hook(pairs):
        out = {}
        for key, value in pairs:
            if key in out:
                raise ExternalAdminAdmissionError(
                    [f"{field}: duplicate JSON key {key!r}"]
                )
            out[key] = value
        return out

    def reject_constant(value: str):
        raise ExternalAdminAdmissionError(
            [f"{field}: non-finite JSON number {value!r} not allowed"]
        )

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs_hook,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise ExternalAdminAdmissionError([f"{field}: invalid JSON"]) from exc


def _require_external_regular_file(
    path: str | pathlib.Path,
    *,
    repo_root: str | pathlib.Path,
    field: str,
) -> tuple[pathlib.Path, bytes]:
    root = pathlib.Path(repo_root).resolve()
    source = pathlib.Path(path)
    if not source.is_absolute():
        raise ExternalAdminAdmissionError([f"{field}: absolute path required"])
    if not source.parent.is_dir() or source.parent.resolve() != source.parent:
        raise ExternalAdminAdmissionError(
            [f"{field}: parent must exist and not traverse symlinks"]
        )
    if not source.exists():
        raise ExternalAdminAdmissionError([f"{field}: file must exist"])
    mode = source.lstat().st_mode
    if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
        raise ExternalAdminAdmissionError(
            [f"{field}: regular non-symlink file required"]
        )
    target = source.resolve()
    try:
        target.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False
    if inside_repo:
        raise ExternalAdminAdmissionError(
            [f"{field}: boundary descriptor must stay outside repository"]
        )
    raw = source.read_bytes()
    if len(raw) > MAX_JSON_BYTES:
        raise ExternalAdminAdmissionError([f"{field}: exceeds JSON byte limit"])
    return source, raw


def _validate_evidence(value: Any, errors: list[str]) -> None:
    if not isinstance(value, list) or len(value) < MIN_EVIDENCE_ITEMS:
        errors.append(
            f"admin_separation_evidence: at least {MIN_EVIDENCE_ITEMS} items required"
        )
        return
    if len(value) > MAX_EVIDENCE_ITEMS:
        errors.append(
            f"admin_separation_evidence: at most {MAX_EVIDENCE_ITEMS} items allowed"
        )
        return

    seen_hashes: set[str] = set()
    seen_types: set[str] = set()
    for index, item in enumerate(value):
        prefix = f"admin_separation_evidence[{index}]"
        if not isinstance(item, dict) or set(item) != EVIDENCE_REQUIRED_KEYS:
            errors.append(f"{prefix}: exact evidence key set required")
            continue

        evidence_type = item.get("evidence_type")
        if not isinstance(evidence_type, str) or OPAQUE_RE.fullmatch(evidence_type) is None:
            errors.append(f"{prefix}.evidence_type: bounded identifier required")
        elif evidence_type in seen_types:
            errors.append(f"{prefix}.evidence_type: duplicate Evidence type")
        else:
            seen_types.add(evidence_type)

        uri = item.get("uri")
        if not isinstance(uri, str) or HTTPS_RE.fullmatch(uri) is None:
            errors.append(f"{prefix}.uri: HTTPS URI required")
        else:
            parsed = urllib.parse.urlsplit(uri)
            decoded = urllib.parse.unquote(uri).casefold()
            if parsed.scheme.casefold() != "https" or not parsed.hostname:
                errors.append(f"{prefix}.uri: normalized HTTPS URI required")
            if parsed.username is not None or parsed.password is not None:
                errors.append(f"{prefix}.uri: embedded credentials are not allowed")
            if "s977043/plangate" in decoded:
                errors.append(
                    f"{prefix}.uri: PlanGate repository cannot be independent-admin Evidence"
                )

        digest = item.get("sha256")
        if not isinstance(digest, str) or HASH_RE.fullmatch(digest) is None:
            errors.append(f"{prefix}.sha256: content-addressed SHA-256 required")
        elif digest in seen_hashes:
            errors.append(f"{prefix}.sha256: duplicate Evidence digest")
        else:
            seen_hashes.add(digest)


def validate_descriptor(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["boundary_descriptor: object required"]

    errors = [
        f"boundary_descriptor privacy: {error}"
        for error in ingress._forbidden_input_errors(value)
    ]
    unknown = sorted(set(value) - REQUIRED_KEYS)
    missing = sorted(REQUIRED_KEYS - set(value))
    if unknown:
        errors.append(f"boundary_descriptor: unsupported keys: {unknown}")
    if missing:
        errors.append(f"boundary_descriptor: missing keys: {missing}")

    if value.get("schema_version") != "1":
        errors.append("schema_version: 1 required")
    if value.get("domain") != INPUT_DOMAIN:
        errors.append(f"domain: {INPUT_DOMAIN} required")
    if value.get("contract_stage") != INPUT_STAGE:
        errors.append(f"contract_stage: {INPUT_STAGE} required")

    for field in ("boundary_id", "admin_scope", "nonce_owner"):
        raw = value.get(field)
        if not isinstance(raw, str) or OPAQUE_RE.fullmatch(raw) is None:
            errors.append(f"{field}: bounded identifier required")

    if value.get("boundary_type") != "github_repository":
        errors.append(
            "boundary_type: github_repository required for this GitHub-attestation contract"
        )

    attestation_repo = value.get("attestation_repo")
    signer_repo = value.get("signer_repo")
    if not isinstance(attestation_repo, str) or REPO_RE.fullmatch(attestation_repo) is None:
        errors.append("attestation_repo: owner/repo required")
    if not isinstance(signer_repo, str) or REPO_RE.fullmatch(signer_repo) is None:
        errors.append("signer_repo: owner/repo required")
    if isinstance(signer_repo, str) and signer_repo.casefold() == PLANGATE_REPO.casefold():
        errors.append("signer_repo: PlanGate repository cannot be its own external signer")
    if (
        isinstance(attestation_repo, str)
        and isinstance(signer_repo, str)
        and attestation_repo.casefold() == signer_repo.casefold()
    ):
        errors.append("signer_repo: must be structurally separate from attestation_repo")

    try:
        command_candidate._validate_policy(
            attestation_repo=attestation_repo,
            signer_repo=signer_repo,
            signer_workflow=value.get("signer_workflow"),
            source_digest=value.get("source_digest"),
            signer_digest=value.get("signer_digest"),
            source_ref=value.get("source_ref"),
        )
    except command_candidate.IndependentAttestationVerifierError as exc:
        errors.extend(f"policy: {error}" for error in exc.errors)

    if value.get("oidc_issuer") != command_candidate.OIDC_ISSUER:
        errors.append("oidc_issuer: exact GitHub Actions OIDC issuer required")
    if value.get("self_hosted_runner_denied") is not True:
        errors.append("self_hosted_runner_denied: true required")

    if value.get("receipt_domain") != receipt.RECEIPT_DOMAIN:
        errors.append("receipt_domain: exact #1471 receipt domain required")
    if value.get("receipt_contract_stage") != receipt.RECEIPT_STAGE:
        errors.append(
            "receipt_contract_stage: exact #1471 receipt contract stage required"
        )

    _validate_evidence(value.get("admin_separation_evidence"), errors)
    return errors


def evaluate_descriptor(
    *,
    repo_root: str | pathlib.Path,
    descriptor_path: str | pathlib.Path,
) -> dict[str, Any]:
    _path, raw = _require_external_regular_file(
        descriptor_path,
        repo_root=repo_root,
        field="boundary_descriptor",
    )
    value = _strict_json_loads(raw, "boundary_descriptor")
    errors = validate_descriptor(value)
    if errors:
        raise ExternalAdminAdmissionError(errors)

    assert isinstance(value, dict)
    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "boundary_id": value["boundary_id"],
        "boundary_type": value["boundary_type"],
        "descriptor_file_sha256": _sha256_bytes(raw),
        "attestation_repo": value["attestation_repo"],
        "signer_repo": value["signer_repo"],
        "signer_workflow": value["signer_workflow"],
        "signer_digest": value["signer_digest"],
        "source_digest": value["source_digest"],
        "source_ref": value["source_ref"],
        "oidc_issuer": value["oidc_issuer"],
        "admin_scope": value["admin_scope"],
        "nonce_owner": value["nonce_owner"],
        "receipt_domain": value["receipt_domain"],
        "receipt_contract_stage": value["receipt_contract_stage"],
        "admin_evidence_count": len(value["admin_separation_evidence"]),
        "descriptor_structure_verified": True,
        "signer_repo_structurally_separate_candidate": True,
        "immutable_signer_digest_bound_candidate": True,
        "source_digest_policy_bound_candidate": True,
        "oidc_issuer_bound_candidate": True,
        "self_hosted_runner_denial_declared_candidate": True,
        "admin_evidence_refs_content_addressed_candidate": True,
        "nonce_owner_declared_candidate": True,
        "receipt_contract_compatible_candidate": True,
        "admin_evidence_independently_verified": False,
        "independent_admin_boundary_verified": False,
        "independent_verifier_execution_attested": False,
        "gh_attestation_cli_execution_verified": False,
        "artifact_digest_cryptographically_verified": False,
        "attestation_signature_cryptographically_verified": False,
        "signer_certificate_identity_verified": False,
        "source_digest_policy_verified": False,
        "signer_workflow_policy_verified": False,
        "self_hosted_runner_denial_verified": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "the external boundary descriptor is structurally admissible and its "
            "administrator-separation Evidence references are content-addressed, "
            "but PlanGate has not independently verified those Evidence objects or "
            "the administrator boundary itself; no strong promotion is allowed"
        ),
        "authority": {key: False for key in sorted(AUTHORITY_KEYS)},
    }
    result["result_hash"] = ingress._canonical_hash(result)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--boundary-descriptor", required=True)
    args = parser.parse_args(argv)

    try:
        result = evaluate_descriptor(
            repo_root=args.repo_root,
            descriptor_path=args.boundary_descriptor,
        )
    except ExternalAdminAdmissionError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
