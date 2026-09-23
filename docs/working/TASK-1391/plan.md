# EXECUTION PLAN — TASK-1391 / #1391

## Current verdict

```text
Planning: GO
Pure contract / projection RED: GO after plan review
Production implementation: BLOCKED by #1387 current-head I1 + #1329 preflight
Durable persistence: OUT OF SCOPE -> #1392
```

## Architecture

```text
Producer
  -> RunEvent candidate
  -> #1391 validate/canonicalize
  -> accepted event value
  -> #1392 durable sink
  -> accepted stream
  -> #1391 deterministic projection
  -> RunEvidence
```

The event semantic owner and the durable storage owner are intentionally separated.

## Proposed implementation surface

Initial code surface after gates:

- `scripts/ai-loop-v2/run_event.py`
  - strict RunEvent parsing / canonicalization
  - event identity
  - stream validation
- `scripts/ai-loop-v2/run_evidence.py`
  - pure projection
- `scripts/ai-loop-v2/test_run_event.py`
- `scripts/ai-loop-v2/test_run_evidence.py`
- `tests/extras/ta-XX-ai-loop-v2-event-evidence.sh`

No top-level JSON Schema in the first vertical slice unless review proves a machine-readable external schema is required. This avoids moving M-1 and M-2 simultaneously without need. Runtime code itself will still move M-2 and trigger #1329.

## RunEvent minimum envelope

Required:
- schema/version marker
- run_id
- event_ref
- event_seq
- event_type
- harness_manifest_ref
- payload
- evidence refs where applicable

Conditional:
- revision
- plan_hash
- source_sha

Rules:
- event_seq is strictly increasing in an accepted stream
- event_seq is independent from RunState revision
- event_ref is stable and unique
- duplicate event_ref with byte/semantic mismatch is invalid
- event type determines allowed payload keys
- unknown critical fields do not fail open

## First-slice event vocabulary

Only what #1383 and immediate owners need:
- plan_contract_bound
- worker_completed
- verification_recorded
- failure_recorded
- artifact_changed
- repair_attempted
- progress_assessed
- pr_convergence_recorded
- decision_made
- state/conflict evidence consumed from #1392

Exact names are frozen by RED fixtures before GREEN implementation. Do not design Evolution event vocabulary here.

## RunEvidence minimum projection

- harness_manifest_ref
- outcome
- stop_reasons[]
- policy_verdicts[]
- verification_result_refs[]
- failure_record_refs[]
- evidence_refs[]
- evidence_status = ready | partial | invalid

Projection rules:
- pure: no network, current Git state, environment, wall clock, or mutable external file lookup
- same accepted input -> same output
- unfinished stream -> partial
- malformed/tampered/binding-inconsistent stream -> invalid
- receiver derives evidence_status
- post-terminal event -> invalid

## Work breakdown

### T1 — Inventory / contract freeze

- compare #1387 fixture envelope with canon
- identify reusable privacy/canonicalization functions from Legacy without importing Legacy vocabulary
- reserve next-free TA number at implementation start
- record exact M-1/M-2/M-3 base evidence

### T2 — RED: event validation

Write tests first for:
- duplicate ref
- non-monotonic seq
- same ref / different content
- harness drift
- invalid taxonomy value
- forbidden raw/private fields
- unbounded/unknown payload field
- future/missing evidence ref where reference integrity applies

### T3 — RED: projection

Write tests first for:
- deterministic replay
- incomplete -> partial
- terminal ready path
- binding mismatch -> invalid
- HUMAN_ESCALATED without reason
- MERGE_READY with reason
- multiple terminal outcomes
- post-terminal event
- producer self-declared ready ignored/rejected

### T4 — Minimal GREEN implementation

Implement strict parse/canonicalization and pure projection only.
No durable writer.

### T5 — TA / repository integration

- standalone-capable extras contract
- explicit 7 guarded-env unset in file
- harness/standalone path correctness
- full `tests/run-tests.sh`
- mutation/negative controls

### T6 — Owner adapter handoff

Define interfaces consumed by #1392/#1393:
- validate_event(value)
- validate_stream(values)
- canonical_event_ref(value)
- project_run_evidence(values, manifest_ref)

Names may differ after implementation review; responsibilities may not.

### T7 — Review

- I0 self-review
- I1+ independent review at exact SHA
- #1329 invalidation evidence
- no C-4/merge

## Replan triggers

- #1392 requires persistence semantics inside #1391
- #1393 requires Decision logic inside event validation
- a formal schema is required before code can be safely consumed
- event_seq must equal RunState revision
- projection requires live external state
- Legacy schema must change

Any of these means the responsibility boundary is wrong and must be reviewed before implementation.
