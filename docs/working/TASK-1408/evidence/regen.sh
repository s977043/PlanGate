#!/bin/sh
# Regenerate evidence after the canon commit (run from repo root with HEAD = canon commit or later evidence-only commits).
# usage: sh docs/working/TASK-1408/evidence/regen.sh <base-sha> <canon-sha>
set -eu
E=docs/working/TASK-1408/evidence
sh "$E/measure.sh" "${1:?base}" "${2:?canon}" > "$E/measurements.txt"
sh "$E/make-manifest.sh" "$1" "$2"
echo "regen OK. Commit evidence; the reviewer records head + measure.sh digest, then runs: sh <pinned check.sh> $1 $2 <evidence-head> <measure.sh-sha256>"
