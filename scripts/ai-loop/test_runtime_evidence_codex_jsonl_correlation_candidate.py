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

import runtime_evidence_codex_jsonl_correlation_candidate as corr  # noqa: E402
import runtime_evidence_codex_probe_candidate as probe  # noqa: E402


REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
PROVIDER = "cloudflare"


def _hook_candidate():
    start = probe.normalize_hook_event(
        event={
            "session_id": "sess-1",
            "transcript_path": "/tmp/main.jsonl",
            "cwd": "/workspace",
            "hook_event_name": "SubagentStart",
            "model": "gpt-5.6",
            "turn_id": "turn-1",
            "agent_id": "agent-1",
            "agent_type": "explorer_agent",
            "permission_mode": "default",
        },
        request_hash=REQ,
        config_sha=CONFIG,
        provider=PROVIDER,
    )
    stop = probe.normalize_hook_event(
        event={
            "session_id": "sess-1",
            "transcript_path": "/tmp/main.jsonl",
            "cwd": "/workspace",
            "hook_event_name": "SubagentStop",
            "model": "gpt-5.6",
            "turn_id": "turn-1",
            "agent_id": "agent-1",
            "agent_type": "explorer_agent",
            "permission_mode": "default",
            "agent_transcript_path": "/tmp/subagent.jsonl",
            "stop_hook_active": False,
            "last_assistant_message": "inspection complete",
        },
        request_hash=REQ,
        config_sha=CONFIG,
        provider=PROVIDER,
    )
    return probe.verify_candidate_trace(
        records=[start, stop],
        request_hash=REQ,
        config_sha=CONFIG,
        provider=PROVIDER,
    )


def _write_jsonl(root: pathlib.Path, rows=None):
    if rows is None:
        rows = [
            {
                "type": "item.completed",
                "item": {
                    "id": "item_1",
                    "type": "command_execution",
                    "command": "SECRET COMMAND MUST NOT LEAK",
                    "exit_code": 0,
                    "status": "completed",
                },
            },
            {
                "type": "item.completed",
                "item": {
                    "id": "item_2",
                    "type": "agent_message",
                    "text": "PRIVATE MESSAGE MUST NOT LEAK",
                },
            },
        ]
    path = root / "codex.jsonl"
    path.write_text(
        "".join(json.dumps(row) + "\n" for row in rows),
        encoding="utf-8",
    )
    return path


class HookCandidateValidationTests(unittest.TestCase):
    def test_candidate_must_stay_non_promoted(self):
        candidate = _hook_candidate()
        candidate["runtime_probe_attestation_verified"] = True
        body = dict(candidate)
        body.pop("result_hash")
        candidate["result_hash"] = corr.ingress._canonical_hash(body)
        with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
            corr.validate_hook_candidate(
                candidate,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
        self.assertTrue(
            any("non-promotion" in e for e in ctx.exception.errors)
        )

    def test_candidate_hash_tamper_is_rejected(self):
        candidate = _hook_candidate()
        candidate["result_hash"] = "sha256:" + "f" * 64
        with self.assertRaises(corr.CodexJsonlCorrelationError):
            corr.validate_hook_candidate(
                candidate,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )


class JsonlSummaryTests(unittest.TestCase):
    def test_runtime_content_is_not_copied(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "repo").mkdir()
            path = _write_jsonl(root)
            result = corr.summarize_codex_jsonl(
                path,
                repo_root=pathlib.Path(tmp) / "repo",
            )
        encoded = json.dumps(result, sort_keys=True)
        self.assertNotIn("SECRET COMMAND", encoded)
        self.assertNotIn("PRIVATE MESSAGE", encoded)
        self.assertFalse(result["raw_payload_copied"])
        self.assertEqual(result["item_completed_count"], 2)
        self.assertEqual(
            result["recognized_item_type_counts"]["command_execution"],
            1,
        )

    def test_raw_jsonl_inside_repo_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = repo / "codex.jsonl"
            path.write_text(
                json.dumps({
                    "type": "item.completed",
                    "item": {"id": "item_1", "type": "agent_message"},
                }) + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.summarize_codex_jsonl(path, repo_root=repo)
        self.assertTrue(
            any("outside repository" in e for e in ctx.exception.errors)
        )

    def test_duplicate_item_id_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "repo").mkdir()
            rows = [
                {"type": "item.completed", "item": {"id": "item_1", "type": "error"}},
                {"type": "item.completed", "item": {"id": "item_1", "type": "agent_message"}},
            ]
            path = _write_jsonl(root, rows)
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.summarize_codex_jsonl(
                    path,
                    repo_root=pathlib.Path(tmp) / "repo",
                )
        self.assertTrue(
            any("duplicate item.id" in e for e in ctx.exception.errors)
        )

    def test_no_completed_item_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "repo").mkdir()
            path = _write_jsonl(
                root,
                [{"type": "turn.started"}],
            )
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.summarize_codex_jsonl(
                    path,
                    repo_root=pathlib.Path(tmp) / "repo",
                )
        self.assertTrue(
            any("item.completed" in e for e in ctx.exception.errors)
        )

    def test_file_size_limit_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "repo").mkdir()
            path = root / "large.jsonl"
            path.write_bytes(b"x" * (corr.MAX_JSONL_BYTES + 1))
            with self.assertRaises(corr.CodexJsonlCorrelationError):
                corr.summarize_codex_jsonl(
                    path,
                    repo_root=pathlib.Path(tmp) / "repo",
                )

    def test_unknown_item_type_is_counted_not_copied(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "repo").mkdir()
            path = _write_jsonl(
                root,
                [
                    {
                        "type": "item.completed",
                        "item": {
                            "id": "item_x",
                            "type": "future_private_type",
                            "payload": "DO NOT COPY",
                        },
                    }
                ],
            )
            result = corr.summarize_codex_jsonl(
                path,
                repo_root=pathlib.Path(tmp) / "repo",
            )
        self.assertEqual(result["unrecognized_item_type_count"], 1)
        self.assertNotIn(
            "future_private_type",
            json.dumps(result, sort_keys=True),
        )
        self.assertNotIn("DO NOT COPY", json.dumps(result, sort_keys=True))


class CorrelationCandidateTests(unittest.TestCase):
    def test_complete_inputs_remain_copresence_candidate_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "repo").mkdir()
            path = _write_jsonl(root)
            result = corr.correlate_candidate(
                repo_root=root / "repo",
                hook_candidate=_hook_candidate(),
                codex_jsonl_path=path,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
        self.assertTrue(result["cross_source_pairing_candidate"])
        self.assertFalse(result["same_run_copresence_verified"])
        self.assertTrue(result["hook_candidate_binding_verified"])
        self.assertTrue(result["codex_jsonl_structural_candidate_verified"])
        self.assertFalse(result["direct_agent_id_correlation_available"])
        self.assertFalse(result["same_run_identity_verified"])
        self.assertFalse(result["trusted_jsonl_capture_root_attested"])
        self.assertFalse(result["codex_jsonl_runtime_correlation_verified"])
        self.assertFalse(result["runtime_probe_attestation_verified"])
        self.assertFalse(result["dispatch_ready"])
        self.assertFalse(result["dispatch_allowed"])

    def test_request_binding_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "repo").mkdir()
            path = _write_jsonl(root)
            with self.assertRaises(corr.CodexJsonlCorrelationError):
                corr.correlate_candidate(
                    repo_root=pathlib.Path(tmp) / "repo",
                    hook_candidate=_hook_candidate(),
                    codex_jsonl_path=path,
                    request_hash="sha256:" + "c" * 64,
                    config_sha=CONFIG,
                    provider=PROVIDER,
                )


if __name__ == "__main__":
    unittest.main()
