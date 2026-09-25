# TODO — TASK-1393 / #1393

## Plan
- [x] pure core boundary
- [x] VerificationResult / FailureRecord shape
- [x] progress derivation
- [x] fail-closed decision order
- [x] freshness rule
- [x] PR convergence observation boundary
- [x] policy verdict handling aligned with taxonomy §5 (R-001 / R-005 / R-006)
- [x] freshness on FAIL side (R-002) / FailureRecord `verification_ref` (R-003)
- [x] C-1 re-run after R-001〜R-006
- [ ] I0 plan review
- [ ] C-2 R1 (external) — high-risk: §7-quater requires ≥2 rounds
- [ ] C-2 R2 (focus: whether R1 fixes actually hold)
- [ ] C-3 (Human, synchronous)

## Preflight
- [ ] #1391 event contract consumable
- [ ] #1392 RunState input shape frozen
- [ ] exact base SHA
- [ ] #1329 semantic invalidation YES

## RED/GREEN
- [ ] records
- [ ] progress assessment
- [ ] decision
- [ ] event draft adapter
- [ ] mutation tests
- [ ] static boundary
- [ ] repository CI

## Handoff
- [ ] #1395 integration
- [ ] runtime review evidence
