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
- [x] I0 plan review（Revision 2.5 / 簡易 C-1 PASS。現行 runtime I0 は別途必要）
- [x] C-2 R1 (external, 2 lanes) → Revision 2.3 (R-055〜R-069; R-055 / R-058 resolved by Human 2026-09-28)
- [x] C-2 R2 (2026-09-28 Revision 2.5 / Human裁定で収束)
- [x] C-3 (Human, 2026-09-28 22:45:37Z、承認plan限定。追加範囲は別途判定)

## Preflight

> 2026-10-08: owner 状況と gate は [dependency-reconciliation.md](dependency-reconciliation.md) に記録。#1391/#1392/#1393/#1395/#1422 は OPEN。C-3 APPROVED は BLOCKED 解消を意味しない。

- [x] #1516 scope-observer の導入と Ratchet の private `_canonical_path` 依存解消
- [ ] Ratchet/TA-92 の provisional `DecisionError/decide` からの移行範囲を Human 裁定し必要時 C-3 再発行
- [ ] #1422 B-1〜B-13 の owner / validation timing を Human 決定
- [ ] #1391 event contract consumable
- [ ] #1392 RunState input shape frozen
- [ ] #1392 derives the transition from (state, action) (request on PR #1406) or this plan's Transition ownership is revisited
- [ ] #1391 decision_made payload keys agreed (plan PF-5)
- [ ] plan "Preflight before exec" PF-1〜PF-8（plan.md の PF-7 / PF-8 を含む。INDEX.md / current-state.md / dependency-reconciliation.md と同じ範囲）
- [ ] #1395 budget requirement recorded (release condition)
- [ ] exact base SHA
- [x] #1329 semantic invalidation YES candidate（V2実行系変更。失効判定・canon I4 は別gate）

## RED/GREEN
- [ ] records
- [ ] progress assessment
- [ ] decision
- [ ] event draft adapter
- [ ] mutation tests
- [ ] static boundary
- [ ] repository CI

## Handoff

- [ ] #1381 AC-6: accepted verifier evidence → owner RunEvent → bound DecisionInput → owner Decision → known-bad block / negative-control pass（simulationは不可）
- [ ] AC-6 / #1395 exact-head independent I3/I4 review（I0と分離）
- [ ] #1395 integration
- [ ] runtime review evidence
