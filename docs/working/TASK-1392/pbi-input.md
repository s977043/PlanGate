# PBI INPUT PACKAGE — TASK-1392 / #1392

> Parent owner: #1025
> Depends on: #1391
> Delivery gate: #1383
> Integration: #1395
> Governance: #1329
> Status: PLAN-ONLY

## Goal

V2 RunState の revision CAS と accepted RunEvent の durable commit を、first slice で crash-consistent に実装する。

## Key design decision

Legacy #1025 の multi-file state / record / ledger / manifest / WAL をそのまま移植しない。

V2 first slice では 1 Run の mutable state と accepted event stream を **1つの atomic snapshot file** に格納する。

```text
run snapshot
  = RunState
  + accepted RunEvents
  + generation
  + snapshot_ref
```

これにより、

- state committed / event missing
- event committed / state CAS failed

という2ファイルhalf-commitを構造的に消す。

## Responsibility

#1392 owns:
- durable lock
- snapshot load/strict validation
- event_seq allocation
- RunState revision CAS
- #1391 finalize/validate_append invocation
- temp write + fsync + os.replace + directory fsync
- crash recovery from old/new complete snapshot
- idempotent transaction retry

#1392 does not own:
- event vocabulary / event ref semantics (#1391)
- Decision semantics (#1393)
- Verification/Failure semantics (#1393)
- Worker
- merge/promotion

## RunState minimum

- run_id
- lifecycle_state
- revision
- pending_action
- policy_verdict
- harness_manifest_ref
- plan_hash
- source_sha
- resumed_from_run_id? optional

Allowed lifecycle values:
- PLANNING
- PLAN_VERIFYING
- EXECUTING
- VERIFYING
- DIAGNOSING
- REPAIRING
- REPLANNING
- PR_CONVERGING
- WAITING_HUMAN
- WAITING_EXTERNAL

Forbidden as Lifecycle State:
- MERGE_READY
- HUMAN_ESCALATED
- HUMAN_REJECTED
- BLOCKED
- NO_PROGRESS

## Trust limit

Single-file atomic replacement prevents partial state/event commits on the same filesystem, but does not detect whole-store rollback by an actor who can restore an older valid snapshot and lock-domain metadata. That needs an external anchor and is outside this slice.
