#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """Validate an externally produced Codex managed-capture manifest candidate.

The manifest binds the reviewed #1461 correlation result to claimed managed
policy/recorder hashes. This validator proves structure and content binding only.
It does not prove the managed policy was live, administrator-controlled, signed,
or independently verified. Runtime attestation and dispatch remain false.
"""

import argparse
import hashlib
import json
import pathlib
import re
import stat
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_codex_jsonl_correlation as correlation  # noqa: E402
import runtime_evidence_codex_probe_candidate as probe  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402

DOMAIN = "plangate.runtime-r1-codex-managed-capture-manifest/v1"
CONTRACT_STAGE = "r1-codex-managed-capture-manifest-candidate-v1"
MANIFEST_DOMAIN = "plangate.runtime-r1-codex-managed-capture-claim/v1"
MANIFEST_STAGE = "r1-codex-managed-capture-claim-v1"
EXPECTED_MANAGED_SOURCE = "requirements.toml"
MAX_JSON_BYTES = 256 * 1024
CAPTURE_ID_RE = re.compile(r"^[A-Za-z0-9_.:/-]{1,256}$")

MANIFEST_KEYS = {
    "schema_version", "domain", "contract_stage", "capture_id",
    "request_hash", "config_sha", "provider", "platform",
    "managed_hook_source", "allow_managed_hooks_only_claimed",
    "hooks_feature_pinned_claimed", "managed_policy_sha256",
    "managed_recorder_sha256", "hook_jsonl_sha256", "exec_jsonl_sha256",
    "correlation_result_hash", "hook_session_id", "exec_thread_id",
    "manifest_hash",
}


CORRELATION_KEYS = {
    "schema_version", "domain", "contract_stage", "request_hash", "config_sha",
    "provider", "platform", "runtime_role", "hook_session_id", "hook_turn_id",
    "hook_agent_id", "exec_thread_id", "hook_jsonl_sha256", "exec_jsonl_sha256",
    "trace_content_binding_verified", "exec_jsonl_structure_verified",
    "identifier_value_match_verified", "hook_session_id_equals_exec_thread_id",
    "session_thread_semantic_binding_verified", "parent_thread_correlation_candidate",
    "parent_thread_correlation_verified", "thread_id_correlation_verified",
    "single_turn_envelope_verified",
    "explicit_forbidden_item_type_absence_verified",
    "documented_item_schema_coverage_complete", "undocumented_item_type_count",
    "command_execution_read_only_verified", "mcp_tool_read_only_verified",
    "repository_postcondition_verified", "turn_id_exposed_in_exec_jsonl",
    "turn_id_correlation_verified", "subagent_identity_exposed_in_exec_jsonl",
    "subagent_identity_correlation_verified", "same_subagent_execution_correlated",
    "hook_execution_root_attested", "codex_jsonl_thread_correlation_verified",
    "codex_jsonl_runtime_correlation_verified", "hard_read_only_enforced",
    "runtime_probe_attestation_verified", "human_rollout_decision_verified",
    "dispatch_ready", "dispatch_allowed", "verification_limit", "event_summary",
    "authority", "result_hash",
}
AUTHORITY_KEYS = {
    "agent_invoke_allowed", "code_write_allowed", "approval_write_allowed",
    "merge_allowed", "deploy_allowed",
}

class ManagedCaptureManifestError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _require_external_regular_file(path, repo_root, field) -> pathlib.Path:
    root = pathlib.Path(repo_root).resolve()
    source = pathlib.Path(path)
    if not source.is_absolute():
        raise ManagedCaptureManifestError([f"{field}: absolute path required"])
    raw_parent = source.parent
    parent = raw_parent.resolve()
    target = source.resolve(strict=False)
    if not root.is_dir():
        raise ManagedCaptureManifestError(["repo_root: existing directory required"])
    if not raw_parent.is_dir():
        raise ManagedCaptureManifestError([f"{field}: parent directory must exist"])
    if parent != raw_parent:
        raise ManagedCaptureManifestError(
            [f"{field}: parent path must not traverse symlinks"]
        )
    if not source.exists():
        raise ManagedCaptureManifestError([f"{field}: file must exist"])
    mode = source.lstat().st_mode
    if stat.S_ISLNK(mode):
        raise ManagedCaptureManifestError([f"{field}: file symlink is not allowed"])
    if not stat.S_ISREG(mode):
        raise ManagedCaptureManifestError([f"{field}: regular file required"])
    try:
        target.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False
    if inside_repo:
        raise ManagedCaptureManifestError(
            [f"{field}: runtime artifact must stay outside repository"]
        )
    return source


def _strict_json_loads(text: str, field: str) -> Any:
    def pairs_hook(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ManagedCaptureManifestError(
                    [f"{field}: duplicate JSON key {key!r}"]
                )
            result[key] = value
        return result

    def reject_constant(value: str):
        raise ManagedCaptureManifestError(
            [f"{field}: non-finite JSON number {value!r} not allowed"]
        )

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs_hook,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise ManagedCaptureManifestError([f"{field}: invalid JSON"]) from exc


def load_json_object(path, *, repo_root, field) -> tuple[dict[str, Any], str]:
    source = _require_external_regular_file(path, repo_root, field)
    try:
        raw = source.read_bytes()
    except OSError as exc:
        raise ManagedCaptureManifestError([f"{field}: cannot read: {exc}"]) from exc
    if len(raw) > MAX_JSON_BYTES:
        raise ManagedCaptureManifestError([f"{field}: file exceeds 256 KiB limit"])
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ManagedCaptureManifestError([f"{field}: UTF-8 required"]) from exc
    value = _strict_json_loads(text, field)
    if not isinstance(value, dict):
        raise ManagedCaptureManifestError([f"{field}: JSON object required"])
    return value, _sha256_bytes(raw)


def _validate_correlation_result(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["correlation_result: object required"]
    errors: list[str] = []
    unknown = sorted(set(value) - CORRELATION_KEYS)
    missing = sorted(CORRELATION_KEYS - set(value))
    if unknown:
        errors.append(f"correlation_result: unsupported keys: {unknown}")
    if missing:
        errors.append(f"correlation_result: missing keys: {missing}")
    if value.get("domain") != correlation.DOMAIN:
        errors.append("correlation_result.domain: exact #1461 domain required")
    if value.get("contract_stage") != correlation.CONTRACT_STAGE:
        errors.append(
            "correlation_result.contract_stage: exact #1461 stage required"
        )

    body = dict(value)
    claimed_hash = body.pop("result_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("correlation_result.result_hash: canonical hash mismatch")

    required_true = (
        "trace_content_binding_verified",
        "exec_jsonl_structure_verified",
        "identifier_value_match_verified",
        "hook_session_id_equals_exec_thread_id",
        "parent_thread_correlation_candidate",
        "single_turn_envelope_verified",
    )
    for field in required_true:
        if value.get(field) is not True:
            errors.append(f"correlation_result.{field}: true required")

    required_false = (
        "session_thread_semantic_binding_verified",
        "parent_thread_correlation_verified",
        "thread_id_correlation_verified",
        "same_subagent_execution_correlated",
        "hook_execution_root_attested",
        "codex_jsonl_thread_correlation_verified",
        "codex_jsonl_runtime_correlation_verified",
        "hard_read_only_enforced",
        "runtime_probe_attestation_verified",
        "human_rollout_decision_verified",
        "dispatch_ready",
        "dispatch_allowed",
    )
    for field in required_false:
        if value.get(field) is not False:
            errors.append(f"correlation_result.{field}: false required")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append("correlation_result.authority: object required")
    else:
        unknown_authority = sorted(set(authority) - AUTHORITY_KEYS)
        missing_authority = sorted(AUTHORITY_KEYS - set(authority))
        if unknown_authority or missing_authority:
            errors.append("correlation_result.authority: exact key set required")
        if any(authority.get(field) is not False for field in AUTHORITY_KEYS):
            errors.append("correlation_result.authority: all values must remain false")
    return errors


def _validate_manifest(manifest: Any, upstream: dict[str, Any]) -> list[str]:
    if not isinstance(manifest, dict):
        return ["capture_manifest: object required"]
    errors: list[str] = []
    unknown = sorted(set(manifest) - MANIFEST_KEYS)
    missing = sorted(MANIFEST_KEYS - set(manifest))
    if unknown:
        errors.append(f"capture_manifest: unsupported keys: {unknown}")
    if missing:
        errors.append(f"capture_manifest: missing keys: {missing}")

    if manifest.get("schema_version") != "1":
        errors.append("capture_manifest.schema_version: 1 required")
    if manifest.get("domain") != MANIFEST_DOMAIN:
        errors.append("capture_manifest.domain: exact managed-capture claim required")
    if manifest.get("contract_stage") != MANIFEST_STAGE:
        errors.append("capture_manifest.contract_stage: exact claim stage required")
    capture_id = manifest.get("capture_id")
    if not isinstance(capture_id, str) or not CAPTURE_ID_RE.fullmatch(capture_id):
        errors.append("capture_manifest.capture_id: bounded opaque id required")

    for field in (
        "request_hash", "config_sha", "managed_policy_sha256",
        "managed_recorder_sha256", "hook_jsonl_sha256", "exec_jsonl_sha256",
        "correlation_result_hash",
    ):
        value = manifest.get(field)
        if not isinstance(value, str) or not probe.HASH_RE.fullmatch(value):
            errors.append(
                f"capture_manifest.{field}: sha256:<64 lowercase hex> required"
            )

    if manifest.get("platform") != "codex":
        errors.append("capture_manifest.platform: codex required")
    provider = manifest.get("provider")
    if not isinstance(provider, str) or not ingress.PROVIDER_RE.fullmatch(provider):
        errors.append("capture_manifest.provider: provider-neutral identifier required")
    if manifest.get("managed_hook_source") != EXPECTED_MANAGED_SOURCE:
        errors.append(
            "capture_manifest.managed_hook_source: requirements.toml required"
        )
    if manifest.get("allow_managed_hooks_only_claimed") is not True:
        errors.append(
            "capture_manifest.allow_managed_hooks_only_claimed: true required"
        )
    if manifest.get("hooks_feature_pinned_claimed") is not True:
        errors.append(
            "capture_manifest.hooks_feature_pinned_claimed: true required"
        )

    for field in ("hook_session_id", "exec_thread_id"):
        value = manifest.get(field)
        if not isinstance(value, str) or not correlation.ID_RE.fullmatch(value):
            errors.append(f"capture_manifest.{field}: bounded identifier required")

    bindings = {
        "request_hash": "request_hash",
        "config_sha": "config_sha",
        "provider": "provider",
        "hook_jsonl_sha256": "hook_jsonl_sha256",
        "exec_jsonl_sha256": "exec_jsonl_sha256",
        "correlation_result_hash": "result_hash",
        "hook_session_id": "hook_session_id",
        "exec_thread_id": "exec_thread_id",
    }
    for manifest_field, result_field in bindings.items():
        if manifest.get(manifest_field) != upstream.get(result_field):
            errors.append(
                f"capture_manifest.{manifest_field}: exact correlation binding required"
            )
    if manifest.get("hook_session_id") != manifest.get("exec_thread_id"):
        errors.append(
            "capture_manifest: hook_session_id and exec_thread_id values must match"
        )

    body = dict(manifest)
    claimed_hash = body.pop("manifest_hash", None)
    if claimed_hash != ingress._canonical_hash(body):
        errors.append("capture_manifest.manifest_hash: canonical hash mismatch")
    return errors


def verify_candidate(*, correlation_result: Any, capture_manifest: Any) -> dict[str, Any]:
    errors = _validate_correlation_result(correlation_result)
    if isinstance(correlation_result, dict):
        errors.extend(_validate_manifest(capture_manifest, correlation_result))
    else:
        errors.append("capture_manifest: cannot bind invalid correlation result")
    if errors:
        raise ManagedCaptureManifestError(errors)

    result = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "request_hash": correlation_result["request_hash"],
        "config_sha": correlation_result["config_sha"],
        "provider": correlation_result["provider"],
        "platform": "codex",
        "capture_id": capture_manifest["capture_id"],
        "managed_hook_source_claim": capture_manifest["managed_hook_source"],
        "managed_policy_sha256": capture_manifest["managed_policy_sha256"],
        "managed_recorder_sha256": capture_manifest["managed_recorder_sha256"],
        "hook_jsonl_sha256": capture_manifest["hook_jsonl_sha256"],
        "exec_jsonl_sha256": capture_manifest["exec_jsonl_sha256"],
        "correlation_result_hash": capture_manifest["correlation_result_hash"],
        "capture_manifest_hash": capture_manifest["manifest_hash"],
        "capture_manifest_structure_verified": True,
        "capture_manifest_content_binding_verified": True,
        "capture_manifest_cross_binding_verified": True,
        "managed_hooks_only_claim_candidate": True,
        "hooks_feature_pinned_claim_candidate": True,
        "same_run_binding_manifest_candidate": True,
        "managed_hook_source_runtime_verified": False,
        "managed_policy_live_verified": False,
        "managed_recorder_binary_verified": False,
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
        "verification_limit": (
            "the manifest binds the reviewed correlation/hash identifiers and "
            "claims a requirements.toml managed-only policy, but this repository "
            "verifier cannot prove the managed policy/recorder was live, "
            "administrator-controlled, signed, or independently verified"
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
    parser.add_argument("--correlation-json", required=True)
    parser.add_argument("--capture-manifest", required=True)
    args = parser.parse_args(argv)
    try:
        upstream, _ = load_json_object(
            args.correlation_json,
            repo_root=args.repo_root,
            field="correlation_json",
        )
        manifest, _ = load_json_object(
            args.capture_manifest,
            repo_root=args.repo_root,
            field="capture_manifest",
        )
        result = verify_candidate(
            correlation_result=upstream,
            capture_manifest=manifest,
        )
    except ManagedCaptureManifestError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
