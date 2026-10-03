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

__doc__ = """runtime_evidence_ingress.py — external runtime evidence R0 ingress (#1448).

R0 contract:
- deterministic / stdlib-only / network-free
- provider payload is untrusted data, never workflow instructions
- authenticate/replay/redaction/secret-scan assertions are caller inputs and fail closed
- provider-specific payload -> sanitized immutable source snapshot
- source snapshot -> existing #1442/#1443 admission signal
- no Agent invocation, Issue/PBI write, code write, RunState/RunEvidence mutation,
  approval, merge, deploy, or publish authority

This module does not fetch provider APIs. Provider transport/authentication belongs to
an outer adapter. The first reference mapper is Cloudflare runtime issues.
"""

import hashlib
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

import pbi_materializer as pm  # noqa: E402


PROVIDER_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
MAX_STATEMENT_CHARS = 500

FORBIDDEN_INPUT_KEYS = {
    "authorization",
    "api_key",
    "access_token",
    "refresh_token",
    "cookie",
    "set_cookie",
    "session_id",
    "customer_payload",
    "request_body",
    "response_body",
    "raw_body",
    "raw_payload",
    "raw_response",
    "command_output",
    "stdout",
    "stderr",
    "full_stack_trace",
    "stack_trace",
    "user_prompt",
    "system_prompt",
    "hidden_cot",
    "chain_of_thought",
}

# Cloudflare Workers Issues documented statuses (2026-09-30):
# Active / Resolved / Ignored. Recurrence is an automation trigger, not a status.
CLOUDFLARE_STATUS_TO_DISPOSITION = {
    "active": "actionable",
    "resolved": "resolved",
    "ignored": "informational",
}


class RuntimeIngressError(ValueError):
    """Fail-closed validation error with machine-readable error strings."""

    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _norm_key(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    return value.strip().lower().replace("-", "_")


def _walk(value: Any, path: str = "$"):
    if isinstance(value, dict):
        for key, child in value.items():
            yield path, str(key), child
            yield from _walk(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _walk(child, f"{path}[{index}]")


def _forbidden_input_errors(value: Any) -> list[str]:
    errors: list[str] = []
    for path, key, _child in _walk(value):
        if _norm_key(key) in FORBIDDEN_INPUT_KEYS:
            errors.append(f"privacy: forbidden runtime input key {path}.{key}")
    return errors


def _sha256_text(value: str) -> str:
    return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def _canonical_hash(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def _require_rfc3339(value: Any, field: str, errors: list[str]) -> str:
    if not isinstance(value, str) or pm._parse_rfc3339(value) is None:
        errors.append(f"{field}: timezone-aware RFC3339 required")
        return ""
    return value


def _require_nonempty_string(
    value: Any,
    field: str,
    errors: list[str],
    *,
    max_chars: int | None = None,
) -> str:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{field}: non-empty string required")
        return ""
    clean = value.strip()
    if max_chars is not None and len(clean) > max_chars:
        errors.append(f"{field}: must be <= {max_chars} chars")
    return clean


def _require_bool(value: Any, field: str, errors: list[str]) -> bool:
    if not isinstance(value, bool):
        errors.append(f"{field}: boolean required")
        return False
    return value


def _validate_envelope(envelope: Any) -> list[str]:
    if not isinstance(envelope, dict):
        return ["envelope: object required"]

    errors = _forbidden_input_errors(envelope)
    authenticated = _require_bool(
        envelope.get("authenticated"), "envelope.authenticated", errors
    )
    replayed = _require_bool(envelope.get("replayed"), "envelope.replayed", errors)
    redaction_applied = _require_bool(
        envelope.get("redaction_applied"),
        "envelope.redaction_applied",
        errors,
    )
    secret_scan = envelope.get("secret_scan")

    if authenticated is not True:
        errors.append("envelope.authenticated: true required")
    if replayed is True:
        errors.append("envelope.replayed: replayed event rejected")
    if redaction_applied is not True:
        errors.append("envelope.redaction_applied: true required")
    if secret_scan != "pass":
        errors.append("envelope.secret_scan: pass required")

    return errors


def _normalize_provider(value: Any, errors: list[str]) -> str:
    provider = _require_nonempty_string(value, "provider", errors).lower()
    if provider and not PROVIDER_RE.fullmatch(provider):
        errors.append("provider: lowercase enum-like provider name required")
    return provider


def _logical_intake_identity(
    *,
    provider: str,
    environment: str,
    issue_fingerprint: str,
    deployment_ref: str | None,
) -> str:
    """Stable logical identity for dedup. Event IDs and occurrence counts are excluded."""
    return _canonical_hash(
        {
            "provider": provider,
            "environment": environment,
            "issue_fingerprint": issue_fingerprint,
            "deployment_ref": deployment_ref or "unavailable",
        }
    )


def _event_ref(provider: str, event_id: str) -> str:
    return _sha256_text(f"{provider}:{event_id}")


def _evidence_instance_ref(provider: str, event_id: str, captured_at: str) -> str:
    """Immutable point-in-time evidence identity.

    Provider issue IDs may be stable while occurrence counters change over time.
    captured_at therefore participates in the immutable evidence identity.
    """
    return _sha256_text(f"{provider}:{event_id}:{captured_at}")


def _snapshot_ref(
    provider: str,
    intake_identity: str,
    snapshot_hash: str,
) -> str:
    """Content-addressed repository ref for one immutable sanitized snapshot."""
    intake_digest = intake_identity.split(":", 1)[1]
    content_digest = snapshot_hash.split(":", 1)[1]
    return (
        "docs/working/_runtime-ingress/"
        f"{provider}/{intake_digest}/{content_digest}.json"
    )


def _bounded_ref_list(value: Any, field: str, errors: list[str]) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        errors.append(f"{field}: array required")
        return []
    refs: list[str] = []
    for index, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            errors.append(f"{field}[{index}]: non-empty opaque ref required")
            continue
        clean = item.strip()
        if len(clean) > 256:
            errors.append(f"{field}[{index}]: ref too long")
            continue
        if "://" in clean:
            errors.append(f"{field}[{index}]: raw URL not allowed; use opaque ref")
            continue
        refs.append(clean)
    return refs



def _validate_source_output_ref(source_ref: Any, provider: str) -> str:
    errors = pm._validate_repo_relative_ref_syntax(source_ref, "source_ref")
    if errors:
        raise RuntimeIngressError(errors)
    assert isinstance(source_ref, str)
    clean = source_ref.strip()
    prefix = f"docs/working/_runtime-ingress/{provider}/"
    if not clean.startswith(prefix):
        raise RuntimeIngressError([
            f"source_ref: must remain under {prefix}"
        ])
    if clean.endswith("/"):
        raise RuntimeIngressError(["source_ref: file ref required"])
    return clean


def _ensure_safe_parent(root: pathlib.Path, target: pathlib.Path) -> None:
    root = root.resolve()
    try:
        relative = target.parent.relative_to(root)
    except ValueError as exc:
        raise RuntimeIngressError(["source_ref: output escapes repository root"]) from exc

    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        if cursor.exists() or cursor.is_symlink():
            mode = cursor.lstat().st_mode
            if stat.S_ISLNK(mode):
                raise RuntimeIngressError([
                    f"source_ref: output parent contains symlink: {cursor.relative_to(root)}"
                ])
            if not stat.S_ISDIR(mode):
                raise RuntimeIngressError([
                    f"source_ref: output parent is not directory: {cursor.relative_to(root)}"
                ])
        else:
            cursor.mkdir(mode=0o755)



def _validate_mapped_snapshot_for_persist(mapped: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    provider = mapped.get("provider")
    snapshot = mapped.get("source_snapshot")
    if not isinstance(provider, str) or not PROVIDER_RE.fullmatch(provider):
        errors.append("mapped.provider: valid provider required")
        return errors
    if not isinstance(snapshot, dict):
        errors.append("mapped.source_snapshot: object required")
        return errors

    errors.extend(_forbidden_input_errors(snapshot))
    errors.extend(
        f"snapshot privacy: {error}"
        for error in pm._privacy_errors({"runtime_ingress_source": snapshot})
    )

    if snapshot.get("domain") != "plangate.runtime-ingress-source/v1":
        errors.append("mapped.source_snapshot.domain: runtime ingress v1 required")
    if snapshot.get("mode") != "r0_shadow":
        errors.append("mapped.source_snapshot.mode: r0_shadow required")

    source = snapshot.get("runtime_source")
    if not isinstance(source, dict):
        errors.append("mapped.source_snapshot.runtime_source: object required")
        return errors

    if source.get("provider") != provider:
        errors.append("mapped.source_snapshot.runtime_source.provider: mismatch")

    # Validate the repository namespace independently from content-address
    # identity so callers receive both safety boundaries rather than only the
    # later hash-binding mismatch.
    try:
        _validate_source_output_ref(mapped.get("source_ref"), provider)
    except RuntimeIngressError as exc:
        errors.extend(exc.errors)

    redaction = source.get("redaction")
    if not isinstance(redaction, dict):
        errors.append("mapped.source_snapshot.runtime_source.redaction: object required")
    else:
        if redaction.get("applied") is not True:
            errors.append("mapped.source_snapshot.redaction.applied: true required")
        if redaction.get("secret_scan") != "pass":
            errors.append("mapped.source_snapshot.redaction.secret_scan: pass required")

    intake_identity = source.get("intake_identity")
    evidence_instance_ref = source.get("evidence_instance_ref")
    if not isinstance(intake_identity, str) or not intake_identity.startswith("sha256:"):
        errors.append("mapped.source_snapshot.intake_identity: sha256 ref required")
    if not isinstance(evidence_instance_ref, str) or not evidence_instance_ref.startswith("sha256:"):
        errors.append("mapped.source_snapshot.evidence_instance_ref: sha256 ref required")

    canonical_snapshot_hash = _canonical_hash(snapshot)
    if mapped.get("snapshot_hash") != canonical_snapshot_hash:
        errors.append("mapped.snapshot_hash: source snapshot hash mismatch")

    if (
        isinstance(intake_identity, str)
        and intake_identity.startswith("sha256:")
    ):
        expected_ref = _snapshot_ref(
            provider,
            intake_identity,
            canonical_snapshot_hash,
        )
        if mapped.get("source_ref") != expected_ref:
            errors.append(
                "mapped.source_ref: does not match content-addressed snapshot hash"
            )

    authority = snapshot.get("authority")
    if not isinstance(authority, dict):
        errors.append("mapped.source_snapshot.authority: object required")
    elif any(value is not False for value in authority.values()):
        errors.append("mapped.source_snapshot.authority: all mutation/agent authority must be false")

    return errors


def persist_source_snapshot(
    repo_root: str | pathlib.Path,
    mapped: dict[str, Any],
) -> dict[str, Any]:
    """Create or idempotently reuse one immutable sanitized source snapshot.

    This is the only write authority in R0. It cannot modify an existing divergent
    artifact and cannot write outside docs/working/_runtime-ingress/<provider>/.
    """
    if not isinstance(mapped, dict):
        raise RuntimeIngressError(["mapped: object required"])
    validation_errors = _validate_mapped_snapshot_for_persist(mapped)
    if validation_errors:
        raise RuntimeIngressError(validation_errors)

    provider = mapped["provider"]
    snapshot = mapped["source_snapshot"]
    source_ref = _validate_source_output_ref(mapped.get("source_ref"), provider)
    root = pathlib.Path(repo_root).resolve()
    if not root.is_dir():
        raise RuntimeIngressError(["repo_root: existing directory required"])
    if not (root / "docs").is_dir() or not (root / "scripts").is_dir():
        raise RuntimeIngressError([
            "repo_root: repository shape requires docs/ and scripts/"
        ])

    target = root / pathlib.PurePosixPath(source_ref)
    _ensure_safe_parent(root, target)

    payload = (
        json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")
    expected_hash = _canonical_hash(snapshot)

    temp_name = (
        f".{target.name}.{os.getpid()}."
        f"{expected_hash.split(':', 1)[1][:12]}.tmp"
    )
    final_name = target.name

    dir_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    dir_flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        dir_fd = os.open(target.parent, dir_flags)
    except OSError as exc:
        raise RuntimeIngressError([
            f"source_ref: output parent cannot be opened safely: {exc}"
        ]) from exc

    file_fd = None
    reused = False
    try:
        try:
            file_fd = os.open(
                temp_name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o600,
                dir_fd=dir_fd,
            )
        except FileExistsError as exc:
            raise RuntimeIngressError([
                f"source_ref: stale temp artifact exists for {source_ref}"
            ]) from exc

        with os.fdopen(file_fd, "wb", closefd=True) as handle:
            file_fd = None
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())

        try:
            os.link(
                temp_name,
                final_name,
                src_dir_fd=dir_fd,
                dst_dir_fd=dir_fd,
                follow_symlinks=False,
            )
        except FileExistsError:
            read_flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
            try:
                existing_fd = os.open(final_name, read_flags, dir_fd=dir_fd)
            except OSError as exc:
                raise RuntimeIngressError([
                    f"source_ref: existing artifact cannot be opened safely: {exc}"
                ]) from exc
            try:
                mode = os.fstat(existing_fd).st_mode
                if not stat.S_ISREG(mode):
                    raise RuntimeIngressError([
                        f"source_ref: existing artifact is not regular file: {source_ref}"
                    ])
                with os.fdopen(existing_fd, "rb", closefd=True) as handle:
                    existing_fd = -1
                    existing = handle.read()
            finally:
                if existing_fd >= 0:
                    os.close(existing_fd)

            if existing != payload:
                raise RuntimeIngressError([
                    f"source_ref: immutable artifact differs on retry: {source_ref}"
                ])
            reused = True

        os.fsync(dir_fd)
    finally:
        if file_fd is not None:
            os.close(file_fd)
        try:
            os.unlink(temp_name, dir_fd=dir_fd)
        except FileNotFoundError:
            pass
        os.close(dir_fd)

    return {
        "mode": "r0_shadow_source_persist",
        "source_ref": source_ref,
        "source_hash": expected_hash,
        "artifact_reused": reused,
        "authority": {
            "evidence_create_allowed": True,
            "overwrite_allowed": False,
            "agent_invoke_allowed": False,
            "pbi_write_allowed": False,
            "issue_write_allowed": False,
            "code_write_allowed": False,
            "approval_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }


def map_cloudflare_issue(
    payload: Any,
    envelope: Any,
    *,
    correlation_ref: str | None = None,
    authority_root: str | pathlib.Path | None = None,
) -> dict[str, Any]:
    """Map an adapter-local Cloudflare issue extraction into the R0 contract.

    This input is NOT claimed to be Cloudflare's generic webhook payload schema.
    Cloudflare generic webhooks use the standard Notifications webhook payload; an
    outer transport adapter must authenticate that delivery and extract only the
    allowlisted fields accepted here.

    Unknown extra keys are rejected so raw telemetry cannot be silently persisted.
    """
    if not isinstance(payload, dict):
        raise RuntimeIngressError(["payload: object required"])

    allowed = {
        "event_id",
        "captured_at",
        "environment",
        "issue_fingerprint",
        "deployment_ref",
        "occurrence_count",
        "recurrence",
        "error_type",
        "statement",
        "trace_refs",
        "log_refs",
        "status",
        "candidate_problem",
    }
    unknown = sorted(set(payload) - allowed)
    errors = _validate_envelope(envelope)
    errors.extend(_forbidden_input_errors(payload))
    if unknown:
        errors.append(f"payload: unsupported keys: {unknown}")

    provider = _normalize_provider("cloudflare", errors)
    event_id = _require_nonempty_string(payload.get("event_id"), "payload.event_id", errors)
    captured_at = _require_rfc3339(payload.get("captured_at"), "payload.captured_at", errors)
    environment = _require_nonempty_string(
        payload.get("environment"), "payload.environment", errors, max_chars=64
    )
    fingerprint = _require_nonempty_string(
        payload.get("issue_fingerprint"),
        "payload.issue_fingerprint",
        errors,
        max_chars=256,
    )
    error_type = _require_nonempty_string(
        payload.get("error_type"), "payload.error_type", errors, max_chars=128
    )
    statement = _require_nonempty_string(
        payload.get("statement"),
        "payload.statement",
        errors,
        max_chars=MAX_STATEMENT_CHARS,
    )

    deployment = payload.get("deployment_ref")
    if deployment is not None:
        deployment = _require_nonempty_string(
            deployment, "payload.deployment_ref", errors, max_chars=256
        )
        if isinstance(deployment, str) and "://" in deployment:
            errors.append("payload.deployment_ref: raw URL not allowed")

    occurrence_count = payload.get("occurrence_count")
    if not isinstance(occurrence_count, int) or isinstance(occurrence_count, bool) or occurrence_count < 1:
        errors.append("payload.occurrence_count: integer >= 1 required")

    recurrence = _require_bool(payload.get("recurrence"), "payload.recurrence", errors)

    status = payload.get("status")
    if not isinstance(status, str) or not status.strip():
        errors.append("payload.status: non-empty string required")
        disposition = "ambiguous"
    else:
        disposition = CLOUDFLARE_STATUS_TO_DISPOSITION.get(
            status.strip().lower(), "ambiguous"
        )

    candidate_problem = payload.get("candidate_problem")
    if candidate_problem is not None:
        candidate_problem = _require_nonempty_string(
            candidate_problem,
            "payload.candidate_problem",
            errors,
            max_chars=MAX_STATEMENT_CHARS,
        )

    trace_refs = _bounded_ref_list(payload.get("trace_refs"), "payload.trace_refs", errors)
    log_refs = _bounded_ref_list(payload.get("log_refs"), "payload.log_refs", errors)

    resolved_correlation_ref = None
    if correlation_ref is not None:
        syntax_errors = pm._validate_repo_relative_ref_syntax(
            correlation_ref, "correlation_ref"
        )
        errors.extend(syntax_errors)
        if not syntax_errors:
            if authority_root is None:
                errors.append(
                    "correlation_ref: authority_root required before claim can be observed"
                )
            else:
                path, _fragment, ref_errors = pm._resolve_repo_authority_ref(
                    correlation_ref,
                    authority_root,
                )
                errors.extend(
                    f"correlation_ref: {error}" for error in ref_errors
                )
                if path is not None and not ref_errors:
                    resolved_correlation_ref = correlation_ref.strip()

    if errors:
        raise RuntimeIngressError(errors)

    intake_identity = _logical_intake_identity(
        provider=provider,
        environment=environment,
        issue_fingerprint=fingerprint,
        deployment_ref=deployment,
    )
    event_ref = _event_ref(provider, event_id)
    evidence_instance_ref = _evidence_instance_ref(
        provider, event_id, captured_at
    )
    snapshot = {
        "schema_version": "1",
        "domain": "plangate.runtime-ingress-source/v1",
        "mode": "r0_shadow",
        "runtime_source": {
            "provider": provider,
            "provider_event_ref": event_ref,
            "evidence_instance_ref": evidence_instance_ref,
            "intake_identity": intake_identity,
            "captured_at": captured_at,
            "environment": environment,
            "issue_fingerprint": _sha256_text(fingerprint),
            "deployment_ref": (
                _sha256_text(deployment) if isinstance(deployment, str) else None
            ),
            "occurrence": {
                "count": occurrence_count,
                "recurrence": recurrence,
            },
            "summary": {
                "error_type": error_type,
                "statement": statement,
            },
            "evidence": {
                "trace_refs": trace_refs,
                "log_refs": log_refs,
                "correlation_ref": resolved_correlation_ref,
            },
            "redaction": {
                "applied": True,
                "secret_scan": "pass",
            },
        },
        "authority": {
            "agent_invoke_allowed": False,
            "pbi_write_allowed": False,
            "issue_write_allowed": False,
            "code_write_allowed": False,
            "run_state_write_allowed": False,
            "run_evidence_write_allowed": False,
            "approval_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }

    snapshot_hash = _canonical_hash(snapshot)
    source_ref = _snapshot_ref(provider, intake_identity, snapshot_hash)

    signal = {
        "signal_id": "runtime:" + intake_identity.split(":", 1)[1],
        "source_ref": source_ref,
        "statement": statement,
        "source_kind": "external_source",
        "claim_class": "observed" if resolved_correlation_ref else "reported",
        "disposition": disposition,
        "target_layer": "delivery",
        "candidate_problem": candidate_problem,
    }

    signal_errors = pm.validate_admission_signal(signal)
    if signal_errors:
        raise RuntimeIngressError(
            [f"admission_signal: {error}" for error in signal_errors]
        )

    privacy_errors = pm._privacy_errors(
        {"runtime_ingress_source": snapshot, "admission_signal": signal}
    )
    if privacy_errors:
        raise RuntimeIngressError(
            [f"privacy: {error}" for error in privacy_errors]
        )

    return {
        "mode": "r0_shadow",
        "provider": provider,
        "intake_identity": intake_identity,
        "source_ref": source_ref,
        "source_snapshot": snapshot,
        "admission_signal": signal,
        "admission": pm.admit_signal(signal),
        "snapshot_hash": snapshot_hash,
        "authority": snapshot["authority"],
    }


def main(argv=None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cloudflare-issue", help="allowlisted Cloudflare issue JSON")
    parser.add_argument("--envelope", help="R0 security envelope JSON")
    parser.add_argument(
        "--correlation-ref",
        help="repository-visible independent correlation evidence; required for observed",
    )
    parser.add_argument(
        "--authority-root",
        help="repository root used to resolve --correlation-ref",
    )
    parser.add_argument(
        "--persist-root",
        help="optional repository root for create-only R0 source snapshot persistence",
    )
    args = parser.parse_args(argv)

    if not args.cloudflare_issue or not args.envelope:
        parser.error("--cloudflare-issue and --envelope are required")

    try:
        payload = json.loads(pathlib.Path(args.cloudflare_issue).read_text(encoding="utf-8"))
        envelope = json.loads(pathlib.Path(args.envelope).read_text(encoding="utf-8"))
        result = map_cloudflare_issue(
            payload,
            envelope,
            correlation_ref=args.correlation_ref,
            authority_root=args.authority_root,
        )
    except (OSError, json.JSONDecodeError, RuntimeIngressError) as exc:
        if isinstance(exc, RuntimeIngressError):
            for error in exc.errors:
                print(f"ERROR: {error}", file=sys.stderr)
        else:
            print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    output = {"mapping": result}
    if args.persist_root:
        output["persistence"] = persist_source_snapshot(args.persist_root, result)

    print(json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
