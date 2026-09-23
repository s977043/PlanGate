# TODO — TASK-1381 / #1381

## Phase B0 — Precondition / Plan

- [x] Phase A contractとの差分を確認
- [x] Legacy freezeとの配置衝突を確認
- [x] schema placement Human裁定を確認
- [x] existing RunEvidence adaptersを棚卸し
- [ ] PR #1380 Independent Review complete
- [ ] PR #1380 contract accepted
- [ ] #870 Delivery E2E: FAIL -> Diagnose -> Repair -> PASS -> MERGE_READY evidence
- [ ] #870 Delivery E2E: NO_PROGRESS -> STOP / ESCALATE evidence
- [ ] #1329 M-1 / M-2 / M-3 base measurement
- [ ] #1329 semantic invalidation review preflight
- [ ] Runtime implementation gate = all above PASS

## Phase B0A — Allowed while blocked

- [x] implementation file placementをV2 namespaceへ固定
- [x] Candidate / Experiment schema scopeを最小化
- [x] evaluator-owned actual delta設計
- [x] mutation matrix
- [x] Delivery-before-Evolution gateをPlanへ反映
- [x] I4 invalidation gateをPlanへ反映

## Phase B1 — RED（runtime gate後のみ）

- [ ] candidate schema RED
- [ ] experiment result schema RED
- [ ] failure instance identity tests
- [ ] pattern snapshot digest tests
- [ ] manifest missing -> INCONCLUSIVE tests
- [ ] evaluation plan mismatch tests
- [ ] allowed_paths overflow mutant
- [ ] activation=fired mutant
- [ ] sealed fixture mutation test
- [ ] known-bad + negative-control fixtures

## Phase B2 — GREEN

- [ ] **GATED:** `scripts/ai-loop-v2/ratchet.py`
- [ ] candidate validator
- [ ] experiment validator
- [ ] evaluator-owned fixture tree delta calculator
- [ ] actual delta validator
- [ ] activation evaluator
- [ ] prevention evidence evaluator
- [ ] PromotionDecision projection
- [ ] deterministic serialization

## Phase B3 — Integration

- [ ] next-free TA number再取得
- [ ] TA-NN
- [ ] Legacy diff review evidence
- [ ] privacy / secret guard
- [ ] no-network / no-merge static guard
- [ ] full test suite
- [ ] fixture E2E

## Phase B4 — Review / Evidence

- [ ] I0 self-review
- [ ] I1+ independent review
- [ ] reviewed_at_sha record
- [ ] CI / Test / CodeQL green
- [ ] #1381 evidence comment
- [ ] #1376 Phase B result comment
- [ ] remaining gaps / Phase C decision

## Explicitly not done in this task

- Production promotion
- merge automation
- plugin distribution
- V2 RunEvidence full implementation
- HarnessManifest generator
- general clustering engine
- long-term recurrence collector


## Plan-review fixes already incorporated

- [x] actual delta を Candidate 自己申告から分離
- [x] TA-87 hardcode を撤回し next-free 解決へ変更
- [x] PromotionDecision を #811 authoritative contract ではなく compatibility projection に限定
- [x] Phase B fixture を #909 Incident Regression Set へ自動昇格しない