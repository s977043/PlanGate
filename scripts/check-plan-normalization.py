#!/usr/bin/env python3
"""Validate that a normalized Plan preserves its executable contract.

This checker is intentionally deterministic and dependency-free. Semantic rewriting is
performed by an agent (plan-normalization skill); this script verifies invariants that
must survive the rewrite:

- core Plan sections still exist
- stable requirement / acceptance-criteria identifiers are not dropped
- conversation-history dependent wording is not left in the canonical Plan

Exit codes:
  0: pass
  1: contract violation
  2: invalid invocation / unreadable input
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_HEADINGS = (
    "Goal",
    "Scope",
    "Global Constraints",
    "Work Breakdown",
    "Verification Plan",
)

# Stable identifiers are the safest mechanically checkable proxy for semantic
# preservation. Keep the pattern conservative to avoid matching prose accidentally.
CONTRACT_ID_RE = re.compile(r"\b(?:AC|REQ|FR|NFR)-[A-Za-z0-9][A-Za-z0-9._-]*\b")
HEADING_RE = re.compile(r"^#{2,6}\s+(.+?)\s*$", re.MULTILINE)

HISTORY_PATTERNS = (
    ("当初", re.compile(r"当初(?:は|の|案)")),
    ("先ほどのレビュー", re.compile(r"先ほどのレビュー")),
    ("前述の指摘", re.compile(r"前述の指摘")),
    ("以前の案", re.compile(r"以前の案|旧案")),
    ("レビューで変更", re.compile(r"レビュー(?:で|により).{0,24}(?:変更|修正)")),
    ("originally", re.compile(r"\boriginally\b", re.IGNORECASE)),
    ("previous review", re.compile(r"\bprevious review\b", re.IGNORECASE)),
    ("as discussed above", re.compile(r"\bas discussed above\b", re.IGNORECASE)),
)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        print(f"error: cannot read {path}: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc


def headings(text: str) -> set[str]:
    return {match.group(1).strip() for match in HEADING_RE.finditer(text)}


def contract_ids(text: str) -> set[str]:
    return set(CONTRACT_ID_RE.findall(text))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate before/after Plan normalization invariants."
    )
    parser.add_argument("--before", required=True, type=Path, help="pre-normalization plan.md snapshot")
    parser.add_argument("--after", required=True, type=Path, help="normalized plan.md")
    args = parser.parse_args()

    before = read_text(args.before)
    after = read_text(args.after)
    errors: list[str] = []

    after_headings = headings(after)
    for required in REQUIRED_HEADINGS:
        if required not in after_headings:
            errors.append(f"missing required heading after normalization: {required}")

    before_ids = contract_ids(before)
    after_ids = contract_ids(after)
    missing_ids = sorted(before_ids - after_ids)
    if missing_ids:
        errors.append(
            "stable contract identifiers disappeared: " + ", ".join(missing_ids)
        )

    history_hits: list[str] = []
    for label, pattern in HISTORY_PATTERNS:
        if pattern.search(after):
            history_hits.append(label)
    if history_hits:
        errors.append(
            "history-dependent wording remains in canonical plan: "
            + ", ".join(history_hits)
        )

    if errors:
        print("[FAIL] plan normalization contract")
        for error in errors:
            print(f"  - {error}")
        print(
            "  Review decision-log.jsonl for preserved rationale, restore any missing "
            "contract IDs, then normalize again."
        )
        return 1

    print("[PASS] plan normalization contract")
    print(f"  required headings: {len(REQUIRED_HEADINGS)} present")
    print(f"  stable contract IDs preserved: {len(before_ids)}")
    print("  history-dependent wording: none detected")
    if not before_ids:
        print(
            "  [WARN] no AC/REQ/FR/NFR identifiers detected; semantic preservation "
            "still requires the skill's manual checklist"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
