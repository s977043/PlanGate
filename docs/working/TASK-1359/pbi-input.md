---
task_id: TASK-1359
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-1359

> Issue: #1359
> Integrates: #933 / #810 / #867
> Related: #1335 / PR #1336, #1358, #960
> Mode candidate: critical（workflow definition change）

## Context / Why

PlanGate has three open gaps that share the same Plan-generation surface.

1. **#933 Prior Artifact Discovery**
   - The same TASK can contain accurate prior artifacts, but later Plan generation may ignore them.
   - The failure is not artifact quality; it is missing retrieval/traceability.

2. **#810 Unknown Discovery**
   - Facts, assumptions, unresolved unknowns and human decisions can be conflated.
   - Repository-resolvable questions may be asked to humans before the repository is inspected.
   - Blocking unknowns can remain while a Plan appears ready.

3. **#867 Knowledge Delta**
   - Newly learned domain knowledge can require names/responsibilities/boundaries to change.
   - Behavior change and structural change can become mixed.
   - Characterization / preparatory refactoring may be required before safe behavior change.

#1335 already established Plan Design Principles:
Evidence Before Design, Minimum Sufficient Design, Explicit Responsibility & Boundary,
Abstraction Requires Evidence, Extension Is Conditional, Design for Verification.

This task integrates the three gaps **upstream into planning guidance** instead of creating three independent gates.

## What — Scope

### In scope

- Define a single Plan-time flow:

```text
Prior Artifacts / Repository Evidence
  -> Facts / Assumptions / Unknowns
  -> Readiness
  -> Knowledge Delta (conditional)
  -> Minimum Sufficient Design
  -> Verification / Work Breakdown
  -> Pre-PR re-check
```

- Add conditional Plan artifact representation for:
  - material prior artifact impact
  - Known Facts / Assumptions / Known Unknowns
  - Blocking Unknowns / Human Decisions Required / Readiness
  - Knowledge Delta
- Define repository-resolvable-first behavior before human questions.
- Define behavior/structural-change separation when Knowledge Delta fires.
- Define Characterization / Preparatory Refactoring triggers.
- Reuse existing C-1 checks; avoid new check IDs unless a demonstrated gap remains.
- Integrate pre-PR re-check into an existing review/diff-audit path rather than introducing a new gate.
- Add fixtures/examples for:
  - simple task
  - prior-artifact reuse
  - blocking unknown
  - knowledge-delta/refactor

### Out of scope

- New generic Unknown subsystem.
- Forcing Knowledge Delta on every Plan.
- Copying all files in TASK directory into Plan.
- New Trust Ledger schema fields without measured insufficiency.
- Reimplementing #794 YAGNI / speculative abstraction review.
- Reimplementing refactor verification already represented by existing TDD/evidence mechanisms.
- River Review diff-review duplication.
- Direct edits to HO paths in this AI-owned phase.
- Changing C-1 total count.

## Acceptance Criteria

- AC-01: Plan generation inventories existing same-TASK artifacts before design.
- AC-02: Only material prior artifacts are traced into the Plan; unrelated artifacts are not copied.
- AC-03: Facts, Assumptions, Known Unknowns, Blocking Unknowns and Human Decisions are distinguishable.
- AC-04: Repository-resolvable questions are investigated before being escalated to a human.
- AC-05: Blocking Unknowns prevent `Readiness=ready`.
- AC-06: Knowledge Delta has explicit trigger and skip conditions.
- AC-07: When Knowledge Delta fires, behavior and structural changes can be separated into identifiable units.
- AC-08: Characterization / Preparatory Refactoring conditions are defined; structural change is not performed from a RED baseline.
- AC-09: Pre-PR review re-checks Plan-time assumptions/unknowns and newly discovered unknowns.
- AC-10: Low-risk tasks do not gain empty sections or ritual `N/A` output.
- AC-11: No new C-1 check ID is added unless current checks cannot express the conformance requirement.
- AC-12: Trust Ledger schema is not expanded without measured evidence that current records are insufficient.
- AC-13: Canonical docs/templates/skills and distributed mirrors remain aligned.
- AC-14: At least four fixed fixtures demonstrate simple/prior-artifact/blocked-unknown/knowledge-delta behavior.

## Evidence

- E-01: #933 documents a real failure where a correct prior artifact existed but was not reread.
- E-02: #810 defines Known Facts / Assumptions / Unknowns and a `Blocking Unknown -> not ready` requirement.
- E-03: #867 defines Knowledge Delta and behavior-vs-structural change separation.
- E-04: #1335 already provides Evidence Before Design and Minimum Sufficient Design, so a second design-principle framework is unnecessary.
- E-05: Current `docs/working/templates/plan.md` already has Questions/Unknowns, Approach Comparison, Change Type, Work Breakdown, Replan and Stop conditions.
- E-06: Current `ai-dev-plan` already requires repository evidence and change-type-aware verification.
- E-07: #1358 adds Minimum Sufficient Test Set and was merged before TASK-1359 implementation. TASK-1359 was rebased onto main and TC-12 confirmed `C1-TEST-14` ownership preservation.
- E-08: #960 still has HO-side C-1 execution drift; this task must not couple non-HO implementation to that unresolved HO patch.

## Unknowns

- U-01: **RESOLVED** — canonical generic pre-PR self-review is `.agents/skills/diff-audit/SKILL.md`.
  - evidence: the skill description explicitly says it is used for commit/PR-before change inspection and is the successor of old self-review.
  - boundary: `review-gate` explicitly says pre-PR self-inspection uses `diff-audit`; `review-gate` itself remains the independent implementation-completion gate.
  - ai-loop note: `docs/workflows/ai-loop/execution-runbook.md` composes `diff-audit` into an ai-loop-specific strengthened pre-PR review; TASK-1359 must not make that ai-loop runbook the generic source of truth.
- U-02: Whether deterministic validation is needed for Blocking Unknown / Readiness after template+skill guidance.
  - owner: agent
  - blocking: no for Phase 1
  - resolution: implement guidance first; add validator only if fixtures show silent non-conformance.
- U-03: **RESOLVED** — use a conditional dedicated `Prior Artifact Impact` table.
  - reason: #933 is specifically a failure of prior evidence not being surfaced into the Plan; a conditional dedicated table makes the reuse decision auditable without copying the whole TASK directory.
  - skip rule: omit the section entirely when no material prior artifact exists.
- U-04: Whether Knowledge Delta needs any new persistent schema.
  - owner: agent
  - blocking: no
  - default: no; only reconsider with measured insufficiency.

## Human Decisions Required

- HD-01: Approve critical-mode Plan before exec.
- HD-02: If an HO path becomes necessary, approve a separate Human-owned patch; do not fold it silently into this PR.
- HD-03: Decide if a proposed validator meaningfully reduces risk after fixtures; default is no validator.

## Estimation Evidence

**Mode**: critical

Reason:
- workflow definition change is explicitly a critical example in `.claude/rules/mode-classification.md`.
- AC count = 14 -> quantitative critical threshold (11+).
- touches multiple planning/review/distribution layers.

**Dependency**:
- #1358 merge/rebase dependency: **RESOLVED** — branch rebased to main `7b523a4530d0c2b324ecd9464736d0c7776a2bdc`; TC-12 PASS.
- #960 HO work may proceed separately; TASK-1359 does not require modifying those HO files in Phase 1.


## Notes from Refinement — 2026-09-23

- Generic pre-PR self-review source of truth: `.agents/skills/diff-audit/SKILL.md`.
- Independent implementation review remains `.agents/skills/review-gate/SKILL.md`; do not merge their responsibilities.
- ai-loop-specific strengthened review in `docs/workflows/ai-loop/execution-runbook.md` is a composition layer, not the generic PlanGate source.
- Prior Artifact Impact will be a **conditional dedicated section** rather than a field inside Required Context.


## Source ownership refinement — 2026-09-23

- `.claude/rules/working-context.md`: HO core artifact/state/gate contract; TASK-1359 does not modify it.
- `docs/ai-driven-development.md` / bundled reference: B-1→B-3 workflow definition extended with conditional guidance.
- `.agents/skills/ai-dev-plan/SKILL.md`: executable planning guidance.
- `docs/working/templates/plan.md`: conditional artifact representation.
- `docs/working/templates/review-self.md`: existing C-1 conformance only.
- `.agents/skills/diff-audit/SKILL.md`: generic pre-PR maker audit.

C-1 landing is fixed before implementation:
- Prior Artifact / repository-first → C1-B1B2-16
- Unknown classification / readiness → C1-PLAN-02
- Knowledge Delta scope discipline → C1-PLAN-03
- safe structural-change ordering → C1-PLAN-06
- C1-TEST-14 → #1358 ownership; TASK-1359 must not modify it.


## Dependency resolution — 2026-09-23

- PR #1358: MERGED
- TASK-1359 branch: rebased onto current main
- compare: ahead 1 / behind 0 at rebase evidence point
- `C1-TEST-14`: unchanged from #1358-merged baseline
- `ai-dev-plan` / `diff-audit` / `review-gate`: branch == main
- evidence: `evidence/c1-review/2026-09-23-rebase-compatibility.md`
- Blocking dependency from #1358: **resolved**
