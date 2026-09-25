# TEST CASES — TASK-1392 / #1392

> 2026-09-25: idempotency removed from the first slice (Human decision R-046). The former ST-21a〜m / 21d2 / 21e2 / 21f2 / 42 (replay, transaction_id, digest) are withdrawn; see `review-external.md` for their history.

| ID | Condition | Expected |
|---|---|---|
| ST-01 | create_run | revision=0, generation=1, event_seq=1 |
| ST-02 | valid transition expected revision N | revision=N+1 |
| ST-03 | two writers expected N | exactly one transition succeeds |
| ST-04 | stale writer | RevisionConflict + state revision unchanged |
| ST-05 | non-terminal conflict event | generation +1, conflict evidence appended |
| ST-05a | stale writer after terminal Outcome | reject with no new event/generation |
| ST-06 | harness ref drift request | reject |
| ST-07 | plan/source drift outside a Replan re-binding | reject (a re-binding per ST-43 is the only allowed change) |
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
| ST-21 | a committed request with a transition resent after its response was lost (same body, same token) | `STATE_CONFLICT`; its drafts are not appended a second time; conflict evidence recorded within the bound (R-046) |
| ST-21b | a committed **events-only** request resent (revision unchanged, `expected_revision` still equal) | `STATE_CONFLICT` because `expected_position` is stale; no second copy of its events (R-049; the original R-001) |
| ST-21q | a stale writer's conflict is recorded while a legitimate writer holds the current token | the legitimate commit still succeeds (`conflict` envelopes do not advance `position`) |
| ST-21r | token with a current revision but a stale position, or the reverse | `STATE_CONFLICT` (stale) |
| ST-21e | `create_run` resent after crash-after-replace | `RunAlreadyExists`, zero mutation; `load_run` shows the created Run (R-046) |
| ST-21g | conflicts at one revision exceed `MAX_CONFLICTS_PER_REVISION` | RevisionConflict `conflict_evidence="suppressed"`, zero mutation |
| ST-21h | `expected_revision` or `expected_position` greater than current | `InvalidExpectedRevision`, zero mutation, no conflict event |
| ST-21i | the same ahead request after the store reaches that revision | ordinary CAS: commits (R-048) |
| ST-21l | empty commit (no drafts, no transition) | reject, zero mutation |
| ST-21n | `create_run` / `commit` with a draft containing a binding key or an envelope key at top level | reject, zero mutation (R-047) |
| ST-21o | `create_run` with an invalid `run_id` or a `plan_event_draft` that is not `plan_contract_bound` | reject |
| ST-21p | `create_run` binds `harness_manifest_ref` / `plan_hash` / `source_sha` from the `binding` argument | the first event carries exactly those values (R-047) |
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
| ST-28c | file contains a stored `state` / `generation` / aggregate key or an envelope key other than `kind` / `events` (snapshot_ref recomputed) | strict load reject (unknown key) |
| ST-28d | bound context changes within the stream other than at a valid re-binding (snapshot_ref recomputed) | strict load reject |
| ST-28e | envelope tamper: empty envelope / first envelope not `create` with `plan_contract_bound` / `conflict` envelope holding anything but one `state_conflict` / `state_conflict` outside a `conflict` envelope | strict load reject |
| ST-28f | non-transition or `state_conflict` event carries a revision other than the folded one (snapshot_ref recomputed) | strict load reject |
| ST-28g | stored `state_transitioned` edge outside the first-slice allowlist, e.g. EXECUTING -> REPAIRING with consistent from_state/+1 | strict load reject |
| ST-28i | accidental corruption (snapshot_ref not recomputed) | load reject. A hostile writer who recomputes `snapshot_ref` is out of scope (Trust limit, R-031) |
| ST-28k | `state_conflict` with `actual_revision` / `actual_position` ≠ fold, or a recorded token that is not stale | strict load reject (R-030 / R-049) |
| ST-30 | commit whose result would exceed `MAX_EVENTS_PER_RUN` or `MAX_SNAPSHOT_BYTES` | `SnapshotCapacityExceeded` before temp write, zero mutation |
| ST-30a | snapshot within `TERMINAL_RESERVE` of a bound, Run in `VERIFYING` | non-terminal commit rejected; terminal `decision_made` still commits |
| ST-30b | ENOSPC during temp write | old snapshot authoritative, stale temp handled as ST-20 |
| ST-30c | terminal `decision_made` larger than `MAX_DECISION_EVENT_BYTES` | rejected by #1391 payload validation (not by the capacity check) |
| ST-30d | stale conflicts arriving near the bound | conflict recorded only outside the reserve, otherwise `suppressed`; the terminal Decision still commits afterwards (R-032) |
| ST-31 | flush primitive unavailable (macOS `F_FULLFSYNC` fails / unsupported platform) | fail closed (`runtime_unwritable`), no fallback to plain `fsync`, old snapshot intact |
| ST-32 | commit latency at the size bound on the CI runner | within the threshold fixed by the fixture; a miss is a Replan trigger |
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
| ST-38 | stored stream violating any of ST-33〜37 / 45 (snapshot_ref recomputed) | strict load reject |
| ST-39 | lock file replaced between open and flock | `runtime_path_changed`, fail closed, no commit |
| ST-40 | unexpected sibling (e.g. random-named temp) in `runtime_root` | reject under lock |
| ST-41 | envelope key at a RunEvent's top level, or a RunEvent top-level key in the envelope | reject (commit and load) |
| ST-43 | `commit(rebinding=B)` in `REPLANNING` with `event_drafts[0]` = `plan_contract_bound`, then `REPLANNING -> PLAN_VERIFYING` | commit; later events carry the new `plan_hash` / `source_sha`; load accepts |
| ST-43a | re-binding outside `REPLANNING` / a second re-binding in the same visit / `harness_manifest_ref` change / `rebinding` without a leading `plan_contract_bound` draft or the reverse | reject (commit and load) |
| ST-43b | one transaction `[plan_contract_bound(new), other event]` + `REPLANNING -> PLAN_VERIFYING` | re-binding event and every later event (incl. the trailing `state_transitioned`) carry the new binding; #1391 `validate_append` and projection accept it (dependency R-043) |
| ST-44 | caller draft of type `state_transitioned` or `state_conflict` (create and commit) | reject, zero mutation (R-039) |
| ST-44a | stored stream with a `state_transitioned` that is not the last event of its envelope, or two in one envelope | strict load reject (R-039) |
| ST-45 | terminal or non-terminal `decision_made` with `decided_in_state` = EXECUTING / REPAIRING / REPLANNING / PLAN_VERIFYING | reject (commit and load) (R-041) |
| ST-46 | stale writer's `state_conflict` recorded between building a Decision input and committing it | Decision rejected by input freshness; rebuilt input commits (R-042 residual) |
| ST-29 | full repository test | PASS |

## Fault matrix invariant

For every injected crash point, recovery must produce exactly one of:
- complete old snapshot
- complete new snapshot

Never a mixed snapshot.

## No-duplicate invariant

A request that already committed can never commit again: every successful commit advances `position`, so resending it carries a stale `expected_position` and is rejected by the CAS, with or without a transition.

## Concurrency invariant

The linearization point is atomic replace under the run lock.
