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
  - structural-debt deferral (#867 Case 3; AC-16)
  - pre-PR diff for `diff-audit` re-check (stop / proceed-with-residual-risk; AC-09 / AC-15)

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
- Human Decision Surface / Plan compression / projection optimization owned by #1347.
- Changing the #1337 evaluation candidate or contaminating its before/after comparison.

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
- AC-15: Pre-PR review distinguishes the two outcomes: a remaining or newly discovered Blocking Unknown **stops** PR creation, while a non-blocking Unknown may **proceed** only when it is recorded as residual risk with its assumption, evidence and verification method (#810 AC 「PR作成を止める条件と、残存リスクを記録して進められる条件が区別される」).
- AC-16: When the structural response required by a Knowledge Delta does not fit the current task (large structural debt, #867 Case 3), the Plan records it as Deferred structural work / a separate Issue or Epic candidate with scope, risk and missing tests, and does not execute it inside the current task.

## Upstream Issue AC Disposition

TASK-1359 integrates #867 and #810; every upstream AC is either handled here, delegated to an existing owner, or explicitly out of scope.

### #867 Knowledge Delta

| #867 AC | Disposition | Where |
|---|---|---|
| 現行 Plan・レビュー・ゲート構造との重複を調査した | 本 TASK で扱う（計画段階で実施済み） | Evidence E-04〜E-06 / plan `Prior Artifact Impact` / `docs/working/TASK-0867/pbi-input.md` |
| Knowledge Delta の記録条件と省略条件 | 本 TASK で扱う | AC-06 / TC-06, TC-07 |
| 振る舞い変更と構造変更を分離するタスク分割ルール | 本 TASK で扱う | AC-07 / TC-07, TC-08 |
| Characterization Test / Preparatory Refactoring の利用条件 | 本 TASK で扱う | AC-08 / TC-08 |
| 投機的抽象化と不要な変更範囲を検出するレビュー項目 | 他 issue へ委譲（新規実装しない） | #794 / `.agents/skills/review-gate`（CLOSED・既存）。Out of scope「Reimplementing #794」 |
| 構造変更前後の振る舞い維持を確認するゲート（外部 API・永続化・CLI の互換性） | 既存機構へ委譲（新規ゲートは追加しない）。本 TASK は Plan からの参照だけを扱う | 既存 `docs/working/templates/evidence-tdd-ledger.json` の `refactor_verify` と review-gate / River Review の diff レビュー。Plan 側は Safety Net → … → Verification の順序で Verification step が既存 `refactor_verify` 証跡を参照することだけを TC-08 で確認する |
| Trust Ledger への記録方法が既存スキーマと整合 | 本 TASK で扱う（新フィールドを追加しない形で） | AC-12 / TC-10。Knowledge Delta の変更理由・検証結果は既存 `decision-log.jsonl` / handoff（妥協点・V2 候補）/ `refactor_verify` へ記録する。TASK-0867 が計画していた Trust Ledger 4 系列の対応表は本 TASK では作らず、既存記録で不足が実測された時点で別 issue とする |
| 単純機能変更・既存コード変更・大規模負債の 3 ケースの fixture | 本 TASK で扱う | Case 1 = simple fixture（TC-06）/ Case 2 = knowledge-delta fixture（TC-07, TC-08）/ Case 3 = structural-debt fixture（AC-16 / TC-15） |
| 「コード美化ではなく知識差分の同期」の説明 | 本 TASK で扱う | plan Task 6（todo T-07）。TC-07 の検証時に正本の説明文を確認する |
| 既存フローを不必要に重くしない適用・スキップ条件 | 本 TASK で扱う | AC-06 / AC-10 / TC-06 |

### #810 Unknown Discovery

| #810 AC | Disposition | Where |
|---|---|---|
| Known Facts / Assumptions / Unknowns の区別 | 本 TASK で扱う | AC-03 / TC-03 |
| コードベースから解決可能な質問を人間へ聞く前に調査 | 本 TASK で扱う | AC-04 / TC-04 |
| Blocking Unknown が残る場合 readiness が `ready` にならない | 本 TASK で扱う | AC-05 / TC-05 |
| Plan Review で未検証の仮定と残存 Unknown を確認 | 本 TASK で扱う | C-1 landing `C1-PLAN-02`（plan `C-1 Landing Map`）/ AC-11 |
| PR 作成前セルフレビューで Plan 時点の Assumption / Unknown を再検査 | 本 TASK で扱う | AC-09 / TC-09 |
| PR 作成を止める条件と、残存リスクを記録して進められる条件の区別 | 本 TASK で扱う | AC-15 / TC-09（進める側）, TC-14（止める側） |
| 通常の低リスク変更で出力と質問が過剰に増えない | 本 TASK で扱う | AC-10 / TC-06 |
| 既存のブレインストーミング / Plan Review / C-1 との責務重複の整理 | 本 TASK で扱う | plan `Source-of-Truth Hierarchy` / `C-1 Landing Map` / AC-11 |
| ドキュメントまたは実例で Unknown-aware な Plan 作成とセルフレビューを確認 | 本 TASK で扱う | AC-14 / fixtures（TC-05, TC-09, TC-14） |

## Evidence

- E-01: #933 documents a real failure where a correct prior artifact existed but was not reread.
- E-02: #810 defines Known Facts / Assumptions / Unknowns and a `Blocking Unknown -> not ready` requirement.
- E-03: #867 defines Knowledge Delta and behavior-vs-structural change separation.
- E-04: #1335 already provides Evidence Before Design and Minimum Sufficient Design, so a second design-principle framework is unnecessary.
- E-05: Current `docs/working/templates/plan.md` already has Questions/Unknowns, Approach Comparison, Change Type, Work Breakdown, Replan and Stop conditions.
- E-06: Current `ai-dev-plan` already requires repository evidence and change-type-aware verification.
- E-07: #1358 adds Minimum Sufficient Test Set and was merged before TASK-1359 implementation. TASK-1359 was rebased onto main and TC-12 confirmed `C1-TEST-14` ownership preservation.
- E-08: #960 still has HO-side C-1 execution drift; this task must not couple non-HO implementation to that unresolved HO patch.
- E-09: #1337 explicitly fixes the Plan Design Principles evaluation candidate SHA and orders #933/#810/#867 implementation **after paired evaluation results are fixed**.
- E-10: #1347 hard-depends on #1337 and explicitly prohibits changing `ai-dev-plan` / Plan Design Principles before #1337 completes; Human Decision Surface / Plan compression is owned there, not by TASK-1359.

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
- AC count = 16 -> quantitative critical threshold (11+).
- touches multiple planning/review/distribution layers.

**Dependency**:
- #1358 merge/rebase dependency: **RESOLVED** — branch rebased to main `7b523a4530d0c2b324ecd9464736d0c7776a2bdc`; TC-12 PASS.
- #1337 paired evaluation result: **BLOCKING** — do not begin production changes to `ai-dev-plan` / Plan workflow surfaces until the result is fixed.
- #1347 Plan Decision Surface: downstream/parallel concern; TASK-1359 must not preempt its Human-facing projection experiment.
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


## Evaluation-order dependency — 2026-09-23

Fresh dependency review after rebasing to latest main found a stronger upstream constraint:

- #1337 freezes baseline/candidate and places **#933 + #810 + #867 implementation after paired evaluation**.
- #1347 explicitly says **do not change `ai-dev-plan` Skill / Plan Design Principles before #1337 completes**.

Therefore:
- TASK-1359 planning/review artifacts may continue.
- Human C-3 and production implementation are **blocked until #1337 result is fixed**.
- TASK-1359 must not add Human Decision Surface / compression changes; #1347 owns that experiment.
