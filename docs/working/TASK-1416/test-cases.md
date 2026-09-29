---
task_id: TASK-1416
artifact_type: test-cases
schema_version: 1
status: draft
---

# TASK-1416 Test Cases

## Convention Evidence

| Rule | Source |
|---|---|
| Execution Readiness is a projection, not a new independent gate/state subsystem | Issue #1416 + TASK-1416 PBI/Plan decision |
| Assumptions / Unknowns ownership | #810 / #1359 |
| Runtime retry / convergence / NO_PROGRESS ownership | #894 / #1383 |
| Human C-3 remains authorization boundary | .claude/rules/working-context.md |
| C-1 verdict enum is PASS / WARN / FAIL | schemas/review-self.schema.json |
| Critical execution requires explicit dependency ordering and concrete execution details | current Plan / ToDo / C-1 templates |

## Readiness Oracle

### ready

Use only when all material execution prerequisites are available, Blocking Unknown = 0, material failures are credibly detectable, and task-risk-appropriate re-plan / stop / escalation boundaries exist.

### needs_clarification

Use when a Human answer or decision is the missing prerequisite and that answer can resolve the requirement / priority / risk-tolerance uncertainty before execution.

### blocked

Use when execution depends on an unavailable external prerequisite or unavailable safety/evidence capability, including unavailable dependency, required evidence, detector, or recovery/stop boundary.

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
| AC-11 | TC-03, TC-04, TC-05, TC-06, TC-07 |
| AC-12 | TC-10 |
| AC-13 | TC-11 |
| AC-14 | TC-12 |

## TC-01: canonical six dimensions are a projection

**Input**
- current main after #1359 production integration
- current Plan / Skill / Review / runtime owner map

**Expected**
- six dimensions have one responsibility map;
- existing canonical fields remain source of truth;
- no new independent Readiness state machine / Unknown registry / retry policy is introduced.

**Verification**
- owner matrix review + production diff inspection

**Expected verdict**
- PASS only when duplicate canonical ownership = 0.

## TC-02: Assumptions / Unknowns reuse existing ownership

**Input**
- #810/#1359 semantics are present.

**Expected**
- no parallel Unknown registry/state machine;
- Blocking Unknown semantics remain compatible;
- repository-resolvable questions are investigated before Human questioning.

**Verification**
- diff review against #1359-owned surfaces

**Expected verdict**
- PASS.

## TC-03: dependency-blocked fixture

**Input**
- required dependency is declared;
- dependency is not currently available;
- no safe delayed-binding path exists.

**Expected readiness**
- **blocked**

**Expected evidence**
- unavailable dependency is named;
- declaration alone is not treated as verification.

**Invariant**
- declared != available != verified

## TC-04: detection-missing fixture

**Input**
- implementation affects a high-impact behavior;
- no test/verifier/runtime signal can distinguish correct from incorrect outcome.

**Expected readiness**
- **blocked**

**Expected evidence**
- missing detector is explicit;
- implementation completion is not accepted as verification.

**Invariant**
- implementation complete != behavior verified != failure detectable

## TC-05: recovery-required fixture

**Input**
- execution can enter a high-impact failure state;
- required re-plan / stop / Human escalation boundary cannot yet be established.

**Expected readiness**
- **blocked**

**Expected evidence**
- missing recovery/stop boundary is explicit;
- runtime retry algorithm is not copied into Plan;
- runtime owner reference points to #894/#1383.

## TC-06: human-clarification fixture

**Input**
- material requirement has two valid interpretations;
- repository evidence cannot select between them;
- one Human product decision resolves the ambiguity;
- external dependencies and verification capabilities are otherwise available.

**Expected readiness**
- **needs_clarification**

**Expected evidence**
- exact Human decision is surfaced;
- execution does not proceed before the answer;
- state is not misclassified as blocked because no external prerequisite is missing.

## TC-07: simple-ready fixture

**Input**
- low-risk local docs/config change;
- no material unverified assumption;
- required dependencies are available and verified for this scope;
- deterministic validation exists;
- normal revert is sufficient recovery.

**Expected readiness**
- **ready**

**Expected evidence**
- six empty sections are not emitted;
- no ceremonial N/A list;
- minimum material evidence remains visible.

## TC-08: C-1/C-2 integration does not expand rubric unnecessarily

**Input**
- current C-1 check IDs after #1359;
- current C-2 interface.

**Expected**
- existing relevant checks are extended first;
- no new C-1 ID without documented enforcement gap;
- no separate giant C-2 rubric.

**Verification**
- before/after C-1 check ID count + review interface diff

**Expected verdict**
- PASS.

## TC-09: Plan → ai-loop handoff preserves readiness context

**Input**
- Plan with expected outcome;
- verified/unverified dependency state;
- verifier/detector refs;
- known blocker/assumption;
- stop/escalation hint.

**Expected**
- handoff preserves references;
- runtime policy remains owned by #894/#1383;
- no duplicate retry/convergence implementation in planning layer.

**Expected verdict**
- PASS.

## TC-10: Human approval boundary is unchanged

**Input**
- critical Plan that is execution-ready.

**Expected**
- C-3 is still required before production execution;
- Execution Readiness does not auto-approve;
- merge remains Human C-4.

**Expected verdict**
- PASS.

## TC-11: frozen evaluation / upstream ordering integrity

**Input**
- #1337 result is not fixed OR #1359 production integration is incomplete.

**Expected readiness**
- **blocked**

**Expected repository behavior**
- production planning surfaces are not modified;
- planning-only TASK-1416 artifacts may change;
- no production task starts.

## TC-12: Pre-C3 Replan Gate / physical dependency

**Input**
- upstream dependencies become available.

**Expected sequence**
1. fresh dependency check;
2. production surface inventory;
3. ai-loop handoff inventory;
4. concrete Plan v2 / todo v2 / test-cases v2 regeneration;
5. canonical 25-item C-1;
6. independent C-2;
7. Human C-3;
8. production tasks.

**Expected graph invariant**
- every production task has a transitive dependency on Human C-3 APPROVED;
- Human C-3 depends on completed C-1 and C-2;
- current planning baseline contains no executable production task.

**Expected verdict**
- PASS only if graph and narrative order agree.

## Edge Cases

- Dependency exists in repository but required version/permission/environment is unavailable -> blocked.
- Dependency was verified in another environment but no evidence applies to current scope -> not verified.
- Verifier command exists but skips affected behavior -> blocked for high-impact change.
- Recovery can retry forever without progress detection -> blocked until stop/no-progress boundary is available.
- A non-blocking Unknown becomes blocking after implementation discovery -> re-plan and readiness downgrade.
- #1359 already implements one proposed #1416 field -> reuse, do not duplicate.
- Simple task technically has all six dimensions but only one or two are material -> keep projection compact.
- Human product choice is the only missing input -> needs_clarification, not blocked.
