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

import json
import pathlib
import tempfile
import unittest
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_receipt as ext  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command  # noqa: E402
import runtime_evidence_independent_verifier_boundary_handoff as boundary  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402

VERIFIER_REPO = "trusted/runtime-verifier"
WORKFLOW_REF = (
    VERIFIER_REPO
    + "/.github/workflows/verify-runtime-attestation.yml@"
    + "0123456789abcdef0123456789abcdef01234567"
)
BINARY = "sha256:" + "a" * 64


def _manifest():
    value = {
        "schema_version": "1",
        "domain": boundary.DOMAIN,
        "contract_stage": boundary.CONTRACT_STAGE,
        "boundary_id": "r1-verifier-prod",
        "consumer_domain": ext.DOMAIN,
        "consumer_contract_stage": ext.CONTRACT_STAGE,
        "receipt_input_domain": ext.RECEIPT_DOMAIN,
        "receipt_input_stage": ext.RECEIPT_STAGE,
        "receipt_max_validity_seconds": ext.MAX_VALIDITY_SECONDS,
        "verifier_repo": VERIFIER_REPO,
        "verifier_workflow_ref": WORKFLOW_REF,
        "verifier_binary_sha256": BINARY,
        "trusted_issuer": command.OIDC_ISSUER,
        "runner_policy": "github-hosted-only",
        "self_hosted_runners_denied": True,
        "nonce_ledger_owner": "trusted.example/nonce-ledger",
        "nonce_ledger_namespace": "plangate/r1/runtime",
        "nonce_issue_once": True,
        "nonce_consume_once": True,
        "nonce_reuse_rejected": True,
        "admin_evidence_refs": [
            {
                "kind": "repository_admin_separation",
                "subject": VERIFIER_REPO,
                "uri": "https://evidence.example/admin-separation.json",
                "sha256": "sha256:" + "b" * 64,
            },
            {
                "kind": "workflow_immutability",
                "subject": WORKFLOW_REF,
                "uri": "https://evidence.example/workflow-immutability.json",
                "sha256": "sha256:" + "c" * 64,
            },
            {
                "kind": "nonce_ledger_ownership",
                "subject": "trusted.example/nonce-ledger",
                "uri": "https://evidence.example/nonce-ledger.json",
                "sha256": "sha256:" + "d" * 64,
            },
        ],
    }
    value["manifest_hash"] = ingress._canonical_hash(value)
    return value


def _bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _rehash(value):
    value = dict(value)
    value.pop("manifest_hash", None)
    value["manifest_hash"] = ingress._canonical_hash(value)
    return value


class BoundaryHandoffTests(unittest.TestCase):
    def test_valid_handoff_remains_candidate_only(self):
        result = boundary.verify_boundary_handoff_bytes(
            boundary_manifest_raw=_bytes(_manifest())
        )
        for field in (
            "verifier_repository_separation_candidate",
            "immutable_verifier_workflow_binding_candidate",
            "verifier_binary_binding_candidate",
            "trusted_issuer_binding_candidate",
            "github_hosted_runner_policy_candidate",
            "nonce_one_time_contract_candidate",
            "admin_evidence_refs_content_addressed_candidate",
        ):
            self.assertTrue(result[field])

        for field in (
            "administrator_separation_authenticated",
            "verifier_workflow_identity_cryptographically_verified",
            "verifier_binary_cryptographically_verified",
            "admin_evidence_authenticated",
            "nonce_one_time_consumption_verified",
            "independent_admin_boundary_verified",
            "independent_verifier_execution_attested",
            "runtime_probe_attestation_verified",
            "human_rollout_decision_verified",
            "dispatch_ready",
            "dispatch_allowed",
        ):
            self.assertFalse(result[field])
        self.assertFalse(any(result["authority"].values()))

    def test_plangate_local_verifier_repo_is_rejected(self):
        value = _manifest()
        value["verifier_repo"] = boundary.PLAN_GATE_REPO
        value["verifier_workflow_ref"] = (
            boundary.PLAN_GATE_REPO
            + "/.github/workflows/verify-runtime-attestation.yml@"
            + "0123456789abcdef0123456789abcdef01234567"
        )
        with self.assertRaises(boundary.IndependentVerifierBoundaryHandoffError):
            boundary.verify_boundary_handoff_bytes(
                boundary_manifest_raw=_bytes(_rehash(value))
            )

    def test_mutable_workflow_ref_is_rejected(self):
        value = _manifest()
        value["verifier_workflow_ref"] = (
            VERIFIER_REPO + "/.github/workflows/verify-runtime-attestation.yml@main"
        )
        with self.assertRaises(boundary.IndependentVerifierBoundaryHandoffError):
            boundary.verify_boundary_handoff_bytes(
                boundary_manifest_raw=_bytes(_rehash(value))
            )

    def test_wrong_consumer_contract_is_rejected(self):
        value = _manifest()
        value["consumer_contract_stage"] = "other-stage"
        with self.assertRaises(boundary.IndependentVerifierBoundaryHandoffError):
            boundary.verify_boundary_handoff_bytes(
                boundary_manifest_raw=_bytes(_rehash(value))
            )

    def test_self_hosted_runner_or_local_ledger_is_rejected(self):
        cases = (
            ("self_hosted_runners_denied", False),
            ("runner_policy", "self-hosted"),
            ("nonce_ledger_owner", boundary.PLAN_GATE_REPO),
        )
        for field, replacement in cases:
            value = _manifest()
            value[field] = replacement
            with self.subTest(field=field):
                with self.assertRaises(
                    boundary.IndependentVerifierBoundaryHandoffError
                ):
                    boundary.verify_boundary_handoff_bytes(
                        boundary_manifest_raw=_bytes(_rehash(value))
                    )

    def test_nonce_contract_must_be_one_time(self):
        for field in ("nonce_issue_once", "nonce_consume_once", "nonce_reuse_rejected"):
            value = _manifest()
            value[field] = False
            with self.subTest(field=field):
                with self.assertRaises(
                    boundary.IndependentVerifierBoundaryHandoffError
                ):
                    boundary.verify_boundary_handoff_bytes(
                        boundary_manifest_raw=_bytes(_rehash(value))
                    )

    def test_admin_evidence_must_cover_all_kinds_once(self):
        value = _manifest()
        value["admin_evidence_refs"][2] = dict(value["admin_evidence_refs"][1])
        with self.assertRaises(boundary.IndependentVerifierBoundaryHandoffError):
            boundary.verify_boundary_handoff_bytes(
                boundary_manifest_raw=_bytes(_rehash(value))
            )

    def test_admin_evidence_subject_must_bind_exact_boundary_entity(self):
        value = _manifest()
        value["admin_evidence_refs"][1]["subject"] = (
            VERIFIER_REPO
            + "/.github/workflows/verify-runtime-attestation.yml@"
            + "ffffffffffffffffffffffffffffffffffffffff"
        )
        with self.assertRaises(boundary.IndependentVerifierBoundaryHandoffError):
            boundary.verify_boundary_handoff_bytes(
                boundary_manifest_raw=_bytes(_rehash(value))
            )

    def test_plangate_repository_cannot_be_admin_evidence_source(self):
        for uri in (
            "https://github.com/s977043/PlanGate/blob/main/evidence.json",
            "https://api.github.com/repos/s977043/PlanGate/issues/1473",
            "https://raw.githubusercontent.com/s977043/PlanGate/main/evidence.json",
        ):
            value = _manifest()
            value["admin_evidence_refs"][0]["uri"] = uri
            with self.subTest(uri=uri):
                with self.assertRaises(
                    boundary.IndependentVerifierBoundaryHandoffError
                ):
                    boundary.verify_boundary_handoff_bytes(
                        boundary_manifest_raw=_bytes(_rehash(value))
                    )

    def test_admin_evidence_requires_https_and_digest(self):
        value = _manifest()
        value["admin_evidence_refs"][0]["uri"] = "file:///tmp/fake.json"
        with self.assertRaises(boundary.IndependentVerifierBoundaryHandoffError):
            boundary.verify_boundary_handoff_bytes(
                boundary_manifest_raw=_bytes(_rehash(value))
            )

    def test_tampered_manifest_hash_is_rejected(self):
        value = _manifest()
        value["boundary_id"] = "tampered"
        with self.assertRaises(boundary.IndependentVerifierBoundaryHandoffError):
            boundary.verify_boundary_handoff_bytes(
                boundary_manifest_raw=_bytes(value)
            )

    def test_repository_local_manifest_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo_root = root / "repo"
            repo_root.mkdir()
            path = repo_root / "boundary.json"
            path.write_bytes(_bytes(_manifest()))
            rc = boundary.main(
                [
                    "--repo-root",
                    str(repo_root),
                    "--boundary-manifest",
                    str(path),
                ]
            )
            self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
