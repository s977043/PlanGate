# TODO — TASK-1383 / #1383

## Stage 0 — Planning

- [x] audit V2 runtime presence
- [x] audit #1025 ownership
- [x] audit #894 ownership
- [x] audit #874 / #1285 ownership
- [x] audit #1369 Worker boundary
- [x] audit #1329 I4 transition rule
- [x] define exact two-path scope
- [x] define dependency matrix
- [x] define mutation tests

## Stage 1 — Owner subset confirmation

- [x] comment required subset on #1025
- [x] comment required subset on #894
- [x] comment required subset on #874
- [x] comment RunEvidence metric non-blocking boundary on #1285
- [x] reconcile owner contracts against canon; no field-ownership conflict found
- [x] Gate A = CONTRACT READY (runtime surfaces still pending)

## Stage 2 — Executable specification

- [x] reserve next-free TA number = 87
- [x] repair-convergence fixture
- [x] no-progress-stop fixture
- [x] Initial Plan Verification / Plan Gate trace
- [x] TA executable invariant checks
- [x] 18 mutation classes
- [x] set -e safe failure capture
- [x] adversarial review: blocker delta / provenance binding / terminality / convergence-input gaps fixed
- [x] Production scope validation must be evaluator-owned; fixture `scope_ok` is non-authoritative
- [x] full tests green on PR #1387 head `caf61900f8e132fb16ef03b794a2274402986621`
- [x] confirm M-2 remains baseline (current diff has no `scripts/ai-loop-v2/**` / `bin/ai-loop-v2/**`)

## Stage 3 — Production runtime preflight

- [x] record latest main SHA = `b2234bd1097f7b741d372e3353d1877932401731`
- [x] M-1 base measurement = baseline
- [x] M-2 base measurement = baseline
- [x] M-3 base measurement = baseline 4 Legacy files
- [x] semantic invalidation review: #1387 tests-only = no; #1391/#1392/#1393/#1395 runtime = YES candidate
- [x] implementation review level fixed: I3 minimum; I4 if protected Evaluation Harness / Human-owned boundary touched
- [ ] next-free TA number resolved if integration shell test is needed

## Stage 4 — Production RED / GREEN

- [ ] #1391 RunEvent spine / RunEvidence projection
- [ ] #1392 RunState CAS / crash recovery
- [ ] #1393 Verification / Failure / Decision core
- [ ] #1395 owner-backed Delivery integration
- [ ] create V2 delivery integration harness only after owner surfaces are consumable
- [ ] Path A RED
- [ ] Path B RED
- [ ] mutation tests RED
- [ ] evaluator-owned actual changed paths vs allowed_scope RED
- [ ] minimal GREEN adapters
- [ ] deterministic serialization/evidence
- [ ] no Legacy runtime authority

## Stage 5 — Review / Evidence

- [ ] I0 self-review
- [ ] I1+ independent review
- [ ] exact reviewed_at_sha
- [ ] CI / Test / CodeQL green
- [ ] evidence to #870
- [ ] owner-backed implementation runs the same fixture OR Human explicitly accepts spec-level fulfillment
- [ ] gate-release result to #1381

## Explicitly not in #1383

- Replan E2E
- Evolution runtime
- provider-specific production Worker
- full V2 metrics schema
- auto merge
- new taxonomy


## CI integration repair

- [x] first full Test failure attributed
- [x] TA-87 task-specific tests confirmed green in failed run
- [x] ta-26 TC-13/TC-33 root cause identified
- [x] explicit 7-env standalone unset added
- [x] rerun Test green


## Taxonomy review repair

- [x] terminal Outcome / Lifecycle State co-presence removed from fixtures
- [x] HUMAN_ESCALATED/BLOCKED Stop Reason requirement made executable
- [x] hardcoded plan-verifier ID removed from repair decision filtering


## Non-vacuity review

- [x] model-PASS override mutation no longer fails first on taxonomy-axis violation
- [x] convergence-input binding has dedicated mutant
- [x] progress fingerprint provenance has dedicated mutant
- [x] introduced-blocker delta has dedicated mutant
- [x] post-terminal continuation has dedicated mutant
