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
| ST-08 | transition target / stored `to_state` = BLOCKED | reject (commit and load) |
| ST-09 | transition target / stored `to_state` = NO_PROGRESS | reject (commit and load) |
| ST-10 | transition target / stored `to_state` = MERGE_READY | reject (commit and load) |
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
| ST-21d | resend of a request that produced a conflict (same transaction_id, same body) | live RevisionConflict (current `actual_revision`, recorded conflict `event_ref`), no second `state_conflict`, no replay (R-029) |
| ST-21d2 | different body under a conflicted transaction_id (including one with a now-current `expected_revision`) | live RevisionConflict, zero mutation; never commits (R-037) |
| ST-21f2 | `create_run` retried under the same transaction_id with a different `plan_hash` | never `replayed=true` (digest differs) → `TransactionIdReuse`; a `plan_event_draft` containing a binding key is rejected (R-038) |
| ST-21e | exact create_run retry after crash-after-replace | `replayed=true`, no second snapshot write (digest recomputed from the stored create envelope; there is no `initial_state` input) |
| ST-21e2 | exact retry of a commit with `transition` | `replayed=true` (the trailing `state_transitioned` is excluded from draft recovery) |
| ST-21f | exact retry of the terminal-decision transaction after terminality | `replayed=true` (lookup precedes terminal rejection) |
| ST-21g | conflicts at one revision exceed `MAX_CONFLICTS_PER_REVISION` | RevisionConflict `conflict_evidence="suppressed"`, zero mutation |
| ST-21h | `expected_revision` greater than current | `InvalidExpectedRevision`, zero mutation, no conflict event |
| ST-21i | suppressed request resent unchanged after the store advances | conflict (stale), never commits |
| ST-21j | two concurrent exact-retry-shaped requests with one new transaction_id | exactly one commit, the other `replayed=true` |
| ST-21k | create_run on existing Run with a new transaction_id / same transaction_id different request | reject / `TransactionIdReuse` |
| ST-21l | empty commit (no drafts, no transition) | reject, zero mutation |
| ST-21m | replay result | returns the derived result of the transaction's own envelope (event_seq range, result_revision), not only the current snapshot |
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
| ST-28b | (removed: create_run has no initial-state input; the start state is a fold constant) | — |
| ST-28c | file contains a stored `state` / `generation` / ledger-aggregate key (model B stores none; snapshot_ref recomputed) | strict load reject (unknown key) |
| ST-28d | bound context (`harness_manifest_ref` / `plan_hash` / `source_sha`) changes within the stream (snapshot_ref recomputed) | strict load reject |
| ST-28e | envelope tamper: duplicate transaction_id / empty envelope / first envelope not `create` with `plan_contract_bound` / `conflict` envelope holding anything but one `state_conflict` / `state_conflict` outside a `conflict` envelope / `expected_revision` not equal to the folded revision at the envelope start | strict load reject |
| ST-28i | accidental corruption of a `commit` envelope's metadata (snapshot_ref not recomputed) | load reject. A hostile writer who recomputes `snapshot_ref` is out of scope (Trust limit, R-031) |
| ST-28j | `transition` non-null without a trailing `state_transitioned`, or a trailing `state_transitioned` with `transition` null / different | strict load reject (R-030) |
| ST-28k | conflict envelope: payload `transaction_id` ≠ envelope id / `actual_revision` ≠ fold / `expected_revision` ≥ `actual_revision` / non-null `expected_revision` or `transition` on the envelope | strict load reject (R-030) |
| ST-42 | `strip(finalize_event(d)) != d` for some valid draft (e.g. #1391 canonicalizes content) | #1391 not consumable (Preflight); a draft containing a binding key is rejected at commit |
| ST-43 | Replan re-binding: one `plan_contract_bound` in `REPLANNING` then `REPLANNING -> PLAN_VERIFYING` | commit; later events carry the new `plan_hash` / `source_sha`; load accepts |
| ST-43a | re-binding outside `REPLANNING` / a second re-binding in the same visit / `harness_manifest_ref` change | reject (commit and load) |
| ST-43b | one transaction `[plan_contract_bound(new), other event]` + `REPLANNING -> PLAN_VERIFYING` | re-binding event and every later event (incl. the trailing `state_transitioned`) carry the new binding; #1391 `validate_append` and projection accept it (dependency R-043) |
| ST-44 | caller draft of type `state_transitioned` or `state_conflict` | reject, zero mutation (R-039) |
| ST-44a | stored stream with a `state_transitioned` that is not the last event of its envelope, or two in one envelope | strict load reject (R-039) |
| ST-45 | terminal or non-terminal `decision_made` with `decided_in_state` = EXECUTING / REPAIRING / REPLANNING / PLAN_VERIFYING | reject (commit and load) (R-041) |
| ST-46 | stale writer's `state_conflict` recorded between building a Decision input and committing it | Decision rejected by input freshness; rebuilt input commits (R-042 residual) |
| ST-28f | non-transition or `state_conflict` event carries a revision other than the folded one (snapshot_ref recomputed) | strict load reject |
| ST-28g | stored `state_transitioned` edge outside the first-slice allowlist, e.g. EXECUTING -> REPAIRING with consistent from_state/+1 | strict load reject |
| ST-28h | (removed with model B: `result_revision` is derived, not stored) | — |
| ST-30 | commit whose result would exceed `MAX_EVENTS_PER_RUN` or `MAX_SNAPSHOT_BYTES` | `SnapshotCapacityExceeded` before temp write, zero mutation |
| ST-30a | snapshot within `TERMINAL_RESERVE` of a bound, Run in `VERIFYING` | non-terminal commit rejected; terminal `decision_made` still commits |
| ST-30d | stale conflicts arriving near the bound | conflict recorded only outside the reserve, otherwise `suppressed`; the terminal Decision still commits afterwards (R-032) |
| ST-30b | ENOSPC during temp write | old snapshot authoritative, stale temp handled as ST-20 |
| ST-31 | flush primitive unavailable (macOS `F_FULLFSYNC` fails / unsupported platform) | fail closed (`runtime_unwritable`), no fallback to plain `fsync`, old snapshot intact |
| ST-32 | commit latency at the size bound on the CI runner | within the threshold fixed by the fixture; a miss is a Replan trigger |
| ST-30c | terminal `decision_made` larger than `MAX_DECISION_EVENT_BYTES` | rejected by #1391 payload validation (not by the capacity check) |
| ST-39 | lock file replaced between open and flock | `runtime_path_changed`, fail closed, no commit |
| ST-40 | unexpected sibling (e.g. random-named temp) in `runtime_root` | reject under lock |
| ST-41 | envelope key at a RunEvent's top level, or a RunEvent top-level key in the envelope (payload contents such as `state_conflict.transaction_id` are not checked) | reject (commit and load) |
| ST-33 | `decision_made.decided_in_state` differs from the folded `lifecycle_state` (terminal and non-terminal) | reject, zero mutation (#1393 IT-01 / IT-02) |
| ST-34 | `decision_made` assigned `event_seq != input_last_event_seq + 1` by another writer's event | reject, zero mutation (#1393 IT-04) |
| ST-34a | `[verification_recorded FAIL, decision_made]` in one transaction | reject, zero mutation (#1393 IT-07 / IT-08) |
| ST-35 | VERIFYING + continue with `transition` to DIAGNOSING | reject |
| ST-35a | PR_CONVERGING + continue with any `transition` | reject |
| ST-35b | VERIFYING + replan / DIAGNOSING + continue | reject |
| ST-35c | each table cell with the matching `transition` | commit |
| ST-36 | `transition` VERIFYING -> PR_CONVERGING without `decision_made` in the transaction | reject |
| ST-36a | mechanical edge (e.g. EXECUTING -> VERIFYING) without `decision_made` | commit |
| ST-37 | two `decision_made` in one transaction | reject |
| ST-38 | stored stream violating any of ST-33〜37 (snapshot_ref recomputed) | strict load reject |
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
