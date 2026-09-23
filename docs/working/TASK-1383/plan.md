# EXECUTION PLAN — TASK-1383 / #1383

## Goal

V2 Delivery first release boundary の2経路を、owner contracts を再実装せず executable fixture で統合する。

## Current verdict

```text
Contract integration planning: GO
Runtime implementation: BLOCKED
```

Runtime blocker is not vague: Gate A in `dependency-matrix.md` is incomplete.

## Strategy

### Stage 0 — Contract integration readiness

Owner Issue の責務を横取りせず、#1383 が consume する最小フィールド / semantic を固定する。

Deliverables:

- dependency matrix
- two E2E trace specifications
- artifact/event ownership map
- negative/mutation cases
- implementation entry checklist

No `scripts/ai-loop-v2/**` in this stage.

### Stage 1 — Owner subset confirmation

#1025 / #894 / #874 の各 owner に #1383 required subset を comment で提示する。

Acceptance:

- owner issue側で衝突が見つかったら #1383 planをrebase
- owner全体のcloseは要求しない
- subsetが stable / accepted になれば Gate A を進める

### Stage 2 — RED E2E fixture

Gate A + #1329 preflight 後のみ。

Candidate runtime namespace:

```text
scripts/ai-loop-v2/
  delivery_e2e.py
  test_delivery_e2e.py

tests/fixtures/ai-loop-v2/delivery/
  repair-convergence/
  no-progress-stop/
```

Important: this is an integration harness, not a second production orchestrator.

### Stage 3 — GREEN minimum integration

Implement only enough adapters to connect owner contracts:

```python
start_run(contract, state, manifest_ref)
record_verification(...)
normalize_failure(...)
decide(...)
apply_repair_fixture(...)
project_run_evidence(...)
```

The functions are illustrative; final API follows owner contracts.

### Stage 4 — E2E evidence

Path A asserts:

- Worker completion alone does not advance
- deterministic FAIL produces FailureRecord
- decision = repair
- artifact/evidence delta after repair
- re-verification occurs
- PASS + PR convergence conditions yield MERGE_READY
- no C-4/merge side effect

Path B asserts:

- equivalent repeated failure alone is not enough unless progress comparator says no meaningful delta
- comparator sees failure/evidence/artifact delta
- decision = stop
- Stop Reason = NO_PROGRESS
- finite termination
- outcome uses existing taxonomy

### Stage 5 — Review / release of #1381 gate

- I0 self-review
- I1+ independent review
- exact reviewed_at_sha
- CI green
- evidence link to #870
- explicit gate-release verdict to #1381

## Test-first plan

### Contract tests

- unknown lifecycle/state/outcome mixing => reject
- VerificationResult unavailable/inconclusive => cannot be treated as PASS
- deterministic FAIL cannot be overridden by model reviewer PASS
- missing harness_manifest_ref => invalid/inconclusive
- run harness ref changes mid-run => fail
- worker says complete, verifier missing => no advance

### Repair convergence mutation tests

Kill mutants:

1. skip re-verification after repair
2. ignore deterministic FAIL
3. generate MERGE_READY from worker self-report
4. reuse stale VerificationResult after artifact change
5. allow repair outside allowed scope
6. auto-merge after MERGE_READY

### No-progress mutation tests

Kill mutants:

1. retry-count-only stop
2. identical FailureRecord but changed artifact/evidence incorrectly treated as no progress
3. no artifact/evidence/failure change incorrectly treated as progress
4. NO_PROGRESS stored as Lifecycle State
5. stop without evidence refs
6. endless loop when budget exhausted

## Files in planning PR

- `docs/working/TASK-1383/pbi-input.md`
- `docs/working/TASK-1383/dependency-matrix.md`
- `docs/working/TASK-1383/plan.md`
- `docs/working/TASK-1383/test-cases.md`
- `docs/working/TASK-1383/todo.md`

## Runtime implementation preconditions

1. Gate A complete
2. #1329 M-1/M-2/M-3 base measurement
3. semantic invalidation review
4. implementation branch based on latest main
5. no conflicting owner contract change in flight

## Replan triggers

- #1025 changes V2 RunState field ownership
- #894 changes Decision Engine action or progress semantics
- #874/#1285 changes RunEvidence projection ownership
- #1329 changes implementation invalidation procedure
- #870 changes Delivery first release boundary
- implementation requires a new top-level artifact

## Stop conditions

- owner contract must be duplicated inside #1383
- Delivery integration requires changing ai-dev public contract
- Legacy ai-loop must become runtime authority
- Candidate/Evolution logic becomes necessary
- Human C-4 / merge authority must change
