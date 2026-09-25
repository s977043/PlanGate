# EXECUTION PLAN — TASK-1392 / #1392

## Current verdict

```text
Plan: GO
Production implementation: after #1391 consumable
Persistence model: single atomic snapshot, model B (Human decision R-017, 2026-09-25):
  stores accepted RunEvents grouped in #1392 transaction envelopes (kind only);
  RunState, generation and per-transaction results are derived on load, never stored
Idempotency: not in the first slice (Human decision R-046, 2026-09-25)
CAS token: expected_revision + expected_position (Human decision R-049), both derived
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

The caller supplies `run_id` (validated against the grammar); there is no caller-supplied filename.

### CAS guarantee scope

The lock domain is the `runtime_root` the caller passes. **CAS and the conflict bound hold only among callers that pass the same `runtime_root`.** Two callers that pass different roots for the same `run_id` get independent locks and snapshots, and both commits can succeed (split-brain); this slice neither detects nor prevents that.

Consequences:
- API docs and the handoff state this limit; no document may describe this slice alone as "durable CAS for a Run" without the qualifier
- **before the first production adapter** (the first caller outside tests) consumes this API, a follow-up must add a Git common-dir resolver (as TASK-1025 plan did) and a test that the primary checkout and a linked worktree resolve to the same lock domain. That follow-up is a precondition of the adapter, not of this slice

## Snapshot

```json
{
  "schema_version": "3",
  "run_id": "RUN-...",
  "transactions": [
    {
      "kind": "create | commit | conflict",
      "events": [ { "...": "accepted #1391 RunEvent, unchanged" } ]
    }
  ],
  "snapshot_ref": "sha256:..."
}
```

`snapshot_ref` = canonical hash of the file excluding `snapshot_ref`.

**Only two kinds of data are stored** (model B, R-017; envelope reduced by R-046):

| stored | owner | meaning |
|---|---|---|
| RunEvents inside `events` | #1391 (type, payload validation, `event_ref`); `state_transitioned` / `state_conflict` payloads #1392 | the append-only event stream (canon §3). The stream is the concatenation of all envelopes' `events` in order |
| envelope `kind` | **#1392** (persistence metadata) | which events were committed together, and whether they are a create, a commit or conflict evidence |

The envelope never adds top-level keys to a RunEvent, and a RunEvent never carries envelope keys at its top level (R-021 ownership boundary; ST-41 checks top-level keys only).

**Derived on every load, never stored** (so there is no second truth to drift, removing the class behind R-002 / R-005 / R-020):

| derived value | derivation |
|---|---|
| RunState (`lifecycle_state`, `revision`, bindings, `pending_action=null`, `policy_verdict=null`) | fold over the stream (see Strict loading) |
| `generation` | number of envelopes |
| `position` (CAS token, R-049) | number of `create` / `commit` envelopes; `conflict` envelopes are **not** counted |
| per-transaction result (`first_event_seq`, `last_event_seq`, the revision it was checked against, `result_revision`, its transition) | from the envelope's events and the fold |

Canon: RunState remains the canonical mutable, revision-CAS artifact of `artifact-responsibilities.md`; model B changes only its physical representation (CAS is realised by appending a `state_transitioned` event under the lock and replacing the file atomically). The canon §4 wording is revised in the same PR.

## Commit protocol

### Binding supply (R-047)

Binding values reach #1392 only through API arguments, never inside a draft:
- `create_run(..., run_id, binding, plan_event_draft)` — `binding = {harness_manifest_ref, plan_hash, source_sha}` plus the LoopContract reference once #1391 defines it
- `commit(..., rebinding=None)` — the new binding for a Replan re-binding (see Replan re-binding)

#1392 passes the binding in force at each event's position to #1391 `finalize_event(draft, bound_context, event_seq)` (TASK-1391 plan T6). Binding keys live only at the RunEvent top level (never inside a payload). A draft that contains a #1391 binding key or an envelope key at its top level is rejected, so there is exactly one channel.

### Retry after a lost response (no idempotency in the first slice)

Human decision R-046 (2026-09-25): the idempotency layer (`transaction_id`, replay, request digest) produced a new failure class in every C-2 round (R1〜R4) and is removed from the first slice.

The revision changes only on a state transition, so a revision-only CAS would let an **events-only** commit be resent and applied twice (the original R-001). Human decision R-049: every commit also carries `expected_position`, and `position` (the number of `create` / `commit` envelopes) grows by exactly one with every successful commit, transition or not.

- a resent request is evaluated like any other: if it already committed, its `expected_position` is now stale, so it gets `STATE_CONFLICT` (canon §4) and **its drafts are not appended a second time**, with or without a transition. This keeps TASK-1391 plan's requirement that an exact retry does not append a second event; the mechanism is the CAS, not a replay index
- `conflict` envelopes do not count toward `position`, so a stale writer's conflict evidence does not make a concurrent legitimate writer stale
- a caller that lost a response calls `load_run` and decides from the stream whether its transaction landed (#1395's responsibility; the first-slice caller is a single deterministic orchestrator)
- a resent `create_run` for an existing Run gets `RunAlreadyExists` with zero mutation; the caller loads and compares
- [Dependency] TASK-1391 plan:81 says "exact retry is handled at #1392 transaction/idempotency layer". It needs the wording "#1392's CAS on revision and position rejects it" (requested on #1391). A dedicated idempotency slice may add replay later

### create_run

Under exclusive lock:

0. validate `run_id` grammar and `binding`; reject a `plan_event_draft` that contains a #1391 binding key or an envelope key at its top level, or is not a `plan_contract_bound` draft
1. if a snapshot exists: reject `RunAlreadyExists` with zero mutation
2. the Run starts at revision 0 in `PLAN_VERIFYING` (first-slice create rule; the transition allowlist has no edge out of `PLANNING`, so a Run created in `PLANNING` could never progress). This is a fold constant, not a stored value
3. allocate event_seq=1
4. #1391 validates/finalizes the plan_contract_bound draft with `binding`
5. #1391 validate_append([], event)
6. build the file with one envelope `kind=create`
7. atomic_replace(snapshot)

### commit_events

Input:
- run_id
- expected_revision
- expected_position
- EventDrafts
- optional state transition request
- optional rebinding (Replan only)

Under exclusive lock:

1. strict load current snapshot
2. validate snapshot_ref + #1391 accepted stream
2a. reject an empty request (no event drafts and no transition) with zero mutation; every envelope holds at least one event
2b. reject any draft that contains a #1391 binding key or an envelope key at its top level
2c. reject any caller draft of a #1392-owned type (`state_transitioned`, `state_conflict`); only #1392 creates them (R-039)
3. compare `expected_revision` / `expected_position` with the derived current values (see Revision conflict); proceed only if both are equal
4. allocate exact next event_seq values
5. bind each event to the context the fold holds **at that event's position**: with `rebinding`, the re-binding `plan_contract_bound` and every later event in the transaction (including a trailing `state_transitioned`) carry the new binding (R-040)
6. #1391 finalize each draft
7. #1391 validate_append against growing in-memory stream
8. inspect finalized drafts for Terminal Outcome:
   - if any draft contains terminal `decision_made.outcome != null`, `transition` must be absent
   - terminal decision must be the final event of the transaction
8a. apply the Decision-bound checks (see Decision-bound transitions)
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

The CAS token is the pair (`expected_revision`, `expected_position`). Because `position` only grows and every revision change happens in a counted envelope, a request is either current (both equal), stale (at least one lower), or ahead (at least one higher).

If the request is **ahead**: reject `InvalidExpectedRevision` with zero mutation and no conflict event. An ahead token cannot come from a correct caller. If the store later reaches that token, the same request is an ordinary CAS and can commit; the error only says "not now" (R-048).

If the request is **stale**:
- do not apply requested drafts/state transition
- if the Run is still non-terminal and the Conflict evidence bound allows it, append a `state_conflict` evidence event in a separate atomic snapshot commit using actual current revision and next event_seq, in one envelope `kind=conflict` holding exactly that event; its payload (#1392-owned) carries `expected_revision`, `actual_revision`, `expected_position`, `actual_position`
- if the Run is already terminal, do not append after terminality; return terminal/stale error without mutating the snapshot
- raise/return RevisionConflict (`STATE_CONFLICT`) containing the conflict `event_ref`, or `conflict_evidence="suppressed"` when not recorded
- state revision remains unchanged

This preserves conflict evidence without pretending the failed mutation committed.

### Conflict evidence bound

Unbounded conflict recording would let a looping stale writer grow the event stream and snapshot without limit.

- **terminal reserve** (R-032): a conflict is recorded only if the resulting file stays outside `TERMINAL_RESERVE`; otherwise the answer is `suppressed` with zero mutation. Conflict evidence can never consume the space kept for the terminal Decision
- **per revision**: at most `MAX_CONFLICTS_PER_REVISION` `state_conflict` events while the state stays at one revision. Beyond the cap, return RevisionConflict with `conflict_evidence="suppressed"` and zero mutation. The cap being reached is itself visible from the recorded conflicts at that revision
- the constant's value is fixed by the RED fixture (provisional: 8); it is a first-slice limit, not a canon value
- without transaction identities, a resent stale request is recorded again (up to the per-revision cap)

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
- a crash after replace but before the response is observed by the caller as a lost response (see Retry after a lost response)

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
- **envelope structure**: at least one envelope; the first is `kind=create` holding exactly the `plan_contract_bound` event; every envelope holds at least one event; a `conflict` envelope holds exactly one `state_conflict` event and nothing else, and a `state_conflict` appears only in a `conflict` envelope; a `state_transitioned` appears **only** as the last event of a `commit` envelope and at most once per envelope (R-039)
- **conflict consistency** (R-030 / R-049): `actual_revision == folded revision`, `actual_position == folded position`, the recorded token is stale (`expected_revision <= actual_revision` and `expected_position <= actual_position`, at least one strictly lower)
- **fold** (the only source of RunState): start from the create rule (`PLAN_VERIFYING`, revision 0, bindings from the first `plan_contract_bound`); every non-transition event and `state_conflict` must carry `revision == running`; `state_transitioned` must carry `running+1`, have `from_state == running state`, and be an edge of the First-slice transition allowlist (re-checked on every load, not only at commit time); bound context changes only as allowed by Replan re-binding (below), otherwise it must not change
- **Decision-bound re-check**: every `decision_made` in the stored stream passes the Decision-bound checks against the folded state at its position, so a stream that was valid only because a check was skipped at commit time is rejected on load

Payload ownership: TASK-1391 plan lists "state/conflict evidence consumed from #1392", so the `state_transitioned` / `state_conflict` payloads (`from_state`, `to_state`, `revision`; expected/actual revision) are **owned by #1392**. The event type names are frozen together with #1391 (#1402's draft uses `state_conflict_recorded` and has no `state_transitioned`; R-022) and frozen by #1392's RED fixtures. #1391 validates them as stream members (binding, sequence, terminality); #1392 does not re-own any other event type (ST-25 static boundary still applies). The TASK-1391 RunEvidence projection does not carry Lifecycle State, so this state fold is #1392's.

Trust limit (R-031): `snapshot_ref` is an unkeyed hash. It detects accidental corruption, not tampering by an actor who can write `runtime_root` and recompute it. This is the same limit as pbi-input "Trust limit".

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
create_run(runtime_root, run_id, binding, plan_event_draft) -> CommitResult
load_run(runtime_root, run_id) -> Snapshot
commit(
    runtime_root,
    run_id,
    expected_revision,
    expected_position,
    event_drafts,
    transition=None,
    rebinding=None,
) -> CommitResult
```

`Snapshot` is the loaded view: the derived RunState, the event stream and the derived per-transaction results. `Snapshot` exposes the derived `revision` and `position` that the caller passes back as its CAS token. `CommitResult = {snapshot, transaction}` where `transaction` is the derived result of the envelope this call wrote (`generation`, `first_event_seq`, `last_event_seq`, `result_revision`).

No CLI in this slice.

## Implementation placement and static coverage

- TA numbers: use **ta-94 or later** (main has ta-88; open PRs and the sweep plan hold ta-88〜93). Re-check `tests/extras/` on main and open PRs just before exec
- relation to PR #1402 (Human decision R-023, 2026-09-25): #1402's `scripts/ai-loop-v2/run_state.py` (multi-file + journal) is **excluded from #1402**; this plan is the owner of RunState persistence and #1402's delivery code consumes the #1392 API instead
- the module location must be one that the static checks actually scan: `scripts/ai-loop-v2/` is outside ta-70 `_T70_DIRS` and `check_exec_boundary.py` today, so ST-25 / ST-26 would pass vacuously there. Before exec, either extend those checks to the chosen directory or place the module where they already apply (with the TC-E9 plugin allowlist / sync declaration that `scripts/ai-loop/` requires). Extending the checks may touch HO paths (`scripts/hooks/*.sh`, `.github/workflows/*`); if so that part is Human-applied
- a positive control is required for ST-25 / ST-26: inject a forbidden symbol and confirm the check fails

## Tests

- CAS concurrent two writers
- stale token; resent request after a lost response (events-only and with transition) gets STATE_CONFLICT and appends no drafts
- conflict event recorded without state revision change; conflict evidence bound (per revision / terminal reserve)
- binding supplied only by arguments; drafts with binding or envelope keys rejected (create and commit)
- no stored RunState / generation / aggregates (a stored `state` key is an unknown key)
- Replan re-binding
- envelope structure / tamper
- envelope keys never appear at RunEvent top level and vice versa
- harness/plan/source drift forbidden outside re-binding
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
6. **Decision states** (R-041): any `decision_made` (terminal or not) whose `decided_in_state` is not `VERIFYING` / `DIAGNOSING` / `PR_CONVERGING` (#1393 I-1). With check 1 this also rejects a Decision while the Run is in `EXECUTING`, `REPAIRING`, `REPLANNING` or `PLAN_VERIFYING`

All six are re-checked on load (Strict loading).

Residual (R-042): a stale writer's `state_conflict` recorded between building a Decision input and committing the Decision breaks check 2, so the legitimate Decision is rejected and #1395 must rebuild the input. This is the intended strictness of input freshness (no event of any kind in between); it is bounded by `MAX_CONFLICTS_PER_REVISION` and stated in the handoff.

[Dependency] The `decision_made` payload keys are frozen by #1391 (TASK-1391 has not frozen them yet; #1393 lists them in its `decision_to_event_draft`). #1392's RED fixtures use those keys only after that agreement.

### Replan re-binding

Human decision R-034 (2026-09-25). The first slice allows `REPLANNING -> PLAN_VERIFYING`, and a Replan produces a new Plan (canon: LoopContract gets a new revision on Replan), so the binding must be able to change there — otherwise the new Plan is rejected by the bound-context check.

- `commit(..., rebinding=B)` is accepted only while the folded state is `REPLANNING`, only once per `REPLANNING` visit, and only when `event_drafts[0]` is a `plan_contract_bound` draft; `rebinding` is non-null **if and only if** such a draft is present
- `B` sets new `plan_hash` / `source_sha` (and the LoopContract reference that #1393 expects from #1391); `harness_manifest_ref` cannot change (a different Harness is a new Run)
- the re-binding event carries the current revision like any non-transition event and the new binding; every later event carries the new binding (commit step 5); the transaction may end with `REPLANNING -> PLAN_VERIFYING`
- outside `REPLANNING`, a `plan_contract_bound` event after the first is rejected; a second re-binding in the same `REPLANNING` visit is rejected
- the fold switches the bindings at that event, and strict load re-checks all of the above
- [Dependency, Human decision R-043] #1391 checks binding continuity in `validate_append` and turns a binding mismatch into `evidence_status=invalid` in its projection (TASK-1391 plan: binding continuity / "binding mismatch -> invalid"). Without a change there, **every Replanned Run's RunEvidence would be invalid**. #1391 is asked to treat a re-binding `plan_contract_bound` as a binding segment boundary in both `validate_append` and the projection. #1391 has no Lifecycle State, so the state condition ("only while `REPLANNING`", once per visit) is checked by #1392 alone. Until #1391 supports this, Preflight stops exec (todo). #1393's plan already assumes "#1391 `plan_contract_bound` (and its re-binding after Replan)"

### Initial state and PLANNING

`create_run` takes no initial-state input and always starts at `PLAN_VERIFYING` (a fold constant): its first event is `plan_contract_bound`, so a Plan already exists (taxonomy: PLANNING = Plan being written, PLAN_VERIFYING = initial Plan under verification). `PLANNING` stays a canonical Lifecycle State value and is **not** removed from canon. A later slice that owns durable planning (planning-time events, incomplete Plan, binding updates) adds `PLANNING -> PLAN_VERIFYING` and a create path starting at `PLANNING`; until then there is no way to request it (the API has no initial-state input). Residual limit: a Run cannot be resumed from the middle of Plan writing.


## pending_action scope

The RunState field exists in canon, but the first owner-backed Delivery paths do not need Human/External waiting.

For this slice:
- persisted `pending_action` must be null
- non-null pending_action is rejected as unsupported
- WAITING_* transitions are unsupported

A later dedicated waiting/resume slice must define pending_action shape and transition evidence before enabling these states.
