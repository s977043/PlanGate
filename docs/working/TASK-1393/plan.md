# EXECUTION PLAN — TASK-1393 / #1393

> Revision 2 (2026-09-25). Rebuilt after adversarial review R3 did not converge. Human design decisions: validate a per-state DecisionInput in one place; accept only `VERIFYING` / `DIAGNOSING` / `PR_CONVERGING`; the Decision carries no `next_state` (#1392 derives the transition); `HUMAN_REQUIRED` is deferred to the waiting/resume slice; the iteration budget is a #1395 requirement. See `decision-log.jsonl` and `review-external.md`.
>
> Revision 2.1 (2026-09-25). Human decision after Rev2-R4: #1393 guarantees only that the Decision follows from the DecisionInput and that every rule checkable on the DecisionInput alone holds. Whether the DecisionInput faithfully reflects the stream (artifact identity, contract boundary, event order, FailureRecord selection) is the Decision Input Binding contract owned by #1422. R-042 / R-044 / R-045 are fixed here as pure rules; R-043 / R-046 move to #1422 (B-7 / B-3).
>
> Revision 2.2 (2026-09-25). Human ruling after Rev2-R5: R-047 is treated as the same class as R-037, so the round is converged with fix-omissions only; R-047〜R-054 are fixed here. A FAIL stays sticky across the contract boundary (R-047); policy verdicts and PR convergence are built from accepted events (R-048); the FailureRecord selection is a pure rule (R-054); every stream invariant this plan relies on is listed as a #1422 item (R-049).
>
> Revision 2.3 (2026-09-25). C-2 R1 (R-055〜R-069): convergence field types (R-056), exec preflight against the #1391 vocabulary as implemented in PR #1402 (R-058〜R-062), payload size bound (R-062), value-object mechanism (R-067). R-055 (DENIED + FAIL) and R-058 (relation to the #1402 `decision_core`) are open for Human decision.

## Architecture

```text
observed verifier facts
 -> VerificationResult / FailureRecord            (validated values)
 -> assess_progress(...)                          (derived value)
 -> make_decision_input(...)                      (all input rules, one place)
 -> decide(decision_input)                        (pure, no validation left)
 -> Decision value
 -> #1391 decision_made EventDraft
 -> #1392 durable commit (derives and checks the transition from the Decision)
```

No I/O in #1393. `decide()` accepts only a `DecisionInput`; it has no other parameters, so no input can bypass validation.

## Data types

### VerificationResult

Required:
- verification_ref
- verifier_id
- kind: deterministic | specification | independent_model | policy
- status: pass | fail | unavailable | inconclusive
- bound_artifact_ref
- event_ref and observed_seq: the #1391 canonical hash and `event_seq` of the accepted `verification_recorded` event this result was built from. A VerificationResult is built only from an accepted event (its `event_seq` is assigned by #1392 under the lock), never from a Worker report
- evidence_refs

Optional:
- source_sha
- head_sha

Immutable value after construction. A verifier is identified by the pair `(verifier_id, kind)` everywhere in this plan.

**Value objects (all types in this plan).** Frozen dataclasses whose collection fields are `tuple` / `frozenset` (mappings as `frozenset` of pairs), so no field can be mutated after construction. Types that must only come from a factory (`ProgressAssessment`, `DecisionInput`, `Decision`) take a module-private sentinel token as a required constructor argument; any other caller gets `TypeError` (DC-07). Every validation error is `DecisionInputError(ValueError)`, matching the existing `EventContractError` / `DecisionError` convention.

**Identifier mapping.** The #1391 events carry an `id`; this plan names it by role: `verification_ref` = the `id` of the verification in a `verification_recorded` event, `failure_ref` = the `id` of the failure in a `failure_recorded` event. `event_ref` is always the canonical hash of the whole event.

### FailureRecord

Required:
- failure_ref
- verification_ref (the deterministic FAIL this record normalizes)
- observation
- fingerprint
- evidence_refs
- cause_hypothesis
- repairability = `repairable | replan_required`
- result = `open | repeated | resolved`
- event_ref and observed_seq: the #1391 canonical hash and `event_seq` of the accepted `failure_recorded` event this record was built from. Like a VerificationResult, a FailureRecord is built only from an accepted event, never from Diagnoser output that has not been recorded

Several FailureRecords may exist for one FAIL (re-diagnosis). The **effective** FR of a FAIL is the one with the highest `observed_seq`; only it decides (I-7). The caller passes every accepted `failure_recorded` event for that FAIL; completeness is #1422 B-9.

Observation and cause hypothesis remain separate.
Unknown repairability/result values are rejected; free-form strings are not decision inputs.

### PolicyVerdict

`make_policy_verdict(*, verdict, event_ref, observed_seq)`: `verdict` is `AUTO_APPROVED | HUMAN_REQUIRED | DENIED` (taxonomy §5); `event_ref` / `observed_seq` identify the accepted event that recorded it. A verdict is built only from an accepted event. [Dependency] #1391 has no policy event in its first-slice vocabulary; until #1422 B-8 adds one, the first slice passes no policy verdicts (taxonomy: MERGE_READY does not require one). A `DENIED` anywhere in the Run must be passed (taxonomy §3: a denied Run restarts only as a new Run), so policy verdicts are **not** cut by the contract boundary; completeness is #1422 B-8.

### ProgressAssessment

`assess_progress(*, previous_decision, current_records, current_artifact_ref, current_verdicts, resolved_blockers, introduced_blockers)` returns an immutable value carrying:

- `current_artifact_ref`
- `current_failure_refs` (the set of `failure_ref` in `current_records`)
- `current_verdicts`
- `previous_decision_ref`
- `no_progress`

`previous_decision` is a `PreviousDecision` value built by `make_previous_decision(*, payload, event_ref, observed_seq)` from the **latest** accepted `decision_made` of the Run whose `decided_in_state` is `DIAGNOSING` or `PR_CONVERGING` and whose effective FR set is non-empty (the base point, R-052). All previous values come from that one payload: `previous_artifact_ref`, the previous fingerprint set, and `previous_verdicts`. `make_previous_decision` rejects a payload whose `decided_in_state` is another state, whose fingerprint set or verdict map is empty, or whose verdict values are outside `pass | fail | unavailable`. Whether it is really the latest such decision is #1422 B-10.

`previous_verdicts` / `current_verdicts` map each required verifier `(verifier_id, kind)` to its artifact verdict (`pass | fail | unavailable`, as returned by `artifact_verdicts`, see DecisionInput); values outside that domain are rejected. `current_verdicts` must equal the verdicts of the DecisionInput it is passed to (P-3).

`artifact_changed` and `evidence_delta` are derived, not supplied:
- `artifact_changed = previous_artifact_ref != current_artifact_ref`
- `evidence_delta` = the required verifiers whose verdict differs between `previous_verdicts` and `current_verdicts` (a verifier present in only one map counts as differing)

`current_records` and `current_verdicts` must be non-empty; otherwise `assess_progress` raises. A diagnosis with no earlier base point uses `FIRST_ITERATION`; whether no base point exists is #1422 B-10.

`no_progress=true` only when all hold:
- the previous fingerprint set equals the set of normalized fingerprints in `current_records` (both non-empty)
- `artifact_changed` is false
- `evidence_delta`, `resolved_blockers`, `introduced_blockers` are all empty

Because the verdict is sticky, a result on the same artifact that leaves every verdict unchanged (a PASS after a FAIL, a repeated unavailable) produces no evidence delta, so it cannot turn a no-progress loop into an unbounded repair loop. A new failure fingerprint is already covered by the fingerprint-set comparison. `resolved_blockers` / `introduced_blockers` remain caller observations (#1395).

No retry-count shortcut.

The first diagnosis of a Run has no base point. The caller passes the explicit value `FIRST_ITERATION` instead of a ProgressAssessment. "Absent" and "first iteration" are different values, so omitting progress is never read as "progress was made".

### Decision

- decision_ref
- decided_in_state: the `lifecycle_state` of the DecisionInput
- action: continue | repair | replan | stop (canon: `artifact-responsibilities.md`)
- outcome: null | MERGE_READY | HUMAN_ESCALATED | BLOCKED
- stop_reasons
- policy_verdicts
- loop_contract_ref and required_verifiers (copied from the DecisionInput)
- input_refs

Constructor rules (a violating Decision cannot be constructed):
- outcome != null <=> action=stop
- MERGE_READY => stop_reasons=[]
- HUMAN_ESCALATED / BLOCKED => >=1 Stop Reason
- outcome=HUMAN_REJECTED is rejected (it is a Stop Reason, not an Outcome)
- `(decided_in_state, action)` for a non-stop action must be a cell of the Transition table below

## Transition ownership

The Decision does not name a target state. #1392 derives the transition from `(snapshot lifecycle_state, action)` and rejects a transaction whose `decision_made` disagrees with the requested transition (request posted on PR #1406, 2026-09-25). For #1393 this means:

| decided_in_state | continue | repair | replan |
|---|---|---|---|
| `VERIFYING` | -> `PR_CONVERGING` | -> `DIAGNOSING` | not produced |
| `DIAGNOSING` | not produced | -> `REPAIRING` | -> `REPLANNING` |
| `PR_CONVERGING` | no transition | -> `REPAIRING` | not produced |

- Every cell is an edge of the #1392 first-slice allowlist (checked against #1406 head `d01fcbeb`).
- #1392 must reject a `decision_made` whose `decided_in_state` differs from the snapshot `lifecycle_state` at commit (otherwise a caller could decide as VERIFYING while the Run is in DIAGNOSING and skip the FailureRecord / NO_PROGRESS rules). Added to the #1406 request.
- `repair` from `VERIFYING` means "enter the repair path via DIAGNOSING"; it is not a repair round. Repair-round counts (#1395 budget, RunEvidence) count only `repair` decided in `DIAGNOSING` / `PR_CONVERGING`.
- Until #1392 adopts the derivation, #1395 must not request a transition that differs from this table. [Dependency] If #1392 changes its allowlist or does not adopt the derivation, this section is revisited before exec.

## DecisionInput

`make_decision_input(*, lifecycle_state, current_artifact_ref, input_last_event_seq, loop_contract_ref, contract_bound_seq, required_verifiers, verification_results, failure_records=(), progress=None, pr_convergence=None, policy_verdicts=())` validates everything below and raises `DecisionInputError` on the first violation. It returns an immutable `DecisionInput`.

`contract_bound_seq` is the `event_seq` of the `plan_contract_bound` event that bound `loop_contract_ref` to the Run (the latest one, so after a Replan it is the re-binding). Its truth is #1422 B-2 / B-6; #1393 only applies it.

Definitions:
- A result is **bound** when `bound_artifact_ref == current_artifact_ref` and either
  - `observed_seq > contract_bound_seq`, or
  - its status is `fail` (a FAIL crosses the contract boundary).
  Unbound (stale) results decide nothing.
- The contract boundary is **asymmetric**. After a Replan, a PASS / unavailable / inconclusive recorded under the previous contract never counts again, even when a revert brings the tree back to the artifact it was recorded on (R-042). A FAIL recorded on the same content stays sticky across the boundary, so a Replan that leaves the tree unchanged cannot release it by a flaky re-run (R-047); only a content change releases it. A verifier whose definition changes in the new contract must get a new `verifier_id` (#1422 B-6); a FAIL of a verifier that is no longer required decides nothing.
- The **artifact verdict** of a required verifier is computed from **all** its bound results, independent of their order:
  - any bound result is `fail` -> `fail` (a FAIL on an artifact stays a FAIL until the artifact changes; a later PASS on the same artifact does not erase it, so "re-run until green" is not a path to success)
  - otherwise any bound result is `pass` -> `pass`
  - otherwise (only `unavailable` / `inconclusive`, or no bound result) -> `unavailable`
- A **required FAIL** is a required verifier whose artifact verdict is `fail`. Its FailureRecord attaches to its bound FAIL result with the highest `observed_seq` (the **latest FAIL**).
- Because the verdict does not depend on order, a later PASS / unavailable inside a state cannot invalidate that state's precondition (a DIAGNOSING entered on a FAIL still has that FAIL). A later **FAIL** moves the latest FAIL, so the existing FR no longer satisfies I-7: the FAIL must be diagnosed again. #1395 owns this: it re-runs diagnosis for the new latest FAIL (a new `failure_recorded` event) before building the next DecisionInput. Re-diagnosis loops count toward the #1395 budget.

Common rules (all states):

| # | Rule |
|---|---|
| I-1 | `lifecycle_state` is `VERIFYING`, `DIAGNOSING`, or `PR_CONVERGING`. Everything else is rejected: `PLAN_VERIFYING` (deferred to a later slice), `PLANNING` / `EXECUTING` / `REPAIRING` / `REPLANNING` (mechanical exits owned by #1392 / #1395), `WAITING_*` (not supported by #1392 in the first slice), Outcome names and unknown values |
| I-2 | `current_artifact_ref` is non-empty |
| I-3 | `required_verifiers` is a non-empty set of `(verifier_id, kind)` pairs, every `kind` is `deterministic`, and no `verifier_id` appears twice. In the first slice only deterministic verifiers can be required; specification / independent_model / policy results are recorded in `input_refs` but decide nothing |
| I-4 | a `verifier_id` has one kind across `required_verifiers` and `verification_results` together (a result `(D, independent_model)` when `(D, deterministic)` is required is rejected) |
| I-5 | `verification_ref` is unique across all results, and every `observed_seq` in the input (results, FailureRecords, policy verdicts, `pr_convergence`) and `contract_bound_seq` are pairwise distinct (each is a distinct event; the latest FAIL is then unique) |
| I-8 | `loop_contract_ref` is non-empty (the LoopContract that `required_verifiers` was resolved from; see Trust boundary) |
| I-6 | every policy verdict is `AUTO_APPROVED`, `HUMAN_REQUIRED`, or `DENIED` (taxonomy §5; `ALLOW` and unknown values are rejected) |
| I-7 | every FailureRecord's `verification_ref` points to the latest FAIL of a required FAIL verifier (no orphan FR, and no FR for a stale, older, or non-required FAIL); its `observed_seq` is greater than that FAIL's `observed_seq` and than `contract_bound_seq` (a diagnosis is recorded after the failure, under the current contract). Several FRs for one FAIL are accepted; the effective FR is the one with the highest `observed_seq` |
| I-9 | `input_last_event_seq` is at least every `observed_seq` in the input (results, FailureRecords, policy verdicts, `pr_convergence`), and every `event_ref` is unique (see Trust boundary) |
| I-10 | `contract_bound_seq` is an integer `>= 1` (#1391 assigns `event_seq` from 1 and the #1392 create envelope binds the contract before any verification, so 0 would mean "no boundary") and less than `input_last_event_seq`. Results with `observed_seq < contract_bound_seq` are accepted; only their FAILs can be bound |
| I-11 | the number of results + FailureRecords + policy verdicts is at most `MAX_INPUT_REFS` (value agreed with #1392; R-062) |

Per-state rules:

| State | FailureRecords | progress | pr_convergence |
|---|---|---|---|
| `VERIFYING` | must be empty (DIAGNOSING has not run) | must be `None` | must be `None` |
| `DIAGNOSING` | at least one required FAIL exists, and every required FAIL has at least one FR | `FIRST_ITERATION` or a ProgressAssessment | must be `None` |
| `PR_CONVERGING` | if a required FAIL exists, every required FAIL has at least one FR; otherwise empty | if a required FAIL exists: `FIRST_ITERATION` or a ProgressAssessment; otherwise `None` | required |

When progress is a ProgressAssessment, its `current_artifact_ref` must equal the input's, and its `current_failure_refs` must equal the set of `failure_ref` of the effective FRs (P-1). Its `current_verdicts` must equal `artifact_verdicts(...)` computed from this input (P-3). A stale assessment cannot be reused.

`artifact_verdicts(*, required_verifiers, verification_results, current_artifact_ref, contract_bound_seq)` is the pure function behind the verdict definition above. `make_decision_input` and `decide` use it; #1395 calls it to obtain `current_verdicts` before `assess_progress`, and the verdicts are recorded in the `decision_made` payload so the next iteration can use them as `previous_verdicts`.

`pr_convergence` is built from an accepted `pr_convergence_recorded` event (#1391 vocabulary): `event_ref`, `observed_seq`, `observed_artifact_ref`, and five observed fields. Each field has a closed domain and a single passing value (R-056):

| Field | Domain | Passes when |
|---|---|---|
| `ci` | `pass \| fail \| pending` | `pass` (all required checks of the head succeeded) |
| `required_reviews` | `satisfied \| unsatisfied` | `satisfied` (the branch protection's required review count is met) |
| `blocking_threads` | integer `>= 0` | `0` |
| `conflict` | boolean | `false` |
| `scope` | `pass \| fail` | `pass` |

A value outside its domain is `DecisionInputError`. `scope` is the verdict of the #1395 deterministic observer that compares the head's changed paths with the LoopContract's allowed paths; #1393 does not compute changed paths and never trusts a Worker's `scope_ok`. #1393 validates `pr_convergence` but does not query GitHub. P-2: `observed_artifact_ref` must equal `current_artifact_ref` and `observed_seq > contract_bound_seq`; convergence observed on another head (an older push, or a push by someone else) or under the previous contract is rejected. That it is the latest `pr_convergence_recorded` for that head is #1422 B-8.

`ProgressAssessment` can be obtained only from `assess_progress` (no public constructor), so its `no_progress` is always derived.

## Decision order

`decide(decision_input)` evaluates in order and returns the first match. It never raises for a validated input except at step 5 and at the `PR_CONVERGING` + `replan_required` limitation.

1. progress is a ProgressAssessment with `no_progress=true` -> stop / HUMAN_ESCALATED / [NO_PROGRESS]
2. at least one required FAIL:
   - `VERIFYING` -> repair (-> DIAGNOSING)
   - `DIAGNOSING` -> replan if **any** effective FR is `replan_required`, otherwise repair
   - `PR_CONVERGING` -> repair if every effective FR is `repairable`; if any is `replan_required`, raise `DecisionInputError` (the allowlist has no `PR_CONVERGING -> REPLANNING` edge; see Known limitations)
3. any required verifier has artifact verdict `unavailable` -> stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE]
4. a `DENIED` verdict -> stop / BLOCKED / [POLICY_DENIED]
5. a `HUMAN_REQUIRED` verdict -> raise `DecisionInputError` (the first slice cannot enter `WAITING_HUMAN`)
6. `PR_CONVERGING`, every required verifier has artifact verdict `pass`, and every pr_convergence field passes -> stop / MERGE_READY
7. every required verifier has artifact verdict `pass`:
   - `VERIFYING` -> continue (-> PR_CONVERGING)
   - `PR_CONVERGING` -> continue (no transition; convergence not yet complete)
8. otherwise -> stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE]. The DecisionInput rules make this unreachable (DIAGNOSING always hits step 2; in the other states, after steps 2-3 every required verifier has verdict `pass`); it exists so that no path ends in continue or MERGE_READY by default

**Stop paths with DENIED.** If step 1 or 3 stops and a `DENIED` verdict is present, the Decision is stop / BLOCKED with stop_reasons = [the triggering reason, POLICY_DENIED]. A Run that Policy denied restarts only as a new Run (taxonomy §3).

**Verifier before Verdict.** Policy is evaluated after steps 1-3 (taxonomy §5). A verdict never overrides a required FAIL: `DENIED` or `HUMAN_REQUIRED` + a required FAIL gives the step 2 result. `DENIED` is checked before `HUMAN_REQUIRED`, so a denied Run is always recorded as BLOCKED. `HUMAN_REQUIRED` + no-progress gives HUMAN_ESCALATED / [NO_PROGRESS] (taxonomy §6 allowed example).

An independent-model PASS never removes a deterministic FAIL: non-required results decide nothing.

### Errors vs outcomes

- A Decision (steps 1-4, 6-8) is a state of the Run and is committed as `decision_made`.
- `DecisionInputError` means the caller passed an input the first slice does not support, or skipped a precondition. No Decision is fabricated. #1395 must treat it as fail-closed (no transition, no success) and own recording it as evidence.

## Freshness

On the same artifact, a FAIL is sticky: PASS -> FAIL and FAIL -> PASS both give verdict `fail`. A flaky verifier therefore cannot turn an artifact green by re-running; the artifact has to change (repair). An `unavailable` / `inconclusive` result does not erase a PASS or a FAIL.

A Replan does not change the artifact, so a FAIL on it survives the new contract (R-047); only PASS / unavailable / inconclusive from before the boundary are dropped.

After repair changes artifact A -> B, only results bound to B count:
- a PASS bound to A cannot support continue or MERGE_READY
- a FAIL bound to A cannot trigger repair / replan, and an FR for it is rejected (I-7)
- a required verifier whose only result is bound to A has verdict `unavailable` -> step 3, even when another required verifier has verdict `pass` on B

## Trust boundary

`decide()` is pure: it cannot read the RunState, the LoopContract, or the event stream. #1393 guarantees only two things: the Decision follows from the DecisionInput, and every rule checkable on the DecisionInput alone (I-1〜I-11, P-1〜P-3, the state table) holds. Whether the DecisionInput reflects the stream is covered only as far as the #1422 items listed below (B-1〜B-11); #1393 defines no stream invariant of its own, and a stream property not in that list is not guaranteed by anyone in the first release.

**Threat model.** The DecisionInput is built by #1395, which is deterministic orchestration code reading the #1391 stream. It is not a Worker. The threats this slice defends against are (1) Worker / fixture self-report entering the decision, and (2) the stream changing between building the input and committing the Decision. A defect in #1395 itself is caught only by audit (below), not prevented.

**Artifact identity.** In the first slice an artifact ref is the git **tree hash** of the candidate (its content), not the commit SHA. `bound_artifact_ref`, `current_artifact_ref`, `previous_artifact_ref` and `pr_convergence.observed_artifact_ref` all use it. The commit SHA is kept separately as `head_sha`. #1395 resolves the tree hash from the commit (`<sha>^{tree}`); GitHub reports a head SHA, which #1395 resolves the same way before building `pr_convergence`.

Consequence: an empty commit, an amend with the same content, or a rebase that yields the same tree is the **same artifact**. It neither releases a sticky FAIL nor counts as `artifact_changed` for NO_PROGRESS. A rebase onto a moved base changes the tree and legitimately requires re-verification (bounded by the #1395 budget).

| Value | Threat | Owner | Control |
|---|---|---|---|
| `lifecycle_state` | decide as another state and skip its rules | #1422 B-4 (#1392 at commit) | reject when `decided_in_state != snapshot lifecycle_state` |
| stream between build and commit | a FAIL recorded after the input was built (a `verification_recorded` event does not change the revision, so the revision CAS does not cover it), including a FAIL placed **earlier in the same transaction** as the `decision_made` | #1422 B-3 (#1392 at commit and load, #1391 stream validation for audit) | `decision_made.event_seq == input_last_event_seq + 1`, at most one `decision_made` per transaction |
| `failure_records` (set and content, including `repairability`) | a Diagnoser result that was not recorded, a repairability flipped from `replan_required` to `repairable`, or omitting the latest `failure_recorded` for one FAIL | #1393 selects (I-7 effective FR); #1422 B-9 checks completeness | build every FR from an accepted `failure_recorded` event (`event_ref`, `observed_seq`); pass **all** of them for each latest FAIL; the payload records each FR's `event_ref`, `observed_seq`, `repairability` and which one is effective |
| `verification_results` (set and content) | a Worker-reported result, or an omitted FAIL | #1395 | build every result from an accepted `verification_recorded` event (`event_ref`, `observed_seq` from the event); pass **all** results on the current artifact up to `input_last_event_seq` (FAILs from before the boundary included). The payload records every `event_ref`; #1422 B-9 checks at load that this set equals the stream's |
| `required_verifiers` / `loop_contract_ref` / `contract_bound_seq` | drop a failing required verifier, or move the contract boundary to revive or hide results | #1422 B-2 / B-6 (#1391 `plan_contract_bound`) | the set, the ref and the boundary are read from the latest `plan_contract_bound`. [Release condition] |
| `FIRST_ITERATION`, `previous_decision`, blocker sets | fake a first iteration or progress, or pick an older base point | #1393 (`make_previous_decision` domain checks) and #1422 B-10 | `previous_decision` is built from one accepted `decision_made`; B-10 checks that it is the latest base point and that `FIRST_ITERATION` is used only when none exists (including after a `PR_CONVERGING` repair). Blocker sets remain #1395 observations |
| `pr_convergence` | convergence of another head, an older observation, or a value not recorded | #1393 (P-2) and #1422 B-8 | built from an accepted `pr_convergence_recorded` event; `observed_artifact_ref == current_artifact_ref`; B-8 checks it is the latest for that head |
| `policy_verdicts` | omitting a `DENIED` (MERGE_READY instead of BLOCKED) or a verdict not recorded | #1422 B-8 (#1391 vocabulary) | built from accepted events; every `DENIED` of the Run is passed |

Audit (#1422 B-11, release condition): recompute each `decision_made` from the stream prefix up to its `input_last_event_seq` and compare.

#1422 items this plan relies on (B-1〜B-11 are in the issue body as of 2026-09-25; B-12 is proposed from C-2 R1):

| # | Invariant |
|---|---|
| B-1 | artifact identity = tree hash, encoded in the #1391 `sha256:<64 hex>` form as `sha256:` + SHA-256 of the string `git-tree:<tree object id>` (R-061) |
| B-2 | `contract_bound_seq` in the payload equals the `event_seq` of the latest `plan_contract_bound` before the `decision_made` (IT-10); #1391 accepts a re-binding after Replan as a boundary instead of rejecting it as binding drift (R-065) |
| B-3 | `decision_made.event_seq == input_last_event_seq + 1`; one `decision_made` per transaction |
| B-4 | `decided_in_state` equals the snapshot `lifecycle_state` |
| B-5 | transition derived from `(state, action)` |
| B-6 | `plan_contract_bound` carries `loop_contract_ref` and the required set; a changed verifier definition gets a new `verifier_id` |
| B-7 | superseded by I-7 (effective FR = highest `observed_seq`) + B-9 |
| B-8 | policy verdicts and `pr_convergence` are built from accepted events; every `DENIED` of the Run and the latest `pr_convergence_recorded` for the head are passed; `pr_convergence_recorded` carries `observed_artifact_ref` (R-060) |
| B-9 | completeness: the result `event_ref` set in the payload equals the stream's `verification_recorded` on the current artifact up to `input_last_event_seq`; likewise every `failure_recorded` for each latest FAIL |
| B-10 | `previous_decision` is the latest base-point `decision_made`; `FIRST_ITERATION` only when none exists |
| B-11 | audit recompute (IT-06) |
| B-12 | `failure_recorded` carries the `verification_ref` of the FAIL it diagnoses (R-059) — proposed, not yet in the issue |

The first release is not complete until #1422 (B-1〜B-11, including the audit) and the #1395 budget are in place.

## Known limitations of the first slice

| Limitation | Handling | Owner |
|---|---|---|
| `PLAN_VERIFYING` decisions (Initial Plan Verification PASS -> continue) | not accepted (I-1). Residual risk: in the first release no component decides Initial Plan Verification; `PLAN_VERIFYING -> EXECUTING` is a mechanical #1395 transition without `decision_made` | later #1393 slice (pbi-input updated) |
| `HUMAN_REQUIRED` -> `WAITING_HUMAN` | `DecisionInputError` (step 5) | #1392 waiting/resume slice |
| `PR_CONVERGING` + `replan_required` | `DecisionInputError` (step 2) | #1392 allowlist (no edge yet) |
| `BUDGET_EXHAUSTED` / `REPEATED_FAILURE` / `OSCILLATION` | not produced by `decide()` | later #1393 slice; budget enforced by #1395 (below) |
| blocker sets are caller observations | trusted as observed values; `evidence_delta` is derived and `previous_verdicts` comes from the base-point payload (#1422 B-10) | #1395 derives blocker sets from RunEvents |
| `required_verifiers` / `contract_bound_seq` are not yet bound to the Run by any event | release condition | #1422 B-2 / B-6 |
| no policy event exists in the #1391 first-slice vocabulary | the first slice passes no policy verdicts until B-8 adds one | #1422 B-8 / #1391 |
| a Replan with an unchanged tree keeps its FAILs (R-047) | intended fail-closed: the Run must change content (repair) or stop | — |
| a flaky verifier blocks an artifact until it changes (sticky FAIL) | intended fail-closed behavior | — |
| sticky FAIL only guarantees that re-running on the **same content** never turns green. Any content change (even one meaningless byte) is a new artifact, so a flaky PASS after it is accepted | residual threat; bounded only by the #1395 budget | #1395 |
| within one contract, reverting to an earlier tree reuses the results recorded on that tree under the same contract | intended: same content under the same contract gives the same deterministic result, and a FAIL recorded there stays sticky | — |

### Budget required from #1395 (release condition)

`NO_PROGRESS` alone does not bound these loops, so the first release requires #1395 to enforce limits outside `decide()`:

1. repair loop whose fingerprint keeps changing (every repair changes the artifact) — including while `DENIED` or `HUMAN_REQUIRED` is present
2. `PR_CONVERGING` continue with no transition while convergence keeps failing (for example conflict stays true)
3. `PLAN_VERIFYING` <-> `REPLANNING` (outside `decide()` in this slice)
4. repeated `DecisionInputError` retries
5. re-diagnosis after a later FAIL moves the latest FAIL (I-7): it records a `failure_recorded` event but produces no Decision, so decision counts do not see it

Required limits: total iterations, consecutive decisions in the same state, replan count, and `failure_recorded` events per Run (for 5). Exceeding one stops the Run as HUMAN_ESCALATED / [BUDGET_EXHAUSTED] recorded by #1395.

## APIs

```python
make_verification_result(...)
make_failure_record(...)
make_policy_verdict(...)
make_previous_decision(...)
artifact_verdicts(...)
assess_progress(...)
FIRST_ITERATION
make_decision_input(...)
decide(decision_input)
decision_to_event_draft(decision)
```

`decision_to_event_draft` creates a #1391 EventDraft with `decided_in_state`, `action`, `outcome`, `stop_reasons`, `policy_verdicts`, `input_last_event_seq`, `loop_contract_ref`, `contract_bound_seq`, `required_verifiers`, `artifact_verdicts`, the `event_ref` of every bound result used, the `event_ref`, `observed_seq` and `repairability` of every FailureRecord and the effective one per FAIL, the `event_ref` of every policy verdict, the `event_ref` and `observed_artifact_ref` of `pr_convergence` (PR_CONVERGING), `current_artifact_ref`, the current fingerprint set (the next base point), the progress kind (`first_iteration` / `assessed`) with `previous_decision_ref`, and `input_refs` (everything the Trust boundary checks need). It does not persist it. [Dependency] The #1391 implementation in PR #1402 fixes the `decision` object to the keys `{action, inputs, outcome, stop_reasons}` and checks that every ref in `inputs` exists earlier in the stream. Where each key above goes (for example the refs into `inputs`, the rest into an agreed extension) is agreed with #1391 before exec (Preflight).

**Payload size (R-062).** #1392 reserves room for a terminal `decision_made`, so the payload must be bounded. `make_decision_input` rejects an input whose results + FailureRecords + policy verdicts exceed `MAX_INPUT_REFS` (I-11). The value is agreed with #1392 before exec.

## Static boundaries

- no os/subprocess/network/time/fs
- no #1392 storage imports
- no merge API
- no GitHub API
- values from the #1391 `progress_assessed` / `repair_attempted` events (caller-given `no_progress`, `evidence_delta`) are never read into a DecisionInput; progress comes only from `assess_progress` (R-066, DC-11)

The module's directory must be covered by the static boundary check (ta-70 `_T70_DIRS` / `check_exec_boundary.py`). `scripts/ai-loop-v2/` is covered by neither today, so DC-09 is judged only after a positive control shows the check fails on a planted forbidden import. If extending the check touches a Hardening Override path, a Human applies it.

## Preflight before exec (C-2 R1)

| # | Condition | Source |
|---|---|---|
| PF-1 | The relation to the `decision_core` in PR #1402 (which declares `Closes #1393` with a different design) is decided: replace, drop, or keep API-compatible; and #1402 no longer closes #1393 unless it implements this plan | R-058 (Human) |
| PF-2 | #1391 `failure_recorded` carries `verification_ref` (#1422 B-12) | R-059 |
| PF-3 | #1391 `pr_convergence_recorded` carries `observed_artifact_ref` (#1422 B-8) | R-060 |
| PF-4 | the artifact ref encoding of #1422 B-1 is adopted by #1391 / #1395 | R-061 |
| PF-5 | the `decision_made` key mapping and `MAX_INPUT_REFS` are agreed with #1391 / #1392 | R-062 |
| PF-6 | the static boundary check covers the module's directory, with a positive control | R-058 AC candidate |

## Taxonomy notes

- `HUMAN_REJECTED` is a Stop Reason, not a Terminal Outcome (action=stop, outcome=HUMAN_ESCALATED, stop_reasons=[HUMAN_REJECTED]).
- Policy vocabulary is taxonomy §5 only; there is no `ALLOW`.

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 実装は新規 module + tests で 3-5 見込み → standard
- 受入基準数: 5（pbi-input First-slice decisions。PLAN_VERIFYING の 1 件は後続へ）→ standard
- 変更種別: MERGE_READY / HUMAN_ESCALATED を決める判定核（承認境界に隣接。success を出す唯一の経路）→ high-risk
- リスク: 誤判定が Delivery の終端を誤らせる（fail-open で MERGE_READY）→ 高
- **最終判定**: high-risk（`review-principles.md` §7-quater: C-2 は 2 ラウンド以上。`lite_eligible=false`・C-3 は Human 同期）
