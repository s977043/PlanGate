# TEST CASES — TASK-1393 / #1393

> Revision 2 (2026-09-25), matching plan Revision 2. IDs are new; Revision 1 IDs are not reused.

Notation: `required = {D}` means `required_verifiers = {(D, deterministic)}`. "fresh" = bound to `current_artifact_ref` (a single bound result unless a history with seq is given), "stale" = bound to the previous artifact. The verdict of a verifier uses all its bound results (plan "artifact verdict": any FAIL -> fail, else any PASS -> pass, else unavailable). Expected values are exact: `action (-> derived transition)`, `stop / outcome / [stop_reasons]`, or `DecisionInputError` (raised by `make_decision_input` unless marked "decide"). Policy = none unless stated.

## DI — DecisionInput validation (`make_decision_input`)

| ID | Input | Expected |
|---|---|---|
| DI-01 | lifecycle_state = PLAN_VERIFYING | `DecisionInputError` |
| DI-02 | lifecycle_state = PLANNING / EXECUTING / REPAIRING / REPLANNING (4 cases) | `DecisionInputError` |
| DI-03 | lifecycle_state = WAITING_HUMAN / WAITING_EXTERNAL, with a fresh D FAIL and a repairable FR | `DecisionInputError` |
| DI-04 | lifecycle_state = MERGE_READY (Outcome name) / unknown string | `DecisionInputError` |
| DI-05 | current_artifact_ref empty | `DecisionInputError` |
| DI-06 | required_verifiers empty | `DecisionInputError` |
| DI-07 | required = {(M, independent_model)} only | `DecisionInputError` |
| DI-08 | required = {D, (S, specification)} | `DecisionInputError` |
| DI-09 | required = {(D, deterministic)} and results contain (D, independent_model) | `DecisionInputError` |
| DI-10 | two results for D bound to the current artifact with the same observed_seq | `DecisionInputError` |
| DI-11 | loop_contract_ref empty | `DecisionInputError` |
| DI-27 | PR_CONVERGING, pr_convergence.observed_artifact_ref != current_artifact_ref | `DecisionInputError` |
| DI-28 | DIAGNOSING, FR pointing to an older D FAIL (seq 10) on the same artifact while the latest D FAIL is seq 20 | `DecisionInputError` |
| DI-29 | two results share a verification_ref | `DecisionInputError` |
| DI-30 | input_last_event_seq lower than the highest observed_seq of the results | `DecisionInputError` |
| DI-12 | policy verdict `ALLOW` / unknown | `DecisionInputError` |
| DI-13 | DIAGNOSING, FR whose verification_ref points to a stale D FAIL (plus a fresh D FAIL with its own FR) | `DecisionInputError` |
| DI-14 | DIAGNOSING, FR pointing to a non-required verifier's FAIL | `DecisionInputError` |
| DI-15 | DIAGNOSING, two FRs for the same fresh D FAIL | `DecisionInputError` |
| DI-16 | VERIFYING with any FR | `DecisionInputError` |
| DI-17 | VERIFYING with progress or pr_convergence set | `DecisionInputError` |
| DI-18 | DIAGNOSING with no required FAIL (fresh D PASS only) | `DecisionInputError` |
| DI-19 | DIAGNOSING, fresh D FAIL without FR | `DecisionInputError` |
| DI-20 | DIAGNOSING, progress = None | `DecisionInputError` |
| DI-21 | DIAGNOSING, ProgressAssessment with a different current_artifact_ref | `DecisionInputError` |
| DI-22 | DIAGNOSING, ProgressAssessment whose current_failure_refs differ from the FRs passed | `DecisionInputError` |
| DI-23 | PR_CONVERGING, pr_convergence = None | `DecisionInputError` |
| DI-24 | PR_CONVERGING, fresh D FAIL, FR present, progress = None | `DecisionInputError` |
| DI-25 | PR_CONVERGING, fresh D PASS, an FR passed | `DecisionInputError` |
| DI-26 | FailureRecord with unknown repairability | `make_failure_record` raises |

## DV — VERIFYING

| ID | Input (required = {D} unless stated) | Expected |
|---|---|---|
| DV-01 | fresh D PASS | continue (-> PR_CONVERGING) |
| DV-02 | fresh D FAIL, no FR | repair (-> DIAGNOSING) |
| DV-03 | fresh D FAIL + fresh model PASS (non-required) | repair (-> DIAGNOSING) |
| DV-04 | fresh D unavailable | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DV-05 | fresh D inconclusive | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DV-06 | D has only a stale PASS | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DV-07 | D has only a stale FAIL | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DV-08 | required = {D, E}, fresh D PASS, E has only a stale FAIL | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DV-09 | required = {D, E}, fresh D FAIL, E missing | repair (-> DIAGNOSING) |
| DV-10 | fresh D PASS + policy DENIED | stop / BLOCKED / [POLICY_DENIED] |
| DV-11 | fresh D PASS + policy HUMAN_REQUIRED | decide raises `DecisionInputError` |
| DV-12 | fresh D PASS + policy {HUMAN_REQUIRED, DENIED} | stop / BLOCKED / [POLICY_DENIED] |
| DV-13 | fresh D FAIL + policy DENIED | repair (-> DIAGNOSING) |
| DV-14 | fresh D unavailable + policy DENIED | stop / BLOCKED / [VERIFIER_UNAVAILABLE, POLICY_DENIED] |
| DV-15 | fresh D PASS + policy AUTO_APPROVED | continue (-> PR_CONVERGING) |
| DV-16 | D on the current artifact: FAIL (seq 10) then FAIL (seq 20), i.e. the repair did not change the artifact | repair (-> DIAGNOSING); no error |
| DV-17 | D on the current artifact: FAIL (seq 10) then PASS (seq 20) (flaky re-run) | repair (-> DIAGNOSING); FAIL is sticky |
| DV-18 | D on the current artifact: PASS (seq 10) then unavailable (seq 20) | continue (-> PR_CONVERGING) |
| DV-19 | D on the current artifact: unavailable (seq 10) then inconclusive (seq 20) | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |

## DD — DIAGNOSING (progress = FIRST_ITERATION unless stated)

| ID | Input | Expected |
|---|---|---|
| DD-01 | fresh D FAIL + repairable FR | repair (-> REPAIRING) |
| DD-02 | fresh D FAIL + replan_required FR | replan (-> REPLANNING) |
| DD-03 | required = {D, E}, fresh D FAIL repairable + fresh E FAIL replan_required | replan (-> REPLANNING) |
| DD-04 | fresh D FAIL + repairable FR, ProgressAssessment no_progress=true | stop / HUMAN_ESCALATED / [NO_PROGRESS] |
| DD-05 | as DD-04 + policy DENIED | stop / BLOCKED / [NO_PROGRESS, POLICY_DENIED] |
| DD-06 | as DD-04 + policy HUMAN_REQUIRED | stop / HUMAN_ESCALATED / [NO_PROGRESS] |
| DD-07 | fresh D FAIL + repairable FR + policy HUMAN_REQUIRED | repair (-> REPAIRING) |
| DD-08 | fresh D FAIL + repairable FR + policy DENIED | repair (-> REPAIRING) |
| DD-09 | ProgressAssessment no_progress=false | repair (-> REPAIRING) |
| DD-11 | entered on D FAIL (seq 10, FR on seq 10); a CI re-run on the same artifact records D PASS (seq 30) | repair (-> REPAIRING); no `DecisionInputError` |
| DD-12 | entered on D FAIL (seq 10, FR on seq 10); then D unavailable (seq 30) | repair (-> REPAIRING) |
| DD-10 | history on artifact A: D FAIL (seq 10, FR f1) -> repair left A unchanged -> D FAIL (seq 20, FR f2, same fingerprint); inputs = both results, FR f2, `assess_progress(previous=[f1], current=[f2], previous_artifact_ref=A, current_artifact_ref=A)` | stop / HUMAN_ESCALATED / [NO_PROGRESS] |

## DP — PR_CONVERGING (convergence = all pass unless stated)

| ID | Input | Expected |
|---|---|---|
| DP-01 | fresh D PASS | stop / MERGE_READY / [] |
| DP-02 | fresh D PASS, conflict=true | continue (no transition) |
| DP-03 | fresh D PASS, one of ci / required_reviews / blocking_threads / scope fails (4 cases) | continue (no transition) |
| DP-04 | D has only a stale PASS | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DP-05 | fresh D inconclusive | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DP-06 | required = {D, E}, fresh D PASS, E only stale FAIL | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DP-07 | fresh D FAIL + repairable FR + FIRST_ITERATION | repair (-> REPAIRING) |
| DP-08 | fresh D FAIL + replan_required FR + FIRST_ITERATION | decide raises `DecisionInputError` |
| DP-09 | fresh D PASS + fresh model FAIL (non-required) | stop / MERGE_READY / [] |
| DP-10 | fresh D PASS + policy DENIED | stop / BLOCKED / [POLICY_DENIED] |
| DP-11 | fresh D PASS + policy {HUMAN_REQUIRED, DENIED} | stop / BLOCKED / [POLICY_DENIED] |
| DP-12 | fresh D PASS + policy AUTO_APPROVED | stop / MERGE_READY / [] |
| DP-13 | D on the current artifact: PASS (seq 10) then FAIL (seq 20, CI re-run) + repairable FR + FIRST_ITERATION | repair (-> REPAIRING); never MERGE_READY |

## PR — assess_progress

| ID | Input (previous and current each 1 FR, same artifact, empty deltas unless stated) | Expected no_progress |
|---|---|---|
| PR-01 | same fingerprint | true |
| PR-02 | previous_artifact_ref != current_artifact_ref | false |
| PR-03 | evidence_delta non-empty | false |
| PR-04 | resolved_blockers non-empty | false |
| PR-05 | introduced_blockers non-empty | false |
| PR-06 | different fingerprint | false |
| PR-07 | previous {f1, f2}, current {f1} | false |
| PR-08 | previous {f1, f2}, current {f2, f1} | true |
| PR-09 | previous records empty | `assess_progress` raises (use FIRST_ITERATION) |

## DC — Decision / EventDraft / boundaries

| ID | Input | Expected |
|---|---|---|
| DC-01 | construct Decision with outcome=HUMAN_REJECTED | rejected |
| DC-02 | construct Decision HUMAN_ESCALATED + [HUMAN_REJECTED] | valid |
| DC-03 | construct Decision action=repair + outcome non-null | rejected |
| DC-04 | construct Decision (DIAGNOSING, continue) / (VERIFYING, replan) / (PR_CONVERGING, replan) | rejected |
| DC-05 | construct Decision MERGE_READY with a Stop Reason | rejected |
| DC-06 | decision_to_event_draft | #1391 accepts; payload carries every field listed in plan "APIs" (decided_in_state, action, outcome, stop_reasons, policy_verdicts, loop_contract_ref, required_verifiers, required result (verification_ref, observed_seq), pr_convergence.observed_artifact_ref, progress kind and fingerprint sets, input_refs) |
| DC-07 | Worker "done" / fixture outcome / fixture no_progress as input; constructing ProgressAssessment directly | no API parameter accepts them; ProgressAssessment has no public constructor |
| DC-08 | `decide` called with anything other than a DecisionInput | `TypeError` |
| DC-09 | no os / subprocess / network / time / fs / #1392 storage / merge / GitHub imports | static PASS |
| DC-10 | full repository suite | PASS |

## Mutation targets

Each mutant must be killed by at least one case above.

- model PASS decides instead of the required deterministic FAIL (DV-03)
- inconclusive treated as PASS (DV-05, DP-05)
- freshness ignored on the PASS side (DV-06, DP-04) / on the FAIL side (DV-07, DI-13)
- freshness judged per result instead of per required verifier (DV-08, DP-06)
- required_verifiers accepts a non-deterministic kind (DI-07, DI-08)
- default fall-through returns continue or MERGE_READY (DV-08 with step 3 removed)
- DENIED evaluated before the required FAIL (DV-13, DD-08)
- HUMAN_REQUIRED evaluated before DENIED (DV-12, DP-11)
- POLICY_DENIED dropped on a step 1 / 3 stop (DD-05, DV-14)
- repair chosen when any FR is replan_required (DD-03)
- FR required in VERIFYING (DV-02) / not required in DIAGNOSING (DI-19)
- progress omission accepted (DI-20, DI-24)
- stale ProgressAssessment accepted (DI-21, DI-22)
- NO_PROGRESS derived from a retry count or ignoring introduced blockers (PR-05)
- fingerprint compared as a list instead of a set (PR-08)
- MERGE_READY without convergence (DP-02, DP-03)
- WAITING_* accepted (DI-03)
- verdict taken from the latest result instead of "any FAIL" (DV-17, DD-11, DP-13)
- unavailable erases a PASS or a FAIL (DV-18, DD-12)
- FR attached to an older FAIL accepted (DI-28)
- pr_convergence head not checked (DI-27)

## Integration cases (owned outside #1393, listed so the Trust boundary is testable)

| ID | Owner | Case | Expected |
|---|---|---|---|
| IT-01 | #1392 | commit `decision_made` with decided_in_state=VERIFYING while the snapshot is DIAGNOSING | reject, zero mutation |
| IT-02 | #1392 | non-terminal `decision_made` (VERIFYING, repair) with transition VERIFYING -> PR_CONVERGING | reject |
| IT-03 | #1391 (dependency, unowned today) | recorded required_verifiers differ from the set bound by `plan_contract_bound` | reject |
| IT-04 | #1392 | commit a `decision_made` whose input_last_event_seq is lower than the stream's last event_seq (a FAIL was recorded after the input was built) | reject, zero mutation |
| IT-06 | audit | recompute a committed Decision from the stream prefix up to its input_last_event_seq | equal to the recorded Decision |
| IT-05 | #1395 / #1391 | FIRST_ITERATION after an earlier DIAGNOSING decision with a FAIL in the same Run | reject |
