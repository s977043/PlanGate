#!/bin/sh
# Run ta-25 with GNU sed shimmed ahead of BSD sed on PATH.
SB=/private/tmp/claude-502/-Users-user-Documents-GitHub-plangate/ed736940-223f-452c-bd1b-4dfefbc8ee9d/scratchpad
WT=/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a7a16f3a740ac59c7
PATH="$SB/gnubin:$PATH"
export PATH
sed --version | head -1
sh "$WT/tests/extras/ta-25-approval-token-guard.sh" 2>&1 | tail -6
