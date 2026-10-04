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

import runtime_evidence_github_attestation_receipt as attestation_receipt  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command_verifier  # noqa: E402
import runtime_evidence_independent_verifier_receipt as receipt_verifier  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402

REQUEST = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
CANDIDATE_RECEIPT = "sha256:" + "c" * 64
MANIFEST_HASH = "sha256:" + "d" * 64
MANIFEST_FILE = "sha256:" + "e" * 64
VERIFIER_BINARY = "sha256:" + "f" * 64
CHALLENGE = "sha256:" + "1" * 64
OTHER_CHALLENGE = "sha256:" + "2" * 64
SOURCE = "0123456789abcdef0123456789abcdef01234567"
SIGNER = "89abcdef0123456789abcdef0123456789abcdef"
ATTESTATION_REPO = "s977043/PlanGate"
SIGNER_REPO = "trusted/runtime-verifier"
SIGNER_WORKFLOW = SIGNER_REPO + "/.github/workflows/sign-runtime-attestation.yml"
SOURCE_REF = "refs/heads/main"
VERIFIER_ISSUER = "trusted.example/verifier"
VERIFIER_WORKFLOW_REF = (
    "trusted/runtime-verifier/.github/workflows/verify-runtime-attestation.yml@"
    "fedcba9876543210fedcba9876543210fedcba98"
)


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _command_result():
    value = {
        "schema_version": "1",
        "domain": command_verifier.DOMAIN,
        "contract_stage": command_verifier.CONTRACT_STAGE,
        "request_hash": REQUEST,
        "config_sha": CONFIG,
        "provider": "cloudflare",
        "platform": "codex",
        "capture_id": "capture-1",
        "candidate_receipt_hash": CANDIDATE_RECEIPT,
        "capture_manifest_hash": MANIFEST_HASH,
        "capture_manifest_file_sha256": MANIFEST_FILE,
        "attestation_repo": ATTESTATION_REPO,
        "signer_repo": SIGNER_REPO,
        "signer_workflow": SIGNER_WORKFLOW,
        "source_digest": SOURCE,
        "signer_digest": SIGNER,
        "source_ref": SOURCE_REF,
        "oidc_issuer": command_verifier.OIDC_ISSUER,
        "predicate_type": attestation_receipt.EXPECTED_PREDICATE_TYPE,
        "exact_verifier_policy_bound_candidate": True,
        "gh_attestation_verify_exit_success_candidate": True,
        "capture_manifest_artifact_binding_candidate": True,
        "signer_workflow_policy_requested_candidate": True,
        "source_digest_policy_requested_candidate": True,
        "signer_digest_policy_requested_candidate": True,
        "self_hosted_runner_denial_requested_candidate": True,
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
        "verification_limit": "candidate only",
        "authority": {
            "agent_invoke_allowed": False,
            "code_write_allowed": False,
            "approval_write_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }
    value["result_hash"] = ingress._canonical_hash(value)
    return value


def _receipt(command=None):
    command = command or _command_result()
    value = {
        "schema_version": "1",
        "domain": receipt_verifier.DOMAIN,
        "contract_stage": receipt_verifier.CONTRACT_STAGE,
        "receipt_id": "receipt-1",
        "challenge_id": CHALLENGE,
        "request_hash": command["request_hash"],
        "config_sha": command["config_sha"],
        "provider": command["provider"],
        "platform": command["platform"],
        "capture_id": command["capture_id"],
        "verification_command_candidate_result_hash": command["result_hash"],
        "capture_manifest_file_sha256": command["capture_manifest_file_sha256"],
        "attestation_repo": command["attestation_repo"],
        "signer_repo": command["signer_repo"],
        "signer_workflow": command["signer_workflow"],
        "source_digest": command["source_digest"],
        "signer_digest": command["signer_digest"],
        "source_ref": command["source_ref"],
        "verifier_issuer": VERIFIER_ISSUER,
        "verifier_workflow_ref": VERIFIER_WORKFLOW_REF,
        "verifier_binary_sha256": VERIFIER_BINARY,
        "execution_id": "exec-1",
        "issued_at": "2026-10-04T15:00:00Z",
        "expires_at": "2026-10-04T15:10:00Z",
    }
    value["receipt_hash"] = ingress._canonical_hash(value)
    return value


def _rehash(value):
    value = dict(value)
    value.pop("receipt_hash", None)
    value["receipt_hash"] = ingress._canonical_hash(value)
    return value


def _rehash_command(value):
    value = dict(value)
    value.pop("result_hash", None)
    value["result_hash"] = ingress._canonical_hash(value)
    return value


def _verify(command=None, receipt=None, **overrides):
    command = command or _command_result()
    receipt = receipt or _receipt(command)
    kwargs = {
        "verification_command_candidate_raw": _json_bytes(command),
        "verifier_receipt_raw": _json_bytes(receipt),
        "expected_challenge_id": CHALLENGE,
        "expected_verifier_issuer": VERIFIER_ISSUER,
        "expected_verifier_workflow_ref": VERIFIER_WORKFLOW_REF,
        "expected_verifier_binary_sha256": VERIFIER_BINARY,
        "observed_at": "2026-10-04T15:05:00Z",
    }
    kwargs.update(overrides)
    return receipt_verifier.verify_receipt_bytes(**kwargs)


class IndependentVerifierReceiptTests(unittest.TestCase):
    def test_valid_receipt_stays_candidate_only(self):
        result = _verify()
        for field in (
            "external_receipt_structure_candidate",
            "external_receipt_content_addressed_candidate",
            "external_receipt_exact_binding_candidate",
            "immutable_verifier_identity_binding_candidate",
            "freshness_window_candidate",
            "run_challenge_binding_candidate",
            "cross_run_replay_binding_candidate",
        ):
            self.assertTrue(result[field])

        self.assertEqual(result["verifier_receipt_hash"], _receipt()["receipt_hash"])
        self.assertEqual(result["attestation_repo"], ATTESTATION_REPO)
        self.assertEqual(result["signer_repo"], SIGNER_REPO)
        self.assertEqual(result["signer_workflow"], SIGNER_WORKFLOW)
        self.assertEqual(result["source_digest"], SOURCE)
        self.assertEqual(result["signer_digest"], SIGNER)
        self.assertEqual(result["observed_at"], "2026-10-04T15:05:00Z")
        self.assertFalse(result["same_challenge_replay_prevented"])
        self.assertFalse(result["receipt_signature_verified"])
        for field in (
            "gh_attestation_cli_execution_verified",
            "artifact_digest_cryptographically_verified",
            "attestation_signature_cryptographically_verified",
            "independent_admin_boundary_verified",
            "independent_verifier_execution_attested",
            "runtime_probe_attestation_verified",
            "human_rollout_decision_verified",
            "dispatch_ready",
            "dispatch_allowed",
        ):
            self.assertFalse(result[field])
        self.assertFalse(any(result["authority"].values()))

    def test_command_candidate_wrong_oidc_or_predicate_fails_closed(self):
        for field, value in (
            ("oidc_issuer", "https://evil.example"),
            ("predicate_type", "https://example.invalid/predicate"),
        ):
            command = _command_result()
            command[field] = value
            command = _rehash_command(command)
            receipt = _receipt(command)
            with self.subTest(field=field):
                with self.assertRaises(
                    receipt_verifier.IndependentVerifierReceiptError
                ):
                    _verify(command=command, receipt=receipt)

    def test_wrong_request_binding_fails_closed(self):
        receipt = _receipt()
        receipt["request_hash"] = "sha256:" + "9" * 64
        with self.assertRaises(receipt_verifier.IndependentVerifierReceiptError):
            _verify(receipt=_rehash(receipt))

    def test_wrong_config_and_provider_fail_closed(self):
        for field, value in (
            ("config_sha", "sha256:" + "8" * 64),
            ("provider", "other-provider"),
        ):
            receipt = _receipt()
            receipt[field] = value
            with self.subTest(field=field):
                with self.assertRaises(
                    receipt_verifier.IndependentVerifierReceiptError
                ):
                    _verify(receipt=_rehash(receipt))

    def test_cross_run_replay_challenge_fails_closed(self):
        with self.assertRaises(receipt_verifier.IndependentVerifierReceiptError):
            _verify(expected_challenge_id=OTHER_CHALLENGE)

    def test_stale_receipt_fails_closed(self):
        with self.assertRaises(receipt_verifier.IndependentVerifierReceiptError):
            _verify(observed_at="2026-10-04T15:10:00Z")

    def test_overlong_validity_window_fails_closed(self):
        receipt = _receipt()
        receipt["expires_at"] = "2026-10-04T15:20:00Z"
        with self.assertRaises(receipt_verifier.IndependentVerifierReceiptError):
            _verify(receipt=_rehash(receipt))

    def test_wrong_immutable_verifier_identity_fails_closed(self):
        with self.assertRaises(receipt_verifier.IndependentVerifierReceiptError):
            _verify(
                expected_verifier_workflow_ref=(
                    "trusted/runtime-verifier/.github/workflows/"
                    "verify-runtime-attestation.yml@"
                    "0000000000000000000000000000000000000000"
                )
            )

    def test_tampered_receipt_hash_fails_closed(self):
        receipt = _receipt()
        receipt["receipt_id"] = "tampered"
        with self.assertRaises(receipt_verifier.IndependentVerifierReceiptError):
            _verify(receipt=receipt)

    def test_repo_local_receipt_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo_root = root / "repo"
            repo_root.mkdir()
            command_path = root / "command.json"
            receipt_path = repo_root / "receipt.json"
            command_path.write_bytes(_json_bytes(_command_result()))
            receipt_path.write_bytes(_json_bytes(_receipt()))
            rc = receipt_verifier.main([
                "--repo-root", str(repo_root),
                "--verification-command-candidate", str(command_path),
                "--verifier-receipt", str(receipt_path),
                "--expected-challenge-id", CHALLENGE,
                "--expected-verifier-issuer", VERIFIER_ISSUER,
                "--expected-verifier-workflow-ref", VERIFIER_WORKFLOW_REF,
                "--expected-verifier-binary-sha256", VERIFIER_BINARY,
                "--observed-at", "2026-10-04T15:05:00Z",
            ])
            self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
