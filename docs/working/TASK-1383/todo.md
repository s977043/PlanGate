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

- [ ] comment required subset on #1025
- [ ] comment required subset on #894
- [ ] comment required subset on #874
- [ ] comment RunEvidence metric non-blocking boundary on #1285
- [ ] reconcile owner feedback
- [ ] Gate A = READY

## Stage 2 — Executable specification

- [x] reserve next-free TA number = 87
- [x] repair-convergence fixture
- [x] no-progress-stop fixture
- [x] Initial Plan Verification / Plan Gate trace
- [x] TA executable invariant checks
- [x] 13 mutation classes
- [x] set -e safe failure capture
- [ ] full tests (rerun after ta-26 TC-13/TC-33 convention fix)
- [ ] confirm M-2 remains baseline

## Stage 3 — Production runtime preflight

- [ ] record latest main SHA
- [ ] M-1 base measurement
- [ ] M-2 base measurement
- [ ] M-3 base measurement
- [ ] semantic invalidation review
- [ ] implementation review level fixed
- [ ] next-free TA number resolved if integration shell test is needed

## Stage 4 — Production RED / GREEN

- [ ] create V2 delivery integration harness only after Gate A
- [ ] Path A RED
- [ ] Path B RED
- [ ] mutation tests RED
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
- [ ] rerun Test green


## Taxonomy review repair

- [x] terminal Outcome / Lifecycle State co-presence removed from fixtures
- [x] HUMAN_ESCALATED/BLOCKED Stop Reason requirement made executable
- [x] hardcoded plan-verifier ID removed from repair decision filtering
