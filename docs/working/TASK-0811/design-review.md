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
  PR #1526 passed all four workflow checks on exact head
  `88f4c39c4720540c31b4051be86ecdd0b3494946` and was subsequently
  merged as fixed `main` `5c1651abe3a15a661a453672fb9d4e841761aeaf`.
  Avoid a duplicate memory rule; long-term recurrence improvement is
  still NOT PROVEN. PASS for proposal quality and single fix verification,
  **not** an adopted Memory Promotion decision.

The previous Test on planning PR #1522's old head conclusively failed
with TC-20 duplicate TA-114 (`1517 passed / 1 failed`). Its underlying
cause is now fixed on main, but that historical run is **still FAIL**:
do not relabel it. Check a new workflow run against the updated main
merge ref and pin the exact PR head. Do not infer quality from #1526
passing on a different commit.

## Current-main reconciliation: three review/adaptation loops (2026-10-08)

1. **検討 → evidence review → correction → review**: The previous
   #1522 Test failure was reproduced in the exact failed job log:
   `ta-61-extra-contract.sh` TC-20 detected duplicate numeric ID 114
   (1517 passed, 1 failed). Compare against `main` and #1526: duplicate
   TA-114 was already present before this documentation PR. **Adapted**
   the proposal to cite the merged PR #1526 and issue #1525 closed.
   Final review: no false claim that historical FAIL was PASS.
2. **検討 → owner/security review → correction → review**: Validate
   `main` at `5c1651abe3a15a661a453672fb9d4e841761aeaf`; the current
   planning PR still adds only four `docs/working/TASK-0811/*`
   proposal/tracking files. **Adapted** Git/revision disclosure and
   maintained the unapproved `plan-proposal.md` path. Final review:
   no change to HO, Hook, production rule, runtime, canonical Plan or
   approval authority. This is NOT independent Human C-3/C-4 review.
3. **検討 → acceptance/CI review → correction → review**: Merge of
   #1526 does not retroactively repair the historical #1522 Test.
   **Adapted** `todo.md` to require this PR's latest-head Test +
   CI + CodeQL + Issue Link on the current merged base and the separate
   Human-owned C-4 decision. Final review: PASS for documentary
   truthfulness and bounded changes; **CI/approval may remain pending**.

Do not count these self-review loops as the future 17-item C-1
independent review or as proof of #1157's real cross-run seed usage.

## 2026-10-08 current-main owner crosswalk — three review loops

**Loop 1 — owner overlap / correction / re-review.**
Finding: #811's proposed promotion decision can look like a new L4
adoption authority, while newly merged `docs/ai/growth-harness.md`
(#1506, #1530) owns L1-L4. Correction: design §1 now explicitly
maps each stage and fixes #811 as advisory knowledge-placement and
risk assessment, not new scheduler, `PromotionDecision`, or
approval. Re-review: no new authority and no duplicate SSoT proposed.

**Loop 2 — claims vs experimental evidence / correction / re-review.**
Finding: the #1495 Ratchet claim-binding implementation can be
misread as completed adoption or effect measurement. Correction:
separate structurally bound `expected_prevention` from evaluator-owned
paired replay, mutants, negative controls, activation, and
`PromotionDecision`; the actual memory candidate → Ratchet path
remains unimplemented. Re-review: any `approve` label in #811
is **proposal-only**, not executable L4 PASS.

**Loop 3 — lifecycle and HO dependency / correction / re-review.**
Finding: Growth Harness, #1157 seed read-path proposal, and #811
responsibility-classes patch refer to distinct HO changes, some to
the same `working-context.md` owner and mirror. Correction: document
source/revision, exact dependency order and need to regenerate a patch
against the Human-applied upstream state; `todo.md` tracks after-C-3
integration. Re-review: no HO edits in this PR; L3 not falsely
declared active. Growth Harness provisional N=5/M=3 settings never
constitute approval or proof of effect.

**Scope of this review:** comparison against merged `main`
`e02c7a45808fbd5861428be170a06abf0742d21f`.
These are **AI self-review and documentation corrections only**:
no new real-run memory evidence, independent Human C-3 / C-4,
or production Gate activation is claimed.

## Merge meaning

This preparatory PR may be considered only as a **non-authoritative
planning artifact**. Even if its own CI and review complete, it
must not close #811, unlock executable changes or be used as evidence
of C-3 / Human-owned C-4 on subsequent PRs.
