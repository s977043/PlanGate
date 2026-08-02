<!-- sync: skill-creator が正本（旧: skill-optimizer / skill-ops-planner と共有、両者は未使用のため削除済み） -->

# Default review checklist

Check the output for:

- task objective is actually answered
- audience fit is appropriate
- required sections are present
- unsupported claims are removed or labeled
- assumptions are explicit
- contradictions are removed
- recommendations are actionable
- wording is specific

See also: `.claude/rules/review-principles.md` for the project-wide review framework.

Resolving that path in an installed environment (it is written against the upstream
repository layout):

1. `.claude/rules/review-principles.md` in the host repository (where `install.sh --claude`
   copies it — its copy targets are `agents` / `skills` / `commands` / `rules` only).
   However, **confirm that the section this skill references (e.g. §3 Severity definitions in
   `review-principles.md`) actually exists**. A same-named file with different content is not
   the PlanGate canonical source, so go to step 2.
2. Otherwise `<plugin_root>/rules/review-principles.md` for the Claude marketplace plugin.
   Resolve `<plugin_root>` by running `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` in Bash — the Read
   tool requires an absolute path and does not expand environment variables, so never Read the
   literal `${CLAUDE_PLUGIN_ROOT}/...` string. If the variable is empty or unset, do not guess
   via cache globs; go to step 3.
3. If neither resolves — always the case for Codex installs, which receive skills only — state
   explicitly that `review-principles.md` could not be read, and use the checklist above as the
   standalone criteria. Do not invent its severity definitions.
