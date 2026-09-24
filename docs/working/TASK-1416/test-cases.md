---
task_id: TASK-1416
artifact_type: test-cases
schema_version: 1
status: draft
---

# TASK-1416 Test Cases

## Traceability

| AC | Test Cases |
|---|---|
| AC-01 | TC-01, TC-02 |
| AC-02 | TC-02 |
| AC-03 | TC-03 |
| AC-04 | TC-04 |
| AC-05 | TC-05 |
| AC-06 | TC-03, TC-06 |
| AC-07 | TC-04 |
| AC-08 | TC-07 |
| AC-09 | TC-08 |
| AC-10 | TC-09 |
| AC-11 | TC-03, TC-04, TC-05, TC-07 |
| AC-12 | TC-10 |
| AC-13 | TC-11 |

## TC-01: canonical six dimensions are defined once

**Given**
- current main after #1359 production integration

**When**
- canonical planning guidance and distributed mirrors are inspected

**Then**
- Why / Outcome
- Assumptions
- Dependencies
- Unknowns / Surprises
- Detectability
- Recovery / Escalation

are defined with one canonical owner, and mirrors point to or faithfully sync from that owner.

**Verification**
- deterministic path/content scan + review of owner matrix

## TC-02: Assumptions / Unknowns reuse existing ownership

**Given**
- #810/#1359 semantics are present

**When**
- #1416 production diff is reviewed

**Then**
- no parallel Unknown registry/state machine is introduced;
- Blocking Unknown semantics remain compatible;
- repository-resolvable questions continue to be resolved before Human questioning.

**Verification**
- diff review against #1359-owned surfaces

## TC-03: dependency-blocked fixture

**Input**
- required dependency is declared;
- dependency is not currently available;
- no safe delayed-binding path exists.

**Expected**
- readiness != ready;
- output explains unavailable required dependency;
- mere declaration does not count as verification.

**Invariant**
```text
declared != available != verified
```

## TC-04: detection-missing fixture

**Input**
- implementation affects a high-impact behavior;
- no test/verifier/runtime signal can distinguish correct from incorrect outcome.

**Expected**
- readiness != ready;
- missing detectability is explicit;
- "implementation completed" does not satisfy verification.

**Invariant**
```text
implementation complete != behavior verified != failure detectable
```

## TC-05: recovery-required fixture

**Input**
- execution can enter a recoverable failure state;
- retry/re-plan/stop/Human escalation boundary is absent.

**Expected**
- readiness = blocked or needs_clarification according to canonical severity rule;
- runtime retry algorithm is not copied into Plan;
- output points to runtime owner.

## TC-06: blocking unknown fixture

**Input**
- material requirement cannot be resolved from repository evidence;
- Human decision is required before implementation.

**Expected**
- readiness = needs_clarification or blocked;
- Human decision is surfaced;
- execution does not proceed as ready.

## TC-07: simple-ready fixture

**Input**
- low-risk local docs/config change;
- no material unverified assumption;
- dependencies are already available;
- deterministic validation exists;
- normal revert is sufficient recovery.

**Expected**
- readiness = ready;
- six empty sections are not emitted;
- no ceremonial N/A list is required;
- minimum material evidence remains visible.

## TC-08: C-1/C-2 integration does not expand rubric unnecessarily

**Given**
- current C-1 check IDs after #1359

**When**
- #1416 diff is applied

**Expected**
- existing relevant checks are extended first;
- no new C-1 ID unless a documented, reviewed enforcement gap proves necessary;
- no separate giant C-2 rubric is created.

**Verification**
- before/after check ID count and diff review

## TC-09: Plan → ai-loop handoff preserves readiness context

**Input**
- Plan with:
  - expected outcome
  - verified/unverified dependency state
  - verifier/detector refs
  - known blocker/assumption
  - stop/escalation hint

**Expected**
- handoff preserves these references;
- runtime policy itself remains owned by #894/#1383;
- no duplicate retry/convergence implementation appears in planning layer.

## TC-10: Human approval boundary is unchanged

**Expected**
- C-3 remains required before critical production execution;
- C-4 remains Human-owned merge gate;
- Execution Readiness does not auto-approve execution or merge.

## TC-11: frozen evaluation / upstream ordering integrity

**Given**
- #1337 result is not fixed or #1359 downstream gate is incomplete

**Expected**
- production execution for TASK-1416 is blocked;
- planning-only artifacts may change;
- production planning surfaces are not modified.

**After unblock**
- T-00 revalidates current main before any production edit.

## Edge Cases

- Dependency exists in repository but required version/permission/environment is unavailable.
- Verifier command exists but is known to skip the affected behavior.
- Recovery can retry forever without progress detection.
- A non-blocking Unknown becomes blocking after implementation discovery.
- #1359 already implements one of #1416's proposed fields; #1416 must reuse rather than duplicate it.
- A simple task technically has all six dimensions but only one or two are material enough to project.
