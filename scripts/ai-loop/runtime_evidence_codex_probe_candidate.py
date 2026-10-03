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

__doc__ = """runtime_evidence_codex_probe_candidate.py — Codex R1 probe candidate.

This module validates Codex lifecycle-hook observations for one Explorer
subagent attempt. It deliberately stops at candidate evidence.

Why candidate-only:
- SubagentStart/SubagentStop are useful runtime observations.
- A repository/project hook is not an independently trusted execution root.
- The model/runtime can potentially reproduce the recorder invocation shape.
- Therefore these records cannot by themselves establish strong attestation.

No function here dispatches an agent or grants mutation authority.
"""

import argparse
import copy
import json
import os
import pathlib
import re
import stat
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-codex-probe-candidate/v1"
RECORD_DOMAIN = "plangate.runtime-r1-codex-hook-observation/v1"
CONTRACT_STAGE = "r1-codex-probe-candidate-v1"

HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
ID_RE = re.compile(r"^[A-Za-z0-9_.:/-]{1,256}$")
VALID_EVENTS = {"SubagentStart", "SubagentStop"}
VALID_PERMISSION_MODES = {
    "default",
    "acceptEdits",
    "plan",
    "dontAsk",
    "bypassPermissions",
}
EXPECTED_AGENT_TYPE = "explorer_agent"


class CodexProbeCandidateError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _validate_binding(
    *,
    request_hash: Any,
    config_sha: Any,
    provider: Any,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(request_hash, str) or not HASH_RE.fullmatch(request_hash):
        errors.append("request_hash: sha256:<64 lowercase hex> required")
    if not isinstance(config_sha, str) or not HASH_RE.fullmatch(config_sha):
        errors.append("config_sha: sha256:<64 lowercase hex> required")
    if not isinstance(provider, str) or not ingress.PROVIDER_RE.fullmatch(provider):
        errors.append("provider: provider-neutral identifier required")
    return errors


def normalize_hook_event(
    *,
    event: Any,
    request_hash: str,
    config_sha: str,
    provider: str,
) -> dict[str, Any]:
    errors = _validate_binding(
        request_hash=request_hash,
        config_sha=config_sha,
        provider=provider,
    )
    if not isinstance(event, dict):
        errors.append("hook event: object required")
        event = {}

    event_name = event.get("hook_event_name")
    if event_name not in VALID_EVENTS:
        errors.append(
            f"hook_event_name: one of {sorted(VALID_EVENTS)} required"
        )

    expected_keys = {
        "session_id",
        "transcript_path",
        "cwd",
        "hook_event_name",
        "model",
        "turn_id",
        "agent_id",
        "agent_type",
        "permission_mode",
        "agent_transcript_path",
        "stop_hook_active",
        "last_assistant_message",
    }
    unknown = sorted(set(event) - expected_keys)
    if unknown:
        errors.append(f"hook event: unsupported keys: {unknown}")

    for field in ("session_id", "turn_id", "agent_id"):
        value = event.get(field)
        if not isinstance(value, str) or not ID_RE.fullmatch(value):
            errors.append(f"{field}: bounded identifier required")

    if event.get("agent_type") != EXPECTED_AGENT_TYPE:
        errors.append(
            f"agent_type: exact {EXPECTED_AGENT_TYPE} required"
        )

    permission_mode = event.get("permission_mode")
    if permission_mode not in VALID_PERMISSION_MODES:
        errors.append(
            "permission_mode: documented Codex permission mode required"
        )

    if event_name == "SubagentStop":
        if not isinstance(event.get("stop_hook_active"), bool):
            errors.append("stop_hook_active: boolean required on SubagentStop")
        transcript = event.get("agent_transcript_path")
        if transcript is not None and not isinstance(transcript, str):
            errors.append(
                "agent_transcript_path: string|null required on SubagentStop"
            )

    if errors:
        raise CodexProbeCandidateError(errors)

    normalized = {
        "schema_version": "1",
        "domain": RECORD_DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "provider": provider,
        "platform": "codex",
        "hook_event_name": event_name,
        "session_id": event["session_id"],
        "turn_id": event["turn_id"],
        "agent_id": event["agent_id"],
        "agent_type": event["agent_type"],
        "permission_mode": permission_mode,
        "model": event.get("model"),
    }
    if event_name == "SubagentStop":
        normalized["stop_hook_active"] = event["stop_hook_active"]
        normalized["agent_transcript_path_present"] = bool(
            event.get("agent_transcript_path")
        )
        normalized["last_assistant_message_present"] = bool(
            event.get("last_assistant_message")
        )

    normalized["record_hash"] = ingress._canonical_hash(normalized)
    return normalized


def _safe_append_jsonl(path: pathlib.Path, record: dict[str, Any]) -> None:
    parent = path.parent
    parent.mkdir(parents=True, exist_ok=True)
    if parent.is_symlink():
        raise CodexProbeCandidateError(
            ["output parent symlink is not allowed"]
        )

    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags, 0o600)
    except OSError as exc:
        raise CodexProbeCandidateError(
            [f"output: cannot open safely: {exc}"]
        ) from exc

    try:
        mode = os.fstat(fd).st_mode
        if not stat.S_ISREG(mode):
            raise CodexProbeCandidateError(
                ["output: regular file required"]
            )
        payload = (
            json.dumps(
                record,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        ).encode("utf-8")
        os.write(fd, payload)
        os.fsync(fd)
    finally:
        os.close(fd)


def record_hook_event(
    *,
    output: str | pathlib.Path,
    event: Any,
    request_hash: str,
    config_sha: str,
    provider: str,
) -> dict[str, Any]:
    record = normalize_hook_event(
        event=event,
        request_hash=request_hash,
        config_sha=config_sha,
        provider=provider,
    )
    _safe_append_jsonl(pathlib.Path(output), record)
    return record


def _validate_record(
    record: Any,
    *,
    request_hash: str,
    config_sha: str,
    provider: str,
    index: int,
) -> list[str]:
    prefix = f"records[{index}]"
    if not isinstance(record, dict):
        return [f"{prefix}: object required"]

    errors: list[str] = []
    if record.get("domain") != RECORD_DOMAIN:
        errors.append(f"{prefix}.domain: {RECORD_DOMAIN} required")
    if record.get("contract_stage") != CONTRACT_STAGE:
        errors.append(
            f"{prefix}.contract_stage: {CONTRACT_STAGE} required"
        )
    if record.get("request_hash") != request_hash:
        errors.append(f"{prefix}.request_hash: exact binding required")
    if record.get("config_sha") != config_sha:
        errors.append(f"{prefix}.config_sha: exact binding required")
    if record.get("provider") != provider:
        errors.append(f"{prefix}.provider: exact binding required")
    if record.get("platform") != "codex":
        errors.append(f"{prefix}.platform: codex required")
    if record.get("agent_type") != EXPECTED_AGENT_TYPE:
        errors.append(
            f"{prefix}.agent_type: {EXPECTED_AGENT_TYPE} required"
        )

    body = copy.deepcopy(record)
    claimed = body.pop("record_hash", None)
    if claimed != ingress._canonical_hash(body):
        errors.append(f"{prefix}.record_hash: canonical hash mismatch")

    return errors


def verify_candidate_trace(
    *,
    records: Any,
    request_hash: str,
    config_sha: str,
    provider: str,
) -> dict[str, Any]:
    errors = _validate_binding(
        request_hash=request_hash,
        config_sha=config_sha,
        provider=provider,
    )
    if not isinstance(records, list):
        errors.append("records: array required")
        records = []

    for index, record in enumerate(records):
        errors.extend(
            _validate_record(
                record,
                request_hash=request_hash,
                config_sha=config_sha,
                provider=provider,
                index=index,
            )
        )

    starts = [
        record
        for record in records
        if isinstance(record, dict)
        and record.get("hook_event_name") == "SubagentStart"
    ]
    stops = [
        record
        for record in records
        if isinstance(record, dict)
        and record.get("hook_event_name") == "SubagentStop"
    ]

    if len(starts) != 1:
        errors.append("trace: exactly one Explorer SubagentStart required")
    if len(stops) != 1:
        errors.append("trace: exactly one Explorer SubagentStop required")

    if len(starts) == 1 and len(stops) == 1:
        start = starts[0]
        stop = stops[0]
        for field in ("session_id", "turn_id", "agent_id", "agent_type"):
            if start.get(field) != stop.get(field):
                errors.append(
                    f"trace: start/stop {field} must match exactly"
                )

    if errors:
        raise CodexProbeCandidateError(errors)

    start = starts[0]
    stop = stops[0]
    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "provider": provider,
        "platform": "codex",
        "runtime_role": EXPECTED_AGENT_TYPE,
        "session_id": start["session_id"],
        "turn_id": start["turn_id"],
        "agent_id": start["agent_id"],
        "permission_mode": start["permission_mode"],
        "subagent_start_candidate_verified": True,
        "subagent_stop_candidate_verified": True,
        "runtime_role_registered_candidate": True,
        "explorer_execution_candidate": True,
        "hook_trace_integrity_verified": True,
        "hook_execution_root_attested": False,
        "codex_jsonl_runtime_correlation_verified": False,
        "hard_read_only_enforced": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "project hook records are runtime observations but are not an "
            "independently trusted execution root; Codex JSONL correlation "
            "and external hook-root attestation are still required"
        ),
        "authority": {
            "agent_invoke_allowed": False,
            "code_write_allowed": False,
            "approval_write_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }
    result["result_hash"] = ingress._canonical_hash(result)
    return result


def load_jsonl(path: str | pathlib.Path) -> list[Any]:
    values: list[Any] = []
    source = pathlib.Path(path)
    try:
        with source.open("r", encoding="utf-8") as handle:
            for line_number, line in enumerate(handle, start=1):
                stripped = line.strip()
                if not stripped:
                    continue
                try:
                    values.append(json.loads(stripped))
                except json.JSONDecodeError as exc:
                    raise CodexProbeCandidateError(
                        [f"jsonl line {line_number}: invalid JSON"]
                    ) from exc
    except OSError as exc:
        raise CodexProbeCandidateError(
            [f"jsonl: cannot read: {exc}"]
        ) from exc
    return values


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    record = sub.add_parser("record-hook")
    record.add_argument("--output", required=True)
    record.add_argument("--request-hash", required=True)
    record.add_argument("--config-sha", required=True)
    record.add_argument("--provider", required=True)

    verify = sub.add_parser("verify-candidate")
    verify.add_argument("--jsonl", required=True)
    verify.add_argument("--request-hash", required=True)
    verify.add_argument("--config-sha", required=True)
    verify.add_argument("--provider", required=True)

    args = parser.parse_args(argv)

    try:
        if args.command == "record-hook":
            event = json.load(sys.stdin)
            result = record_hook_event(
                output=args.output,
                event=event,
                request_hash=args.request_hash,
                config_sha=args.config_sha,
                provider=args.provider,
            )
        else:
            result = verify_candidate_trace(
                records=load_jsonl(args.jsonl),
                request_hash=args.request_hash,
                config_sha=args.config_sha,
                provider=args.provider,
            )
    except (
        CodexProbeCandidateError,
        json.JSONDecodeError,
    ) as exc:
        if isinstance(exc, CodexProbeCandidateError):
            for error in exc.errors:
                print(f"ERROR: {error}", file=sys.stderr)
        else:
            print(f"ERROR: invalid hook JSON: {exc}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
