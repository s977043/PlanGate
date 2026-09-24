# TASK-1359 TEST CASES

## Acceptance Criteria → Test Case Mapping

| Acceptance Criteria | Test Cases |
|---|---|
| AC-01 Prior Artifact inventory | TC-01 |
| AC-02 material selection | TC-02 |
| AC-03 Facts / Assumptions / Unknowns separation | TC-03 |
| AC-04 repository-resolvable-first | TC-04 |
| AC-05 Blocking Unknown readiness | TC-05 |
| AC-06 Knowledge Delta trigger/skip | TC-06, TC-07 |
| AC-07 behavior / structural separation | TC-07, TC-08 |
| AC-08 Characterization / Preparatory Refactoring | TC-08 |
| AC-09 pre-PR re-check | TC-09 |
| AC-10 low-risk output load | TC-06 |
| AC-11 no new C-1 ID | TC-10 |
| AC-12 no speculative Trust Ledger schema | TC-10 |
| AC-13 canonical / mirror alignment | TC-11 |
| AC-14 four fixed fixtures | TC-06, TC-01/TC-02, TC-05, TC-07 |
| AC-15 pre-PR stop vs residual-risk proceed | TC-09, TC-14 |
| AC-16 structural debt deferred (#867 Case 3) | TC-15 |

## Verification Trace

| Trace Type | Trace ID / 内容 | Source / Evidence | Test Cases |
|---|---|---|---|
| AC | AC-01/02 Prior Artifact discovery/materiality | #933, #1359 | TC-01, TC-02 |
| AC | AC-03/04 Unknown classification/repository-first | #810, #1359 | TC-03, TC-04 |
| AC | AC-05 Blocking Unknown readiness | #810, #1359 | TC-05 |
| AC | AC-06/07 Knowledge Delta trigger/separation | #867, #1359 | TC-06, TC-07 |
| AC | AC-08 Characterization/Preparatory | #867 | TC-08 |
| AC | AC-09 pre-PR re-check | #810/#867 | TC-09 |
| AC | AC-10/11/12 minimality/no new C-1/schema | #1335/#960 | TC-10 |
| AC | AC-13 canonical/mirror alignment | #1359 | TC-11 |
| AC | AC-14 four fixed fixtures | #1359 | TC-06, TC-01/TC-02, TC-05, TC-07 |
| AC | AC-15 pre-PR stop vs residual-risk proceed | #810 AC「PR作成を止める条件と、残存リスクを記録して進められる条件が区別される」 | TC-09, TC-14 |
| AC | AC-16 structural debt deferred | #867 Case 3 / #867 AC「3 ケースの fixture」 | TC-15 |
| Contract | COMP-1358-01: #1358 Minimum Sufficient Test Set ownership is preserved | PR #1358 | TC-12 |
| Contract | COMP-1337-01: frozen evaluation candidate is not contaminated before #1337 result fixed | #1337 / #1347 | TC-13 |

## Test Cases

### TC-01: Relevant prior artifact is reused

- Input: same TASK contains a previous artifact directly affecting the same component/contract.
- Expected: Plan records artifact + reused evidence/decision + current impact.
- Expected source: #933 / AC-01.
- Type: manual semantic fixture review.
- Verification method: inspect fixed fixture input and generated/expected Plan artifact; confirm prior artifact trace is present and sourced.

### TC-02: Unrelated prior artifact is not copied

- Input: same TASK contains unrelated historical notes.
- Expected: unrelated artifact is not materialized into Plan; no full-directory dump.
- Expected source: AC-02 / Minimum Sufficient Design.
- Type: manual semantic fixture review / negative control.
- Verification method: confirm unrelated same-TASK artifacts are absent from material Plan output.

### TC-03: Facts and assumptions remain distinct

- Input: one repository-confirmed fact and one unverified assumption.
- Expected: fact has evidence; assumption is not promoted to fact.
- Expected source: #810 / Evidence Before Design.
- Verification method: confirm only repository-backed fact is under Facts and unverified claim remains under Assumptions/Unknowns.

### TC-04: Repository-resolvable question is investigated first

- Input: question answer exists in repository/config/test history.
- Expected: agent resolves it from repository instead of adding Human Decision.
- Expected source: AC-04.
- Verification method: confirm repository evidence is recorded and no unnecessary Human Decision is emitted.

### TC-05: Blocking Unknown prevents ready

- Input: unresolved high-impact requirement with human owner.
- Expected: Blocking Unknown remains visible and `Readiness != ready`.
- Expected source: AC-05.
- Verification method: confirm Blocking Unknown is present and Readiness is `blocked` or `needs_clarification`, never `ready`.

### TC-06: Simple change skips Knowledge Delta ceremony

- Input: one-file behavior-preserving wording/config style change with no knowledge/structure change, no material prior artifact, and no open Unknown.
- Expected:
  - no empty Knowledge Delta section;
  - no `Prior Artifact Impact` section (no material prior artifact exists, so the section is omitted entirely);
  - no empty Facts / Assumptions / Unknowns / Blocking Unknowns / Human Decisions / Readiness sections and no ritual `N/A` / `なし` placeholders for them;
  - Plan remains compact.
- Expected source: AC-06/10.
- Type: manual semantic fixture review / negative control.
- Verification method: inspect the simple fixture's expected Plan output and confirm none of the three section groups above appears empty or as a ritual placeholder.

### TC-07: Knowledge Delta fires for changed domain understanding

- Input: newly confirmed rule invalidates an existing responsibility/name boundary.
- Expected:
  - the four required Knowledge Delta fields — Newly learned / Existing representation / Delta / Required structural response — are recorded;
  - the fifth field, Deferred structural work, appears only when scope-external structural work exists (that case is TC-15); it is not emitted as an empty placeholder here.
- Expected source: #867 / AC-06/07.
- Verification method: confirm the four required fields are materially populated, the structural response is tied to current evidence, and the canonical guidance describes Knowledge Delta as knowledge-difference synchronization rather than code beautification (#867 AC).

### TC-08: Structural change starts from a safe baseline

- Input: refactor required but behavior safety is not established.
- Expected: Characterization/Safety Net precedes Preparatory Refactoring; no structural work from RED baseline.
- Expected source: #867 / AC-08.
- Verification method: confirm Work Breakdown orders safety baseline before structural change and does not require RED during refactor, and that its Verification step points at the existing `refactor_verify` evidence (`docs/working/templates/evidence-tdd-ledger.json`) for external API / persistence / CLI compatibility instead of defining a new gate.

### TC-09: Pre-PR re-check identifies changed unknown state

- Input: pre-PR diff fixture (todo T-17) where a Plan assumption was resolved during implementation and a new **non-blocking** unknown was discovered.
- Expected:
  - pre-PR review records resolved assumption + new unknown + scope impact;
  - the non-blocking unknown is recorded as residual risk with assumption / evidence / verification method, and PR creation may proceed (proceed side of AC-15).
- Expected source: AC-09 / AC-15.
- Type: manual semantic fixture review / positive control for AC-15.
- Verification method: run/inspect `diff-audit` against the fixture diff and confirm assumption state + newly discovered Unknown + residual-risk record are reported and PR readiness is not stopped.

### TC-10: No speculative governance expansion

- Input: all four scenarios can be represented using current Plan/review/evidence structures.
- Expected:
  - no new C-1 check ID;
  - no new Trust Ledger schema;
  - no new generic gate/framework.
- Expected source: #1335 / #960 / AC-11/12.
- Verification method: compare C-1 heading count and schema/file diff; assert no new check ID, Trust Ledger schema, or generic gate file is introduced.

### TC-11: Canonical/mirror alignment

- Input: final branch after sync.
- Expected:
  - canonical skill and distribution mirrors aligned;
  - C-1 heading count unchanged from baseline;
  - repository sync/check CI succeeds.
- Expected source: AC-13 (fixture coverage for AC-14 is verified by TC-01/TC-02/TC-05/TC-06/TC-07, not by TC-11).
- Verification commands:
  - `grep -c '^### C1-' docs/working/templates/review-self.md`
  - `python3 scripts/check-stale-skill-refs.py`
  - `sh scripts/sync-plugin-plangate.sh --dry-run`
  - `sh tests/run-tests.sh`
- Expected: C-1 count unchanged; stale-ref/sync/full tests pass.

### TC-12: #1358 C1-TEST-14 ownership is preserved

- Input: TASK-1359 branch rebased after PR #1358 merge.
- Expected:
  - `C1-TEST-14` remains byte-equivalent to the #1358-merged baseline;
  - TASK-1359 changes only `C1-B1B2-16`, `C1-PLAN-02`, `C1-PLAN-03`, and `C1-PLAN-06` in C-1;
  - C-1 heading count remains unchanged.
- Source: dependency contract COMP-1358-01.
- Type: compatibility / negative control.
- Verification method:
  - save the #1358-merged baseline block for `C1-TEST-14`;
  - compare the same block after TASK-1359 changes;
  - expected diff: empty.

### TC-13: #1337 frozen candidate is not contaminated

- Input: TASK-1359 branch while #1337 paired evaluation result is not fixed.
- Expected:
  - branch diff contains only `docs/working/TASK-1359/**`;
  - no change to `.agents/skills/ai-dev-plan/SKILL.md`;
  - no change to `docs/ai/plan-design-principles.md`;
  - no change to production plan/review templates or mirrors.
- Source: dependency contract COMP-1337-01 / #1337 / #1347.
- Type: compatibility / evaluation-integrity negative control.
- Verification method:
  - compare `main...feat/1359-plan-knowledge-continuity`;
  - assert every changed path starts with `docs/working/TASK-1359/`;
  - if any production surface appears before T-00 completes, FAIL and stop.

### TC-14: Pre-PR new Blocking Unknown stops PR creation

- Input: pre-PR diff fixture (todo T-17) where implementation discovered a new **blocking** unknown (high-impact requirement question with human owner) that the Plan did not have.
- Expected:
  - `diff-audit` reports the new Blocking Unknown;
  - PR readiness is stopped (PR is not created / not marked ready);
  - the unknown is not downgraded to residual risk to let the PR proceed.
- Expected source: AC-15 / #810 AC.
- Type: manual semantic fixture review / negative control for AC-15 (pairs with TC-09 as the proceed side).
- Verification method: run/inspect `diff-audit` against the fixture diff and confirm the Blocking Unknown is reported and the PR-readiness outcome is stop.

### TC-15: Large structural debt is deferred, not executed

- Input: structural-debt fixture (#867 Case 3) where a Knowledge Delta implies a structural change larger than the current task (wide scope, high risk, missing tests).
- Expected:
  - Knowledge Delta records `Deferred structural work` with scope, risk and missing tests;
  - the work is emitted as a separate Issue / Epic candidate (handoff V2 候補 / 別 Issue);
  - the current Work Breakdown does not include the deferred structural change.
- Expected source: AC-16 / #867 Case 3.
- Type: manual semantic fixture review / negative control.
- Verification method: inspect the structural-debt fixture's expected Plan output; confirm Deferred structural work is populated and no Work Breakdown task performs it.

## Edge Cases

- Prior artifact exists but is stale: record provenance/freshness; do not treat as current fact without validation.
- Multiple artifacts conflict: classify as Unknown/Blocking Unknown instead of choosing silently.
- Knowledge Delta is identified but structural response is outside current scope: record Deferred structural work / new Issue candidate.
- Pre-PR re-check finds a new Blocking Unknown: PR readiness must stop (TC-14).
- Pre-PR re-check finds a new non-blocking Unknown: record it as residual risk and proceed (TC-09).

## Minimum Sufficient Test Set

The suite intentionally keeps one positive and one negative control for prior-artifact materiality,
one negative control for conditional Knowledge Delta, and distinct safety cases for readiness/refactor/pre-PR.
TC-12 is retained because it proves a distinct compatibility contract with the immediate dependency #1358.
TC-13 is retained because it proves evaluation-integrity isolation from the frozen #1337 experiment.
TC-14 is retained because it is the stop side of AC-15; TC-09 alone only proves the proceed side.
TC-15 is retained because deferring out-of-scope structural debt (#867 Case 3) is a distinct boundary from TC-07/TC-08, where the structural response is performed inside the task.
Do not add cases that prove the same Trace and failure mode without a distinct boundary or risk.
