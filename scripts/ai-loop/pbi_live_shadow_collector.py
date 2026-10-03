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

__doc__ = """pbi_live_shadow_collector.py — persist passive PBI live-shadow evidence (#1442).

This adapter is intentionally narrower than the PBI materializer:
- it may create evidence artifacts only under
  docs/working/TASK-XXXX/evidence/pbi-live-shadow/
- artifacts are create-only; existing files are never replaced
- capture uses pbi_materializer.build_passive_shadow_capture()
- review-packet creation revalidates capture <-> RunEvidence binding
- no oracle / expected decision is attached by the collector
- no PBI / Issue / RunState / Harness mutation is allowed
"""

import argparse
import json
import os
import pathlib
import stat
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import pbi_materializer as pm  # noqa: E402


class CollectorError(ValueError):
    pass


def _load_json_object(path: pathlib.Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise CollectorError(f"{label}: unreadable: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise CollectorError(f"{label}: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise CollectorError(f"{label}: object required")
    return value


def _namespace_prefix(task_id: str) -> str:
    if not pm.TASK_ID_RE.fullmatch(task_id):
        raise CollectorError("task_id: TASK-NNNN required")
    return f"docs/working/{task_id}/evidence/pbi-live-shadow/"


def _validate_output_ref(task_id: str, ref: Any, label: str) -> str:
    errors = pm._validate_repo_relative_ref_syntax(ref, label)
    if errors:
        raise CollectorError("; ".join(errors))
    assert isinstance(ref, str)
    clean = ref.strip()
    prefix = _namespace_prefix(task_id)
    if not clean.startswith(prefix):
        raise CollectorError(
            f"{label}: must be under {prefix}"
        )
    if clean.endswith("/"):
        raise CollectorError(f"{label}: file ref required")
    return clean


def _ensure_safe_parent(root: pathlib.Path, target: pathlib.Path) -> None:
    root = root.resolve()
    try:
        relative = target.parent.relative_to(root)
    except ValueError as exc:
        raise CollectorError("output path escapes repository root") from exc

    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        if cursor.exists() or cursor.is_symlink():
            mode = cursor.lstat().st_mode
            if stat.S_ISLNK(mode):
                raise CollectorError(
                    f"output parent contains symlink: {cursor.relative_to(root)}"
                )
            if not stat.S_ISDIR(mode):
                raise CollectorError(
                    f"output parent is not directory: {cursor.relative_to(root)}"
                )
        else:
            cursor.mkdir(mode=0o755)


def _atomic_create_json(
    repo_root: pathlib.Path,
    ref: str,
    value: dict[str, Any],
) -> tuple[str, bool]:
    root = repo_root.resolve()
    target = root / ref
    _ensure_safe_parent(root, target)

    payload = (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")
    digest = pm._canonical_json_hash(value).split(":", 1)[1][:12]
    temp_name = f".{target.name}.{os.getpid()}.{digest}.tmp"
    final_name = target.name

    dir_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    dir_flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        dir_fd = os.open(target.parent, dir_flags)
    except OSError as exc:
        raise CollectorError(f"output parent cannot be opened safely: {exc}") from exc

    file_fd = None
    try:
        try:
            file_fd = os.open(
                temp_name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o600,
                dir_fd=dir_fd,
            )
        except FileExistsError as exc:
            raise CollectorError(
                f"stale temp artifact exists for {ref}; manual review required"
            ) from exc

        with os.fdopen(file_fd, "wb", closefd=True) as handle:
            file_fd = None
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())

        reused = False
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
                raise CollectorError(
                    f"existing artifact is not a safe regular file: {ref}"
                ) from exc
            try:
                mode = os.fstat(existing_fd).st_mode
                if not stat.S_ISREG(mode):
                    raise CollectorError(
                        f"existing artifact is not a regular file: {ref}"
                    )
                with os.fdopen(existing_fd, "rb", closefd=True) as handle:
                    existing_fd = -1
                    existing = handle.read()
            finally:
                if existing_fd >= 0:
                    os.close(existing_fd)

            if existing != payload:
                raise CollectorError(
                    f"artifact already exists with different content: {ref}"
                )
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

    return pm._canonical_json_hash(value), reused


def _require_existing_source(
    repo_root: pathlib.Path,
    source_ref: str,
) -> pathlib.Path:
    path, _fragment, errors = pm._resolve_repo_authority_ref(
        source_ref,
        repo_root,
    )
    if errors or path is None:
        raise CollectorError(
            "source_ref: " + "; ".join(errors or ["unresolvable"])
        )
    return path


def collect_capture(
    *,
    repo_root: pathlib.Path,
    signal: dict[str, Any],
    task_id: str,
    run_id: str,
    captured_at: str,
    runtime_head_sha: str,
    capture_ref: str,
) -> dict[str, Any]:
    capture_ref = _validate_output_ref(
        task_id, capture_ref, "capture_ref"
    )
    source_ref = signal.get("source_ref")
    if not isinstance(source_ref, str) or not source_ref.strip():
        raise CollectorError("signal.source_ref: non-empty string required")
    source_path = _require_existing_source(repo_root, source_ref.strip())

    capture = pm.build_passive_shadow_capture(
        task_id=task_id,
        run_id=run_id,
        captured_at=captured_at,
        runtime_head_sha=runtime_head_sha,
        capture_ref=capture_ref,
        signal=signal,
    )

    capture_target = (repo_root.resolve() / capture_ref).resolve(strict=False)
    if source_path.resolve() == capture_target:
        raise CollectorError("source_ref must be distinct from capture artifact")

    artifact_hash, artifact_reused = _atomic_create_json(
        repo_root, capture_ref, capture
    )
    return {
        "mode": "pbi_live_shadow_collect_capture",
        "artifact_ref": capture_ref,
        "artifact_hash": artifact_hash,
        "artifact_reused": artifact_reused,
        "source_ref": source_ref.strip(),
        "run_evidence_ref": None,
        "next": "finalize_run_evidence_with_source_and_capture_refs",
        "authority": {
            "evidence_create_allowed": True,
            "overwrite_allowed": False,
            "idempotent_reuse_allowed": True,
            "pbi_write_allowed": False,
            "issue_write_allowed": False,
            "close_allowed": False,
            "suppression_allowed": False,
            "merge_allowed": False,
            "oracle_attached": False,
        },
    }


def collect_review_packet(
    *,
    repo_root: pathlib.Path,
    capture_ref: str,
    run_evidence_ref: str,
    packet_ref: str,
) -> dict[str, Any]:
    capture, run_evidence, errors = pm._validate_live_run_binding(
        capture_ref=capture_ref,
        run_evidence_ref=run_evidence_ref,
        authority_root=repo_root,
    )
    if errors or capture is None or run_evidence is None:
        raise CollectorError(
            "live binding invalid: " + "; ".join(errors or ["unknown"])
        )

    task_id = capture.get("task_id")
    if not isinstance(task_id, str):
        raise CollectorError("capture.task_id: string required")
    packet_ref = _validate_output_ref(
        task_id, packet_ref, "packet_ref"
    )

    signal = capture.get("signal")
    if not isinstance(signal, dict):
        raise CollectorError("capture.signal: object required")
    source_ref = signal.get("source_ref")
    if not isinstance(source_ref, str):
        raise CollectorError("capture.signal.source_ref: string required")
    _require_existing_source(repo_root, source_ref)

    ev_refs = run_evidence.get("evidence_refs", [])
    if (
        not isinstance(ev_refs, list)
        or capture_ref not in ev_refs
        or source_ref not in ev_refs
    ):
        raise CollectorError(
            "RunEvidence must bind both source_ref and capture_ref"
        )

    signal_errors = pm.validate_admission_signal(signal)
    if signal_errors:
        raise CollectorError(
            "capture.signal invalid: " + "; ".join(signal_errors)
        )

    packet = {
        "schema_version": 1,
        "domain": "plangate.pbi-live-shadow-review-packet/v1",
        "mode": "pbi_live_shadow_review_packet",
        "evidence_class": "live_shadow",
        "task_id": task_id,
        "run_id": capture["run_id"],
        "refs": {
            "blind_review_source_ref": source_ref,
            "capture_ref_for_binding_only": capture_ref,
            "run_evidence_ref_for_binding_only": run_evidence_ref,
        },
        "hashes": {
            "signal_hash": capture["signal_hash"],
            "capture_hash": pm._canonical_json_hash(capture),
            "run_evidence_hash": pm._canonical_json_hash(run_evidence),
        },
        "review_contract": {
            "independent_review_required": True,
            "review_from_upstream_source": True,
            "actual_decision_disclosed": False,
            "normalized_disposition_disclosed": False,
            "oracle_attached": False,
            "expected_decision_attached": False,
            "quality_acceptance_decided": False,
            "packet_blind_to_actual": True,
            "capture_signal_blinding_enforced": False,
            "oracle_independence_owner": "caller_or_independent_reviewer",
        },
        "authority": {
            "evidence_create_allowed": True,
            "overwrite_allowed": False,
            "idempotent_reuse_allowed": True,
            "pbi_write_allowed": False,
            "issue_write_allowed": False,
            "close_allowed": False,
            "suppression_allowed": False,
            "merge_allowed": False,
        },
    }

    artifact_hash, artifact_reused = _atomic_create_json(
        repo_root, packet_ref, packet
    )
    return {
        "mode": "pbi_live_shadow_collect_review_packet",
        "artifact_ref": packet_ref,
        "artifact_hash": artifact_hash,
        "artifact_reused": artifact_reused,
        "blind_review_source_ref": source_ref,
        "review_required": True,
        "actual_decision_disclosed": False,
        "authority": packet["authority"],
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    sub = parser.add_subparsers(dest="command", required=True)

    capture = sub.add_parser("capture")
    capture.add_argument("--signal", required=True)
    capture.add_argument("--task-id", required=True)
    capture.add_argument("--run-id", required=True)
    capture.add_argument("--captured-at", required=True)
    capture.add_argument("--runtime-head-sha", required=True)
    capture.add_argument("--capture-ref", required=True)

    packet = sub.add_parser("packet")
    packet.add_argument("--capture-ref", required=True)
    packet.add_argument("--run-evidence-ref", required=True)
    packet.add_argument("--packet-ref", required=True)

    args = parser.parse_args(argv)
    root = pathlib.Path(args.repo_root).resolve()
    try:
        if args.command == "capture":
            signal = _load_json_object(pathlib.Path(args.signal), "--signal")
            result = collect_capture(
                repo_root=root,
                signal=signal,
                task_id=args.task_id,
                run_id=args.run_id,
                captured_at=args.captured_at,
                runtime_head_sha=args.runtime_head_sha,
                capture_ref=args.capture_ref,
            )
        else:
            result = collect_review_packet(
                repo_root=root,
                capture_ref=args.capture_ref,
                run_evidence_ref=args.run_evidence_ref,
                packet_ref=args.packet_ref,
            )
    except (CollectorError, pm.MaterializationError) as exc:
        print(str(exc), file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
