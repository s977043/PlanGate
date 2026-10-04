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

import copy
import json
import pathlib
import tempfile
import unittest
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_receipt as verifier_receipt  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402

REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
CANDIDATE_RECEIPT = "sha256:" + "c" * 64
MANIFEST = "sha256:" + "d" * 64
MANIFEST_FILE = "sha256:" + "e" * 64
CHALLENGE = "sha256:" + "f" * 64
SOURCE = "0123456789abcdef0123456789abcdef01234567"
SIGNER = "89abcdef0123456789abcdef0123456789abcdef"
ATTESTATION_REPO = "s977043/PlanGate"
SIGNER_REPO = "trusted/runtime-verifier"
WORKFLOW = SIGNER_REPO + "/.github/workflows/verify-runtime-attestation.yml"


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _command_candidate():
    value = {
        "schema_version": "1",
        "domain": command.DOMAIN,
        "contract_stage": command.CONTRACT_STAGE,
        "request_hash": REQ,
        "config_sha": CONFIG,
        "provider": "cloudflare",
        "platform": "codex",
        "capture_id": "capture-1",
        "candidate_receipt_hash": CANDIDATE_RECEIPT,
        "capture_manifest_hash": MANIFEST,
        "capture_manifest_file_sha256": MANIFEST_FILE,
        "attestation_repo": ATTESTATION_REPO,
        "signer_repo": SIGNER_REPO,
        "signer_workflow": WORKFLOW,
        "source_digest": SOURCE,
        "signer_digest": SIGNER,
        "source_ref": "refs/heads/main",
        "oidc_issuer": command.OIDC_ISSUER,
        "predicate_type": "https://slsa.dev/provenance/v1",
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


def _receipt(command_candidate=None):
    candidate = command_candidate or _command_candidate()
    claims = {field: True for field in verifier_receipt.EXTERNAL_CLAIM_KEYS}
    value = {
        "schema_version": "1",
        "domain": verifier_receipt.EXTERNAL_RECEIPT_DOMAIN,
        "receipt_id": "receipt-1",
        "request_hash": candidate["request_hash"],
        "config_sha": candidate["config_sha"],
        "provider": candidate["provider"],
        "platform": candidate["platform"],
        "capture_id": candidate["capture_id"],
        "command_candidate_hash": candidate["result_hash"],
        "capture_manifest_file_sha256": candidate["capture_manifest_file_sha256"],
        "attestation_repo": candidate["attestation_repo"],
        "signer_repo": candidate["signer_repo"],
        "signer_workflow": candidate["signer_workflow"],
        "source_digest": candidate["source_digest"],
        "signer_digest": candidate["signer_digest"],
        "source_ref": candidate["source_ref"],
        "challenge_hash": CHALLENGE,
        "issued_at": "2026-10-04T12:00:00Z",
        "expires_at": "2026-10-04T12:10:00Z",
        "claims": claims,
    }
    value["receipt_hash"] = ingress._canonical_hash(value)
    return value


def _rehash(value, field="receipt_hash"):
    body = dict(value)
    body.pop(field, None)
    value[field] = ingress._canonical_hash(body)
    return value


def _verify(candidate=None, receipt=None, **kwargs):
    candidate = candidate or _command_candidate()
    receipt = receipt or _receipt(candidate)
    return verifier_receipt.verify_candidate_bytes(
        command_candidate_raw=_json_bytes(candidate),
        external_receipt_raw=_json_bytes(receipt),
        expected_challenge_hash=kwargs.get("expected_challenge_hash", CHALLENGE),
        observed_at=kwargs.get("observed_at", "2026-10-04T12:05:00Z"),
        consumed_receipt_hashes=kwargs.get("consumed_receipt_hashes", ()),
    )


class ExternalVerifierReceiptTests(unittest.TestCase):
    def test_valid_receipt_stays_candidate_only(self):
        result = _verify()
        for field in (
            "exact_command_candidate_binding_verified_candidate",
            "external_receipt_self_hash_verified_candidate",
            "external_claim_set_complete_candidate",
            "challenge_binding_verified_candidate",
            "freshness_window_verified_candidate",
            "replay_absence_verified_candidate",
        ):
            self.assertTrue(result[field])
        for field in (
            "external_receipt_signature_verified",
            "external_receipt_origin_verified",
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
        ):
            self.assertFalse(result[field])
        self.assertFalse(any(result["authority"].values()))

    def test_wrong_request_binding_is_rejected(self):
        receipt = _receipt()
        receipt["request_hash"] = "sha256:" + "1" * 64
        _rehash(receipt)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(receipt=receipt)

    def test_wrong_config_binding_is_rejected(self):
        receipt = _receipt()
        receipt["config_sha"] = "sha256:" + "2" * 64
        _rehash(receipt)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(receipt=receipt)

    def test_wrong_provider_binding_is_rejected(self):
        receipt = _receipt()
        receipt["provider"] = "other-provider"
        _rehash(receipt)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(receipt=receipt)

    def test_wrong_command_hash_is_rejected(self):
        receipt = _receipt()
        receipt["command_candidate_hash"] = "sha256:" + "3" * 64
        _rehash(receipt)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(receipt=receipt)

    def test_wrong_challenge_is_rejected(self):
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(expected_challenge_hash="sha256:" + "4" * 64)

    def test_expired_receipt_is_rejected(self):
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(observed_at="2026-10-04T12:10:00Z")

    def test_future_receipt_is_rejected(self):
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(observed_at="2026-10-04T11:59:59Z")

    def test_overlong_ttl_is_rejected(self):
        receipt = _receipt()
        receipt["expires_at"] = "2026-10-04T12:20:00Z"
        _rehash(receipt)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(receipt=receipt)

    def test_replayed_receipt_hash_is_rejected(self):
        receipt = _receipt()
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(
                receipt=receipt,
                consumed_receipt_hashes=(receipt["receipt_hash"],),
            )

    def test_invalid_consumed_hash_is_rejected(self):
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(consumed_receipt_hashes=("not-a-hash",))

    def test_false_external_claim_is_rejected(self):
        receipt = _receipt()
        receipt["claims"] = copy.deepcopy(receipt["claims"])
        receipt["claims"]["independent_admin_boundary_verified"] = False
        _rehash(receipt)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(receipt=receipt)

    def test_unknown_receipt_key_is_rejected_even_when_rehashed(self):
        receipt = _receipt()
        receipt["future_authority"] = True
        _rehash(receipt)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(receipt=receipt)

    def test_promoted_repository_command_candidate_is_rejected(self):
        candidate = _command_candidate()
        candidate["gh_attestation_cli_execution_verified"] = True
        _rehash(candidate, "result_hash")
        receipt = _receipt(candidate)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(candidate=candidate, receipt=receipt)

    def test_command_candidate_unknown_key_is_rejected(self):
        candidate = _command_candidate()
        candidate["future_authority"] = True
        _rehash(candidate, "result_hash")
        receipt = _receipt(candidate)
        with self.assertRaises(verifier_receipt.ExternalVerifierReceiptError):
            _verify(candidate=candidate, receipt=receipt)

    def test_repo_local_receipt_file_is_rejected_by_cli_loader_boundary(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = pathlib.Path(tmp) / "repo"
            repo_root.mkdir()
            path = repo_root / "receipt.json"
            path.write_bytes(_json_bytes(_receipt()))
            with self.assertRaises(Exception):
                verifier_receipt.fileio.load_raw_bytes(
                    path,
                    repo_root=repo_root,
                    field="external_receipt",
                    max_bytes=verifier_receipt.MAX_JSON_BYTES,
                )


if __name__ == "__main__":
    unittest.main()
