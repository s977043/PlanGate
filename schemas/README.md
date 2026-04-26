# PlanGate Schemas

JSON Schema definitions for PlanGate artifacts and execution records.

## Artifact Schemas (frontmatter)

All PlanGate markdown artifacts carry a YAML frontmatter block that is validated against these schemas.

| Schema | Artifact file | Description |
| --- | --- | --- |
| `pbi-input.schema.json` | `pbi-input.md` | PBI Input Package |
| `plan.schema.json` | `plan.md` | Execution Plan |
| `todo.schema.json` | `todo.md` | Execution TODO |
| `test-cases.schema.json` | `test-cases.md` | Test Cases |
| `review-self.schema.json` | `review-self.md` | C-1 Self Review |
| `review-external.schema.json` | `review-external.md` | C-2 External Review |
| `handoff.schema.json` | `handoff.md` | WF-05 Handoff Package |

### Frontmatter Standard

```yaml
---
task_id: TASK-0001
artifact_type: plan        # see artifact_type values in each schema
schema_version: 1
status: draft              # draft | approved | final
created_by: spec-writer
source_pbi_hash: sha256:<64-char-hex>
---
```

## Gate Approval Schemas

Machine-readable approval records written to `docs/working/TASK-XXXX/approvals/`.

| Schema | File | Description |
| --- | --- | --- |
| `c3-approval.schema.json` | `approvals/c3.json` | C-3 gate approval record |
| `c4-approval.schema.json` | `approvals/c4.json` | C-4 gate approval record |
| `status.schema.json` | `status.json` | Task state snapshot |

### c3.json example

```json
{
  "task_id": "TASK-0001",
  "phase": "C-3",
  "c3_status": "APPROVED",
  "approved_by": "human",
  "approved_at": "2026-04-26T10:00:00+09:00",
  "plan_hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}
```

### exec pre-check (gate enforcement)

Before `exec` begins, the following are verified:

1. `plan.md`, `todo.md`, `test-cases.md`, `review-self.md` exist
2. `approvals/c3.json` exists and `c3_status === "APPROVED"`
3. Current `sha256(plan.md)` matches `plan_hash` in `c3.json` (detects post-approval modification)
4. For `high-risk` or `critical` mode: `review-external.md` must also exist

## Execution Log Schema

| Schema | File | Description |
| --- | --- | --- |
| `run-event.schema.json` | `run.ndjson` | Single event line in the NDJSON execution log |

### run.ndjson format

Each line is a JSON object conforming to `run-event.schema.json`.

```jsonl
{"ts":"2026-04-26T10:00:00+09:00","task_id":"TASK-0001","phase":"B","event":"plan_generated","agent":"spec-writer"}
{"ts":"2026-04-26T10:30:00+09:00","task_id":"TASK-0001","phase":"C-3","event":"approved","by":"human","plan_hash":"sha256:e3b0c4..."}
{"ts":"2026-04-26T11:00:00+09:00","task_id":"TASK-0001","phase":"D","event":"exec_started","agent":"implementer"}
{"ts":"2026-04-26T11:05:00+09:00","task_id":"TASK-0001","phase":"D","event":"task_completed","task_ref":"T-01","agent":"implementer"}
{"ts":"2026-04-26T11:30:00+09:00","task_id":"TASK-0001","phase":"V-1","event":"acceptance_passed","agent":"acceptance-tester"}
{"ts":"2026-04-26T11:35:00+09:00","task_id":"TASK-0001","phase":"PR","event":"pr_created","pr_number":42,"agent":"orchestrator"}
```

## Schema Version Policy

- `schema_version` starts at `1` and increments on breaking changes.
- Non-breaking additions (new optional fields) do not require a version bump.
