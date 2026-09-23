# TEST CASES — TASK-1381 / #1381

| ID | AC | Input / Mutation | Expected |
|---|---|---|---|
| TC-01 | AC-1 | failure instance with run_id/event_ref/failure_record_ref/run_evidence_ref | immutable source binding accepted |
| TC-02 | AC-1 | same fingerprint, different event_ref | distinct failure instances |
| TC-03 | AC-2 | source bundle -> candidate | source refs preserved |
| TC-04 | AC-3 | pattern snapshot | classifier_digest + source_set_digest required |
| TC-05 | AC-3 | same pattern_id, different classifier_digest | not treated as identical evidence snapshot |
| TC-06 | AC-4 | baseline/candidate manifest refs present | paired identity accepted |
| TC-07 | AC-4/9 | baseline manifest missing | INCONCLUSIVE |
| TC-08 | AC-4/9 | candidate manifest missing | INCONCLUSIVE |
| TC-09 | AC-5 | known-bad baseline | miss reproduced |
| TC-10 | AC-6 | known-bad candidate | detect/stop + influenced_decision |
| TC-11 | AC-7 | negative control | no false-positive block |
| TC-12 | AC-8 | evaluator computes fixture-tree delta within allowed_paths | allowed |
| TC-13 | AC-8/10 | evaluator computes extra changed path outside allowed_paths | fail-closed |
| TC-13b | AC-8 | Candidate JSON falsely declares narrower/clean delta | ignored; evaluator-derived tree delta remains authority |
| TC-14 | AC-9 | prevention evidence PASS | machine-readable PASS |
| TC-15 | AC-9 | evidence unavailable | INCONCLUSIVE |
| TC-16 | AC-10 | candidate changes sealed fixture | fail-closed |
| TC-17 | AC-10 | evaluation plan digest mismatch | INCONCLUSIVE |
| TC-18 | AC-10 | activation=fired, required=influenced_decision | INCONCLUSIVE |
| TC-19 | AC-11 | ExperimentResult -> projection | candidate/result/evidence refs preserved |
| TC-20 | AC-12 | PASS result | no merge/promotion side effect |
| TC-21 | AC-13 | PR review evidence | Legacy run-evidence schema unchanged |
| TC-22 | AC-13 | PR review evidence | scripts/ai-loop/** unchanged |
| TC-23 | AC-14 | same fixture + same inputs | deterministic serialized result |
| TC-24 | AC-15 | full vertical slice | source -> candidate -> delta -> evidence -> decision |
| TC-25 | safety | raw transcript / prompt / secret fields | rejected / absent |
| TC-26 | safety | network / GitHub mutation primitive scan | none in ratchet.py |
| TC-27 | regression | full repository tests | PASS |

## Mutation requirements

最低限次の mutant を kill する。

1. `allowed_paths` subset check を削除
2. activation level check を `fired` へ弱める
3. evaluation_plan_digest comparison を削除
4. negative control を評価対象から外す
5. baseline/candidate manifest missing を PASS 扱い
6. `pattern_id` だけで snapshot 同一判定
7. candidate declaration を actual delta として採用

## Fixture design

`verification-skipped` は positive / negative の両側を必須にする。

- known-bad: required verification evidence missing
- negative-control: required verification evidence present

「known-bad を止めた」だけでは PASS にしない。
正常ケースを通せることまで確認する。


## Boundary tests

- PromotionDecision projection は #811 authoritative schema として保存しない。
- development fixture が PlanGateBench / Incident Regression Set の正本一覧を自動変更しない。
- TA 番号は実装直前に next-free を再確認し、番号そのものを contract にしない。