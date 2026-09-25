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
- [x] Revision 2: DecisionInput validated in one place, 3 accepted states, no next_state (Human decisions 2026-09-25)
- [x] adversarial review of Revision 2 (Rev2-R1〜R5; Human ruled R5 converged, 2026-09-25)
- [x] Revision 2.1 / 2.2 (scope narrowed to DecisionInput, stream binding to #1422; R-042〜R-054)
- [ ] I0 plan review
- [x] C-2 R1 (external, 2 lanes) → Revision 2.3 (R-055〜R-069; R-055 / R-058 open for Human)
- [ ] C-2 R2 (focus: whether R1 fixes actually hold)
- [ ] C-3 (Human, synchronous)

## Preflight
- [ ] #1391 event contract consumable
- [ ] #1392 RunState input shape frozen
- [ ] #1392 derives the transition from (state, action) (request on PR #1406) or this plan's Transition ownership is revisited
- [ ] #1391 decision_made payload keys agreed (plan PF-5)
- [ ] plan "Preflight before exec" PF-1〜PF-6
- [ ] #1395 budget requirement recorded (release condition)
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
