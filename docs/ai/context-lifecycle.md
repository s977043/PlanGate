# Context Lifecycle — fresh-context checkpoint integration

> This document is an **integration map**, not a new state or context source of truth.
> Existing PlanGate contracts remain authoritative. Related: #1410 / #911.

## 1. Purpose

Long-running agent sessions accumulate implementation discussion, tool output, superseded
decisions, and repair history. Re-reading that history on every turn increases cost and can
bias later decisions toward stale state.

PlanGate handles this by carrying **canonical artifacts and evidence**, not conversational
history, across execution boundaries.

```text
conversation / tool history
        |
        v
checkpoint canonical state
        |
        +-- decisions -> decision-log / canonical plan
        +-- progress  -> INDEX.md + current-state.md
        +-- evidence  -> evidence / report / review artifact refs
        |
        v
fresh session / fresh reviewer
        |
        v
L0 -> phase-required L1 -> L2/L3 on demand
```

A fresh-context transition is **not** a workflow reset. C-3/C-4, Plan binding, RunState,
evidence, and Human-owned authority remain unchanged.

## 2. Ownership and existing SSoTs

| Concern | Owner / existing contract | This policy |
|---|---|---|
| Current task position | working-context: `INDEX.md` + `current-state.md` | reuse |
| Final executable Plan | Plan normalization / canonical `plan.md` (#1220) | reuse |
| Important rationale | `decision-log.jsonl` / ADR | reference, do not duplicate |
| Phase context budget | Dynamic Context Engine (#199) | reuse |
| Subagent working set | `context-packager` / `dispatch/*` | reuse |
| Session/tool handoff | `local-exec-handoff` | reuse |
| Compact-time freshness | PreCompact memory guard (#742) | reuse |
| Durable runtime state | #1025 / RunState follow-ups | reuse |
| Review evidence | River Review Review Artifact / Execution Manifest | evidence producer only |

**River Review does not own execution-session memory.** A River Review artifact can be
referenced from PlanGate evidence, but raw review conversation is not a checkpoint payload.

## 3. Fresh-context triggers

### MUST checkpoint and restart from canonical state

1. worker / agent / model / runtime changes;
2. an independent reviewer starts;
3. a task is handed from implementer to reviewer or between workers;
4. execution is intentionally interrupted because of an external wait or usage limit.

### SHOULD checkpoint and restart when useful

5. compaction or context pressure is imminent;
6. a phase transition materially changes the required working set;
7. repeated repair/review loops have accumulated superseded discussion;
8. the active session contains substantial unrelated exploration that is no longer needed.

Do **not** invent a provider-independent token threshold. When a runtime exposes reliable
usage, it may inform the decision; otherwise use the observable triggers above.

## 4. Checkpoint procedure

Before leaving the current context:

1. **Canonicalize decisions.** Material final decisions belong in canonical Plan /
   decision-log / ADR, not only in chat.
2. **Refresh L0.** Update `INDEX.md` and `current-state.md` with the actual phase,
   completed/current work, blockers, next action, and plan deviation.
3. **Persist evidence by reference.** Put test/review outputs in their existing evidence,
   report, or Review Artifact locations. Do not paste raw tool streams into L0.
4. **Use the existing handoff surface when ownership changes.**
   - model/runtime/session switch: `local-exec-handoff`
   - subagent/worker handoff: `context-packager` + `dispatch/*`
   - reviewer input: review package + diff/evidence
5. If required canonical state is missing or known stale, record the degradation and repair
   it before claiming a resumable checkpoint.

No new `checkpoint.json`, Context Manifest, or RunState is introduced by this policy.

## 5. Fresh-context resume procedure

Start the next context without copying the previous conversation.

1. Load **L0**: `INDEX.md` -> `current-state.md`.
2. Load only the **phase-required L1** artifacts defined by working-context.
3. Load **L2** evidence / decision-log only for a concrete question.
4. Load **L3** history / other TASK context only when the task cannot be resolved from
   L0-L2.
5. For execution, re-check the existing approval / Plan binding contract before writes.
6. For independent review, use the review package, diff, and evidence; do not inherit the
   implementer's conversational reasoning.

The objective is not “small context at all costs”. The objective is the **minimum sufficient,
current, auditable working set**.

## 6. What must not be carried forward

Do not persist or mechanically replay:

- hidden chain-of-thought;
- raw chat transcript as execution state;
- full raw tool output when a result/evidence artifact already exists;
- superseded design alternatives inside canonical Plan;
- credentials, secrets, or personal data;
- provider-specific session internals as PlanGate's canonical state.

Material facts, decisions, failures, and evidence must instead be represented in the existing
canonical artifacts or by stable references.

## 7. Relationship to existing controls

### Plan normalization (#1220)

Removes review-history/superseded-state noise from the executable Plan before C-3. Context
Lifecycle depends on that canonical Plan; it does not create `canonical-plan.md`.

### PreCompact memory guard (#742)

The guard specification, staging script, apply script, and tests exist. **Do not infer that
the Human-owned PreCompact wiring is active from this document.** Its enforcement status
depends on the target environment's settings / Human-applied wiring.

When the guard is actually wired, it is a safety net for stale task memory before compact.
This policy defines what to do with a valid checkpoint afterward: resume from canonical
artifacts rather than replaying conversation history.

### Dynamic Context Engine (#199)

Resolves phase/mode/profile context and budget. It remains the runtime context resolver.
Context Lifecycle defines **when to start a fresh working set**, not a replacement resolver.

### Durable RunState (#1025 and follow-ups)

Owns crash-consistent runtime execution state. Working-context files remain the human/agent
operational view. This policy does not add another state machine.

### External wait / usage interruption (#938)

This policy defines the **checkpoint boundary** for an intentional interruption. It does not
claim that workflow-conductor wait/resume integration is complete. #938 remains the owner of
that operational automation/guidance until its own acceptance criteria are satisfied.

### River Review

River Review provides independent review/evidence. Keeping its execution manifest free of
raw context/hidden reasoning is compatible with this policy. PlanGate may retain a stable
artifact/evidence reference, not the review conversation.

## 8. Review checklist

A Context Lifecycle change is acceptable only when all are true:

- no second SSoT for Plan, context, checkpoint, or RunState was introduced;
- fresh-context transition can resume from L0 + phase-required L1;
- missing/stale state is not silently treated as success;
- independent review does not inherit implementation conversation;
- evidence is retained without raw transcript/hidden reasoning;
- no C-3/C-4/Human-owned authority is weakened;
- simple tasks do not gain mandatory ceremony beyond the existing working-context files.

## 9. Non-goals

- Vector DB / embeddings / long-term memory service
- automatic provider-independent token accounting
- automatic session termination
- storing complete conversations
- changing C-3/C-4 or merge authority
- moving River Review execution state into PlanGate or vice versa
