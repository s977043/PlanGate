# TEST CASES — TASK-1391 / #1391

## Event envelope

| ID | Condition | Expected |
|---|---|---|
| EV-01 | valid minimum event | accepted |
| EV-02 | accepted stream contains duplicate event_ref / same content | invalid stream; idempotent retry must have been absorbed by #1392 before append |
| EV-03 | duplicate event_ref / different content | invalid / reject tamper |
| EV-04 | event_seq decreases | reject |
| EV-04a | event_seq jumps from N to N+2 | invalid gap |
| EV-04b | first accepted event_seq is not 1 | invalid |
| EV-05 | event_seq duplicate for different event | invalid |
| EV-05a | producer draft tries to supply authoritative event_seq/event_ref | reject draft |
| EV-05b | #1392 assigns next event_seq then #1391 finalizes | accepted |
| EV-05c | recomputed canonical event_ref differs from stored ref | invalid |
| EV-06 | revision differs while event_seq advances | allowed when event type permits |
| EV-07 | harness_manifest_ref changes mid-run | reject |
| EV-08 | unknown terminal/state taxonomy value | reject |
| EV-09 | raw transcript / secret field | reject |
| EV-10 | unknown critical payload field | reject/fail closed |

## Reference integrity

| ID | Condition | Expected |
|---|---|---|
| RF-01 | decision input refers to earlier evidence | accept |
| RF-02 | future ref in candidate append | reject before commit |
| RF-02a | #1392 attempts commit without validate_append | boundary/static failure |
| RF-03 | missing ref | reject |
| RF-04 | same ref registered twice by different artifacts | reject |

## Projection

| ID | Condition | Expected |
|---|---|---|
| PJ-01 | same stream twice | same semantic projection |
| PJ-02 | unfinished stream | evidence_status=partial |
| PJ-03 | valid terminal stream | evidence_status=ready |
| PJ-04 | readable binding mismatch | evidence_status=invalid |
| PJ-04a | malformed JSON / unusable envelope | reject; no RunEvidence fabricated |
| PJ-05 | multiple terminal outcomes | invalid |
| PJ-06 | event after terminal outcome | invalid |
| PJ-07 | MERGE_READY + Stop Reason | invalid |
| PJ-08 | HUMAN_ESCALATED without Stop Reason | invalid |
| PJ-09 | BLOCKED without Stop Reason | invalid |
| PJ-10 | producer includes evidence_status=ready | cannot override receiver |

## Privacy / trust

| ID | Condition | Expected |
|---|---|---|
| PV-01 | hidden CoT/raw transcript | reject |
| PV-02 | credential/secret value | reject |
| PV-03 | evidence uses refs instead of raw log body | accept |
| PV-04 | unsupported field only exists to bypass validator | reject |

## Boundary tests

| ID | Condition | Expected |
|---|---|---|
| BD-01 | #1391 writes persistent runtime JSONL itself | design violation |
| BD-02 | projection reads current Git/environment/time | design violation |
| BD-03 | RunState CAS logic appears in #1391 | design violation |
| BD-04 | Decision logic appears in #1391 | design violation |
| BD-05 | Legacy run-evidence schema modified | reject scope |

## Mutation targets

At minimum:
1. allow duplicate ref with different content
2. event_seq == revision assumption
3. accept harness drift
4. accept post-terminal event
5. accept HUMAN_ESCALATED without reason
6. accept MERGE_READY with reason
7. trust producer evidence_status
8. allow unknown payload keys
9. drop reference-integrity check
10. make projection depend on wall clock

## Revision 2 / Phase 1B 追加（RED。`3331e5c4` で FAIL することを確認してから GREEN）

`EV-02` の期待値は R-002 により「#1392 は CAS で再送を拒否する。stream に同一内容が現れたら invalid」と読み替える。

### Event

| ID | 由来 | Condition | Expected |
|---|---|---|---|
| EV-11 | R-001 | 2 本目の `plan_contract_bound` で plan_hash / source_sha が変わる | accepted（新セグメント） |
| EV-12 | R-001 | 2 本目の bound で `harness_manifest_ref` が変わる | invalid |
| EV-13 | R-001 | `contract_bound_seq` が直前の bound の seq と異なる | invalid |
| EV-13a | R-001 / R-013 | bound 無しで binding（plan_hash）だけが途中で変わる | invalid（binding drift 単体） |
| EV-14 | R-003 | draft の payload（ネスト含む）に binding キー | reject draft |
| EV-15 | R-003 | `bound_context` 以外から binding 値を渡す | reject |
| EV-16 | R-004 | bound に `loop_contract_ref` / `required_verifiers` 欠落・空・重複 | reject |
| EV-17 | R-005 | `failure.verification_ref` 欠落 / future / missing | reject |
| EV-18 | R-006 | convergence に `observed_artifact_ref` 欠落 | reject |
| EV-19 | R-006 | 5 フィールドのいずれかが値域外 / freshness フィールドを持つ | reject |
| EV-20 | R-008 | blocker snapshot の `blockers` 重複 / 非 list / ref 欠落 | reject |
| EV-21 | R-010 | decision に `input_last_event_seq` / `contract_bound_seq` / `decided_in_state` 欠落 | reject |
| EV-22 | R-010 | `inputs` 件数 > `MAX_INPUT_REFS` / payload > `MAX_DECISION_EVENT_BYTES`（#1393 から import） | reject at append |
| EV-23 | R-010 | `inputs` が latest prior decision より前の ref だけ | reject |
| EV-24 | R-011 | `state_transitioned` / `state_conflict` が #1392 定義と不一致 | reject |
| EV-25 | R-013 | 2 イベントが同じ registered ref（verification id 等）を登録 | invalid |
| EV-26 | R-013 | 同一 event_seq が 2 件 | invalid |
| EV-27 | R-013 | 既存 stream の 1 件をそのまま再 append（replay） | invalid |
| EV-28 | R-013 | `outcome=MERGE_READY` かつ policy `DENIED` 等の Outcome 矛盾 | invalid（具体的組合せは RED で凍結） |

### Projection

| ID | 由来 | Condition | Expected |
|---|---|---|---|
| PJ-04b | R-012 | 空 list / 非 list / 非 object 要素 | 例外で reject、RunEvidence を返さない |
| PJ-11 | R-007 | `policy_verdict_recorded` を含む stream | `policy_verdicts[]` がイベントから導出される |
| PJ-12 | R-009 | bound 無しで terminal decision（inputs:[]） | invalid（`ready` にならない）。旧実装で `ready` になることを実行再現 |
| PJ-13 | R-009 | `required_verifiers` の一部に結果が無い terminal | invalid |
| PJ-14 | R-009 | 最新セグメントの bound 前の verification しか無い | invalid |
| PJ-15 | R-013 | producer が payload に `evidence_status=ready` を入れる | reject（未知キー）、receiver 判定のみ |

### Mutation targets（追加）

11. 2 本目の bound を binding drift として扱う（EV-11 で検出）
12. 2 本目の bound で manifest 変化を許す（EV-12）
13. draft の binding キーを許す（EV-14）
14. `policy_verdicts` を `[]` に戻す（PJ-11）
15. `ready` 判定から bound 先行条件を外す（PJ-12）
16. `ready` 判定から required_verifiers 充足を外す（PJ-13）
17. MAX_* の append 時再検査を外す（EV-22）
18. 使用不能入力を `invalid` で返す（PJ-04b）
