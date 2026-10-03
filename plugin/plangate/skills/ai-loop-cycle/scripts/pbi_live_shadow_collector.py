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
- blind review packets contain no maker actual / expected decision
- reviewed-case assembly accepts a separately authored oracle but does not create it
- no PBI / Issue / RunState / Harness mutation is allowed
"""

import argparse
import hashlib
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


def _load_json_array(path: pathlib.Path, label: str) -> list[Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise CollectorError(f"{label}: unreadable: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise CollectorError(f"{label}: invalid JSON: {exc}") from exc
    if not isinstance(value, list):
        raise CollectorError(f"{label}: array required")
    return value


def _file_sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def _load_repo_json_object(
    repo_root: pathlib.Path,
    ref: str,
    label: str,
) -> tuple[pathlib.Path, dict[str, Any]]:
    path, _fragment, errors = pm._resolve_repo_authority_ref(
        ref,
        repo_root,
    )
    if errors or path is None:
        raise CollectorError(
            f"{label}: " + "; ".join(errors or ["unresolvable"])
        )
    return path, _load_json_object(path, label)


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


def _require_safe_repo_file(
    repo_root: pathlib.Path,
    ref: str,
    label: str,
) -> pathlib.Path:
    errors = pm._validate_repo_relative_ref_syntax(ref, label)
    if errors:
        raise CollectorError(f"{label}: " + "; ".join(errors))

    root = repo_root.resolve()
    path_text = ref.partition("#")[0]
    pure = pathlib.PurePosixPath(path_text)
    cursor = root

    for index, part in enumerate(pure.parts):
        cursor = cursor / part
        try:
            mode = cursor.lstat().st_mode
        except FileNotFoundError as exc:
            raise CollectorError(
                f"{label}: repository source does not exist: {ref!r}"
            ) from exc
        except OSError as exc:
            raise CollectorError(
                f"{label}: repository source cannot be inspected: {ref!r}: {exc}"
            ) from exc

        if stat.S_ISLNK(mode):
            raise CollectorError(
                f"{label}: symlink path component rejected: "
                f"{cursor.relative_to(root).as_posix()}"
            )
        is_last = index == len(pure.parts) - 1
        if is_last:
            if not stat.S_ISREG(mode):
                raise CollectorError(
                    f"{label}: repository source must be a regular file: {ref!r}"
                )
        elif not stat.S_ISDIR(mode):
            raise CollectorError(
                f"{label}: parent path component is not a directory: "
                f"{cursor.relative_to(root).as_posix()}"
            )

    try:
        resolved = cursor.resolve(strict=True)
        resolved.relative_to(root)
    except (OSError, ValueError) as exc:
        raise CollectorError(
            f"{label}: source escapes repository root: {ref!r}"
        ) from exc
    return resolved


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
    return _require_safe_repo_file(
        repo_root,
        source_ref,
        "source_ref",
    )


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
        "run_evidence_handoff": {
            "evidence_refs": [source_ref.strip(), capture_ref],
            "source_sha256": _file_sha256(source_path),
            "capture_hash": artifact_hash,
            "cli_args": [
                "--evidence-ref",
                source_ref.strip(),
                "--evidence-ref",
                capture_ref,
            ],
            "task_id": task_id,
            "run_id": run_id,
            "runtime_head_sha": runtime_head_sha,
            "captured_at": captured_at,
            "advisory_only": True,
            "must_revalidate_after_run_evidence": True,
        },
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
    source_path = _require_existing_source(repo_root, source_ref)

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
            "source_sha256": _file_sha256(source_path),
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


def _validate_admission_oracle(
    *,
    oracle: dict[str, Any],
    oracle_ref: str,
    packet: dict[str, Any],
    packet_ref: str,
    source_ref: str,
    source_sha256: str,
) -> None:
    errors: list[str] = []

    if oracle.get("schema_version") != 1:
        errors.append("oracle.schema_version: 1 required")
    if oracle.get("domain") != "plangate.pbi-live-shadow-admission-oracle/v1":
        errors.append(
            "oracle.domain: plangate.pbi-live-shadow-admission-oracle/v1 required"
        )

    case_ref = oracle.get("case_ref")
    if not isinstance(case_ref, str) or not case_ref.strip():
        errors.append("oracle.case_ref: non-empty string required")

    if oracle.get("packet_ref") != packet_ref:
        errors.append("oracle.packet_ref: exact review packet ref required")
    if oracle.get("packet_hash") != pm._canonical_json_hash(packet):
        errors.append("oracle.packet_hash: review packet hash mismatch")
    if oracle.get("reviewed_source_ref") != source_ref:
        errors.append("oracle.reviewed_source_ref: exact upstream source ref required")
    if oracle.get("reviewed_source_sha256") != source_sha256:
        errors.append("oracle.reviewed_source_sha256: upstream source hash mismatch")

    expected = oracle.get("expected_admission_decision")
    if expected not in pm.VALID_ADMISSION_DECISIONS:
        errors.append(
            "oracle.expected_admission_decision: one of "
            f"{sorted(pm.VALID_ADMISSION_DECISIONS)} required"
        )

    if oracle.get("independent_review_asserted") is not True:
        errors.append("oracle.independent_review_asserted: true required")
    if oracle.get("maker_actual_not_consulted_asserted") is not True:
        errors.append(
            "oracle.maker_actual_not_consulted_asserted: true required"
        )

    for forbidden in (
        "actual",
        "actual_decision",
        "actual_admission_decision",
        "maker_actual",
    ):
        if forbidden in oracle:
            errors.append(f"oracle.{forbidden}: maker actual must not be stored")

    refs = packet.get("refs")
    if isinstance(refs, dict):
        bound_refs = {
            refs.get("blind_review_source_ref"),
            refs.get("capture_ref_for_binding_only"),
            refs.get("run_evidence_ref_for_binding_only"),
            packet_ref,
        }
        if oracle_ref in bound_refs:
            errors.append("oracle_ref: oracle must be a distinct artifact")

    privacy_errors = pm._privacy_errors({"oracle": oracle})
    errors.extend(
        "oracle privacy: " + error for error in privacy_errors
    )

    if errors:
        raise CollectorError("; ".join(errors))


def collect_reviewed_admission_case(
    *,
    repo_root: pathlib.Path,
    packet_ref: str,
    oracle_ref: str,
    case_artifact_ref: str,
) -> dict[str, Any]:
    _packet_path, packet = _load_repo_json_object(
        repo_root, packet_ref, "packet_ref"
    )
    if packet.get("domain") != "plangate.pbi-live-shadow-review-packet/v1":
        raise CollectorError("packet_ref: unsupported review packet domain")
    if packet.get("mode") != "pbi_live_shadow_review_packet":
        raise CollectorError("packet_ref: review packet mode required")

    task_id = packet.get("task_id")
    if not isinstance(task_id, str):
        raise CollectorError("packet.task_id: string required")
    _validate_output_ref(task_id, packet_ref, "packet_ref")
    case_artifact_ref = _validate_output_ref(
        task_id, case_artifact_ref, "case_artifact_ref"
    )

    refs = packet.get("refs")
    hashes = packet.get("hashes")
    review_contract = packet.get("review_contract")
    if not isinstance(refs, dict):
        raise CollectorError("packet.refs: object required")
    if not isinstance(hashes, dict):
        raise CollectorError("packet.hashes: object required")
    if not isinstance(review_contract, dict):
        raise CollectorError("packet.review_contract: object required")
    if review_contract.get("packet_blind_to_actual") is not True:
        raise CollectorError("packet.review_contract.packet_blind_to_actual: true required")
    if review_contract.get("actual_decision_disclosed") is not False:
        raise CollectorError(
            "packet.review_contract.actual_decision_disclosed: false required"
        )

    source_ref = refs.get("blind_review_source_ref")
    capture_ref = refs.get("capture_ref_for_binding_only")
    run_evidence_ref = refs.get("run_evidence_ref_for_binding_only")
    for label, value in (
        ("source_ref", source_ref),
        ("capture_ref", capture_ref),
        ("run_evidence_ref", run_evidence_ref),
    ):
        if not isinstance(value, str) or not value.strip():
            raise CollectorError(f"packet.refs.{label}: non-empty string required")

    assert isinstance(source_ref, str)
    assert isinstance(capture_ref, str)
    assert isinstance(run_evidence_ref, str)

    source_path = _require_existing_source(repo_root, source_ref)
    source_sha256 = _file_sha256(source_path)
    if hashes.get("source_sha256") != source_sha256:
        raise CollectorError("packet.hashes.source_sha256: current source hash mismatch")

    capture, run_evidence, binding_errors = pm._validate_live_run_binding(
        capture_ref=capture_ref,
        run_evidence_ref=run_evidence_ref,
        authority_root=repo_root,
    )
    if binding_errors or capture is None or run_evidence is None:
        raise CollectorError(
            "live binding invalid: "
            + "; ".join(binding_errors or ["unknown"])
        )

    if hashes.get("capture_hash") != pm._canonical_json_hash(capture):
        raise CollectorError("packet.hashes.capture_hash: current capture hash mismatch")
    if hashes.get("run_evidence_hash") != pm._canonical_json_hash(run_evidence):
        raise CollectorError(
            "packet.hashes.run_evidence_hash: current RunEvidence hash mismatch"
        )
    if hashes.get("signal_hash") != capture.get("signal_hash"):
        raise CollectorError("packet.hashes.signal_hash: current signal hash mismatch")

    oracle_ref = _validate_output_ref(
        task_id, oracle_ref, "oracle_ref"
    )
    _oracle_path, oracle = _load_repo_json_object(
        repo_root, oracle_ref, "oracle_ref"
    )
    _validate_admission_oracle(
        oracle=oracle,
        oracle_ref=oracle_ref,
        packet=packet,
        packet_ref=packet_ref,
        source_ref=source_ref,
        source_sha256=source_sha256,
    )

    signal = capture.get("signal")
    if not isinstance(signal, dict):
        raise CollectorError("capture.signal: object required")

    eval_case = {
        "case_ref": oracle["case_ref"],
        "split": "test",
        "evidence_class": "live_shadow",
        "evidence_refs": [
            source_ref,
            capture_ref,
            run_evidence_ref,
            packet_ref,
        ],
        "live_capture": {
            "capture_ref": capture_ref,
            "run_evidence_ref": run_evidence_ref,
        },
        "signal": signal,
        "expected": {
            "oracle_ref": oracle_ref,
            "admission_decision": oracle["expected_admission_decision"],
        },
    }

    batch_errors = pm._validate_admission_batch(
        [eval_case],
        authority_root=repo_root,
    )
    if batch_errors:
        raise CollectorError(
            "assembled admission case invalid: " + "; ".join(batch_errors)
        )

    artifact_hash, artifact_reused = _atomic_create_json(
        repo_root, case_artifact_ref, eval_case
    )
    return {
        "mode": "pbi_live_shadow_collect_reviewed_admission_case",
        "artifact_ref": case_artifact_ref,
        "artifact_hash": artifact_hash,
        "artifact_reused": artifact_reused,
        "packet_ref": packet_ref,
        "oracle_ref": oracle_ref,
        "review_assertions": {
            "independent_review_asserted": True,
            "maker_actual_not_consulted_asserted": True,
            "oracle_authorship_verified": False,
            "reviewer_identity_required": False,
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
            "quality_acceptance_decided": False,
        },
    }


def _validate_materialization_oracle(
    *,
    oracle: dict[str, Any],
    oracle_ref: str,
    admission_case: dict[str, Any],
    admission_case_ref: str,
    payload: dict[str, Any],
    payload_ref: str,
    existing_work: list[Any],
    existing_work_ref: str,
) -> None:
    errors: list[str] = []

    if oracle.get("schema_version") != 1:
        errors.append("materialization_oracle.schema_version: 1 required")
    if oracle.get("domain") != "plangate.pbi-live-shadow-materialization-oracle/v1":
        errors.append(
            "materialization_oracle.domain: "
            "plangate.pbi-live-shadow-materialization-oracle/v1 required"
        )

    case_ref = oracle.get("case_ref")
    if not isinstance(case_ref, str) or not case_ref.strip():
        errors.append("materialization_oracle.case_ref: non-empty string required")

    bindings = (
        ("admission_case_ref", admission_case_ref),
        ("payload_ref", payload_ref),
        ("existing_work_ref", existing_work_ref),
    )
    for field, expected_ref in bindings:
        if oracle.get(field) != expected_ref:
            errors.append(
                f"materialization_oracle.{field}: exact bound ref required"
            )

    hash_bindings = (
        ("admission_case_hash", pm._canonical_json_hash(admission_case)),
        ("payload_hash", pm._canonical_json_hash(payload)),
        ("existing_work_hash", pm._canonical_json_hash(existing_work)),
    )
    for field, expected_hash in hash_bindings:
        if oracle.get(field) != expected_hash:
            errors.append(
                f"materialization_oracle.{field}: bound artifact hash mismatch"
            )

    expected = oracle.get("expected")
    expected_for_validation: dict[str, Any] = {"oracle_ref": oracle_ref}
    if isinstance(expected, dict):
        expected_for_validation.update(expected)
    else:
        errors.append("materialization_oracle.expected: object required")
    errors.extend(
        "materialization_oracle.expected." + error
        for error in pm._validate_shadow_expected(expected_for_validation)
    )

    if oracle.get("independent_review_asserted") is not True:
        errors.append(
            "materialization_oracle.independent_review_asserted: true required"
        )
    if oracle.get("maker_actual_not_consulted_asserted") is not True:
        errors.append(
            "materialization_oracle.maker_actual_not_consulted_asserted: true required"
        )

    for forbidden in (
        "actual",
        "actual_decision",
        "actual_materialization_decision",
        "maker_actual",
    ):
        if forbidden in oracle:
            errors.append(
                f"materialization_oracle.{forbidden}: maker actual must not be stored"
            )

    privacy_errors = pm._privacy_errors({"materialization_oracle": oracle})
    errors.extend(
        "materialization_oracle privacy: " + error
        for error in privacy_errors
    )

    if errors:
        raise CollectorError("; ".join(errors))


def collect_reviewed_materialization_case(
    *,
    repo_root: pathlib.Path,
    admission_case_ref: str,
    payload_ref: str,
    existing_work_ref: str,
    oracle_ref: str,
    case_artifact_ref: str,
) -> dict[str, Any]:
    admission_path, admission_case = _load_repo_json_object(
        repo_root, admission_case_ref, "admission_case_ref"
    )
    parts = pathlib.PurePosixPath(
        admission_path.relative_to(repo_root.resolve()).as_posix()
    ).parts
    task_id = parts[2] if len(parts) > 2 else ""
    _validate_output_ref(task_id, admission_case_ref, "admission_case_ref")

    admission_errors = pm._validate_admission_batch(
        [admission_case],
        authority_root=repo_root,
    )
    if admission_errors:
        raise CollectorError(
            "admission_case invalid: " + "; ".join(admission_errors)
        )
    admission_report = pm.evaluate_admission_batch(
        [admission_case],
        authority_root=repo_root,
    )
    admission_result = admission_report["cases"][0]
    if (
        admission_result.get("status") != "match"
        or admission_result.get("actual") != "materialize"
        or admission_result.get("expected") != "materialize"
    ):
        raise CollectorError(
            "admission_case: reviewed materialize match required before "
            "materialization evaluation"
        )

    payload_ref = _validate_output_ref(task_id, payload_ref, "payload_ref")
    existing_work_ref = _validate_output_ref(
        task_id, existing_work_ref, "existing_work_ref"
    )
    oracle_ref = _validate_output_ref(task_id, oracle_ref, "oracle_ref")
    case_artifact_ref = _validate_output_ref(
        task_id, case_artifact_ref, "materialization_case_artifact_ref"
    )

    payload_path, payload = _load_repo_json_object(
        repo_root, payload_ref, "payload_ref"
    )
    existing_path, _fragment, existing_errors = pm._resolve_repo_authority_ref(
        existing_work_ref,
        repo_root,
    )
    if existing_errors or existing_path is None:
        raise CollectorError(
            "existing_work_ref: "
            + "; ".join(existing_errors or ["unresolvable"])
        )
    existing_work = _load_json_array(
        existing_path,
        "existing_work_ref",
    )
    _oracle_path, oracle = _load_repo_json_object(
        repo_root, oracle_ref, "oracle_ref"
    )

    _validate_materialization_oracle(
        oracle=oracle,
        oracle_ref=oracle_ref,
        admission_case=admission_case,
        admission_case_ref=admission_case_ref,
        payload=payload,
        payload_ref=payload_ref,
        existing_work=existing_work,
        existing_work_ref=existing_work_ref,
    )

    live_capture = admission_case.get("live_capture")
    evidence_refs = list(admission_case.get("evidence_refs", []))
    for ref in (
        admission_case_ref,
        payload_ref,
        existing_work_ref,
    ):
        if ref not in evidence_refs:
            evidence_refs.append(ref)

    expected = oracle["expected"]
    eval_case = {
        "case_ref": oracle["case_ref"],
        "split": "test",
        "evidence_class": "live_shadow",
        "evidence_refs": evidence_refs,
        "live_capture": live_capture,
        "payload": payload,
        "existing_work": existing_work,
        "expected": {
            "oracle_ref": oracle_ref,
            "decision": expected["decision"],
            "matched_ref": expected.get("matched_ref"),
            "readiness_status": expected["readiness_status"],
            "readiness_route": expected["readiness_route"],
        },
    }

    batch_errors = pm._validate_shadow_batch(
        [eval_case],
        authority_root=repo_root,
    )
    if batch_errors:
        raise CollectorError(
            "assembled materialization case invalid: "
            + "; ".join(batch_errors)
        )

    artifact_hash, artifact_reused = _atomic_create_json(
        repo_root, case_artifact_ref, eval_case
    )
    return {
        "mode": "pbi_live_shadow_collect_reviewed_materialization_case",
        "artifact_ref": case_artifact_ref,
        "artifact_hash": artifact_hash,
        "artifact_reused": artifact_reused,
        "admission_case_ref": admission_case_ref,
        "payload_ref": payload_ref,
        "existing_work_ref": existing_work_ref,
        "oracle_ref": oracle_ref,
        "review_assertions": {
            "admission_materialize_match_revalidated": True,
            "independent_review_asserted": True,
            "maker_actual_not_consulted_asserted": True,
            "oracle_authorship_verified": False,
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
            "quality_acceptance_decided": False,
        },
    }


def _revalidate_materialization_case_chain(
    *,
    repo_root: pathlib.Path,
    task_id: str,
    case: dict[str, Any],
) -> None:
    expected = case.get("expected")
    if not isinstance(expected, dict):
        raise CollectorError("materialization case expected: object required")
    oracle_ref = _validate_output_ref(
        task_id,
        expected.get("oracle_ref"),
        "materialization_case.expected.oracle_ref",
    )

    _oracle_path, oracle = _load_repo_json_object(
        repo_root, oracle_ref, "materialization_oracle_ref"
    )
    admission_case_ref = _validate_output_ref(
        task_id,
        oracle.get("admission_case_ref"),
        "materialization_oracle.admission_case_ref",
    )
    payload_ref = _validate_output_ref(
        task_id,
        oracle.get("payload_ref"),
        "materialization_oracle.payload_ref",
    )
    existing_work_ref = _validate_output_ref(
        task_id,
        oracle.get("existing_work_ref"),
        "materialization_oracle.existing_work_ref",
    )

    evidence_refs = case.get("evidence_refs", [])
    if not isinstance(evidence_refs, list):
        raise CollectorError("materialization_case.evidence_refs: array required")
    for ref in (admission_case_ref, payload_ref, existing_work_ref):
        if ref not in evidence_refs:
            raise CollectorError(
                f"materialization_case.evidence_refs: missing bound ref {ref}"
            )
    if oracle_ref in evidence_refs:
        raise CollectorError(
            "materialization_case.evidence_refs: oracle must remain separate"
        )

    _admission_path, admission_case = _load_repo_json_object(
        repo_root, admission_case_ref, "admission_case_ref"
    )
    admission_errors = pm._validate_admission_batch(
        [admission_case],
        authority_root=repo_root,
    )
    if admission_errors:
        raise CollectorError(
            "admission_case invalid: " + "; ".join(admission_errors)
        )
    admission_report = pm.evaluate_admission_batch(
        [admission_case],
        authority_root=repo_root,
    )
    admission_result = admission_report["cases"][0]
    if (
        admission_result.get("status") != "match"
        or admission_result.get("actual") != "materialize"
        or admission_result.get("expected") != "materialize"
    ):
        raise CollectorError(
            "admission_case: reviewed materialize match required"
        )

    _payload_path, payload = _load_repo_json_object(
        repo_root, payload_ref, "payload_ref"
    )
    existing_path, _fragment, existing_errors = pm._resolve_repo_authority_ref(
        existing_work_ref,
        repo_root,
    )
    if existing_errors or existing_path is None:
        raise CollectorError(
            "existing_work_ref: "
            + "; ".join(existing_errors or ["unresolvable"])
        )
    existing_work = _load_json_array(existing_path, "existing_work_ref")

    _validate_materialization_oracle(
        oracle=oracle,
        oracle_ref=oracle_ref,
        admission_case=admission_case,
        admission_case_ref=admission_case_ref,
        payload=payload,
        payload_ref=payload_ref,
        existing_work=existing_work,
        existing_work_ref=existing_work_ref,
    )

    if case.get("payload") != payload:
        raise CollectorError(
            "materialization_case.payload: stored payload artifact mismatch"
        )
    if case.get("existing_work") != existing_work:
        raise CollectorError(
            "materialization_case.existing_work: stored snapshot mismatch"
        )
    if case.get("live_capture") != admission_case.get("live_capture"):
        raise CollectorError(
            "materialization_case.live_capture: admission binding mismatch"
        )


def inventory_live_materialization_cases(
    *,
    repo_root: pathlib.Path,
) -> dict[str, Any]:
    root = repo_root.resolve()
    pattern = (
        "docs/working/TASK-*/evidence/"
        "pbi-live-shadow/**/materialization-case.json"
    )
    discovered = sorted(root.glob(pattern))
    candidates: list[tuple[str, dict[str, Any]]] = []
    invalid: list[dict[str, Any]] = []

    for path in discovered:
        try:
            rel = path.relative_to(root).as_posix()
        except ValueError:
            continue

        try:
            safe_path = _require_safe_repo_file(
                root,
                rel,
                "case_artifact_ref",
            )
        except CollectorError as exc:
            invalid.append({"ref": rel, "errors": [str(exc)]})
            continue

        try:
            case = _load_json_object(safe_path, rel)
        except CollectorError as exc:
            invalid.append({"ref": rel, "errors": [str(exc)]})
            continue

        parts = pathlib.PurePosixPath(rel).parts
        task_id = parts[2] if len(parts) > 2 else ""
        try:
            _validate_output_ref(
                task_id, rel, "materialization_case_artifact_ref"
            )
            _revalidate_materialization_case_chain(
                repo_root=root,
                task_id=task_id,
                case=case,
            )
        except CollectorError as exc:
            invalid.append({"ref": rel, "errors": [str(exc)]})
            continue

        errors = pm._validate_shadow_batch(
            [case],
            authority_root=root,
        )
        if errors:
            invalid.append({"ref": rel, "errors": errors})
            continue
        candidates.append((rel, case))

    refs_by_case_id: dict[str, list[str]] = {}
    for rel, case in candidates:
        logical = case.get("case_ref")
        if isinstance(logical, str):
            refs_by_case_id.setdefault(logical, []).append(rel)

    duplicate_refs = {
        ref
        for refs in refs_by_case_id.values()
        if len(refs) > 1
        for ref in refs
    }

    valid_cases: list[dict[str, Any]] = []
    valid_refs: list[str] = []
    for rel, case in candidates:
        if rel in duplicate_refs:
            logical = case.get("case_ref")
            invalid.append(
                {
                    "ref": rel,
                    "errors": [
                        f"duplicate logical case_ref {logical!r}: "
                        + ", ".join(refs_by_case_id.get(logical, []))
                    ],
                }
            )
            continue
        valid_cases.append(case)
        valid_refs.append(rel)

    evaluated_cases: list[dict[str, Any]] = []
    metrics: dict[str, Any] | None = None
    rollout_quality = pm._materialization_live_quality([])

    if valid_cases:
        try:
            report = pm.evaluate_shadow_batch(
                valid_cases,
                authority_root=root,
            )
        except pm.MaterializationError as exc:
            invalid.append(
                {
                    "ref": "<aggregate-evaluation>",
                    "errors": list(exc.errors),
                }
            )
        else:
            evaluated_cases = report["cases"]
            metrics = report["metrics"]
            rollout_quality = report["rollout_quality"]

    observed_decisions = sorted({
        case.get("actual_decision")
        for case in evaluated_cases
        if isinstance(case, dict)
        and isinstance(case.get("actual_decision"), str)
    })
    reviewed_expected_decisions = sorted({
        case.get("expected_decision")
        for case in evaluated_cases
        if isinstance(case, dict)
        and isinstance(case.get("expected_decision"), str)
    })
    missing_decisions = sorted(
        pm.VALID_DECISIONS - set(observed_decisions)
    )
    missing_reviewed_decisions = sorted(
        pm.VALID_DECISIONS - set(reviewed_expected_decisions)
    )
    collection_gaps: list[str] = []
    if invalid:
        collection_gaps.append("invalid_materialization_case_artifacts_present")
    if not valid_cases:
        collection_gaps.append("tracked_materialization_case_missing")
    collection_gaps.extend(
        f"materialization_decision_missing:{decision}"
        for decision in missing_decisions
    )

    return {
        "mode": "pbi_live_shadow_materialization_inventory",
        "scope": "repository_tracked_live_shadow_materialization",
        "discovered_case_artifacts": [
            path.relative_to(root).as_posix() for path in discovered
        ],
        "valid_case_artifacts": valid_refs,
        "invalid_case_artifacts": sorted(
            invalid,
            key=lambda item: str(item.get("ref", "")),
        ),
        "tracked_live_case_total": len(valid_cases),
        "evaluated_case_total": len(evaluated_cases),
        "invalid_case_total": len(invalid),
        "has_tracked_live_evidence": bool(valid_cases),
        "inventory_complete": not invalid,
        "coverage": {
            "observed_materialization_decisions": observed_decisions,
            "missing_materialization_decisions": missing_decisions,
            "materialization_decision_coverage_complete": (
                not missing_decisions
            ),
            "reviewed_expected_materialization_decisions": (
                reviewed_expected_decisions
            ),
            "missing_reviewed_materialization_decisions": (
                missing_reviewed_decisions
            ),
            "reviewed_materialization_case_coverage_complete": (
                not missing_reviewed_decisions
            ),
            "actual_coverage_is_ground_truth_coverage": False,
            "representative_coverage_claim_allowed": False,
        },
        "collection_gaps": collection_gaps,
        "metrics": metrics,
        "rollout_quality": rollout_quality,
        "verification_boundary": {
            "repository_chain_revalidated": True,
            "admission_materialize_match_revalidated": True,
            "task_namespace_binding_enforced": True,
            "duplicate_logical_case_ids_rejected": True,
            "runtime_execution_verified": False,
            "source_preexistence_verified": False,
            "reviewer_identity_verified": False,
            "historical_promoted_to_live": False,
            "synthetic_fixture_counted": False,
        },
        "authority": {
            "read_only": True,
            "write_allowed": False,
            "close_allowed": False,
            "suppression_allowed": False,
            "merge_allowed": False,
            "quality_thresholds_applied": False,
            "quality_acceptance_decided": False,
        },
    }


def inventory_live_shadow_cases(
    *,
    repo_root: pathlib.Path,
) -> dict[str, Any]:
    root = repo_root.resolve()
    pattern = (
        "docs/working/TASK-*/evidence/"
        "pbi-live-shadow/**/admission-case.json"
    )
    discovered = sorted(root.glob(pattern))

    candidates: list[tuple[str, dict[str, Any]]] = []
    invalid: list[dict[str, Any]] = []

    for path in discovered:
        try:
            rel = path.relative_to(root).as_posix()
        except ValueError:
            continue

        try:
            safe_path = _require_safe_repo_file(
                root,
                rel,
                "case_artifact_ref",
            )
        except CollectorError as exc:
            invalid.append({"ref": rel, "errors": [str(exc)]})
            continue

        try:
            case = _load_json_object(safe_path, rel)
        except CollectorError as exc:
            invalid.append({"ref": rel, "errors": [str(exc)]})
            continue

        parts = pathlib.PurePosixPath(rel).parts
        task_id = parts[2] if len(parts) > 2 else ""
        ownership_errors: list[str] = []
        try:
            _validate_output_ref(task_id, rel, "case_artifact_ref")
        except CollectorError as exc:
            ownership_errors.append(str(exc))

        live_capture = case.get("live_capture")
        expected = case.get("expected")
        if not isinstance(live_capture, dict):
            ownership_errors.append("case.live_capture: object required")
        else:
            for label in ("capture_ref", "run_evidence_ref"):
                value = live_capture.get(label)
                try:
                    _validate_output_ref(task_id, value, f"case.live_capture.{label}")
                except CollectorError as exc:
                    ownership_errors.append(str(exc))

        if not isinstance(expected, dict):
            ownership_errors.append("case.expected: object required")
        else:
            try:
                _validate_output_ref(
                    task_id,
                    expected.get("oracle_ref"),
                    "case.expected.oracle_ref",
                )
            except CollectorError as exc:
                ownership_errors.append(str(exc))

        if ownership_errors:
            invalid.append({"ref": rel, "errors": ownership_errors})
            continue

        errors = pm._validate_admission_batch(
            [case],
            authority_root=root,
        )
        if errors:
            invalid.append({"ref": rel, "errors": errors})
            continue

        candidates.append((rel, case))

    refs_by_case_id: dict[str, list[str]] = {}
    for rel, case in candidates:
        logical = case.get("case_ref")
        if isinstance(logical, str):
            refs_by_case_id.setdefault(logical, []).append(rel)

    duplicate_refs = {
        ref
        for refs in refs_by_case_id.values()
        if len(refs) > 1
        for ref in refs
    }

    valid_cases: list[dict[str, Any]] = []
    valid_refs: list[str] = []
    for rel, case in candidates:
        if rel in duplicate_refs:
            logical = case.get("case_ref")
            invalid.append(
                {
                    "ref": rel,
                    "errors": [
                        f"duplicate logical case_ref {logical!r}: "
                        + ", ".join(refs_by_case_id.get(logical, []))
                    ],
                }
            )
            continue
        valid_cases.append(case)
        valid_refs.append(rel)

    evaluated_cases: list[dict[str, Any]] = []
    metrics: dict[str, Any] | None = None
    rollout_quality = pm._admission_live_quality([])

    if valid_cases:
        try:
            report = pm.evaluate_admission_batch(
                valid_cases,
                authority_root=root,
            )
        except pm.MaterializationError as exc:
            invalid.append(
                {
                    "ref": "<aggregate-evaluation>",
                    "errors": list(exc.errors),
                }
            )
        else:
            evaluated_cases = report["cases"]
            metrics = report["metrics"]
            rollout_quality = report["rollout_quality"]

    observed_decisions = sorted({
        case.get("actual")
        for case in evaluated_cases
        if isinstance(case, dict) and isinstance(case.get("actual"), str)
    })
    reviewed_expected_decisions = sorted({
        case.get("expected")
        for case in evaluated_cases
        if isinstance(case, dict) and isinstance(case.get("expected"), str)
    })
    observed_source_kinds = sorted({
        case.get("signal", {}).get("source_kind")
        for case in valid_cases
        if isinstance(case.get("signal"), dict)
        and isinstance(case["signal"].get("source_kind"), str)
    })
    missing_admission_decisions = sorted(
        pm.VALID_ADMISSION_DECISIONS - set(observed_decisions)
    )
    missing_reviewed_admission_decisions = sorted(
        pm.VALID_ADMISSION_DECISIONS - set(reviewed_expected_decisions)
    )
    collection_gaps: list[str] = []
    if invalid:
        collection_gaps.append("invalid_case_artifacts_present")
    if not valid_cases:
        collection_gaps.append("tracked_live_case_missing")
    collection_gaps.extend(
        f"admission_decision_missing:{decision}"
        for decision in missing_admission_decisions
    )

    return {
        "mode": "pbi_live_shadow_inventory",
        "scope": "repository_tracked_live_shadow",
        "discovered_case_artifacts": [
            path.relative_to(root).as_posix() for path in discovered
        ],
        "valid_case_artifacts": valid_refs,
        "invalid_case_artifacts": sorted(
            invalid,
            key=lambda item: str(item.get("ref", "")),
        ),
        "tracked_live_case_total": len(valid_cases),
        "evaluated_case_total": len(evaluated_cases),
        "invalid_case_total": len(invalid),
        "has_tracked_live_evidence": bool(valid_cases),
        "inventory_complete": not invalid,
        "coverage": {
            "observed_admission_decisions": observed_decisions,
            "missing_admission_decisions": missing_admission_decisions,
            "admission_decision_coverage_complete": (
                not missing_admission_decisions
            ),
            "reviewed_expected_admission_decisions": (
                reviewed_expected_decisions
            ),
            "missing_reviewed_admission_decisions": (
                missing_reviewed_admission_decisions
            ),
            "reviewed_admission_case_coverage_complete": (
                not missing_reviewed_admission_decisions
            ),
            "actual_coverage_is_ground_truth_coverage": False,
            "observed_source_kinds": observed_source_kinds,
            "source_kind_coverage_requirement_defined": False,
            "representative_coverage_claim_allowed": False,
        },
        "collection_gaps": collection_gaps,
        "materialization_rollout_boundary": {
            "covered_by_this_inventory": False,
            "duplicate_fp_fn_review_satisfied": False,
            "materialization_case_inventory_required": True,
        },
        "metrics": metrics,
        "rollout_quality": rollout_quality,
        "verification_boundary": {
            "repository_chain_revalidated": True,
            "task_namespace_binding_enforced": True,
            "duplicate_logical_case_ids_rejected": True,
            "runtime_execution_verified": False,
            "source_preexistence_verified": False,
            "reviewer_identity_verified": False,
            "historical_promoted_to_live": False,
            "synthetic_fixture_counted": False,
        },
        "authority": {
            "read_only": True,
            "write_allowed": False,
            "close_allowed": False,
            "suppression_allowed": False,
            "merge_allowed": False,
            "quality_thresholds_applied": False,
            "quality_acceptance_decided": False,
        },
    }


def plan_live_shadow_collection(
    *,
    repo_root: pathlib.Path,
) -> dict[str, Any]:
    admission = inventory_live_shadow_cases(repo_root=repo_root)
    materialization = inventory_live_materialization_cases(
        repo_root=repo_root
    )

    admission_missing = list(
        admission.get("coverage", {}).get(
            "missing_reviewed_admission_decisions", []
        )
    )
    materialization_missing = list(
        materialization.get("coverage", {}).get(
            "missing_reviewed_materialization_decisions", []
        )
    )

    admission_targets = {
        "materialize": (
            "when naturally observed: an observed actionable delivery signal "
            "with a concrete candidate_problem"
        ),
        "no_action": (
            "when naturally observed: an observed informational/resolved "
            "signal with no new PBI work"
        ),
        "discover_more": (
            "when naturally observed: an inferred/reported/ambiguous signal "
            "that must return to bounded discovery"
        ),
    }
    materialization_targets = {
        "create_new": (
            "when naturally observed after reviewed materialize admission: "
            "no equivalent open work matches the intended outcome"
        ),
        "update_existing": (
            "when naturally observed after reviewed materialize admission: "
            "same goal/problem exists but a semantic requirement/AC delta "
            "needs an update"
        ),
        "link_only": (
            "when naturally observed after reviewed materialize admission: "
            "existing work has the same semantics and only new evidence "
            "needs linking"
        ),
    }

    gaps: list[dict[str, Any]] = []
    for decision in ("materialize", "no_action", "discover_more"):
        if decision in admission_missing:
            gaps.append(
                {
                    "stage": "admission",
                    "decision": decision,
                    "observation_condition": admission_targets[decision],
                    "observation_mode": "opportunistic_real_run_only",
                    "prerequisites": [],
                    "prerequisites_satisfied": True,
                    "collector_path_available": True,
                    "real_runtime_observation_available": None,
                }
            )
    admission_materialize_observed = (
        "materialize"
        in admission.get("coverage", {}).get(
            "reviewed_expected_admission_decisions", []
        )
    )
    for decision in ("create_new", "update_existing", "link_only"):
        if decision in materialization_missing:
            gaps.append(
                {
                    "stage": "materialization",
                    "decision": decision,
                    "observation_condition": materialization_targets[decision],
                    "observation_mode": "opportunistic_real_run_only",
                    "prerequisites": [
                        "reviewed_admission_materialize_case"
                    ],
                    "prerequisites_satisfied": (
                        admission_materialize_observed
                    ),
                    "collector_path_available": (
                        admission_materialize_observed
                    ),
                    "real_runtime_observation_available": None,
                }
            )

    blockers: list[str] = []
    if admission.get("invalid_case_total", 0):
        blockers.append("invalid_admission_case_artifacts_present")
    if materialization.get("invalid_case_total", 0):
        blockers.append("invalid_materialization_case_artifacts_present")
    if not admission.get("has_tracked_live_evidence", False):
        blockers.append("tracked_admission_live_case_missing")
    if not materialization.get("has_tracked_live_evidence", False):
        blockers.append("tracked_materialization_live_case_missing")

    return {
        "mode": "pbi_live_shadow_collection_plan",
        "scope": "repository_tracked_live_shadow_gaps",
        "inventory_snapshot": {
            "admission": {
                "tracked_live_case_total": admission[
                    "tracked_live_case_total"
                ],
                "invalid_case_total": admission["invalid_case_total"],
                "observed_actual_decisions": admission["coverage"][
                    "observed_admission_decisions"
                ],
                "reviewed_expected_decisions": admission["coverage"][
                    "reviewed_expected_admission_decisions"
                ],
                "missing_reviewed_decisions": admission_missing,
                "observed_source_kinds": admission["coverage"][
                    "observed_source_kinds"
                ],
            },
            "materialization": {
                "tracked_live_case_total": materialization[
                    "tracked_live_case_total"
                ],
                "invalid_case_total": materialization["invalid_case_total"],
                "observed_actual_decisions": materialization["coverage"][
                    "observed_materialization_decisions"
                ],
                "reviewed_expected_decisions": materialization["coverage"][
                    "reviewed_expected_materialization_decisions"
                ],
                "missing_reviewed_decisions": materialization_missing,
            },
        },
        "observation_gaps": gaps,
        "observation_gap_count": len(gaps),
        "collector_path_available_gap_count": sum(
            1 for item in gaps if item.get("collector_path_available") is True
        ),
        "collection_execution_status": (
            "not_needed"
            if not gaps
            else (
                "available"
                if any(
                    item.get("collector_path_available") is True
                    for item in gaps
                )
                else "blocked_by_prerequisites"
            )
        ),
        "collection_execution_blocked": bool(gaps) and not any(
            item.get("collector_path_available") is True for item in gaps
        ),
        "blockers": blockers,
        "completion_blockers": blockers,
        "blocker_semantics": "rollout_completion_not_collection_execution",
        "policy_boundary": {
            "opportunistic_observation_only": True,
            "synthetic_case_generation_for_coverage_allowed": False,
            "historical_relabeling_allowed": False,
            "decision_coverage_quota_defined": False,
            "source_kind_coverage_requirement_defined": False,
            "representative_coverage_claim_allowed": False,
            "coverage_complete_implies_representative": False,
            "observation_gap_is_quota": False,
            "observation_gap_is_case_generation_instruction": False,
            "coverage_gap_basis": "reviewed_expected_decisions",
            "maker_actual_counts_as_ground_truth_coverage": False,
            "runtime_execution_verified": False,
            "real_runtime_observation_available_verified": False,
            "quality_thresholds_applied": False,
            "quality_acceptance_decided": False,
        },
        "authority": {
            "read_only": True,
            "write_allowed": False,
            "close_allowed": False,
            "suppression_allowed": False,
            "merge_allowed": False,
        },
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

    reviewed_case = sub.add_parser("case")
    reviewed_case.add_argument("--packet-ref", required=True)
    reviewed_case.add_argument("--oracle-ref", required=True)
    reviewed_case.add_argument("--case-artifact-ref", required=True)

    materialization_case = sub.add_parser("materialization-case")
    materialization_case.add_argument("--admission-case-ref", required=True)
    materialization_case.add_argument("--payload-ref", required=True)
    materialization_case.add_argument("--existing-work-ref", required=True)
    materialization_case.add_argument("--oracle-ref", required=True)
    materialization_case.add_argument("--case-artifact-ref", required=True)

    sub.add_parser("inventory")
    sub.add_parser("materialization-inventory")
    sub.add_parser("collection-plan")

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
        elif args.command == "packet":
            result = collect_review_packet(
                repo_root=root,
                capture_ref=args.capture_ref,
                run_evidence_ref=args.run_evidence_ref,
                packet_ref=args.packet_ref,
            )
        elif args.command == "case":
            result = collect_reviewed_admission_case(
                repo_root=root,
                packet_ref=args.packet_ref,
                oracle_ref=args.oracle_ref,
                case_artifact_ref=args.case_artifact_ref,
            )
        elif args.command == "materialization-case":
            result = collect_reviewed_materialization_case(
                repo_root=root,
                admission_case_ref=args.admission_case_ref,
                payload_ref=args.payload_ref,
                existing_work_ref=args.existing_work_ref,
                oracle_ref=args.oracle_ref,
                case_artifact_ref=args.case_artifact_ref,
            )
        elif args.command == "materialization-inventory":
            result = inventory_live_materialization_cases(repo_root=root)
        elif args.command == "collection-plan":
            result = plan_live_shadow_collection(repo_root=root)
        else:
            result = inventory_live_shadow_cases(repo_root=root)
    except (CollectorError, pm.MaterializationError) as exc:
        print(str(exc), file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
