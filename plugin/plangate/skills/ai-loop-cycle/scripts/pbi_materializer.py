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

__doc__ = """pbi_materializer.py — ai-loop V2 feedback/Evidence -> PBI shadow materializer (#1442).

Phase 1 first slice:
- deterministic / stdlib-only / network-free
- Human / AI / mixed authoring
- observed / reported / inferred provenance
- Reuse / Update Before Create
- follow_up / replan_current timing and delivery / harness target separation
- circular provenance and privacy fail-closed
- shadow/read-only CLI only; no Issue/PBI write, close, merge, RunState mutation

The caller may inject normalized existing Issue/PBI candidates as JSON and/or allow a
local docs/working/TASK-*/pbi-input.md scan. GitHub/network access belongs to an adapter,
not this primitive.
"""

import argparse
import json
import pathlib
import re
import sys
import unicodedata
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_evidence  # noqa: E402

TASK_ID_RE = re.compile(r"^TASK-[0-9]{4}$")
RFC3339_RE = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
    r"(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})$"
)
COMMIT_SHA_RE = re.compile(r"^[0-9a-f]{40}$")

VALID_AUTHORS = {"human", "ai", "mixed"}
VALID_DISCOVERY_DEPTHS = {"minimal", "expanded"}
VALID_TIMINGS = {"follow_up", "replan_current"}
VALID_TARGETS = {"delivery", "harness"}
VALID_CLAIM_CLASSES = {"observed", "reported", "inferred"}
VALID_SOURCE_KINDS = {
    "human_feedback",
    "issue",
    "run_evidence",
    "failure_record",
    "measurement",
    "existing_behavior",
    "external_source",
    "decision_log",
    "policy",
}
VALID_ACCEPTANCE_BASES = {"evidence", "explicit_decision", "policy_rule"}
VALID_DECISIONS = {"update_existing", "link_only", "create_new"}
VALID_READINESS_STATUSES = {"ready", "blocked"}
VALID_EVAL_SPLITS = {"train", "test"}
VALID_EVIDENCE_CLASSES = {"synthetic_fixture", "historical_replay", "live_shadow"}
VALID_ADMISSION_DECISIONS = {"materialize", "no_action", "discover_more"}
VALID_SIGNAL_DISPOSITIONS = {"actionable", "resolved", "informational", "ambiguous"}
VALID_READINESS_ROUTES = {
    "future_run",
    "replan_current",
    "harness_candidate_required",
    "harness_follow_up",
    "bound_pbi_requires_replan",
}

FORBIDDEN_LOCAL_KEYS = {
    "raw_transcript",
    "transcript",
    "session_transcript",
    "session_log",
    "hidden_cot",
    "chain_of_thought",
    "reasoning_trace",
}

DOWNSTREAM_FILENAMES = {
    "pbi-input.md",
    "plan.md",
    "todo.md",
    "test-cases.md",
    "review-self.md",
    "review-external.md",
    "handoff.md",
    "current-state.md",
    "status.md",
    "INDEX.md",
}
DERIVED_FILENAMES = DOWNSTREAM_FILENAMES - {"pbi-input.md"}


class MaterializationError(ValueError):
    """Fail-closed validation error with machine-readable error strings."""

    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _norm(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    return " ".join(unicodedata.normalize("NFKC", value).strip().lower().split())


def _as_string_list(value: Any, field: str, errors: list[str]) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        errors.append(f"{field}: array required")
        return []
    out: list[str] = []
    for i, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            errors.append(f"{field}[{i}]: non-empty string required")
            continue
        out.append(item.strip())
    return out


def _walk_keys(value: Any, path: str = "$"):
    if isinstance(value, dict):
        for key, child in value.items():
            yield path, str(key), child
            yield from _walk_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for i, child in enumerate(value):
            yield from _walk_keys(child, f"{path}[{i}]")


def _privacy_projection(value: Any) -> Any:
    """Rename only non-identifying categorical PBI author values for EH-8 reuse.

    Any other author value stays under the original key and remains subject to the
    RunEvidence account-identifier privacy policy.
    """
    if isinstance(value, dict):
        out = {}
        for key, child in value.items():
            projected_key = (
                "pbi_author_kind"
                if key == "author" and child in VALID_AUTHORS
                else key
            )
            out[projected_key] = _privacy_projection(child)
        return out
    if isinstance(value, list):
        return [_privacy_projection(item) for item in value]
    return value


def _privacy_errors(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for path, key, _value in _walk_keys(payload):
        if _norm(key).replace("-", "_") in FORBIDDEN_LOCAL_KEYS:
            errors.append(f"privacy: forbidden key {path}.{key}")

    # Reuse the RunEvidence privacy backstop instead of forking its key/value rules.
    # PBI author categories (human|ai|mixed) are roles, not account identifiers.
    privacy_projection = _privacy_projection(payload)
    errors.extend(
        f"privacy: {e}"
        for e in run_evidence.check_output_privacy(privacy_projection)
    )
    return errors


def _is_circular_source(task_id: str, source_ref: str) -> bool:
    ref = source_ref.replace("\\", "/")
    marker = f"docs/working/{task_id}/"
    if marker not in ref:
        return False
    name = ref.rsplit("/", 1)[-1]
    return name in DOWNSTREAM_FILENAMES


def _claim_origin_ref(claim: dict[str, Any]) -> str:
    origin = claim.get("origin_ref")
    return origin.strip() if isinstance(origin, str) and origin.strip() else str(
        claim.get("source_ref", "")
    ).strip()


def _detect_authority_root(authority_root=None) -> pathlib.Path | None:
    """Resolve the repository root used only for acceptance-authority verification."""
    if authority_root is not None:
        # An explicit trust root is authoritative. Never silently fall back to cwd/source
        # roots when it is invalid, otherwise a caller can believe it verified repo A
        # while the materializer actually verified repo B.
        candidates = [pathlib.Path(authority_root)]
    else:
        candidates = [pathlib.Path.cwd(), *HERE.parents]
    seen = set()
    for candidate in candidates:
        try:
            root = candidate.resolve()
        except OSError:
            continue
        if root in seen:
            continue
        seen.add(root)
        if not root.is_dir():
            continue
        if (root / "docs").is_dir() and (
            (root / "scripts").is_dir() or (root / ".git").exists()
        ):
            return root
    return None


def _resolve_repo_authority_ref(
    source_ref: str, authority_root=None
) -> tuple[pathlib.Path | None, str, list[str]]:
    """Resolve a repository-relative ref without permitting traversal or absolute paths."""
    errors = []
    root = _detect_authority_root(authority_root)
    if root is None:
        return None, "", [
            "authority_ref: repository root could not be resolved; pass --authority-root"
        ]

    path_text, sep, fragment = source_ref.partition("#")
    if not path_text or "\\" in path_text:
        return None, fragment, [f"authority_ref: invalid repository path: {source_ref!r}"]
    pure = pathlib.PurePosixPath(path_text)
    if pure.is_absolute() or ".." in pure.parts:
        return None, fragment, [f"authority_ref: absolute/traversal ref rejected: {source_ref!r}"]

    resolved = (root / pathlib.Path(*pure.parts)).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        return None, fragment, [f"authority_ref: ref escapes repository root: {source_ref!r}"]
    if not resolved.is_file():
        return None, fragment, [f"authority_ref: repository source does not exist: {source_ref!r}"]
    return resolved, fragment if sep else "", errors


def _markdown_heading_slugs(text: str) -> set[str]:
    """Return a conservative GitHub-style heading slug set for policy refs."""
    slugs: set[str] = set()
    counts: dict[str, int] = {}
    for line in text.splitlines():
        match = re.match(r"^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$", line)
        if not match:
            continue
        heading = unicodedata.normalize("NFKC", match.group(1)).strip().lower()
        chars = []
        for ch in heading:
            if ch.isspace():
                chars.append("-")
            elif ch.isalnum() or ch in "-_":
                chars.append(ch)
        base = re.sub(r"-+", "-", "".join(chars)).strip("-")
        if not base:
            continue
        count = counts.get(base, 0)
        counts[base] = count + 1
        slugs.add(base if count == 0 else f"{base}-{count}")
    return slugs


def _markdown_fragment_exists(path: pathlib.Path, fragment: str) -> bool:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return False
    if fragment in _markdown_heading_slugs(text):
        return True
    escaped = re.escape(fragment)
    return bool(re.search(
        rf'<a\s+[^>]*id=["\']{escaped}["\'][^>]*>',
        text,
        flags=re.IGNORECASE,
    ))


def _verify_acceptance_authority_ref(
    source_ref: str, source_kind: str, authority_root=None
) -> list[str]:
    path, fragment, errors = _resolve_repo_authority_ref(source_ref, authority_root)
    if errors or path is None:
        return errors

    if source_kind == "decision_log":
        if path.name != "decision-log.jsonl":
            return [
                f"authority_ref: decision_log must reference decision-log.jsonl: {source_ref!r}"
            ]
        if not fragment:
            return [
                f"authority_ref: decision_log requires a decision_id fragment: {source_ref!r}"
            ]
        matches = 0
        try:
            for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError as exc:
                    return [
                        f"authority_ref: malformed decision-log JSONL at {path.name}:{lineno}: {exc}"
                    ]
                if isinstance(record, dict) and record.get("decision_id") == fragment:
                    matches += 1
        except OSError as exc:
            return [f"authority_ref: cannot read {source_ref!r}: {exc}"]
        if matches != 1:
            return [
                f"authority_ref: decision_id {fragment!r} must exist exactly once in {path.name}; found {matches}"
            ]
    elif source_kind == "policy":
        if not fragment:
            return [
                f"authority_ref: policy requires a rule fragment: {source_ref!r}"
            ]
        if path.suffix.lower() != ".md":
            return [
                f"authority_ref: Phase 1 policy authority must be a Markdown source: {source_ref!r}"
            ]
        if not _markdown_fragment_exists(path, fragment):
            return [
                f"authority_ref: policy rule fragment {fragment!r} does not exist in {path.name}"
            ]
    else:
        return [f"authority_ref: unsupported acceptance authority kind: {source_kind!r}"]
    return []


def validate_admission_signal(signal: Any) -> list[str]:
    """Validate a normalized delivery signal before PBI materialization."""
    errors: list[str] = []
    if not isinstance(signal, dict):
        return ["admission_signal: object required"]

    for field in ("signal_id", "source_ref", "statement"):
        if not isinstance(signal.get(field), str) or not signal.get(field, "").strip():
            errors.append(f"admission_signal.{field}: non-empty string required")

    source_kind = signal.get("source_kind")
    if source_kind not in VALID_SOURCE_KINDS:
        errors.append(
            f"admission_signal.source_kind: one of {sorted(VALID_SOURCE_KINDS)} required"
        )

    claim_class = signal.get("claim_class")
    if claim_class not in VALID_CLAIM_CLASSES:
        errors.append(
            f"admission_signal.claim_class: one of {sorted(VALID_CLAIM_CLASSES)} required"
        )

    disposition = signal.get("disposition")
    if disposition not in VALID_SIGNAL_DISPOSITIONS:
        errors.append(
            "admission_signal.disposition: "
            f"one of {sorted(VALID_SIGNAL_DISPOSITIONS)} required"
        )

    target = signal.get("target_layer", "delivery")
    if target not in VALID_TARGETS:
        errors.append(
            f"admission_signal.target_layer: one of {sorted(VALID_TARGETS)} required"
        )

    candidate_problem = signal.get("candidate_problem")
    if candidate_problem is not None and (
        not isinstance(candidate_problem, str) or not candidate_problem.strip()
    ):
        errors.append(
            "admission_signal.candidate_problem: null or non-empty string required"
        )

    errors.extend(_privacy_errors({"admission_signal": signal}))
    return errors


def admit_signal(signal: dict[str, Any]) -> dict[str, Any]:
    """Return a non-authoritative admission proposal for a normalized signal.

    Admission is intentionally separate from update_existing/link_only/create_new.
    It never mutates an Issue/PBI and never closes or resolves source work.
    """
    errors = validate_admission_signal(signal)
    if errors:
        raise MaterializationError(errors)

    if signal.get("target_layer", "delivery") == "harness":
        raise MaterializationError([
            "admission_signal.target_layer: harness admission is owned by #874/#869 Candidate/Evolution"
        ])

    claim_class = signal["claim_class"]
    disposition = signal["disposition"]
    candidate_problem = signal.get("candidate_problem")

    if claim_class == "inferred" or disposition == "ambiguous":
        decision = "discover_more"
        reason = "inferred_or_ambiguous_signal_requires_bounded_discovery"
    elif disposition in {"resolved", "informational"} and claim_class == "observed":
        decision = "no_action"
        reason = f"observed_{disposition}_signal_has_no_new_pbi_work"
    elif disposition in {"resolved", "informational"}:
        decision = "discover_more"
        reason = f"{claim_class}_{disposition}_signal_requires_confirmation"
    elif disposition == "actionable" and isinstance(candidate_problem, str) and candidate_problem.strip():
        decision = "materialize"
        reason = "actionable_signal_has_candidate_problem"
    else:
        decision = "discover_more"
        reason = "actionable_signal_missing_candidate_problem"

    result = {
        "decision": decision,
        "reason": reason,
        "signal_id": signal["signal_id"],
        "source_ref": signal["source_ref"],
        "proposal_only": True,
        "write_allowed": False,
        "close_allowed": False,
        "suppression_allowed": False,
        "next": {
            "materialize": "pbi_materializer",
            "no_action": "record_evaluation_only",
            "discover_more": "bounded_discovery",
        }[decision],
    }
    privacy = _privacy_errors({"admission_result": result})
    if privacy:
        raise MaterializationError(privacy)
    return result


def validate_payload(payload: Any, authority_root=None) -> list[str]:
    errors: list[str] = []
    if not isinstance(payload, dict):
        return ["payload: object required"]

    task_id = payload.get("task_id")
    if not isinstance(task_id, str) or not TASK_ID_RE.fullmatch(task_id):
        errors.append(f"task_id: TASK-XXXX required, got {task_id!r}")

    for field in ("title", "goal", "problem"):
        if not isinstance(payload.get(field), str) or not payload.get(field, "").strip():
            errors.append(f"{field}: non-empty string required")

    author = payload.get("author")
    if author not in VALID_AUTHORS:
        errors.append(f"author: one of {sorted(VALID_AUTHORS)} required")

    discovery_depth = payload.get("discovery_depth", "minimal")
    if discovery_depth not in VALID_DISCOVERY_DEPTHS:
        errors.append(
            f"discovery_depth: one of {sorted(VALID_DISCOVERY_DEPTHS)} required"
        )
    actor_job = payload.get("actor_job")
    if actor_job is not None and (
        not isinstance(actor_job, str) or not actor_job.strip()
    ):
        errors.append("actor_job: omitted or non-empty string required")

    timing = payload.get("application_timing")
    target = payload.get("target_layer")
    if timing not in VALID_TIMINGS:
        errors.append(f"application_timing: one of {sorted(VALID_TIMINGS)} required")
    if target not in VALID_TARGETS:
        errors.append(f"target_layer: one of {sorted(VALID_TARGETS)} required")
    if timing == "replan_current" and target == "harness":
        errors.append("application: replan_current + harness is invalid")

    _as_string_list(payload.get("source_run_refs"), "source_run_refs", errors)
    _as_string_list(payload.get("unknowns"), "unknowns", errors)
    _as_string_list(payload.get("assumptions"), "assumptions", errors)
    _as_string_list(payload.get("risks"), "risks", errors)
    _as_string_list(payload.get("acceptance_criteria"), "acceptance_criteria", errors)
    _as_string_list(payload.get("in_scope"), "in_scope", errors)
    _as_string_list(payload.get("out_of_scope"), "out_of_scope", errors)

    claims = payload.get("claims")
    if author in {"ai", "mixed"} and (not isinstance(claims, list) or not claims):
        errors.append("claims: AI/mixed authored PBI requires at least one material claim")
        claims = claims if isinstance(claims, list) else []
    elif claims is None:
        claims = []
    elif not isinstance(claims, list):
        errors.append("claims: array required")
        claims = []

    seen_claim_ids: set[str] = set()
    source_refs: set[str] = set()
    claim_classes_by_ref: dict[str, set[str]] = {}
    source_kinds_by_ref: dict[str, set[str]] = {}
    for i, claim in enumerate(claims):
        if not isinstance(claim, dict):
            errors.append(f"claims[{i}]: object required")
            continue
        cid = claim.get("id")
        if not isinstance(cid, str) or not cid.strip():
            errors.append(f"claims[{i}].id: non-empty string required")
        elif cid in seen_claim_ids:
            errors.append(f"claims[{i}].id: duplicate {cid}")
        else:
            seen_claim_ids.add(cid)

        for field in ("text", "source_ref", "supports"):
            if not isinstance(claim.get(field), str) or not claim.get(field, "").strip():
                errors.append(f"claims[{i}].{field}: non-empty string required")

        if claim.get("claim_class") not in VALID_CLAIM_CLASSES:
            errors.append(
                f"claims[{i}].claim_class: one of {sorted(VALID_CLAIM_CLASSES)} required"
            )
        if claim.get("source_kind") not in VALID_SOURCE_KINDS:
            errors.append(
                f"claims[{i}].source_kind: one of {sorted(VALID_SOURCE_KINDS)} required"
            )

        source_ref = claim.get("source_ref")
        if isinstance(source_ref, str) and source_ref.strip():
            source_ref = source_ref.strip()
            source_refs.add(source_ref)
            claim_classes_by_ref.setdefault(source_ref, set()).add(str(claim.get("claim_class")))
            source_kinds_by_ref.setdefault(source_ref, set()).add(str(claim.get("source_kind")))
            if isinstance(task_id, str) and _is_circular_source(task_id, source_ref):
                errors.append(
                    f"claims[{i}].source_ref: circular provenance from same-task downstream artifact"
                )
        origin_ref = _claim_origin_ref(claim)
        if isinstance(source_ref, str) and source_ref.strip():
            source_name = source_ref.replace("\\", "/").rsplit("/", 1)[-1]
            explicit_origin = claim.get("origin_ref")
            if source_name in DERIVED_FILENAMES and (
                not isinstance(explicit_origin, str)
                or not explicit_origin.strip()
                or explicit_origin.strip() == source_ref.strip()
            ):
                errors.append(
                    f"claims[{i}].origin_ref: derived artifact source requires a distinct original source ref"
                )
        if origin_ref:
            source_refs.add(origin_ref)
            claim_classes_by_ref.setdefault(origin_ref, set()).add(str(claim.get("claim_class")))
            source_kinds_by_ref.setdefault(origin_ref, set()).add(str(claim.get("source_kind")))
            if isinstance(task_id, str) and _is_circular_source(task_id, origin_ref):
                errors.append(
                    f"claims[{i}].origin_ref: circular provenance from same-task downstream artifact"
                )

    requirements = payload.get("requirements")
    if requirements is None:
        requirements = []
    elif not isinstance(requirements, list):
        errors.append("requirements: array required")
        requirements = []

    seen_req_ids: set[str] = set()
    for i, req in enumerate(requirements):
        if not isinstance(req, dict):
            errors.append(f"requirements[{i}]: object required")
            continue
        rid = req.get("id")
        if not isinstance(rid, str) or not rid.strip():
            errors.append(f"requirements[{i}].id: non-empty string required")
        elif rid in seen_req_ids:
            errors.append(f"requirements[{i}].id: duplicate {rid}")
        else:
            seen_req_ids.add(rid)

        if not isinstance(req.get("goal_problem"), str) or not req.get(
            "goal_problem", ""
        ).strip():
            errors.append(f"requirements[{i}].goal_problem: non-empty string required")
        if req.get("acceptance_basis") not in VALID_ACCEPTANCE_BASES:
            errors.append(
                f"requirements[{i}].acceptance_basis: one of {sorted(VALID_ACCEPTANCE_BASES)} required"
            )
        basis_ref = req.get("basis_ref")
        if not isinstance(basis_ref, str) or not basis_ref.strip():
            errors.append(f"requirements[{i}].basis_ref: non-empty string required")
        elif req.get("acceptance_basis") == "evidence":
            if basis_ref not in source_refs:
                errors.append(
                    f"requirements[{i}].basis_ref: evidence basis must reference claim source/origin"
                )
            else:
                classes = claim_classes_by_ref.get(basis_ref, set())
                if classes and classes <= {"inferred"}:
                    errors.append(
                        f"requirements[{i}].basis_ref: inferred-only source cannot be the evidence acceptance basis"
                    )
        elif req.get("acceptance_basis") == "explicit_decision":
            kinds = source_kinds_by_ref.get(basis_ref, set())
            if "decision_log" not in kinds:
                errors.append(
                    f"requirements[{i}].basis_ref: explicit_decision must reference decision_log provenance"
                )
            else:
                errors.extend(
                    f"requirements[{i}].basis_ref: {error}"
                    for error in _verify_acceptance_authority_ref(
                        basis_ref, "decision_log", authority_root
                    )
                )
        elif req.get("acceptance_basis") == "policy_rule":
            kinds = source_kinds_by_ref.get(basis_ref, set())
            if "policy" not in kinds:
                errors.append(
                    f"requirements[{i}].basis_ref: policy_rule must reference policy provenance"
                )
            else:
                errors.extend(
                    f"requirements[{i}].basis_ref: {error}"
                    for error in _verify_acceptance_authority_ref(
                        basis_ref, "policy", authority_root
                    )
                )
        related_ac = req.get("related_ac")
        if not isinstance(related_ac, str) or not related_ac.strip():
            errors.append(f"requirements[{i}].related_ac: non-empty string required")

    candidate_ref = payload.get("harness_candidate_ref")
    if target == "harness" and candidate_ref not in (None, "", "pending"):
        if not isinstance(candidate_ref, str):
            errors.append("harness_candidate_ref: string/pending required")

    errors.extend(_privacy_errors(payload))
    return errors


def _semantic_sets(payload: dict[str, Any]) -> tuple[set[str], set[str]]:
    reqs = {
        _norm(req.get("goal_problem"))
        for req in payload.get("requirements", [])
        if isinstance(req, dict) and _norm(req.get("goal_problem"))
    }
    acs = {_norm(x) for x in payload.get("acceptance_criteria", []) if _norm(x)}
    return reqs, acs


def _payload_source_refs(payload: dict[str, Any]) -> set[str]:
    refs = {
        str(x).strip()
        for x in payload.get("source_run_refs", [])
        if isinstance(x, str) and x.strip()
    }
    for claim in payload.get("claims", []):
        if not isinstance(claim, dict):
            continue
        for ref in (claim.get("source_ref"), _claim_origin_ref(claim)):
            if isinstance(ref, str) and ref.strip():
                refs.add(ref.strip())
    return refs


def _candidate_facts(candidate: dict[str, Any]) -> tuple[set[str], set[str], set[str]]:
    source_refs = {
        str(x).strip()
        for x in candidate.get("source_refs", [])
        if isinstance(x, str) and x.strip()
    }
    reqs = {_norm(x) for x in candidate.get("requirements", []) if _norm(x)}
    acs = {_norm(x) for x in candidate.get("acceptance_criteria", []) if _norm(x)}
    return source_refs, reqs, acs


def _validate_existing_work(existing_work: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(existing_work, list):
        return ["existing_work: array required"]
    for i, item in enumerate(existing_work):
        if not isinstance(item, dict):
            errors.append(f"existing_work[{i}]: object required")
            continue
        if not isinstance(item.get("ref"), str) or not item.get("ref", "").strip():
            errors.append(f"existing_work[{i}].ref: non-empty string required")
        for field in ("goal", "problem"):
            if not isinstance(item.get(field), str):
                errors.append(f"existing_work[{i}].{field}: string required")
        _as_string_list(item.get("source_refs"), f"existing_work[{i}].source_refs", errors)
        _as_string_list(item.get("requirements"), f"existing_work[{i}].requirements", errors)
        _as_string_list(
            item.get("acceptance_criteria"),
            f"existing_work[{i}].acceptance_criteria",
            errors,
        )
        if not isinstance(item.get("bound_to_approved_plan"), bool):
            errors.append(
                f"existing_work[{i}].bound_to_approved_plan: boolean required"
            )
    return errors


def decide_materialization(
    payload: dict[str, Any],
    existing_work: list[dict[str, Any]],
    authority_root=None,
) -> dict[str, Any]:
    """Deterministically choose update_existing/link_only/create_new.

    Matching is exact/canonical only. No fuzzy/LLM similarity is used.
    """
    errors = validate_payload(payload, authority_root=authority_root)
    if errors:
        raise MaterializationError(errors)
    existing_errors = _validate_existing_work(existing_work)
    if existing_errors:
        raise MaterializationError(existing_errors)

    p_sources = _payload_source_refs(payload)
    p_reqs, p_acs = _semantic_sets(payload)
    checked_refs = sorted(
        item["ref"]
        for item in existing_work
        if isinstance(item, dict) and isinstance(item.get("ref"), str)
    )
    p_goal = _norm(payload["goal"])
    p_problem = _norm(payload["problem"])

    ranked: list[tuple[tuple[int, int, int, int, int], str, dict[str, Any]]] = []
    for item in existing_work:
        if not isinstance(item, dict):
            continue
        ref = item.get("ref")
        if not isinstance(ref, str) or not ref.strip():
            continue
        c_sources, c_reqs, c_acs = _candidate_facts(item)
        source_overlap = len(p_sources & c_sources)
        goal_same = int(bool(p_goal) and p_goal == _norm(item.get("goal")))
        problem_same = int(bool(p_problem) and p_problem == _norm(item.get("problem")))
        req_overlap = len(p_reqs & c_reqs)
        ac_overlap = len(p_acs & c_acs)
        if not (source_overlap or (goal_same and problem_same)):
            continue
        score = (
            source_overlap,
            goal_same,
            problem_same,
            req_overlap,
            ac_overlap,
        )
        ranked.append((score, ref, item))

    if not ranked:
        return {
            "decision": "create_new",
            "matched_ref": None,
            "related_refs": [],
            "checked_refs": checked_refs,
            "requires_replan": False,
            "reason": "no deterministic existing-work match",
        }

    ranked.sort(key=lambda x: (x[0], x[1]), reverse=True)
    best_score = ranked[0][0]
    tied = sorted(ref for score, ref, _item in ranked if score == best_score)
    if len(tied) > 1:
        raise MaterializationError([
            "existing_work: ambiguous top match; normalize/resolve before materialization: "
            + ", ".join(tied)
        ])
    best = ranked[0][2]
    c_sources, c_reqs, c_acs = _candidate_facts(best)
    same_goal_problem = (
        p_goal == _norm(best.get("goal"))
        and p_problem == _norm(best.get("problem"))
    )
    same_semantics = same_goal_problem and p_reqs == c_reqs and p_acs == c_acs

    related_refs = sorted(
        {
            item.get("ref")
            for _score, _ref, item in ranked
            if isinstance(item.get("ref"), str)
        }
    )

    if same_semantics:
        return {
            "decision": "link_only",
            "matched_ref": best["ref"],
            "related_refs": related_refs,
            "checked_refs": checked_refs,
            "requires_replan": False,
            "reason": "same goal/problem/requirements/AC; link evidence only",
        }

    if same_goal_problem:
        bound = bool(best.get("bound_to_approved_plan"))
        return {
            "decision": "update_existing",
            "matched_ref": best["ref"],
            "related_refs": related_refs,
            "checked_refs": checked_refs,
            "requires_replan": bound,
            "reason": (
                "same goal/problem with semantic delta; bound PBI requires replan"
                if bound
                else "same goal/problem with semantic delta"
            ),
        }

    return {
        "decision": "create_new",
        "matched_ref": None,
        "related_refs": related_refs,
        "checked_refs": checked_refs,
        "requires_replan": False,
        "reason": "source overlap exists but goal/problem materially differs",
    }


def scan_working_pbis(
    working_root: pathlib.Path, payload: dict[str, Any]
) -> list[dict[str, Any]]:
    """Read-only exact scan of docs/working/TASK-*/pbi-input.md.

    Legacy/unstructured PBI files are represented only by facts that appear literally
    in the file. This intentionally prefers false negatives over fuzzy false matches.
    """
    root = pathlib.Path(working_root)
    if not root.is_dir():
        return []
    p_sources = _payload_source_refs(payload)
    p_reqs, p_acs = _semantic_sets(payload)
    goal = _norm(payload.get("goal"))
    problem = _norm(payload.get("problem"))
    out: list[dict[str, Any]] = []

    for path in sorted(root.glob("TASK-*/pbi-input.md")):
        if path.parent.name == payload.get("task_id"):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        norm_text = _norm(text)
        source_refs = sorted(ref for ref in p_sources if _norm(ref) in norm_text)
        found_reqs = sorted(req for req in p_reqs if req in norm_text)
        found_acs = sorted(ac for ac in p_acs if ac in norm_text)
        goal_value = payload["goal"] if goal and goal in norm_text else ""
        problem_value = payload["problem"] if problem and problem in norm_text else ""
        if not source_refs and not (goal_value and problem_value):
            continue
        approvals = path.parent / "approvals" / "c3.json"
        rel = path.relative_to(root).as_posix()
        out.append(
            {
                "ref": f"docs/working/{rel}",
                "source_refs": source_refs,
                "goal": goal_value,
                "problem": problem_value,
                "requirements": found_reqs,
                "acceptance_criteria": found_acs,
                "bound_to_approved_plan": approvals.is_file(),
            }
        )
    return out


def _validate_materialization_decision(decision: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(decision, dict):
        return ["decision: object required"]

    kind = decision.get("decision")
    if kind not in VALID_DECISIONS:
        errors.append(f"decision.decision: one of {sorted(VALID_DECISIONS)} required")

    matched_ref = decision.get("matched_ref")
    if matched_ref is not None and (
        not isinstance(matched_ref, str) or not matched_ref.strip()
    ):
        errors.append("decision.matched_ref: null or non-empty string required")

    _as_string_list(decision.get("related_refs"), "decision.related_refs", errors)
    _as_string_list(decision.get("checked_refs"), "decision.checked_refs", errors)

    if not isinstance(decision.get("requires_replan"), bool):
        errors.append("decision.requires_replan: boolean required")

    if not isinstance(decision.get("reason"), str) or not decision.get("reason", "").strip():
        errors.append("decision.reason: non-empty string required")

    return errors


def plan_readiness(payload: dict[str, Any], decision: dict[str, Any]) -> dict[str, Any]:
    decision_errors = _validate_materialization_decision(decision)
    if decision_errors:
        raise MaterializationError(decision_errors)

    timing = payload["application_timing"]
    target = payload["target_layer"]

    if decision["requires_replan"]:
        if timing == "replan_current" and target == "delivery":
            return {
                "status": "ready",
                "route": "replan_current",
                "current_run_effect": "replan_required",
            }
        return {
            "status": "blocked",
            "route": "bound_pbi_requires_replan",
            "current_run_effect": "none",
        }
    if target == "harness":
        ref = payload.get("harness_candidate_ref")
        if not isinstance(ref, str) or not ref.strip() or ref == "pending":
            return {
                "status": "blocked",
                "route": "harness_candidate_required",
                "current_run_effect": "none",
            }
        return {
            "status": "ready",
            "route": "harness_follow_up",
            "current_run_effect": "none",
        }
    if timing == "replan_current":
        return {
            "status": "ready",
            "route": "replan_current",
            "current_run_effect": "replan_required",
        }
    return {
        "status": "ready",
        "route": "future_run",
        "current_run_effect": "none",
    }


def _bullets(values: list[str]) -> str:
    return "\n".join(f"- {v}" for v in values) if values else "- （なし）"


def _md_cell(value: Any) -> str:
    """Keep provenance tables parseable without changing semantic content."""
    return str(value).replace("\\", "\\\\").replace("|", "\\|").replace("\r\n", "<br>").replace("\n", "<br>").replace("\r", "<br>")


def render_pbi_markdown(
    payload: dict[str, Any], decision: dict[str, Any], readiness: dict[str, Any]
) -> str:
    """Render a deterministic pbi-input.md proposal. Does not write files."""
    claims = payload.get("claims", [])
    requirements = payload.get("requirements", [])

    prov_rows = [
        "| Claim ID | Claim | Source Ref | Origin Ref | Source Kind | Claim Class | Supports |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for claim in claims:
        prov_rows.append(
            "| "
            + " | ".join(
                _md_cell(value)
                for value in (
                    claim["id"],
                    claim["text"],
                    claim["source_ref"],
                    _claim_origin_ref(claim),
                    claim["source_kind"],
                    claim["claim_class"],
                    claim["supports"],
                )
            )
            + " |"
        )

    req_rows = [
        "| Requirement ID | Goal / Problem | Evidence / Source | Acceptance Basis | Related AC |",
        "| --- | --- | --- | --- | --- |",
    ]
    for req in requirements:
        req_rows.append(
            "| "
            + " | ".join(
                _md_cell(value)
                for value in (
                    req["id"],
                    req["goal_problem"],
                    req["basis_ref"],
                    req["acceptance_basis"],
                    req["related_ac"],
                )
            )
            + " |"
        )

    source_runs = _as_string_list(payload.get("source_run_refs"), "source_run_refs", [])
    candidate_ref = payload.get("harness_candidate_ref") or "N/A"
    related = ", ".join(decision.get("related_refs") or []) or "（なし）"
    checked = ", ".join(decision.get("checked_refs") or []) or "（候補refなし）"
    problem_refs = sorted({
        _claim_origin_ref(claim)
        for claim in claims
        if isinstance(claim, dict)
        and _norm(claim.get("supports")) == "problem"
        and _claim_origin_ref(claim)
    })
    update_warning = (
        "> update_existing is a semantic patch proposal. Do not replace the bound PBI "
        "body without the existing Replan / policy path.\n\n"
        if decision["decision"] == "update_existing"
        else ""
    )

    return (
        f"# PBI INPUT PACKAGE: {payload['title']}\n\n"
        f"> Materializer mode: shadow / read-only. This output does not authorize execution.\n\n"
        + update_warning
        + f"## Context / Why\n\n{payload['problem']}\n\n"
        f"### Bounded Discovery\n\n"
        f"- Discovery depth: {payload.get('discovery_depth', 'minimal')}\n"
        f"- Actor / Job: {payload.get('actor_job') or '（minimal: not supplied）'}\n"
        f"- PBI author: {payload['author']}\n"
        f"- Application timing: {payload['application_timing']}\n"
        f"- Target layer: {payload['target_layer']}\n"
        f"- Source run / failure refs: {', '.join(source_runs) or '（なし）'}\n"
        f"- HarnessImprovementCandidate ref: {candidate_ref}\n"
        f"- Problem evidence refs: {', '.join(problem_refs) or '（なし）'}\n"
        f"- Plan readiness: {readiness['status']} ({readiness['route']})\n\n"
        f"#### Source / Feedback Provenance\n\n"
        + "\n".join(prov_rows)
        + "\n\n#### Existing Work Check\n\n"
        + f"- Checked candidate refs: {checked}\n"
        + f"- Materialization decision: {decision['decision']}\n"
        + f"- Matched existing ref: {decision.get('matched_ref') or '（なし）'}\n"
        + f"- Related PBI / Issue refs: {related}\n"
        + f"- Requires replan: {str(bool(decision.get('requires_replan'))).lower()}\n"
        + f"- Decision reason: {decision['reason']}\n"
        + "\n#### Requirement Discovery Trace\n\n"
        + "\n".join(req_rows)
        + "\n\n## What（Scope）\n\n### In scope\n\n"
        + _bullets(payload.get("in_scope", []))
        + "\n\n### Out of scope\n\n"
        + _bullets(payload.get("out_of_scope", []))
        + "\n\n## 受入基準\n\n"
        + _bullets(payload.get("acceptance_criteria", []))
        + "\n\n## Notes from Refinement\n\n"
        + f"- Goal: {payload['goal']}\n"
        + f"- Decision reason: {decision['reason']}\n\n"
        + "## Estimation Evidence\n\n### Risks\n\n"
        + _bullets(payload.get("risks", []))
        + "\n\n### Unknowns\n\n"
        + _bullets(payload.get("unknowns", []))
        + "\n\n### Assumptions\n\n"
        + _bullets(payload.get("assumptions", []))
        + "\n"
    )


def _validate_shadow_expected(expected: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(expected, dict):
        return ["shadow_expected: object required"]

    oracle_ref = expected.get("oracle_ref")
    if not isinstance(oracle_ref, str) or not oracle_ref.strip():
        errors.append("shadow_expected.oracle_ref: non-empty string required")

    if expected.get("decision") not in VALID_DECISIONS:
        errors.append(
            f"shadow_expected.decision: one of {sorted(VALID_DECISIONS)} required"
        )

    matched_ref = expected.get("matched_ref")
    if matched_ref is not None and (
        not isinstance(matched_ref, str) or not matched_ref.strip()
    ):
        errors.append(
            "shadow_expected.matched_ref: null or non-empty string required"
        )

    if expected.get("readiness_status") not in VALID_READINESS_STATUSES:
        errors.append(
            "shadow_expected.readiness_status: "
            f"one of {sorted(VALID_READINESS_STATUSES)} required"
        )

    if expected.get("readiness_route") not in VALID_READINESS_ROUTES:
        errors.append(
            "shadow_expected.readiness_route: "
            f"one of {sorted(VALID_READINESS_ROUTES)} required"
        )

    errors.extend(_privacy_errors({"shadow_expected": expected}))
    return errors


def compare_shadow(
    result: dict[str, Any], expected: dict[str, Any]
) -> dict[str, Any]:
    """Compare a shadow result with a reviewed expectation.

    This function is evaluation-only. A match never grants write/merge/promotion
    authority and does not mutate the PBI, Issue, RunState, or Harness.
    """
    errors = _validate_shadow_expected(expected)
    if errors:
        raise MaterializationError(errors)

    decision_errors = _validate_materialization_decision(result.get("decision"))
    if decision_errors:
        raise MaterializationError(
            [f"shadow_result.{e}" for e in decision_errors]
        )

    readiness = result.get("readiness")
    if not isinstance(readiness, dict):
        raise MaterializationError(["shadow_result.readiness: object required"])

    actual = {
        "decision": result["decision"]["decision"],
        "matched_ref": result["decision"]["matched_ref"],
        "readiness_status": readiness.get("status"),
        "readiness_route": readiness.get("route"),
    }
    expected_fields = {
        "decision": expected["decision"],
        "matched_ref": expected.get("matched_ref"),
        "readiness_status": expected["readiness_status"],
        "readiness_route": expected["readiness_route"],
    }

    checks = {
        field: actual[field] == expected_fields[field]
        for field in (
            "decision",
            "matched_ref",
            "readiness_status",
            "readiness_route",
        )
    }
    mismatches = [field for field, ok in checks.items() if not ok]
    comparison = {
        "status": "match" if not mismatches else "mismatch",
        "oracle_ref": expected["oracle_ref"],
        "checks": checks,
        "mismatches": mismatches,
        "actual": actual,
        "expected": expected_fields,
    }

    privacy = _privacy_errors({"shadow_comparison": comparison})
    if privacy:
        raise MaterializationError(privacy)
    return comparison


def _validate_live_shadow_capture(
    case: dict[str, Any],
    prefix: str,
    refs: list[str],
    authority_root=None,
) -> list[str]:
    errors: list[str] = []
    evidence_class = case.get("evidence_class", "synthetic_fixture")
    capture = case.get("live_capture")

    if evidence_class != "live_shadow":
        if capture is not None:
            errors.append(
                f"{prefix}.live_capture: only valid when evidence_class=live_shadow"
            )
        return errors

    if not isinstance(capture, dict):
        return [f"{prefix}.live_capture: object required for live_shadow"]

    if capture.get("capture_mode") != "passive_shadow":
        errors.append(
            f"{prefix}.live_capture.capture_mode: passive_shadow required"
        )

    captured_at = capture.get("captured_at")
    if not isinstance(captured_at, str) or not RFC3339_RE.fullmatch(captured_at):
        errors.append(
            f"{prefix}.live_capture.captured_at: timezone-aware RFC3339 required"
        )

    runtime_head_sha = capture.get("runtime_head_sha")
    if not isinstance(runtime_head_sha, str) or not COMMIT_SHA_RE.fullmatch(
        runtime_head_sha
    ):
        errors.append(
            f"{prefix}.live_capture.runtime_head_sha: 40 lowercase hex required"
        )

    capture_ref = capture.get("capture_ref")
    if not isinstance(capture_ref, str) or not capture_ref.strip():
        errors.append(
            f"{prefix}.live_capture.capture_ref: non-empty repository ref required"
        )
    else:
        capture_ref = capture_ref.strip()
        if capture_ref not in refs:
            errors.append(
                f"{prefix}.live_capture.capture_ref: must also appear in evidence_refs"
            )
        _path, _fragment, ref_errors = _resolve_repo_authority_ref(
            capture_ref, authority_root
        )
        errors.extend(
            f"{prefix}.live_capture.capture_ref: {error}"
            for error in ref_errors
        )

    errors.extend(
        f"{prefix}.live_capture.{error}"
        for error in _privacy_errors({"live_capture": capture})
    )
    return errors


def _validate_shadow_batch(cases: Any, authority_root=None) -> list[str]:
    errors: list[str] = []
    if not isinstance(cases, list) or not cases:
        return ["shadow_batch: non-empty array required"]

    seen_refs: set[str] = set()
    has_test = False
    for i, case in enumerate(cases):
        if not isinstance(case, dict):
            errors.append(f"shadow_batch[{i}]: object required")
            continue

        case_ref = case.get("case_ref")
        if not isinstance(case_ref, str) or not case_ref.strip():
            errors.append(f"shadow_batch[{i}].case_ref: non-empty string required")
        elif case_ref in seen_refs:
            errors.append(f"shadow_batch[{i}].case_ref: duplicate {case_ref}")
        else:
            seen_refs.add(case_ref)

        split = case.get("split")
        if split not in VALID_EVAL_SPLITS:
            errors.append(
                f"shadow_batch[{i}].split: one of {sorted(VALID_EVAL_SPLITS)} required"
            )
        elif split == "test":
            has_test = True

        evidence_class = case.get("evidence_class", "synthetic_fixture")
        if evidence_class not in VALID_EVIDENCE_CLASSES:
            errors.append(
                f"shadow_batch[{i}].evidence_class: one of {sorted(VALID_EVIDENCE_CLASSES)} required"
            )

        evidence_refs = case.get("evidence_refs", [])
        refs = _as_string_list(
            evidence_refs,
            f"shadow_batch[{i}].evidence_refs",
            errors,
        )
        if evidence_class in {"historical_replay", "live_shadow"}:
            if not refs:
                errors.append(
                    f"shadow_batch[{i}].evidence_refs: {evidence_class} requires repository-visible evidence refs"
                )
            for ref in refs:
                _path, _fragment, ref_errors = _resolve_repo_authority_ref(
                    ref, authority_root
                )
                errors.extend(
                    f"shadow_batch[{i}].evidence_refs: {error}"
                    for error in ref_errors
                )

        errors.extend(
            _validate_live_shadow_capture(
                case,
                f"shadow_batch[{i}]",
                refs,
                authority_root=authority_root,
            )
        )

        payload = case.get("payload")
        if not isinstance(payload, dict):
            errors.append(f"shadow_batch[{i}].payload: object required")
        else:
            errors.extend(
                f"shadow_batch[{i}].payload.{error}"
                for error in _privacy_errors(payload)
            )
            if (
                evidence_class == "historical_replay"
                and payload.get("target_layer") == "harness"
            ):
                errors.append(
                    f"shadow_batch[{i}]: harness historical replay must use #874/#869 Candidate/Evolution path"
                )

        existing_work = case.get("existing_work")
        if not isinstance(existing_work, list):
            errors.append(f"shadow_batch[{i}].existing_work: array required")

        expected = case.get("expected")
        errors.extend(
            f"shadow_batch[{i}].{error}"
            for error in _validate_shadow_expected(expected)
        )

        if (
            evidence_class in {"historical_replay", "live_shadow"}
            and isinstance(expected, dict)
            and isinstance(expected.get("oracle_ref"), str)
            and expected.get("oracle_ref", "").strip()
        ):
            oracle_ref = expected["oracle_ref"].strip()
            _oracle_path, _oracle_fragment, oracle_errors = _resolve_repo_authority_ref(
                oracle_ref, authority_root
            )
            errors.extend(
                f"shadow_batch[{i}].oracle_ref: {error}"
                for error in oracle_errors
            )
            oracle_path_text = oracle_ref.partition("#")[0]
            evidence_path_texts = {
                ref.partition("#")[0] for ref in refs
            }
            if oracle_path_text in evidence_path_texts:
                errors.append(
                    f"shadow_batch[{i}].oracle_ref: oracle artifact must be distinct from source evidence"
                )

        # Do not privacy-scan the whole nested payload again: root PBI author is
        # categorical (human|ai|mixed) and is adapted only by _privacy_errors(payload).
        # All non-payload batch metadata remains covered here.
        errors.extend(
            f"shadow_batch[{i}].{error}"
            for error in _privacy_errors(
                {
                    "case_ref": case_ref,
                    "split": split,
                    "evidence_class": evidence_class,
                    "evidence_refs": refs,
                    "existing_work": existing_work,
                }
            )
        )

    if not has_test:
        errors.append(
            "shadow_batch: at least one test split case is required; train-only evidence cannot support rollout evaluation"
        )

    return errors


def _metric_bucket() -> dict[str, int]:
    return {
        "total": 0,
        "exact_matches": 0,
        "decision_matches": 0,
        "readiness_matches": 0,
        "errors": 0,
    }


def _finalize_metrics(bucket: dict[str, int]) -> dict[str, Any]:
    total = bucket["total"]

    def _rate(value: int) -> float:
        return 0.0 if total == 0 else round(value / total, 6)

    return {
        **bucket,
        "exact_match_rate": _rate(bucket["exact_matches"]),
        "decision_accuracy": _rate(bucket["decision_matches"]),
        "readiness_accuracy": _rate(bucket["readiness_matches"]),
    }


def evaluate_shadow_batch(
    cases: list[dict[str, Any]], authority_root=None
) -> dict[str, Any]:
    """Evaluate reviewed train/test cases without granting write authority."""
    errors = _validate_shadow_batch(cases, authority_root=authority_root)
    if errors:
        raise MaterializationError(errors)

    metrics = {
        "overall": _metric_bucket(),
        "train": _metric_bucket(),
        "test": _metric_bucket(),
    }
    evidence_metrics = {
        evidence_class: _metric_bucket()
        for evidence_class in sorted(VALID_EVIDENCE_CLASSES)
    }
    case_results: list[dict[str, Any]] = []
    observed_decisions: set[str] = set()
    observed_readiness_routes: set[str] = set()

    for case in cases:
        split = case["split"]
        evidence_class = case.get("evidence_class", "synthetic_fixture")
        for key in ("overall", split):
            metrics[key]["total"] += 1
        evidence_metrics[evidence_class]["total"] += 1

        try:
            result = materialize(
                case["payload"],
                case["existing_work"],
                authority_root=authority_root,
            )
            comparison = compare_shadow(result, case["expected"])
            exact = comparison["status"] == "match"
            decision_ok = (
                comparison["checks"]["decision"]
                and comparison["checks"]["matched_ref"]
            )
            readiness_ok = (
                comparison["checks"]["readiness_status"]
                and comparison["checks"]["readiness_route"]
            )
            observed_decisions.add(result["decision"]["decision"])
            observed_readiness_routes.add(result["readiness"]["route"])

            for key in ("overall", split):
                metrics[key]["exact_matches"] += int(exact)
                metrics[key]["decision_matches"] += int(decision_ok)
                metrics[key]["readiness_matches"] += int(readiness_ok)
            evidence_metrics[evidence_class]["exact_matches"] += int(exact)
            evidence_metrics[evidence_class]["decision_matches"] += int(decision_ok)
            evidence_metrics[evidence_class]["readiness_matches"] += int(readiness_ok)

            case_results.append(
                {
                    "case_ref": case["case_ref"],
                    "split": split,
                    "evidence_class": evidence_class,
                    "evidence_refs": list(case.get("evidence_refs", [])),
                    "status": comparison["status"],
                    "mismatches": comparison["mismatches"],
                }
            )
        except MaterializationError as exc:
            for key in ("overall", split):
                metrics[key]["errors"] += 1
            evidence_metrics[evidence_class]["errors"] += 1
            case_results.append(
                {
                    "case_ref": case["case_ref"],
                    "split": split,
                    "evidence_class": evidence_class,
                    "evidence_refs": list(case.get("evidence_refs", [])),
                    "status": "error",
                    "mismatches": ["materialization_error"],
                    "errors": list(exc.errors),
                }
            )

    report = {
        "mode": "shadow_evaluation",
        "write_allowed": False,
        "automatic_promotion": False,
        "evaluation_contract": {
            "split_required": True,
            "scope": "post_admission_materialization",
            "materialization_admission_evaluated": False,
            "no_action_coverage": False,
            "historical_live_oracle_repository_visibility_enforced": True,
            "source_oracle_artifact_separation_enforced": True,
            "live_shadow_capture_metadata_enforced": True,
            "live_shadow_label_alone_sufficient": False,
            "runtime_head_binding_verified": False,
            "runtime_head_binding_owner": "caller_or_runtime_capture",
            "oracle_independence_enforced": False,
            "oracle_independence_owner": "caller_or_independent_reviewer",
            "holdout_isolation_enforced": False,
            "generalization_claim_allowed": False,
            "holdout_isolation_owner": "caller_or_independent_evaluator",
        },
        "metrics": {
            key: _finalize_metrics(value) for key, value in metrics.items()
        },
        "evidence_metrics": {
            key: _finalize_metrics(value)
            for key, value in evidence_metrics.items()
        },
        "rollout_evidence": {
            "synthetic_fixture_cases": evidence_metrics["synthetic_fixture"]["total"],
            "historical_replay_cases": evidence_metrics["historical_replay"]["total"],
            "live_shadow_cases": evidence_metrics["live_shadow"]["total"],
            "synthetic_excluded_from_rollout_claim": True,
            "observed_decisions": sorted(observed_decisions),
            "observed_readiness_routes": sorted(observed_readiness_routes),
            "write_review_eligible": False,
            "write_review_blockers": [
                "admission_no_action_not_evaluated",
                "live_shadow_not_yet_required_or_observed",
                "independent_oracle_isolation_not_enforced",
            ],
        },
        "cases": case_results,
    }
    privacy = _privacy_errors({"shadow_evaluation": report})
    if privacy:
        raise MaterializationError(privacy)
    return report


def _validate_admission_expected(expected: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(expected, dict):
        return ["admission_expected: object required"]

    oracle_ref = expected.get("oracle_ref")
    if not isinstance(oracle_ref, str) or not oracle_ref.strip():
        errors.append("admission_expected.oracle_ref: non-empty string required")

    if expected.get("admission_decision") not in VALID_ADMISSION_DECISIONS:
        errors.append(
            "admission_expected.admission_decision: "
            f"one of {sorted(VALID_ADMISSION_DECISIONS)} required"
        )

    errors.extend(_privacy_errors({"admission_expected": expected}))
    return errors


def _validate_admission_batch(cases: Any, authority_root=None) -> list[str]:
    errors: list[str] = []
    if not isinstance(cases, list) or not cases:
        return ["admission_batch: non-empty array required"]

    seen_refs: set[str] = set()
    has_test = False
    for i, case in enumerate(cases):
        if not isinstance(case, dict):
            errors.append(f"admission_batch[{i}]: object required")
            continue

        case_ref = case.get("case_ref")
        if not isinstance(case_ref, str) or not case_ref.strip():
            errors.append(f"admission_batch[{i}].case_ref: non-empty string required")
        elif case_ref in seen_refs:
            errors.append(f"admission_batch[{i}].case_ref: duplicate {case_ref}")
        else:
            seen_refs.add(case_ref)

        split = case.get("split")
        if split not in VALID_EVAL_SPLITS:
            errors.append(
                f"admission_batch[{i}].split: one of {sorted(VALID_EVAL_SPLITS)} required"
            )
        elif split == "test":
            has_test = True

        evidence_class = case.get("evidence_class", "synthetic_fixture")
        if evidence_class not in VALID_EVIDENCE_CLASSES:
            errors.append(
                f"admission_batch[{i}].evidence_class: one of {sorted(VALID_EVIDENCE_CLASSES)} required"
            )

        refs = _as_string_list(
            case.get("evidence_refs", []),
            f"admission_batch[{i}].evidence_refs",
            errors,
        )
        if evidence_class in {"historical_replay", "live_shadow"}:
            if not refs:
                errors.append(
                    f"admission_batch[{i}].evidence_refs: {evidence_class} requires repository-visible evidence refs"
                )
            for ref in refs:
                _path, _fragment, ref_errors = _resolve_repo_authority_ref(
                    ref, authority_root
                )
                errors.extend(
                    f"admission_batch[{i}].evidence_refs: {error}"
                    for error in ref_errors
                )

        errors.extend(
            _validate_live_shadow_capture(
                case,
                f"admission_batch[{i}]",
                refs,
                authority_root=authority_root,
            )
        )

        signal = case.get("signal")
        errors.extend(
            f"admission_batch[{i}].{error}"
            for error in validate_admission_signal(signal)
        )

        expected = case.get("expected")
        errors.extend(
            f"admission_batch[{i}].{error}"
            for error in _validate_admission_expected(expected)
        )

        if (
            evidence_class in {"historical_replay", "live_shadow"}
            and isinstance(expected, dict)
            and isinstance(expected.get("oracle_ref"), str)
            and expected.get("oracle_ref", "").strip()
        ):
            oracle_ref = expected["oracle_ref"].strip()
            _oracle_path, _oracle_fragment, oracle_errors = _resolve_repo_authority_ref(
                oracle_ref, authority_root
            )
            errors.extend(
                f"admission_batch[{i}].oracle_ref: {error}"
                for error in oracle_errors
            )
            oracle_path_text = oracle_ref.partition("#")[0]
            evidence_path_texts = {
                ref.partition("#")[0] for ref in refs
            }
            if oracle_path_text in evidence_path_texts:
                errors.append(
                    f"admission_batch[{i}].oracle_ref: oracle artifact must be distinct from source evidence"
                )

        errors.extend(
            f"admission_batch[{i}].{error}"
            for error in _privacy_errors(
                {
                    "case_ref": case_ref,
                    "split": split,
                    "evidence_class": evidence_class,
                    "evidence_refs": refs,
                }
            )
        )

    if not has_test:
        errors.append(
            "admission_batch: at least one test split case is required"
        )
    return errors


def _admission_metric_bucket() -> dict[str, int]:
    return {"total": 0, "matches": 0, "errors": 0}


def _finalize_admission_metrics(bucket: dict[str, int]) -> dict[str, Any]:
    total = bucket["total"]
    return {
        **bucket,
        "accuracy": 0.0 if total == 0 else round(bucket["matches"] / total, 6),
    }


def evaluate_admission_batch(
    cases: list[dict[str, Any]], authority_root=None
) -> dict[str, Any]:
    """Evaluate PBI admission without granting close/write authority."""
    errors = _validate_admission_batch(cases, authority_root=authority_root)
    if errors:
        raise MaterializationError(errors)

    metrics = {
        "overall": _admission_metric_bucket(),
        "train": _admission_metric_bucket(),
        "test": _admission_metric_bucket(),
    }
    evidence_metrics = {
        evidence_class: _admission_metric_bucket()
        for evidence_class in sorted(VALID_EVIDENCE_CLASSES)
    }
    case_results: list[dict[str, Any]] = []
    observed_decisions: set[str] = set()

    for case in cases:
        split = case["split"]
        evidence_class = case.get("evidence_class", "synthetic_fixture")
        for key in ("overall", split):
            metrics[key]["total"] += 1
        evidence_metrics[evidence_class]["total"] += 1

        try:
            result = admit_signal(case["signal"])
            expected_decision = case["expected"]["admission_decision"]
            matched = result["decision"] == expected_decision
            observed_decisions.add(result["decision"])

            for key in ("overall", split):
                metrics[key]["matches"] += int(matched)
            evidence_metrics[evidence_class]["matches"] += int(matched)

            case_results.append(
                {
                    "case_ref": case["case_ref"],
                    "split": split,
                    "evidence_class": evidence_class,
                    "evidence_refs": list(case.get("evidence_refs", [])),
                    "status": "match" if matched else "mismatch",
                    "actual": result["decision"],
                    "expected": expected_decision,
                    "oracle_ref": case["expected"]["oracle_ref"],
                }
            )
        except MaterializationError as exc:
            for key in ("overall", split):
                metrics[key]["errors"] += 1
            evidence_metrics[evidence_class]["errors"] += 1
            case_results.append(
                {
                    "case_ref": case["case_ref"],
                    "split": split,
                    "evidence_class": evidence_class,
                    "evidence_refs": list(case.get("evidence_refs", [])),
                    "status": "error",
                    "errors": list(exc.errors),
                }
            )

    live_count = evidence_metrics["live_shadow"]["total"]
    decision_coverage_complete = observed_decisions == VALID_ADMISSION_DECISIONS
    blockers = []
    if live_count == 0:
        blockers.append("live_shadow_not_yet_observed")
    if not decision_coverage_complete:
        blockers.append("admission_decision_coverage_incomplete")
    blockers.append("independent_oracle_isolation_not_enforced")

    report = {
        "mode": "admission_evaluation",
        "write_allowed": False,
        "close_allowed": False,
        "suppression_allowed": False,
        "automatic_promotion": False,
        "evaluation_contract": {
            "scope": "pbi_admission",
            "historical_live_oracle_repository_visibility_enforced": True,
            "source_oracle_artifact_separation_enforced": True,
            "live_shadow_capture_metadata_enforced": True,
            "live_shadow_label_alone_sufficient": False,
            "runtime_head_binding_verified": False,
            "runtime_head_binding_owner": "caller_or_runtime_capture",
            "oracle_independence_enforced": False,
            "oracle_independence_owner": "caller_or_independent_reviewer",
            "holdout_isolation_enforced": False,
            "generalization_claim_allowed": False,
        },
        "metrics": {
            key: _finalize_admission_metrics(value)
            for key, value in metrics.items()
        },
        "evidence_metrics": {
            key: _finalize_admission_metrics(value)
            for key, value in evidence_metrics.items()
        },
        "coverage": {
            "observed_admission_decisions": sorted(observed_decisions),
            "materialize_coverage": "materialize" in observed_decisions,
            "no_action_coverage": "no_action" in observed_decisions,
            "discover_more_coverage": "discover_more" in observed_decisions,
            "decision_coverage_complete": decision_coverage_complete,
        },
        "rollout_evidence": {
            "synthetic_fixture_cases": evidence_metrics["synthetic_fixture"]["total"],
            "historical_replay_cases": evidence_metrics["historical_replay"]["total"],
            "live_shadow_cases": live_count,
            "synthetic_excluded_from_rollout_claim": True,
            "write_review_eligible": False,
            "write_review_blockers": blockers,
        },
        "cases": case_results,
    }
    privacy = _privacy_errors({"admission_evaluation": report})
    if privacy:
        raise MaterializationError(privacy)
    return report


def materialize(
    payload: dict[str, Any],
    existing_work: list[dict[str, Any]],
    authority_root=None,
) -> dict[str, Any]:
    decision = decide_materialization(
        payload, existing_work, authority_root=authority_root
    )
    readiness = plan_readiness(payload, decision)
    markdown = render_pbi_markdown(payload, decision, readiness)
    proposal_kind = {
        "create_new": "full_draft",
        "update_existing": "semantic_patch_proposal",
        "link_only": "link_evidence_only",
    }[decision["decision"]]
    result = {
        "mode": "shadow",
        "task_id": payload["task_id"],
        "proposal_kind": proposal_kind,
        "apply_contract": {
            "write_allowed": False,
            "replacement_allowed": False,
        },
        "decision": decision,
        "readiness": readiness,
        "pbi_markdown": markdown,
    }
    privacy = _privacy_errors(result)
    if privacy:
        raise MaterializationError(privacy)
    return result


def _load_json(path: pathlib.Path, expected: type, label: str):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise MaterializationError([f"{label}: unreadable: {exc}"]) from exc
    except json.JSONDecodeError as exc:
        raise MaterializationError([f"{label}: invalid JSON: {exc}"]) from exc
    if not isinstance(data, expected):
        raise MaterializationError([f"{label}: expected {expected.__name__}"])
    return data


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", help="normalized PBI payload JSON")
    parser.add_argument(
        "--eval-batch",
        help="reviewed train/test materialization shadow cases JSON array; evaluation-only",
    )
    parser.add_argument(
        "--eval-admission-batch",
        help="reviewed PBI admission cases JSON array; evaluation-only and never closes/writes",
    )
    parser.add_argument("--existing", help="normalized existing-work JSON array")
    parser.add_argument(
        "--authority-root",
        help="repository root for read-only decision_log/policy authority verification",
    )
    parser.add_argument(
        "--expected",
        help="optional reviewed shadow expectation JSON; comparison only, never enables writes",
    )
    parser.add_argument(
        "--working-root",
        help="optional local docs/working root for deterministic PBI scan",
    )
    parser.add_argument("--format", choices=("json", "md"), default="json")
    parser.add_argument("--mode", choices=("shadow",), default="shadow")
    args = parser.parse_args(argv)

    try:
        selected_modes = sum(
            bool(value)
            for value in (args.input, args.eval_batch, args.eval_admission_batch)
        )
        if selected_modes != 1:
            raise MaterializationError([
                "exactly one of --input / --eval-batch / --eval-admission-batch is required"
            ])

        authority_root = pathlib.Path(args.authority_root) if args.authority_root else None

        if args.eval_admission_batch:
            if args.format != "json":
                raise MaterializationError([
                    "--eval-admission-batch requires --format json"
                ])
            if args.existing or args.expected or args.working_root:
                raise MaterializationError([
                    "--eval-admission-batch cannot be combined with --existing/--expected/--working-root"
                ])
            cases = _load_json(
                pathlib.Path(args.eval_admission_batch),
                list,
                "--eval-admission-batch",
            )
            result = evaluate_admission_batch(cases, authority_root=authority_root)
        elif args.eval_batch:
            if args.format != "json":
                raise MaterializationError(["--eval-batch requires --format json"])
            if args.existing or args.expected or args.working_root:
                raise MaterializationError([
                    "--eval-batch cannot be combined with --existing/--expected/--working-root"
                ])
            cases = _load_json(pathlib.Path(args.eval_batch), list, "--eval-batch")
            result = evaluate_shadow_batch(cases, authority_root=authority_root)
        else:
            payload = _load_json(pathlib.Path(args.input), dict, "--input")
            errors = validate_payload(payload, authority_root=authority_root)
            if errors:
                raise MaterializationError(errors)
            existing: list[dict[str, Any]] = []
            if args.existing:
                existing.extend(_load_json(pathlib.Path(args.existing), list, "--existing"))
            if args.working_root:
                existing.extend(scan_working_pbis(pathlib.Path(args.working_root), payload))
            result = materialize(payload, existing, authority_root=authority_root)
            if args.expected:
                if args.format != "json":
                    raise MaterializationError([
                        "--expected requires --format json so comparison evidence is not hidden"
                    ])
                expected = _load_json(pathlib.Path(args.expected), dict, "--expected")
                result["shadow_comparison"] = compare_shadow(result, expected)
    except MaterializationError as exc:
        for error in exc.errors:
            print(f"[pbi-materializer] FAIL: {error}", file=sys.stderr)
        return 3

    if args.format == "md":
        sys.stdout.write(result["pbi_markdown"])
    else:
        sys.stdout.write(
            json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
