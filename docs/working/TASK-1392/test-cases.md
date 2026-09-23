# TEST CASES — TASK-1392 / #1392

| ID | Condition | Expected |
|---|---|---|
| ST-01 | create_run | revision=0, generation=1, event_seq=1 |
| ST-02 | valid transition expected revision N | revision=N+1 |
| ST-03 | two writers expected N | exactly one transition succeeds |
| ST-04 | stale writer | RevisionConflict + state revision unchanged |
| ST-05 | non-terminal conflict event | generation +1, conflict evidence appended |
| ST-05a | stale writer after terminal Outcome | reject with no new event/generation |
| ST-06 | harness ref drift request | reject |
| ST-07 | plan/source drift | reject |
| ST-08 | state=BLOCKED | reject |
| ST-09 | state=NO_PROGRESS | reject |
| ST-10 | state=MERGE_READY | reject |
| ST-11 | event gap/invalid append | reject before durable replace |
| ST-12 | snapshot_ref tamper | reject |
| ST-13 | event tamper | reject |
| ST-14 | duplicate JSON key | reject |
| ST-15 | NaN/Infinity | reject |
| ST-16 | path traversal run id | reject |
| ST-17 | snapshot symlink | reject |
| ST-18 | crash before replace | old snapshot only |
| ST-19 | crash after replace before API return | new snapshot recoverable |
| ST-20 | stale temp file | deterministic cleanup/ignore under lock |
| ST-21 | retry same expected revision after committed transition | conflict, no duplicate transition |
| ST-22 | multiple non-state events one transaction | contiguous event_seq; revision unchanged |
| ST-23 | non-terminal transition + other events | state_transitioned is transaction-final event and carries new revision |
| ST-23a | terminal decision + state transition request | reject before commit |
| ST-23b | terminal decision only | commit without RunState revision increment |
| ST-24 | terminal stream then append | reject through #1391 |
| ST-25 | direct event writer duplicated in #1392 | static boundary FAIL |
| ST-26 | merge/promotion primitive | static boundary FAIL |
| ST-27 | unsupported state edge, e.g. EXECUTING -> REPAIRING | reject |
| ST-28 | transition to/from WAITING_* without resume contract | reject in first slice |
| ST-28a | non-null pending_action | reject as unsupported first-slice input |
| ST-29 | full repository test | PASS |

## Fault matrix invariant

For every injected crash point, recovery must produce exactly one of:
- complete old snapshot
- complete new snapshot

Never a mixed snapshot.

## Concurrency invariant

The linearization point is atomic replace under the run lock.
