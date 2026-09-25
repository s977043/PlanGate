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

__doc__ = """reviewer_normalize.py — deterministic external-review normalization.

Issue #1394. This module is the single provider-specific normalization boundary
for structured external-review output. It does not make approval decisions,
perform semantic similarity, or infer Deliberation positions from findings.

Provider/lane identity is supplied by the PlanGate runtime and overrides any
self-asserted identity in provider output.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
ADAPTER_RIVER_REVIEW_V1 = "river-review-v1"
ADAPTER_PLANGATE_NORMALIZED_V1 = "plangate-normalized-v1"
SUPPORTED_ADAPTERS = (
    ADAPTER_RIVER_REVIEW_V1,
    ADAPTER_PLANGATE_NORMALIZED_V1,
)

SEVERITIES = ("critical", "major", "minor", "info")
STANCE_VALUES = ("support", "oppose", "conditional", "unknown")
POSITION_CAPABILITIES = ("explicit", "unavailable")
EXECUTION_STATUSES = ("executed", "unavailable")
NORMALIZATION_STATUSES = ("valid", "invalid")

_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")


class NormalizeError(ValueError):
    pass


def _string(value: Any, *, field: str, allow_empty: bool = False) -> str:
    if not isinstance(value, str):
        raise NormalizeError(f"{field}: expected string")
    if not allow_empty and not value.strip():
        raise NormalizeError(f"{field}: empty")
    return value


def _string_list(value: Any, *, field: str) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise NormalizeError(f"{field}: expected array")
    result: list[str] = []
    for idx, item in enumerate(value):
        result.append(_string(item, field=f"{field}[{idx}]"))
    return result


def normalize_severity(value: Any) -> str:
    """Normalize severity using PlanGate's existing safe fallback."""
    if isinstance(value, str):
        candidate = value.strip().lower()
        if candidate in SEVERITIES:
            return candidate
    return "major"


def _runtime_identity(provider: str, lane: str) -> tuple[str, str]:
    provider = _string(provider, field="provider")
    lane = _string(lane, field="lane")
    if not _ID_RE.fullmatch(provider):
        raise NormalizeError("provider: invalid identifier")
    if not _ID_RE.fullmatch(lane):
        raise NormalizeError("lane: invalid identifier")
    return provider, lane


def _base_envelope(
    *,
    provider: str,
    lane: str,
    execution_status: str = "executed",
    normalization_status: str = "valid",
    position_capability: str = "unavailable",
    findings: list[dict[str, Any]] | None = None,
    positions: list[dict[str, Any]] | None = None,
    limitations: list[str] | None = None,
) -> dict[str, Any]:
    if execution_status not in EXECUTION_STATUSES:
        raise NormalizeError("execution_status: invalid")
    if normalization_status not in NORMALIZATION_STATUSES:
        raise NormalizeError("normalization_status: invalid")
    if position_capability not in POSITION_CAPABILITIES:
        raise NormalizeError("position_capability: invalid")
    if position_capability == "unavailable" and positions:
        raise NormalizeError("positions must be empty when capability is unavailable")

    provider, lane = _runtime_identity(provider, lane)
    return {
        "schema_version": SCHEMA_VERSION,
        "execution_status": execution_status,
        "normalization_status": normalization_status,
        "reviewer_id": provider,
        "lane": lane,
        "position_capability": position_capability,
        "findings": findings or [],
        "positions": positions or [],
        "limitations": limitations or [],
    }


def _river_evidence_refs(issue: dict[str, Any]) -> list[str]:
    refs: list[str] = []

    for key in ("criterionRefs", "artifactRefs"):
        for value in _string_list(issue.get(key), field=key):
            if value not in refs:
                refs.append(value)

    file_name = _string(issue.get("file"), field="issue.file")
    line = issue.get("line")
    if line is not None:
        if not isinstance(line, int) or isinstance(line, bool) or line < 1:
            raise NormalizeError("issue.line: expected positive integer")
        location = f"{file_name}:{line}"
    else:
        location = file_name
    if location not in refs:
        refs.append(location)

    return refs


def normalize_river_review_v1(
    raw: Any,
    *,
    provider: str,
    lane: str,
) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise NormalizeError("river-review-v1: root must be object")

    issues = raw.get("issues")
    summary = raw.get("summary")
    if not isinstance(issues, list):
        raise NormalizeError("river-review-v1: issues must be array")
    if not isinstance(summary, dict):
        raise NormalizeError("river-review-v1: summary must be object")

    findings: list[dict[str, Any]] = []
    required = ("id", "ruleId", "title", "message", "severity", "phase", "file")

    for idx, issue in enumerate(issues):
        if not isinstance(issue, dict):
            raise NormalizeError(f"issues[{idx}]: expected object")
        for key in required:
            if key not in issue:
                raise NormalizeError(f"issues[{idx}].{key}: missing")

        source_ref = _string(issue["id"], field=f"issues[{idx}].id")
        title = _string(issue["title"], field=f"issues[{idx}].title")
        message = _string(issue["message"], field=f"issues[{idx}].message")

        findings.append(
            {
                "source_finding_ref": source_ref,
                "severity": normalize_severity(issue["severity"]),
                "claim": title,
                "rationale_summary": message,
                "evidence_refs": _river_evidence_refs(issue),
            }
        )

    limitations = ["positions_unavailable_from_finding_only_adapter"]
    if raw.get("timedOutRoles"):
        limitations.append("river_review_timed_out_roles_present")

    # River Review run-level decision/gate and finding presence/absence are
    # deliberately NOT converted into Deliberation stance.
    return _base_envelope(
        provider=provider,
        lane=lane,
        findings=findings,
        positions=[],
        position_capability="unavailable",
        limitations=limitations,
    )


def _normalize_explicit_position(value: Any, *, idx: int) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise NormalizeError(f"positions[{idx}]: expected object")

    required = (
        "position_id",
        "stance",
        "severity",
        "claim",
        "rationale_summary",
        "evidence_refs",
        "assumptions",
    )
    for key in required:
        if key not in value:
            raise NormalizeError(f"positions[{idx}].{key}: missing")

    position_id = _string(value["position_id"], field=f"positions[{idx}].position_id")
    stance = _string(value["stance"], field=f"positions[{idx}].stance")
    if stance not in STANCE_VALUES:
        raise NormalizeError(f"positions[{idx}].stance: invalid")

    severity = normalize_severity(value["severity"])
    claim = _string(value["claim"], field=f"positions[{idx}].claim")
    rationale = _string(
        value["rationale_summary"],
        field=f"positions[{idx}].rationale_summary",
    )
    evidence_refs = _string_list(
        value["evidence_refs"],
        field=f"positions[{idx}].evidence_refs",
    )
    assumptions = _string_list(
        value["assumptions"],
        field=f"positions[{idx}].assumptions",
    )

    result: dict[str, Any] = {
        "position_id": position_id,
        "stance": stance,
        "severity": severity,
        "claim": claim,
        "rationale_summary": rationale,
        "evidence_refs": evidence_refs,
        "assumptions": assumptions,
    }

    source_ref = value.get("source_finding_ref")
    if source_ref is not None:
        result["source_finding_ref"] = _string(
            source_ref,
            field=f"positions[{idx}].source_finding_ref",
        )

    return result


def normalize_plangate_normalized_v1(
    raw: Any,
    *,
    provider: str,
    lane: str,
) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise NormalizeError("plangate-normalized-v1: root must be object")

    capability = raw.get("position_capability", "unavailable")
    if capability not in POSITION_CAPABILITIES:
        raise NormalizeError("position_capability: invalid")

    raw_findings = raw.get("findings", [])
    if not isinstance(raw_findings, list):
        raise NormalizeError("findings: expected array")

    findings: list[dict[str, Any]] = []
    for idx, finding in enumerate(raw_findings):
        if not isinstance(finding, dict):
            raise NormalizeError(f"findings[{idx}]: expected object")
        for key in (
            "source_finding_ref",
            "severity",
            "claim",
            "rationale_summary",
            "evidence_refs",
        ):
            if key not in finding:
                raise NormalizeError(f"findings[{idx}].{key}: missing")
        findings.append(
            {
                "source_finding_ref": _string(
                    finding["source_finding_ref"],
                    field=f"findings[{idx}].source_finding_ref",
                ),
                "severity": normalize_severity(finding["severity"]),
                "claim": _string(
                    finding["claim"],
                    field=f"findings[{idx}].claim",
                ),
                "rationale_summary": _string(
                    finding["rationale_summary"],
                    field=f"findings[{idx}].rationale_summary",
                ),
                "evidence_refs": _string_list(
                    finding["evidence_refs"],
                    field=f"findings[{idx}].evidence_refs",
                ),
            }
        )

    raw_positions = raw.get("positions", [])
    if not isinstance(raw_positions, list):
        raise NormalizeError("positions: expected array")
    positions = [
        _normalize_explicit_position(position, idx=idx)
        for idx, position in enumerate(raw_positions)
    ]

    if capability == "unavailable" and positions:
        raise NormalizeError("positions present while position_capability=unavailable")
    if capability == "explicit" and not positions:
        raise NormalizeError("position_capability=explicit requires at least one position")

    limitations = _string_list(raw.get("limitations", []), field="limitations")

    # Runtime identity wins over any provider/lane fields present in raw data.
    return _base_envelope(
        provider=provider,
        lane=lane,
        findings=findings,
        positions=positions,
        position_capability=capability,
        limitations=limitations,
    )


def normalize(
    raw: Any,
    *,
    adapter: str,
    provider: str,
    lane: str,
) -> dict[str, Any]:
    if adapter == ADAPTER_RIVER_REVIEW_V1:
        return normalize_river_review_v1(raw, provider=provider, lane=lane)
    if adapter == ADAPTER_PLANGATE_NORMALIZED_V1:
        return normalize_plangate_normalized_v1(raw, provider=provider, lane=lane)
    raise NormalizeError(f"unsupported adapter: {adapter}")


def invalid_envelope(
    *,
    provider: str,
    lane: str,
    reason: str,
    execution_status: str = "executed",
) -> dict[str, Any]:
    return _base_envelope(
        provider=provider,
        lane=lane,
        execution_status=execution_status,
        normalization_status="invalid",
        position_capability="unavailable",
        limitations=[reason],
    )


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    obj: dict[str, Any] = {}
    for key, value in pairs:
        if key in obj:
            raise NormalizeError(f"duplicate JSON key: {key}")
        obj[key] = value
    return obj


def _reject_non_finite(token: str) -> Any:
    raise NormalizeError(f"non-finite JSON number: {token}")


def _read_json(path: str) -> Any:
    text = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    return json.loads(
        text,
        object_pairs_hook=_reject_duplicate_keys,
        parse_constant=_reject_non_finite,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter", choices=SUPPORTED_ADAPTERS, required=True)
    parser.add_argument("--provider", required=True)
    parser.add_argument("--lane", required=True)
    parser.add_argument("--input", required=True)
    args = parser.parse_args(argv)

    try:
        raw = _read_json(args.input)
        envelope = normalize(
            raw,
            adapter=args.adapter,
            provider=args.provider,
            lane=args.lane,
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, NormalizeError) as exc:
        try:
            envelope = invalid_envelope(
                provider=args.provider,
                lane=args.lane,
                reason=f"normalization_error:{type(exc).__name__}",
            )
        except NormalizeError:
            print(f"ERROR: invalid runtime identity: {exc}", file=sys.stderr)
            return 2
        print(json.dumps(envelope, ensure_ascii=False, sort_keys=True))
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print(json.dumps(envelope, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
