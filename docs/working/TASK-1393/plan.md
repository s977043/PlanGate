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
- verification_ref (the deterministic FAIL this record normalizes; used to detect a FAIL without a FailureRecord)
- observation
- fingerprint
- evidence_refs
- cause_hypothesis
- repairability = `repairable | replan_required`
- result = `open | repeated | resolved`

Observation and cause hypothesis remain separate.
Unknown repairability/result values are rejected; free-form strings are not decision inputs.

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
- next_state: the #1392 Lifecycle State the caller transitions to; `null` when action=stop or when the Run stays in the current state
- input_refs
- outcome: null | MERGE_READY | HUMAN_ESCALATED | BLOCKED
- stop_reasons
- policy_verdicts

Rules:
- outcome != null => action=stop and next_state=null
- action != stop => outcome=null
- MERGE_READY => stop_reasons=[]
- HUMAN_ESCALATED/BLOCKED => >=1 Stop Reason
- a non-null next_state must be an edge of the #1392 first-slice transition allowlist from `lifecycle_state` (checked against #1406 head `c48843ab`; if #1392 changes the allowlist, this table follows it)

## State-aware decision

The engine consumes a RunState **snapshot value** (not storage) through `lifecycle_state`. `decide()` accepts only the states in the table below. Every other state raises `DecisionInputError` at step 0:

- `PLANNING` / `EXECUTING` / `REPAIRING` / `REPLANNING`: their exit is a mechanical transition owned by #1392 / #1395, not a decision
- `WAITING_HUMAN` / `WAITING_EXTERNAL`: #1392 does not create or resume them in the first slice; deciding in them would let the AI leave a Human wait on its own
- an Outcome name (`MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED`) or any other value passed as a state

| lifecycle_state | Required inputs | Possible Decisions (action / next_state or outcome) |
|---|---|---|
| `PLAN_VERIFYING` | specification results for the plan artifact | continue / `EXECUTING`; replan / `REPLANNING` (fresh specification FAIL); stop (steps 1, 3, 4) |
| `VERIFYING` | deterministic results; FailureRecord **not** required (DIAGNOSING has not run yet) | continue / `DIAGNOSING` (any fresh deterministic FAIL); continue / `PR_CONVERGING` (every required verifier has a fresh PASS); stop (steps 1, 3, 4) |
| `DIAGNOSING` | a FailureRecord for every fresh deterministic FAIL | repair / `REPAIRING`; replan / `REPLANNING`; stop (steps 1, 3, 4) |
| `PR_CONVERGING` | deterministic results, `pr_convergence`, and a FailureRecord for every fresh deterministic FAIL | repair / `REPAIRING`; continue / null (fresh PASS, convergence not yet all pass); stop / MERGE_READY (step 5); stop (steps 1, 3, 4) |

`PR_CONVERGING` + `replan_required` FAIL has no edge in the #1392 allowlist, so it raises `DecisionInputError` (unsupported in the first slice) rather than fabricating a transition.

## Decision order

Fail-closed priority. Each step returns the first match; later steps are not evaluated. If no step matches, the result is stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE] (step 7). There is no path that reaches MERGE_READY or continue by default.

0. input contract validation -> raise `DecisionInputError` (no Decision value):
   - `lifecycle_state` not in the State-aware decision table
   - `required_verifiers` empty
   - a policy verdict outside the taxonomy §5 vocabulary (including `ALLOW`)
   - in `DIAGNOSING` / `PR_CONVERGING`: a fresh deterministic FAIL whose `verification_ref` has no FailureRecord
   - the same `verifier_id` has both a fresh PASS and a fresh FAIL (contradictory observation)
1. no-progress assessment -> stop / HUMAN_ESCALATED / [NO_PROGRESS]
2. fresh deterministic FAIL (one or more), by state:
   - `VERIFYING` -> continue / `DIAGNOSING`
   - `DIAGNOSING` / `PR_CONVERGING`: if **any** FailureRecord is `replan_required` -> replan (from `PR_CONVERGING`: `DecisionInputError`, see above); otherwise all are `repairable` -> repair
   - `PLAN_VERIFYING` (fresh specification FAIL) -> replan / `REPLANNING`
3. any `required_verifiers` entry without a result bound to `current_artifact_ref`, or whose fresh result is unavailable/inconclusive -> stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE]
3a. policy verdict `HUMAN_REQUIRED` -> raise `DecisionInputError` (first slice cannot enter `WAITING_HUMAN`; see Policy scope)
4. policy verdict `DENIED` -> stop / BLOCKED / [POLICY_DENIED]
5. only in `PR_CONVERGING`: every required verifier has a fresh PASS + PR convergence PASS -> stop / MERGE_READY
6. every required verifier has a fresh PASS, no convergence yet:
   - `PLAN_VERIFYING` -> continue / `EXECUTING`
   - `VERIFYING` -> continue / `PR_CONVERGING`
   - `PR_CONVERGING` -> continue / null
7. otherwise -> stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE]

An independent-model PASS never removes a deterministic FAIL from step 2.

Policy is evaluated after Verifier evidence (steps 1-3), as `taxonomy.md` §5 requires: a Verdict cannot override a deterministic FAIL, so `DENIED` or `HUMAN_REQUIRED` + fresh deterministic FAIL yields the step 2 result, and `HUMAN_REQUIRED` + no-progress yields HUMAN_ESCALATED / [NO_PROGRESS] (the §6 allowed example). `DENIED` can never reach step 5.

**DENIED on another stop path.** When step 1 or step 3 stops the Run and a `DENIED` verdict is also present, the Decision is stop / BLOCKED with stop_reasons = [the triggering reason, POLICY_DENIED]. A Run that Policy denied must not be resumable as a HUMAN_ESCALATED Run; per taxonomy §3 it restarts only as a new Run.

### Input contract violations vs runtime outcomes

- A runtime outcome (step 1-7) is a legitimate state of the Run and is returned as a Decision so that #1392 records `decision_made`.
- An input contract violation (step 0 and step 3a, and `PR_CONVERGING` + `replan_required`) means the caller passed an input the first slice does not support or skipped a precondition (DIAGNOSING did not produce a FailureRecord). It raises `DecisionInputError`; it is not a Run state, and no Decision is fabricated for it.
- A fresh FAIL in `VERIFYING` without a FailureRecord is **not** a violation: it is the normal path to `DIAGNOSING`.
- #1395 integration must treat `DecisionInputError` as fail-closed (no transition to success). Recording it as evidence is the caller's responsibility and out of scope for #1393.

## Required verifiers

`required_verifiers` is a caller-supplied observed value: the set of `(verifier_id, kind)` pairs the LoopContract requires for the current `lifecycle_state`. #1393 does not derive it. It must be non-empty (step 0).

Only results from required verifiers decide steps 2, 3, 5 and 6. A result from a verifier that is not required (for example an independent-model review) is recorded in `input_refs` but can neither satisfy nor fail a required verifier.

## Freshness

Caller supplies `current_artifact_ref`.
Every VerificationResult that the decision uses, PASS **and** FAIL, must bind exactly to `current_artifact_ref`. A result bound to any other artifact is stale and ignored.

After repair changes artifact A -> B:
- PASS bound to A is stale: it cannot support MERGE_READY or continue
- FAIL bound to A is stale: it cannot trigger repair/replan again
- only results bound to B are used; a required verifier whose only result is bound to A has no fresh result, so step 3 applies (VERIFIER_UNAVAILABLE), never a stale-based repair or success. This holds even when another required verifier has a fresh PASS on B

## Out of scope: budget and repetition

`NO_PROGRESS` requires `artifact_changed=false`, and every repair changes the artifact, so NO_PROGRESS alone does not bound a repair loop whose fingerprint keeps changing. `BUDGET_EXHAUSTED` / `REPEATED_FAILURE` / `OSCILLATION` (taxonomy §4, detected by the Decision Engine) are not in the first slice.

- Owner: a later Decision Engine slice; until then #1395 must enforce an iteration budget outside `decide()`
- Residual risk accepted by this slice: without #1395's budget, a Run with a persistent `DENIED` and a changing FAIL repairs without bound and never reaches BLOCKED
- [P1 / Human] whether the first release may ship without the budget Stop Reasons in `decide()`

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
  lifecycle_state,
  current_artifact_ref,
  required_verifiers,
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
- missing FailureRecord for deterministic FAIL in DIAGNOSING / PR_CONVERGING -> `DecisionInputError`, no Decision; in VERIFYING -> continue / DIAGNOSING
- required verifier X fresh PASS + required verifier Y only a stale FAIL, in PR_CONVERGING with convergence pass -> VERIFIER_UNAVAILABLE, never MERGE_READY
- mixed repairability -> replan
- WAITING_* / EXECUTING / REPAIRING state -> `DecisionInputError`
- DENIED + no-progress -> BLOCKED / [NO_PROGRESS, POLICY_DENIED]
- HUMAN_REQUIRED + fresh deterministic FAIL -> step 2 result, not an error
- stale FAIL (bound to previous artifact) -> no repair/replan; no fresh result -> VERIFIER_UNAVAILABLE
- policy `DENIED` -> stop / BLOCKED / [POLICY_DENIED]
- policy `DENIED` + fresh deterministic FAIL -> repair/replan (Verdict after Verifier)
- policy `HUMAN_REQUIRED` (no earlier stop) / unknown / `ALLOW` -> `DecisionInputError`
- MERGE_READY without convergence
- convergence PASS but no fresh deterministic PASS
- Worker self-report field cannot enter API
- pre-authored outcome/no_progress cannot enter observation constructors

## Static boundaries

- no os/subprocess/network/time/fs
- no #1392 storage imports
- no merge API
- no GitHub API


## Policy scope

Vocabulary follows `docs/ai/ai-loop-v2/taxonomy.md` §5 (`AUTO_APPROVED` / `HUMAN_REQUIRED` / `DENIED`). There is no `ALLOW` verdict.

| Input | First-slice handling | Canon basis |
|---|---|---|
| no verdict | normal evaluation | MERGE_READY does not require `AUTO_APPROVED` (§6) |
| `AUTO_APPROVED` | normal evaluation | §5 |
| `DENIED` | step 4: stop / BLOCKED / [POLICY_DENIED]; on a step 1 / 3 stop, outcome becomes BLOCKED and POLICY_DENIED is added | §5 `DENIED` -> `POLICY_DENIED`; §3 BLOCKED = the Run ends on a boundary; §4 allows several Reasons |
| `HUMAN_REQUIRED` | step 3a (after Verifier evidence): `DecisionInputError` (out of first-slice scope). Steps 1-3 still decide first | §5 maps it to State `WAITING_HUMAN`, which is a wait, not a terminal Outcome, and evaluates Verdicts after Verifier evidence. Decision actions have no wait action and #1392 does not support WAITING_* yet, so the first slice does not fabricate a terminal Outcome for it |
| unknown value | step 0: `DecisionInputError` | not in the §5 vocabulary |

Out of scope, owned elsewhere:
- the transition to `WAITING_HUMAN` on `HUMAN_REQUIRED` (RunState owner, #1392 / #1395)
- how #1395 records a `DecisionInputError` as evidence

[P1 / Human] How `HUMAN_REQUIRED` reaches `WAITING_HUMAN` with a recorded event (a later owner slice decides whether the Decision core gains a wait action or the Policy Gate transitions the RunState directly).


## Taxonomy correction

`HUMAN_REJECTED` is a **Stop Reason**, not a Terminal Outcome.

A Human rejection is represented as:

```text
action = stop
outcome = HUMAN_ESCALATED
stop_reasons = [HUMAN_REJECTED]
```

The Decision core must reject `outcome=HUMAN_REJECTED`.

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 実装は新規 module + tests で 3-5 見込み → standard
- 受入基準数: 6（pbi-input First-slice decisions）→ high-risk
- 変更種別: MERGE_READY / HUMAN_ESCALATED を決める判定核（承認境界に隣接。success を出す唯一の経路）→ high-risk
- リスク: 誤判定が Delivery の終端を誤らせる（fail-open で MERGE_READY）→ 高
- **最終判定**: high-risk（`review-principles.md` §7-quater: 承認境界に触れるため C-2 は 2 ラウンド以上。`lite_eligible=false`・C-3 は Human 同期）
