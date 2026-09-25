# TEST CASES — TASK-1393 / #1393

Expected values name the exact result: `action / next_state` for a non-stop Decision, `stop / outcome / [stop_reasons]` for a stop, or `DecisionInputError`. "fresh" = bound to `current_artifact_ref`. Unless stated, `required_verifiers` = {D (deterministic)} and policy = none.

| ID | Condition | Expected |
|---|---|---|
| DC-01 | PLAN_VERIFYING, required = {S (specification)}, fresh S PASS | continue / EXECUTING |
| DC-01a | VERIFYING, required = {D}, only a fresh specification PASS (D has no result) | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DC-01b | lifecycle_state = WAITING_HUMAN or WAITING_EXTERNAL, with fresh D FAIL + repairable FailureRecord | `DecisionInputError` |
| DC-01c | lifecycle_state = EXECUTING / REPAIRING / REPLANNING / PLANNING | `DecisionInputError` |
| DC-01d | lifecycle_state = MERGE_READY (Outcome name as state) or unknown string | `DecisionInputError` |
| DC-01e | PLAN_VERIFYING, fresh S FAIL | replan / REPLANNING |
| DC-02 | DIAGNOSING, fresh D FAIL + fresh model PASS + repairable FailureRecord | repair / REPAIRING |
| DC-02a | VERIFYING, fresh D FAIL, no FailureRecord | continue / DIAGNOSING |
| DC-03 | DIAGNOSING or PR_CONVERGING, fresh D FAIL, no FailureRecord with matching `verification_ref` | `DecisionInputError` |
| DC-03a | DIAGNOSING, D has only a stale FAIL (bound to previous artifact) + FailureRecord | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DC-03b | VERIFYING, stale D FAIL + fresh D PASS | continue / PR_CONVERGING |
| DC-03c | PR_CONVERGING, required = {D, E}, fresh D PASS, E has only a stale FAIL, convergence all pass | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DC-04 | DIAGNOSING, fresh D FAIL + replan_required FailureRecord | replan / REPLANNING |
| DC-04a | FailureRecord with unknown repairability | `make_failure_record` raises (value error) |
| DC-04b | DIAGNOSING, required = {D, E}, fresh D FAIL (repairable) + fresh E FAIL (replan_required) | replan / REPLANNING |
| DC-04c | PR_CONVERGING, fresh D FAIL + replan_required FailureRecord | `DecisionInputError` |
| DC-04d | same verifier_id D has a fresh PASS and a fresh FAIL | `DecisionInputError` |
| DC-04e | `required_verifiers` empty | `DecisionInputError` |
| DC-05 | VERIFYING, fresh D unavailable | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DC-06 | PR_CONVERGING, fresh D inconclusive, convergence all pass | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DC-07 | PR_CONVERGING, fresh D PASS, convergence not all pass | continue / null |
| DC-07a | VERIFYING, fresh D PASS | continue / PR_CONVERGING |
| DC-08 | PR_CONVERGING, fresh D PASS, convergence all pass | stop / MERGE_READY / [] |
| DC-08a | VERIFYING, fresh D PASS, convergence all pass | continue / PR_CONVERGING (MERGE_READY only in PR_CONVERGING) |
| DC-09 | PR_CONVERGING, D has only a stale PASS, convergence all pass | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DC-10 | same fingerprint / no deltas | `assess_progress` -> no_progress=true; decide -> stop / HUMAN_ESCALATED / [NO_PROGRESS] |
| DC-11 | artifact_changed=true, rest as DC-10 | no_progress=false |
| DC-12 | evidence_delta nonempty, rest as DC-10 | no_progress=false |
| DC-13 | resolved blocker nonempty, rest as DC-10 | no_progress=false |
| DC-14 | introduced blocker nonempty, rest as DC-10 | no_progress=false |
| DC-15 | different fingerprint, rest as DC-10 | no_progress=false |
| DC-16 | NO_PROGRESS decision | action=stop, outcome=HUMAN_ESCALATED, stop_reasons=[NO_PROGRESS], next_state=null |
| DC-17 | MERGE_READY decision | stop_reasons=[] and next_state=null |
| DC-17a | constructing a Decision with outcome=HUMAN_REJECTED | rejected (not an Outcome) |
| DC-17b | Decision with HUMAN_ESCALATED + Stop Reason HUMAN_REJECTED | valid taxonomy |
| DC-17c | Decision with action=repair and outcome non-null, or next_state not an allowlist edge from lifecycle_state | rejected |
| DC-18 | decision EventDraft | #1391 accepts |
| DC-19 | Worker done input | API has no such authority input |
| DC-20 | fixture outcome/no_progress input | constructors reject/absent |
| DC-20a | PR_CONVERGING, fresh D PASS, convergence all pass, policy = AUTO_APPROVED | stop / MERGE_READY / [] (same as with no verdict) |
| DC-20b | PR_CONVERGING, fresh D PASS, convergence all pass, policy = DENIED | stop / BLOCKED / [POLICY_DENIED] |
| DC-20c | DIAGNOSING, policy = DENIED, fresh D FAIL + repairable FailureRecord | repair / REPAIRING |
| DC-20d | VERIFYING, fresh D PASS, policy = HUMAN_REQUIRED | `DecisionInputError` |
| DC-20e | policy = unknown value, including `ALLOW` | `DecisionInputError` |
| DC-20f | DIAGNOSING, policy = HUMAN_REQUIRED, fresh D FAIL + repairable FailureRecord | repair / REPAIRING |
| DC-20g | policy = HUMAN_REQUIRED, no-progress | stop / HUMAN_ESCALATED / [NO_PROGRESS] |
| DC-20h | policy = DENIED, no-progress | stop / BLOCKED / [NO_PROGRESS, POLICY_DENIED] |
| DC-20i | policy = DENIED, VERIFYING, fresh D unavailable | stop / BLOCKED / [VERIFIER_UNAVAILABLE, POLICY_DENIED] |
| DC-21 | no I/O/network/merge imports | static PASS |
| DC-22 | full repository suite | PASS |

## Mutation targets

- choose model PASS over deterministic FAIL
- treat inconclusive as PASS
- ignore artifact binding freshness (PASS side and FAIL side are separate mutants)
- decide freshness per result instead of per required verifier (DC-03c must kill it)
- fall through to continue / MERGE_READY when no step matches
- evaluate DENIED or HUMAN_REQUIRED before deterministic FAIL
- map DENIED to MERGE_READY-eligible / treat HUMAN_REQUIRED as normal evaluation
- drop POLICY_DENIED on a step 1 / 3 stop
- return a Decision instead of raising for a FAIL without FailureRecord in DIAGNOSING
- require a FailureRecord in VERIFYING
- choose repair when any FailureRecord is replan_required
- accept WAITING_* states
- derive NO_PROGRESS from retry count
- ignore introduced blockers
- allow MERGE_READY without convergence
- allow terminal Outcome with continue action
