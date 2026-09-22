# PDP-EVAL-v1 Materialized Input Manifest

- Source: `docs/working/discussions/2026-09-20-plan-design-principles-eval-inputs.md`
- Source Git blob: `1a6176ff18c19f7cf1141c38aab9a23e1968ce0b`
- Materialization contract: fixed wrapper from the source document
- Verification: **PASS — all 8 derived PBI semantic fields match source**
- Generated for: #1337

## Frozen inputs

| Case | Path | Git blob |
| --- | --- | --- |
| PDP-01 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-01/pbi-input.md` | `e5f9f46397ca85ea82c0f72f19c3ad81fe4e722f` |
| PDP-02 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-02/pbi-input.md` | `f6cfd3a3bf4c23729a6bd407c3a7c1281058b253` |
| PDP-03 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-03/pbi-input.md` | `aec24092eec9ab9bc8b4dd692e4941bf0b88489f` |
| PDP-04 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-04/pbi-input.md` | `6ea5585de848fb11e5848d2a669ad8538c952363` |
| PDP-05 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-05/pbi-input.md` | `38b267c1930e36d5700e3aed437c0a59ed909282` |
| PDP-06 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-06/pbi-input.md` | `f8d538e7e2530e0bbebc0d4ffc5a8d96880f98fc` |
| PDP-07 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-07/pbi-input.md` | `b34035d35f2b5b15a4466889a70a290f1fc41208` |
| PDP-08 | `docs/working/eval-inputs/PDP-EVAL-v1/PDP-08/pbi-input.md` | `8a72f5d3694853487db2f8a031679932296cd5aa` |

## Semantic equality check

Each derived file was compared field-by-field against the frozen source:

- Context / Why
- In scope
- Out of scope
- Acceptance Criteria
- Evidence
- Unknowns
- Assumptions

All 8 cases: **PASS**.

The wrapper adds only:

- fixed frontmatter
- fixed PlanGate PBI headings
- `Risks: 未評価 — Planで判断`

No fixture meaning is added or removed.

## Operator rule

Do not reconstruct a PBI from the source during a run.

Instead:

1. copy the frozen derived file for the case;
2. place the exact bytes at `docs/working/TASK-EVAL-PDPXX/pbi-input.md` in each detached variant worktree;
3. compute SHA256 after copy;
4. baseline/candidate hashes for the pair must match.

A mismatch is `INCONCLUSIVE_INPUT_MISMATCH`.

## Review note

The first equality-check implementation incorrectly compared heading ranges
(`Context` through `### In scope`, and AC through `### Evidence`) and reported false mismatches.
The checker boundary was corrected to the actual wrapper headings
(`## What — Scope`, `## Notes from Refinement`), after which all semantic fields matched.
No derived PBI content change was required.
