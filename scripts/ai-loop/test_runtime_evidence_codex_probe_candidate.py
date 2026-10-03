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

import runtime_evidence_codex_probe_candidate as probe  # noqa: E402


REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
PROVIDER = "cloudflare"


def _start():
    return {
        "session_id": "sess-1",
        "transcript_path": "/tmp/main.jsonl",
        "cwd": "/workspace",
        "hook_event_name": "SubagentStart",
        "model": "gpt-5.6",
        "turn_id": "turn-1",
        "agent_id": "agent-1",
        "agent_type": "explorer_agent",
        "permission_mode": "default",
    }


def _stop():
    return {
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
    }


def _normalized():
    return [
        probe.normalize_hook_event(
            event=_start(),
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
        ),
        probe.normalize_hook_event(
            event=_stop(),
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
        ),
    ]


class NormalizeHookEventTests(unittest.TestCase):
    def test_start_and_stop_normalize(self):
        rows = _normalized()
        self.assertEqual(rows[0]["hook_event_name"], "SubagentStart")
        self.assertEqual(rows[1]["hook_event_name"], "SubagentStop")
        self.assertEqual(rows[0]["agent_type"], "explorer_agent")
        self.assertTrue(rows[1]["agent_transcript_path_present"])

    def test_wrong_agent_type_is_rejected(self):
        event = _start()
        event["agent_type"] = "worker"
        with self.assertRaises(probe.CodexProbeCandidateError):
            probe.normalize_hook_event(
                event=event,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )

    def test_unknown_hook_field_is_rejected(self):
        event = _start()
        event["pretend_attested"] = True
        with self.assertRaises(probe.CodexProbeCandidateError) as ctx:
            probe.normalize_hook_event(
                event=event,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
        self.assertTrue(
            any("unsupported keys" in e for e in ctx.exception.errors)
        )


class CandidateTraceTests(unittest.TestCase):
    def test_complete_trace_is_candidate_only(self):
        result = probe.verify_candidate_trace(
            records=_normalized(),
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
        )
        self.assertTrue(result["subagent_start_candidate_verified"])
        self.assertTrue(result["subagent_stop_candidate_verified"])
        self.assertTrue(result["runtime_role_registered_candidate"])
        self.assertTrue(result["explorer_execution_candidate"])
        self.assertTrue(result["hook_trace_integrity_verified"])
        self.assertFalse(result["hook_execution_root_attested"])
        self.assertFalse(result["codex_jsonl_runtime_correlation_verified"])
        self.assertFalse(result["hard_read_only_enforced"])
        self.assertFalse(result["runtime_probe_attestation_verified"])
        self.assertFalse(result["human_rollout_decision_verified"])
        self.assertFalse(result["dispatch_ready"])
        self.assertFalse(result["dispatch_allowed"])
        self.assertFalse(result["authority"]["agent_invoke_allowed"])

    def test_start_stop_agent_id_mismatch_is_rejected(self):
        rows = _normalized()
        bad = copy.deepcopy(rows)
        bad[1]["agent_id"] = "agent-2"
        body = copy.deepcopy(bad[1])
        body.pop("record_hash")
        bad[1]["record_hash"] = probe.ingress._canonical_hash(body)
        with self.assertRaises(probe.CodexProbeCandidateError) as ctx:
            probe.verify_candidate_trace(
                records=bad,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
        self.assertTrue(
            any("agent_id must match" in e for e in ctx.exception.errors)
        )

    def test_duplicate_start_is_rejected(self):
        rows = _normalized()
        rows.insert(1, copy.deepcopy(rows[0]))
        with self.assertRaises(probe.CodexProbeCandidateError) as ctx:
            probe.verify_candidate_trace(
                records=rows,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
        self.assertTrue(
            any("exactly one Explorer SubagentStart" in e for e in ctx.exception.errors)
        )

    def test_record_hash_tamper_is_rejected(self):
        rows = _normalized()
        rows[0]["permission_mode"] = "bypassPermissions"
        with self.assertRaises(probe.CodexProbeCandidateError) as ctx:
            probe.verify_candidate_trace(
                records=rows,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
        self.assertTrue(
            any("record_hash" in e for e in ctx.exception.errors)
        )

    def test_request_binding_mismatch_is_rejected(self):
        with self.assertRaises(probe.CodexProbeCandidateError) as ctx:
            probe.verify_candidate_trace(
                records=_normalized(),
                request_hash="sha256:" + "c" * 64,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
        self.assertTrue(
            any("request_hash: exact binding" in e for e in ctx.exception.errors)
        )


class JsonlRecordingTests(unittest.TestCase):
    def test_record_hook_appends_two_records(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = pathlib.Path(tmp) / "hooks.jsonl"
            probe.record_hook_event(
                output=output,
                event=_start(),
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
            probe.record_hook_event(
                output=output,
                event=_stop(),
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
            )
            rows = probe.load_jsonl(output)

        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["hook_event_name"], "SubagentStart")
        self.assertEqual(rows[1]["hook_event_name"], "SubagentStop")

    def test_invalid_jsonl_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = pathlib.Path(tmp) / "bad.jsonl"
            source.write_text("{not-json}\n", encoding="utf-8")
            with self.assertRaises(probe.CodexProbeCandidateError):
                probe.load_jsonl(source)


if __name__ == "__main__":
    unittest.main()
