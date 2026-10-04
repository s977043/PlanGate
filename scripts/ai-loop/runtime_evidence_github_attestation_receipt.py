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

__doc__ = """Validate a candidate receipt from external gh attestation verification.

This module never invokes gh and never claims that cryptographic verification
actually ran. It validates only:
- a reviewed #1463 managed-capture result;
- the exact external capture-manifest file bytes;
- the documented shape of gh attestation verify --format json;
- an in-toto/SLSA subject SHA-256 equal to those manifest file bytes.

GitHub documents that signature.certificate and verifiedTimestamps in successful
gh attestation verify --format json output are non-user-manipulable when that
output really came from gh. This repository parser cannot prove that provenance,
so every cryptographic / signer / independent-admin attestation flag stays false.
"""

import argparse
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

import runtime_evidence_codex_managed_capture_manifest as managed  # noqa: E402
import runtime_evidence_codex_probe_candidate as probe  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-github-attestation-receipt/v1"
CONTRACT_STAGE = "r1-github-attestation-receipt-candidate-v1"
EXPECTED_PREDICATE_TYPE = "https://slsa.dev/provenance/v1"
MAX_JSON_BYTES = 2 * 1024 * 1024

MANAGED_RESULT_KEYS = {
    "schema_version", "domain", "contract_stage", "request_hash", "config_sha",
    "provider", "platform", "capture_id", "managed_hook_source_claim",
    "managed_policy_sha256", "managed_recorder_sha256", "hook_jsonl_sha256",
    "exec_jsonl_sha256", "correlation_result_hash", "capture_manifest_hash",
    "capture_manifest_structure_verified", "capture_manifest_self_hash_verified",
    "capture_manifest_cross_binding_verified", "managed_hooks_only_claim_candidate",
    "hooks_feature_pinned_claim_candidate", "same_run_binding_manifest_candidate",
    "managed_hook_source_runtime_verified", "managed_policy_live_verified",
    "managed_policy_content_binding_verified", "managed_recorder_binary_verified",
    "managed_recorder_content_binding_verified", "manifest_signature_verified",
    "independent_verifier_execution_attested", "managed_hook_root_attested",
    "same_run_identity_verified", "codex_jsonl_runtime_correlation_verified",
    "hard_read_only_enforced", "runtime_probe_attestation_verified",
    "human_rollout_decision_verified", "dispatch_ready", "dispatch_allowed",
    "verification_limit", "authority", "result_hash",
}
AUTHORITY_KEYS = {
    "agent_invoke_allowed", "code_write_allowed", "approval_write_allowed",
    "merge_allowed", "deploy_allowed",
}
HEX64_RE = re.compile(r"^[0-9a-f]{64}$")


class GitHubAttestationReceiptError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _require_external_regular_file(path, repo_root, field) -> pathlib.Path:
    root = pathlib.Path(repo_root).resolve()
    source = pathlib.Path(path)
    if not source.is_absolute():
        raise GitHubAttestationReceiptError([f"{field}: absolute path required"])
    raw_parent = source.parent
    parent = raw_parent.resolve()
    target = source.resolve(strict=False)
    if not root.is_dir():
        raise GitHubAttestationReceiptError(["repo_root: existing directory required"])
    if not raw_parent.is_dir():
        raise GitHubAttestationReceiptError([f"{field}: parent directory must exist"])
    if parent != raw_parent:
        raise GitHubAttestationReceiptError(
            [f"{field}: parent path must not traverse symlinks"]
        )
    if not source.exists():
        raise GitHubAttestationReceiptError([f"{field}: file must exist"])
    mode = source.lstat().st_mode
    if stat.S_ISLNK(mode):
        raise GitHubAttestationReceiptError([f"{field}: file symlink is not allowed"])
    if not stat.S_ISREG(mode):
        raise GitHubAttestationReceiptError([f"{field}: regular file required"])
    try:
        target.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False
    if inside_repo:
        raise GitHubAttestationReceiptError(
            [f"{field}: runtime artifact must stay outside repository"]
        )
    return source


def _strict_json_loads(text: str, field: str) -> Any:
    def pairs_hook(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise GitHubAttestationReceiptError(
                    [f"{field}: duplicate JSON key {key!r}"]
                )
            result[key] = value
        return result

    def reject_constant(value: str):
        raise GitHubAttestationReceiptError(
            [f"{field}: non-finite JSON number {value!r} not allowed"]
        )

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs_hook,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise GitHubAttestationReceiptError([f"{field}: invalid JSON"]) from exc


def load_json_value(path, *, repo_root, field) -> tuple[Any, str]:
    source = _require_external_regular_file(path, repo_root, field)
    try:
        raw = source.read_bytes()
    except OSError as exc:
        raise GitHubAttestationReceiptError([f"{field}: cannot read: {exc}"]) from exc
    if len(raw) > MAX_JSON_BYTES:
        raise GitHubAttestationReceiptError([f"{field}: file exceeds 2 MiB limit"])
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise GitHubAttestationReceiptError([f"{field}: UTF-8 required"]) from exc
    return _strict_json_loads(text, field), _sha256_bytes(raw)


def _validate_managed_result(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["managed_capture_result: object required"]
    errors: list[str] = []
    unknown = sorted(set(value) - MANAGED_RESULT_KEYS)
    missing = sorted(MANAGED_RESULT_KEYS - set(value))
    if unknown:
        errors.append(f"managed_capture_result: unsupported keys: {unknown}")
    if missing:
        errors.append(f"managed_capture_result: missing keys: {missing}")
    if value.get("schema_version") != "1":
        errors.append("managed_capture_result.schema_version: 1 required")
    if value.get("domain") != managed.DOMAIN:
        errors.append("managed_capture_result.domain: exact #1463 domain required")
    if value.get("contract_stage") != managed.CONTRACT_STAGE:
        errors.append(
            "managed_capture_result.contract_stage: exact #1463 stage required"
        )
    if value.get("platform") != "codex":
        errors.append("managed_capture_result.platform: codex required")

    body = dict(value)
    claimed_hash = body.pop("result_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("managed_capture_result.result_hash: canonical hash mismatch")

    required_true = (
        "capture_manifest_structure_verified",
        "capture_manifest_self_hash_verified",
        "capture_manifest_cross_binding_verified",
        "managed_hooks_only_claim_candidate",
        "hooks_feature_pinned_claim_candidate",
        "same_run_binding_manifest_candidate",
    )
    for field in required_true:
        if value.get(field) is not True:
            errors.append(f"managed_capture_result.{field}: true required")

    required_false = (
        "managed_hook_source_runtime_verified",
        "managed_policy_live_verified",
        "managed_policy_content_binding_verified",
        "managed_recorder_binary_verified",
        "managed_recorder_content_binding_verified",
        "manifest_signature_verified",
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
    for field in required_false:
        if value.get(field) is not False:
            errors.append(f"managed_capture_result.{field}: false required")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append("managed_capture_result.authority: object required")
    else:
        if set(authority) != AUTHORITY_KEYS:
            errors.append("managed_capture_result.authority: exact key set required")
        if any(authority.get(field) is not False for field in AUTHORITY_KEYS):
            errors.append("managed_capture_result.authority: all values must remain false")
    return errors


def _validate_manifest_file(
    manifest: Any,
    *,
    managed_result: dict[str, Any],
) -> list[str]:
    if not isinstance(manifest, dict):
        return ["capture_manifest: object required"]
    errors: list[str] = []
    if set(manifest) != managed.MANIFEST_KEYS:
        errors.append("capture_manifest: exact #1463 manifest key set required")
    body = dict(manifest)
    claimed_hash = body.pop("manifest_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("capture_manifest.manifest_hash: canonical hash mismatch")
    if claimed_hash != managed_result.get("capture_manifest_hash"):
        errors.append("capture_manifest: exact #1463 manifest-hash binding required")
    return errors


def _validate_gh_output(value: Any, artifact_sha256: str) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["gh_attestation_output: array required"], {}
    if len(value) != 1:
        return ["gh_attestation_output: exactly one verified attestation required"], {}

    entry = value[0]
    if not isinstance(entry, dict):
        return ["gh_attestation_output[0]: object required"], {}
    if set(entry) != {"attestation", "verificationResult"}:
        errors.append(
            "gh_attestation_output[0]: exact attestation/verificationResult keys required"
        )

    verification = entry.get("verificationResult")
    if not isinstance(verification, dict):
        errors.append("verificationResult: object required")
        return errors, {}

    signature = verification.get("signature")
    certificate_present = (
        isinstance(signature, dict)
        and isinstance(signature.get("certificate"), dict)
        and bool(signature.get("certificate"))
    )
    if not certificate_present:
        errors.append("verificationResult.signature.certificate: non-empty object required")

    timestamps = verification.get("verifiedTimestamps")
    timestamps_present = isinstance(timestamps, list) and len(timestamps) > 0
    if not timestamps_present:
        errors.append("verificationResult.verifiedTimestamps: non-empty array required")

    statement = verification.get("statement")
    if not isinstance(statement, dict):
        errors.append("verificationResult.statement: object required")
        return errors, {
            "certificate_present": certificate_present,
            "timestamps_present": timestamps_present,
        }

    if statement.get("predicateType") != EXPECTED_PREDICATE_TYPE:
        errors.append(
            f"verificationResult.statement.predicateType: {EXPECTED_PREDICATE_TYPE} required"
        )

    subjects = statement.get("subject")
    subject_digest_match = False
    if not isinstance(subjects, list) or len(subjects) != 1:
        errors.append("verificationResult.statement.subject: exactly one subject required")
    else:
        subject = subjects[0]
        if not isinstance(subject, dict):
            errors.append("verificationResult.statement.subject[0]: object required")
        else:
            digest = subject.get("digest")
            expected_hex = artifact_sha256.removeprefix("sha256:")
            if (
                not isinstance(digest, dict)
                or set(digest) != {"sha256"}
                or not isinstance(digest.get("sha256"), str)
                or not HEX64_RE.fullmatch(digest["sha256"])
            ):
                errors.append(
                    "verificationResult.statement.subject[0].digest: exact sha256 digest required"
                )
            elif digest["sha256"] != expected_hex:
                errors.append(
                    "verificationResult.statement.subject[0].digest.sha256: "
                    "exact capture-manifest file binding required"
                )
            else:
                subject_digest_match = True

    return errors, {
        "certificate_present": certificate_present,
        "timestamps_present": timestamps_present,
        "verified_timestamp_count": len(timestamps) if isinstance(timestamps, list) else 0,
        "subject_digest_match": subject_digest_match,
    }


def verify_candidate(
    *,
    managed_capture_result: Any,
    capture_manifest: Any,
    capture_manifest_file_sha256: str,
    gh_attestation_output: Any,
    gh_attestation_output_sha256: str,
) -> dict[str, Any]:
    errors = _validate_managed_result(managed_capture_result)
    if isinstance(managed_capture_result, dict):
        errors.extend(
            _validate_manifest_file(
                capture_manifest,
                managed_result=managed_capture_result,
            )
        )
    else:
        errors.append("capture_manifest: cannot bind invalid managed-capture result")

    if not isinstance(capture_manifest_file_sha256, str) or not probe.HASH_RE.fullmatch(
        capture_manifest_file_sha256
    ):
        errors.append("capture_manifest_file_sha256: valid SHA-256 required")

    gh_errors, gh_summary = _validate_gh_output(
        gh_attestation_output,
        capture_manifest_file_sha256,
    )
    errors.extend(gh_errors)
    if not isinstance(gh_attestation_output_sha256, str) or not probe.HASH_RE.fullmatch(
        gh_attestation_output_sha256
    ):
        errors.append("gh_attestation_output_sha256: valid SHA-256 required")
    if errors:
        raise GitHubAttestationReceiptError(errors)

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": managed_capture_result["request_hash"],
        "config_sha": managed_capture_result["config_sha"],
        "provider": managed_capture_result["provider"],
        "platform": "codex",
        "capture_id": managed_capture_result["capture_id"],
        "managed_capture_result_hash": managed_capture_result["result_hash"],
        "capture_manifest_hash": managed_capture_result["capture_manifest_hash"],
        "capture_manifest_file_sha256": capture_manifest_file_sha256,
        "gh_attestation_output_sha256": gh_attestation_output_sha256,
        "github_attestation_output_structure_verified": True,
        "artifact_subject_digest_match_candidate": True,
        "signature_certificate_present_candidate": gh_summary["certificate_present"],
        "verified_timestamp_present_candidate": gh_summary["timestamps_present"],
        "verified_timestamp_count": gh_summary["verified_timestamp_count"],
        "slsa_provenance_predicate_type_candidate": True,
        "statement_predicate_trusted": False,
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
        "manifest_signature_verified": False,
        "managed_hook_root_attested": False,
        "same_run_identity_verified": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "the raw JSON shape matches documented gh attestation verification output "
            "and its SLSA subject digest equals the exact capture-manifest file bytes, "
            "but repository code did not execute gh or cryptographically authenticate "
            "the output source; certificate/timestamp presence therefore remains candidate evidence"
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


def _decode_json_bytes(raw: bytes, *, field: str, max_bytes: int) -> Any:
    if len(raw) > max_bytes:
        raise GitHubAttestationReceiptError(
            [f"{field}: file exceeds {max_bytes} byte limit"]
        )
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise GitHubAttestationReceiptError([f"{field}: UTF-8 required"]) from exc
    return _strict_json_loads(text, field)


def verify_candidate_bytes(
    *,
    managed_capture_result_raw: bytes,
    capture_manifest_raw: bytes,
    gh_attestation_output_raw: bytes,
) -> dict[str, Any]:
    managed_result = _decode_json_bytes(
        managed_capture_result_raw,
        field="managed_capture_result",
        max_bytes=MAX_JSON_BYTES,
    )
    manifest = _decode_json_bytes(
        capture_manifest_raw,
        field="capture_manifest",
        max_bytes=managed.MAX_JSON_BYTES,
    )
    gh_output = _decode_json_bytes(
        gh_attestation_output_raw,
        field="gh_attestation_output",
        max_bytes=MAX_JSON_BYTES,
    )
    return _verify_candidate(
        managed_capture_result=managed_result,
        capture_manifest=manifest,
        capture_manifest_file_sha256=_sha256_bytes(capture_manifest_raw),
        gh_attestation_output=gh_output,
        gh_attestation_output_sha256=_sha256_bytes(gh_attestation_output_raw),
    )


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--managed-capture-result", required=True)
    parser.add_argument("--capture-manifest", required=True)
    parser.add_argument("--gh-attestation-json", required=True)
    args = parser.parse_args(argv)
    try:
        managed_path = _require_external_regular_file(
            args.managed_capture_result, args.repo_root, "managed_capture_result"
        )
        manifest_path = _require_external_regular_file(
            args.capture_manifest, args.repo_root, "capture_manifest"
        )
        gh_path = _require_external_regular_file(
            args.gh_attestation_json, args.repo_root, "gh_attestation_output"
        )
        managed_raw = managed_path.read_bytes()
        manifest_raw = manifest_path.read_bytes()
        gh_raw = gh_path.read_bytes()
        result = verify_candidate_bytes(
            managed_capture_result_raw=managed_raw,
            capture_manifest_raw=manifest_raw,
            gh_attestation_output_raw=gh_raw,
        )
    except GitHubAttestationReceiptError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
