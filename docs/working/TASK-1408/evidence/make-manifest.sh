#!/bin/sh
# Generate the declaration (evidence/manifest.txt) only. check.sh compares it in a repro-check
# (detects forgetting to regenerate; not a tamper check).
# usage (repo root): sh docs/working/TASK-1408/evidence/make-manifest.sh <base-sha> <canon-sha>
# Deterministic: no timestamps, so regenerating with the same inputs is a no-op.
set -eu
E=docs/working/TASK-1408/evidence
BASE=$(git rev-parse "${1:?base}^{commit}")
CANON=$(git rev-parse "${2:?canon}^{commit}")
ME1=$(gh pr view 1402 -R s977043/plangate --json state,mergedAt,mergeCommit)
[ -n "$ME1" ] || { echo "FAIL: empty gh output" >&2; exit 1; }
h() { shasum -a 256 "$1" | cut -d' ' -f1; }
{
  echo "task: TASK-1408"
  echo "note: self-declared. The sha256 values below are written by the author in the same commit as the scripts;"
  echo "note: in-repo matching detects forgetting to regenerate, not tampering. Trust anchor: reviewed_at_sha and"
  echo "note: script digests recorded outside the commit (PR body / handoff), plus Human C-4."
  echo "base: $BASE"
  echo "canon: $CANON"
  echo "canon_parent: $BASE"
  echo "canon_paths: .github/PULL_REQUEST_TEMPLATE.md docs/ai/ai-loop-v2/phase0-migration.md"
  echo "head: (not declarable: this file is part of head) recorded outside the commit by the reviewer; check.sh stops unless HEAD equals that record"
  echo "head_paths_prefix: docs/working/TASK-1408/"
  for f in measure.sh check.sh make-manifest.sh regen.sh measurements.txt; do
    echo "sha256 $f: $(h "$E/$f")"  # self-declared
  done
  echo "me1: $ME1"
  echo "executor: author context (not independent)"
  echo "independent-rerun: NOT YET (T-10, separate context)"
} > "$E/manifest.txt"
echo "manifest written"
