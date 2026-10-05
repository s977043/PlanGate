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

import datetime as dt
import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_receipt as ext  # noqa: E402
import runtime_evidence_independent_attestation_verifier as command  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
CANDIDATE_RECEIPT = "sha256:" + "c" * 64
MANIFEST = "sha256:" + "d" * 64
MANIFEST_FILE = "sha256:" + "e" * 64
VERIFIER_BINARY = "sha256:" + "f" * 64
SOURCE = "0123456789abcdef0123456789abcdef01234567"
SIGNER = "89abcdef0123456789abcdef0123456789abcdef"
ATTESTATION_REPO = "s977043/plangate"
SIGNER_REPO = "trusted/runtime-verifier"
WORKFLOW = SIGNER_REPO + "/.github/workflows/verify-runtime-attestation.yml"
NONCE = "nonce-0123456789abcdef"
NOW = dt.datetime(2026, 10, 4, 12, 0, 0, tzinfo=dt.timezone.utc)


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _sha(raw):
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _authority():
    return {
        "agent_invoke_allowed": False,
        "code_write_allowed": False,
        "approval_write_allowed": False,
        "merge_allowed": False,
        "deploy_allowed": False,
    }


def _candidate():
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
        "authority": _authority(),
    }
    value["result_hash"] = ingress._canonical_hash(value)
    return value


def _receipt(candidate, candidate_raw):
    return {
        "schema_version": "1",
        "domain": ext.RECEIPT_DOMAIN,
        "contract_stage": ext.RECEIPT_STAGE,
        "request_hash": candidate["request_hash"],
        "config_sha": candidate["config_sha"],
        "provider": candidate["provider"],
        "platform": candidate["platform"],
        "capture_id": candidate["capture_id"],
        "command_candidate_result_hash": candidate["result_hash"],
        "command_candidate_file_sha256": _sha(candidate_raw),
        "capture_manifest_hash": candidate["capture_manifest_hash"],
        "capture_manifest_file_sha256": candidate["capture_manifest_file_sha256"],
        "attestation_repo": candidate["attestation_repo"],
        "signer_repo": candidate["signer_repo"],
        "signer_workflow": candidate["signer_workflow"],
        "source_digest": candidate["source_digest"],
        "signer_digest": candidate["signer_digest"],
        "source_ref": candidate["source_ref"],
        "verifier_id": "external-r1-verifier",
        "verifier_version": "1.0.0",
        "verifier_binary_sha256": VERIFIER_BINARY,
        "verification_nonce": NONCE,
        "issued_at": "2026-10-04T11:59:00Z",
        "expires_at": "2026-10-04T12:10:00Z",
        "claimed_gh_attestation_cli_execution_verified": True,
        "claimed_artifact_digest_cryptographically_verified": True,
        "claimed_attestation_signature_cryptographically_verified": True,
        "claimed_signer_certificate_identity_verified": True,
        "claimed_verified_timestamp_cryptographically_verified": True,
        "claimed_signer_workflow_policy_verified": True,
        "claimed_source_digest_policy_verified": True,
        "claimed_self_hosted_runner_denial_verified": True,
        "claimed_independent_admin_boundary_verified": True,
        "claimed_independent_verifier_execution_attested": True,
        "claimed_runtime_probe_attestation_verified": True,
        "claimed_hard_read_only_enforced": True,
    }


def _gh_output(receipt_raw):
    digest = hashlib.sha256(receipt_raw).hexdigest()
    return [{
        "attestation": {"bundle": "opaque"},
        "verificationResult": {
            "statement": {
                "subject": [{
                    "name": "external-verifier-receipt.json",
                    "digest": {"sha256": digest},
                }],
                "predicateType": "https://slsa.dev/provenance/v1",
                "predicate": {"UNTRUSTED": "never promoted"},
            }
        },
    }]


class _Completed:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class ExternalVerifierReceiptTests(unittest.TestCase):
    def _run(self, *, mutate_candidate=None, mutate_receipt=None, mutate_output=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo_root = root / "repo"
            external = root / "external"
            repo_root.mkdir()
            external.mkdir()

            candidate = _candidate()
            if mutate_candidate is not None:
                mutate_candidate(candidate)
                body = dict(candidate)
                body.pop("result_hash", None)
                candidate["result_hash"] = ingress._canonical_hash(body)
            candidate_raw = _json_bytes(candidate)
            candidate_path = external / "command-candidate.json"
            candidate_path.write_bytes(candidate_raw)

            receipt = _receipt(candidate, candidate_raw)
            if mutate_receipt is not None:
                mutate_receipt(receipt)
            receipt_raw = _json_bytes(receipt)
            receipt_path = external / "external-verifier-receipt.json"
            receipt_path.write_bytes(receipt_raw)

            output = _gh_output(receipt_raw)
            if mutate_output is not None:
                mutate_output(output)

            calls = []

            def fake_runner(args, *, repo, cwd=None):
                calls.append((list(args), repo, cwd))
                return _Completed(
                    0,
                    json.dumps(output, separators=(",", ":")) + "\n",
                    "",
                )

            original = ext.gh_exec.run_gh
            ext.gh_exec.run_gh = fake_runner
            try:
                result = ext.verify_external_receipt(
                    repo_root=repo_root,
                    command_candidate_path=candidate_path,
                    external_receipt_path=receipt_path,
                    expected_nonce=NONCE,
                    cwd=repo_root,
                    now=NOW,
                )
            finally:
                ext.gh_exec.run_gh = original
            return result, calls

    def test_valid_receipt_stays_candidate_only(self):
        result, calls = self._run()
        self.assertEqual(len(calls), 1)
        args, repo, _cwd = calls[0]
        self.assertEqual(repo, ATTESTATION_REPO)
        self.assertEqual(args[:2], ["attestation", "verify"])
        self.assertIn("--deny-self-hosted-runners", args)
        self.assertEqual(args[args.index("--signer-workflow") + 1], WORKFLOW)
        self.assertEqual(args[args.index("--source-digest") + 1], SOURCE)
        self.assertEqual(args[args.index("--signer-digest") + 1], SIGNER)

        for field in (
            "receipt_structure_verified",
            "receipt_candidate_binding_verified",
            "receipt_content_addressed",
            "receipt_nonce_binding_verified",
            "receipt_freshness_verified",
            "receipt_artifact_digest_binding_candidate",
            "receipt_attestation_verify_exit_success_candidate",
        ):
            self.assertTrue(result[field])

        for field in (
            "receipt_claims_authenticated",
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

    def test_wrong_nonce_is_rejected_before_gh(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "verification_nonce", "nonce-fedcba9876543210"
                )
            )

    def test_stale_receipt_is_rejected(self):
        def mutate(value):
            value["issued_at"] = "2026-10-04T11:00:00Z"
            value["expires_at"] = "2026-10-04T11:10:00Z"

        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(mutate_receipt=mutate)

    def test_overlong_validity_is_rejected(self):
        def mutate(value):
            value["expires_at"] = "2026-10-04T12:30:00Z"

        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(mutate_receipt=mutate)

    def test_wrong_request_binding_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "request_hash", "sha256:" + "9" * 64
                )
            )

    def test_wrong_candidate_file_digest_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "command_candidate_file_sha256", "sha256:" + "8" * 64
                )
            )

    def test_wrong_capture_manifest_file_digest_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "capture_manifest_file_sha256", "sha256:" + "7" * 64
                )
            )

    def test_wrong_signer_workflow_binding_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "signer_workflow",
                    "other/repo/.github/workflows/verify.yml",
                )
            )

    def test_wrong_source_digest_binding_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "source_digest", "1" * 40
                )
            )

    def test_wrong_signer_digest_binding_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "signer_digest", "2" * 40
                )
            )

    def test_wrong_source_ref_binding_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "source_ref", "refs/heads/other"
                )
            )

    def test_candidate_self_promotion_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_candidate=lambda value: value.__setitem__(
                    "runtime_probe_attestation_verified", True
                )
            )

    def test_candidate_policy_tamper_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_candidate=lambda value: value.__setitem__(
                    "signer_workflow",
                    "other/repo/.github/workflows/verify.yml",
                )
            )

    def test_receipt_artifact_digest_mismatch_is_rejected(self):
        def mutate(output):
            output[0]["verificationResult"]["statement"]["subject"][0]["digest"][
                "sha256"
            ] = "0" * 64

        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(mutate_output=mutate)

    def test_raw_runtime_payload_key_is_rejected(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            self._run(
                mutate_receipt=lambda value: value.__setitem__(
                    "stdout", "untrusted runtime output"
                )
            )

    def test_nonce_environment_is_required(self):
        with self.assertRaises(ext.ExternalVerifierReceiptError):
            ext.load_expected_nonce({})
        self.assertEqual(
            ext.load_expected_nonce({ext.NONCE_ENV: NONCE}),
            NONCE,
        )


if __name__ == "__main__":
    unittest.main()
