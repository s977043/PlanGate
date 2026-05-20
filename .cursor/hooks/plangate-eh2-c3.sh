#!/bin/sh
# EH-2: C-3 approval required (Cursor preToolUse)
exec sh "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)/scripts/hooks/cursor-adapter.sh" check-c3-approval.sh
