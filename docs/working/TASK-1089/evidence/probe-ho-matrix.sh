#!/bin/sh
# HO 9 categories x TASK set/unset probe
# usage: sh probe.sh <repo_root>
ROOT=$1
HOOK="$ROOT/scripts/hooks/check-plan-hash.sh"
TASKID=${PROBE_TASK:-TASK-1078}
set -- \
  .claude/rules/working-context.md \
  .claude/settings.json \
  .claude/commands/x.md \
  .claude/agents/x.md \
  scripts/hooks/check-plan-hash.sh \
  bin/plangate \
  schemas/x.schema.json \
  .github/workflows/ci.yml \
  CLAUDE.md
printf '%-42s %-8s %-8s\n' TARGET no-task "task=$TASKID"
for f in "$@"; do
  o1=$(PLANGATE_HOOK_TASK="" PLANGATE_HOOK_FILE="$f" sh "$HOOK" </dev/null 2>&1); r1=$?
  o2=$(PLANGATE_HOOK_TASK="$TASKID" PLANGATE_HOOK_FILE="$f" sh "$HOOK" </dev/null 2>&1); r2=$?
  printf '%-42s rc=%-5s rc=%-5s | %s\n' "$f" "$r1" "$r2" "$(printf '%s' "$o2" | head -1)"
done
