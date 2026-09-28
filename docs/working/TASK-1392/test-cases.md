# TEST CASES — TASK-1392 / #1392

> 2026-09-25: idempotency removed from the first slice (Human decision R-046). The former ST-21a〜m / 21d2 / 21e2 / 21f2 / 42 (replay, transaction_id, digest) are withdrawn; see `review-external.md` for their history.

| ID | Condition | Expected |
|---|---|---|
| ST-01 | create_run | `lifecycle_state=PLAN_VERIFYING`, revision=0, position=1, generation=1, event_seq=1 |
| ST-01a | `load_run` before any Run exists | `RunNotFound` (R-066) |
| ST-02 | valid transition with token (N, P) | revision=N+1, position=P+1 |
| ST-03 | two writers with the same token (N, P) | exactly one commit succeeds |
| ST-04 | stale writer | RevisionConflict + state revision unchanged |
| ST-05 | non-terminal conflict event | generation +1, conflict evidence appended |
| ST-05a | stale writer after terminal Outcome | `RunTerminal`, no new event/generation |
| ST-06 | `rebinding` that changes `harness_manifest_ref` | reject (commit and load) |
| ST-07 | `rebinding` outside `REPLANNING` (the only request path that could change `plan_hash` / `source_sha`) | reject; see ST-43a for the full set |
| ST-08 | transition target / stored `to_state` = BLOCKED | reject (commit and load) |
| ST-09 | transition target / stored `to_state` = NO_PROGRESS | reject (commit and load) |
| ST-10 | transition target / stored `to_state` = MERGE_READY | reject (commit and load) |
| ST-11 | event gap/invalid append | reject before durable replace |
| ST-12 | snapshot_ref tamper | reject |
| ST-13 | event tamper | reject |
| ST-14 | duplicate JSON key | reject |
| ST-14a | invalid UTF-8 / unknown `schema_version` | reject |
| ST-15 | NaN/Infinity | reject |
| ST-16 | path traversal run id | reject |
| ST-16a | file `run_id` differs from the file name / events' `run_id` | strict load reject |
| ST-17 | snapshot symlink | reject |
| ST-17a | lock file is a symlink | reject (no-follow open) |
| ST-18 | crash before replace (after `.pending.tmp` only / after the pending replace / after its directory flush) | old snapshot only; the leftover `.pending.tmp` or pending marker matching the old ref is removed on the next call, no halt (R-087) |
| ST-18a | pending marker write or its directory flush fails | `RuntimeUnwritable`, zero mutation, nothing replaced |
| ST-18b | resolving a pending marker that matches the old ref, and the directory flush after its removal fails | `RuntimeUnwritable`, the call does not proceed; `RuntimeUnwritable` is in #1395's stop class, so the next resolution happens only after a Human handles the stop (R-085) |
| ST-18e | resolving a new-ref pending marker, and writing the halt marker fails | `RunHalted` (reason `DURABILITY_UNKNOWN` from the pending marker); every later call halts again from the leftover pending marker (R-091) |
| ST-18f | pending marker present, no snapshot, `old_snapshot_ref` not null | `RunHalted` (the snapshot disappeared after the replace) |
| ST-18c | `create_run` crash with `old_snapshot_ref = null`: before the replace / after the replace | no snapshot → pending removed, create may proceed / snapshot present → `RunHalted` |
| ST-18d | conflict recording crashes after its replace, before step 14 | next call returns `RunHalted` (pending applies to conflict recording, R-086) |
| ST-19 | crash after a successful step 14 and pending removal, before API return | new snapshot authoritative; no halt |
| ST-19b | crash after replace, before step 14 succeeds (pending marker present with the new ref) | next operation writes `DURABILITY_UNKNOWN` and returns `RunHalted` (R-077) |
| ST-19c | step 14 succeeds, crash before the pending marker is removed | next operation halts (conservative; documented) |
| ST-19d | pending marker unreadable / symlink | halted (R-077 / R-078) |
| ST-19a | writer crashes after replace, before the directory fsync; then `load_run` | `load_run` never returns that snapshot: the pending marker halts the Run (as ST-19b); `load_run` does not flush the directory itself (R-089) |
| ST-19e | step 14 succeeds, the directory flush after removing the pending marker fails | the commit returns success; if a crash then undoes the removal, the next call halts (R-085) |
| ST-20 | stale temp file | deterministic cleanup/ignore under lock |
| ST-21 | a committed request with a transition resent after its response was lost (same body, same token) | `STATE_CONFLICT`; its drafts are not appended a second time; conflict evidence recorded within the bound (R-046) |
| ST-21b | a committed **events-only** request resent (revision unchanged, `expected_revision` still equal) | `STATE_CONFLICT` because `expected_position` is stale; no second copy of its events (R-049; the original R-001) |
| ST-21q | a stale writer's conflict is recorded while a legitimate writer holds the current token | the legitimate commit still succeeds (`conflict` envelopes do not advance `position`) |
| ST-21r | token with a current revision but a stale position, or the reverse | `STATE_CONFLICT` (stale) |
| ST-21e | `create_run` resent after its response was lost: (a) crash after step 14 and pending removal / (b) crash between replace and step 14 | (a) `RunAlreadyExists`, zero mutation; `load_run` shows the created Run / (b) `RunHalted` via the pending marker (R-046 / R-077) |
| ST-21g | conflicts at one position exceed `MAX_CONFLICTS_PER_POSITION` | RevisionConflict `conflict_evidence="suppressed"`, zero mutation |
| ST-21g2 | a long run of non-transition commits at one revision, with conflicts between them | conflicts are recorded again after each new position (cap counted per position, R-056) |
| ST-21h | `expected_revision` or `expected_position` greater than current, including mixed tokens such as (R+1, P−1) | `InvalidExpectedRevision`, zero mutation, no conflict event; the Run still loads (R-055) |
| ST-21s | (withdrawn with R-060: #1392 has no landed-check rule; recovery is #1395's re-derivation from the stream) | — |
| ST-21t | `plan_contract_bound` payload binding values differ from the `binding` / `rebinding` argument | reject (R-047) |
| ST-21i | the same ahead request after the store reaches that token (revision and position) | ordinary CAS: commits (R-048) |
| ST-21l | empty commit (no drafts, no transition) | reject, zero mutation |
| ST-21n | `create_run` / `commit` with a draft containing a binding key or an envelope key at top level | reject, zero mutation (R-047) |
| ST-21o | `create_run` with an invalid `run_id` or a `plan_event_draft` that is not `plan_contract_bound` | reject |
| ST-21p | `create_run` binds `harness_manifest_ref` / `plan_hash` / `source_sha` from the `binding` argument | the first event carries exactly those values (R-047) |
| ST-22 | multiple non-state events one transaction | contiguous event_seq; revision unchanged |
| ST-23 | non-terminal transition + other events | state_transitioned is transaction-final event and carries new revision |
| ST-23a | terminal decision + state transition request | reject before commit |
| ST-23c | terminal `decision_made` followed by another draft in the same transaction | reject before commit (terminal decision must be the final event) |
| ST-23b | terminal decision only | commit without RunState revision increment |
| ST-24 | terminal stream then append | reject through #1391 |
| ST-25 | direct event writer duplicated in #1392 | static boundary FAIL |
| ST-26 | merge/promotion primitive | static boundary FAIL |
| ST-27 | unsupported state edge, e.g. EXECUTING -> REPAIRING | reject |
| ST-28 | transition to/from WAITING_* without resume contract | reject in first slice |
| ST-28a | (merged into ST-28c: a non-null `pending_action` is not representable in model B; any key that could carry it is an unknown key) | — |
| ST-28c | file contains a stored `state` / `generation` / aggregate key or an envelope key other than `kind` / `events` (snapshot_ref recomputed) | strict load reject (unknown key) |
| ST-28d | bound context changes within the stream other than at a valid re-binding (snapshot_ref recomputed) | strict load reject |
| ST-28e | envelope tamper: unknown `kind` value / empty envelope / first envelope not `create` with `plan_contract_bound` / `conflict` envelope holding anything but one `state_conflict` / `state_conflict` outside a `conflict` envelope | strict load reject |
| ST-28f | non-transition or `state_conflict` event carries a revision other than the folded one (snapshot_ref recomputed) | strict load reject |
| ST-28g | stored `state_transitioned` edge outside the first-slice allowlist, e.g. EXECUTING -> REPAIRING with consistent from_state/+1 | strict load reject |
| ST-28i | accidental corruption (snapshot_ref not recomputed) | load reject. A hostile writer who recomputes `snapshot_ref` is out of scope (Trust limit, R-031) |
| ST-28k | `state_conflict` with `actual_revision` / `actual_position` ≠ fold, or a recorded token that is not stale | strict load reject (R-030 / R-049) |
| ST-30 | commit whose result would exceed `MAX_EVENTS_PER_RUN` or `MAX_SNAPSHOT_BYTES` | `SnapshotCapacityExceeded` before temp write, zero mutation |
| ST-30a | snapshot within `TERMINAL_RESERVE` of a bound, Run in `VERIFYING` | non-terminal commit rejected; terminal `decision_made` still commits |
| ST-30b | ENOSPC during temp write | `RuntimeUnwritable`; old snapshot authoritative, stale temp handled as ST-20 |
| ST-30c | terminal `decision_made` larger than `MAX_DECISION_EVENT_BYTES` | rejected by #1391 payload validation (not by the capacity check) |
| ST-30e | file just outside the reserve; a small non-terminal commit would end inside it, then a maximum-size terminal Decision | the non-terminal commit is rejected (judged after appending); the terminal Decision commits (R-057) |
| ST-30d | stale conflicts arriving near the bound | conflict recorded only outside the reserve, otherwise `suppressed`; the terminal Decision still commits afterwards (R-032) |
| ST-31 | temp-file flush fails or the primitive is unavailable (macOS `F_FULLFSYNC` / unsupported platform) before replace | fail closed (`runtime_unwritable`), no fallback to plain `fsync`, old snapshot intact |
| ST-31a | directory flush fails after replace (step 14) | `DurabilityUnknown`; the result is in the stop class, not re-derived (R-067) |
| ST-32 | commit latency at the size bound on the CI runner | within the threshold fixed by the fixture; a miss is a Replan trigger |
| ST-32a | `load_run` latency at the size bound, alone and with concurrent readers | within the fixture threshold; a miss is a Replan trigger (R-068) |
| ST-47 | lock held longer than `LOCK_WAIT_TIMEOUT` | `create_run` / `commit` / `load_run` / `halt_run` return `RuntimeBusy` without reading or writing the snapshot (only the lock file may have been created) (R-068) |
| ST-47a | read-only `runtime_root` | `load_run` fails closed (`RuntimeUnwritable`) |
| ST-48 | halt marker present | `create_run` / `commit` / `load_run` return `RunHalted` with its reason; the snapshot is neither read nor written (R-071) |
| ST-48a | directory flush fails after replace (commit or create) | the `DURABILITY_UNKNOWN` marker is written before `DurabilityUnknown` is returned; every later call, including `load_run`, returns `RunHalted` (R-075) |
| ST-48l | `halt_run` keeps getting `RuntimeBusy` (lock holder hung) | after `MAX_HALT_BUSY_RETRIES`, #1395 raises to a Human and does not resume the Run (R-092) |
| ST-50 | structural: every open / read / write / replace / unlink / flush in `create_run`, `commit` (incl. conflict recording), pending resolution, `load_run` and `halt_run` goes through the one descriptor opened at the start of the call (spy on the file-system layer) | no path-based access; one descriptor per call (R-090) |
| ST-50a | optional, Linux ≥ 4.13 with an error-injecting device: Run B's flush consumes an error caused by Run A's replace, then A runs step 14 | A observes the error → `DurabilityUnknown` (OS behaviour; not part of the default suite, per Durability definition) |
| ST-48b | `halt_run(RUN_MISSING)` for a `run_id` with no snapshot, then `create_run` | `RunHalted`; the Run cannot be silently recreated (R-073) |
| ST-48c | writing the halt marker itself fails after a step-14 failure | `DurabilityUnknown` is still returned; the pending marker keeps the Run halted on the next call (ST-19b) |
| ST-48d | `halt_run` when a marker already exists, and two concurrent `halt_run` calls | the first marker is kept; both calls succeed |
| ST-48e | halt marker is corrupt / a dangling symlink / only `.halt.tmp` exists | `RunHalted` (reason `UNREADABLE` when unparseable); presence decided by `lstat` (R-078) |
| ST-48f | `halt_run` acquires the lock between another caller's lock wait and its commit | the commit sees the marker after taking the lock and returns `RunHalted`; no commit lands after a halt (R-079) |
| ST-48g | `halt_run` with an unknown reason / on a read-only root / with a replaced lock inode | `ValidationRejected` / `RuntimeUnwritable` / `RuntimePathChanged` (R-080) |
| ST-48h | a Human removes the marker after following the unhalt procedure | the next call proceeds; removal is followed by a directory flush (R-081; operator procedure, checked by the handoff review, not by #1392 code) |
| ST-48i | halt marker and a new-ref pending marker both present; the Human removes only the halt marker | the next call resolves the pending marker and halts again; removing both per the procedure lets the Run proceed (R-084) |
| ST-48j | `halt_run` while a pending marker is present | `halt_run` does not resolve the pending marker, writes (or keeps) the halt marker and returns success (R-084) |
| ST-48k | halt marker and pending marker both present, any other call | `RunHalted` from the halt marker; the pending marker is not touched (halt is checked first) |
| ST-49a (#1395 handoff) | `RunNotFound` for a run_id that #1395 has received a successful `create_run` or `load_run` for | `halt_run(RUN_MISSING)`, never `create_run` (R-082; checked in #1395's tests) |
| ST-49 | every #1392 outcome, including an unexpected exception | maps to exactly one row of the #1395 table (re-derive / retry same call / create / stop); the table has a default stop row (R-072) |
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
| ST-39 | lock file replaced between open and flock (commit, create_run, load_run, halt_run) | `runtime_path_changed`, fail closed, no mutation |
| ST-39a | `runtime_root` moved and replaced by a copy after the descriptor was opened, before the lock check | `RuntimePathChanged`, zero mutation; two writers cannot both commit with the same token (R-095) |
| ST-18g | only `.pending.tmp` exists and the directory flush after removing it fails | `RuntimeUnwritable`, the call does not proceed (R-097) |
| ST-40 | unexpected file with this Run's `<safe-run-id>.` prefix other than `.lock` / `.json` / `.json.tmp` / `.halt` / `.halt.tmp` / `.pending` / `.pending.tmp` (e.g. a random-named temp); `halt_run` still succeeds in that state | reject under lock; another Run's files in the same `runtime_root` do not affect this Run |
| ST-41 | envelope key at a RunEvent's top level, or a RunEvent top-level key in the envelope | reject (commit and load) |
| ST-43 | `commit(rebinding=B)` in `REPLANNING` with `event_drafts[0]` = `plan_contract_bound`, then `REPLANNING -> PLAN_VERIFYING` | commit; later events carry the new `plan_hash` / `source_sha`; load accepts |
| ST-43a | re-binding outside `REPLANNING` / a second re-binding in the same visit / `harness_manifest_ref` change / `rebinding` without a leading `plan_contract_bound` draft or the reverse | reject (commit and load) |
| ST-43b | one transaction `[plan_contract_bound(new), other event]` + `REPLANNING -> PLAN_VERIFYING` | re-binding event and every later event (incl. the trailing `state_transitioned`) carry the new binding; #1391 `validate_append` and projection accept it (dependency R-043) |
| ST-44 | caller draft of type `state_transitioned` or `state_conflict` (create and commit) | reject, zero mutation (R-039) |
| ST-44a | stored stream with a `state_transitioned` that is not the last event of its envelope, or two in one envelope | strict load reject (R-039) |
| ST-45 | terminal or non-terminal `decision_made` with `decided_in_state` = EXECUTING / REPAIRING / REPLANNING / PLAN_VERIFYING | reject (commit and load) (R-041) |
| ST-46 | stale writer's `state_conflict` recorded between building a Decision input and committing it | Decision rejected by input freshness with zero mutation (R-042 residual; rebuilding the input is #1395's) |
| ST-29 | full repository test | PASS |

## Fault matrix invariant

For every injected crash point (including the pending-marker stages and the conflict-recording path), recovery must produce exactly one of:
- complete old snapshot
- complete new snapshot
- `RunHalted` with `DURABILITY_UNKNOWN` (the Human decides; never a silently returned snapshot of unknown durability)

Never a mixed snapshot (R-088).

## No-duplicate invariant

A request that already committed can never commit again **with the same token**: every successful commit advances `position`, so resending it carries a stale `expected_position` and is rejected by the CAS, with or without a transition. Resending with a re-read token is outside #1392's guarantee (#1395 re-derives instead, R-060).

## Concurrency invariant

The linearization point is atomic replace under the run lock.
