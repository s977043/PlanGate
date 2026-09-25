# EXECUTION PLAN — TASK-1392 / #1392

## Current verdict

```text
Plan: GO
Production implementation: after #1391 consumable
Persistence model: single atomic snapshot, model B (Human decision R-017, 2026-09-25):
  stores accepted RunEvents grouped in #1392 transaction envelopes;
  RunState, generation and the idempotency index are derived on load, never stored
```

## Storage layout

Trusted caller supplies a runtime root. #1392 first slice does not discover repo/Git/common-dir.

```text
<runtime-root>/
  <safe-run-id>.lock
  <safe-run-id>.json
```

Run ID grammar:
`RUN-[A-Z0-9][A-Z0-9_-]{0,63}`

No caller-supplied filename.

### CAS guarantee scope

The lock domain is the `runtime_root` the caller passes. **CAS, idempotency and the conflict bound hold only among callers that pass the same `runtime_root`.** Two callers that pass different roots for the same `run_id` get independent locks and snapshots, and both commits can succeed (split-brain); this slice neither detects nor prevents that.

Consequences:
- API docs and the handoff state this limit; no document may describe this slice alone as "durable CAS for a Run" without the qualifier
- **before the first production adapter** (the first caller outside tests) consumes this API, a follow-up must add a Git common-dir resolver (as TASK-1025 plan did) and a test that the primary checkout and a linked worktree resolve to the same lock domain. That follow-up is a precondition of the adapter, not of this slice

## Snapshot

```json
{
  "schema_version": "2",
  "run_id": "RUN-...",
  "transactions": [
    {
      "transaction_id": "TXN-...",
      "kind": "create | commit | conflict",
      "expected_revision": 0,
      "transition": null,
      "events": [ { "...": "accepted #1391 RunEvent, unchanged" } ]
    }
  ],
  "snapshot_ref": "sha256:..."
}
```

`snapshot_ref` = canonical hash of the file excluding `snapshot_ref`.

**Only two kinds of data are stored** (model B, R-017):

| stored | owner | meaning |
|---|---|---|
| RunEvents inside `events` | #1391 (type, payload validation, `event_ref`); `state_transitioned` / `state_conflict` payloads #1392 | the append-only event stream (canon §3). The stream is the concatenation of all envelopes' `events` in order |
| transaction envelope fields (`transaction_id`, `kind`, `expected_revision`, `transition`) | **#1392** (persistence metadata) | which events were committed together, and the request fields that are not recoverable from the events. Per kind: `create` — `expected_revision` and `transition` are null; `commit` — `expected_revision` is the revision the request was checked against and `transition` is the requested transition or null; `conflict` — both null (the conflict's numbers live only in the `state_conflict` payload, so there is no second copy) |

The envelope never adds top-level keys to a RunEvent, and a RunEvent never carries envelope keys at its top level (R-021 ownership boundary; ST-41 checks top-level keys only — a `state_conflict` payload legitimately contains `transaction_id`).

**Derived on every load, never stored** (so there is no second truth to drift, removing the class behind R-002 / R-005 / R-020):

| derived value | derivation |
|---|---|
| RunState (`lifecycle_state`, `revision`, bindings, `pending_action=null`, `policy_verdict=null`) | fold over the stream (see Strict loading) |
| `generation` | number of envelopes |
| per-transaction result (`first_event_seq`, `last_event_seq`, `result_revision`) | from the envelope's events and the fold |
| replay index `transaction_id -> request_digest` | only `create` / `commit` envelopes. The digest is recomputed from stored data only: the envelope (`kind`, `run_id`, `expected_revision`, `transition`) plus the event drafts recovered from the envelope's events — excluding the #1392-generated trailing `state_transitioned` — by removing the #1391 binding keys (`run_id`, `event_seq`, `revision`, `harness_manifest_ref`, `plan_hash`, `source_sha`, `event_ref`) |
| conflicted `transaction_id` set | the `transaction_id` of each `conflict` envelope. No digest is kept for conflicts (Human decision R-029: conflicts are outside replay) |

[Dependency] draft recovery requires `strip(finalize_event(d)) == d` for every valid draft `d`, i.e. #1391 `finalize_event` adds **only** the binding keys above and does not canonicalize the draft's own content. This is a #1391 consumability condition (todo Preflight; ST-42). A draft that already contains a binding key is rejected at commit, so the round trip cannot be ambiguous.

Canon: RunState remains the canonical mutable, revision-CAS artifact of `artifact-responsibilities.md`; model B changes only its physical representation (CAS is realised by appending a `state_transitioned` event under the lock and replacing the file atomically). The canon §4 wording is revised in the same PR.

## Commit protocol

### Transaction identity

Every mutating call carries a caller-supplied `transaction_id`:
`TXN-[A-Z0-9][A-Z0-9_-]{0,63}`

`request_digest` = canonical hash of exactly the data the replay index can recompute:
`kind`, `run_id`, `expected_revision`, `transition`, `event_drafts` (for create_run: `kind=create`, `run_id`, `plan_event_draft`; there is no `initial_state` input — the initial state is a fold constant).

Under the lock, **before** the expected_revision check:

| lookup | result |
|---|---|
| `transaction_id` in the replay index, same `request_digest` | **exact retry**: return the current snapshot with `replayed=true` and the derived result of that envelope. No new event, no new envelope, no state change |
| `transaction_id` in the replay index, different `request_digest` | reject `TransactionIdReuse`. Zero mutation |
| `transaction_id` in the conflicted set | **no replay** (conflicts are outside idempotency, R-029). Evaluate the request normally: its `expected_revision` was stale when the conflict was recorded and revisions only increase, so it is stale again — return a live RevisionConflict (current `actual_revision`, the recorded conflict's `event_ref`) with zero mutation. A request with a different body under a conflicted `transaction_id` is rejected `TransactionIdReuse` without comparing digests |
| absent | proceed normally |

The lookup runs before the revision check because an exact retry after a successful commit necessarily carries a stale `expected_revision`. This is the layer that TASK-1391 plan delegates to #1392 ("exact retry ... does **not** append a second event").

A `transaction_id` is consumed by the commit or by the recorded conflict it produced. A caller that wants to retry with a new `expected_revision` uses a new `transaction_id`. A request answered with `suppressed` (Conflict evidence bound) or `InvalidExpectedRevision` is not recorded and so does not consume its `transaction_id`; it cannot later commit unchanged, because its `expected_revision` is already behind (suppressed) or can never be current (see below).

Trust limit (R-031): `snapshot_ref` is an unkeyed hash. It detects accidental corruption, not tampering by an actor who can write `runtime_root` and recompute it — e.g. renaming an events-only envelope's `transaction_id` and then resending the original request appends its drafts again. This is the same limit as pbi-input "Trust limit"; ST-28i covers corruption, not a hostile writer.

Relation to canon §4 (`artifact-responsibilities.md`: "mismatch -> STATE_CONFLICT"): replay is **re-delivery of the response of a request that already committed**, identified only by the same `transaction_id` and the same `request_digest`. It is not a CAS retry. Any other request carrying a stale `expected_revision` — including an identical payload under a new `transaction_id` — is a CAS mismatch and gets `STATE_CONFLICT` as canon §4 requires. API docs and tests (ST-21 vs ST-21a) keep the two apart.

### create_run

Under exclusive lock:

1. if a snapshot exists: apply the Transaction identity lookup (exact create retry after a crash-after-replace returns `replayed=true`); otherwise reject
2. the Run starts at revision 0 in `PLAN_VERIFYING` (first-slice create rule; the transition allowlist has no edge out of `PLANNING`, so a Run created in `PLANNING` could never progress). This is a fold constant, not a stored value
3. allocate event_seq=1
4. #1391 validates/finalizes plan_contract_bound event
5. #1391 validate_append([], event)
6. build the file with one envelope `kind=create`
7. atomic_replace(snapshot)

### commit_events

Input:
- run_id
- transaction_id
- expected_revision
- EventDrafts
- optional state transition request

Under exclusive lock:

1. strict load current snapshot
2. validate snapshot_ref + #1391 accepted stream
2a. Transaction identity lookup (may return replay / live RevisionConflict for a conflicted id / TransactionIdReuse here)
2c. reject any draft that contains a #1391 binding key or an envelope key at its top level
2b. reject an empty request (no event drafts and no transition) with zero mutation; every envelope holds at least one event
3. require expected_revision == derived current revision
4. allocate exact next event_seq values
5. bind current run/manifest/plan/source context
6. #1391 finalize each draft
7. #1391 validate_append against growing in-memory stream
8. inspect finalized drafts for Terminal Outcome:
   - if any draft contains terminal `decision_made.outcome != null`, `transition` must be absent
   - terminal decision must be the final event of the transaction
8a. apply the Decision-bound checks (see Decision-bound transitions): `decided_in_state`, `input_last_event_seq`, and the transition derived from `(lifecycle_state, action)`
9. if non-terminal state transition requested:
   - validate from_state/current revision
   - increment revision exactly +1
   - append `state_transitioned` as final event of transaction
   - event-level `revision` is the **new revision**; earlier events in the same transaction retain the pre-transition revision
10. build the new file = old envelopes + one envelope `kind=commit` holding this transaction's events
11. write temp in same directory, at the fixed name `<safe-run-id>.json.tmp` (no random names; any other sibling in `runtime_root` is rejected, so ST-20 cleanup is deterministic)
12. flush + fsync temp
13. `os.replace(temp, target)`
14. fsync parent directory
15. return committed snapshot

No successful response before step 15 (parent-directory fsync complete).

## Revision conflict

If `expected_revision > current revision`: reject `InvalidExpectedRevision` with zero mutation and no conflict event. A revision ahead of the store cannot come from a correct caller; recording it as a conflict would let the same request commit once the store catches up.

If `expected_revision < current revision`:
- do not apply requested drafts/state transition
- if the Run is still non-terminal, append a `state_conflict` evidence event in a separate atomic snapshot commit using actual current revision and next event_seq
- if the Run is already terminal, do not append after terminality; return terminal/stale error without mutating the snapshot
- raise/return RevisionConflict containing conflict event_ref
- state revision remains unchanged
- conflict recording adds one envelope `kind=conflict` (`expected_revision` and `transition` null) for the failed request's `transaction_id`, holding exactly the `state_conflict` event; its payload (#1392-owned) carries `transaction_id`, `expected_revision`, `actual_revision` and no digest. Strict load checks `payload.transaction_id == envelope.transaction_id`, `actual_revision == folded revision`, `expected_revision < actual_revision` (R-030)

This preserves conflict evidence without pretending the failed mutation committed.

### Conflict evidence bound

Unbounded conflict recording would let a looping stale writer grow the event stream and snapshot without limit.

- **per transaction**: at most one `state_conflict` per `transaction_id` (resending a conflicted request gets a live RevisionConflict with no new event; see Transaction identity)
- **terminal reserve** (R-032): a conflict is recorded only if the resulting file stays outside `TERMINAL_RESERVE`; otherwise the answer is `suppressed` with zero mutation. Conflict evidence can never consume the space kept for the terminal Decision
- **per revision**: at most `MAX_CONFLICTS_PER_REVISION` `state_conflict` events while the state stays at one revision. Beyond the cap, return RevisionConflict with `conflict_evidence="suppressed"` and zero mutation. The cap being reached is itself visible from the recorded conflicts at that revision
- the constant's value is fixed by the RED fixture (provisional: 8); it is a first-slice limit, not a canon value

## Crash semantics

Fault injection labels:

- after temp open
- after temp write
- after temp fsync
- before replace
- after replace
- after directory fsync

Expected:
- before replace: old snapshot remains authoritative; stale temp ignored/cleaned under lock
- after replace: new snapshot authoritative
- recovery never composes fields from old/new
- successful API response only after directory fsync

No separate WAL is required because the whole Run (events and envelopes) is one replace unit.

## Durability definition

"fsync" in the commit protocol means the platform's strongest available flush, per platform:

| platform | file flush | directory flush | if unavailable |
|---|---|---|---|
| Linux | `os.fsync(fd)` | `os.fsync(dirfd)` | fail closed (`runtime_unwritable`) before replace |
| macOS | `fcntl(fd, F_FULLFSYNC)` | `fcntl(dirfd, F_FULLFSYNC)` | fail closed; plain `fsync` is **not** accepted as a fallback |
| other | unsupported | unsupported | fail closed at `create_run` |

What a successful response guarantees: the new snapshot survives process crash and OS crash. Power loss is covered only to the extent the storage device honours the flush above; this slice does not claim more. Fault injection (Crash semantics) covers the process-crash points; OS / power-loss behaviour is out of test scope and stated as a residual risk in the handoff.

## Size and cost bound

Every commit rewrites the whole snapshot, so write volume and latency grow with the Run's history. First-slice bounds (values provisional, fixed by RED / performance fixtures):

- `MAX_EVENTS_PER_RUN` (provisional 2048) and `MAX_SNAPSHOT_BYTES` (provisional 8 MiB)
- a commit whose resulting snapshot would exceed either bound is rejected with `SnapshotCapacityExceeded` **before the temp file is written**, with zero mutation
- **terminal reserve**: non-terminal commits are rejected once the snapshot is within `TERMINAL_RESERVE` of either bound. A fixed reserve alone does not prove that a terminal Decision fits, so the reserve is **derived, not guessed**: `TERMINAL_RESERVE >= 1 event and >= MAX_DECISION_EVENT_BYTES + envelope overhead`, where `MAX_DECISION_EVENT_BYTES` is the maximum canonical encoded size of a `decision_made` event. [Dependency] #1391 / #1393 must bound the `decision_made` payload (e.g. the number of `event_ref` it lists) so that the maximum exists; until then the reserve is provisional and the guarantee "a full Run can always commit its terminal outcome" is **not claimed**. A terminal Decision larger than the reserve is rejected by #1391 payload validation, not by the capacity check (ST-30c). Scope of the guarantee (R-033): a terminal `decision_made` is accepted only in the Decision states (`VERIFYING` / `DIAGNOSING` / `PR_CONVERGING`, #1393 I-1). A Run that reaches the reserve in another state (e.g. `EXECUTING`) cannot make the mechanical transition that would lead to a Decision state, so it cannot terminate through a Decision; #1395's budget must stop such a Run before the bound, and this residual is stated in the handoff
- temp space: the store needs free space for one extra snapshot; ENOSPC during temp write is a pre-replace failure (old snapshot stays authoritative)
- performance fixture: commit latency at the bound on the CI runner; the threshold is fixed with the fixture (provisional p95 ≤ 200 ms). Missing the threshold is a **Replan trigger** (compaction or WAL slice), not a reason to relax the bound

## Strict loading

- UTF-8
- duplicate JSON keys reject
- NaN / Infinity reject
- unknown keys reject
- symlink target/lock reject where platform supports no-follow checks
- snapshot_ref mismatch reject
- file `run_id` / event run binding mismatch reject
- event stream (concatenation of envelopes' `events`) invalid by #1391 `validate_stream` => snapshot invalid
- **envelope structure**: at least one envelope; the first is `kind=create` holding exactly the `plan_contract_bound` event; every envelope holds at least one event; `transaction_id` values are unique; a `conflict` envelope holds exactly one `state_conflict` event and nothing else, and a `state_conflict` appears only in a `conflict` envelope; per-kind null rules for `expected_revision` / `transition` (Snapshot table); **`transition` is non-null if and only if** the envelope's last event is a `state_transitioned`, and then they match (R-030)
- **conflict consistency** (R-030): `state_conflict.payload.transaction_id == envelope.transaction_id`, `actual_revision == folded revision`, `expected_revision < actual_revision`
- **fold** (the only source of RunState): start from the create rule (`PLAN_VERIFYING`, revision 0, bindings from `plan_contract_bound`); every non-transition event and `state_conflict` must carry `revision == running`; `state_transitioned` must carry `running+1`, have `from_state == running state`, and be an edge of the First-slice transition allowlist (re-checked on every load, not only at commit time); bound context changes only as allowed by Replan re-binding (below), otherwise it must not change; each `commit` envelope's `expected_revision` equals the running revision at its start
- **Decision-bound re-check**: every `decision_made` in the stored stream passes the Decision-bound checks against the folded state at its position (`decided_in_state`, `event_seq == input_last_event_seq + 1`, derived transition and the bare-edge rule), so a stream that was valid only because a check was skipped at commit time is rejected on load

Payload ownership: TASK-1391 plan lists "state/conflict evidence consumed from #1392", so the `state_transitioned` / `state_conflict` payloads (`from_state`, `to_state`, `revision`; `transaction_id`, expected/actual revision) are **owned by #1392**. The event type names are frozen together with #1391 (#1402's draft uses `state_conflict_recorded` and has no `state_transitioned`; R-022) and frozen by #1392's RED fixtures. #1391 validates them as stream members (binding, sequence, terminality); #1392 does not re-own any other event type (ST-25 static boundary still applies). The TASK-1391 RunEvidence projection does not carry Lifecycle State, so this state fold is #1392's.

## Locking

POSIX first slice:
- per-run lock file, opened no-follow from a `runtime_root` dirfd
- `fcntl.flock(LOCK_EX)`
- after acquiring the lock, re-open the lock path from the same dirfd and compare `(st_dev, st_ino)` with the locked fd; on mismatch release and fail closed (`runtime_path_changed`), as TASK-1025 plan did. Without this, a lock file replaced between open and flock lets two writers hold locks on different inodes and both pass CAS (ST-39)
- lock held across load -> validate -> build -> replace -> dir fsync
- lock file is not Run truth

If runtime platform lacks required locking/fsync semantics, fail closed rather than silently weakening.

## Integration API

Proposed:

```python
create_run(runtime_root, transaction_id, plan_event_draft) -> CommitResult
load_run(runtime_root, run_id) -> Snapshot
commit(
    runtime_root,
    run_id,
    transaction_id,
    expected_revision,
    event_drafts,
    transition=None,
) -> CommitResult
```

`Snapshot` is the loaded view: the derived RunState, the event stream and the derived per-transaction results. `CommitResult = {snapshot, replayed: bool, transaction}` where `transaction` is the derived result of the request's own envelope (`generation`, `first_event_seq`, `last_event_seq`, `result_revision`). `replayed=true` means the request had already committed and nothing was written; `snapshot` is then the current one and may be ahead of the transaction, so callers read their own outcome and event refs from `transaction`, not from `snapshot.state`.

No CLI in this slice.

## Implementation placement and static coverage

- TA numbers: use **ta-94 or later** (main has ta-88; open PRs and the sweep plan hold ta-88〜93). Re-check `tests/extras/` on main and open PRs just before exec
- relation to PR #1402 (Human decision R-023, 2026-09-25): #1402's `scripts/ai-loop-v2/run_state.py` (multi-file + journal) is **excluded from #1402**; this plan is the owner of RunState persistence and #1402's delivery code consumes the #1392 API instead
- the module location must be one that the static checks actually scan: `scripts/ai-loop-v2/` is outside ta-70 `_T70_DIRS` and `check_exec_boundary.py` today, so ST-25 / ST-26 would pass vacuously there. Before exec, either extend those checks to the chosen directory or place the module where they already apply (with the TC-E9 plugin allowlist / sync declaration that `scripts/ai-loop/` requires). Extending the checks may touch HO paths (`scripts/hooks/*.sh`, `.github/workflows/*`); if so that part is Human-applied
- a positive control is required for ST-25 / ST-26: inject a forbidden symbol and confirm the check fails

## Tests

- CAS concurrent two writers
- stale expected revision
- conflict event recorded without state revision change
- exact retry (with and without transition) returns replay, no second event
- transaction_id reuse with a different request rejected
- conflict evidence bound (per transaction / per revision)
- no stored RunState / generation / ledger aggregate (a stored `state` key is an unknown key)
- digest round trip: `strip(finalize(d)) == d`; drafts with binding keys rejected
- conflicted transaction_id: live conflict, no replay, no second event
- Replan re-binding
- envelope tamper (structure, metadata vs recomputed digest)
- envelope keys never appear inside RunEvents and vice versa
- harness/plan/source drift forbidden
- state enum forbidden values
- crash matrix old-or-new
- temp residue recovery
- snapshot tamper
- duplicate JSON
- symlink/path traversal
- no merge/promotion symbols
- #1391 contract reuse; no event logic copy


## Terminal transaction rule

Terminal Outcome belongs to the event/evidence axis, not RunState.

A transaction that commits terminal `decision_made`:
- does not increment RunState revision solely to represent terminality
- does not append a `state_transitioned` event after it
- leaves the last non-terminal Lifecycle State as historical state, while terminal Outcome is derived from event stream/RunEvidence
- is final for the Run; later `commit` calls are rejected by #1391 terminality validation


## First-slice transition allowlist

Do not infer an unrestricted transition graph from the Lifecycle State enum.

For this slice:

```text
PLAN_VERIFYING -> EXECUTING | REPLANNING
EXECUTING      -> VERIFYING
VERIFYING      -> DIAGNOSING | PR_CONVERGING
DIAGNOSING     -> REPAIRING | REPLANNING
REPAIRING      -> VERIFYING
REPLANNING     -> PLAN_VERIFYING
PR_CONVERGING  -> REPAIRING
```

A terminal Decision does not transition to a terminal state.

WAITING_HUMAN / WAITING_EXTERNAL remain canonical Lifecycle State values, but this first slice does not create or resume them because the pending-action contract is not implemented. Transition requests to/from WAITING_* are rejected rather than guessed.

### Decision-bound transitions

Requested by #1393 (PR #1407 comments, 2026-09-25; adversarial reviews R3 / Rev2-R1〜R3). The allowlist alone accepts any listed edge, so a Decision of `DIAGNOSING` could be followed by a commit of `VERIFYING -> PR_CONVERGING`. By Human decision #1393 does not carry `next_state`; **#1392 derives the transition from `(lifecycle_state, action)` and checks it.** #1392 reads four `decision_made` payload keys — `decided_in_state`, `action`, `outcome`, `input_last_event_seq` — and contains no Decision logic.

Decision-bound edges (action values per `artifact-responsibilities.md`: continue / repair / replan / stop; `stop` is terminal and follows the Terminal transaction rule):

| from_state | continue | repair | replan |
|---|---|---|---|
| VERIFYING | PR_CONVERGING | DIAGNOSING | — (reject) |
| DIAGNOSING | — (reject) | REPAIRING | REPLANNING |
| PR_CONVERGING | no transition | REPAIRING | — (reject) |

Mechanical edges (no `decision_made`, unchanged): `PLAN_VERIFYING -> EXECUTING | REPLANNING`, `EXECUTING -> VERIFYING`, `REPAIRING -> VERIFYING`, `REPLANNING -> PLAN_VERIFYING`. First-slice Decisions are not accepted in `PLAN_VERIFYING` (#1393 I-1).

`commit()` rejects with zero mutation when:

1. **state binding**: any `decision_made` (terminal or not) has `decided_in_state` different from the folded `lifecycle_state` at its position. `decide()` is pure and cannot read RunState, so `decided_in_state` is the caller's claim; without this check a Run in `DIAGNOSING` could be decided as `VERIFYING` and skip DIAGNOSING's FailureRecord / replan / NO_PROGRESS rules
2. **input freshness**: a `decision_made` is assigned `event_seq != payload.input_last_event_seq + 1`. No event of any kind — from another writer or earlier in the same transaction — may sit between the input and the Decision. `verification_recorded` does not change the revision, so the revision CAS alone cannot catch a FAIL recorded after the input was built. Consequence: a `decision_made` is the first event of its transaction, followed only by its `state_transitioned` if any
3. **derived transition**: a transaction with a non-terminal `decision_made` requests a `transition` other than the table's result for `(decided_in_state, action)`, including a transition where the table says "no transition", or the table says "reject"
4. **bare decision-bound edge**: a `transition` on a Decision-bound edge without a `decision_made` in the same transaction
5. **one Decision per transaction**: more than one `decision_made` in a transaction

All five are re-checked on load (Strict loading). Exact retry of a Decision transaction is still answered by the Transaction identity lookup before these checks.

[Dependency] The `decision_made` payload keys are frozen by #1391 (TASK-1391 has not frozen them yet; #1393 lists them in its `decision_to_event_draft`). #1392's RED fixtures use those keys only after that agreement.

### Replan re-binding

Human decision R-034 (2026-09-25). The first slice allows `REPLANNING -> PLAN_VERIFYING`, and a Replan produces a new Plan (canon: LoopContract gets a new revision on Replan), so the binding must be able to change there — otherwise the new Plan is rejected by the bound-context check.

- while the folded state is `REPLANNING`, a transaction may contain **one** re-binding `plan_contract_bound` event. It sets new `plan_hash` / `source_sha` (and the LoopContract reference that #1393 expects from #1391) for every later event; `harness_manifest_ref` cannot change (a different Harness is a new Run)
- the re-binding event carries the current revision like any non-transition event; the transaction may end with `REPLANNING -> PLAN_VERIFYING`
- outside `REPLANNING`, a `plan_contract_bound` event after the first is rejected; a second re-binding in the same `REPLANNING` visit is rejected
- the fold switches the bindings at that event, and strict load re-checks all of the above
- [Dependency] #1391 must allow `plan_contract_bound` as a re-binding event (not only as the first event). #1393's plan already assumes "#1391 `plan_contract_bound` (and its re-binding after Replan)"

### Initial state and PLANNING

`create_run` takes no initial-state input and always starts at `PLAN_VERIFYING` (a fold constant): its first event is `plan_contract_bound`, so a Plan already exists (taxonomy: PLANNING = Plan being written, PLAN_VERIFYING = initial Plan under verification). `PLANNING` stays a canonical Lifecycle State value and is **not** removed from canon. A later slice that owns durable planning (planning-time events, incomplete Plan, binding updates) adds `PLANNING -> PLAN_VERIFYING` and a create path starting at `PLANNING`; until then such a request is rejected (ST-28b). Residual limit: a Run cannot be resumed from the middle of Plan writing.


## pending_action scope

The RunState field exists in canon, but the first owner-backed Delivery paths do not need Human/External waiting.

For this slice:
- persisted `pending_action` must be null
- non-null pending_action is rejected as unsupported
- WAITING_* transitions are unsupported

A later dedicated waiting/resume slice must define pending_action shape and transition evidence before enabling these states.
