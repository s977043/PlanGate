#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
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

import runtime_evidence_codex_jsonl_correlation as corr  # noqa: E402
import runtime_evidence_codex_managed_capture_manifest as managed  # noqa: E402
import runtime_evidence_codex_probe_candidate as probe  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402

REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
PROVIDER = "cloudflare"
THREAD = "sess-1"
HOOK_SHA = "sha256:" + "c" * 64
EXEC_SHA = "sha256:" + "d" * 64
POLICY_SHA = "sha256:" + "e" * 64
RECORDER_SHA = "sha256:" + "f" * 64


def _hook_records():
    start = {
        "session_id": THREAD,
        "transcript_path": "/tmp/main.jsonl",
        "cwd": "/workspace",
        "hook_event_name": "SubagentStart",
        "model": "gpt-5.6",
        "turn_id": "turn-hook-1",
        "agent_id": "agent-1",
        "agent_type": "explorer_agent",
        "permission_mode": "default",
    }
    stop = {
        **start,
        "hook_event_name": "SubagentStop",
        "agent_transcript_path": "/tmp/subagent.jsonl",
        "stop_hook_active": False,
        "last_assistant_message": "inspection complete",
    }
    return [
        probe.normalize_hook_event(
            event=start, request_hash=REQ, config_sha=CONFIG, provider=PROVIDER
        ),
        probe.normalize_hook_event(
            event=stop, request_hash=REQ, config_sha=CONFIG, provider=PROVIDER
        ),
    ]


def _exec_events():
    return [
        {"type": "thread.started", "thread_id": THREAD},
        {"type": "turn.started"},
        {
            "type": "item.completed",
            "item": {"id": "item-1", "type": "command_execution"},
        },
        {
            "type": "turn.completed",
            "usage": {
                "input_tokens": 10,
                "cached_input_tokens": 0,
                "cache_write_input_tokens": 0,
                "output_tokens": 2,
                "reasoning_output_tokens": 1,
            },
        },
    ]


def _correlation_result():
    return corr.correlate_candidate(
        hook_records=_hook_records(),
        exec_events=_exec_events(),
        request_hash=REQ,
        config_sha=CONFIG,
        provider=PROVIDER,
        hook_jsonl_sha256=HOOK_SHA,
        exec_jsonl_sha256=EXEC_SHA,
    )


def _manifest(result=None):
    result = result or _correlation_result()
    value = {
        "schema_version": "1",
        "domain": managed.MANIFEST_DOMAIN,
        "contract_stage": managed.MANIFEST_STAGE,
        "capture_id": "capture-1",
        "request_hash": result["request_hash"],
        "config_sha": result["config_sha"],
        "provider": result["provider"],
        "platform": "codex",
        "managed_hook_source": "requirements.toml",
        "allow_managed_hooks_only_claimed": True,
        "hooks_feature_pinned_claimed": True,
        "managed_policy_sha256": POLICY_SHA,
        "managed_recorder_sha256": RECORDER_SHA,
        "hook_jsonl_sha256": result["hook_jsonl_sha256"],
        "exec_jsonl_sha256": result["exec_jsonl_sha256"],
        "correlation_result_hash": result["result_hash"],
        "hook_session_id": result["hook_session_id"],
        "exec_thread_id": result["exec_thread_id"],
    }
    value["manifest_hash"] = ingress._canonical_hash(value)
    return value


def _rehash_manifest(value):
    body = dict(value)
    body.pop("manifest_hash", None)
    value["manifest_hash"] = ingress._canonical_hash(body)


class ManagedCaptureManifestTests(unittest.TestCase):
    def test_valid_manifest_remains_candidate_only(self):
        result = managed.verify_candidate(
            correlation_result=_correlation_result(),
            capture_manifest=_manifest(),
        )
        for field in (
            "capture_manifest_structure_verified",
            "capture_manifest_self_hash_verified",
            "capture_manifest_cross_binding_verified",
            "same_run_binding_manifest_candidate",
        ):
            self.assertTrue(result[field])
        for field in (
            "managed_hook_source_runtime_verified",
            "managed_policy_live_verified",
            "managed_policy_content_binding_verified",
            "managed_recorder_binary_verified",
            "managed_recorder_content_binding_verified",
            "manifest_signature_verified",
            "independent_verifier_execution_attested",
            "managed_hook_root_attested",
            "same_run_identity_verified",
            "runtime_probe_attestation_verified",
            "human_rollout_decision_verified",
            "dispatch_ready",
            "dispatch_allowed",
        ):
            self.assertFalse(result[field])
        self.assertFalse(any(result["authority"].values()))

    def _reject_modified_manifest(self, field, value):
        manifest = _manifest()
        manifest[field] = value
        _rehash_manifest(manifest)
        with self.assertRaises(managed.ManagedCaptureManifestError):
            managed.verify_candidate(
                correlation_result=_correlation_result(),
                capture_manifest=manifest,
            )

    def test_request_hash_mismatch_is_rejected(self):
        self._reject_modified_manifest("request_hash", "sha256:" + "9" * 64)

    def test_config_sha_mismatch_is_rejected(self):
        self._reject_modified_manifest("config_sha", "sha256:" + "9" * 64)

    def test_provider_mismatch_is_rejected(self):
        self._reject_modified_manifest("provider", "other")

    def test_hook_hash_mismatch_is_rejected(self):
        self._reject_modified_manifest("hook_jsonl_sha256", "sha256:" + "9" * 64)

    def test_exec_hash_mismatch_is_rejected(self):
        self._reject_modified_manifest("exec_jsonl_sha256", "sha256:" + "9" * 64)

    def test_correlation_hash_mismatch_is_rejected(self):
        self._reject_modified_manifest(
            "correlation_result_hash", "sha256:" + "9" * 64
        )

    def test_manifest_hash_mismatch_is_rejected(self):
        manifest = _manifest()
        manifest["manifest_hash"] = "sha256:" + "9" * 64
        with self.assertRaises(managed.ManagedCaptureManifestError):
            managed.verify_candidate(
                correlation_result=_correlation_result(),
                capture_manifest=manifest,
            )

    def test_managed_only_claim_must_be_true(self):
        self._reject_modified_manifest("allow_managed_hooks_only_claimed", False)

    def test_hooks_feature_pinned_claim_must_be_true(self):
        self._reject_modified_manifest("hooks_feature_pinned_claimed", False)

    def test_unsupported_managed_source_is_rejected(self):
        self._reject_modified_manifest("managed_hook_source", "project")

    def test_unknown_manifest_key_is_rejected(self):
        manifest = _manifest()
        manifest["raw_runtime_text"] = "must not be accepted"
        _rehash_manifest(manifest)
        with self.assertRaises(managed.ManagedCaptureManifestError):
            managed.verify_candidate(
                correlation_result=_correlation_result(),
                capture_manifest=manifest,
            )

    def test_promoted_upstream_correlation_is_rejected(self):
        result = _correlation_result()
        result["runtime_probe_attestation_verified"] = True
        body = dict(result)
        body.pop("result_hash")
        result["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(managed.ManagedCaptureManifestError):
            managed.verify_candidate(
                correlation_result=result,
                capture_manifest=_manifest(result),
            )

    def test_unknown_upstream_field_is_rejected(self):
        result = _correlation_result()
        result["future_promotion_flag"] = True
        body = dict(result)
        body.pop("result_hash")
        result["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(managed.ManagedCaptureManifestError):
            managed.verify_candidate(
                correlation_result=result,
                capture_manifest=_manifest(result),
            )

    def test_missing_upstream_authority_key_is_rejected(self):
        result = _correlation_result()
        result["authority"] = copy.deepcopy(result["authority"])
        result["authority"].pop("deploy_allowed")
        body = dict(result)
        body.pop("result_hash")
        result["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(managed.ManagedCaptureManifestError):
            managed.verify_candidate(
                correlation_result=result,
                capture_manifest=_manifest(result),
            )

    def test_nonzero_upstream_authority_is_rejected(self):
        result = _correlation_result()
        result["authority"] = copy.deepcopy(result["authority"])
        result["authority"]["agent_invoke_allowed"] = True
        body = dict(result)
        body.pop("result_hash")
        result["result_hash"] = ingress._canonical_hash(body)
        with self.assertRaises(managed.ManagedCaptureManifestError):
            managed.verify_candidate(
                correlation_result=result,
                capture_manifest=_manifest(result),
            )


class LoaderTests(unittest.TestCase):
    def test_loader_hashes_same_read_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "manifest.json"
            value = _manifest()
            path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
            loaded, digest = managed.load_json_object(
                path, repo_root=repo, field="capture_manifest"
            )
        self.assertEqual(loaded, value)
        self.assertRegex(digest, r"^sha256:[0-9a-f]{64}$")

    def test_repo_local_artifact_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = repo / "manifest.json"
            path.write_text("{}\n", encoding="utf-8")
            with self.assertRaises(managed.ManagedCaptureManifestError):
                managed.load_json_object(
                    path, repo_root=repo, field="capture_manifest"
                )

    def test_duplicate_json_key_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "manifest.json"
            path.write_text('{"x":1,"x":2}\n', encoding="utf-8")
            with self.assertRaises(managed.ManagedCaptureManifestError):
                managed.load_json_object(
                    path, repo_root=repo, field="capture_manifest"
                )

    def test_invalid_utf8_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "manifest.json"
            path.write_bytes(b"\xff\n")
            with self.assertRaises(managed.ManagedCaptureManifestError):
                managed.load_json_object(
                    path, repo_root=repo, field="capture_manifest"
                )

    def test_size_limit_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "manifest.json"
            path.write_bytes(b"x" * (managed.MAX_JSON_BYTES + 1))
            with self.assertRaises(managed.ManagedCaptureManifestError):
                managed.load_json_object(
                    path, repo_root=repo, field="capture_manifest"
                )


if __name__ == "__main__":
    unittest.main()
