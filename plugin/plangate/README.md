# plangate (Claude Code plugin)

> ⚠️ This README is a **placeholder** created by TASK-0017 (skeleton).
> Full documentation (install instructions, usage examples, bundled skill/agent lists, troubleshooting) will be completed in **TASK-0020**.

## Status

- **Version**: 0.1.0 (skeleton)
- **Parent initiative**: [#16 Claude Code plugin 化](https://github.com/s977043/plangate/issues/16)
- **Bundle strategy**: Core (B) — 7 skills + 8 agents + 3 rules

## Planned structure

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json       # manifest (metadata)
├── agents/               # populated by TASK-0019
├── skills/               # populated by TASK-0018
├── rules/                # populated by TASK-0019 (non-standard, referenced from agents)
├── hooks/                # reserved for future deterministic hooks
├── scripts/              # populated by TASK-0019 (referenced via ${CLAUDE_PLUGIN_ROOT}/scripts)
└── README.md             # this file (to be replaced in TASK-0020)
```

## Current state (skeleton only)

The plugin is **not yet functional**. Only the directory scaffolding and manifest exist. Wait for subsequent TASKs:

- [#18 TASK-0018] skills migration (7 items)
- [#19 TASK-0019] agents migration (8 items) + rules + scripts
- [#20 TASK-0020] Full README, migration note, install instructions

## Reference paths (for future scripts/hooks)

- `${CLAUDE_PLUGIN_ROOT}` — resolves to the plugin root directory at runtime
- Example: `node "${CLAUDE_PLUGIN_ROOT}/scripts/example.mjs"`

## License

See repository root LICENSE.
