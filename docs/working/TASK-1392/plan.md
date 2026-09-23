# EXECUTION PLAN — TASK-1392 / #1392

## Current verdict

```text
Plan: GO
Production implementation: after #1391 consumable
Persistence model: single atomic snapshot
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

## Snapshot

```json
{
  "schema_version": "1",
  "generation": 3,
  "state": {
    "run_id": "RUN-...",
    "lifecycle_state": "VERIFYING",
    "revision": 2,
    "pending_action": null,
    "policy_verdict": null,
    "harness_manifest_ref": "sha256:...",
    "plan_hash": "sha256:...",
    "source_sha": "..."
  },
  "events": [],
  "snapshot_ref": "sha256:..."
}
```

`snapshot_ref` = canonical hash of snapshot excluding snapshot_ref.

## Commit protocol

### create_run

Under exclusive lock:

1. require no existing snapshot
2. construct revision=0 RunState
3. allocate event_seq=1
4. #1391 validates/finalizes plan_contract_bound event
5. #1391 validate_append([], event)
6. build generation=1 snapshot
7. atomic_replace(snapshot)

### commit_events

Input:
- run_id
- expected_revision
- EventDrafts
- optional state transition request

Under exclusive lock:

1. strict load current snapshot
2. validate snapshot_ref + #1391 accepted stream
3. require expected_revision == current state revision
4. allocate exact next event_seq values
5. bind current run/manifest/plan/source context
6. #1391 finalize each draft
7. #1391 validate_append against growing in-memory stream
8. inspect finalized drafts for Terminal Outcome:
   - if any draft contains terminal `decision_made.outcome != null`, `transition` must be absent
   - terminal decision must be the final event of the transaction
9. if non-terminal state transition requested:
   - validate from_state/current revision
   - increment revision exactly +1
   - append `state_transitioned` as final event of transaction
10. build generation+1 snapshot
11. write temp in same directory
12. flush + fsync temp
13. `os.replace(temp, target)`
14. fsync parent directory
15. return committed snapshot

No successful response before step 13.

## Revision conflict

If expected_revision mismatches:
- do not apply requested drafts/state transition
- append a `state_conflict` evidence event in a separate atomic snapshot commit using actual current revision and next event_seq
- raise/return RevisionConflict containing conflict event_ref
- state revision remains unchanged
- conflict recording itself increments generation only

This preserves conflict evidence without pretending the failed mutation committed.

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

No separate WAL is required because state+events are one replace unit.

## Strict loading

- UTF-8
- duplicate JSON keys reject
- NaN / Infinity reject
- unknown keys reject
- symlink target/lock reject where platform supports no-follow checks
- snapshot_ref mismatch reject
- state/event run binding mismatch reject
- event stream invalid => snapshot invalid

## Locking

POSIX first slice:
- per-run lock file
- `fcntl.flock(LOCK_EX)`
- lock held across load -> validate -> build -> replace -> dir fsync
- lock file is not Run truth

If runtime platform lacks required locking/fsync semantics, fail closed rather than silently weakening.

## Integration API

Proposed:

```python
create_run(runtime_root, initial_state, plan_event_draft) -> Snapshot
load_run(runtime_root, run_id) -> Snapshot
commit(
    runtime_root,
    run_id,
    expected_revision,
    event_drafts,
    transition=None,
) -> Snapshot
```

No CLI in this slice.

## Tests

- CAS concurrent two writers
- stale expected revision
- conflict event recorded without state revision change
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
