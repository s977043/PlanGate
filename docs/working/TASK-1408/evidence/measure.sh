#!/bin/sh
# TASK-1408 ME-2 / ME-3 / ME-4 / ME-5 measurement (commit-pinned; independent of the working tree).
# usage: sh measure.sh <base-sha> [<canon-sha>]
# Reproduction procedure, not a trust anchor: verify this file's digest against the value recorded in the
# PR body / handoff for reviewed_at_sha before trusting its output (status.md "独立再実行の手順").
# ME-1 (gh pr view 1402) needs network and is recorded separately in measurements.txt.
set -eu

BASE=${1:?usage: measure.sh <base-sha> [<canon-sha>]}
CANON=${2:-}
EXPIRY=3331e5c49751b268412d4db8e5862982ac0005d8
D=docs/ai/ai-loop-v2
P=$D/phase0-migration.md
OTHERS="$D/README.md $D/north-star.md $D/taxonomy.md $D/harness-manifest.md $D/evaluation-trust-boundary.md $D/artifact-responsibilities.md"
V='HarnessManifest|harness_manifest|harness_id|distribution_digest|protected_surfaces'
V="$V"'|independence_level|LoopContract|paired_replay|meta_verifier|promotion_evaluat'
V="$V"'|carve_out|sealed_fixture'
BASELINE='scripts/ai-loop/corpus_hash.py
scripts/ai-loop/run_evidence.py
scripts/ai-loop/test_corpus_hash.py
scripts/ai-loop/test_run_evidence.py'

fail() { echo "FAIL: $*" >&2; exit 1; }

for s in "$BASE" "$EXPIRY" "$EXPIRY^1" ${CANON:+"$CANON"}; do
  git rev-parse --verify -q "$s^{commit}" >/dev/null || fail "unknown commit: $s"
done
[ -n "$V" ] || fail "empty vocabulary"
BASE=$(git rev-parse "$BASE^{commit}")
[ -z "$CANON" ] || CANON=$(git rev-parse "$CANON^{commit}")
PARENT=$(git rev-parse "$EXPIRY^1")

m3() { git grep -liE "$V" "$1" -- scripts bin .github/workflows | sed 's/^[^:]*://' | sort; }

echo "base=$BASE"
echo "canon=${CANON:-(not given)}"
echo "expiry=$EXPIRY parent=$PARENT"

for S in "$PARENT" "$EXPIRY" "$BASE"; do
  echo "######## $S"
  echo "== M-1 (names, recursive) =="
  git ls-tree -r --name-only "$S" schemas | grep -Ei 'harness|loop-contract|run-state|runstate' || echo "(none)"
  echo "== M-1 (content) =="
  c=$(git grep -liE "$V" "$S" -- schemas | sed 's/^[^:]*://')
  [ -n "$c" ] && echo "$c" || echo "(none)"
  echo "== M-2 =="
  git ls-tree -r --name-only "$S" scripts/ai-loop-v2 bin/ai-loop-v2 || true
  echo "== M-3 =="
  m3 "$S" || true
done

# negative / positive controls (fail-closed)
[ -z "$(git ls-tree -r --name-only "$EXPIRY^1" scripts/ai-loop-v2 bin/ai-loop-v2)" ] || fail "M-2 non-empty at parent"
[ "$(m3 "$EXPIRY^1")" = "$BASELINE" ] || fail "M-3 at parent differs from baseline"
m3 "$EXPIRY" | grep -qx 'scripts/ai-loop-v2/run_state.py' || fail "positive control run_state.py not detected at expiry"
m3 "$EXPIRY^1" | grep -qx 'scripts/ai-loop-v2/run_state.py' && fail "positive control detected at parent"
echo "== controls: OK =="

echo "== 1402 canon diff (expect empty) =="
git diff --name-only "$EXPIRY^1" "$EXPIRY" -- "$D"

echo "== post-expiry canon commits (first-parent $EXPIRY..base) =="
git log --first-parent --format='%h %s' "$EXPIRY..$BASE" -- $P $OTHERS

if [ -n "$CANON" ]; then
  echo "== ME-4: other canon 6 files unchanged base..canon =="
  git diff --exit-code --stat "$BASE" "$CANON" -- $OTHERS || fail "other canon files changed"
  echo "OK"
  echo "== ME-4: numstat $P (deletions must be 0) =="
  ns=$(git diff --numstat "$BASE" "$CANON" -- "$P")
  [ -n "$ns" ] || fail "no diff in $P between base and canon"
  echo "$ns"
  [ "$(echo "$ns" | awk '{print $2}')" = "0" ] || fail "deletions in $P"
  echo "== ME-5: baseline block byte-equal base vs canon =="
  blk() { git show "$1:$P" | awk '/^\*\*M-3 の baseline/{f=1} f{print} f&&/^```$/{exit}'; }
  b1=$(blk "$BASE"); b2=$(blk "$CANON")
  [ -n "$b1" ] || fail "baseline block not found"
  [ "$b1" = "$b2" ] || fail "baseline block changed"
  echo "$b1" | git hash-object --stdin
fi
