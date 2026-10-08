---
task_id: TASK-0811
artifact_type: design-proposal
status: NON_CANONICAL_PROPOSED_AWAITING_C3
mode: high-risk
source_issue: 811
baseline_main: 7349c2b1ba2a9cf84ba3b38a3aa635398dc4e95c
---

# TASK-0811 — Memory Promotion Gate / pre-C-3 plan

> **Status: planning artifact only; NOT an approved executable Plan.**
> The Human decision on 2026-07-12 selected a medium-sized **documentation** scope,
> but explicitly required synchronous **C-3** because the intended one-line
> `.claude/rules/responsibility-classes.md` addition touches HO.
> The Human's design selection is **not** C-3 approval. Do not mark this Plan
> APPROVED, run execution, apply the HO edit, or report Issue #811 complete.

## Goal / acceptance

Prepare a reviewable, non-canonical design proposal for an auditable Memory Promotion Gate, preserving the existing
PlanGate / ai-loop / River Review authority boundaries. Scope owner is #811.
The intended deliverables **after C-3** are:

1. `docs/ai/memory-promotion-gate.md`: normative gate documentation
   (candidate contract, policy, decision vocabulary/reasons, trust ledger,
   3+ worked examples, phased adoption decision).
2. `docs/working/templates/memory-promotion-candidate.md`: reusable candidate /
   decision template.
3. `docs/working/_audit/memory-promotion-log.jsonl`: append-only operation log,
   with the schema specified in item 1 (new file only if C-3 confirms practical
   retention of real records rather than a committed empty placeholder).
4. **HO proposal only**, in a non-HO plan/handoff: a one-line addition to
   `.claude/rules/responsibility-classes.md`. Human separately applies
   the line after approved C-3; AI must not modify this protected file.
5. Linkage: #754 seeds-hygiene (consolidation), #811 promotion,
   #869/#1376 evolution / traceability and #874 evidence. Do not create a
   duplicate SSoT or new promotion authority.

## Scope boundaries / out of scope

- **Documentation first.** No CLI, Hook, automatic promotion, auto-merge,
  outside-repository writes, external service, memory schema runtime, or vector DB.
- `knowledge-capture` immediate capture = low-risk/single-case reference;
  Gate = high-risk or persistent executable guidance.
- Existing C-3 (Plan execution approval), C-4 / Human merge, HO, permissions,
  deterministic Verifier, Policy Verdict and Evolution `PromotionDecision`
  **retain their owners**. The Memory Promotion Gate is an **advisory proposal
  and review contract**, not a replacement authority.
- `MEMORY.md`/Git memory is retained knowledge only; cannot override Plan,
  RunState, Evidence, owner privacy or executed permissions.
- Do not rewrite append-only `improvement-seeds.md`; contradictions and
  withdrawal should be represented in a separate derived view / linked
  superseding record, not by erasing historical entries.

## Evidence / reviewed source of requirements

- Issue #811 plus 2026-07-12 Human decision, 2026-07-18 responsibility split,
  and Aug-26/27 migrated #1157 AC comments.
- `docs/working/TASK-0811/pbi-input.md` (draft requirements; **not C-3**).
- `docs/ai/context-lifecycle.md` (retained knowledge vs task state).
- `docs/ai/seeds-hygiene.md` / `docs/ai/retro-phase.md` (append-only + adoption).
- `docs/ai/ai-loop-v2/evaluation-trust-boundary.md` (candidate cannot amend
  its own decision authority).
- `.claude/rules/responsibility-classes.md` (Human-owned C-3/C-4/merge/HO).

## Work breakdown / approvals

| ID | Work | Owner | Completion condition |
|---|---|---|---|
| P1 | Reconcile #811 Human decisions / migrated #1157 ACs with existing owners | AI | Requirements inventory grounded in repo / comments |
| P2 | Prepare non-normative candidate / decision / ledger examples | AI | Reviewable proposal; no authority granted |
| P3 | Three planning review loops: SSoT, security, measurability | AI | All findings corrected or open issue with owner |
| G1 | **Synchronous C-3** on this concrete Plan and HO one-line proposal | **Human-owned** | Existing valid approval artifact for exact plan/hash; no inference from chat/PR |
| E1 | Create canonical doc and template, choose audit log materialization | AI only after G1 | Documentation ACs + #1157 linkage |
| E2 | Independently verify examples, risk/authority boundaries, acceptance evidence | Verifier | FAIL / INCONCLUSIVE never treated as PASS |
| G2 | Apply HO rule addition, if still desired | **Human-owned** | Human application / independent verification |
| G3 | C-4 review and merge | **Human-owned** | Exact-head CI, unresolved 0, actual C-4 decision |
| H1 | Mark Issue #811 complete only after original DoD **and** migrated ACs verified | Workflow | Evidence-backed closure |

## Explicitly transferred #1157 acceptance requirements

These requirements are not discharged merely by authoring Gate documentation:

| AC | Requirement | Observable evidence after C-3 |
|---|---|---|
| 1157-1 | `improvement-seeds.md` is *actually read*, not merely mentioned | Harness run/trace and read evidence with positive & negative control |
| 1157-2 | Wrong knowledge can be superseded / rejected without mutating raw seeds | Provenance-linked correction in derived or separate append-only record |
| 1157-2b | Bounded read/token budget for accumulating seeds | Explicit budget and overflow/fallback tests |
| 1157-3 | Know that cross-run lessons are re-used, not recreated each run | Candidate identity / reuse event and independently checked source |
| 1157-4 | Fix digest relation and source-of-truth | Seeds raw record, adopted digest as **derived** summary, provenance / staleness check |

## Verification / stopping rules

- Before modifying normative/HO files: obtain real C-3 evidence bound to the
  approved Plan revision. Absence => **BLOCKED**, not 'approved in prior chat'.
- Check documentation completeness against all #811 DoD items and the migrated ACs.
- Check minimal scope, reviewer independence, source/owner privacy, no instruction
  or evidence laundering, no duplicate authority or runtime subsystem.
- After changes: validate links, markdownlint, plugin mirror if any `.claude` rules
  change, and exact-head CI/Test/CodeQL as applicable.
- Do not self-approve C-3/C-4 or use a comment/review from the same credential
  as proof of a Human-owned approval.
- The current PR is **pre-C-3 planning only**; merging it would not complete
  #811 or authorize E1/E2/G2/H1.

## Proposed one-line HO patch (NOT APPLIED)

Proposed **one new bullet** under `## 境界の原則` in
`.claude/rules/responsibility-classes.md` (NOT a fifth row in the
four-class table; do not change that table), **only after Human C-3
and by the Human-owned execution path**:

`- Memory Promotion Gate: AI-owned は知見候補・Evidence・差分案の作成、CI-owned は契約検証、Workflow-owned は承認待ち追跡。高リスクまたは恒久的な Rule / Skill / Hook 昇格判断、HO 実適用、C-4 / merge は Human-owned。`

This is precisely a suggested one-line insertion for the Human to
approve/reword at G1, **not current policy**; AI must not apply it.

## Decision / remaining unknowns

- 2026-07-12 **medium documentation approach is accepted**; not blanket
  approval of the exact plan, HO patch, log retention or authority.
- The empty log file (vs schema-only until first event) is not resolved.
  Recommend schema-only until first Human-confirmed decision, to avoid an
  unauditable / misleading empty 'active' ledger.
- Recommendation: non-canon design proposal first, Human C-3 second, only then
  canonical implementation. Any runtime automation is a distinct PBI.
