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

import runtime_evidence_codex_jsonl_correlation as corr  # noqa: E402
import runtime_evidence_codex_probe_candidate as probe  # noqa: E402


REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64
PROVIDER = "cloudflare"
THREAD = "sess-1"


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
            event=start,
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
        ),
        probe.normalize_hook_event(
            event=stop,
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
        ),
    ]


def _exec_events():
    return [
        {"type": "thread.started", "thread_id": THREAD},
        {"type": "turn.started"},
        {
            "type": "item.completed",
            "item": {
                "id": "item-1",
                "type": "reasoning",
                "text": "omitted by correlator",
            },
        },
        {
            "type": "item.completed",
            "item": {
                "id": "item-2",
                "type": "agent_message",
                "text": "omitted by correlator",
            },
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


class CorrelationTests(unittest.TestCase):
    def test_same_thread_single_turn_is_partial_correlation_only(self):
        result = corr.correlate_candidate(
            hook_records=_hook_records(),
            exec_events=_exec_events(),
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
            hook_jsonl_sha256="sha256:" + "d" * 64,
            exec_jsonl_sha256="sha256:" + "c" * 64,
        )
        self.assertTrue(result["exec_jsonl_structure_verified"])
        self.assertTrue(result["identifier_value_match_verified"])
        self.assertTrue(result["hook_session_id_equals_exec_thread_id"])
        self.assertFalse(result["session_thread_semantic_binding_verified"])
        self.assertTrue(result["parent_thread_correlation_candidate"])
        self.assertFalse(result["parent_thread_correlation_verified"])
        self.assertFalse(result["thread_id_correlation_verified"])
        self.assertFalse(result["codex_jsonl_thread_correlation_verified"])
        self.assertTrue(result["trace_content_binding_verified"])
        self.assertTrue(result["single_turn_envelope_verified"])
        self.assertTrue(
            result["explicit_forbidden_item_type_absence_verified"]
        )
        self.assertFalse(result["command_execution_read_only_verified"])
        self.assertFalse(result["mcp_tool_read_only_verified"])
        self.assertFalse(result["repository_postcondition_verified"])
        self.assertFalse(result["turn_id_exposed_in_exec_jsonl"])
        self.assertFalse(result["turn_id_correlation_verified"])
        self.assertFalse(result["subagent_identity_correlation_verified"])
        self.assertFalse(result["same_subagent_execution_correlated"])
        self.assertFalse(result["codex_jsonl_runtime_correlation_verified"])
        self.assertFalse(result["runtime_probe_attestation_verified"])
        self.assertFalse(result["dispatch_allowed"])

    def test_thread_mismatch_is_rejected(self):
        events = _exec_events()
        events[0]["thread_id"] = "different-thread"
        with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )
        self.assertTrue(any("session_id" in e for e in ctx.exception.errors))

    def test_turn_completed_before_start_is_rejected(self):
        events = _exec_events()
        events[1], events[-1] = events[-1], events[1]
        with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )
        self.assertTrue(
            any("must follow turn.started" in e for e in ctx.exception.errors)
        )

    def test_item_outside_turn_boundary_is_rejected(self):
        events = _exec_events()
        item = events.pop(2)
        events.insert(1, item)
        with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )
        self.assertTrue(
            any("inside turn boundary" in e for e in ctx.exception.errors)
        )

    def test_event_after_turn_completed_is_rejected(self):
        events = _exec_events()
        events.append(
            {
                "type": "item.completed",
                "item": {
                    "id": "late",
                    "type": "agent_message",
                    "text": "late",
                },
            }
        )
        with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )
        self.assertTrue(
            any("final event" in e for e in ctx.exception.errors)
        )

    def test_multiple_turns_are_rejected(self):
        events = _exec_events()
        events.insert(-1, {"type": "turn.started"})
        with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )
        self.assertTrue(any("exactly one turn.started" in e for e in ctx.exception.errors))

    def test_turn_failed_is_rejected(self):
        events = _exec_events()
        events[-1] = {"type": "turn.failed", "error": {"message": "failed"}}
        with self.assertRaises(corr.CodexJsonlCorrelationError):
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )

    def test_file_change_is_rejected(self):
        events = _exec_events()
        events.insert(
            -1,
            {
                "type": "item.completed",
                "item": {
                    "id": "item-file",
                    "type": "file_change",
                    "changes": [{"path": "x", "kind": "update"}],
                    "status": "completed",
                },
            },
        )
        with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )
        self.assertTrue(any("file_change forbidden" in e for e in ctx.exception.errors))

    def test_web_search_is_rejected(self):
        events = _exec_events()
        events.insert(
            -1,
            {
                "type": "item.completed",
                "item": {
                    "id": "item-web",
                    "type": "web_search",
                    "query": "secret runtime text",
                },
            },
        )
        with self.assertRaises(corr.CodexJsonlCorrelationError):
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )

    def test_undocumented_item_type_is_schema_drift_not_attestation(self):
        events = _exec_events()
        events.insert(
            -1,
            {
                "type": "item.completed",
                "item": {
                    "id": "item-future",
                    "type": "future_item",
                    "opaque": "do not copy",
                },
            },
        )
        result = corr.correlate_candidate(
            hook_records=_hook_records(),
            exec_events=events,
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
            hook_jsonl_sha256="sha256:" + "d" * 64,
            exec_jsonl_sha256="sha256:" + "c" * 64,
        )
        self.assertFalse(result["documented_item_schema_coverage_complete"])
        self.assertEqual(result["undocumented_item_type_count"], 3)
        self.assertFalse(result["codex_jsonl_runtime_correlation_verified"])

    def test_unknown_top_level_event_is_rejected(self):
        events = _exec_events()
        events.insert(1, {"type": "future.event"})
        with self.assertRaises(corr.CodexJsonlCorrelationError):
            corr.correlate_candidate(
                hook_records=_hook_records(),
                exec_events=events,
                request_hash=REQ,
                config_sha=CONFIG,
                provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )

    def test_raw_text_is_not_copied_to_result(self):
        events = _exec_events()
        events[2]["item"]["text"] = "TOP-SECRET-REASONING"
        result = corr.correlate_candidate(
            hook_records=_hook_records(),
            exec_events=events,
            request_hash=REQ,
            config_sha=CONFIG,
            provider=PROVIDER,
                hook_jsonl_sha256="sha256:" + "d" * 64,
                exec_jsonl_sha256="sha256:" + "c" * 64,
            )
        serialized = json.dumps(result, ensure_ascii=False)
        self.assertNotIn("TOP-SECRET-REASONING", serialized)
        self.assertNotIn("omitted by correlator", serialized)


class JsonlLoaderTests(unittest.TestCase):
    def test_relative_trace_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp) / "repo"
            repo.mkdir()
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.load_exec_jsonl("exec.jsonl", repo_root=repo)
        self.assertTrue(
            any("absolute path required" in e for e in ctx.exception.errors)
        )

    def test_exec_trace_inside_repo_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = repo / "exec.jsonl"
            path.write_text(
                json.dumps({"type": "thread.started", "thread_id": THREAD})
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.load_exec_jsonl(path, repo_root=repo)
        self.assertTrue(
            any("outside repository" in e for e in ctx.exception.errors)
        )

    def test_trace_file_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            real = root / "real.jsonl"
            real.write_text("{}\n", encoding="utf-8")
            link = root / "link.jsonl"
            try:
                link.symlink_to(real)
            except (OSError, NotImplementedError):
                self.skipTest("symlink creation unavailable")
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.load_exec_jsonl(link, repo_root=repo)
        self.assertTrue(
            any("file symlink" in e for e in ctx.exception.errors)
        )

    def test_trace_symlink_parent_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            real = root / "real"
            real.mkdir()
            link = root / "link"
            try:
                link.symlink_to(real, target_is_directory=True)
            except (OSError, NotImplementedError):
                self.skipTest("symlink creation unavailable")
            path = real / "exec.jsonl"
            path.write_text("{}\n", encoding="utf-8")
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.load_exec_jsonl(link / "exec.jsonl", repo_root=repo)
        self.assertTrue(
            any("must not traverse symlinks" in e for e in ctx.exception.errors)
        )

    def test_hook_loader_returns_records_and_content_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "hooks.jsonl"
            payload = "\n".join(
                json.dumps(e, sort_keys=True) for e in _hook_records()
            ) + "\n"
            path.write_text(payload, encoding="utf-8")
            records, digest = corr.load_hook_jsonl(path, repo_root=repo)
        self.assertEqual(records, _hook_records())
        self.assertRegex(digest, r"^sha256:[0-9a-f]{64}$")

    def test_hook_size_limit_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "hooks.jsonl"
            path.write_bytes(b"x" * (probe.MAX_JSONL_BYTES + 1))
            with self.assertRaises(corr.CodexJsonlCorrelationError):
                corr.load_hook_jsonl(path, repo_root=repo)

    def test_hook_invalid_utf8_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "hooks.jsonl"
            path.write_bytes(b"\xff\n")
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.load_hook_jsonl(path, repo_root=repo)
        self.assertTrue(
            any("UTF-8 required" in e for e in ctx.exception.errors)
        )

    def test_hook_malformed_json_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "hooks.jsonl"
            path.write_text("{not-json}\n", encoding="utf-8")
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.load_hook_jsonl(path, repo_root=repo)
        self.assertTrue(
            any("invalid JSON" in e for e in ctx.exception.errors)
        )

    def test_hook_record_count_limit_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            path = root / "hooks.jsonl"
            path.write_text(
                "{}\n" * (probe.MAX_JSONL_RECORDS + 1),
                encoding="utf-8",
            )
            with self.assertRaises(corr.CodexJsonlCorrelationError) as ctx:
                corr.load_hook_jsonl(path, repo_root=repo)
        self.assertTrue(
            any("record count exceeds limit" in e for e in ctx.exception.errors)
        )

    def test_loader_returns_content_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "exec.jsonl"
            payload = "\n".join(
                json.dumps(e, sort_keys=True) for e in _exec_events()
            ) + "\n"
            path.write_text(payload, encoding="utf-8")
            events, digest = corr.load_exec_jsonl(path)
        self.assertEqual(events, _exec_events())
        self.assertRegex(digest, r"^sha256:[0-9a-f]{64}$")

    def test_size_limit_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "exec.jsonl"
            path.write_bytes(b"x" * (corr.MAX_EXEC_JSONL_BYTES + 1))
            with self.assertRaises(corr.CodexJsonlCorrelationError):
                corr.load_exec_jsonl(path)


if __name__ == "__main__":
    unittest.main()
