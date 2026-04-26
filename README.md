# PlanGate

> "No approval, no code." — A gate-driven workflow for AI coding agents.

[![GitHub release](https://img.shields.io/github/v/release/s977043/plangate)](https://github.com/s977043/plangate/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![日本語](https://img.shields.io/badge/lang-%E6%97%A5%E6%9C%AC%E8%AA%9E-blue)](README.ja.md)

PlanGate is a governance-first workflow harness for AI coding agents.
It prevents AI agents from writing production code until a human-approved plan, task list, and acceptance test set exist.

Unlike agent frameworks that focus on autonomy, PlanGate focuses on **approval boundaries, auditability, and Scrum-friendly delivery**.

![PlanGate overview](docs/assets/harness-plangate-readme-dark-v2.png)

## Install

### Option A: Clone and register plugin (recommended)

```bash
git clone https://github.com/s977043/plangate.git
```

Then follow [Claude Code plugin registration instructions](plugin/plangate/README.md) to register the plugin.

### Option B: Copy `.claude/` directly

```bash
git clone https://github.com/s977043/plangate.git
cp -r plangate/.claude/ your-project/.claude/
```

> [!WARNING]
> **Do not use both methods in the same project.**
> Installing the plugin AND copying `.claude/` causes duplicate skill/command resolution.
> Choose one method. See [plugin migration guide](docs/plangate-plugin-migration.md) for details.

## How It Works

PlanGate enforces two human-approval gates before and after AI implementation:

| Gate | When | Decision |
| --- | --- | --- |
| **C-3** | After plan review, before implementation | APPROVE / CONDITIONAL / REJECT |
| **C-4** | After AI implements, on GitHub PR | APPROVE / REQUEST CHANGES |

```text
Human writes PBI → AI generates plan → [C-3: Human approves]
→ AI implements (TDD) → Auto-verify (L-0, V-1…V-4)
→ PR created → [C-4: Human reviews on GitHub] → Merge
```

| Concept | Description |
| --- | --- |
| Plan-first | PBI → plan / todo / test-cases before any code |
| Gate control | C-3 (plan approval) and C-4 (PR review) fix human decision points |
| Built-in verification | L-0 lint fix, V-1 acceptance check, V-3 external review |
| Persistent artifacts | `docs/working/TASK-XXXX/` keeps plan, review, tests, handoff |
| Separated execution layer | v7: Workflow / Skill / Agent separated for reusability |

## Quick Start

```bash
# 1. Create working context
/working-context TASK-XXXX

# 2. Generate plan + todo + test cases + self-review
/ai-dev-workflow TASK-XXXX plan

# 3. [C-3 Gate] Human reviews plan, then execute
/ai-dev-workflow TASK-XXXX exec
```

Details: [docs/plangate.md](docs/plangate.md)

## 10-Minute Tutorial

### Step 1: Create working context

```bash
/working-context TASK-0001
```

Creates `docs/working/TASK-0001/pbi-input.md` and related artifact files.

### Step 2: Fill in PBI INPUT PACKAGE (human)

Edit `docs/working/TASK-0001/pbi-input.md`:

- **Why** — business context, problem being solved
- **What** — scope in / out
- **Acceptance criteria** — verifiable, testable conditions

### Step 3: Generate plan

```bash
/ai-dev-workflow TASK-0001 plan
```

AI produces: `plan.md`, `todo.md`, `test-cases.md`, `review-self.md`

### Step 4: C-3 Gate — Human reviews and approves (human)

Read `docs/working/TASK-0001/plan.md` and decide:

- **APPROVE** → proceed to exec
- **CONDITIONAL** → note required fixes, proceed
- **REJECT** → revise PBI and regenerate plan

### Step 5: Execute

```bash
/ai-dev-workflow TASK-0001 exec
```

AI implements with TDD, runs lint fix (L-0), acceptance check (V-1), external review (V-3), and creates a PR.

### Step 6: C-4 Gate — PR review on GitHub (human)

Review the PR on GitHub and merge when ready. Done.

See `examples/sample-task/` for a complete worked example of all artifact files.

## Plugin vs `.claude/` — Which to use?

| | Plugin (via plugin registration) | `.claude/` copy |
| --- | --- | --- |
| **Use case** | Base layer for multiple projects | Single project or full customization |
| **Update** | Re-clone and re-register | Manual `git pull` |
| **Customization** | Project `.claude/` overrides plugin | Edit directly |
| **Conflict risk** | Low (namespaced skills/commands) | None |

Choose **one** method per project. If you need to customize skills or commands beyond what the plugin offers, use Option B and edit `.claude/` directly.
See [plugin/plangate/README.md](plugin/plangate/README.md) for plugin registration instructions.

## Repository Layout

```text
/docs                    — Knowledge and workflow documentation
  /ai                    — Shared rules and role definitions
  /workflows             — v7 Workflow definitions (WF-01 to WF-05)
  /working               — Per-ticket working context (TASK-XXXX/)
/.claude                 — Claude Code configuration
/.codex                  — Codex CLI configuration
/plugin/plangate         — Claude Code plugin package
/scripts                 — Helper scripts
/examples                — Worked examples of PlanGate artifacts
```

## Claude Code + Codex CLI

PlanGate is designed for use with both Claude Code and Codex CLI. Shared rules are centralized in [docs/ai/project-rules.md](docs/ai/project-rules.md); tool-specific entry files are kept thin.

| Tool | Entry file | Config |
| --- | --- | --- |
| Claude Code | [CLAUDE.md](CLAUDE.md) | `.claude/` |
| Codex CLI | [AGENTS.md](AGENTS.md) | `.codex/` |
| Shared | [docs/ai/project-rules.md](docs/ai/project-rules.md) | `docs/`, `scripts/` |

Role details: [docs/ai/tool-roles.md](docs/ai/tool-roles.md)

## Read Next

| Document | Description |
| --- | --- |
| [docs/philosophy.md](docs/philosophy.md) | Philosophy, problem framing, harness engineering positioning |
| [docs/index.md](docs/index.md) | GitHub Pages documentation entry point |
| [docs/plangate.md](docs/plangate.md) | PlanGate guide, operating procedures, phase descriptions |
| [docs/plangate-v7-hybrid.md](docs/plangate-v7-hybrid.md) | v7 hybrid architecture |
| [docs/workflows/README.md](docs/workflows/README.md) | WF-01 to WF-05 Workflow definitions |
| [docs/plangate-plugin-migration.md](docs/plangate-plugin-migration.md) | Using and migrating to Claude Code plugin |
| [docs/oss-governance.md](docs/oss-governance.md) | OSS publication settings and operational decisions |
| [CHANGELOG.md](CHANGELOG.md) | Major release history |

## Japanese README

[日本語版 README はこちら → README.ja.md](README.ja.md)

## License

MIT — see [LICENSE](LICENSE)
