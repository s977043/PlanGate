#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """Run bounded GitHub artifact-attestation verification for R1 evidence.

This is the cryptographic-verification slice of #1468. It executes only the
strictly allowlisted, read-only gh attestation verify path through gh_exec and
then reuses the #1466 candidate receipt parser for exact capture-manifest
binding.

Successful cryptographic verification is not proof that this Python process
itself ran inside an independently administered boundary. Therefore the
independent-admin, runtime-probe, and dispatch authority flags stay false.
"""

import argparse
import json
import pathlib
import re
import sys
from typing import Any, Callable

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import gh_exec  # noqa: E402
import runtime_evidence_codex_managed_capture_manifest as managed  # noqa: E402
import runtime_evidence_github_attestation_receipt as candidate_receipt  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-independent-attestation-verifier/v1"
CONTRACT_STAGE = "r1-independent-attestation-verifier-crypto-v1"
OIDC_ISSUER = "https://token.actions.githubusercontent.com"
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
REF_RE = re.compile(r"^refs/(?:heads|tags)/[A-Za-z0-9][A-Za-z0-9._/-]*$")
WORKFLOW_FILE_RE = re.compile(r"^[A-Za-z0-9_.-]+\.ya?ml$")
MAX_STDOUT_BYTES = candidate_receipt.MAX_JSON_BYTES


class IndependentAttestationVerifierError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _validate_policy(
    *,
    verifier_repo: str,
    signer_workflow: str,
    source_digest: str,
    source_ref: str,
) -> None:
    errors: list[str] = []
    if not isinstance(verifier_repo, str) or REPO_RE.fullmatch(verifier_repo) is None:
        errors.append("verifier_repo: owner/repo required")

    expected_prefix = f"{verifier_repo}/.github/workflows/"
    if (
        not isinstance(signer_workflow, str)
        or not signer_workflow.startswith(expected_prefix)
        or WORKFLOW_FILE_RE.fullmatch(
            signer_workflow.removeprefix(expected_prefix)
        ) is None
    ):
        errors.append(
            "signer_workflow: exact verifier-repo .github/workflows file required"
        )

    if not isinstance(source_digest, str) or SHA40_RE.fullmatch(source_digest) is None:
        errors.append("source_digest: 40 lowercase hex git SHA required")

    if (
        not isinstance(source_ref, str)
        or ".." in source_ref
        or REF_RE.fullmatch(source_ref) is None
    ):
        errors.append("source_ref: bounded refs/heads/* or refs/tags/* required")

    if errors:
        raise IndependentAttestationVerifierError(errors)


def build_verify_args(
    *,
    artifact_path: pathlib.Path,
    verifier_repo: str,
    signer_workflow: str,
    source_digest: str,
    source_ref: str,
) -> list[str]:
    _validate_policy(
        verifier_repo=verifier_repo,
        signer_workflow=signer_workflow,
        source_digest=source_digest,
        source_ref=source_ref,
    )
    return [
        "attestation", "verify", str(artifact_path),
        "--repo", verifier_repo,
        "--signer-repo", verifier_repo,
        "--signer-workflow", signer_workflow,
        "--source-digest", source_digest,
        "--signer-digest", source_digest,
        "--source-ref", source_ref,
        "--cert-oidc-issuer", OIDC_ISSUER,
        "--predicate-type", candidate_receipt.EXPECTED_PREDICATE_TYPE,
        "--deny-self-hosted-runners",
        "--no-public-good",
        "--format", "json",
    ]


def verify_with_github_attestation(
    *,
    repo_root,
    managed_capture_result_raw: bytes,
    capture_manifest_path,
    verifier_repo: str,
    signer_workflow: str,
    source_digest: str,
    source_ref: str,
    cwd=None,
    runner: Callable[..., Any] = gh_exec.run_gh,
) -> dict[str, Any]:
    manifest_path = candidate_receipt._require_external_regular_file(
        capture_manifest_path,
        repo_root,
        "capture_manifest",
    )
    manifest_raw = candidate_receipt.load_raw_bytes(
        manifest_path,
        repo_root=repo_root,
        field="capture_manifest",
        max_bytes=managed.MAX_JSON_BYTES,
    )
    args = build_verify_args(
        artifact_path=manifest_path,
        verifier_repo=verifier_repo,
        signer_workflow=signer_workflow,
        source_digest=source_digest,
        source_ref=source_ref,
    )

    try:
        proc = runner(args, repo=verifier_repo, cwd=cwd)
    except gh_exec.Denied as exc:
        raise IndependentAttestationVerifierError(
            [f"gh_attestation_verify: allowlist denied: {exc}"]
        ) from exc

    if getattr(proc, "returncode", 1) != 0:
        raise IndependentAttestationVerifierError(
            ["gh_attestation_verify: verification command failed"]
        )
    stdout = getattr(proc, "stdout", None)
    if not isinstance(stdout, str):
        raise IndependentAttestationVerifierError(
            ["gh_attestation_verify: text stdout required"]
        )
    gh_raw = stdout.encode("utf-8")
    if len(gh_raw) > MAX_STDOUT_BYTES:
        raise IndependentAttestationVerifierError(
            [f"gh_attestation_verify: stdout exceeds {MAX_STDOUT_BYTES} byte limit"]
        )

    try:
        upstream = candidate_receipt.verify_candidate_bytes(
            managed_capture_result_raw=managed_capture_result_raw,
            capture_manifest_raw=manifest_raw,
            gh_attestation_output_raw=gh_raw,
        )
    except candidate_receipt.GitHubAttestationReceiptError as exc:
        raise IndependentAttestationVerifierError(exc.errors) from exc

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": upstream["request_hash"],
        "config_sha": upstream["config_sha"],
        "provider": upstream["provider"],
        "platform": upstream["platform"],
        "capture_id": upstream["capture_id"],
        "candidate_receipt_hash": upstream["result_hash"],
        "capture_manifest_hash": upstream["capture_manifest_hash"],
        "capture_manifest_file_sha256": upstream["capture_manifest_file_sha256"],
        "verifier_repo": verifier_repo,
        "signer_workflow": signer_workflow,
        "source_digest": source_digest,
        "source_ref": source_ref,
        "oidc_issuer": OIDC_ISSUER,
        "predicate_type": candidate_receipt.EXPECTED_PREDICATE_TYPE,
        "exact_verifier_policy_bound": True,
        "gh_attestation_cli_execution_verified": True,
        "artifact_digest_cryptographically_verified": True,
        "attestation_signature_cryptographically_verified": True,
        "signer_certificate_identity_verified": True,
        "verified_timestamp_cryptographically_verified": True,
        "signer_workflow_policy_verified": True,
        "source_digest_policy_verified": True,
        "self_hosted_runner_denial_verified": True,
        "capture_manifest_artifact_attestation_verified": True,
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
            "gh cryptographically verified the exact capture-manifest artifact "
            "against a pinned repository/workflow/source policy, but this process "
            "cannot self-attest that its execution environment is independently "
            "administered; runtime/dispatch promotion therefore remains blocked"
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
    parser.add_argument("--managed-capture-result", required=True)
    parser.add_argument("--capture-manifest", required=True)
    parser.add_argument("--verifier-repo", required=True)
    parser.add_argument("--signer-workflow", required=True)
    parser.add_argument("--source-digest", required=True)
    parser.add_argument("--source-ref", required=True)
    args = parser.parse_args(argv)

    try:
        managed_raw = candidate_receipt.load_raw_bytes(
            args.managed_capture_result,
            repo_root=args.repo_root,
            field="managed_capture_result",
            max_bytes=candidate_receipt.MAX_JSON_BYTES,
        )
        result = verify_with_github_attestation(
            repo_root=args.repo_root,
            managed_capture_result_raw=managed_raw,
            capture_manifest_path=args.capture_manifest,
            verifier_repo=args.verifier_repo,
            signer_workflow=args.signer_workflow,
            source_digest=args.source_digest,
            source_ref=args.source_ref,
            cwd=args.repo_root,
        )
    except (
        candidate_receipt.GitHubAttestationReceiptError,
        IndependentAttestationVerifierError,
    ) as exc:
        errors = getattr(exc, "errors", [str(exc)])
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
