#!/bin/sh
# apply-task-1353-plan-deliberation-schema.sh
#
# Human-owned Hardening Override application for TASK-1353 / #1353.
# AI may create/review this script but MUST NOT run the apply path.
#
# Usage:
#   sh scripts/apply-task-1353-plan-deliberation-schema.sh --dry-run
#   sh scripts/apply-task-1353-plan-deliberation-schema.sh --human-confirmed
#
# Safety:
# - deterministic generator is the source of the proposed schema content
# - existing mismatched target is never overwritten
# - exact existing target is idempotent SKIP
# - apply requires an explicit Human confirmation flag

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
GENERATOR="$REPO_ROOT/scripts/generate-plan-deliberation-schema.py"
TARGET="$REPO_ROOT/schemas/plan-deliberation.schema.json"
MODE="${1:-}"

case "$MODE" in
  --dry-run|--human-confirmed) ;;
  *)
    echo "Usage: $0 --dry-run | --human-confirmed" >&2
    exit 2
    ;;
esac

[ -f "$GENERATOR" ] || {
  echo "ERROR: generator not found: $GENERATOR" >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 is required" >&2
  exit 1
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT HUP INT TERM

python3 "$GENERATOR" >"$TMP"

python3 - "$TMP" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
schema = json.loads(path.read_text(encoding="utf-8"))

if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
    raise SystemExit("ERROR: unexpected JSON Schema dialect")
if schema.get("properties", {}).get("artifact_type", {}).get("const") != "plan-deliberation":
    raise SystemExit("ERROR: unexpected artifact_type")

try:
    from jsonschema import Draft202012Validator
except ImportError:
    pass
else:
    Draft202012Validator.check_schema(schema)
PY

if [ "$MODE" = "--dry-run" ]; then
  python3 - "$TARGET" "$TMP" <<'PY'
import difflib
import pathlib
import sys

target = pathlib.Path(sys.argv[1])
proposed = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
current = target.read_text(encoding="utf-8") if target.exists() else ""

sys.stdout.writelines(
    difflib.unified_diff(
        current.splitlines(True),
        proposed.splitlines(True),
        fromfile=str(target),
        tofile=str(target) + " (proposed)",
    )
)
PY
  echo "[dry-run] no files changed" >&2
  exit 0
fi

if [ -f "$TARGET" ]; then
  if cmp -s "$TARGET" "$TMP"; then
    echo "SKIP: schema already applied and identical"
    exit 0
  fi
  echo "ERROR: target already exists with different content; refusing overwrite" >&2
  echo "       Review/replan instead of replacing a Stable schema in place." >&2
  exit 1
fi

cp "$TMP" "$TARGET"

python3 -m json.tool "$TARGET" >/dev/null
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  python3 - "$TARGET" <<'PY'
import json
import pathlib
import sys
from jsonschema import Draft202012Validator

schema = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
Draft202012Validator.check_schema(schema)
PY
else
  echo "[WARN] jsonschema not installed; structural schema validation skipped" >&2
fi

echo "[applied] $TARGET"
echo "NEXT: inspect git diff -- schemas/plan-deliberation.schema.json before continuing." >&2
