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

## Revision 2.1（C-2 R1 / R-020〜R-041）

ID は plan の `P1B-n` に読み替える（上節の B-n は旧ラベル。plan「ID 対応表」）。

- [x] C-2 R1 指摘集約（review-external R-020〜R-041）と確定反映
- [ ] 👤 C-3（Human）
- [ ] 🤖 **#1393 PF-5 合意の確認（MAX_* 値・定義 module・バイト上限の範囲・decision_made key mapping）。未合意なら exec BLOCKED（D-6）** — rollback: 不要
- [ ] 🤖 T1: #1047 語彙との衝突なし・観測/仮説分離の確認（R-028）— rollback: 不要
- [ ] 🤖 RED: P1B-2 seq adjacency（EV-29 / EV-30）— rollback: test 追加の revert
- [ ] 🤖 RED: 値域・閉集合・blockers（EV-31〜33a, EV-37）— rollback: 同上
- [ ] 🤖 RED: load 層（各 A+L ケースの L 側, PJ-19, EV-34）— rollback: 同上
- [ ] 🤖 RED/GREEN: D-5 対照（PJ-16〜18）— rollback: 同上
- [ ] 🤖 RED: D-7 の unknown type / 旧名（EV-35 / EV-36）— rollback: 同上
- [ ] 🤖 GREEN: `validate_append` を append-only / whole-stream に分離（R-037）— rollback: 当該 commit を revert
- [ ] 🤖 GREEN: `delivery_runtime.py` の使用不能入力処理（R-033 / PJ-20）— rollback: 同上
- [ ] 🤖 既存 fixture / ta-87 / ta-93 / test_delivery_v2 / test_ratchet の再実行と更新（R-032 / R-035）— rollback: 同上
- [ ] 🤖 P1B-13 adapter 境界文書（R-025）— rollback: 文書 revert
- [ ] 🤖 mutation 19〜22 — rollback: 不要
- [ ] 🤖 #1392 exec 時: `state_conflict` 改名・payload・EV-24（D-7。本 TASK の exec 範囲外として追跡のみ）— rollback: 不要
