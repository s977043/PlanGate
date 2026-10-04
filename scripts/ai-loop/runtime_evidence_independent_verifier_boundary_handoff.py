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

__doc__ = """Validate the #1473 independent-verifier boundary handoff candidate.

This is a repository-side preparation contract only. It checks that a proposed
GitHub Actions verifier boundary is structurally separated from PlanGate,
immutably identified, tied to the #1471 receipt consumer contract, and accompanied
by content-addressed external administration evidence references and an external
one-time nonce-ledger contract.

Passing this validator MUST NOT be interpreted as proof that the administration,
workflow, binary, evidence, or nonce ledger is independently controlled. Those
facts require independently administered evidence and remain false here.
"""

import argparse
import json
import pathlib
import re
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_receipt as external_receipt  # noqa: E402
import runtime_evidence_github_attestation_receipt as receipt_io  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command_verifier  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-independent-verifier-boundary-handoff/v1"
CONTRACT_STAGE = "r1-independent-verifier-boundary-handoff-candidate-v1"
PLAN_GATE_REPO = "s977043/PlanGate"
MAX_JSON_BYTES = 256 * 1024

REPO_RE = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$"
)
WORKFLOW_REF_RE = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*/"
    r"\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml@[0-9a-f]{40}$"
)
HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
IDENTITY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9:/._@+-]{0,255}$")
NAMESPACE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$")
HTTPS_RE = re.compile(r"^https://[^\s]+$")

MANIFEST_KEYS = {
    "schema_version",
    "domain",
    "contract_stage",
    "boundary_id",
    "consumer_domain",
    "consumer_contract_stage",
    "receipt_input_domain",
    "receipt_input_stage",
    "receipt_max_validity_seconds",
    "verifier_repo",
    "verifier_workflow_ref",
    "verifier_binary_sha256",
    "trusted_issuer",
    "runner_policy",
    "self_hosted_runners_denied",
    "nonce_ledger_owner",
    "nonce_ledger_namespace",
    "nonce_issue_once",
    "nonce_consume_once",
    "nonce_reuse_rejected",
    "admin_evidence_refs",
    "manifest_hash",
}

EVIDENCE_KEYS = {"kind", "uri", "sha256"}
REQUIRED_EVIDENCE_KINDS = {
    "repository_admin_separation",
    "workflow_immutability",
    "nonce_ledger_ownership",
}

AUTHORITY_KEYS = {
    "agent_invoke_allowed",
    "code_write_allowed",
    "approval_write_allowed",
    "merge_allowed",
    "deploy_allowed",
}


class IndependentVerifierBoundaryHandoffError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _strict_json_loads(raw: bytes, field: str) -> Any:
    if len(raw) > MAX_JSON_BYTES:
        raise IndependentVerifierBoundaryHandoffError(
            [f"{field}: exceeds {MAX_JSON_BYTES} byte limit"]
        )
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise IndependentVerifierBoundaryHandoffError(
            [f"{field}: UTF-8 required"]
        ) from exc

    def pairs_hook(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise IndependentVerifierBoundaryHandoffError(
                    [f"{field}: duplicate JSON key {key!r}"]
                )
            value[key] = item
        return value

    def reject_constant(value):
        raise IndependentVerifierBoundaryHandoffError(
            [f"{field}: non-finite JSON number {value!r} not allowed"]
        )

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs_hook,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise IndependentVerifierBoundaryHandoffError(
            [f"{field}: invalid JSON"]
        ) from exc


def _validate_manifest(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["boundary_manifest: object required"]

    errors: list[str] = []
    unknown = sorted(set(value) - MANIFEST_KEYS)
    missing = sorted(MANIFEST_KEYS - set(value))
    if unknown:
        errors.append(f"boundary_manifest: unsupported keys: {unknown}")
    if missing:
        errors.append(f"boundary_manifest: missing keys: {missing}")

    if value.get("schema_version") != "1":
        errors.append("boundary_manifest.schema_version: 1 required")
    if value.get("domain") != DOMAIN:
        errors.append("boundary_manifest.domain: exact domain required")
    if value.get("contract_stage") != CONTRACT_STAGE:
        errors.append("boundary_manifest.contract_stage: exact stage required")

    boundary_id = value.get("boundary_id")
    if not isinstance(boundary_id, str) or IDENTITY_RE.fullmatch(boundary_id) is None:
        errors.append("boundary_manifest.boundary_id: bounded identity required")

    exact_contract = {
        "consumer_domain": external_receipt.DOMAIN,
        "consumer_contract_stage": external_receipt.CONTRACT_STAGE,
        "receipt_input_domain": external_receipt.RECEIPT_DOMAIN,
        "receipt_input_stage": external_receipt.RECEIPT_STAGE,
        "receipt_max_validity_seconds": external_receipt.MAX_VALIDITY_SECONDS,
    }
    for field, expected in exact_contract.items():
        if value.get(field) != expected:
            errors.append(
                f"boundary_manifest.{field}: exact #1471 contract binding required"
            )

    verifier_repo = value.get("verifier_repo")
    if not isinstance(verifier_repo, str) or REPO_RE.fullmatch(verifier_repo) is None:
        errors.append("boundary_manifest.verifier_repo: owner/repo required")
    elif verifier_repo.lower() == PLAN_GATE_REPO.lower():
        errors.append(
            "boundary_manifest.verifier_repo: PlanGate-local verifier is not independent"
        )

    workflow_ref = value.get("verifier_workflow_ref")
    if not isinstance(workflow_ref, str) or WORKFLOW_REF_RE.fullmatch(workflow_ref) is None:
        errors.append(
            "boundary_manifest.verifier_workflow_ref: immutable workflow@40hex required"
        )
    elif isinstance(verifier_repo, str) and not workflow_ref.startswith(
        verifier_repo + "/.github/workflows/"
    ):
        errors.append(
            "boundary_manifest.verifier_workflow_ref: exact verifier_repo workflow required"
        )

    binary = value.get("verifier_binary_sha256")
    if not isinstance(binary, str) or HASH_RE.fullmatch(binary) is None:
        errors.append(
            "boundary_manifest.verifier_binary_sha256: sha256 verifier digest required"
        )

    if value.get("trusted_issuer") != command_verifier.OIDC_ISSUER:
        errors.append(
            "boundary_manifest.trusted_issuer: exact GitHub Actions OIDC issuer required"
        )
    if value.get("runner_policy") != "github-hosted-only":
        errors.append(
            "boundary_manifest.runner_policy: github-hosted-only required"
        )
    if value.get("self_hosted_runners_denied") is not True:
        errors.append(
            "boundary_manifest.self_hosted_runners_denied: true required"
        )

    ledger_owner = value.get("nonce_ledger_owner")
    if (
        not isinstance(ledger_owner, str)
        or IDENTITY_RE.fullmatch(ledger_owner) is None
    ):
        errors.append(
            "boundary_manifest.nonce_ledger_owner: bounded external identity required"
        )
    elif ledger_owner.lower() == PLAN_GATE_REPO.lower():
        errors.append(
            "boundary_manifest.nonce_ledger_owner: PlanGate cannot own the independent nonce ledger"
        )

    ledger_namespace = value.get("nonce_ledger_namespace")
    if (
        not isinstance(ledger_namespace, str)
        or NAMESPACE_RE.fullmatch(ledger_namespace) is None
    ):
        errors.append(
            "boundary_manifest.nonce_ledger_namespace: bounded namespace required"
        )

    for field in ("nonce_issue_once", "nonce_consume_once", "nonce_reuse_rejected"):
        if value.get(field) is not True:
            errors.append(f"boundary_manifest.{field}: true contract required")

    evidence = value.get("admin_evidence_refs")
    if not isinstance(evidence, list):
        errors.append("boundary_manifest.admin_evidence_refs: array required")
    else:
        kinds: list[str] = []
        uris: list[str] = []
        for index, item in enumerate(evidence):
            prefix = f"boundary_manifest.admin_evidence_refs[{index}]"
            if not isinstance(item, dict):
                errors.append(f"{prefix}: object required")
                continue
            if set(item) != EVIDENCE_KEYS:
                errors.append(f"{prefix}: exact kind/uri/sha256 keys required")
                continue
            kind = item.get("kind")
            uri = item.get("uri")
            digest = item.get("sha256")
            if kind not in REQUIRED_EVIDENCE_KINDS:
                errors.append(f"{prefix}.kind: unsupported evidence kind")
            else:
                kinds.append(kind)
            if not isinstance(uri, str) or HTTPS_RE.fullmatch(uri) is None:
                errors.append(f"{prefix}.uri: https URL required")
            else:
                uris.append(uri)
            if not isinstance(digest, str) or HASH_RE.fullmatch(digest) is None:
                errors.append(f"{prefix}.sha256: sha256 digest required")

        if set(kinds) != REQUIRED_EVIDENCE_KINDS or len(kinds) != len(
            REQUIRED_EVIDENCE_KINDS
        ):
            errors.append(
                "boundary_manifest.admin_evidence_refs: exactly one ref per required kind"
            )
        if len(uris) != len(set(uris)):
            errors.append(
                "boundary_manifest.admin_evidence_refs: duplicate URI not allowed"
            )

    body = dict(value)
    claimed_hash = body.pop("manifest_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("boundary_manifest.manifest_hash: canonical hash mismatch")
    return errors


def verify_boundary_handoff_bytes(*, boundary_manifest_raw: bytes) -> dict[str, Any]:
    manifest = _strict_json_loads(boundary_manifest_raw, "boundary_manifest")
    errors = _validate_manifest(manifest)
    if errors:
        raise IndependentVerifierBoundaryHandoffError(errors)

    assert isinstance(manifest, dict)
    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "boundary_id": manifest["boundary_id"],
        "boundary_manifest_hash": manifest["manifest_hash"],
        "consumer_domain": manifest["consumer_domain"],
        "consumer_contract_stage": manifest["consumer_contract_stage"],
        "verifier_repo": manifest["verifier_repo"],
        "verifier_workflow_ref": manifest["verifier_workflow_ref"],
        "verifier_binary_sha256": manifest["verifier_binary_sha256"],
        "trusted_issuer": manifest["trusted_issuer"],
        "runner_policy": manifest["runner_policy"],
        "nonce_ledger_owner": manifest["nonce_ledger_owner"],
        "nonce_ledger_namespace": manifest["nonce_ledger_namespace"],
        "verifier_repository_separation_candidate": True,
        "immutable_verifier_workflow_binding_candidate": True,
        "verifier_binary_binding_candidate": True,
        "trusted_issuer_binding_candidate": True,
        "github_hosted_runner_policy_candidate": True,
        "nonce_one_time_contract_candidate": True,
        "admin_evidence_refs_content_addressed_candidate": True,
        "administrator_separation_authenticated": False,
        "verifier_workflow_identity_cryptographically_verified": False,
        "verifier_binary_cryptographically_verified": False,
        "admin_evidence_authenticated": False,
        "nonce_one_time_consumption_verified": False,
        "gh_attestation_cli_execution_verified": False,
        "artifact_digest_cryptographically_verified": False,
        "attestation_signature_cryptographically_verified": False,
        "signer_certificate_identity_verified": False,
        "source_digest_policy_verified": False,
        "signer_workflow_policy_verified": False,
        "self_hosted_runner_denial_verified": False,
        "independent_admin_boundary_verified": False,
        "independent_verifier_execution_attested": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "the proposed external boundary is structurally separated from PlanGate, "
            "immutably identified, bound to the #1471 receipt contract, and accompanied "
            "by content-addressed administration evidence references plus a one-time "
            "nonce-ledger contract; repository code cannot authenticate the administration, "
            "workflow/binary provenance, evidence refs, or ledger behavior, so strong "
            "machine/runtime/Human/dispatch promotion remains blocked"
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
    parser.add_argument("--boundary-manifest", required=True)
    args = parser.parse_args(argv)

    try:
        raw = receipt_io.load_raw_bytes(
            args.boundary_manifest,
            repo_root=args.repo_root,
            field="boundary_manifest",
            max_bytes=MAX_JSON_BYTES,
        )
        result = verify_boundary_handoff_bytes(boundary_manifest_raw=raw)
    except (
        receipt_io.GitHubAttestationReceiptError,
        IndependentVerifierBoundaryHandoffError,
    ) as exc:
        errors = getattr(exc, "errors", [str(exc)])
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
