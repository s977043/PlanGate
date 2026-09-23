# TEST CASES — TASK-1383 / #1383

## Contract readiness

| ID | Input / Condition | Expected |
|---|---|---|
| TC-01 | RunState without revision | contract not ready |
| TC-02 | RunState without harness_manifest_ref | contract not ready |
| TC-03 | VerificationResult status unavailable | not PASS |
| TC-04 | VerificationResult status inconclusive | not PASS |
| TC-05 | deterministic verifier FAIL + model PASS | FAIL remains blocking |
| TC-06 | FailureRecord mixes observation and cause | reject / owner contract mismatch |
| TC-07 | Decision Engine returns stop reason as state | reject |
| TC-08 | NO_PROGRESS based only on retry count | reject |
| TC-09 | Worker says complete but no verification evidence | cannot advance |
| TC-10 | RunEvidence requirement expands into full §18 metrics | not required by this E2E gate |

## Path A — Repair convergence

| ID | Step | Expected |
|---|---|---|
| TC-11 | start valid run | fixed contract/state/manifest refs |
| TC-12 | worker output exists | no completion yet |
| TC-13 | deterministic verify FAIL | VerificationResult FAIL |
| TC-14 | failure normalization | immutable FailureRecord |
| TC-15 | decision after reparable failure | repair |
| TC-16 | repair artifact changes | new artifact digest/evidence |
| TC-17 | old verification reused | rejected stale |
| TC-18 | verify after repair PASS | fresh PASS evidence |
| TC-19 | PR convergence incomplete | not MERGE_READY |
| TC-20 | all convergence conditions true | MERGE_READY |
| TC-21 | MERGE_READY reached | merge not executed |

## Path B — NO_PROGRESS

| ID | Condition | Expected |
|---|---|---|
| TC-22 | same failure + no artifact delta + no evidence delta | no-progress signal |
| TC-23 | same failure + meaningful artifact/evidence delta | not yet NO_PROGRESS |
| TC-24 | different normalized failure | not same-failure shortcut |
| TC-25 | progress comparator unavailable | fail closed / no success |
| TC-26 | threshold met | stop action |
| TC-27 | stop persisted | Stop Reason NO_PROGRESS |
| TC-28 | terminal projection | existing outcome only |
| TC-29 | repeated evaluation after stop | no loop continuation |

## Governance

| ID | Condition | Expected |
|---|---|---|
| TC-30 | runtime branch creates scripts/ai-loop-v2 | M-2 changed |
| TC-31 | semantic enforcement added | #1329 invalidation candidate |
| TC-32 | implementation PR edits canon 7 to keep I1 exception | invalid |
| TC-33 | Legacy scripts/ai-loop changed for new V2 feature | invalid absent Human freeze exception |


## Executable specification additions from review

| ID | Condition | Expected |
|---|---|---|
| TC-34 | Initial Plan Verification missing | reject before Execute |
| TC-35 | Plan Verification not bound to current plan_hash | reject |
| TC-36 | Plan Gate outcome set before Execute | reject |
| TC-37 | final deterministic verification = inconclusive | cannot reach MERGE_READY |
| TC-38 | fixture marks itself authoritative | reject |
| TC-39 | LoopContract contains runtime state/outcome | reject responsibility mixing |
| TC-40 | harness_manifest_ref changes in one event | reject |
| TC-41 | merge_executed event appears | reject |

TA-87 currently kills 10 mutation classes:
1. Initial Plan Verification skipped
2. Worker self-report completion
3. model PASS overriding deterministic FAIL
4. inconclusive treated as PASS
5. stale verification reuse
6. active-run Harness drift
7. auto merge side effect
8. retry-count-only NO_PROGRESS
9. NO_PROGRESS used as Lifecycle State
10. meaningful artifact delta mislabeled NO_PROGRESS
