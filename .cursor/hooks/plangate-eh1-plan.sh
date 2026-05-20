#!/bin/sh
# EH-1: plan.md must exist before production edits (Cursor preToolUse)
exec sh "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)/scripts/hooks/cursor-adapter.sh" check-plan-exists.sh
