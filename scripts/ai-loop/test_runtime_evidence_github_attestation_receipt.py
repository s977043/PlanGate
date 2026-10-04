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
import hashlib
import json
import pathlib
import tempfile
import unittest
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import runtime_evidence_codex_managed_capture_manifest as managed  # noqa: E402
import runtime_evidence_github_attestation_receipt as receipt  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402

REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
HOOK = "sha256:" + "c" * 64
EXEC = "sha256:" + "d" * 64
CORR = "sha256:" + "e" * 64
POLICY = "sha256:" + "f" * 64
RECORDER = "sha256:" + "1" * 64


def _manifest():
    value = {
        "schema_version": "1",
        "domain": managed.MANIFEST_DOMAIN,
        "contract_stage": managed.MANIFEST_STAGE,
        "capture_id": "capture-1",
        "request_hash": REQ,
        "config_sha": CONFIG,
        "provider": "cloudflare",
        "platform": "codex",
        "managed_hook_source": "requirements.toml",
        "allow_managed_hooks_only_claimed": True,
        "hooks_feature_pinned_claimed": True,
        "managed_policy_sha256": POLICY,
        "managed_recorder_sha256": RECORDER,
        "hook_jsonl_sha256": HOOK,
        "exec_jsonl_sha256": EXEC,
        "correlation_result_hash": CORR,
        "hook_session_id": "sess-1",
        "exec_thread_id": "sess-1",
    }
    value["manifest_hash"] = ingress._canonical_hash(value)
    return value


def _managed_result(manifest=None):
    manifest = manifest or _manifest()
    value = {
        "schema_version": "1",
        "domain": managed.DOMAIN,
        "contract_stage": managed.CONTRACT_STAGE,
        "request_hash": REQ,
        "config_sha": CONFIG,
        "provider": "cloudflare",
        "platform": "codex",
        "capture_id": "capture-1",
        "managed_hook_source_claim": "requirements.toml",
        "managed_policy_sha256": POLICY,
        "managed_recorder_sha256": RECORDER,
        "hook_jsonl_sha256": HOOK,
        "exec_jsonl_sha256": EXEC,
        "correlation_result_hash": CORR,
        "capture_manifest_hash": manifest["manifest_hash"],
        "capture_manifest_structure_verified": True,
        "capture_manifest_self_hash_verified": True,
        "capture_manifest_cross_binding_verified": True,
        "managed_hooks_only_claim_candidate": True,
        "hooks_feature_pinned_claim_candidate": True,
        "same_run_binding_manifest_candidate": True,
        "managed_hook_source_runtime_verified": False,
        "managed_policy_live_verified": False,
        "managed_policy_content_binding_verified": False,
        "managed_recorder_binary_verified": False,
        "managed_recorder_content_binding_verified": False,
        "manifest_signature_verified": False,
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


def _manifest_bytes(manifest=None):
    manifest = manifest or _manifest()
    return (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _file_sha(raw):
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _gh_output(file_sha):
    return [{
        "attestation": {"bundle": "opaque-untrusted-bundle"},
        "verificationResult": {
            "signature": {
                "certificate": {
                    "sourceRepository": "s977043/PlanGate",
                    "subjectAlternativeName": "https://github.com/example/verifier/.github/workflows/verify.yml@refs/heads/main",
                }
            },
            "verifiedTimestamps": [{"type": "rekor", "time": "2026-10-04T00:00:00Z"}],
            "statement": {
                "subject": [{
                    "name": "capture-manifest.json",
                    "digest": {"sha256": file_sha.removeprefix("sha256:")},
                }],
                "predicateType": receipt.EXPECTED_PREDICATE_TYPE,
                "predicate": {"UNTRUSTED": "must never flow to result"},
            },
        },
    }]


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _verify(*, managed_capture_result, capture_manifest, gh_attestation_output,
            capture_manifest_file_sha256=None, gh_attestation_output_sha256=None):
    manifest_raw = _json_bytes(capture_manifest)
    gh_raw = _json_bytes(gh_attestation_output)
    if capture_manifest_file_sha256 is not None:
        expected = _file_sha(manifest_raw)
        if capture_manifest_file_sha256 != expected:
            # Exercise the internal mismatch path explicitly when requested.
            return receipt._verify_candidate(
                managed_capture_result=managed_capture_result,
                capture_manifest=capture_manifest,
                capture_manifest_file_sha256=capture_manifest_file_sha256,
                gh_attestation_output=gh_attestation_output,
                gh_attestation_output_sha256=(
                    gh_attestation_output_sha256 or _file_sha(gh_raw)
                ),
            )
    return receipt.verify_candidate_bytes(
        managed_capture_result_raw=_json_bytes(managed_capture_result),
        capture_manifest_raw=manifest_raw,
        gh_attestation_output_raw=gh_raw,
    )


class ReceiptTests(unittest.TestCase):
    def test_valid_receipt_remains_candidate_only(self):
        manifest = _manifest()
        file_sha = _file_sha(_manifest_bytes(manifest))
        result = _verify(
            managed_capture_result=_managed_result(manifest),
            capture_manifest=manifest,
            capture_manifest_file_sha256=file_sha,
            gh_attestation_output=_gh_output(file_sha),
            gh_attestation_output_sha256="sha256:" + "2" * 64,
        )
        self.assertTrue(result["github_attestation_output_structure_verified"])
        self.assertTrue(result["artifact_subject_digest_match_candidate"])
        self.assertTrue(result["signature_certificate_present_candidate"])
        self.assertTrue(result["verified_timestamp_present_candidate"])
        for field in (
            "statement_predicate_trusted",
            "gh_attestation_cli_execution_verified",
            "artifact_digest_cryptographically_verified",
            "attestation_signature_cryptographically_verified",
            "signer_certificate_identity_verified",
            "verified_timestamp_cryptographically_verified",
            "signer_workflow_policy_verified",
            "source_digest_policy_verified",
            "self_hosted_runner_denial_verified",
            "independent_admin_boundary_verified",
            "independent_verifier_execution_attested",
            "manifest_signature_verified",
            "managed_hook_root_attested",
            "same_run_identity_verified",
            "runtime_probe_attestation_verified",
            "human_rollout_decision_verified",
            "dispatch_ready",
            "dispatch_allowed",
        ):
            self.assertFalse(result[field])
        self.assertNotIn("UNTRUSTED", json.dumps(result))
        self.assertFalse(any(result["authority"].values()))

    def test_subject_digest_mismatch_is_rejected(self):
        manifest = _manifest()
        file_sha = _file_sha(_manifest_bytes(manifest))
        output = _gh_output("sha256:" + "9" * 64)
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=_managed_result(manifest),
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=output,
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_multiple_attestations_are_rejected(self):
        manifest = _manifest()
        file_sha = _file_sha(_manifest_bytes(manifest))
        output = _gh_output(file_sha) * 2
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=_managed_result(manifest),
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=output,
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_empty_verified_timestamps_are_rejected(self):
        manifest = _manifest()
        file_sha = _file_sha(_manifest_bytes(manifest))
        output = _gh_output(file_sha)
        output[0]["verificationResult"]["verifiedTimestamps"] = []
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=_managed_result(manifest),
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=output,
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_missing_certificate_is_rejected(self):
        manifest = _manifest()
        file_sha = _file_sha(_manifest_bytes(manifest))
        output = _gh_output(file_sha)
        output[0]["verificationResult"]["signature"]["certificate"] = {}
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=_managed_result(manifest),
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=output,
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_wrong_predicate_type_is_rejected(self):
        manifest = _manifest()
        file_sha = _file_sha(_manifest_bytes(manifest))
        output = _gh_output(file_sha)
        output[0]["verificationResult"]["statement"]["predicateType"] = "other"
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=_managed_result(manifest),
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=output,
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_promoted_managed_result_is_rejected(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        managed_result["managed_hook_root_attested"] = True
        body = dict(managed_result)
        body.pop("result_hash")
        managed_result["result_hash"] = ingress._canonical_hash(body)
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_upstream_provider_format_drift_is_rejected(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        managed_result["provider"] = "Bad/Provider"
        body = dict(managed_result)
        body.pop("result_hash")
        managed_result["result_hash"] = ingress._canonical_hash(body)
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_upstream_managed_source_drift_is_rejected(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        managed_result["managed_hook_source_claim"] = "project"
        body = dict(managed_result)
        body.pop("result_hash")
        managed_result["result_hash"] = ingress._canonical_hash(body)
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_unknown_managed_result_field_is_rejected(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        managed_result["future_authority"] = True
        body = dict(managed_result)
        body.pop("result_hash")
        managed_result["result_hash"] = ingress._canonical_hash(body)
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_missing_upstream_authority_key_is_rejected(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        managed_result["authority"] = copy.deepcopy(managed_result["authority"])
        managed_result["authority"].pop("deploy_allowed")
        body = dict(managed_result)
        body.pop("result_hash")
        managed_result["result_hash"] = ingress._canonical_hash(body)
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_nonzero_upstream_authority_is_rejected(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        managed_result["authority"] = copy.deepcopy(managed_result["authority"])
        managed_result["authority"]["agent_invoke_allowed"] = True
        body = dict(managed_result)
        body.pop("result_hash")
        managed_result["result_hash"] = ingress._canonical_hash(body)
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_manifest_schema_drift_is_rejected_even_when_rehashed(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        manifest["future_claim"] = "unexpected"
        body = dict(manifest)
        body.pop("manifest_hash")
        manifest["manifest_hash"] = ingress._canonical_hash(body)
        managed_result["capture_manifest_hash"] = manifest["manifest_hash"]
        managed_body = dict(managed_result)
        managed_body.pop("result_hash")
        managed_result["result_hash"] = ingress._canonical_hash(managed_body)
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_multiple_statement_subjects_are_rejected(self):
        manifest = _manifest()
        file_sha = _file_sha(_manifest_bytes(manifest))
        output = _gh_output(file_sha)
        output[0]["verificationResult"]["statement"]["subject"].append(
            copy.deepcopy(output[0]["verificationResult"]["statement"]["subject"][0])
        )
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=_managed_result(manifest),
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=output,
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )

    def test_manifest_hash_mismatch_is_rejected(self):
        manifest = _manifest()
        managed_result = _managed_result(manifest)
        manifest["manifest_hash"] = "sha256:" + "9" * 64
        file_sha = _file_sha(_manifest_bytes(manifest))
        with self.assertRaises(receipt.GitHubAttestationReceiptError):
            _verify(
                managed_capture_result=managed_result,
                capture_manifest=manifest,
                capture_manifest_file_sha256=file_sha,
                gh_attestation_output=_gh_output(file_sha),
                gh_attestation_output_sha256="sha256:" + "2" * 64,
            )


class LoaderTests(unittest.TestCase):
    def test_loader_hashes_exact_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "value.json"
            raw = b'{"x":1}\n'
            path.write_bytes(raw)
            value, digest = receipt.load_json_value(
                path, repo_root=repo, field="fixture"
            )
        self.assertEqual(value, {"x": 1})
        self.assertEqual(digest, _file_sha(raw))

    def test_duplicate_key_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "value.json"
            path.write_text('{"x":1,"x":2}\n', encoding="utf-8")
            with self.assertRaises(receipt.GitHubAttestationReceiptError):
                receipt.load_json_value(path, repo_root=repo, field="fixture")

    def test_repo_local_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = repo / "value.json"
            path.write_text("{}\n", encoding="utf-8")
            with self.assertRaises(receipt.GitHubAttestationReceiptError):
                receipt.load_json_value(path, repo_root=repo, field="fixture")

    def test_invalid_utf8_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "value.json"
            path.write_bytes(b"\xff")
            with self.assertRaises(receipt.GitHubAttestationReceiptError):
                receipt.load_json_value(path, repo_root=repo, field="fixture")

    def test_size_limit_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "value.json"
            path.write_bytes(b"x" * (receipt.MAX_JSON_BYTES + 1))
            with self.assertRaises(receipt.GitHubAttestationReceiptError):
                receipt.load_json_value(path, repo_root=repo, field="fixture")


if __name__ == "__main__":
    unittest.main()
