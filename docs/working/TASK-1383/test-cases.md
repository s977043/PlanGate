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

TA-87 currently kills 13 mutation classes:
1. Initial Plan Verification skipped
2. Worker self-report completion
3. model PASS overriding deterministic FAIL
4. inconclusive treated as PASS
5. stale verification reuse
6. active-run Harness drift
7. auto merge side effect
8. retry-count-only NO_PROGRESS
9. Terminal Outcome event mixed with Lifecycle State
10. NO_PROGRESS used as Lifecycle State
11. meaningful artifact delta mislabeled NO_PROGRESS
12. Decision references a removed FailureRecord
13. HUMAN_ESCALATED without Stop Reason


## Evidence reference integrity

- every `decision.inputs[]` must resolve to an existing earlier evidence/reference in the same trace
- future references are rejected
- duplicate reference IDs are rejected
- removing a FailureRecord while leaving its decision reference must fail even if the expected projection is also edited


## CI integration finding — extras convention

Initial full Test run failed even though TA-87 itself was green.

Observed:
- TA-87: both traces PASS
- TA-87: 11 mutation classes killed
- repository result: 1275 passed / 2 failed
- failures were ta-26 TC-13 / TC-33

Root cause:
- new standalone-capable TA-87 did not contain the repository-required explicit unset of the runner's guarded 7 env vars
- the shared `_extra-contract.sh` also unsets them at runtime, but ta-26 TC-33 intentionally requires each extras file to carry the explicit local defense
- ta-26 recursive standalone TC-13 consequently also failed

Fix:
```sh
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi
```

Review lesson:
- a new `tests/extras/ta-*.sh` must satisfy both its task-specific assertions and the repository-wide extras meta-contract
- "TA itself green" is not sufficient evidence; full `tests/run-tests.sh` is mandatory


## Taxonomy-axis review

Canonical taxonomy requires four orthogonal axes.

Additional executable rules:
- non-terminal events may carry a Lifecycle State
- terminal `decision_made` with an Outcome does **not** simultaneously carry a Lifecycle State in this fixture
- `MERGE_READY` has no Stop Reason
- `HUMAN_ESCALATED` / `BLOCKED` require at least one Stop Reason
- Stop Reason values can never be used as Lifecycle State values

This keeps the fixture from implying that a terminal Run is still in `WAITING_HUMAN` or another non-terminal state.
