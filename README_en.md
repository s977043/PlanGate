# PlanGate

> "No approval, no code." — A gate-driven workflow for AI coding agents.

[![GitHub release](https://img.shields.io/github/v/release/s977043/plangate)](https://github.com/s977043/plangate/releases)
[![CI](https://github.com/s977043/plangate/actions/workflows/ci.yml/badge.svg)](https://github.com/s977043/plangate/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/s977043/plangate/badge)](https://securityscorecards.dev/viewer/?uri=github.com/s977043/plangate)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![日本語](https://img.shields.io/badge/lang-%E6%97%A5%E6%9C%AC%E8%AA%9E-blue)](README.md)

PlanGate is a governance-first workflow harness for AI coding agents.
It prevents AI agents from writing production code until a human-approved plan, task list, and acceptance test set exist.

Unlike agent frameworks that focus on autonomy, PlanGate focuses on **approval boundaries, auditability, and Scrum-friendly delivery**.

![PlanGate overview](docs/assets/harness-plangate-readme-dark-v2.png)

## Install

### Option A: Clone and register plugin (recommended)

```bash
git clone https://github.com/s977043/plangate.git
cd plangate
```

Then follow [Claude Code plugin registration instructions](plugin/plangate/README.md), or copy `.claude/` into your project.

### Option B: Copy `.claude/` directly

```bash
git clone https://github.com/s977043/plangate.git
cp -r plangate/.claude/ your-project/.claude/
```

> [!NOTE]
> **New users should pick either Option A or Option B.**
> For existing users or staged migrations, dual-running the plugin alongside `.claude/` is technically supported, but be aware that same-named Skills / commands may resolve in non-obvious order.
> To explicitly invoke the plugin side, use the `plangate:<skill-or-agent>` prefix. See [plugin migration guide](docs/plangate-plugin-migration.md) for details.

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
| Control OS | v7.2+: Intent / Mode / GatePolicy / Evidence Ledger / Completion Gate |

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
| **Conflict risk** | Low through namespacing, but duplicate command / skill resolution still matters | None |

For a new installation, choose one method. During migration or advanced customization, you may run the plugin as a base layer and keep project-specific overrides in `.claude/`.
See [plugin/plangate/README.md](plugin/plangate/README.md) for plugin registration instructions.

## Repository Layout

```text
/bin                     — plangate CLI (init / doctor / status / validate [--mode] / review / exec / abort / timeline / resume)
/docs                    — Knowledge and workflow documentation
  /ai                    — Shared rules, role definitions, execution contract, Model Profile, Prompt Assembly, Eval framework (v8.3)
    /contracts           — Phase-specific contracts × 7 (plan / classify / approve-wait / execute / review / verify / handoff)
    /adapters            — Profile-specific adapters × 4 (outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown)
    /eval-cases          — Model migration eval observation points × 8 (v8.3)
  /workflows             — v7 Workflow definitions (WF-01 to WF-05 + Orchestrator)
  /working               — Per-ticket working context (TASK-XXXX/, PBI-XXX/)
/schemas                 — JSON Schemas (plan / handoff / status / approval / model-profile / Structured Outputs × 4 etc.)
/workflows               — v8 Workflow DSL (5-mode YAML: ultra-light / light / standard / high-risk / critical)
/.claude                 — Claude Code configuration
/.codex                  — Codex CLI configuration
/plugin/plangate         — Claude Code plugin package
/scripts                 — Helper scripts
/examples                — Worked examples of PlanGate artifacts
/tests                   — CLI test suite (fixtures + run-tests.sh)
```

## Claude Code + Codex CLI

PlanGate is designed for use with both Claude Code and Codex CLI. Shared rules are centralized in [docs/ai/project-rules.md](docs/ai/project-rules.md); tool-specific entry files are kept thin.

| Tool | Entry file | Config |
| --- | --- | --- |
| Claude Code | [CLAUDE.md](CLAUDE.md) | `.claude/` |
| Codex CLI | [AGENTS.md](AGENTS.md) | `.codex/` |
| Shared | [docs/ai/project-rules.md](docs/ai/project-rules.md) | `docs/`, `scripts/` |

Role details: [docs/ai/tool-roles.md](docs/ai/tool-roles.md)

## CLI

`bin/plangate` is a POSIX sh CLI for local PlanGate task contexts.

```bash
bin/plangate init TASK-XXXX
bin/plangate status TASK-XXXX
bin/plangate validate TASK-XXXX --mode high-risk
PLANGATE_EXTERNAL_REVIEWER=gemini bin/plangate review TASK-XXXX --phase c2
PLANGATE_IMPL_AGENT=opencode bin/plangate exec TASK-XXXX --mode standard
```

- `validate --mode <mode>` reads `gate_enforcement.c3.required_artifacts` from `workflows/<mode>.yaml`.
- `review` dispatches an external reviewer provider and writes `review-external.md`.
- `exec` blocks execution unless the C-3 gate is `APPROVED`.

## Testing

Run the CLI test suite locally:

```bash
sh tests/run-tests.sh
```

The suite has **10 tests** total (as of v8.1.0) and validates:

- `plangate validate --dir` against four fixture scenarios (complete-task / missing-approval / stale-plan-hash / broken-pbi)
- `plangate validate --mode <mode>` — artifact list determined dynamically from Workflow DSL (standard passes, unknown mode errors)
- `plangate review` — usage shown when arguments are missing
- `plangate exec` — blocked when the C-3 gate (`approvals/c3.json` with APPROVED) has not cleared

CI runs the same suite on every PR via `.github/workflows/test.yml`.

## Provider Support

PlanGate's governance workflow is designed to be provider-agnostic.
The gate mechanism, artifact schemas, and `run.ndjson` log format work independently of the AI tool used.

| Provider | Role | Status |
| --- | --- | --- |
| Claude Code | Plan generation, exec orchestration | Fully supported |
| Codex CLI | External review (C-2 / V-3), parallel exec | Fully supported |
| Gemini CLI | External review | Supported — `PLANGATE_EXTERNAL_REVIEWER=gemini plangate review` |
| OpenCode | Implementation agent | Supported — `PLANGATE_IMPL_AGENT=opencode plangate exec` |
| Cursor | Implementation agent | Planned |

To contribute support for a new provider, see [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-new-provider).

## Read Next

| Document | Description |
| --- | --- |
| [docs/philosophy.md](docs/philosophy.md) | Philosophy, problem framing, harness engineering positioning |
| [docs/index.md](docs/index.md) | GitHub Pages documentation entry point |
| [docs/plangate.md](docs/plangate.md) | PlanGate guide, operating procedures, phase descriptions |
| [docs/plangate-v7-hybrid.md](docs/plangate-v7-hybrid.md) | v7 hybrid architecture |
| [docs/orchestrator-mode.md](docs/orchestrator-mode.md) | Parent-Child PBI Orchestrator Mode specification |
| [docs/workflows/README.md](docs/workflows/README.md) | WF-01 to WF-05 Workflow definitions |
| [docs/ai/core-contract.md](docs/ai/core-contract.md) | Execution contract canonical (Iron Law / Stop rules / Output discipline) |
| [docs/ai/model-profiles.yaml](docs/ai/model-profiles.yaml) | Per-execution-model 4 profiles (v8.3) |
| [docs/ai/prompt-assembly.md](docs/ai/prompt-assembly.md) | 4-layer prompt assembly (v8.3) |
| [docs/ai/structured-outputs.md](docs/ai/structured-outputs.md) | Structured Outputs / JSON Schema policy (v8.3) |
| [docs/ai/eval-plan.md](docs/ai/eval-plan.md) | Model migration eval framework (8 observations, v8.3) |
| [docs/ai/responsibility-boundary.md](docs/ai/responsibility-boundary.md) | CLAUDE.md / Skill / Hook responsibility boundary (v8.3) |
| [docs/ai/tool-policy.md](docs/ai/tool-policy.md) | Phase-specific allowed_tools (v8.3) |
| [docs/ai/hook-enforcement.md](docs/ai/hook-enforcement.md) | Hook-enforced items EHS-1 to EHS-3 (v8.3) |
| [docs/plangate-plugin-migration.md](docs/plangate-plugin-migration.md) | Using and migrating to Claude Code plugin |
| [docs/oss-governance.md](docs/oss-governance.md) | OSS publication settings and operational decisions |
| [CHANGELOG.md](CHANGELOG.md) | Major release history |

## Japanese README

[日本語版 README はこちら → README.md](README.md)

## License

MIT — see [LICENSE](LICENSE)
