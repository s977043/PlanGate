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

__doc__ = """Intent Context Package v1 contract helper (#1389).

Responsibilities:
- validate JSON Schema + cross-reference semantics
- derive semantic context_ref without volatile audit metadata
- derive exact snapshot_ref from immutable artifact bytes
- reuse the repository canonical JSON hash contract; do not fork it

This module does not resolve external sources and does not make approval decisions.
"""

import argparse
import copy
from datetime import datetime
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
AI_LOOP_DIR = HERE / "ai-loop"
CONTRACT_MODULE_DIR = AI_LOOP_DIR if AI_LOOP_DIR.is_dir() else HERE
sys.path.insert(0, str(CONTRACT_MODULE_DIR))
import c3_contract  # noqa: E402

SCHEMA_PATH = REPO / "schemas" / "intent-context-package.schema.json"

_FORBIDDEN_KEYS = {
    "context_ref",
    "snapshot_ref",
    "raw_transcript",
    "chain_of_thought",
    "system_prompt",
    "user_prompt",
    "prompt_text",
    "api_key",
    "secret",
    "stdout",
    "stderr",
    "command_output",
    "raw_request",
    "raw_response",
    "absolute_path",
}
_WINDOWS_ABS = re.compile(r"^[A-Za-z]:[\\/]")


def _sorted_refs(values: list[str]) -> list[str]:
    return sorted(values)


def _norm_basis(value: dict[str, Any]) -> dict[str, Any]:
    return {"kind": value["kind"], "ref": value.get("ref")}


def semantic_projection(payload: dict[str, Any]) -> dict[str, Any]:
    """Return the deterministic semantic contract projection for context_ref.

    Volatile audit metadata (created_at, resolver_version, source.observed_at)
    and supersession bookkeeping are intentionally excluded so that
    re-resolving identical semantics does not make an approved Plan stale.
    """

    sources = []
    for src in sorted(payload["sources"], key=lambda x: x["source_id"]):
        sources.append(
            {
                "source_id": src["source_id"],
                "kind": src["kind"],
                "ref": src["ref"],
                "revision_ref": src.get("revision_ref"),
                "content_digest": src.get("content_digest"),
                "authority": src["authority"],
                "authority_basis": _norm_basis(src["authority_basis"]),
                "freshness": src["freshness"],
                "freshness_basis": _norm_basis(src["freshness_basis"]),
            }
        )

    def norm_statement(item: dict[str, Any], id_key: str, text_key: str) -> dict[str, Any]:
        return {
            id_key: item[id_key],
            text_key: item[text_key],
            "source_ids": _sorted_refs(item["source_ids"]),
        }

    summary = norm_statement(payload["intent"]["summary"], "statement_id", "text")
    outcomes = [
        norm_statement(x, "outcome_id", "text")
        for x in sorted(payload["intent"]["desired_outcomes"], key=lambda x: x["outcome_id"])
    ]
    non_goals = [
        norm_statement(x, "non_goal_id", "text")
        for x in sorted(payload["intent"]["non_goals"], key=lambda x: x["non_goal_id"])
    ]

    constraints = []
    for x in sorted(payload["constraints"], key=lambda x: x["constraint_id"]):
        constraints.append(
            {
                "constraint_id": x["constraint_id"],
                "category": x["category"],
                "statement": x["statement"],
                "source_ids": _sorted_refs(x["source_ids"]),
            }
        )

    acceptance_inputs = []
    for x in sorted(payload["acceptance_inputs"], key=lambda x: x["input_id"]):
        acceptance_inputs.append(
            {
                "input_id": x["input_id"],
                "statement": x["statement"],
                "source_ids": _sorted_refs(x["source_ids"]),
            }
        )

    assumptions = []
    for x in sorted(payload["assumptions"], key=lambda x: x["assumption_id"]):
        assumptions.append(
            {
                "assumption_id": x["assumption_id"],
                "statement": x["statement"],
                "source_ids": _sorted_refs(x["source_ids"]),
                "verification_needed": x["verification_needed"],
            }
        )

    unknowns = [
        copy.deepcopy(x)
        for x in sorted(payload["unknowns"], key=lambda x: x["unknown_id"])
    ]

    conflicts = []
    for x in sorted(payload["conflicts"], key=lambda x: x["conflict_id"]):
        conflicts.append(
            {
                "conflict_id": x["conflict_id"],
                "statement_refs": sorted(x["statement_refs"]),
                "source_ids": _sorted_refs(x["source_ids"]),
                "description": x["description"],
            }
        )

    return {
        "schema_version": payload["schema_version"],
        "context_id": payload["context_id"],
        "task_id": payload["task_id"],
        "intent": {
            "summary": summary,
            "desired_outcomes": outcomes,
            "non_goals": non_goals,
        },
        "sources": sources,
        "constraints": constraints,
        "acceptance_inputs": acceptance_inputs,
        "assumptions": assumptions,
        "unknowns": unknowns,
        "conflicts": conflicts,
    }


def compute_context_ref(payload: dict[str, Any]) -> str:
    """Semantic Plan-binding identity using the existing canonical hash contract."""
    return c3_contract.canonical_hash(semantic_projection(payload))


def compute_snapshot_ref(raw_bytes: bytes) -> str:
    """Exact immutable artifact identity; audit-only, never Plan stale identity."""
    return "sha256:" + hashlib.sha256(raw_bytes).hexdigest()


def _walk_keys(value: Any, path: str = "<root>") -> list[str]:
    errors: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in _FORBIDDEN_KEYS:
                errors.append(f"forbidden key at {path}: {key}")
            errors.extend(_walk_keys(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for idx, child in enumerate(value):
            errors.extend(_walk_keys(child, f"{path}[{idx}]"))
    return errors


def _statement_entries(payload: dict[str, Any]) -> list[tuple[str, list[str]]]:
    items: list[tuple[str, list[str]]] = []
    summary = payload["intent"]["summary"]
    items.append((summary["statement_id"], summary["source_ids"]))
    for x in payload["intent"]["desired_outcomes"]:
        items.append((x["outcome_id"], x["source_ids"]))
    for x in payload["intent"]["non_goals"]:
        items.append((x["non_goal_id"], x["source_ids"]))
    for x in payload["constraints"]:
        items.append((x["constraint_id"], x["source_ids"]))
    for x in payload["acceptance_inputs"]:
        items.append((x["input_id"], x["source_ids"]))
    return items


def _validate_datetime(value: Any, field: str) -> str | None:
    """Require an offset-aware RFC3339-compatible date-time.

    jsonschema format checking may depend on optional format packages in some
    environments, so the contract enforces this invariant explicitly too.
    """
    if not isinstance(value, str) or not value:
        return f"{field} must be a non-empty date-time string"
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return f"{field} is not a valid RFC3339-compatible date-time"
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        return f"{field} must include a timezone offset"
    return None


def validate_semantics(payload: dict[str, Any]) -> list[str]:
    """Validate cross-reference and provenance rules not expressible cleanly in JSON Schema."""
    errors = _walk_keys(payload)

    created_at_error = _validate_datetime(payload.get("created_at"), "created_at")
    if created_at_error:
        errors.append(created_at_error)
    for src in payload.get("sources", []):
        observed_error = _validate_datetime(
            src.get("observed_at"), f"{src.get('source_id', '<unknown>')}.observed_at"
        )
        if observed_error:
            errors.append(observed_error)

    source_ids = [x["source_id"] for x in payload.get("sources", [])]
    source_set = set(source_ids)
    if len(source_ids) != len(source_set):
        errors.append("duplicate source_id")

    statement_entries = _statement_entries(payload)
    statement_ids = [sid for sid, _ in statement_entries]
    assumption_ids = [x["assumption_id"] for x in payload.get("assumptions", [])]
    unknown_ids = [x["unknown_id"] for x in payload.get("unknowns", [])]
    all_statement_ids = statement_ids + assumption_ids + unknown_ids
    if len(all_statement_ids) != len(set(all_statement_ids)):
        errors.append("duplicate normalized statement/uncertainty id")

    for sid, refs in statement_entries:
        missing = sorted(set(refs) - source_set)
        if missing:
            errors.append(f"{sid} references unknown source_id(s): {', '.join(missing)}")

    for assumption in payload.get("assumptions", []):
        missing = sorted(set(assumption.get("source_ids", [])) - source_set)
        if missing:
            errors.append(
                f"{assumption['assumption_id']} references unknown source_id(s): {', '.join(missing)}"
            )

    known_statement_refs = set(all_statement_ids)
    for conflict in payload.get("conflicts", []):
        missing_sources = sorted(set(conflict["source_ids"]) - source_set)
        if missing_sources:
            errors.append(
                f"{conflict['conflict_id']} references unknown source_id(s): "
                + ", ".join(missing_sources)
            )
        missing_statements = sorted(set(conflict["statement_refs"]) - known_statement_refs)
        if missing_statements:
            errors.append(
                f"{conflict['conflict_id']} references unknown statement(s): "
                + ", ".join(missing_statements)
            )

    for src in payload.get("sources", []):
        refs_to_check = [
            ("ref", src.get("ref")),
            ("authority_basis.ref", src.get("authority_basis", {}).get("ref")),
            ("freshness_basis.ref", src.get("freshness_basis", {}).get("ref")),
        ]
        for label, ref in refs_to_check:
            if isinstance(ref, str) and (ref.startswith("/") or _WINDOWS_ABS.match(ref)):
                errors.append(
                    f"{src['source_id']} {label} uses non-portable absolute local path"
                )
        if src.get("authority") == "authoritative":
            authority_basis = src.get("authority_basis", {})
            if (
                authority_basis.get("kind") == "unverified_default"
                or not authority_basis.get("ref")
            ):
                errors.append(f"{src['source_id']} authoritative source lacks valid authority basis")
        if src.get("freshness") == "current":
            if not (src.get("revision_ref") or src.get("content_digest")):
                errors.append(f"{src['source_id']} current source lacks observed identity")
            freshness_basis = src.get("freshness_basis", {})
            if freshness_basis.get("kind") == "unavailable" or not freshness_basis.get("ref"):
                errors.append(f"{src['source_id']} current source lacks freshness evidence")

    return errors



def authoritative_conflicts(payload: dict[str, Any]) -> list[str]:
    """Return conflict IDs backed by at least two authoritative sources.

    Conflict resolution is intentionally not attempted here. This helper only
    exposes the deterministic safety condition consumed by the C-3' builder:
    unresolved authoritative conflicts cannot be AUTO_APPROVED.
    """
    authority = {
        src["source_id"]: src.get("authority")
        for src in payload.get("sources", [])
        if isinstance(src, dict) and isinstance(src.get("source_id"), str)
    }
    result: list[str] = []
    for conflict in payload.get("conflicts", []):
        if not isinstance(conflict, dict):
            continue
        authoritative_ids = {
            sid
            for sid in conflict.get("source_ids", [])
            if authority.get(sid) == "authoritative"
        }
        if len(authoritative_ids) >= 2:
            result.append(str(conflict.get("conflict_id", "<unknown>")))
    return sorted(result)



def validate_schema(payload: dict[str, Any]) -> list[str]:
    try:
        from jsonschema import Draft202012Validator, FormatChecker
    except ImportError as exc:
        raise RuntimeError("jsonschema not installed; run: pip install 'jsonschema>=4,<5'") from exc

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(validator.iter_errors(payload), key=lambda e: list(e.absolute_path))
    result: list[str] = []
    for err in errors:
        path = "/".join(str(x) for x in err.absolute_path) or "<root>"
        result.append(f"{path}: {err.message}")
    return result


def validate_package(payload: dict[str, Any]) -> list[str]:
    schema_errors = validate_schema(payload)
    if schema_errors:
        return schema_errors
    return validate_semantics(payload)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Intent Context Package v1 and print derived refs")
    parser.add_argument("package", help="path to intent-context.json")
    args = parser.parse_args()

    path = Path(args.package)
    try:
        raw = path.read_bytes()
        payload = json.loads(raw)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    errors = validate_package(payload)
    if errors:
        for err in errors:
            print(f"[FAIL] {err}", file=sys.stderr)
        return 1

    print(f"context_ref={compute_context_ref(payload)}")
    print(f"snapshot_ref={compute_snapshot_ref(raw)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
