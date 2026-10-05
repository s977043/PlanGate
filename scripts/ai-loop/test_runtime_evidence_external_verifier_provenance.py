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
import datetime as dt
import hashlib
import json
import pathlib
import tempfile
import unittest
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_bootstrap_manifest as bootstrap  # noqa: E402
import runtime_evidence_external_verifier_provenance as prov  # noqa: E402
import runtime_evidence_external_verifier_receipt as upstream  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402


NOW = dt.datetime(2026, 10, 5, 0, 0, tzinfo=dt.timezone.utc)
CHALLENGE = "sha256:" + "9" * 64
WORKFLOW = "trusted/verifier/.github/workflows/verify.yml@" + "a" * 40
ISSUER = prov.GITHUB_ACTIONS_OIDC_ISSUER
BINARY = "sha256:" + "b" * 64
BOOTSTRAP_COMMIT = "c" * 40


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _file_sha(raw):
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _bootstrap_manifest():
    files = []
    total = 0
    for index, name in enumerate(bootstrap.REQUIRED_FILES, start=1):
        size = index * 10
        total += size
        files.append(
            {
                "path": (bootstrap.PACKAGE_RELATIVE_DIR / name).as_posix(),
                "sha256": "sha256:" + str(index) * 64,
                "size_bytes": size,
            }
        )
    package_binding = {
        "domain": bootstrap.DOMAIN,
        "contract_stage": bootstrap.CONTRACT_STAGE,
        "declared_source_commit": BOOTSTRAP_COMMIT,
        "files": files,
    }
    value = {
        "schema_version": "1",
        "domain": bootstrap.DOMAIN,
        "contract_stage": bootstrap.CONTRACT_STAGE,
        "declared_source_commit": BOOTSTRAP_COMMIT,
        "package_file_count": len(files),
        "package_total_bytes": total,
        "files": files,
        "package_content_hash": ingress._canonical_hash(package_binding),
        "exact_required_file_set_verified": True,
        "package_bytes_content_addressed_candidate": True,
        "declared_source_commit_bound_candidate": True,
        "bootstrap_contract_semantics_revalidated": False,
        "source_commit_repository_membership_verified": False,
        "external_operator_received_package_verified": False,
        "external_operator_accepted_package_verified": False,
        "admin_evidence_independently_verified": False,
        "nonce_one_time_consumption_verified": False,
        "independent_admin_boundary_verified": False,
        "independent_verifier_execution_attested": False,
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


def _upstream():
    value = {
        "schema_version": "1",
        "domain": upstream.DOMAIN,
        "contract_stage": upstream.CONTRACT_STAGE,
        "request_hash": "sha256:" + "1" * 64,
        "config_sha": "sha256:" + "2" * 64,
        "provider": "cloudflare",
        "platform": "codex",
        "capture_id": "capture-1",
        "command_candidate_result_hash": "sha256:" + "3" * 64,
        "command_candidate_file_sha256": "sha256:" + "4" * 64,
        "external_receipt_file_sha256": "sha256:" + "5" * 64,
        "verification_nonce": "nonce-1234567890abcdef",
        "issued_at": "2026-10-04T23:50:00Z",
        "expires_at": "2026-10-05T00:05:00Z",
        "verifier_id": "external-verifier",
        "verifier_version": "v1.0.0",
        "verifier_binary_sha256": BINARY,
        "receipt_structure_verified": True,
        "receipt_candidate_binding_verified": True,
        "receipt_content_addressed": True,
        "receipt_nonce_binding_verified": True,
        "receipt_freshness_verified": True,
        "receipt_artifact_digest_binding_candidate": True,
        "receipt_attestation_verify_exit_success_candidate": True,
        "receipt_claims_authenticated": False,
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


def _receipt(upstream_value=None, bootstrap_value=None):
    upstream_value = upstream_value or _upstream()
    bootstrap_value = bootstrap_value or _bootstrap_manifest()
    upstream_raw = _json_bytes(upstream_value)
    bootstrap_raw = _json_bytes(bootstrap_value)
    value = {
        "schema_version": "1",
        "domain": prov.RECEIPT_DOMAIN,
        "contract_stage": prov.RECEIPT_STAGE,
        "request_hash": upstream_value["request_hash"],
        "config_sha": upstream_value["config_sha"],
        "provider": upstream_value["provider"],
        "platform": upstream_value["platform"],
        "capture_id": upstream_value["capture_id"],
        "bootstrap_manifest_result_hash": bootstrap_value["result_hash"],
        "bootstrap_manifest_file_sha256": _file_sha(bootstrap_raw),
        "bootstrap_package_content_hash": bootstrap_value["package_content_hash"],
        "bootstrap_declared_source_commit": bootstrap_value["declared_source_commit"],
        "external_verifier_result_hash": upstream_value["result_hash"],
        "external_verifier_result_file_sha256": _file_sha(upstream_raw),
        "external_receipt_file_sha256": upstream_value["external_receipt_file_sha256"],
        "verification_nonce": upstream_value["verification_nonce"],
        "verifier_id": upstream_value["verifier_id"],
        "verifier_version": upstream_value["verifier_version"],
        "verifier_binary_sha256": upstream_value["verifier_binary_sha256"],
        "verifier_issuer": ISSUER,
        "verifier_workflow_ref": WORKFLOW,
        "execution_id": "run-12345",
        "challenge_id": CHALLENGE,
        "issued_at": "2026-10-04T23:58:00Z",
        "expires_at": "2026-10-05T00:03:00Z",
    }
    value["provenance_receipt_hash"] = ingress._canonical_hash(value)
    return value


def _verify(up=None, boot=None, receipt=None, **kwargs):
    up = up or _upstream()
    boot = boot or _bootstrap_manifest()
    receipt = receipt or _receipt(up, boot)
    return prov.verify_provenance_bytes(
        bootstrap_manifest_result_raw=_json_bytes(boot),
        external_verifier_result_raw=_json_bytes(up),
        provenance_receipt_raw=_json_bytes(receipt),
        expected_verifier_workflow_ref=kwargs.get("workflow", WORKFLOW),
        expected_challenge_id=kwargs.get("challenge", CHALLENGE),
        now=kwargs.get("now", NOW),
    )


class ExternalVerifierProvenanceTests(unittest.TestCase):
    def test_valid_provenance_stays_candidate_only(self):
        result = _verify()
        for field in (
            "bootstrap_manifest_binding_candidate",
            "bootstrap_package_content_binding_candidate",
            "external_verifier_result_binding_verified",
            "upstream_receipt_freshness_reverified",
            "provenance_receipt_structure_verified",
            "provenance_receipt_content_addressed",
            "immutable_verifier_identity_binding_candidate",
            "github_actions_oidc_issuer_bound_candidate",
            "run_challenge_binding_candidate",
            "freshness_window_candidate",
        ):
            self.assertTrue(result[field])
        for field in (
            "bootstrap_contract_semantics_revalidated",
            "source_commit_repository_membership_verified",
            "external_operator_received_package_verified",
            "external_operator_accepted_package_verified",
            "same_challenge_replay_prevented",
            "provenance_receipt_signature_verified",
            "crypto_verifier_binary_verified",
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
        self.assertEqual(
            result["command_candidate_result_hash"],
            _upstream()["command_candidate_result_hash"],
        )
        self.assertEqual(
            result["bootstrap_package_content_hash"],
            _bootstrap_manifest()["package_content_hash"],
        )
        self.assertFalse(any(result["authority"].values()))

    def test_bootstrap_self_promotion_is_rejected(self):
        protected = (
            "bootstrap_contract_semantics_revalidated",
            "source_commit_repository_membership_verified",
            "external_operator_received_package_verified",
            "external_operator_accepted_package_verified",
            "independent_admin_boundary_verified",
            "runtime_probe_attestation_verified",
            "human_rollout_decision_verified",
            "dispatch_ready",
            "dispatch_allowed",
        )
        for field in protected:
            with self.subTest(field=field):
                boot = _bootstrap_manifest()
                boot[field] = True
                body = dict(boot)
                body.pop("result_hash")
                boot["result_hash"] = ingress._canonical_hash(body)
                with self.assertRaises(prov.ExternalVerifierProvenanceError):
                    _verify(boot=boot, receipt=_receipt(_upstream(), boot))

    def test_non_object_bootstrap_manifest_fails_closed(self):
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            prov.verify_provenance_bytes(
                bootstrap_manifest_result_raw=b"[]",
                external_verifier_result_raw=_json_bytes(_upstream()),
                provenance_receipt_raw=_json_bytes(_receipt()),
                expected_verifier_workflow_ref=WORKFLOW,
                expected_challenge_id=CHALLENGE,
                now=NOW,
            )

    def test_oversized_bootstrap_file_claim_is_rejected(self):
        boot = _bootstrap_manifest()
        boot["files"][0]["size_bytes"] = bootstrap.MAX_FILE_BYTES + 1
        boot["package_total_bytes"] = sum(item["size_bytes"] for item in boot["files"])
        package_binding = {
            "domain": boot["domain"],
            "contract_stage": boot["contract_stage"],
            "declared_source_commit": boot["declared_source_commit"],
            "files": boot["files"],
        }
        boot["package_content_hash"] = ingress._canonical_hash(package_binding)
        body = dict(boot)
        body.pop("result_hash")
        boot["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(boot=boot, receipt=_receipt(_upstream(), boot))

    def test_wrong_bootstrap_package_hash_is_rejected(self):
        boot = _bootstrap_manifest()
        boot["package_content_hash"] = "sha256:" + "f" * 64
        body = dict(boot)
        body.pop("result_hash")
        boot["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(boot=boot, receipt=_receipt(_upstream(), boot))

    def test_receipt_bound_to_other_bootstrap_manifest_is_rejected(self):
        boot = _bootstrap_manifest()
        other = copy.deepcopy(boot)
        other["declared_source_commit"] = "d" * 40
        package_binding = {
            "domain": other["domain"],
            "contract_stage": other["contract_stage"],
            "declared_source_commit": other["declared_source_commit"],
            "files": other["files"],
        }
        other["package_content_hash"] = ingress._canonical_hash(package_binding)
        body = dict(other)
        body.pop("result_hash")
        other["result_hash"] = ingress._canonical_hash(body)
        receipt = _receipt(_upstream(), boot)
        with self.assertRaises(prov.ExternalVerifierProvenanceError) as caught:
            _verify(boot=other, receipt=receipt)
        self.assertIn("exact #1484 binding required", str(caught.exception))

    def test_legacy_receipt_without_bootstrap_binding_is_rejected(self):
        value = _receipt()
        for key in (
            "bootstrap_manifest_result_hash",
            "bootstrap_manifest_file_sha256",
            "bootstrap_package_content_hash",
            "bootstrap_declared_source_commit",
        ):
            value.pop(key)
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_wrong_challenge_is_rejected(self):
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(challenge="sha256:" + "8" * 64)

    def test_wrong_verifier_issuer_is_rejected(self):
        value = _receipt()
        value["verifier_issuer"] = "https://issuer.invalid"
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_wrong_verifier_workflow_is_rejected(self):
        other = "trusted/verifier/.github/workflows/other.yml@" + "a" * 40
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(workflow=other)

    def test_wrong_verifier_binary_is_rejected(self):
        value = _receipt()
        value["verifier_binary_sha256"] = "sha256:" + "c" * 64
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_plangate_workflow_cannot_be_external_verifier(self):
        value = _receipt()
        value["verifier_workflow_ref"] = (
            "s977043/PlanGate/.github/workflows/verify.yml@" + "a" * 40
        )
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value, workflow=value["verifier_workflow_ref"])

    def test_stale_upstream_result_cannot_be_rewrapped(self):
        value = _upstream()
        value["issued_at"] = "2026-10-04T22:00:00Z"
        value["expires_at"] = "2026-10-04T22:05:00Z"
        body = dict(value)
        body.pop("result_hash")
        value["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(up=value, receipt=_receipt(value))

    def test_upstream_expiry_boundary_is_rejected(self):
        value = _upstream()
        value["expires_at"] = NOW.isoformat().replace("+00:00", "Z")
        body = dict(value)
        body.pop("result_hash")
        value["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(up=value, receipt=_receipt(value))

    def test_malformed_upstream_nonce_is_rejected(self):
        value = _upstream()
        value["verification_nonce"] = "short"
        body = dict(value)
        body.pop("result_hash")
        value["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(up=value, receipt=_receipt(value))

    def test_provenance_cannot_predate_upstream_result(self):
        value = _receipt()
        value["issued_at"] = "2026-10-04T23:49:00Z"
        value["expires_at"] = "2026-10-05T00:02:00Z"
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError) as caught:
            _verify(receipt=value)
        self.assertIn("must not predate #1471 issued_at", str(caught.exception))

    def test_stale_provenance_is_rejected(self):
        value = _receipt()
        value["issued_at"] = "2026-10-04T22:00:00Z"
        value["expires_at"] = "2026-10-04T22:05:00Z"
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_overlong_validity_is_rejected(self):
        value = _receipt()
        value["expires_at"] = "2026-10-05T00:30:00Z"
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_wrong_request_binding_is_rejected(self):
        value = _receipt()
        value["request_hash"] = "sha256:" + "7" * 64
        body = dict(value)
        body.pop("provenance_receipt_hash")
        value["provenance_receipt_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_upstream_self_promotion_is_rejected(self):
        value = _upstream()
        value["runtime_probe_attestation_verified"] = True
        body = dict(value)
        body.pop("result_hash")
        value["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(up=value, receipt=_receipt(value))

    def test_unknown_upstream_field_is_rejected(self):
        value = _upstream()
        value["future_authority"] = True
        body = dict(value)
        body.pop("result_hash")
        value["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(up=value, receipt=_receipt(value))

    def test_tampered_provenance_hash_is_rejected(self):
        value = _receipt()
        value["provenance_receipt_hash"] = "sha256:" + "6" * 64
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_raw_runtime_payload_key_is_rejected(self):
        value = _receipt()
        value["stdout"] = "untrusted runtime payload"
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            _verify(receipt=value)

    def test_same_challenge_replay_is_not_overclaimed(self):
        first = _verify()
        second = _verify()
        self.assertFalse(first["same_challenge_replay_prevented"])
        self.assertEqual(first["result_hash"], second["result_hash"])

    def test_repository_local_receipt_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            repo = root / "repo"
            repo.mkdir()
            (repo / "docs").mkdir()
            (repo / "scripts").mkdir()
            boot_path = root / "bootstrap.json"
            boot_path.write_bytes(_json_bytes(_bootstrap_manifest()))
            up_path = root / "upstream.json"
            up_path.write_bytes(_json_bytes(_upstream()))
            receipt_path = repo / "receipt.json"
            receipt_path.write_bytes(_json_bytes(_receipt()))
            with self.assertRaises(prov.ExternalVerifierProvenanceError) as caught:
                prov.verify_provenance_files(
                    repo_root=repo,
                    bootstrap_manifest_result_path=boot_path,
                    external_verifier_result_path=up_path,
                    provenance_receipt_path=receipt_path,
                    expected_verifier_workflow_ref=WORKFLOW,
                    expected_challenge_id=CHALLENGE,
                    now=NOW,
                )
            self.assertIn("must stay outside repository", str(caught.exception))

    def test_symlinked_provenance_receipt_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            repo = root / "repo"
            external = root / "external"
            repo.mkdir()
            external.mkdir()
            boot_path = external / "bootstrap.json"
            boot_path.write_bytes(_json_bytes(_bootstrap_manifest()))
            up_path = external / "upstream.json"
            up_path.write_bytes(_json_bytes(_upstream()))
            real = external / "real-receipt.json"
            real.write_bytes(_json_bytes(_receipt()))
            link = external / "receipt.json"
            try:
                link.symlink_to(real)
            except (OSError, NotImplementedError):
                self.skipTest("symlink creation unavailable")
            with self.assertRaises(prov.ExternalVerifierProvenanceError):
                prov.verify_provenance_files(
                    repo_root=repo,
                    bootstrap_manifest_result_path=boot_path,
                    external_verifier_result_path=up_path,
                    provenance_receipt_path=link,
                    expected_verifier_workflow_ref=WORKFLOW,
                    expected_challenge_id=CHALLENGE,
                    now=NOW,
                )

    def test_duplicate_json_key_is_rejected(self):
        raw = b'{"schema_version":"1","schema_version":"1"}'
        with self.assertRaises(prov.ExternalVerifierProvenanceError):
            prov._strict_json_loads(raw, "fixture")


if __name__ == "__main__":
    unittest.main()
