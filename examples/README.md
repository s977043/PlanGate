# PlanGate Examples

A complete worked example showing PlanGate artifacts for a real-world task.

## Scenario

**"Add user registration to a Node.js/Express API"**

`POST /api/users` with email validation, bcrypt password hashing (cost=12), and PostgreSQL storage.

## Files

| File | Phase | Description |
|------|-------|-------------|
| `sample-task/pbi-input.md` | A | PBI INPUT PACKAGE (written by human) |
| `sample-task/plan.md` | B | Execution plan (AI-generated) |
| `sample-task/todo.md` | B | Task breakdown for agent execution |
| `sample-task/test-cases.md` | B | Test case definitions |
| `sample-task/review-self.md` | C-1 | 17-point self-review result |
| `sample-task/handoff.md` | WF-05 | Handoff package after completion |
| `sample-task/metrics-events.ndjson` | post-V-1 | Sample metrics events emitted by `bin/plangate metrics` (v8.6.0) |
| `sample-task/metrics-summary.md` | post-V-1 | Sample summary report from `bin/plangate metrics --report` |

## How to Use

1. Read `pbi-input.md` first — this is what the human writes before running PlanGate.
2. Run `/ai-dev-workflow TASK-XXXX plan` to generate the other files automatically.
3. Use these files as format references for your own tasks.
4. After completing a TASK, run `bin/plangate metrics <TASK-XXXX> --collect` then `--report` (v8.6.0+); see `metrics-events.ndjson` / `metrics-summary.md` for expected shapes.

## Templates

Blank templates are available in [`docs/working/templates/`](../docs/working/templates/).
