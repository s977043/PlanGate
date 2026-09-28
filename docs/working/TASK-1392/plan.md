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
  <safe-run-id>.halt     (only when the Run is halted; see Halt marker)
  <safe-run-id>.pending  (only while a replace is in flight; see Pending marker)
```

### Halt marker (Human decision R-071)

States that must survive a restart but cannot always be written to the stream — "this Run was stopped", "durability of the last commit is unknown", "this Run existed and is now missing" — are kept in a per-Run **halt marker**, not in the caller's memory.

- `<safe-run-id>.halt` = canonical JSON `{schema_version, run_id, reason, evidence}` with `reason` ∈ `CALLER_STOP` / `DURABILITY_UNKNOWN` / `RUN_MISSING`. It is written under the run lock via `<safe-run-id>.halt.tmp`, file flush, replace and directory flush; if a marker already exists the first one is kept
- **presence** is decided by `lstat` on the entry name, never by opening or parsing it: if **any** entry named `<safe-run-id>.halt` or `<safe-run-id>.halt.tmp` exists — a regular file, a symlink (even dangling), or corrupt content — the Run is halted. The content is parsed only to report the reason; an unparseable marker is reported as reason `UNREADABLE` (R-078)
- every operation (`create_run`, `commit`, `load_run`, `halt_run`) checks for the marker **after** acquiring the run lock and before touching the snapshot; while it exists, `create_run`, `commit` and `load_run` return **`RunHalted`** and neither read nor write the snapshot (R-079)
- #1392 writes the marker itself with `DURABILITY_UNKNOWN` whenever the directory flush after a replace fails (the flush error may have been consumed, so a later success is not proof), and via the Pending marker after a crash (below); if writing the marker also fails, it still returns the error, and the pending marker (if any) keeps the Run halted on the next call
- `halt_run(runtime_root, run_id, reason, evidence)` lets #1395 persist a stop; it works even when no snapshot exists (so a missing Run cannot be silently recreated). Its outcomes: success (marker durable or already present), `RuntimeBusy`, `RuntimeUnwritable`, `RuntimePathChanged`, `ValidationRejected` (unknown reason) (R-080)
- **Human unhalt procedure** (Human-owned, outside the API; R-081): `CALLER_STOP` — confirm the cause is resolved, then remove the marker. `RUN_MISSING` — restore the snapshot from a known copy or abandon the `run_id`; never remove the marker to let #1395 recreate it. `DURABILITY_UNKNOWN` / `UNREADABLE` — verify the snapshot against an independent record (or accept the older state by restoring it), make the directory durable with a fresh flush, then remove the marker **and any `.pending` / `.pending.tmp`** (otherwise the next call resolves the leftover pending and halts again, R-084). A pending marker **without** a halt marker (the halt write failed, R-091) is handled the same way as `DURABILITY_UNKNOWN`. Any restored snapshot file is **file-flushed** before the directory flush (a restore is the only replace that does not go through a pending marker, R-093). Removing the marker is itself followed by a directory flush. This procedure is part of the #1395 / operator handoff
- the marker is not Run truth: it never changes the stream, RunState or RunEvidence

### Pending marker (Human decision R-077)

The window between a failed (or not yet attempted) directory flush after replace and a durable halt marker is closed by writing the intent **before** the replace:

Applies to **every path that replaces the snapshot**: `create_run`, `commit`, and conflict-evidence recording (R-086).

1. under the run lock, write `<safe-run-id>.pending` = `{run_id, old_snapshot_ref, new_snapshot_ref}` via `.pending.tmp`, file flush, replace, **directory flush** (if any of this fails: `RuntimeUnwritable`, zero mutation, nothing replaced)
2. replace the snapshot (commit step 13 / create step 7 / conflict recording)
3. directory flush (step 14). **Success**: the new snapshot is durable. Remove `.pending`, then flush the directory again. If this last flush fails, the call **still returns success** (the commit is durable); a crash before that removal becomes durable makes the pending marker reappear and the next call halts conservatively (ST-19c) (R-085)
4. **Failure**: write the halt marker (`DURABILITY_UNKNOWN`), then return `DurabilityUnknown`

Every operation except `halt_run`, after taking the lock and checking the halt marker, resolves a pending marker (presence by `lstat`, as for the halt marker):
- only `.pending.tmp` exists: residue from a crash before step 1 finished; nothing was replaced — remove it, flush the directory, proceed (R-087). If that flush fails, return `RuntimeUnwritable` and do not proceed (R-097)
- the current snapshot's `snapshot_ref` equals `old_snapshot_ref` (or there is no snapshot and `old_snapshot_ref` is null): the replace never happened — remove `.pending`, flush the directory, proceed. If that flush fails, return `RuntimeUnwritable` and **do not proceed** (the next call resolves again) (R-085)
- otherwise (it equals `new_snapshot_ref`, or anything else, or `.pending` is unreadable): the replace happened but its durability is unknown — write the halt marker (`DURABILITY_UNKNOWN`), leave `.pending` in place for the Human, and return `RunHalted`. If writing the halt marker fails, still return `RunHalted` (reason `DURABILITY_UNKNOWN`, from the pending marker): the leftover pending marker halts every later call in the same way (R-091)

`halt_run` does **not** resolve a pending marker: it always writes its own marker (or keeps an existing one) and returns success, so a stop is never blocked by a leftover pending (R-084).

Because every replace is preceded by a durable pending marker, a writer crash after the replace is always detected; `load_run` therefore no longer flushes the directory itself (Durable read).

Consequence: a writer crash between replace and a successful step 14 always halts the Run for a Human, even when the data was in fact durable. This is deliberate (a later successful flush cannot prove durability). Cost: one extra file flush and two extra directory flushes per commit (5 flushes instead of 2); measured by the performance fixture (ST-32). If the threshold is missed, candidates for the Replan are group commit or a WAL slice.

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

#1392 passes the binding in force at each event's position to #1391 `finalize_event(draft, bound_context, event_seq)` (TASK-1391 plan T6). `bound_context` = `run_id`, the event's `revision`, and the binding values (`harness_manifest_ref`, `plan_hash`, `source_sha`); `event_seq` is passed separately (TASK-1391 plan: #1392 binds run_id / event_seq / revision / manifest / plan / source). The binding values inside the `plan_contract_bound` payload, if #1391 defines any, must equal the `binding` / `rebinding` argument (ST-21t). Binding keys live only at the RunEvent top level (never inside a payload). A draft that contains a #1391 binding key or an envelope key at its top level is rejected, so there is exactly one channel.

### Retry after a lost response (no idempotency in the first slice)

Human decision R-046 (2026-09-25): the idempotency layer (`transaction_id`, replay, request digest) produced a new failure class in every C-2 round (R1〜R4) and is removed from the first slice.

The revision changes only on a state transition, so a revision-only CAS would let an **events-only** commit be resent and applied twice (the original R-001). Human decision R-049: every commit also carries `expected_position`, and `position` (the number of `create` / `commit` envelopes) grows by exactly one with every successful commit, transition or not.

- a resent request is evaluated like any other: if it already committed, its `expected_position` is now stale, so it gets `STATE_CONFLICT` (canon §4) and **its drafts are not appended a second time**, with or without a transition. This keeps TASK-1391 plan's requirement that an exact retry does not append a second event; the mechanism is the CAS, not a replay index
- `conflict` envelopes do not count toward `position`, so a stale writer's conflict evidence does not make a concurrent legitimate writer stale
- **#1392's guarantee ends at the same token**: a resend with the same token never applies twice. #1392 has **no** rule for deciding whether a lost request landed (Human decision R-060, replacing R-054: the landed-check rule produced three new failure classes in C-2 R6 — several in-flight requests from one writer, the index across conflict envelopes, and caller crash)
- **recovery belongs to #1395** (handoff contract): after a lost response, an error, or its own crash, the caller **discards** the in-flight request, calls `load_run`, and **derives the next action deterministically from the loaded stream**. If the lost request landed, its events are in the stream and the derivation does not produce it again; if it did not land, the derivation produces it again with a fresh token. Resending the old drafts with a re-read token without re-deriving is outside the contract (it can apply the same content twice)
- **which outcomes are re-derived and which stop** (R-065 / R-072; re-deriving a deterministic request after a deterministic rejection would loop forever). #1392 returns exactly these outcomes; anything else (an unexpected exception) falls into the last row:

  | outcome | #1395 action |
  |---|---|
  | no response (lost), own crash, `StateConflict` (recorded or `suppressed`), `RunAlreadyExists` | discard, `load_run`, re-derive. At most `MAX_REDERIVE_PER_POSITION` (provisional 3) re-derivations while `position` does not advance; beyond that, `halt_run(CALLER_STOP)` |
  | `RuntimeBusy` (lock wait timeout) | wait and retry the **same call**; at most `MAX_BUSY_RETRIES` (provisional, fixture) consecutive attempts, counted per call whether or not a position has been read; beyond that, `halt_run(CALLER_STOP)` (R-074) |
  | `RunNotFound` from `load_run` | derive `create_run` **only for a `run_id` for which #1395 has never received a successful `create_run` or `load_run`**; otherwise (a deleted snapshot or a wrong `runtime_root`), `halt_run(RUN_MISSING)` (R-073 / R-082). #1395 records issued and observed run_ids durably in its own task context **before** calling `create_run` |
  | `RunNotFound` from `commit` | stop class (the Run disappeared under an active writer): `halt_run(RUN_MISSING)` (R-082) |
  | `RunHalted` | stop; do nothing until a Human removes the marker |
  | `ValidationRejected` (drafts, allowlist, Decision-bound checks, bindings), `SnapshotCapacityExceeded`, `InvalidExpectedRevision`, `RunTerminal` (commit after terminality), `SnapshotInvalid` (strict load), `RuntimeUnwritable` (incl. ENOSPC and failed flushes before a replace), `RuntimePathChanged`, `DurabilityUnknown`, **any other outcome** | **stop**: `halt_run(CALLER_STOP)` with the error as evidence (for `DurabilityUnknown` #1392 has already written the marker); do not re-derive |

  **Stopping is complete only when `halt_run` succeeds** (R-080). `halt_run` returning `RuntimeBusy` is retried up to `MAX_HALT_BUSY_RETRIES` (provisional, fixture); `LOCK_WAIT_TIMEOUT` bounds only the waiting side, so a lock holder that hangs (e.g. inside a flush, or stopped) can keep the lock indefinitely (R-092). Beyond that bound, and when `halt_run` returns `RuntimeUnwritable` / `RuntimePathChanged` / anything else, the stop is unpersisted — #1395 must not resume that Run automatically and raises it to a Human (residual, handoff). #1395 never re-enters the stop row for a failed `halt_run` (no recursion).

  Because the stop is persisted by the halt marker, a #1395 restart sees `RunHalted` and cannot resume a stopped Run, even outside a Decision state (R-033 residual closed). The re-derivation counters live in #1395's memory; a crash resets them, so repeated crashes are bounded only by #1395's own restart policy (residual, handoff)
- external side effects that are not recorded in the stream (e.g. starting a worker before any event says so) can be repeated by re-derivation; #1395 must record intent before acting or treat such effects as idempotent (residual, handoff)
- a resent `create_run` for an existing Run gets `RunAlreadyExists` with zero mutation; the caller loads and re-derives from the stream (if the existing Run's `plan_contract_bound` binding differs from what the caller intended, that is a deterministic mismatch: stop)
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
7. write the pending marker (old ref null), then atomic_replace(snapshot) with the same flush and directory-flush steps as commit 11〜14, and the same Pending marker rules

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
11. write temp in same directory, at the fixed name `<safe-run-id>.json.tmp` (no random names; any other file whose name starts with `<safe-run-id>.` besides `.lock`, `.json`, `.json.tmp`, `.halt`, `.halt.tmp`, `.pending` and `.pending.tmp` is rejected, so ST-20 cleanup is deterministic; other Runs' files in the same `runtime_root` are not affected. `halt_run` is exempt from this rejection, so a stop can always be written)
12. flush + fsync temp
12a. write the pending marker (Pending marker step 1)
13. `os.replace(temp, target)`
14. fsync parent directory; on success remove the pending marker and flush the directory again; on failure write the halt marker and return `DurabilityUnknown`
15. return committed snapshot

No successful response before step 15 (parent-directory fsync complete).

## Revision conflict

The CAS token is the pair (`expected_revision`, `expected_position`). Because `position` only grows and every revision change happens in a counted envelope, a request is classified **in this order** (R-055): **ahead** if either component is higher than current (even if the other is lower, e.g. (R+1, P−1)); otherwise **current** if both are equal; otherwise **stale**. Checking ahead first keeps a recorded conflict always stale, so strict load's conflict check can never reject a Run because of it.

If the request is **ahead**: reject `InvalidExpectedRevision` with zero mutation and no conflict event. An ahead token cannot come from a correct caller, because `load_run` returns only durable snapshots (see Durable read); without that rule, a token read before a dir fsync could be lost by an OS crash and become ahead. If the store later reaches that token, the same request is an ordinary CAS and can commit; the error only says "not now" (R-048).

If the request is **stale**:
- do not apply requested drafts/state transition
- if the Run is still non-terminal and the Conflict evidence bound allows it, append a `state_conflict` evidence event in a separate atomic snapshot commit using actual current revision and next event_seq, in one envelope `kind=conflict` holding exactly that event; its payload (#1392-owned) carries `expected_revision`, `actual_revision`, `expected_position`, `actual_position`
- if the Run is already terminal, do not append after terminality; return `RunTerminal` without mutating the snapshot
- raise/return RevisionConflict (`STATE_CONFLICT`) containing the conflict `event_ref`, or `conflict_evidence="suppressed"` when not recorded
- state revision remains unchanged

This preserves conflict evidence without pretending the failed mutation committed.

### Conflict evidence bound

Unbounded conflict recording would let a looping stale writer grow the event stream and snapshot without limit.

- **terminal reserve** (R-032): a conflict is recorded only if the file **after appending it** stays outside `TERMINAL_RESERVE`; otherwise the answer is `suppressed` with zero mutation. Conflict evidence can never consume the space kept for the terminal Decision
- **per position** (R-056): at most `MAX_CONFLICTS_PER_POSITION` `state_conflict` events while `position` stays the same. Beyond the cap, return RevisionConflict with `conflict_evidence="suppressed"` and zero mutation. The cap being reached is itself visible from the recorded conflicts at that position. Counting per position (not per revision) keeps recording evidence across a long run of non-transition commits (e.g. repeated `continue` in `PR_CONVERGING`); overall growth stays bounded by `MAX_EVENTS_PER_RUN`
- the constant's value is fixed by the RED fixture (provisional: 8); it is a first-slice limit, not a canon value
- without transaction identities, a resent stale request is recorded again (up to the per-position cap)

## Crash semantics

Fault injection labels:

- after snapshot temp open / write / fsync
- after `.pending.tmp` write, after pending replace, after pending directory flush (R-088)
- before snapshot replace
- after snapshot replace
- after step 14 directory fsync
- after pending removal, before and after its directory flush
- the same points for `create_run` and conflict recording

Expected — every crash point yields exactly one of: the complete old snapshot, the complete new snapshot, or `RunHalted` (`DURABILITY_UNKNOWN`) for the Human (R-088):
- before replace: old snapshot remains authoritative; stale temp ignored/cleaned under lock; a leftover `.pending.tmp` or a pending marker matching the old ref is removed
- after replace, before a successful step 14: the pending marker does not match the old ref, so the next operation writes the halt marker and returns `RunHalted` (Human-owned recovery, R-077)
- after a successful step 14: new snapshot authoritative
- recovery never composes fields from old/new
- successful API response only after directory fsync
- a crash after a successful step 14 but before the response is observed by the caller as a lost response (see Retry after a lost response); a crash between replace and a successful step 14 halts the Run (above)

### Durable read (R-061)

`load_run` takes the run lock, returns `RunHalted` if a halt marker exists, resolves a pending marker (Pending marker), and only then reads and returns the snapshot. The guarantee is "**durable unless a halt marker says otherwise**": every replace is preceded by a durable pending marker and followed either by a successful directory flush (then the pending is removed) or by a halt marker; a writer crash in between leaves the pending marker, which the resolution turns into `RunHalted`. So `load_run` itself does not flush the directory (R-089: that flush became redundant with R-077, and its transient failure would have halted a healthy Run). If no snapshot exists it returns `RunNotFound` (R-066). The lock wait is bounded by `LOCK_WAIT_TIMEOUT` (provisional, fixed by fixture); on timeout it returns `RuntimeBusy` without reading. `load_run` creates the lock file if missing and may remove a resolved pending marker, so `runtime_root` must be writable even for reads; a read-only root fails closed (`runtime_unwritable`) (R-068). A snapshot that was replaced but whose directory entry was not yet flushed (writer crashed between steps 13 and 14) is therefore never returned: the leftover pending marker halts the Run (ST-19a / 19b).

No separate WAL is required because the whole Run (events and envelopes) is one replace unit.

## Durability definition

"fsync" in the commit protocol means the platform's strongest available flush, per platform:

| platform | file flush | directory flush | if unavailable |
|---|---|---|---|
| Linux | `os.fsync(fd)` | `os.fsync(dirfd)` | fail closed (`runtime_unwritable`) before replace |
| macOS | `fcntl(fd, F_FULLFSYNC)` | `fcntl(dirfd, F_FULLFSYNC)` | fail closed; plain `fsync` is **not** accepted as a fallback |
| other | unsupported | unsupported | fail closed at `create_run` |

Flush failure by step (R-067):

| failing step | state on disk | result |
|---|---|---|
| temp file flush (step 12), before replace | old snapshot authoritative | `runtime_unwritable`; zero mutation |
| directory flush (step 14), after replace | the new snapshot is visible but its durability is unknown | #1392 writes the halt marker (`DURABILITY_UNKNOWN`) and returns `DurabilityUnknown`. A later successful flush is **not** proof of durability (on Linux a writeback error is reported once, so a later `fsync` on a new descriptor can succeed although data was lost), so every later call gets `RunHalted` until a Human inspects the Run |
| `create_run` directory flush, after replace | same as above | same as above |
| pending-marker write (before replace) | old snapshot authoritative | `RuntimeUnwritable`; zero mutation |
| pending removal directory flush, after a successful step 14 | new snapshot durable; the removal may not be | success is returned; if a crash undoes the removal, the next call halts conservatively (R-085) |
| directory flush while resolving a pending marker that matches the old ref | old snapshot authoritative | `RuntimeUnwritable`; the call does not proceed; the next call resolves again (R-085) |

**One directory descriptor per call** (Human decision R-090): all Runs share the `runtime_root` directory inode while locks are per Run, so a directory-flush error could be reported to another Run's concurrent flush and then not to this Run (a writeback error is reported once per descriptor state; a descriptor opened later may see success). Every #1392 call therefore opens **one** directory descriptor for `runtime_root` at the **start of the call** (before taking the lock and before any mutation) and uses that same descriptor for everything in the call: opening the lock file, every open / read / write / replace / unlink relative to it (`dir_fd=` / `*at` calls; no path-based access), and every directory flush. On Linux ≥ 4.13 an error is reported to every descriptor that was open when it occurred, so this Run's step 14 observes it even if another Run consumed it first.

**Root identity** (R-095): after taking the lock, #1392 compares `lstat(runtime_root)` with `fstat(dirfd)` (`st_dev`, `st_ino`); if they differ (the root was moved or replaced), release and return `RuntimePathChanged` with zero mutation. Because every later operation goes through the same descriptor, a replacement of the root after this check cannot split two writers across two inodes within the call; such a replacement is an operator error outside the guarantee (residual, handoff; ST-39).

**Platform scope** (R-096): the per-descriptor error reporting above is **not** one of the "required semantics" that make #1392 fail closed at `create_run` (Durability definition): macOS and Linux < 4.13 are supported, and on them the cross-Run error-consumption window is a stated residual risk. A shared directory error is observed by every Run whose descriptor was open, so one I/O error can halt all concurrently active Runs (fail closed; availability residual, handoff).

What a successful response guarantees: the new snapshot survives process crash and OS crash. Power loss is covered only to the extent the storage device honours the flush above; this slice does not claim more. Fault injection (Crash semantics) covers the process-crash points; OS / power-loss behaviour is out of test scope and stated as a residual risk in the handoff.

## Size and cost bound

Every commit rewrites the whole snapshot, so write volume and latency grow with the Run's history. First-slice bounds (values provisional, fixed by RED / performance fixtures):

- `MAX_EVENTS_PER_RUN` (provisional 2048) and `MAX_SNAPSHOT_BYTES` (provisional 8 MiB)
- a commit whose resulting snapshot would exceed either bound is rejected with `SnapshotCapacityExceeded` **before the temp file is written**, with zero mutation
- **terminal reserve**: a non-terminal commit is accepted only if the file **after appending it** stays outside `TERMINAL_RESERVE` of both bounds (event count and canonical bytes), so no commit can straddle into the reserve (R-057; ST-30e). A fixed reserve alone does not prove that a terminal Decision fits, so the reserve is **derived, not guessed**: `TERMINAL_RESERVE >= 1 event and >= MAX_DECISION_EVENT_BYTES + envelope overhead`, where `MAX_DECISION_EVENT_BYTES` is the maximum canonical encoded size of a `decision_made` event. [Dependency] #1391 / #1393 must bound the `decision_made` payload (e.g. the number of `event_ref` it lists) so that the maximum exists; until then the reserve is provisional and the guarantee "a full Run can always commit its terminal outcome" is **not claimed**. A terminal Decision larger than the reserve is rejected by #1391 payload validation, not by the capacity check (ST-30c). Scope of the guarantee (R-033): a terminal `decision_made` is accepted only in the Decision states (`VERIFYING` / `DIAGNOSING` / `PR_CONVERGING`, #1393 I-1). A Run that reaches the reserve in another state (e.g. `EXECUTING`) cannot make the mechanical transition that would lead to a Decision state, so it cannot terminate through a Decision; #1395's budget must stop such a Run before the bound, and this residual is stated in the handoff
- temp space: the store needs free space for one extra snapshot; ENOSPC during temp write is a pre-replace failure (old snapshot stays authoritative)
- performance fixture: commit latency at the bound on the CI runner; the threshold is fixed with the fixture (provisional p95 ≤ 200 ms). Missing the threshold is a **Replan trigger** (compaction or WAL slice), not a reason to relax the bound
- the same fixture measures `load_run` at the bound, alone and with concurrent readers (every read takes the exclusive lock, so reads are serialised; R-068); a miss is also a Replan trigger (e.g. a shared read lock)

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
- `load_run` also takes the lock (it may resolve a pending marker; Durable read)
- every lock acquisition (`create_run`, `commit`, `load_run`, `halt_run`) re-checks the lock inode as above and waits at most `LOCK_WAIT_TIMEOUT` and otherwise returns `RuntimeBusy` with zero mutation (R-068)
- lock file is not Run truth

If runtime platform lacks required locking/fsync semantics (`flock`, the flush primitives of Durability definition, `*at` calls with `dir_fd`), fail closed rather than silently weakening. Per-descriptor error reporting is not in this list (Platform scope, R-096).

## Integration API

Proposed:

```python
create_run(runtime_root, run_id, binding, plan_event_draft) -> CommitResult
load_run(runtime_root, run_id) -> Snapshot
halt_run(runtime_root, run_id, reason, evidence) -> None
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

Outcomes (closed set, R-072; the snake_case codes used elsewhere in this plan are the same outcomes): success, `RunNotFound`, `RunAlreadyExists`, `RunHalted`, `RunTerminal`, `StateConflict` (`STATE_CONFLICT`, with `conflict_evidence` recorded or `suppressed`), `InvalidExpectedRevision`, `SnapshotCapacityExceeded`, `ValidationRejected`, `SnapshotInvalid`, `RuntimeBusy`, `RuntimeUnwritable` (`runtime_unwritable`, incl. ENOSPC), `RuntimePathChanged` (`runtime_path_changed`), `DurabilityUnknown`. Every outcome is mapped in the #1395 table above; an unexpected exception is treated as the stop class. `halt_run`'s own outcomes are listed in Halt marker and handled by the stop-completion rule (R-080).

No CLI in this slice.

## Implementation placement and static coverage

- TA numbers: use **ta-94 or later** (main has ta-88; open PRs and the sweep plan hold ta-88〜93). Re-check `tests/extras/` on main and open PRs just before exec
- relation to PR #1402 (Human decision R-023, 2026-09-25): #1402's `scripts/ai-loop-v2/run_state.py` (multi-file + journal) is **excluded from #1402**; this plan is the owner of RunState persistence and #1402's delivery code consumes the #1392 API instead
- the module location must be one that the static checks actually scan: `scripts/ai-loop-v2/` is outside ta-70 `_T70_DIRS` and `check_exec_boundary.py` today, so ST-25 / ST-26 would pass vacuously there. Before exec, either extend those checks to the chosen directory or place the module where they already apply (with the TC-E9 plugin allowlist / sync declaration that `scripts/ai-loop/` requires). Extending the checks may touch HO paths (`scripts/hooks/*.sh`, `.github/workflows/*`); if so that part is Human-applied
- a positive control is required for ST-25 / ST-26: inject a forbidden symbol and confirm the check fails

## Tests

- CAS concurrent two writers
- stale token; resent request after a lost response (events-only and with transition) gets STATE_CONFLICT and appends no drafts
- conflict event recorded without state revision change; conflict evidence bound (per position / terminal reserve)
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

Residual (R-042): a stale writer's `state_conflict` recorded between building a Decision input and committing the Decision breaks check 2, so the legitimate Decision is rejected and #1395 must rebuild the input. This is the intended strictness of input freshness (no event of any kind in between); it is bounded by `MAX_CONFLICTS_PER_POSITION` and stated in the handoff.

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
