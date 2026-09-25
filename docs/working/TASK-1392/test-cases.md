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
| ST-21 | new transaction_id, same expected revision after committed transition | conflict, no duplicate transition |
| ST-21a | exact retry (same transaction_id + request) of a committed transition | `replayed=true`, current snapshot, no new event/generation/revision |
| ST-21b | exact retry of a committed transaction **without** transition (events only) | `replayed=true`, no second event |
| ST-21c | same transaction_id, different request | `TransactionIdReuse`, zero mutation |
| ST-21d | exact retry of a request that produced a conflict | same RevisionConflict / conflict event_ref, no second `state_conflict` |
| ST-21e | exact create_run retry after crash-after-replace | `replayed=true`, no second snapshot write |
| ST-21f | exact retry of the terminal-decision transaction after terminality | `replayed=true` (lookup precedes terminal rejection) |
| ST-21g | conflicts at one revision exceed `MAX_CONFLICTS_PER_REVISION` | RevisionConflict `conflict_evidence="suppressed"`, zero mutation |
| ST-21h | `expected_revision` greater than current | `InvalidExpectedRevision`, zero mutation, no conflict event |
| ST-21i | suppressed request resent unchanged after the store advances | conflict (stale), never commits |
| ST-21j | two concurrent exact-retry-shaped requests with one new transaction_id | exactly one commit, the other `replayed=true` |
| ST-21k | create_run on existing Run with a new transaction_id / same transaction_id different request | reject / `TransactionIdReuse` |
| ST-21l | empty commit (no drafts, no transition) | reject, zero mutation |
| ST-21m | replay result | returns the transaction's own ledger entry (event_seq range, result_revision), not only the current snapshot |
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
| ST-28b | first-slice create_run with `lifecycle_state != PLAN_VERIFYING` | reject |
| ST-28c | stored `state.lifecycle_state` / `revision` differs from the `state_transitioned` fold (snapshot_ref recomputed) | strict load reject |
| ST-28d | stored `harness_manifest_ref` / `plan_hash` / `source_sha` differs from the events' bound context (snapshot_ref recomputed) | strict load reject |
| ST-28e | ledger tamper: duplicate transaction_id / gap or overlap in event_seq ranges / `generation != len(transactions)` / first entry not `create` / `conflict` entry covering a non-`state_conflict` event | strict load reject |
| ST-28f | non-transition or `state_conflict` event carries a revision other than the folded one (snapshot_ref recomputed) | strict load reject |
| ST-28g | stored `state_transitioned` edge outside the first-slice allowlist, e.g. EXECUTING -> REPAIRING with consistent from_state/+1 | strict load reject |
| ST-28h | ledger `result_revision` differs from the fold | strict load reject |
| ST-29 | full repository test | PASS |

## Fault matrix invariant

For every injected crash point, recovery must produce exactly one of:
- complete old snapshot
- complete new snapshot

Never a mixed snapshot.

## Idempotency invariant

For any transaction_id, the stream contains that transaction's events at most once, however many times the exact request is retried.

## Concurrency invariant

The linearization point is atomic replace under the run lock.
