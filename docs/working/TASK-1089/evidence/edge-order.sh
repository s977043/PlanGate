#!/bin/sh
# Edge ordering cases: no-task x HO x STRICT / plan.md-like HO path
unset PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_SKIP_REASON PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT 2>/dev/null || true
H="$1/scripts/hooks/check-plan-hash.sh"
e() { printf '%-46s rc=%-3s %s\n' "$1" "$2" "$(printf '%s' "$3" | head -1 | cut -c1-80)"; }
o=$(PLANGATE_HOOK_FILE=bin/plangate PLANGATE_HOOK_STRICT=1 sh "$H" </dev/null 2>&1); r=$?
e "E1 no-task + HO + STRICT=1" "$r" "$o"
o=$(PLANGATE_HOOK_FILE=.claude/rules/plan.md sh "$H" </dev/null 2>&1); r=$?
e "E2 no-task + HO path named plan.md" "$r" "$o"
o=$(PLANGATE_HOOK_FILE=bin/plangate PLANGATE_SKIP_REASON=x sh "$H" </dev/null 2>&1); r=$?
e "E3 no-task + HO + SKIP_REASON" "$r" "$o"
o=$(PLANGATE_HOOK_FILE="" sh "$H" </dev/null 2>&1); r=$?
e "E4 no-task + empty target" "$r" "$o"
o=$(PLANGATE_HOOK_TASK=TASK-X PLANGATE_HOOK_FILE="" sh "$H" </dev/null 2>&1); r=$?
e "E5 task + empty target" "$r" "$o"
o=$(PLANGATE_HOOK_TASK=TASK-X PLANGATE_HOOK_FILE="docs/x.md" sh "$H" </dev/null 2>&1); r=$?
e "E6 task + non-HO .md" "$r" "$o"
