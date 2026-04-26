# PlanGate — Minimal Node.js Example

A minimal PlanGate setup for a Node.js/Express project.

## What this shows

How to apply PlanGate to an existing Node.js project with the minimum required configuration.

## Setup

### Option A: Plugin (recommended)

```bash
git clone https://github.com/s977043/plangate.git
```

Then register the plugin in Claude Code by pointing to `plangate/plugin/plangate/`.
See [plugin registration guide](../../plugin/plangate/README.md).

### Option B: Copy `.claude/` directly

```bash
git clone https://github.com/s977043/plangate.git
cp -r plangate/.claude/ your-node-project/.claude/
```

> **Do not use both methods in the same project.**

## Start a task

```bash
# 1. Create working context
/working-context TASK-0001

# 2. Fill in docs/working/TASK-0001/pbi-input.md (you write this)

# 3. Generate plan + tests
/ai-dev-workflow TASK-0001 plan

# 4. Approve plan (C-3 Gate), then execute
/ai-dev-workflow TASK-0001 exec
```

## Worked example

See [`../sample-task/`](../sample-task/) for a complete set of PlanGate artifact files
using a Node.js/Express scenario (user registration API).

## Project-specific CLAUDE.md

Copy [`CLAUDE.md`](CLAUDE.md) to your Node.js project root and fill in the blanks.
