# TEST CASES — TASK-1381 / #1381

| ID | AC | Input / Mutation | Expected |
|---|---|---|---|
| TC-01 | AC-1 | failure instance with run_id/event_ref/failure_record_ref/run_evidence_ref | immutable source binding accepted |
| TC-02 | AC-1 | same fingerprint, different event_ref | distinct failure instances |
| TC-03 | AC-2 | source bundle -> candidate | source refs preserved |
| TC-04 | AC-3 | pattern snapshot | classifier_digest + source_set_digest required |
| TC-04b | AC-1/3 | Candidate tampers source_set_digest | evaluator recomputes from stable failure refs; mismatch -> INCONCLUSIVE / fail-closed |
| TC-04c | AC-1 | failure_record_ref / run_evidence_ref does not match canonical fixture payload digest | source binding rejected |
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
| TC-17 | AC-10 | Candidate evaluation_plan_digest differs from evaluator-owned sealed evaluation-plan.json digest | INCONCLUSIVE |
| TC-17b | AC-10 | Candidate supplies self-consistent plan/threshold differing from sealed evaluation plan | ignored / rejected; Candidate cannot choose judge |
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
8. Candidate の evaluation_plan_digest を evaluator-owned plan から再計算せず採用
9. source_set_digest を failure_instance_refs から再計算せず採用
10. failure_record_ref / run_evidence_ref を source payload から再計算せず採用

## Fixture design

`verification-skipped` は positive / negative の両側を必須にする。

- known-bad: required verification evidence missing
- negative-control: required verification evidence present

「known-bad を止めた」だけでは PASS にしない。
正常ケースを通せることまで確認する。


## Boundary tests

- PromotionDecision projection は #811 authoritative schema として保存しない。
- development fixture が PlanGateBench / Incident Regression Set の正本一覧を自動変更しない。
- `evaluation-plan.json` は evaluator-owned / sealed。Candidate payload から plan / threshold を上書きできない。
- fixture source payload refs と source_set_digest は evaluator が deterministic に再計算する。
- TA 番号は実装直前に next-free を再確認し、番号そのものを contract にしない。

## Governance / sequencing cases

| ID | Gate | Input / State | Expected |
|---|---|---|---|
| TC-28 | Delivery-before-Evolution | #870 Delivery E2E evidence missing | runtime implementation NO-GO; no `scripts/ai-loop-v2/**` creation |
| TC-29 | I4 invalidation | first runtime PR adds `scripts/ai-loop-v2/` | M-2 changes from baseline; PR classified as I1 exception invalidation candidate |
| TC-30 | Semantic invalidation | evaluator mechanically emits PASS/FAIL/INCONCLUSIVE | reviewer must answer semantic enforcement=yes; indeterminate => yes |
| TC-31 | Separation of authority | runtime implementation PR attempts to edit canon 7 to preserve I1 exception | invalid; separate canon review path required |

These are implementation-entry review cases, not runtime unit tests. Evidence is recorded in PR checklist / review record per #1329.
