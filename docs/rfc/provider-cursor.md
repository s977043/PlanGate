# RFC: Cursor Provider Support

**Status**: Partial (v8.8.0 — RFC + quickstart + `.cursor/` wiring + hook adapter; full exec automation TBD)
**Created**: 2026-05-19
**Issue**: [#291](https://github.com/s977043/PlanGate/issues/291) / [#82](https://github.com/s977043/PlanGate/issues/82)

## Motivation

Cursor is widely used as an IDE-integrated coding agent. PlanGate already documents Cursor as
「計画中」 in the Provider table, but unlike OpenCode and Gemini CLI there was no RFC, no
`.cursor/` package, and no hook bridge.

Adding Cursor support would:

- Let teams use PlanGate gates (C-3 / C-4, artifacts, `plangate validate`) without switching IDEs
- Reuse the repo-owned skill layer (`.agents/skills/`) already shared with Codex CLI
- Reduce lock-in perception for OSS adopters (aligns with #82 provider abstraction)

## Role mapping

| PlanGate role | Claude Code | Codex CLI | Cursor (this RFC) |
| --- | --- | --- | --- |
| Planner / conductor | `.claude/commands`, `workflow-conductor` agent | `./scripts/ai-dev-workflow` | Agent + `ai-dev-plan` skill (`.agents/skills/`) |
| Implementer | `implementer` agent, `/ai-dev-workflow exec` | `implementer.toml`, `plangate exec` | Cursor Agent (manual or future API); `PLANGATE_IMPL_AGENT=cursor` logs intent |
| External reviewer | Codex / Gemini via `plangate review` | same | same (CLI, outside Cursor) |
| Gate enforcement | `.claude/settings.json` hooks | harness + hooks on Codex path | `.cursor/hooks.json` → `scripts/hooks/cursor-adapter.sh` |

## Proposed configuration

### Environment

```bash
# Active PlanGate task for hook context (required for EH-1 / EH-2 in strict workflows)
export PLANGATE_HOOK_TASK=TASK-0042

# Optional: block on violation instead of warn-only (matches PLANGATE_HOOK_STRICT=1)
export PLANGATE_HOOK_STRICT=1

# Implementation agent dispatch (exec phase)
export PLANGATE_IMPL_AGENT=cursor
bin/plangate exec TASK-0042 --mode standard
```

### Project files (shipped in PlanGate repo)

```text
.cursor/
  hooks.json              # preToolUse → PlanGate EH-1 / EH-2 adapters
  hooks/
    plangate-eh1-plan.sh
    plangate-eh2-c3.sh
  rules/
    plangate.mdc          # Agent rules: read AGENTS.md, skills, working context
docs/cursor/
  quickstart.md           # Level 1–3 setup for Cursor users
scripts/hooks/
  cursor-adapter.sh       # Claude hook JSON ↔ Cursor hook JSON translator
```

Skills remain canonical under `.agents/skills/`. Cursor discovers workflow skills via
symlinks under `.cursor/skills/` (see `docs/cursor/quickstart.md`).

## Implementation plan

### Phase 0 (Done in v8.8.0)

1. RFC (this document) and `docs/cursor/quickstart.md`
2. `.cursor/rules/plangate.mdc` + `hooks.json` + EH-1/EH-2 adapters
3. `scripts/hooks/cursor-adapter.sh` — translate `continue` / `stopReason` → `permission` / messages
4. README Provider row → links to RFC + quickstart
5. `plangate exec` accepts `PLANGATE_IMPL_AGENT=cursor` (manual handoff message)

### Phase 1 (Follow-up)

1. Wire EH-3 (plan_hash), EH-6 (forbidden_files) via `preToolUse` adapters
2. `plangate doctor` — report `.cursor/hooks.json` wiring (parity with `.claude/settings.json`)
3. Optional `plangate doctor --fix` merge for Cursor hooks

### Phase 2 (Future)

1. Cursor Cloud Agents API / SDK integration for automated `exec` (if stable contract exists)
2. Map Cursor subagent types to PlanGate agent roles in `docs/cursor/agent-mapping.md`

## Hook adapter design

Claude Code hooks emit:

```json
{"continue": false, "stopReason": "..."}
```

Cursor `preToolUse` expects:

```json
{"permission": "deny", "user_message": "...", "agent_message": "..."}
```

`cursor-adapter.sh` invokes existing `scripts/hooks/check-*.sh` unchanged, parses stdout,
and emits Cursor-compatible JSON. Existing hook unit tests (`tests/hooks/run-tests.sh`) remain
valid; add `tests/hooks/cursor-adapter-test.sh` for translation-only cases.

## Open questions

- **Task auto-detection**: Should hooks infer `PLANGATE_HOOK_TASK` from the only open `docs/working/TASK-*`
  directory, or always require explicit env (current: explicit, false-positive safe)?
- **Strict by default in Cursor**: Claude defaults to warn-only; should Cursor adapters default to
  `PLANGATE_HOOK_STRICT=1` for IDE users?
- **Tab vs Agent**: PlanGate gates target Agent `Write` / `StrReplace`; Tab inline edits may need
  `afterTabFileEdit` separately.
- **Cloud Agents**: When to promote from manual exec handoff to API-driven `plangate exec`?
