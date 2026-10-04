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
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_external_admin_admission as admission  # noqa: E402
import runtime_evidence_external_verifier_receipt as receipt  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command_candidate  # noqa: E402


ATTESTATION_REPO = "s977043/PlanGate"
SIGNER_REPO = "trusted-runtime/runtime-verifier"
WORKFLOW = SIGNER_REPO + "/.github/workflows/verify-runtime-attestation.yml"
SOURCE = "0123456789abcdef0123456789abcdef01234567"
SIGNER = "89abcdef0123456789abcdef0123456789abcdef"


def _descriptor():
    return {
        "schema_version": "1",
        "domain": admission.INPUT_DOMAIN,
        "contract_stage": admission.INPUT_STAGE,
        "boundary_id": "runtime-verifier-prod",
        "boundary_type": "github_repository",
        "attestation_repo": ATTESTATION_REPO,
        "signer_repo": SIGNER_REPO,
        "signer_workflow": WORKFLOW,
        "signer_digest": SIGNER,
        "source_digest": SOURCE,
        "source_ref": "refs/heads/main",
        "oidc_issuer": command_candidate.OIDC_ISSUER,
        "self_hosted_runner_denied": True,
        "admin_scope": "external-runtime-verifier-admins",
        "nonce_owner": "external-runtime-verifier",
        "receipt_domain": receipt.RECEIPT_DOMAIN,
        "receipt_contract_stage": receipt.RECEIPT_STAGE,
        "admin_separation_evidence": [
            {
                "evidence_type": "administrator-separation-attestation",
                "uri": "https://example.invalid/evidence/admin-separation.json",
                "sha256": "sha256:" + "a" * 64,
            },
            {
                "evidence_type": "signer-identity-attestation",
                "uri": "https://example.invalid/evidence/signer-identity.json",
                "sha256": "sha256:" + "b" * 64,
            },
            {
                "evidence_type": "nonce-lifecycle-policy",
                "uri": "https://example.invalid/evidence/nonce-lifecycle.json",
                "sha256": "sha256:" + "c" * 64,
            },
        ],
    }


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


class ExternalAdminAdmissionTests(unittest.TestCase):
    def _run(self, *, mutate=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo_root = root / "repo"
            external = root / "external"
            repo_root.mkdir()
            external.mkdir()

            value = _descriptor()
            if mutate is not None:
                mutate(value)

            path = external / "boundary.json"
            path.write_bytes(_json_bytes(value))
            return admission.evaluate_descriptor(
                repo_root=repo_root,
                descriptor_path=path,
            )

    def test_valid_descriptor_stays_candidate_only(self):
        result = self._run()
        for field in (
            "descriptor_structure_verified",
            "signer_repo_structurally_separate_candidate",
            "immutable_signer_digest_bound_candidate",
            "source_digest_policy_bound_candidate",
            "oidc_issuer_bound_candidate",
            "self_hosted_runner_denial_declared_candidate",
            "admin_evidence_refs_content_addressed_candidate",
            "admin_evidence_set_content_hash_candidate",
            "nonce_owner_declared_candidate",
            "receipt_contract_compatible_candidate",
        ):
            self.assertTrue(result[field])

        for field in (
            "admin_evidence_independently_verified",
            "independent_admin_boundary_verified",
            "independent_verifier_execution_attested",
            "gh_attestation_cli_execution_verified",
            "artifact_digest_cryptographically_verified",
            "attestation_signature_cryptographically_verified",
            "signer_certificate_identity_verified",
            "source_digest_policy_verified",
            "signer_workflow_policy_verified",
            "self_hosted_runner_denial_verified",
            "runtime_probe_attestation_verified",
            "human_rollout_decision_verified",
            "dispatch_ready",
            "dispatch_allowed",
        ):
            self.assertFalse(result[field])
        self.assertFalse(any(result["authority"].values()))
        self.assertTrue(result["admin_evidence_set_hash"].startswith("sha256:"))
        self.assertNotIn("admin_separation_evidence", result)

    def test_evidence_set_hash_is_order_independent(self):
        first = self._run()

        def reverse(value):
            value["admin_separation_evidence"] = list(
                reversed(value["admin_separation_evidence"])
            )

        second = self._run(mutate=reverse)
        self.assertEqual(
            first["admin_evidence_set_hash"],
            second["admin_evidence_set_hash"],
        )

    def test_signer_repo_must_be_separate_from_attestation_repo(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.update(
                    {
                        "signer_repo": ATTESTATION_REPO,
                        "signer_workflow": (
                            ATTESTATION_REPO
                            + "/.github/workflows/verify-runtime-attestation.yml"
                        ),
                    }
                )
            )

    def test_plangate_repo_cannot_be_external_signer(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.update(
                    {
                        "attestation_repo": "other/evidence",
                        "signer_repo": "s977043/PlanGate",
                        "signer_workflow": (
                            "s977043/PlanGate/.github/workflows/verify.yml"
                        ),
                    }
                )
            )

    def test_plangate_repository_evidence_uri_is_rejected(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value["admin_separation_evidence"][0].update(
                    {
                        "uri": (
                            "https://github.com/s977043/PlanGate/blob/main/"
                            "docs/evidence.json"
                        )
                    }
                )
            )

    def test_plangate_repository_evidence_uri_case_and_encoding_bypass_is_rejected(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value["admin_separation_evidence"][0].update(
                    {
                        "uri": (
                            "https://github.com/S977043%2FPlanGate/blob/main/"
                            "docs/evidence.json"
                        )
                    }
                )
            )

    def test_plangate_repository_evidence_uri_dot_segment_bypass_is_rejected(self):
        def mutate(value):
            value["admin_separation_evidence"][0]["uri"] = (
                "https://github.com/s977043/./PlanGate/evidence.json"
            )

        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(mutate=mutate)

    def test_plangate_repository_evidence_uri_double_slash_bypass_is_rejected(self):
        def mutate(value):
            value["admin_separation_evidence"][0]["uri"] = (
                "https://github.com/s977043//PlanGate/evidence.json"
            )

        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(mutate=mutate)

    def test_noncanonical_external_evidence_uri_path_is_rejected(self):
        def mutate(value):
            value["admin_separation_evidence"][0]["uri"] = (
                "https://example.invalid/evidence/../admin.json"
            )

        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(mutate=mutate)

    def test_external_service_type_is_not_admitted_by_github_contract(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.__setitem__(
                    "boundary_type", "external_service"
                )
            )

    def test_evidence_uri_query_or_fragment_is_rejected(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value["admin_separation_evidence"][0].update(
                    {
                        "uri": (
                            "https://example.invalid/evidence/admin-separation.json"
                            "?token=secret#latest"
                        )
                    }
                )
            )

    def test_duplicate_evidence_digest_is_rejected(self):
        def mutate(value):
            value["admin_separation_evidence"][1]["sha256"] = (
                value["admin_separation_evidence"][0]["sha256"]
            )

        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(mutate=mutate)

    def test_duplicate_evidence_type_is_rejected(self):
        def mutate(value):
            value["admin_separation_evidence"][1]["evidence_type"] = (
                value["admin_separation_evidence"][0]["evidence_type"]
            )

        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(mutate=mutate)

    def test_missing_required_evidence_class_is_rejected(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.__setitem__(
                    "admin_separation_evidence",
                    value["admin_separation_evidence"][:2],
                )
            )

    def test_self_hosted_runner_denial_is_required(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.__setitem__(
                    "self_hosted_runner_denied", False
                )
            )

    def test_receipt_contract_must_match_1471(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.__setitem__(
                    "receipt_contract_stage", "other-stage"
                )
            )

    def test_raw_runtime_payload_key_is_rejected(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.__setitem__(
                    "stdout", "runtime output"
                )
            )

    def test_self_promotion_field_is_rejected_as_unknown(self):
        with self.assertRaises(admission.ExternalAdminAdmissionError):
            self._run(
                mutate=lambda value: value.__setitem__(
                    "independent_admin_boundary_verified", True
                )
            )

    def test_descriptor_inside_repository_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo_root = root / "repo"
            repo_root.mkdir()
            path = repo_root / "boundary.json"
            path.write_bytes(_json_bytes(_descriptor()))
            with self.assertRaises(admission.ExternalAdminAdmissionError):
                admission.evaluate_descriptor(
                    repo_root=repo_root,
                    descriptor_path=path,
                )


if __name__ == "__main__":
    unittest.main()
