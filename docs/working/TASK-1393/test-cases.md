# TEST CASES — TASK-1393 / #1393

| ID | Condition | Expected |
|---|---|---|
| DC-01 | specification plan PASS | continue |
| DC-02 | deterministic FAIL + model PASS + repairable failure | repair |
| DC-03 | deterministic FAIL + no FailureRecord | fail closed / validation error |
| DC-04 | deterministic FAIL + repairability=replan_required | replan |
| DC-04a | unknown repairability | reject |
| DC-05 | unavailable deterministic verifier | HUMAN_ESCALATED / VERIFIER_UNAVAILABLE |
| DC-06 | inconclusive deterministic verifier | no MERGE_READY |
| DC-07 | fresh deterministic PASS, no convergence | continue |
| DC-08 | fresh PASS + convergence all pass | MERGE_READY |
| DC-09 | stale PASS + convergence pass | no MERGE_READY |
| DC-10 | same fingerprint/no deltas | NO_PROGRESS |
| DC-11 | artifact_changed=true | not NO_PROGRESS |
| DC-12 | evidence_delta nonempty | not NO_PROGRESS |
| DC-13 | resolved blocker nonempty | not NO_PROGRESS |
| DC-14 | introduced blocker nonempty | not NO_PROGRESS |
| DC-15 | different fingerprint | not NO_PROGRESS |
| DC-16 | NO_PROGRESS decision | stop + HUMAN_ESCALATED + reason |
| DC-17 | MERGE_READY | no Stop Reason |
| DC-18 | decision EventDraft | #1391 accepts |
| DC-19 | Worker done input | API has no such authority input |
| DC-20 | fixture outcome/no_progress input | constructors reject/absent |
| DC-20a | policy=ALLOW | normal evaluation |
| DC-20b | policy=DENIED/HUMAN_REQUIRED/unknown | fail closed; never MERGE_READY |
| DC-21 | no I/O/network/merge imports | static PASS |
| DC-22 | full repository suite | PASS |

## Mutation targets

- choose model PASS over deterministic FAIL
- treat inconclusive as PASS
- ignore artifact binding freshness
- derive NO_PROGRESS from retry count
- ignore introduced blockers
- allow MERGE_READY without convergence
- allow terminal Outcome with continue action
