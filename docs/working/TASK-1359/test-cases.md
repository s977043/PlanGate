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
| Contract | COMP-1358-01: #1358 Minimum Sufficient Test Set ownership is preserved | PR #1358 | TC-12 |

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

- Input: one-file behavior-preserving wording/config style change with no knowledge/structure change.
- Expected: no empty Knowledge Delta section; Plan remains compact.
- Expected source: AC-06/10.
- Type: manual semantic fixture review / negative control.
- Verification method: confirm no empty/ritual Knowledge Delta section is emitted.

### TC-07: Knowledge Delta fires for changed domain understanding

- Input: newly confirmed rule invalidates an existing responsibility/name boundary.
- Expected: Newly learned / Existing representation / Delta / Structural response are recorded.
- Expected source: #867 / AC-06/07.
- Verification method: confirm all five Knowledge Delta fields are materially populated and structural response is tied to current evidence.

### TC-08: Structural change starts from a safe baseline

- Input: refactor required but behavior safety is not established.
- Expected: Characterization/Safety Net precedes Preparatory Refactoring; no structural work from RED baseline.
- Expected source: #867 / AC-08.
- Verification method: confirm Work Breakdown orders safety baseline before structural change and does not require RED during refactor.

### TC-09: Pre-PR re-check identifies changed unknown state

- Input: Plan assumption was resolved during implementation and a new unknown was discovered.
- Expected: pre-PR review records resolved assumption + new unknown + scope impact.
- Expected source: AC-09.
- Verification method: run/inspect `diff-audit` against the fixture diff and confirm assumption state + newly discovered Unknown are reported.

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
- Expected source: AC-13/14.
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

## Edge Cases

- Prior artifact exists but is stale: record provenance/freshness; do not treat as current fact without validation.
- Multiple artifacts conflict: classify as Unknown/Blocking Unknown instead of choosing silently.
- Knowledge Delta is identified but structural response is outside current scope: record Deferred structural work / new Issue candidate.
- Pre-PR re-check finds a new Blocking Unknown: PR readiness must stop.

## Minimum Sufficient Test Set

The suite intentionally keeps one positive and one negative control for prior-artifact materiality,
one negative control for conditional Knowledge Delta, and distinct safety cases for readiness/refactor/pre-PR.
TC-12 is retained because it proves a distinct compatibility contract with the immediate dependency #1358, not another TASK-1359 behavior trace.
Do not add cases that prove the same Trace and failure mode without a distinct boundary or risk.
