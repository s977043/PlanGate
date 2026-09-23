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

- [ ] reserve next-free TA number
- [ ] repair-convergence fixture
- [ ] no-progress-stop fixture
- [ ] TA executable invariant checks
- [ ] mutation checks
- [ ] full tests
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
- [ ] gate-release result to #1381

## Explicitly not in #1383

- Replan E2E
- Evolution runtime
- provider-specific production Worker
- full V2 metrics schema
- auto merge
- new taxonomy
