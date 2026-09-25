# ADR-002: Plan Contract の正本と実行参照

**Status**: Accepted  
**Date**: 2026-09-24  
**PBI**: TASK-0981 (#981) / #1403 — Intent Context binding  
**Decision Makers**: mine_take

---

Plan Contract は既存の Plan Package + c3-prime 契約の別名であり、新しい Plan identity artifact ではない。

## Context

PlanGate already binds execution to `plan_hash`, `plan_package_hash`, C-1/C-2 evidence and C-3/C-3' approval. #981 identified the remaining handoff gap: an Executor needs a machine-readable reference to the exact approved Plan and approval without moving approval state into a second source of truth.

#1389 adds a pre-Plan Intent Context Package with `context_id` (logical lineage), `context_ref` (semantic stale/binding identity), and `snapshot_ref` (exact audit identity).

The Plan must explicitly record the semantic context used to create it so the existing Plan hash/approval naturally binds that decision.

## Problem Statement

A sidecar created after approval cannot safely invent a Context binding that was not present in the approved Plan. Conversely, adding execution data to the approval record mixes responsibilities and conflicts with the 1 approval : N execution model.

## Decision Drivers

- Preserve `plan_hash` / `plan_package_hash` as Plan identity SSoT.
- Preserve `approvals/c3.json` as approval snapshot SSoT.
- Make Context binding explicit rather than a hidden hash input.
- Fail closed on semantic drift while avoiding timestamp-only false stale.
- Support legacy C-3 and c3-prime without changing C-4 / merge authority.
- Do not claim ActorSession authenticity before #980.

## Considered Options

### Option A: approval record only

Rejected. Approval is the immutable decision snapshot and not the per-execution reference surface.

### Option B: execution sidecar only

Rejected. A post-approval sidecar could attach a Context that the approved Plan never referenced.

### Option C: explicit Plan marker + execution sidecar

Adopted. When Intent Context is used, `plan.md` contains exactly one `Intent-Context-ID: CTX-...` line and one `Intent-Context-Ref: sha256:<64hex>` line. Existing Plan hash therefore covers the semantic Context binding.

The execution reference is `docs/working/TASK-XXXX/execution/plan-contract.json`. It repeats the approved Plan/approval/semantic Context refs for deterministic preflight. `snapshot_ref` is retained only for exact audit.

## Decision

1. Canonical contract: `docs/workflows/ai-loop/c3-prime-contract.md` remains the Plan Contract SSoT. The sidecar is an execution reference, not a parallel Plan definition.
2. No `plan_version`: execution identity remains `plan_hash` + `plan_package_hash`; `task_id` is the logical Plan ID.
3. Physical execution reference: `docs/working/TASK-XXXX/execution/plan-contract.json`.
4. Schema enforcement: `schemas/plan-contract.schema.json` plus mandatory `schema_mapping.py` registration.
5. Actor boundary: future ActorSession values remain non-verified opaque identifiers until #980.
6. Legacy approval: usable only when C-3 is `APPROVED` and `plan_hash` matches current `plan.md`. **Legacy binding caveat:** legacy C-3 approves `plan.md` via `plan_hash`; it does not retroactively approve the six-file `plan_package_hash`. In a legacy sidecar, `plan_package_hash` is an execution-time integrity snapshot used to detect later drift, not evidence that the legacy approval covered all six artifacts.
7. Presence/integrity: all six Plan Package artifacts must be present and non-empty.
8. No action-policy duplication: `NO MERGE BY AI` remains enforced by existing implementation/policy, not copied into sidecar.
9. Evidence binding: existing C-1/C-2/c3-prime verification remains owned by #872 and is reused.
10. Run-event actor vocabulary/authenticity remains later #981/#980 work; #1403 does not modify RunEvent.

### Intent Context extension

When `intent-context.json` exists it must validate under #1389 and belong to the same TASK. The approved Plan must contain matching ID/ref markers. Sidecar `context_binding.context_ref` must equal the current semantic ref. `snapshot_ref` is audit-only and is not a preflight stale key.

A semantic `context_ref` change fails preflight and requires a new Plan/review/approval. A timestamp/resolver-only exact snapshot change with unchanged semantic ref does not invalidate the Plan.

An unresolved conflict backed by at least two authoritative sources cannot produce C-3' `AUTO_APPROVED`; it must use a non-auto decision path. No Intent Context means the optional binding is omitted for backward compatibility.

## Consequences

### Positive

- Source → Context → approved Plan → execution reference is reconstructable.
- Exact audit snapshot changes do not cause false stale.
- Existing Plan/approval identities remain unchanged.
- #1385 can consume semantic Context refs without owning their semantics.

### Negative / Risks

- Planners using Intent Context must write two exact marker lines into `plan.md`.
- Any of the six Plan Package artifacts changing requires sidecar re-issuance.
- Actor authenticity remains intentionally unsolved here.

## Related

- #981 — Plan Contract owner
- #1403 — Intent Context Plan-binding slice
- #1389 / PR #1396 — Intent Context identity contract
- #1399 — Dynamic Context Engine adapter
- #872 — Plan Package / c3-prime
- #980 — Principal / ActorSession authenticity
- #1385 — Work Item Graph consumer
- This ADR occupies `adr-002`; #980 uses `adr-003` or later.
