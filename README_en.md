# PlanGate

> "No approval, no code." — A gate-driven workflow for AI coding agents.  
> 日本語: AI コーディングエージェントのための軽量ガバナンスハーネス。

[![GitHub release](https://img.shields.io/github/v/release/s977043/plangate)](https://github.com/s977043/plangate/releases)
[![CI](https://github.com/s977043/plangate/actions/workflows/ci.yml/badge.svg)](https://github.com/s977043/plangate/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/s977043/plangate/badge)](https://securityscorecards.dev/viewer/?uri=github.com/s977043/plangate)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![日本語](https://img.shields.io/badge/lang-%E6%97%A5%E6%9C%AC%E8%AA%9E-blue)](README.md)

PlanGate is a governance-first workflow harness for AI coding agents.
It prevents AI agents from writing production code until a human-approved plan, task list, and acceptance test set exist.

Unlike agent frameworks that focus on autonomy, PlanGate focuses on **approval boundaries, auditability, and Scrum-friendly delivery**.

![PlanGate overview](docs/assets/harness-plangate-readme-dark-v2.png)

## Current Status

As of v8.6.0, PlanGate combines Hook enforcement with **Metrics v1** and **Harness Improvement Governance**, so the improvement cycle can be judged by comparison rather than intuition.

| Item | Status |
| --- | --- |
| Latest release | **v8.6.0** — Harness Improvement Roadmap Phase 0/1 + Governance |
| Hook enforcement | **10/10 hooks implemented** (carried over from v8.5.0) |
| Metrics v1 | Workflow event collection and reporting via `bin/plangate metrics` (v8.6.0) |
| Baseline | v8.5.0 baseline fixed under `docs/ai/eval-baselines/` (v8.6.0) |
| Governance | Issue / Label / Milestone Governance + Metrics Privacy Policy (v8.6.0) |
| CLI tests | `sh tests/run-tests.sh` — **32 PASS** |
| Hook tests | `sh tests/hooks/run-tests.sh` — **42 PASS** |
| Eval | 8-observation evaluation and release blocker detection via `bin/plangate eval` |
| Schema | JSON artifact validation via `validate-schemas` + CI |

v8.6.0 can check these invariants through hooks and CLI:

- Detect production code edits without `plan.md`
- Block execution without C-3 approval
- Detect post-approval `plan.md` tampering through `plan_hash`
- Detect V-1 execution without `test-cases.md`
- Detect PR creation without verification evidence
- Detect out-of-scope file edits through `forbidden_files`
- Detect merges without both C-3 and C-4 approvals
- Require V-3 external review for standard / high-risk / critical modes

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
| Gate control | C-3 plan approval and C-4 PR review fix human decision points |
| Hook enforcement | v8.5 checks plan / approval / evidence / scope / review invariants through hooks and CLI |
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
/bin                     — plangate CLI (init / doctor / status / validate / validate-schemas / review / exec / eval / abort / timeline / resume)
/docs                    — Knowledge and workflow documentation
  /ai                    — Shared rules, role definitions, execution contract, Model Profile, Prompt Assembly, Eval framework (v8.3+)
    /contracts           — Phase-specific contracts × 7 (plan / classify / approve-wait / execute / review / verify / handoff)
    /adapters            — Profile-specific adapters × 4 (outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown)
    /eval-cases          — Model migration eval observation points × 8 (v8.3+)
  /workflows             — v7 Workflow definitions (WF-01 to WF-05 + Orchestrator)
  /working               — Per-ticket working context (TASK-XXXX/, PBI-XXX/)
/schemas                 — JSON Schemas (plan / handoff / status / approval / model-profile / Structured Outputs / eval-result etc.)
/workflows               — v8 Workflow DSL (5-mode YAML: ultra-light / light / standard / high-risk / critical)
/.claude                 — Claude Code configuration
/.codex                  — Codex CLI configuration
/plugin/plangate         — Claude Code plugin package
/scripts                 — Helper scripts, hooks, parsers, CI helpers
/examples                — Worked examples of PlanGate artifacts
/tests                   — CLI / hook test suite (fixtures + hooks + extras + run-tests.sh)
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
bin/plangate validate-schemas TASK-XXXX
bin/plangate eval TASK-XXXX --no-write
PLANGATE_EXTERNAL_REVIEWER=gemini bin/plangate review TASK-XXXX --phase c2
PLANGATE_IMPL_AGENT=opencode bin/plangate exec TASK-XXXX --mode standard
```

- `validate --mode <mode>` reads `gate_enforcement.c3.required_artifacts` from `workflows/<mode>.yaml`.
- `validate-schemas` validates task artifacts against JSON Schemas.
- `eval` generates `eval-result.{md,json}` with 8-observation evaluation and release blocker detection.
- `review` dispatches an external reviewer provider and writes `review-external.md`.
- `exec` blocks execution unless the C-3 gate is `APPROVED`.

## Testing

Run the CLI / hook test suites locally:

```bash
sh tests/run-tests.sh
sh tests/hooks/run-tests.sh
```

Test status as of v8.6.0:

| Suite | Count | Main coverage |
| --- | ---: | --- |
| `tests/run-tests.sh` | **32 PASS** | CLI, Workflow DSL, schema validate, eval, metrics v1, provider dispatch, fixture validation |
| `tests/hooks/run-tests.sh` | **42 PASS** | EH-1 to EH-7 / EHS-1 to EHS-3, default / strict / bypass mode behavior |

Main coverage:

- `plangate validate --dir` — complete-task / missing-approval / stale-plan-hash / broken-pbi fixtures
- `plangate validate --mode <mode>` — artifact list determined dynamically from Workflow DSL
- `plangate validate-schemas` — JSON Schema compliance for task artifacts
- `plangate eval` — 8-observation evaluation, baseline comparison, release blocker detection
- `plangate metrics` — workflow event collection / reporting (v8.6.0)
- `plangate review` — external reviewer provider dispatch
- `plangate exec` — blocked execution when the C-3 gate has not cleared
- hook enforcement — plan / approval / hash / test-cases / evidence / forbidden_files / merge approvals / V-3 review checks

CI runs the same CLI / hook suites on every PR via `.github/workflows/test.yml`.

## Metrics v1 — 5-minute quickstart (v8.6.0)

PlanGate v8.6.0 introduces structured workflow event collection and aggregation.
It is opt-in: existing workflows are unaffected.

```bash
# 1. After a TASK completes, collect events (append-only NDJSON)
bin/plangate metrics TASK-XXXX --collect

# 2. Show summary for that TASK
bin/plangate metrics TASK-XXXX --report

# 3. Aggregate across all TASKs (hook violations / C-3 / V-1 / C-4 / by mode)
bin/plangate metrics --report --aggregate

# 4. Emit JSON (for baseline comparison or CI pipelines)
bin/plangate metrics TASK-XXXX --report --json
```

Sample artifacts:

- [`examples/sample-task/metrics-events.ndjson`](examples/sample-task/metrics-events.ndjson) — minimal 8-event example
- [`examples/sample-task/metrics-summary.md`](examples/sample-task/metrics-summary.md) — sample `--report` output

| Item | Location / Spec |
| --- | --- |
| Event schema | [`schemas/plangate-event.schema.json`](schemas/plangate-event.schema.json) — 11 events, `additionalProperties: false` |
| Event log | `docs/working/_metrics/events.ndjson` — **excluded by `.gitignore`, never committed** |
| Privacy policy | [`docs/ai/metrics-privacy.md`](docs/ai/metrics-privacy.md) — only §3 Allowed fields are emitted; §4 Forbidden is blocked at the schema level |
| Privacy enforcement | Hook EH-8 (`scripts/hooks/check-metrics-privacy.sh`) — checks staging for events.ndjson / Forbidden fields |
| Baseline | [`docs/ai/eval-baselines/2026-05-04-baseline.{md,json}`](docs/ai/eval-baselines/) — fixed snapshot just after v8.5.0, the comparison anchor for later improvements |
| Operational guide | [`docs/ai/metrics.md`](docs/ai/metrics.md) — 9-chapter guide |

> [!NOTE]
> **`docs/working/_metrics/events.ndjson` is never committed to the public repo.** Privacy is enforced by three layers: `.gitignore` + Hook EH-8 + schema `additionalProperties: false`.

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
| [docs/ai/structured-outputs.md](docs/ai/structured-outputs.md) | Structured Outputs / JSON Schema policy (v8.3+) |
| [docs/ai/eval-plan.md](docs/ai/eval-plan.md) | Model migration eval framework (8 observations) |
| [docs/ai/eval-runner.md](docs/ai/eval-runner.md) | Machine evaluation CLI spec for `bin/plangate eval` |
| [docs/ai/responsibility-boundary.md](docs/ai/responsibility-boundary.md) | CLAUDE.md / Skill / Hook responsibility boundary |
| [docs/ai/tool-policy.md](docs/ai/tool-policy.md) | Phase-specific allowed_tools definition |
| [docs/ai/hook-enforcement.md](docs/ai/hook-enforcement.md) | v8.5 Hook enforcement 10/10 implementation status |
| [docs/plangate-plugin-migration.md](docs/plangate-plugin-migration.md) | Using and migrating to Claude Code plugin |
| [docs/oss-governance.md](docs/oss-governance.md) | OSS publication settings and operational decisions |
| [CHANGELOG.md](CHANGELOG.md) | Major release history |

## Japanese README

[日本語版 README はこちら → README.md](README.md)

## License

MIT — see [LICENSE](LICENSE)
