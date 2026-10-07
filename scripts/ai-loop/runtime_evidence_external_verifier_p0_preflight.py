#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """Read-only structural preflight for the external-verifier P0 decision.

The preflight reads ADR-007 only. It can establish that the repository-side
Human Decision Record is structurally consistent, but it cannot verify the
identity of the Human decision maker, authenticate decision evidence, prove
administrator independence, provision the external boundary, or authorize
runtime/dispatch promotion.
"""

import argparse
import hashlib
import json
import pathlib
import re
import stat
import sys
from typing import Any

DOMAIN = "plangate.runtime-r1-external-verifier-p0-preflight/v1"
CONTRACT_STAGE = "r1-external-verifier-p0-preflight-candidate-v1"
ADR_RELATIVE_PATH = pathlib.Path(
    "docs/decisions/adr-007-external-runtime-verifier-boundary.md"
)
MAX_ADR_BYTES = 256 * 1024

RECORD_KEYS = (
    "selected_option",
    "external_verifier_location",
    "external_verifier_admin",
    "nonce_ledger_owner",
    "trusted_issuer",
    "decision_recorded_by",
    "decision_recorded_at",
    "decision_evidence_ref",
)

STRONG_FALSE_FIELDS = (
    "human_decision_identity_verified",
    "decision_evidence_ref_authenticated",
    "external_boundary_provisioned_verified",
    "p1_activation_allowed",
    "external_provisioning_allowed",
    "admin_evidence_independently_verified",
    "nonce_one_time_consumption_verified",
    "independent_admin_boundary_verified",
    "independent_verifier_execution_attested",
    "runtime_probe_attestation_verified",
    "human_rollout_decision_verified",
    "dispatch_ready",
    "dispatch_allowed",
)

STATUS_RE = re.compile(r"^\*\*Status\*\*: (Proposed|Accepted)\s*$", re.MULTILINE)
MAKERS_RE = re.compile(r"^\*\*Decision Makers\*\*: (.+?)\s*$", re.MULTILINE)
STATE_RE = re.compile(
    r"^\*\*Decision state: (NOT_MADE|RECORDED_BY_HUMAN)\.\*\*\s*$",
    re.MULTILINE,
)
FIELD_RE = re.compile(r"^([a-z_]+) = (.+)$")


class P0PreflightError(ValueError):
    pass


def _sha256(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def _read_adr(repo_root: pathlib.Path) -> tuple[pathlib.Path, bytes]:
    root = repo_root.resolve(strict=True)
    path = root / ADR_RELATIVE_PATH
    try:
        st = path.lstat()
    except FileNotFoundError as exc:
        raise P0PreflightError(f"ADR-007 missing: {ADR_RELATIVE_PATH}") from exc
    if stat.S_ISLNK(st.st_mode):
        raise P0PreflightError("ADR-007 must not be a symlink")
    if not stat.S_ISREG(st.st_mode):
        raise P0PreflightError("ADR-007 must be a regular file")
    if st.st_size > MAX_ADR_BYTES:
        raise P0PreflightError(
            f"ADR-007 exceeds {MAX_ADR_BYTES} byte limit"
        )
    return path, path.read_bytes()


def _single_match(pattern: re.Pattern[str], text: str, label: str) -> str:
    values = pattern.findall(text)
    if len(values) != 1:
        raise P0PreflightError(f"{label}: expected exactly one value")
    return values[0].strip()


def _decision_record(text: str) -> dict[str, str]:
    start_marker = "### Human Decision Record"
    end_marker = "### Decision-state transition contract"
    if text.count(start_marker) != 1 or text.count(end_marker) != 1:
        raise P0PreflightError(
            "Human Decision Record section markers must occur exactly once"
        )
    section = text.split(start_marker, 1)[1].split(end_marker, 1)[0]
    fences = section.split("```text")
    if len(fences) != 2:
        raise P0PreflightError("Human Decision Record must contain one text fence")
    fenced_tail = fences[1].split("```", 1)
    if len(fenced_tail) != 2:
        raise P0PreflightError("Human Decision Record text fence is not closed")

    values: dict[str, str] = {}
    for raw in fenced_tail[0].strip().splitlines():
        match = FIELD_RE.fullmatch(raw.strip())
        if not match:
            raise P0PreflightError(
                f"Human Decision Record contains malformed line: {raw!r}"
            )
        key, value = match.groups()
        if key not in RECORD_KEYS:
            raise P0PreflightError(
                f"Human Decision Record contains unexpected key: {key}"
            )
        if key in values:
            raise P0PreflightError(
                f"Human Decision Record contains duplicate key: {key}"
            )
        values[key] = value.strip()

    missing = [key for key in RECORD_KEYS if key not in values]
    if missing:
        raise P0PreflightError(
            "Human Decision Record missing keys: " + ", ".join(missing)
        )
    return values


def evaluate_text(text: str, *, adr_sha256: str) -> dict[str, Any]:
    status = _single_match(STATUS_RE, text, "Status")
    decision_makers = _single_match(MAKERS_RE, text, "Decision Makers")
    decision_state = _single_match(STATE_RE, text, "Decision state")
    record = _decision_record(text)

    undecided = [key for key, value in record.items() if value == "UNDECIDED"]
    unassigned_makers = "UNASSIGNED" in decision_makers

    if status == "Proposed":
        if decision_state != "NOT_MADE":
            raise P0PreflightError(
                "Proposed ADR must use Decision state: NOT_MADE"
            )
        if not unassigned_makers:
            raise P0PreflightError(
                "Proposed ADR must keep Decision Makers UNASSIGNED"
            )
        if len(undecided) != len(RECORD_KEYS):
            raise P0PreflightError(
                "Proposed ADR must keep all Human Decision Record fields UNDECIDED"
            )
        state = "blocked_on_human_decision"
        recorded_candidate = False
        preflight_candidate = False
    else:
        if decision_state != "RECORDED_BY_HUMAN":
            raise P0PreflightError(
                "Accepted ADR must use Decision state: RECORDED_BY_HUMAN"
            )
        if unassigned_makers:
            raise P0PreflightError(
                "Accepted ADR must name the Decision Makers"
            )
        if undecided:
            raise P0PreflightError(
                "Accepted ADR must have no UNDECIDED Human Decision Record fields"
            )
        state = "human_decision_record_present_candidate"
        recorded_candidate = True
        preflight_candidate = True

    result: dict[str, Any] = {
        "schema_version": "1",
        "domain": DOMAIN,
        "contract_stage": CONTRACT_STAGE,
        "decision_record_path": ADR_RELATIVE_PATH.as_posix(),
        "decision_record_file_sha256": adr_sha256,
        "adr_status": status,
        "decision_state": decision_state,
        "decision_record_structurally_valid": True,
        "human_decision_recorded_candidate": recorded_candidate,
        "p1_preflight_candidate": preflight_candidate,
        "state": state,
        "record": record,
        "verification_limit": (
            "Repository-local structural preflight only. Human identity, "
            "decision-evidence authenticity, administrator independence, "
            "external provisioning, runtime attestation, Human rollout, and "
            "dispatch authority are not verified. Exit code 0 is structural "
            "preflight success only and is not provisioning permission."
        ),
    }
    for field in STRONG_FALSE_FIELDS:
        result[field] = False
    return result


def evaluate_repo(repo_root: pathlib.Path) -> dict[str, Any]:
    _, data = _read_adr(repo_root)
    try:
        text = data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise P0PreflightError("ADR-007 must be valid UTF-8") from exc
    return evaluate_text(text, adr_sha256=_sha256(data))


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=pathlib.Path,
        default=pathlib.Path.cwd(),
        help="PlanGate repository root (default: cwd)",
    )
    parser.add_argument("--pretty", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        result = evaluate_repo(args.repo_root)
    except (OSError, P0PreflightError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print(
        json.dumps(
            result,
            ensure_ascii=False,
            sort_keys=True,
            indent=2 if args.pretty else None,
            separators=None if args.pretty else (",", ":"),
        )
    )
    return 0 if result["p1_preflight_candidate"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
