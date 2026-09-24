# PBI INPUT PACKAGE — TASK-1391 / #1391

> Parent owner: #874
> Delivery gate: #1383
> EPIC: #870
> Base: `b2234bd1097f7b741d372e3353d1877932401731`
> Status: PLAN-ONLY / PRODUCTION IMPLEMENTATION BLOCKED

## Context / Why

ai-loop V2 canon defines the authoritative evidence model as:

```text
RunEvent stream (append-only)
  -> deterministic projection
  -> RunEvidence (rebuildable cache)
```

#1387 proved the Delivery Path A / Path B semantics as a non-authoritative executable specification, but Production owner-backed components do not yet exist.

#1391 is the first owner implementation slice. It must define V2 RunEvent semantics and deterministic projection without reusing Legacy RunEvidence schema/runtime as V2 authority.

## Authoritative inputs

- `docs/ai/ai-loop-v2/artifact-responsibilities.md` §1 / §3
- `docs/ai/ai-loop-v2/taxonomy.md`
- `docs/ai/ai-loop-v2/harness-manifest.md`
- #874 V2 rebaseline
- #1383 / PR #1387 executable specification
- #1329 semantic invalidation procedure

## Goal

Implement a storage-agnostic V2 event/evidence core that can be consumed by:
- #1392 durable RunState/event transaction
- #1393 Verification/Failure/Decision core
- #1383 owner-backed Delivery E2E

## Responsibility boundary

#1391 owns:
- RunEvent canonical representation
- stable event identity
- event-sequence / binding / taxonomy validation
- stream validation
- deterministic RunEvidence projection

#1391 does not own:
- durable event persistence / WAL / lock / recovery (#1392)
- RunState transition semantics (#1392)
- VerificationResult / FailureRecord / Decision logic (#1393)
- Worker runtime (#1369)
- PR convergence runtime
- Evolution metrics expansion (#1285)

## Key constraints

- `event_seq` != RunState `revision`
- accepted stream contains no duplicate `event_ref`
- retry/idempotency is handled by #1392 before append: exact replay returns the already accepted event instead of appending a duplicate
- same `event_ref` + different content => invalid
- producer cannot self-declare receiver-derived `evidence_status`
- raw transcript / hidden CoT / secrets are forbidden
- terminal Outcome is unique and final
- MERGE_READY has no Stop Reason
- HUMAN_ESCALATED / BLOCKED require Stop Reason
- Legacy schema/runtime remain unchanged
- no durable JSONL writer in #1391
- producer does not choose authoritative `event_seq`; #1392 assigns sequence under the durable commit boundary
- `event_ref` is derived only after the accepted envelope is fully bound

## Dependencies

- #1387 current-head I1 must pass before Production implementation begins
- #1329 preflight required at exact implementation base SHA
- #1392 consumes this contract
- #1393 may begin pure RED work after the event envelope is frozen

## Non-goals

- RunState persistence
- WAL / transaction store
- Human interrupt/resume
- Decision Engine
- V2 metrics collection
- production merge/promotion
- generic Graph runtime
- full future event taxonomy

## Success condition

The same accepted event list always yields the same validated RunEvidence projection, while malformed, privacy-unsafe, stale-binding, non-terminally-consistent, or reference-invalid streams fail closed.
