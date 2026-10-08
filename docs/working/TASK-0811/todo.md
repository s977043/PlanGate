# TASK-0811 — tracking / handoff

Source: #811 and `TASK-0811/pbi-input.md`. This file is a task-specific
planning checklist, **not** proof of Human approval or completed production
Memory Promotion Gate.

## Completed preparation

- [x] Verify #811 decisions and ownership boundaries, including 2026-07-12
      medium-documentation decision and C-3 requirement
- [x] Recover #1157 migrated ACs and their Aug-27 correction
- [x] Verify the current `improvement-seeds.md` and
      `improvement-digest.md` exist, and distinguish raw historical evidence
      from derived, adoption-gated digest
- [x] Prepare `plan-proposal.md` (non-canonical pre-C-3) and `design-proposal.md` (non-canon)
- [x] Complete three AI self-review/adaptation loops on PR #1522, recorded in `design-review.md` (not independent C-4 approval)
- [x] Define Git's evidence / source revision / PR and merged SHA role in non-canon `design-proposal.md` §9, plus three additional Git-boundary self-review passes
- [ ] Confirm latest-head CI/links/mergeability. Existing Test failure on this docs-only PR was traced to inherited duplicate TA-114; separate fix PR #1526 / issue #1525 (all checks must pass on the relevant final head). C-4 is Human-owned

## Unresolved blockers and next actions

- [ ] **G0 Human-owned**: review the proposal and authorize preparing a formal
      canonical `plan.md`. Do not let the proposal path act as execution Plan.
- [ ] **G1 Human-owned synchronous C-3**: approve/revise/reject that formal
      canonical Plan, candidate/ledger terms, and HO one-line wording. Do not
      infer this from an Issue/PR comment or broad automation request.
- [ ] **E1 after G1**: move approved design to
      `docs/ai/memory-promotion-gate.md`, add
      `docs/working/templates/memory-promotion-candidate.md`, decide whether
      to materialize `_audit/memory-promotion-log.jsonl` or leave a schema
      until the first approved record. No CLI/Hook runtime.
- [ ] **E2 after G1**: independent candidate examples and boundary validation,
      C-1 17-item review, evidence-backed 3+ scenarios, adoption decision.
- [ ] **G2 Human-owned**: apply any approved
      `.claude/rules/responsibility-classes.md` HO change; independent
      verification of the actual settings/rules.
- [ ] **Migrated #1157 AC-1**: real trace demonstrating a selected seed/digest
      was read and used, including positive/negative control, not just docs.
- [ ] **Migrated #1157 AC-2 / -2b / -3 / -4**: supersession without seed
      mutation, bounded budget, cross-run reuse evidence, raw vs derived
      digest source-of-truth and provenance checks.
- [ ] **C-4 and issue closure**: Human review/merge after tests on exact
      head, and close #811 only after all original and migrated ACs pass.

## Explicit stop / defer boundary

Issue #811 is **not complete** when this pre-C-3 planning PR merges.
No other open ai-loop V2 Issue is implicitly part of TASK-0811.
PlanGate retains its C-3 / C-4 / HO / RunState / Evidence / PromotionDecision
owners. An executable Memory Promotion Gate without Human C-3 is prohibited.
