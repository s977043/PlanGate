# plangate — Claude Code plugin

PlanGate — a governance OS for AI-assisted coding.
Provides Intent/Mode classification, a 4-Gate approval system, and an agent control layer as a Claude Code plugin.

- **Version**: 0.5.0
- **Source**: https://github.com/s977043/plangate

## Install

### Prerequisites

- Claude Code CLI (latest recommended)
- git

### Steps

```bash
# 1. Clone the plangate repository
git clone https://github.com/s977043/plangate.git
cd plangate

# 2. Register the plugin with Claude Code (follow the official Claude Code instructions)
#    e.g. via the plugin install command, or by adding the plugin path to .claude/settings.json
```

Refer to the Claude Code official documentation for detailed plugin registration steps.

## Contents

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json         # manifest (v0.5.0)
├── agents/                 # 6 agents
├── skills/                 # 14 skills
│   ├── brainstorming/
│   ├── self-review/
│   ├── subagent-driven-development/
│   ├── systematic-debugging/
│   ├── codex-multi-agent/
│   ├── setup-team/
│   ├── intent-classifier/
│   ├── skill-policy-router/
│   ├── evidence-ledger/
│   ├── design-gate/
│   ├── review-gate/
│   ├── context-packager/
│   ├── subagent-dispatch/
│   └── pr-decision/
├── commands/               # 7 commands
│   ├── working-context.md
│   ├── ai-dev-workflow.md
│   ├── pg-think.md
│   ├── pg-hunt.md
│   ├── pg-check.md
│   ├── pg-verify.md
│   └── pg-tdd.md
├── rules/                  # 9 rules
│   ├── working-context.md
│   ├── review-principles.md
│   ├── mode-classification.md
│   ├── evidence-ledger.md
│   ├── design-gate.md
│   ├── review-gate.md
│   ├── completion-gate.md
│   ├── subagent-roles.md
│   └── worktree-policy.md
├── hooks/                  # (reserved for future use)
└── scripts/                # (reserved for future use)
```

## Basic Usage

### Start a workflow

```
/working-context TASK-XXXX
/ai-dev-workflow TASK-XXXX plan
/ai-dev-workflow TASK-XXXX exec
```

### Invoke skills explicitly

```
plangate:brainstorming
plangate:self-review
plangate:subagent-driven-development
plangate:systematic-debugging
plangate:codex-multi-agent
```

### Invoke agents (via the Task tool)

```python
Task(subagent_type="plangate:workflow-conductor", ...)
Task(subagent_type="plangate:spec-writer", ...)
Task(subagent_type="plangate:implementer", ...)
Task(subagent_type="plangate:linter-fixer", ...)
Task(subagent_type="plangate:acceptance-tester", ...)
Task(subagent_type="plangate:code-optimizer", ...)
```

### Rule references

Agents inside the plugin reference rules using paths relative to the plugin root:

```markdown
> Authoritative source: `plugin/plangate/rules/mode-classification.md`
```

## Troubleshooting

### `plangate:<skill>` is not recognized

- Verify the plugin is correctly installed and enabled
- Restart Claude Code

### Conflict with a legacy `.claude/` directory

- The plugin and a legacy `.claude/` setup can coexist (dual-mode operation)
- Use the explicit `plangate:` prefix to target the plugin side
- To fully separate, temporarily rename or remove files in `.claude/`

### Using an agent not bundled in this plugin (e.g. `backend-specialist`)

Project-specific agents are not included in this plugin. Obtain them directly:

```bash
git clone https://github.com/s977043/plangate.git
cp plangate/.claude/agents/backend-specialist.md <your-project>/.claude/agents/
```

See the [migration guide](../../docs/plangate-plugin-migration.md) for details.

### Using hooks

Hooks are not implemented in this version (directory structure reserved). Planned for a future release.

## Known Limitations

- Post-install behavior depends on Claude Code internals (refer to runtime verification results)
- `test-engineer` and `release-manager` agents are not bundled (they do not exist in `.claude/` either)

## References

- Migration guide: [docs/plangate-plugin-migration.md](../../docs/plangate-plugin-migration.md)
- Project repository: https://github.com/s977043/plangate
- Parent issue: [#16](https://github.com/s977043/plangate/issues/16)

## License

See the LICENSE file at the repository root.
