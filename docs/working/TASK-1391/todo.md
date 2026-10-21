# TODO — TASK-1391 / #1391

## Plan-only phase

- [x] owner boundary defined
- [x] persistence boundary separated from #1391
- [x] #1392 durable sink dependency identified
- [x] #1393 pure decision dependency identified
- [x] first-slice event vocabulary bounded
- [x] RED categories defined
- [x] event_seq allocation assigned to #1392 durable boundary
- [x] EventDraft vs Accepted RunEvent separated
- [x] duplicate retry vs duplicate accepted event separated
- [x] parse failure vs evidence_status=invalid separated
- [x] precommit validate_append assigned to #1391/#1392 boundary
- [x] event_seq made contiguous, not merely monotonic
- [x] I0 plan self-review
- [ ] I1+ plan review
- [ ] exact reviewed_at_sha

## Before Production implementation

- [ ] #1387 current-head I1 PASS
- [ ] latest main/base SHA recorded
- [ ] M-1 before recorded
- [ ] M-2 before recorded
- [ ] M-3 before recorded
- [ ] semantic invalidation = YES candidate recorded
- [ ] implementation files re-inventoried
- [ ] next-free TA number reserved

## RED

- [ ] event envelope tests
- [ ] reference-integrity tests
- [ ] privacy tests
- [ ] projection tests
- [ ] boundary/static tests
- [ ] mutation tests

## GREEN

- [ ] run_event pure validation
- [ ] run_evidence pure projection
- [ ] no durable writer
- [ ] full suite green
- [ ] TA standalone green
- [ ] plugin/distribution impact reviewed

## Review / handoff

- [ ] I0 implementation review
- [ ] I1+ implementation review
- [ ] #1329 invalidation evidence returned
- [ ] #1392 interface handoff
- [ ] #1393 interface handoff
- [ ] #1383 integration evidence updated

## Revision 2 / Phase 1B（R-001〜R-019）

- [x] 指摘集約（review-external R-001〜R-019）
- [x] plan 差分化（D-1）
- [ ] 👤 C-3（Human）
- [ ] 🤖 reviewed_at_sha / base SHA 記録 — rollback: 不要
- [ ] 🤖 #1329 preflight（M-1/M-2/M-3 before）記録 — rollback: 不要
- [ ] 🤖 RED: B-2 rebinding（EV-11〜13）— rollback: test 追加の revert
- [ ] 🤖 RED: B-3 binding 供給（EV-14〜15）— rollback: 同上
- [ ] 🤖 RED: B-6 / B-12 / B-8 / B-13 / B-10 / B-11 payload（EV-16〜24）— rollback: 同上
- [ ] 🤖 RED: B-9 non-vacuity / B-8 policy projection / B-14（PJ-04b, PJ-11〜14）— R-009 は実行再現 — rollback: 同上
- [ ] 🤖 RED: G13 不足分（EV-25〜28, PJ-15）— rollback: 同上
- [ ] 🤖 GREEN: run_event.py / run_evidence.py 差分 — rollback: 当該 commit を revert（#1392 / #1393 側の呼び出しが未追従なら同時に戻す）
- [ ] 🤖 mutation 11〜18 — rollback: 不要
- [ ] 🤖 敵対レビュー R1 / R2 + 回避クラス台帳 — rollback: 不要
- [ ] 🤖 R-014 / R-015 裁定記録 — rollback: 不要
- [ ] 👤 C-4
