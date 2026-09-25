# TEST CASES — TASK-1393 / #1393

> Revision 2 (2026-09-25), matching plan Revision 2. IDs are new; Revision 1 IDs are not reused.
>
> Revision 2.1 (2026-09-25), matching plan Revision 2.1: contract boundary (`contract_bound_seq`), derived `evidence_delta` (`artifact_verdicts`), FR order (I-7). Stream-side cases moved to #1422 are listed under Integration cases.
>
> Revision 2.3 (2026-09-25), matching plan Revision 2.3: convergence field domains (R-056), `MAX_INPUT_REFS` (R-062), progress events not read (R-066).
>
> Revision 2.2 (2026-09-25), matching plan Revision 2.2: asymmetric contract boundary (R-047), event-bound policy / convergence (R-048), effective FR (R-054), `previous_decision` base point (R-052), seq uniqueness and `contract_bound_seq >= 1` (R-050 / R-051), explicit `input_last_event_seq` (R-053).

Notation: `required = {D}` means `required_verifiers = {(D, deterministic)}`. "fresh" = bound to `current_artifact_ref` with `observed_seq > contract_bound_seq` (a single bound result unless a history with seq is given), "stale" = bound to the previous artifact. `contract_bound_seq = 1`, every other seq > 1, and `input_last_event_seq` = the highest seq in the case unless stated. The verdict of a verifier uses all its bound results (plan "artifact verdict": any FAIL -> fail, else any PASS -> pass, else unavailable). Expected values are exact: `action (-> derived transition)`, `stop / outcome / [stop_reasons]`, or `DecisionInputError` (raised by `make_decision_input` unless marked "decide"). Policy = none unless stated.

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
| DI-31 | input_last_event_seq lower than the observed_seq of a FailureRecord | `DecisionInputError` |
| DI-32 | DIAGNOSING entered on D FAIL (seq 10, FR on seq 10); a CI re-run records D FAIL (seq 30); input still carries the FR on seq 10 | `DecisionInputError` (re-diagnosis required; #1395 records a new FR for seq 30) |
| DI-33 | contract_bound_seq >= input_last_event_seq | `DecisionInputError` |
| DI-34 | contract_bound_seq = 0 / negative / not an integer | `DecisionInputError` |
| DI-35 | DIAGNOSING, latest D FAIL at seq 20, its FR at observed_seq 15 | `DecisionInputError` (FR must be recorded after the FAIL) |
| DI-37 | DIAGNOSING, contract_bound_seq = 50, D FAIL on T at seq 40 (crosses the boundary), its only FR at seq 45 (previous contract), input_last_event_seq = 70 | `DecisionInputError` (FR must be recorded under the current contract) |
| DI-38 | an FR and a result share an observed_seq (FR seq 20 == D FAIL seq 20) | `DecisionInputError` (I-5) |
| DI-39 | contract_bound_seq = 50 and a D result at seq 50 | `DecisionInputError` (I-5) |
| DI-40 | `make_policy_verdict` without event_ref or observed_seq | raises |
| DI-41 | PR_CONVERGING, contract_bound_seq = 50, pr_convergence observed_seq = 45 on the current artifact, input_last_event_seq = 70 | `DecisionInputError` (P-2) |
| DI-42 | a policy verdict whose observed_seq > input_last_event_seq | `DecisionInputError` (I-9) |
| DI-36 | DIAGNOSING, ProgressAssessment whose current_verdicts = {D: pass} while the input gives D verdict fail | `DecisionInputError` (P-3) |
| DI-43 | results + FailureRecords + policy verdicts = `MAX_INPUT_REFS` + 1 | `DecisionInputError` (I-11); exactly `MAX_INPUT_REFS` is accepted |
| DI-12 | policy verdict `ALLOW` / unknown | `DecisionInputError` |
| DI-13 | DIAGNOSING, FR whose verification_ref points to a stale D FAIL (plus a fresh D FAIL with its own FR) | `DecisionInputError` |
| DI-14 | DIAGNOSING, FR pointing to a non-required verifier's FAIL | `DecisionInputError` |
| DI-15 | retired in Revision 2.2 (several FRs for one FAIL are valid; see DD-14 / DD-15) | — |
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
| DV-20 | D FAIL bound to tree T (commit c1); an empty commit c2 has the same tree T; current_artifact_ref = T; D PASS recorded on T via c2 | repair (-> DIAGNOSING); the empty commit does not release the sticky FAIL |
| DV-19 | D on the current artifact: unavailable (seq 10) then inconclusive (seq 20) | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DV-21 | contract_bound_seq = 50, input_last_event_seq = 70; D PASS on tree T at seq 40 (previous contract); revert brings current_artifact_ref back to T; no D result after seq 50 | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] |
| DV-22 | R-047: contract_bound_seq = 50, input_last_event_seq = 70; on T: D FAIL at seq 40 (previous contract), Replan left the tree at T, flaky D PASS at seq 60 | repair (-> DIAGNOSING); the FAIL crosses the boundary |
| DV-23 | contract_bound_seq = 50, input_last_event_seq = 70; D unavailable on T at seq 40, D PASS at seq 60 | continue (-> PR_CONVERGING) |

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
| DD-13 | as DD-10 but the "repair" was an empty commit (commit SHA changed, tree unchanged): previous_decision artifact = T, current_artifact_ref = T | stop / HUMAN_ESCALATED / [NO_PROGRESS] |
| DD-10 | history on artifact A: D FAIL (seq 10, FR f1) -> repair left A unchanged -> D FAIL (seq 20, FR f2, same fingerprint); inputs = both results, FR f2, `assess_progress(previous_decision = the DIAGNOSING decision_made that used f1 (fingerprints {fp}, artifact A, verdicts {D: fail}), current_records=[f2], current_artifact_ref=A, current_verdicts={D: fail})` | stop / HUMAN_ESCALATED / [NO_PROGRESS] |
| DD-14 | D FAIL at seq 10; FRs for it at seq 12 (replan_required) and seq 14 (repairable) | repair (-> REPAIRING); the effective FR is seq 14 |
| DD-15 | as DD-14 with repairability swapped (seq 12 repairable, seq 14 replan_required) | replan (-> REPLANNING) |
| DD-16 | contract_bound_seq = 50, input_last_event_seq = 70; D FAIL on T at seq 40 (crossed the boundary), FR at seq 55 repairable | repair (-> REPAIRING) |

## DP — PR_CONVERGING (convergence = all pass unless stated)

| ID | Input | Expected |
|---|---|---|
| DP-01 | fresh D PASS | stop / MERGE_READY / [] |
| DP-02 | fresh D PASS, conflict=true | continue (no transition) |
| DP-03 | fresh D PASS, exactly one field not passing: ci = `fail`, ci = `pending`, required_reviews = `unsatisfied`, blocking_threads = 1, scope = `fail` (5 cases) | continue (no transition) |
| DP-16 | pr_convergence with ci = `green` / required_reviews = 2 / blocking_threads = -1 / scope = `ok` (4 cases) | `DecisionInputError` |
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
| DP-14 | R-042: contract_bound_seq = 50 (Replan re-bound the contract), input_last_event_seq = 70; D PASS on tree T at seq 40; revert brings current_artifact_ref back to T; convergence (seq 65) all pass; no D result after seq 50 | stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE]; never MERGE_READY |
| DP-15 | R-047: contract_bound_seq = 50, input_last_event_seq = 70; on T: D FAIL at seq 40, flaky D PASS at seq 60, FR at seq 62 repairable, FIRST_ITERATION, convergence (seq 65) all pass | repair (-> REPAIRING); never MERGE_READY |

## PR — assess_progress

| ID | Input (previous_decision: fingerprints {fp}, artifact A, verdicts {D: fail}; current: 1 FR with fingerprint fp, artifact A, verdicts {D: fail}; empty blocker sets unless stated) | Expected no_progress |
|---|---|---|
| PR-01 | same fingerprint | true |
| PR-02 | previous_decision artifact != current_artifact_ref | false |
| PR-03 | previous verdicts {D: pass}, current {D: fail} | false |
| PR-04 | resolved_blockers non-empty | false |
| PR-05 | introduced_blockers non-empty | false |
| PR-06 | different fingerprint | false |
| PR-07 | previous {f1, f2}, current {f1} | false |
| PR-08 | previous {f1, f2}, current {f2, f1} | true |
| PR-09 | `make_previous_decision` with an empty fingerprint set | raises (use FIRST_ITERATION) |
| PR-10 | same fingerprint, same artifact; previous verdicts = {D: fail}; current results on the artifact = D FAIL (seq 10), D PASS (seq 20); current_verdicts = `artifact_verdicts(...)` of those results | true (verdict stays fail, so evidence_delta is empty) |
| PR-11 | same fingerprint, same artifact; previous verdicts = {D: unavailable}, current_verdicts = {D: fail} | false |
| PR-12 | previous verdict map empty (`make_previous_decision` raises) / current_verdicts empty (`assess_progress` raises) | raises |
| PR-13 | same fingerprint, same artifact; previous verdicts = {D: fail}, current_verdicts = {D: fail, E: pass} | false (E present in one map only) |
| PR-14 | `make_previous_decision` from a decision_made with decided_in_state = VERIFYING | raises |
| PR-15 | `make_previous_decision` with a verdict value outside pass / fail / unavailable | raises |
| AV-01 | `artifact_verdicts`, contract_bound_seq = 50: D PASS at seq 49 only | {D: unavailable} |
| AV-02 | contract_bound_seq = 50: D PASS at seq 51 only | {D: pass} |
| AV-03 | contract_bound_seq = 50: D FAIL at seq 49, D PASS at seq 51 | {D: fail} |

## DC — Decision / EventDraft / boundaries

| ID | Input | Expected |
|---|---|---|
| DC-01 | construct Decision with outcome=HUMAN_REJECTED | rejected |
| DC-02 | construct Decision HUMAN_ESCALATED + [HUMAN_REJECTED] | valid |
| DC-03 | construct Decision action=repair + outcome non-null | rejected |
| DC-04 | construct Decision (DIAGNOSING, continue) / (VERIFYING, replan) / (PR_CONVERGING, replan) | rejected |
| DC-05 | construct Decision MERGE_READY with a Stop Reason | rejected |
| DC-06 | decision_to_event_draft | #1391 accepts; payload carries every field listed in plan "APIs" (decided_in_state, action, outcome, stop_reasons, policy_verdicts, loop_contract_ref, required_verifiers, required result (verification_ref, observed_seq), pr_convergence.observed_artifact_ref, progress kind and fingerprint sets, input_refs, contract_bound_seq, artifact_verdicts, FR observed_seq and the effective FR per FAIL, policy verdict event_refs, pr_convergence event_ref, current_artifact_ref, current fingerprint set, previous_decision_ref) |
| DC-07 | Worker "done" / fixture outcome / fixture no_progress as input; constructing ProgressAssessment directly | no API parameter accepts them; ProgressAssessment has no public constructor |
| DC-08 | `decide` called with anything other than a DecisionInput | `TypeError` |
| DC-09 | no os / subprocess / network / time / fs / #1392 storage / merge / GitHub imports | static PASS |
| DC-10 | full repository suite | PASS |
| DC-11 | a `progress_assessed` event with `no_progress=true` and a `repair_attempted` event with empty `evidence_delta` exist in the stream; the DecisionInput is built with `assess_progress` giving `no_progress=false` | decision follows `assess_progress` (no API reads the event values) |
| DC-12 | DC-09 positive control: plant a forbidden import (e.g. `subprocess`) in a copy of the module | the static boundary check fails |

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
- FR attached to an older FAIL accepted (DI-28, DI-32)
- artifact identity by commit SHA instead of tree hash (DV-20, DD-13)
- same-artifact verdict-neutral result counted as evidence delta (PR-10)
- FailureRecord seq not bounded by input_last_event_seq (DI-31)
- pr_convergence head not checked (DI-27)
- contract boundary ignored for PASS (DV-21, DP-14, AV-01) / applied to FAIL (DV-22, DP-15, AV-03). An inclusive boundary (`>=`) is an equivalent mutant because I-5 forbids a result at `contract_bound_seq` (DI-39)
- effective FR taken from the lowest seq or the first given (DD-14, DD-15)
- seq uniqueness checked only within results (DI-38, DI-39)
- `contract_bound_seq = 0` accepted (DI-34)
- FR under the previous contract accepted (DI-37)
- pr_convergence under the previous contract accepted (DI-41)
- previous_decision from another state or with unknown verdicts accepted (PR-14, PR-15)
- evidence_delta taken from the latest result instead of the verdict (PR-10) / verifier missing from one map ignored (PR-13)
- FR recorded before its FAIL accepted (DI-35)
- ProgressAssessment verdicts not checked against the input (DI-36)

## Integration cases (owned outside #1393, listed so the Trust boundary is testable)

| ID | Owner | Case | Expected |
|---|---|---|---|
| IT-01 | #1422 B-4 (#1392) | commit `decision_made` with decided_in_state=VERIFYING while the snapshot is DIAGNOSING | reject, zero mutation |
| IT-02 | #1422 B-5 (#1392) | non-terminal `decision_made` (VERIFYING, repair) with transition VERIFYING -> PR_CONVERGING | reject |
| IT-03 | #1422 B-6 (#1391) | recorded required_verifiers differ from the set bound by `plan_contract_bound` | reject |
| IT-04 | #1422 B-3 (#1392) | commit a `decision_made` whose input_last_event_seq + 1 is not its assigned event_seq because another writer recorded a FAIL after the input was built | reject, zero mutation |
| IT-07 | #1422 B-3 (#1392) | one transaction = [verification_recorded FAIL, decision_made(MERGE_READY, input_last_event_seq = seq before that FAIL)] | reject, zero mutation (the FAIL sits between input and Decision) |
| IT-08 | #1422 B-3 (#1392 load, #1391 stream validation) | a stored stream with a decision_made whose event_seq != input_last_event_seq + 1 | load rejects the stream |
| IT-09 | #1395 | FR built from Diagnoser output without an accepted failure_recorded event | not possible: FR constructor requires event_ref / observed_seq of an accepted event |
| IT-06 | audit | recompute a committed Decision from the stream prefix up to its input_last_event_seq | equal to the recorded Decision |
| IT-05 | #1422 B-10 | FIRST_ITERATION after an earlier DIAGNOSING or PR_CONVERGING decision with an FR in the same Run | reject |
| IT-10 | #1422 B-2 | a decision_made whose contract_bound_seq is not the event_seq of the latest plan_contract_bound before it | reject |
| IT-11 | #1422 B-9 | a decision_made whose FR refs omit the latest failure_recorded for a latest FAIL | reject |
| IT-13 | #1422 B-8 | a decision_made with no DENIED ref while the Run has a DENIED policy event | reject |
| IT-14 | #1422 B-9 | a decision_made whose result refs omit a verification_recorded on the current artifact up to input_last_event_seq | reject |
| IT-15 | #1422 B-10 | previous_decision_ref is not the latest base-point decision_made | reject |
| IT-12 | #1422 B-3 | one transaction with two decision_made | reject |
