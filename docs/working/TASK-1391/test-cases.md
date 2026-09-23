# TEST CASES — TASK-1391 / #1391

## Event envelope

| ID | Condition | Expected |
|---|---|---|
| EV-01 | valid minimum event | accepted |
| EV-02 | accepted stream contains duplicate event_ref / same content | invalid stream; idempotent retry must have been absorbed by #1392 before append |
| EV-03 | duplicate event_ref / different content | invalid / reject tamper |
| EV-04 | event_seq decreases | reject |
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
| RF-02 | future ref | reject |
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
