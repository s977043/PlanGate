# PBI INPUT PACKAGE: AI Execution ReadinessをPlan作成・レビュー・ai-loop handoffへ統合する

> Source of intent: GitHub Issue #1416 and Human request in the originating conversation.
> This package translates the accepted issue scope into a PlanGate task input. It does not authorize production execution before existing upstream gates allow it.

## Context / Why

AI coding agents can continue quickly even when a plan contains hidden assumptions, unavailable dependencies, undetected failure modes, or no explicit recovery boundary.

PlanGate already has adjacent mechanisms:
- #810 / #1359: Facts / Assumptions / Unknowns / Blocking Unknowns / Readiness
- #894 / #1383: runtime retry / no-progress / stop / convergence
- #1335 / #1337: Plan Design Principles and its frozen paired evaluation

The missing connection is an explicit answer to:

> Is this plan safe and observable enough to hand to an AI agent for autonomous execution?

The proposed concept is **AI Execution Readiness**, using six dimensions:
1. Why / Outcome
2. Assumptions
3. Dependencies
4. Unknowns / Surprises
5. Detectability
6. Recovery / Escalation

## What（Scope）

### In scope

- Define canonical responsibility and semantics for the six AI Execution Readiness dimensions.
- Integrate the concept into existing Plan creation / C-1-C-2 review / ai-loop handoff surfaces without introducing a parallel gate subsystem.
- Reuse #810 / #1359 for Assumptions / Unknowns and #894 / #1383 for runtime recovery semantics.
- Distinguish declared dependency from available / verified dependency.
- Define readiness outcomes: ready / needs_clarification / blocked.
- Define material-only representation so simple tasks are not forced to emit ceremonial N/A sections.
- Prepare at least four fixed scenarios:
  - simple
  - dependency-blocked
  - detection-missing
  - recovery-required
- Preserve Human C-3/C-4 ownership.

### Out of scope

- Copying Scrum Definition of Ready as-is.
- Asking six fixed questions to a Human on every task.
- Eliminating all Unknowns.
- Reimplementing ai-loop retry / convergence / NO_PROGRESS control.
- Replacing #894 / #1383 runtime policy.
- Creating a new runtime engine, schema, validator, or Trust Ledger field without measured need.
- Modifying the frozen #1337 evaluation candidate or claiming effectiveness before its paired evaluation result is fixed.
- Bypassing #1359 execution ordering.

## 受入基準

- [ ] AC-01: Six AI Execution Readiness dimensions have one canonical definition and responsibility boundary.
- [ ] AC-02: Assumptions / Unknowns reuse #810 / #1359 rather than creating duplicate state.
- [ ] AC-03: Dependency state distinguishes declared / available / verified.
- [ ] AC-04: Material failure modes have an explicit detector / verifier reference or the plan cannot be ready.
- [ ] AC-05: Retry / re-plan / stop / Human escalation boundaries are expressible without duplicating runtime Loop Control.
- [ ] AC-06: Blocking Unknown or unavailable required dependency prevents ready.
- [ ] AC-07: A high-impact failure with no credible detector prevents ready.
- [ ] AC-08: Simple tasks do not gain mandatory empty sections or N/A ceremony.
- [ ] AC-09: C-1/C-2 reuse existing checks/rubrics where possible; no unnecessary new check IDs.
- [ ] AC-10: Plan-to-ai-loop handoff preserves expected outcome, detector/verifier refs, known blockers/assumptions, and stop/escalation hints.
- [ ] AC-11: Four fixed scenarios cover simple / dependency-blocked / detection-missing / recovery-required.
- [ ] AC-12: Human approval boundaries remain unchanged.
- [ ] AC-13: #1337 frozen evaluation integrity and #1359 execution ordering remain intact.

## Notes from Refinement

- Issue #1416 is the accepted feature scope.
- This task must not treat `declared dependency == available dependency == verified dependency`.
- This task must not treat `implementation complete == behavior verified == failure detectable`.
- The concept is an execution-readiness projection over existing evidence, not a new independent state machine.
- Any deterministic validator is deferred until dogfood shows guidance-only enforcement is insufficient.

## Estimation Evidence

### Risks

- Highest risk: contaminating or bypassing #1337 / #1359 sequencing by editing the same production planning surfaces too early.
- Duplicate responsibility risk: introducing a new Unknown or runtime recovery subsystem.
- Ceremony risk: forcing six sections for low-risk/simple tasks.
- Drift risk: changing canonical Skill/template without corresponding distributed mirrors.
- False-ready risk: textual presence of a dependency or verifier being mistaken for verified availability/effectiveness.

### Unknowns

- Whether #1337 paired evaluation will change the Plan Design Principles baseline/candidate direction.
- Whether #1359 production implementation will already provide part of the final artifact shape.
- Whether dogfood demonstrates a need for deterministic readiness validation.

### Assumptions

- #1416 should compose on top of #1359 rather than compete with it.
- Runtime recovery semantics remain owned by #894 / #1383.
- Planning artifacts can be prepared now without changing frozen production surfaces.
