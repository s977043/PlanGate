# EXECUTION PLAN — TASK-1393 / #1393

## Architecture

```text
observed verifier facts
 -> VerificationResult
 -> FailureRecord normalization input
 -> progress assessment
 -> decide(...)
 -> Decision value
 -> #1391 decision_made EventDraft
 -> #1392 durable commit
```

No I/O in #1393.

## Data types

### VerificationResult

Required:
- verification_ref
- verifier_id
- kind: deterministic | specification | independent_model | policy
- status: pass | fail | unavailable | inconclusive
- bound_artifact_ref
- evidence_refs

Optional:
- source_sha
- head_sha

Immutable value after construction.

### FailureRecord

Required:
- failure_ref
- observation
- fingerprint
- evidence_refs
- cause_hypothesis
- repairability
- result

Observation and cause hypothesis remain separate.

### ProgressAssessment

Derived by pure function from:
- previous FailureRecord
- current FailureRecord
- artifact_changed
- evidence_delta
- resolved_blockers
- introduced_blockers

`no_progress=true` only when:
- normalized fingerprint unchanged
- artifact_changed=false
- evidence_delta empty
- resolved_blockers empty
- introduced_blockers empty

No retry-count shortcut.

### Decision

- decision_ref
- action: continue | repair | replan | stop
- input_refs
- outcome: null | MERGE_READY | HUMAN_ESCALATED | HUMAN_REJECTED | BLOCKED
- stop_reasons
- policy_verdicts

Rules:
- outcome != null => action=stop
- MERGE_READY => stop_reasons=[]
- HUMAN_ESCALATED/BLOCKED => >=1 Stop Reason

## Decision order

Fail-closed priority:

1. policy denied / blocking policy -> stop according to existing Policy Verdict mapping (first slice only if provided by caller)
2. no-progress assessment -> stop / HUMAN_ESCALATED / NO_PROGRESS
3. deterministic VerificationResult FAIL:
   - repairable FailureRecord -> repair
   - otherwise -> replan
4. required deterministic/specification verifier unavailable or inconclusive -> stop / HUMAN_ESCALATED / VERIFIER_UNAVAILABLE
5. fresh deterministic PASS on current artifact + PR convergence PASS -> MERGE_READY
6. valid pass without convergence -> continue

An independent-model PASS never removes a deterministic FAIL from step 3.

## Freshness

Caller supplies `current_artifact_ref`.
Any verification used for completion must bind exactly to current_artifact_ref.

After repair changes artifact A -> B:
- PASS bound to A is stale
- only PASS bound to B may support MERGE_READY

## PR convergence input

Pure observed value:
- ci pass
- required_reviews pass
- blocking_threads=0
- conflict=false
- scope=pass

#1393 validates/consumes it but does not query GitHub or derive changed paths.

## APIs

```python
make_verification_result(...)
make_failure_record(...)
assess_progress(...)
decide(
  *,
  current_artifact_ref,
  verification_results,
  failure_records,
  progress=None,
  pr_convergence=None,
  policy_verdicts=(),
)
decision_to_event_draft(decision)
```

The final function creates a #1391 EventDraft but does not persist it.

## RED cases

- model PASS + deterministic FAIL
- inconclusive/unavailable -> no success
- stale PASS
- same failure + no deltas -> NO_PROGRESS
- changed artifact -> not NO_PROGRESS
- evidence delta -> not NO_PROGRESS
- introduced blocker -> not NO_PROGRESS
- missing FailureRecord for deterministic FAIL
- MERGE_READY without convergence
- convergence PASS but no fresh deterministic PASS
- Worker self-report field cannot enter API
- pre-authored outcome/no_progress cannot enter observation constructors

## Static boundaries

- no os/subprocess/network/time/fs
- no #1392 storage imports
- no merge API
- no GitHub API
