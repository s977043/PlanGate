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
import runtime_evidence_independent_attestation_verifier as verifier  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402

REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
HOOK = "sha256:" + "c" * 64
EXEC = "sha256:" + "d" * 64
CORR = "sha256:" + "e" * 64
POLICY = "sha256:" + "f" * 64
RECORDER = "sha256:" + "1" * 64
SOURCE = "0123456789abcdef0123456789abcdef01234567"
SIGNER = "89abcdef0123456789abcdef0123456789abcdef"
ATTESTATION_REPO = "s977043/plangate"
SIGNER_REPO = "trusted/runtime-verifier"
WORKFLOW = SIGNER_REPO + "/.github/workflows/verify-runtime-attestation.yml"


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


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


def _managed_result(manifest):
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


def _gh_output(manifest_raw):
    digest = hashlib.sha256(manifest_raw).hexdigest()
    return [{
        "attestation": {"bundle": "opaque"},
        "verificationResult": {
            "signature": {
                "certificate": {
                    "sourceRepository": ATTESTATION_REPO,
                    "sourceRepositoryDigest": SOURCE,
                    "subjectAlternativeName": (
                        "https://github.com/" + WORKFLOW + "@refs/heads/main"
                    ),
                }
            },
            "verifiedTimestamps": [{"type": "rekor", "time": "2026-10-04T00:00:00Z"}],
            "statement": {
                "subject": [{
                    "name": "capture-manifest.json",
                    "digest": {"sha256": digest},
                }],
                "predicateType": receipt.EXPECTED_PREDICATE_TYPE,
                "predicate": {"UNTRUSTED": "must not flow into result"},
            },
        },
    }]


class _Completed:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class VerifierTests(unittest.TestCase):
    def _run(self, *, returncode=0, output_mutator=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo_root = root / "repo"
            repo_root.mkdir()
            manifest_path = root / "capture-manifest.json"
            manifest = _manifest()
            manifest_raw = _json_bytes(manifest)
            manifest_path.write_bytes(manifest_raw)
            managed_raw = _json_bytes(_managed_result(manifest))
            output = _gh_output(manifest_raw)
            if output_mutator is not None:
                output_mutator(output)
            calls = []

            def fake_runner(args, *, repo, cwd=None):
                calls.append((list(args), repo, cwd))
                return _Completed(
                    returncode=returncode,
                    stdout=json.dumps(output, separators=(",", ":")) + "\n",
                )

            original_runner = verifier.gh_exec.run_gh
            verifier.gh_exec.run_gh = fake_runner
            try:
                result = verifier.verify_with_github_attestation(
                    repo_root=repo_root,
                    managed_capture_result_raw=managed_raw,
                    capture_manifest_path=manifest_path,
                    attestation_repo=ATTESTATION_REPO,
                    signer_repo=SIGNER_REPO,
                    signer_workflow=WORKFLOW,
                    source_digest=SOURCE,
                    signer_digest=SIGNER,
                    source_ref="refs/heads/main",
                    cwd=repo_root,
                )
            finally:
                verifier.gh_exec.run_gh = original_runner
            return result, calls

    def test_repository_local_verification_stays_candidate_only(self):
        result, calls = self._run()
        self.assertEqual(len(calls), 1)
        args, repo, _cwd = calls[0]
        self.assertEqual(repo, ATTESTATION_REPO)
        self.assertIn("--deny-self-hosted-runners", args)
        self.assertNotIn("--no-public-good", args)
        self.assertEqual(args[args.index("--repo") + 1], ATTESTATION_REPO)
        self.assertEqual(args[args.index("--signer-repo") + 1], SIGNER_REPO)
        self.assertEqual(args[args.index("--signer-workflow") + 1], WORKFLOW)
        self.assertEqual(args[args.index("--source-digest") + 1], SOURCE)
        self.assertEqual(args[args.index("--signer-digest") + 1], SIGNER)
        self.assertNotEqual(SOURCE, SIGNER)

        for field in (
            "exact_verifier_policy_bound_candidate",
            "gh_attestation_verify_exit_success_candidate",
            "capture_manifest_artifact_binding_candidate",
            "signer_workflow_policy_requested_candidate",
            "source_digest_policy_requested_candidate",
            "signer_digest_policy_requested_candidate",
            "self_hosted_runner_denial_requested_candidate",
        ):
            self.assertTrue(result[field])

        for field in (
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
        self.assertNotIn("UNTRUSTED", json.dumps(result))

    def test_gh_failure_is_fail_closed(self):
        with self.assertRaises(verifier.IndependentAttestationVerifierError):
            self._run(returncode=1)

    def test_wrong_subject_digest_is_rejected(self):
        def mutate(output):
            output[0]["verificationResult"]["statement"]["subject"][0]["digest"]["sha256"] = (
                "9" * 64
            )
        with self.assertRaises(verifier.IndependentAttestationVerifierError):
            self._run(output_mutator=mutate)

    def test_policy_rejects_wrong_workflow_repo(self):
        with self.assertRaises(verifier.IndependentAttestationVerifierError):
            verifier.build_verify_args(
                artifact_path=pathlib.Path("/tmp/a.json"),
                attestation_repo=ATTESTATION_REPO,
                signer_repo=SIGNER_REPO,
                signer_workflow="other/repo/.github/workflows/verify.yml",
                source_digest=SOURCE,
                signer_digest=SIGNER,
                source_ref="refs/heads/main",
            )

    def test_policy_accepts_distinct_attestation_and_signer_repos(self):
        args = verifier.build_verify_args(
            artifact_path=pathlib.Path("/tmp/a.json"),
            attestation_repo=ATTESTATION_REPO,
            signer_repo=SIGNER_REPO,
            signer_workflow=WORKFLOW,
            source_digest=SOURCE,
            signer_digest=SIGNER,
            source_ref="refs/heads/main",
        )
        self.assertEqual(args[args.index("--repo") + 1], ATTESTATION_REPO)
        self.assertEqual(args[args.index("--signer-repo") + 1], SIGNER_REPO)
        self.assertEqual(args[args.index("--source-digest") + 1], SOURCE)
        self.assertEqual(args[args.index("--signer-digest") + 1], SIGNER)

    def test_policy_rejects_noncanonical_source_ref(self):
        with self.assertRaises(verifier.IndependentAttestationVerifierError):
            verifier.build_verify_args(
                artifact_path=pathlib.Path("/tmp/a.json"),
                attestation_repo=ATTESTATION_REPO,
                signer_repo=SIGNER_REPO,
                signer_workflow=WORKFLOW,
                source_digest=SOURCE,
                signer_digest=SIGNER,
                source_ref="refs/heads/a/../main",
            )

    def test_repo_local_manifest_is_rejected_before_runner(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = pathlib.Path(tmp) / "repo"
            repo_root.mkdir()
            manifest_path = repo_root / "capture-manifest.json"
            manifest = _manifest()
            manifest_path.write_bytes(_json_bytes(manifest))
            calls = []

            def fake_runner(args, *, repo, cwd=None):
                calls.append(args)
                return _Completed()

            original_runner = verifier.gh_exec.run_gh
            verifier.gh_exec.run_gh = fake_runner
            try:
                with self.assertRaises(receipt.GitHubAttestationReceiptError):
                    verifier.verify_with_github_attestation(
                        repo_root=repo_root,
                        managed_capture_result_raw=_json_bytes(_managed_result(manifest)),
                        capture_manifest_path=manifest_path,
                        attestation_repo=ATTESTATION_REPO,
                        signer_repo=SIGNER_REPO,
                        signer_workflow=WORKFLOW,
                        source_digest=SOURCE,
                        signer_digest=SIGNER,
                        source_ref="refs/heads/main",
                    )
            finally:
                verifier.gh_exec.run_gh = original_runner
            self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
