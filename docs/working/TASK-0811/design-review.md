# TASK-0811 — pre-C-3 AI self-review record

> Three rounds of `検討 → レビュー → 対応 → レビュー` on PR #1522.
> **This is AI self-review, not an independent reviewer, Human C-3, C-4,
> or the official 17-item C-1 execution review.** No production promotion
> behavior, Hook or HO changes have been implemented.

## Loop 1: owner / single source of truth

- Finding: original proposed HO 'one line' looked like a malformed fifth
  responsibility-class table row.
- Correction: specify a single proposed bullet under existing
  `## 境界の原則` without changing the four-class table, and explicitly
  prohibit AI application before synchronous C-3.
- Re-review: PASS for the **proposal quality only**; #811 C-3 still open.

## Loop 2: provenance, privacy and authority spoofing

- Finding: append-only JSONL record / free-text `actor` cannot authenticate
  Human approval; sample missing bindings to the applied source revision.
- Correction: `candidate_revision`, `decision_record_id`,
  `approval_authority_ref`, `applied_artifact_ref`, complete proposed
  decision fields; approval must independently resolve to a trusted
  Human/policy source and verified applied ref.
- Re-review: PASS for proposed model; no executable gate or authorized
  actual approval event has been produced.

## Loop 3: evidence strength and historical unsafe memory

- Finding: uncertain digest workaround must not be declared malicious
  without current verification, nor silently promoted as a safe recipe.
  A trace of a read operation alone cannot prove memory affected an
  agent's behavior.
- Correction: provisional `needs_evidence`; `reject` only after verified
  unsafe source/policy conflict. Migrated #1157 AC-1 demands source-pinned
  read + positive/negative control of downstream use.
- Re-review: PASS for this non-canon plan; fixture / runtime evidence
  remains explicitly outstanding.

## Verified at this phase

- #811 Human selected medium documentation-only scope on 2026-07-12,
  but did not give exact-plan synchronous C-3.
- #1157 augmented acceptance is retained (including Aug-27 corrections).
- Raw `improvement-seeds.md` and derived `improvement-digest.md`
  actually exist on the examined main revision.
- Context Lifecycle, seeds-hygiene, retro-phase and evaluation-trust-boundary
  remain cited source contracts rather than duplicated policy owners.
- No HO file, active workflow, canonical Plan, runtime gate or real audit
  log is modified by this preparatory PR.

## Not verified / cannot be closed by this PR

- [ ] Exact-plan Human C-3 and HO approval.
- [ ] Post-C-3 canonical Gate documentation / template / audit log policy.
- [ ] Human HO application and C-4 review for the future implementation.
- [ ] Official C-1 17-item executed checklist.
- [ ] Migrated #1157 actual-read effectiveness, supersession, bounded
      budget, cross-run reuse and digest provenance tested in real runs.
- [ ] Candidate examples validated against executable fixtures.
- [ ] End-to-end trust ledger / production promotion measured.

## Additional guard review: unapproved Plan path

- Finding: placing the draft at `docs/working/TASK-0811/plan.md` risks an
  operational consumer treating a proposal as canonical Plan despite its
  status text. This is a status-vs-path authority confusion.
- Correction: moved it to `plan-proposal.md` with explicit non-canon
  frontmatter. Formal `plan.md` must be created only through G0 / Human
  review, and synchronous C-3 binds to its exact revision.
- Re-review expectation: assert there is **no** `plan.md` in this PR tree,
  and that all references point to `plan-proposal.md`.

## Git evidence follow-up: three design review passes (2026-10-08)

- **G-1 / SSoT**: Git is a revisioned evidence and change ledger only;
  original RunEvidence, canonical Plan, Human C-3/C-4, Permission and
  Evolution PromotionDecision remain separate authorities. PASS for
  non-canon design §9; no runtime changes.
- **G-2 / Provenance + privacy**: exact source SHA and source scope are
  required; Git history / merged status cannot prove Human identity or
  effect. Redact or decline forbidden cross-scope propagation. PASS
  for the proposal; no executable gate or real ledger record generated.
- **G-3 / Real failure case**: #1525 / PR #1526 demonstrate observed
  TA-114 collision detected by pre-existing deterministic TC-20.
  Avoid a duplicate memory rule. Until exact-head CI passes and later
  recurrence evidence exists, this is a *candidate*, not validated
  prevention. PASS for proposal quality; effectiveness is NOT PROVEN.

The CI result for planning PR #1522 itself may remain failing until
its inherited TC-20 collision on main is resolved, and its **own**
exact-head checks complete successfully after reconciliation. Do not
waive or misclassify the failing Test as a PASS.

## Merge meaning

This preparatory PR may be considered only as a **non-authoritative
planning artifact**. Even if its own CI and review complete, it
must not close #811, unlock executable changes or be used as evidence
of C-3 / Human-owned C-4 on subsequent PRs.
