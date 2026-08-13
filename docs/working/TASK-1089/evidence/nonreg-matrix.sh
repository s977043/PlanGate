#!/bin/sh
# Non-regression matrix for check-plan-hash.sh
# usage: sh nonreg.sh <sandbox_root_containing_scripts/hooks/check-plan-hash.sh>
unset PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_SKIP_REASON PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT 2>/dev/null || true
ROOT=$1
HOOK="$ROOT/scripts/hooks/check-plan-hash.sh"
W="$ROOT/docs/working"
mkdir -p "$W/_audit" "$W/TASK-T/approvals" "$W/_maintenance"
rm -f "$W/_maintenance/maintenance.json"

run() { # label, then env assignments via caller using env prefix
  :
}
emit() {
  printf '%-52s rc=%-3s %s\n' "$1" "$2" "$(printf '%s' "$3" | head -1 | cut -c1-90)"
}

# --- task context, non-HO target ---
rm -f "$W/TASK-T/plan.md" "$W/TASK-T/approvals/c3.json"
o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=docs/foo.txt sh "$HOOK" </dev/null 2>&1); r=$?
emit "T1 task/plan.md absent" "$r" "$o"

printf 'PLAN BODY\n' > "$W/TASK-T/plan.md"
o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=docs/foo.txt sh "$HOOK" </dev/null 2>&1); r=$?
emit "T2 task/c3.json absent" "$r" "$o"

printf '{"c3_status":"APPROVED"}\n' > "$W/TASK-T/approvals/c3.json"
o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=docs/foo.txt sh "$HOOK" </dev/null 2>&1); r=$?
emit "T3 task/plan_hash unrecorded" "$r" "$o"

H=$(shasum -a 256 "$W/TASK-T/plan.md" | awk '{print $1}')
printf '{"c3_status":"APPROVED","plan_hash":"sha256:%s"}\n' "$H" > "$W/TASK-T/approvals/c3.json"
o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=docs/foo.txt sh "$HOOK" </dev/null 2>&1); r=$?
emit "T4 task/plan_hash match" "$r" "$o"

printf '{"c3_status":"APPROVED","plan_hash":"sha256:deadbeef"}\n' > "$W/TASK-T/approvals/c3.json"
o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=docs/foo.txt sh "$HOOK" </dev/null 2>&1); r=$?
emit "T5 task/mismatch default" "$r" "$o"

o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=docs/foo.txt PLANGATE_HOOK_STRICT=1 sh "$HOOK" </dev/null 2>&1); r=$?
emit "T6 task/mismatch STRICT" "$r" "$o"

o=$(PLANGATE_HOOK_TASK=NOPE PLANGATE_HOOK_FILE=docs/foo.txt sh "$HOOK" </dev/null 2>&1); r=$?
emit "T7 invalid task id" "$r" "$o"

o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=docs/working/TASK-T/plan.md sh "$HOOK" </dev/null 2>&1); r=$?
emit "T8 task/target=own plan.md" "$r" "$o"

o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=.claude/rules/x.md PLANGATE_BYPASS_HOOK=1 sh "$HOOK" </dev/null 2>&1); r=$?
emit "T9 BYPASS=1 + HO + task" "$r" "$o"

# --- no-task context ---
o=$(PLANGATE_HOOK_FILE=docs/working/TASK-T/plan.md sh "$HOOK" </dev/null 2>&1); r=$?
emit "N1 no-task/plan.md" "$r" "$o"

o=$(PLANGATE_HOOK_FILE=docs/some/readme.md sh "$HOOK" </dev/null 2>&1); r=$?
emit "N2 no-task/non-HO .md (doc-light)" "$r" "$o"

o=$(PLANGATE_HOOK_FILE=src/app.py sh "$HOOK" </dev/null 2>&1); r=$?
emit "N3 no-task/non-HO non-md no SKIP_REASON" "$r" "$o"

o=$(PLANGATE_HOOK_FILE=src/app.py PLANGATE_SKIP_REASON="because" sh "$HOOK" </dev/null 2>&1); r=$?
emit "N4 no-task/non-HO non-md SKIP_REASON" "$r" "$o"

o=$(PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILE=src/app.py sh "$HOOK" </dev/null 2>&1); r=$?
emit "N5 no-task/STRICT" "$r" "$o"

NOW=$(date -u +%s)
cat > "$W/_maintenance/maintenance.json" <<EOF
{"scope":"t","until":$((NOW+600)),"granted_at":$((NOW-1)),"reason":"t","approved_by":"t"}
EOF
o=$(PLANGATE_HOOK_FILE=src/app.py sh "$HOOK" </dev/null 2>&1); r=$?
emit "N6 no-task/maintenance window non-HO" "$r" "$o"
o=$(PLANGATE_HOOK_FILE=bin/plangate sh "$HOOK" </dev/null 2>&1); r=$?
emit "N7 no-task/maintenance window HO" "$r" "$o"
o=$(PLANGATE_HOOK_TASK=TASK-T PLANGATE_HOOK_FILE=src/app.py sh "$HOOK" </dev/null 2>&1); r=$?
emit "N8 task/maintenance window non-HO" "$r" "$o"
rm -f "$W/_maintenance/maintenance.json"

# stdin JSON path (no env target)
o=$(printf '{"tool_input":{"file_path":"CLAUDE.md"}}' | PLANGATE_HOOK_TASK=TASK-T sh "$HOOK" 2>&1); r=$?
emit "S1 stdin json HO + task" "$r" "$o"
o=$(printf '{"tool_input":{"file_path":"docs/x.txt"}}' | PLANGATE_HOOK_TASK=TASK-T sh "$HOOK" 2>&1); r=$?
emit "S2 stdin json non-HO + task" "$r" "$o"
