# TODO — TASK-1381 / #1381

## Phase B0 — Precondition / Plan

- [x] Phase A contractとの差分を確認
- [x] Legacy freezeとの配置衝突を確認
- [x] schema placement Human裁定を確認
- [x] existing RunEvidence adaptersを棚卸し
- [ ] PR #1380 Independent Review complete
- [ ] PR #1380 contract accepted

## Phase B1 — RED

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

- [ ] `scripts/ai-loop-v2/ratchet.py`
- [ ] candidate validator
- [ ] experiment validator
- [ ] actual delta validator
- [ ] activation evaluator
- [ ] prevention evidence evaluator
- [ ] PromotionDecision projection
- [ ] deterministic serialization

## Phase B3 — Integration

- [ ] TA-87
- [ ] Legacy diff guard
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
