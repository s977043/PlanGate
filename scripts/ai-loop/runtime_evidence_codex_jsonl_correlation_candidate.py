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

__doc__ = """runtime_evidence_codex_jsonl_correlation_candidate.py.

Correlates a reviewed Codex Explorer lifecycle candidate with a bounded
`codex exec --json` JSONL file.

This is intentionally a *pairing candidate*, not proof of co-presence or strong
runtime correlation. Current Codex JSONL evidence observed in this repository
does not carry request_hash/config_sha/provider or the Explorer hook's agent_id,
so unrelated runs could otherwise be paired.

No raw prompt, command text, reasoning, agent message, transcript path, or
runtime log body is copied into the resulting artifact.
"""

import argparse
import hashlib
import json
import pathlib
import re
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-codex-jsonl-correlation-candidate/v1"
HOOK_DOMAIN = "plangate.runtime-r1-codex-probe-candidate/v1"
CONTRACT_STAGE = "r1-codex-jsonl-correlation-candidate-v1"

HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
ID_RE = re.compile(r"^[A-Za-z0-9_.:/-]{1,256}$")
MAX_JSONL_BYTES = 2 * 1024 * 1024
MAX_JSONL_RECORDS = 256
MAX_LINE_BYTES = 256 * 1024

RECOGNIZED_ITEM_TYPES = {
    "command_execution",
    "agent_message",
    "error",
    "reasoning",
}


class CodexJsonlCorrelationError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


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


def _load_json_object(path: pathlib.Path, *, label: str) -> dict[str, Any]:
    if not path.is_file() or path.is_symlink():
        raise CodexJsonlCorrelationError(
            [f"{label}: regular non-symlink file required"]
        )
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise CodexJsonlCorrelationError(
            [f"{label}: cannot read: {exc}"]
        ) from exc
    if len(raw) > MAX_JSONL_BYTES:
        raise CodexJsonlCorrelationError(
            [f"{label}: exceeds 2 MiB limit"]
        )
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise CodexJsonlCorrelationError(
            [f"{label}: invalid JSON"]
        ) from exc
    if not isinstance(value, dict):
        raise CodexJsonlCorrelationError(
            [f"{label}: object required"]
        )
    return value


def validate_hook_candidate(
    candidate: Any,
    *,
    request_hash: str,
    config_sha: str,
    provider: str,
) -> dict[str, Any]:
    errors = _validate_binding(
        request_hash=request_hash,
        config_sha=config_sha,
        provider=provider,
    )
    if not isinstance(candidate, dict):
        errors.append("hook_candidate: object required")
        candidate = {}

    expected = {
        "domain": HOOK_DOMAIN,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "provider": provider,
        "platform": "codex",
        "candidate_trace_structure_verified": True,
        "record_hash_integrity_verified": True,
        "hook_execution_root_attested": False,
        "codex_jsonl_runtime_correlation_verified": False,
        "hard_read_only_enforced": False,
        "runtime_probe_attestation_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
    }
    for key, value in expected.items():
        if candidate.get(key) != value:
            errors.append(
                f"hook_candidate.{key}: exact non-promotion binding required"
            )

    claimed = candidate.get("result_hash")
    if not isinstance(claimed, str) or not HASH_RE.fullmatch(claimed):
        errors.append("hook_candidate.result_hash: canonical sha256 required")
    else:
        body = dict(candidate)
        body.pop("result_hash", None)
        if claimed != ingress._canonical_hash(body):
            errors.append("hook_candidate.result_hash: canonical hash mismatch")

    for key in ("session_id", "turn_id", "agent_id"):
        value = candidate.get(key)
        if not isinstance(value, str) or not ID_RE.fullmatch(value):
            errors.append(
                f"hook_candidate.{key}: bounded identifier required"
            )

    if errors:
        raise CodexJsonlCorrelationError(errors)

    return {
        "session_id": candidate["session_id"],
        "turn_id": candidate["turn_id"],
        "agent_id": candidate["agent_id"],
        "hook_candidate_hash": claimed,
    }


def summarize_codex_jsonl(
    path: str | pathlib.Path,
    *,
    repo_root: str | pathlib.Path,
) -> dict[str, Any]:
    source = pathlib.Path(path)
    root = pathlib.Path(repo_root).resolve()
    if not root.is_dir():
        raise CodexJsonlCorrelationError(
            ["repo_root: existing directory required"]
        )
    if not source.is_file() or source.is_symlink():
        raise CodexJsonlCorrelationError(
            ["codex_jsonl: regular non-symlink file required"]
        )

    resolved = source.resolve()
    try:
        resolved.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False
    if inside_repo:
        raise CodexJsonlCorrelationError(
            ["codex_jsonl: raw runtime trace must stay outside repository"]
        )

    try:
        size = source.stat().st_size
    except OSError as exc:
        raise CodexJsonlCorrelationError(
            [f"codex_jsonl: cannot stat: {exc}"]
        ) from exc
    if size > MAX_JSONL_BYTES:
        raise CodexJsonlCorrelationError(
            ["codex_jsonl: exceeds 2 MiB limit"]
        )

    records = 0
    completed_items = 0
    recognized_counts = {key: 0 for key in sorted(RECOGNIZED_ITEM_TYPES)}
    unrecognized_item_type_count = 0
    item_ids: list[str] = []
    errors: list[str] = []

    try:
        with source.open("rb") as handle:
            for line_number, raw_line in enumerate(handle, start=1):
                if not raw_line.strip():
                    continue
                if records >= MAX_JSONL_RECORDS:
                    errors.append("codex_jsonl: record count exceeds limit")
                    break
                if len(raw_line) > MAX_LINE_BYTES:
                    errors.append(
                        f"codex_jsonl line {line_number}: exceeds 256 KiB limit"
                    )
                    break

                records += 1
                try:
                    value = json.loads(raw_line.decode("utf-8"))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    errors.append(
                        f"codex_jsonl line {line_number}: invalid JSON"
                    )
                    continue
                if not isinstance(value, dict):
                    errors.append(
                        f"codex_jsonl line {line_number}: object required"
                    )
                    continue

                event_type = value.get("type")
                if not isinstance(event_type, str) or len(event_type) > 128:
                    errors.append(
                        f"codex_jsonl line {line_number}: bounded type required"
                    )
                    continue

                if event_type != "item.completed":
                    continue

                item = value.get("item")
                if not isinstance(item, dict):
                    errors.append(
                        f"codex_jsonl line {line_number}: item object required"
                    )
                    continue

                item_id = item.get("id")
                item_type = item.get("type")
                if not isinstance(item_id, str) or not ID_RE.fullmatch(item_id):
                    errors.append(
                        f"codex_jsonl line {line_number}: bounded item.id required"
                    )
                    continue
                if not isinstance(item_type, str) or len(item_type) > 128:
                    errors.append(
                        f"codex_jsonl line {line_number}: bounded item.type required"
                    )
                    continue

                completed_items += 1
                item_ids.append(item_id)
                if item_type in recognized_counts:
                    recognized_counts[item_type] += 1
                else:
                    unrecognized_item_type_count += 1
    except OSError as exc:
        raise CodexJsonlCorrelationError(
            [f"codex_jsonl: cannot read: {exc}"]
        ) from exc

    if records == 0:
        errors.append("codex_jsonl: at least one record required")
    if completed_items == 0:
        errors.append(
            "codex_jsonl: at least one item.completed record required"
        )
    if len(set(item_ids)) != len(item_ids):
        errors.append("codex_jsonl: duplicate item.id is not allowed")

    if errors:
        raise CodexJsonlCorrelationError(errors)

    raw = source.read_bytes()
    return {
        "jsonl_sha256": _sha256_bytes(raw),
        "jsonl_bytes": len(raw),
        "record_count": records,
        "item_completed_count": completed_items,
        "recognized_item_type_counts": recognized_counts,
        "unrecognized_item_type_count": unrecognized_item_type_count,
        "item_id_set_hash": ingress._canonical_hash(sorted(item_ids)),
        "raw_payload_copied": False,
    }


def correlate_candidate(
    *,
    repo_root: str | pathlib.Path,
    hook_candidate: Any,
    codex_jsonl_path: str | pathlib.Path,
    request_hash: str,
    config_sha: str,
    provider: str,
) -> dict[str, Any]:
    hook = validate_hook_candidate(
        hook_candidate,
        request_hash=request_hash,
        config_sha=config_sha,
        provider=provider,
    )
    jsonl = summarize_codex_jsonl(
        codex_jsonl_path,
        repo_root=repo_root,
    )

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "provider": provider,
        "platform": "codex",
        "hook_candidate_hash": hook["hook_candidate_hash"],
        "codex_jsonl_sha256": jsonl["jsonl_sha256"],
        "codex_jsonl_summary": {
            "jsonl_bytes": jsonl["jsonl_bytes"],
            "record_count": jsonl["record_count"],
            "item_completed_count": jsonl["item_completed_count"],
            "recognized_item_type_counts": jsonl[
                "recognized_item_type_counts"
            ],
            "unrecognized_item_type_count": jsonl[
                "unrecognized_item_type_count"
            ],
            "item_id_set_hash": jsonl["item_id_set_hash"],
            "raw_payload_copied": False,
        },
        "cross_source_pairing_candidate": True,
        "same_run_copresence_verified": False,
        "hook_candidate_binding_verified": True,
        "codex_jsonl_structural_candidate_verified": True,
        "direct_agent_id_correlation_available": False,
        "same_run_identity_verified": False,
        "trusted_jsonl_capture_root_attested": False,
        "hook_execution_root_attested": False,
        "codex_jsonl_runtime_correlation_verified": False,
        "hard_read_only_enforced": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "the lifecycle candidate is request/config/provider-bound and "
            "the Codex JSONL is structurally summarized, but current JSONL "
            "evidence carries none of those bindings and no direct Explorer "
            "agent_id join key; co-presence, same-run identity, and independent "
            "capture roots are not verified"
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


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--hook-candidate", required=True)
    parser.add_argument("--codex-jsonl", required=True)
    parser.add_argument("--request-hash", required=True)
    parser.add_argument("--config-sha", required=True)
    parser.add_argument("--provider", required=True)
    args = parser.parse_args(argv)

    try:
        candidate = _load_json_object(
            pathlib.Path(args.hook_candidate),
            label="hook_candidate",
        )
        result = correlate_candidate(
            repo_root=args.repo_root,
            hook_candidate=candidate,
            codex_jsonl_path=args.codex_jsonl,
            request_hash=args.request_hash,
            config_sha=args.config_sha,
            provider=args.provider,
        )
    except CodexJsonlCorrelationError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
