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

__doc__ = """Content-address the proposal-only external verifier bootstrap package.

This validator binds the exact reviewed bootstrap bytes to a declared PlanGate
source commit before handoff to an external operator. It deliberately does not
prove that the declared commit contains those bytes, that an external operator
received/accepted them, or that an independent administration boundary exists.
Those facts require Evidence outside normal PlanGate repository authority.
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

import runtime_evidence_ingress as ingress  # noqa: E402


DOMAIN = "plangate.runtime-r1-external-verifier-bootstrap-manifest/v1"
CONTRACT_STAGE = "r1-external-verifier-bootstrap-manifest-candidate-v1"
PACKAGE_RELATIVE_DIR = pathlib.Path(
    "docs/working/_runtime-attestation/external-verifier-bootstrap"
)
REQUIRED_FILES = (
    "README.md",
    "nonce-ledger-policy.proposed.json",
    "operator-handoff.proposed.json",
    "verifier-workflow.proposed.yml",
)
MAX_FILE_BYTES = 512 * 1024
MAX_PACKAGE_BYTES = 2 * 1024 * 1024
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")

AUTHORITY_KEYS = {
    "agent_invoke_allowed",
    "code_write_allowed",
    "approval_write_allowed",
    "merge_allowed",
    "deploy_allowed",
}


class ExternalVerifierBootstrapManifestError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _require_package_dir(
    package_dir: str | pathlib.Path,
    *,
    repo_root: str | pathlib.Path,
) -> tuple[pathlib.Path, pathlib.Path]:
    root = pathlib.Path(repo_root).resolve()
    raw_package = pathlib.Path(package_dir)
    if not raw_package.is_absolute():
        raise ExternalVerifierBootstrapManifestError(
            ["bootstrap_dir: absolute path required"]
        )
    if not root.is_dir():
        raise ExternalVerifierBootstrapManifestError(
            ["repo_root: existing directory required"]
        )
    if not raw_package.exists():
        raise ExternalVerifierBootstrapManifestError(
            ["bootstrap_dir: directory must exist"]
        )

    mode = raw_package.lstat().st_mode
    if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
        raise ExternalVerifierBootstrapManifestError(
            ["bootstrap_dir: regular non-symlink directory required"]
        )
    if raw_package.parent.resolve() != raw_package.parent:
        raise ExternalVerifierBootstrapManifestError(
            ["bootstrap_dir: parent path must not traverse symlinks"]
        )

    package = raw_package.resolve()
    try:
        relative = package.relative_to(root)
    except ValueError as exc:
        raise ExternalVerifierBootstrapManifestError(
            ["bootstrap_dir: package must stay inside repository"]
        ) from exc

    if relative != PACKAGE_RELATIVE_DIR:
        raise ExternalVerifierBootstrapManifestError(
            [
                "bootstrap_dir: exact reviewed package path required: "
                + PACKAGE_RELATIVE_DIR.as_posix()
            ]
        )
    return root, package


def build_manifest(
    *,
    repo_root: str | pathlib.Path,
    bootstrap_dir: str | pathlib.Path,
    declared_source_commit: str,
) -> dict[str, Any]:
    if not isinstance(declared_source_commit, str) or COMMIT_RE.fullmatch(
        declared_source_commit
    ) is None:
        raise ExternalVerifierBootstrapManifestError(
            ["declared_source_commit: 40 lowercase hex Git commit required"]
        )

    root, package = _require_package_dir(
        bootstrap_dir,
        repo_root=repo_root,
    )

    entries = list(package.iterdir())
    actual_names = sorted(entry.name for entry in entries)
    required_names = sorted(REQUIRED_FILES)
    if actual_names != required_names:
        raise ExternalVerifierBootstrapManifestError(
            [
                "bootstrap_dir: exact required file set mismatch; "
                f"required={required_names!r} actual={actual_names!r}"
            ]
        )

    files: list[dict[str, Any]] = []
    total_bytes = 0
    for name in REQUIRED_FILES:
        source = package / name
        mode = source.lstat().st_mode
        if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
            raise ExternalVerifierBootstrapManifestError(
                [f"bootstrap_file {name}: regular non-symlink file required"]
            )
        if source.parent.resolve() != source.parent:
            raise ExternalVerifierBootstrapManifestError(
                [f"bootstrap_file {name}: parent path must not traverse symlinks"]
            )

        raw = source.read_bytes()
        if len(raw) > MAX_FILE_BYTES:
            raise ExternalVerifierBootstrapManifestError(
                [f"bootstrap_file {name}: exceeds 512 KiB limit"]
            )
        total_bytes += len(raw)
        if total_bytes > MAX_PACKAGE_BYTES:
            raise ExternalVerifierBootstrapManifestError(
                ["bootstrap package exceeds 2 MiB limit"]
            )

        files.append(
            {
                "path": source.relative_to(root).as_posix(),
                "sha256": _sha256_bytes(raw),
                "size_bytes": len(raw),
            }
        )

    package_binding = {
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "declared_source_commit": declared_source_commit,
        "files": files,
    }
    result: dict[str, Any] = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "declared_source_commit": declared_source_commit,
        "package_file_count": len(files),
        "package_total_bytes": total_bytes,
        "files": files,
        "package_content_hash": ingress._canonical_hash(package_binding),
        "exact_required_file_set_verified": True,
        "package_bytes_content_addressed_candidate": True,
        "declared_source_commit_bound_candidate": True,
        "bootstrap_contract_semantics_revalidated": False,
        "source_commit_repository_membership_verified": False,
        "external_operator_received_package_verified": False,
        "external_operator_accepted_package_verified": False,
        "admin_evidence_independently_verified": False,
        "nonce_one_time_consumption_verified": False,
        "independent_admin_boundary_verified": False,
        "independent_verifier_execution_attested": False,
        "runtime_probe_attestation_verified": False,
        "human_rollout_decision_verified": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "verification_limit": (
            "The exact local bootstrap bytes are content-addressed together with "
            "a declared source commit. This repository-local operation does not "
            "independently prove Git commit membership, external operator receipt "
            "or acceptance, administrator separation, nonce consumption, runtime "
            "attestation, Human approval, or dispatch authority."
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
    parser.add_argument("--bootstrap-dir", required=True)
    parser.add_argument("--declared-source-commit", required=True)
    args = parser.parse_args(argv)

    try:
        result = build_manifest(
            repo_root=args.repo_root,
            bootstrap_dir=args.bootstrap_dir,
            declared_source_commit=args.declared_source_commit,
        )
    except ExternalVerifierBootstrapManifestError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
