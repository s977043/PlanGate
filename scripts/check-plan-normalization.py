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

__doc__ = """
Validate that a normalized Plan preserves its executable contract.

This checker is intentionally deterministic and dependency-free. Semantic rewriting is
performed by an agent (plan-normalization skill); this script verifies invariants that
must survive the rewrite:

- the normalization actually happened (before != after)
- core Plan sections still exist
- stable requirement / acceptance-criteria identifiers are not dropped
- conversation-history dependent wording and superseded-state structure are not left
  in the canonical Plan

Applicability: this gate validates plans that are put through the plan-normalization
skill. It is NOT a repository-wide lint over historical docs/working/TASK-*/plan.md.
See docs/ai/plan-normalization-gate.md section 3 for the applicability contract.

Exit codes:
  0: pass
  1: contract violation
  2: invalid invocation / unreadable input
"""

import argparse
import re
import subprocess
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
# R- is included because this gate sits immediately after the C-2 R-NNN reflection
# step, where R-NNN traceability must survive the rewrite (review-principles 7-bis).
CONTRACT_ID_RE = re.compile(r"\b(?:AC|REQ|FR|NFR|R)-[A-Za-z0-9][A-Za-z0-9._-]*\b")
HEADING_RE = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.MULTILINE)

# Heading normalization: the required-heading check must not reject a Plan purely
# for cosmetic heading style. Accepted variants (docs section 4 example included):
#   "## 1. Goal" / "# Goal" / "## Scope (In/Out)" / "## Scope（In / Out）"
_NUM_PREFIX_RE = re.compile(r"^\s*(?:\d+(?:\.\d+)*)[.)]?\s+")
_SUBTITLE_RE = re.compile(r"\s*(?:[（(\[]|[:：]\s).*$")
_TRAILING_PUNCT_RE = re.compile(r"[\s:：\-–—]+$")

# History-dependent wording. This is a DENYLIST of representative phrasings and is
# deliberately documented as low-recall: paraphrases WILL slip through. See
# the "機械検証の限界" section of docs/ai/plan-normalization-gate.md. The skill's
# manual self-containment check (step 5) is the actual gate for meaning.
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

# Structural markers: instead of chasing paraphrases with an ever-growing denylist,
# detect the shapes that only appear when superseded state is still rendered in
# the Plan body. Kept deliberately small so it does not silently become a second
# denylist with false positives (M-1: over-strict matching rejects valid Plans).
_ST = chr(126)  # strikethrough delimiter character
STRUCTURAL_PATTERNS = (
    # strikethrough: the canonical way to render "this was the old decision"
    (
        "strikethrough",
        re.compile(_ST + _ST + "[^" + _ST + r"\n]+" + _ST + _ST),
    ),
    # a heading whose own title announces history / rejected alternatives
    (
        "history-heading",
        re.compile(
            r"^#{1,6}\s+.*(?:変更履歴|改訂履歴|検討経緯|代替案|却下案|"
            r"Change\s*Log|Revision\s*History|Alternatives\s*Considered)"
            r".*$",
            re.MULTILINE | re.IGNORECASE,
        ),
    ),
)


def fail_invocation(message):
    print("error: " + message, file=sys.stderr)
    raise SystemExit(2)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        fail_invocation("cannot read {}: {}".format(path, exc))
    return ""  # unreachable


def _git(argv):
    try:
        return subprocess.run(argv, capture_output=True, check=False)
    except OSError as exc:
        fail_invocation("cannot invoke git: {}".format(exc))
        raise SystemExit(2) from exc


def read_git_ref(ref: str, path: str) -> str:
    """Read a path at a git ref.

    The point of --before-ref is that the pre-normalization baseline is then a
    committed object, not a file the normalizing agent writes for itself.
    """
    proc = _git(["git", "show", "{}:{}".format(ref, path)])
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", "replace").strip()
        fail_invocation("git show {}:{} failed: {}".format(ref, path, stderr))
    try:
        return proc.stdout.decode("utf-8")
    except UnicodeError as exc:
        fail_invocation("git show {}:{} is not UTF-8: {}".format(ref, path, exc))
    return ""  # unreachable


def canonical_heading(raw: str) -> str:
    text = _NUM_PREFIX_RE.sub("", raw.strip())
    text = _SUBTITLE_RE.sub("", text)
    text = _TRAILING_PUNCT_RE.sub("", text)
    return text.strip()


def headings(text: str) -> set:
    out = set()
    for match in HEADING_RE.finditer(text):
        raw = match.group(1).strip()
        out.add(raw)
        out.add(canonical_heading(raw))
    return out


def contract_ids(text: str) -> set:
    return set(CONTRACT_ID_RE.findall(text))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate before/after Plan normalization invariants."
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument(
        "--before",
        type=Path,
        help=(
            "pre-normalization plan.md snapshot written by the agent. Emits a "
            "WARN: the baseline is not independently verifiable. Prefer "
            "--before-ref."
        ),
    )
    source.add_argument(
        "--before-ref",
        help=(
            "git ref holding the pre-normalization plan (e.g. HEAD, origin/main), "
            "read with git show so the baseline cannot be authored by the "
            "normalizing agent."
        ),
    )
    parser.add_argument("--after", required=True, type=Path, help="normalized plan.md")
    parser.add_argument(
        "--before-path",
        help=(
            "path inside --before-ref (defaults to --after resolved relative to "
            "the repository root)"
        ),
    )
    return parser


def resolve_before(args):
    """Return (text, provenance label, independently-verified?)."""
    if args.before_ref:
        path = args.before_path
        if not path:
            top = _git(["git", "rev-parse", "--show-toplevel"])
            if top.returncode != 0:
                fail_invocation("not inside a git repository; pass --before-path")
            root = Path(top.stdout.decode("utf-8").strip())
            try:
                path = str(args.after.resolve().relative_to(root.resolve()))
            except ValueError:
                fail_invocation(
                    "--after is outside the repository; pass --before-path"
                )
        return (
            read_git_ref(args.before_ref, path),
            "{}:{}".format(args.before_ref, path),
            True,
        )
    return read_text(args.before), str(args.before), False


def main() -> int:
    args = build_parser().parse_args()

    before, before_label, before_verified = resolve_before(args)
    after = read_text(args.after)
    errors = []
    warnings = []

    if not before_verified:
        warnings.append(
            "--before is an agent-authored snapshot and is NOT independently "
            "verifiable. Use --before-ref so the baseline comes from git."
        )

    # A no-op normalization must not self-certify (cp before.md after.md).
    if before.strip() == after.strip():
        errors.append(
            "no-op normalization: before and after are identical, so no "
            "normalization was performed. This gate cannot be satisfied by "
            "copying the snapshot."
        )

    after_headings = headings(after)
    for required in REQUIRED_HEADINGS:
        if required not in after_headings:
            errors.append("missing required heading after normalization: " + required)

    before_ids = contract_ids(before)
    after_ids = contract_ids(after)
    missing_ids = sorted(before_ids - after_ids)
    if missing_ids:
        errors.append(
            "stable contract identifiers disappeared: " + ", ".join(missing_ids)
        )

    # An empty before_ids set makes the ID invariant vacuously true (before minus
    # after is always empty), so a Plan with no identifiers would PASS this check
    # without the check ever having looked at anything. A Plan reaching this gate
    # has already been through C-1/C-2 and is required by section 4 of
    # docs/ai/plan-normalization-gate.md to carry Acceptance Criteria, so "no
    # identifiers at all" is a violation rather than a WARN. The rationale is
    # recorded in that document so the strictness is a reviewed decision.
    if not before_ids:
        errors.append(
            "no AC/REQ/FR/NFR/R identifiers found in the pre-normalization plan; "
            "the identifier-preservation invariant would be vacuously true. Give "
            "the Plan's acceptance criteria stable IDs before normalizing."
        )

    history_hits = [label for label, p in HISTORY_PATTERNS if p.search(after)]
    if history_hits:
        errors.append(
            "history-dependent wording remains in canonical plan: "
            + ", ".join(history_hits)
        )

    structural_hits = [label for label, p in STRUCTURAL_PATTERNS if p.search(after)]
    if structural_hits:
        errors.append(
            "superseded-state structure remains in canonical plan: "
            + ", ".join(structural_hits)
        )

    for warning in warnings:
        print("  [WARN] " + warning)

    if errors:
        print("[FAIL] plan normalization contract")
        for error in errors:
            print("  - " + error)
        print(
            "  Review decision-log.jsonl for preserved rationale, restore any "
            "missing contract IDs, then normalize again."
        )
        return 1

    print("[PASS] plan normalization contract")
    print("  before: " + before_label)
    print("  required headings: {} present".format(len(REQUIRED_HEADINGS)))
    print("  stable contract IDs preserved: {}".format(len(before_ids)))
    print("  history-dependent wording: none of the known patterns detected")
    print(
        "  NOTE: history detection is a low-recall denylist plus two structural "
        "markers; the skill's manual self-containment check is not optional."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
