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
- [x] Ratchet/TA-92 の provisional `DecisionError/decide` からの移行範囲を Human 裁定（2026-10-21、R-081: PF-1 に追加。Revision 2.6）
- [ ] Revision 2.6 に対する c3.json を Human が再発行（AI は発行しない）
- [x] #1422 B-1〜B-13 の owner / validation timing を Human 決定（2026-10-21 部分凍結、R-082。B-8 / B-13 は未凍結 gap）
- [ ] #1422 B-8 / B-13 の語彙・event 形状が #1391 plan（C-3）で決まる
- [ ] #1391 event contract consumable
- [ ] #1392 RunState input shape frozen
- [ ] #1392 derives the transition from (state, action) (request on PR #1406) or this plan's Transition ownership is revisited
- [x] #1391 decision_made payload keys and I-11 limits agreed (plan PF-5, Human decision 2026-10-22, R-085〜R-088, Revision 2.7)
- [ ] Revision 2.7 に対する c3.json を Human が再発行（AI は発行しない）
- [ ] exec: `scripts/ai-loop-v2/limits.py`（葉 module）を作成し仮値を fixture 固定（R-086 / R-087）
- [ ] #1395 budget 確定時に `MAX_INPUT_REFS >= budget 最大件数` を検証（R-087）
- [ ] plan "Preflight before exec" PF-1〜PF-8（plan.md の PF-7 / PF-8 を含む。INDEX.md / current-state.md / dependency-reconciliation.md と同じ範囲）
- [ ] #1395 budget requirement recorded (release condition)
- [ ] exact base SHA
- [x] #1329 semantic invalidation YES candidate（V2実行系変更。失効判定・canon I4 は別gate）

## RED/GREEN
- [ ] records
- [ ] progress assessment
- [ ] decision
- [ ] event draft adapter
- [ ] caller migration (PF-1 / R-079 / R-081): `delivery_runtime.py`, `test_delivery_v2.py`, ta-87 / ta-93 fixtures, and `ratchet.py` (:16 import, :193 keyword call → `make_decision_input(lifecycle_state="PR_CONVERGING", ...)` + `decide(decision_input)`, `changed_paths` dropped, `DecisionInputError` → `ERROR` at :208). rollback: revert the migration commit (ratchet.py returns to the provisional `decision_core`)
- [ ] TA-92 regression after the Ratchet switch: `python3 scripts/ai-loop-v2/test_ratchet.py` and `tests/extras/ta-92-ai-loop-v2-ratchet.sh` PASS with unchanged expected outcomes (RT-01〜RT-04)
- [ ] mutation tests
- [ ] static boundary
- [ ] repository CI

## Handoff

- [ ] #1381 AC-6: accepted verifier evidence → owner RunEvent → bound DecisionInput → owner Decision → known-bad block / negative-control pass（simulationは不可）
- [ ] AC-6 / #1395 exact-head independent I3/I4 review（I0と分離）
- [ ] #1395 integration
- [ ] runtime review evidence
