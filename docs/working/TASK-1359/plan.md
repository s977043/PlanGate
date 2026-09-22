---
task_id: TASK-1359
artifact_type: plan
schema_version: 1
status: draft
mode: critical
related_issue: https://github.com/s977043/PlanGate/issues/1359
created_by: orchestrator
---

# TASK-1359 Implementation Plan

## Goal

Integrate Prior Artifact Discovery, Unknown Discovery and Knowledge Delta into one evidence-first Plan-generation contract without creating a new review framework or unnecessary gates.

## Context

- Related issues: #1359 / #933 / #810 / #867
- Related architecture: #1335 / PR #1336
- Dependency: PR #1358 merged; TASK-1359 rebased and compatibility evidence recorded.
- **Hard dependency**: #1337 paired evaluation result must be fixed before Human C-3 / production implementation. This preserves the frozen evaluation candidate and avoids contaminating #1337.
- #1347 owns Human Decision Surface / Plan compression experiments after #1337; TASK-1359 must not absorb that scope.
- Parallel governance dependency: #960 HO-side C-1 drift remains separate.
- Related artifacts:
  - `pbi-input.md`
  - `test-cases.md`

## Scope

### In Scope

- Planning guidance and Plan template representation.
- Existing C-1 check strengthening only where needed.
- Existing pre-PR review/diff-audit integration.
- Four fixed evaluation fixtures.
- Distribution sync through existing paths.

### Out of Scope

- New Unknown service/subsystem.
- Human Decision Surface / Plan compression / Human Attention projection changes owned by #1347.
- Any change that alters or contaminates #1337 baseline/candidate evaluation inputs or candidate SHA.
- New Trust Ledger schema fields.
- New C-1 IDs.
- HO file edits.
- New generic validator unless a fixture proves guidance-only is insufficient.
- River Review implementation-review duplication.

## Global Constraints

- Rebase after #1358 before implementation.
- Do not edit HO paths; if an HO dependency is discovered, stop and split a Human-owned patch.
- Keep C-1 total unchanged.
- Do not duplicate #794, #934, #203, #894, or #1358 responsibilities.
- Low-risk tasks must not be forced to emit empty Knowledge Delta / Unknown sections.
- Any new persistent field must have measured current-model insufficiency.
- Existing plugin/Codex sync routes are reused; generated/mirrored content is not hand-invented independently.

## Prior Artifact Impact

| Artifact | Evidence / decision reused | Impact on this Plan |
|---|---|---|
| `docs/working/TASK-0810/pbi-input.md` | Unknown Discovery scope and readiness semantics | Reuse Facts/Assumptions/Unknowns vocabulary; do not create a separate Unknown subsystem |
| `docs/working/TASK-0867/pbi-input.md` | Knowledge Delta trigger/skip, separation pattern, Trust Ledger narrowing | Reuse conditional Knowledge Delta; no new Trust Ledger schema |
| #1335 / PR #1336 | Evidence Before Design / Minimum Sufficient Design / Design for Verification | Make them the upstream source of truth |
| #1358 | Minimum Sufficient Test Set | Avoid generating redundant fixtures/tests; rebase before implementation |
| #960 | C-1 source-of-truth drift | Do not add a new C-1 item or couple this task to HO count changes |

## Facts / Assumptions / Unknowns

### Known Facts

- Current Plan template already has `Questions / Unknowns`, Approach Comparison, Change Type, Work Breakdown, Replan and Stop sections.
- Current Plan Design Principles already require repository evidence before design.
- #810 and #867 already have reviewed PBI artifacts.
- #933 has no formal PBI artifact.
- `.agents/skills/diff-audit/SKILL.md` is the generic commit/PR-before self-inspection surface and successor of old self-review.
- `.agents/skills/review-gate/SKILL.md` explicitly separates itself from pre-PR `diff-audit` and remains the implementation-completion independent gate.
- ai-loop's `execution-runbook.md` composes `diff-audit` into a stronger ai-loop-only pre-PR flow; it is not the generic source of truth.
- Workflow definition changes are classified as critical.
- Current C-1 count is 25 and must not be expanded by this task.

### Assumptions

- Existing Plan artifact can absorb the new information with a small number of conditional sections rather than a new artifact type.
- Existing pre-PR review path can host Unknown/Assumption re-check without a new gate.
- Existing decision/evidence records are sufficient for Knowledge Delta rationale unless fixtures prove otherwise.

### Known Unknowns

- Whether deterministic readiness validation is needed after guidance is implemented.

### Resolved Unknowns

- RU-01: generic pre-PR self-review surface = `.agents/skills/diff-audit/SKILL.md`.
- RU-02: `Prior Artifact Impact` = conditional dedicated Plan section; omit entirely when no material prior artifact exists.
- RU-03: #1358 dependency = merged/rebased; TC-12 confirms `C1-TEST-14` preservation and shared review/planning surfaces remain unchanged on TASK-1359 branch.

### Blocking Unknowns

- なし

### External Blockers

- **EB-01: #1337 paired evaluation result not fixed**
  - blocking: yes for Human C-3 and exec
  - reason: #1337 explicitly orders #933/#810/#867 implementation after paired evaluation and freezes the candidate SHA.
  - unblock condition: #1337 records a fixed pair-level evaluation result / next-action decision that allows downstream implementation.

### Human Decisions Required

- C-3 approval for critical-mode exec.
- Any HO patch split.
- Any schema/validator expansion beyond Phase 1.

### Readiness

**blocked**

Reason: internal Blocking Unknowns = 0 and #1358 compatibility is resolved, but external blocker EB-01 (#1337 result not fixed) prevents Human C-3 / production implementation.

## Source-of-Truth Hierarchy

TASK-1359 は正本を増やさず、既存の責務階層へ配置する。

| Layer | Source | TASK-1359での扱い |
|---|---|---|
| Core artifact / state / gate contract | `.claude/rules/working-context.md` | **HO・変更しない**。3ファイル同時生成、C-1/C-2/C-3、artifact lifecycleの基礎契約を維持 |
| B-1 → B-2 → B-3 workflow definition | `docs/ai-driven-development.md` → bundled `references/ai-driven-development.md` | conditional Prior Artifact / Unknown / Knowledge Delta planning flowを追加 |
| Executable planning guidance | `.agents/skills/ai-dev-plan/SKILL.md` | repository-first discovery、readiness、safe structural-response orderingを実行規範化 |
| Plan artifact shape | `docs/working/templates/plan.md` | materialな判断だけをconditional sectionとして表現 |
| C-1 conformance | `docs/working/templates/review-self.md` | 既存check IDへ分散統合。新IDは作らない |
| Pre-PR maker audit | `.agents/skills/diff-audit/SKILL.md` | implementation後のUnknown/Assumption/Knowledge Delta再検査 |
| Independent implementation review | `.agents/skills/review-gate/SKILL.md` | 責務不変。maker-side pre-PR auditを取り込まない |

> `working-context.md` の必須artifact基礎契約は変えない。TASK-1359の新規情報は **conditional guidance / conditional artifact representation** として導入し、全task必須の新contractへ昇格しない。

## C-1 Landing Map

#1358 が `C1-TEST-14` を Minimum Sufficient Test Set の着地点として使うため、TASK-1359はそこへ追記しない。C-1責務は次へ固定する。

| TASK-1359 concern | Existing C-1 check | 追加するconformance |
|---|---|---|
| repository-first / same-TASK prior artifact discovery | `C1-B1B2-16` | 人間へ質問する前にrepository / same-TASK artifactsで解消可能な事項を調査したか |
| Facts / Assumptions / Known Unknowns / Blocking Unknowns / Readiness | `C1-PLAN-02` | 未検証前提とUnknownが分類され、Blocking Unknownが残る場合ready扱いされていないか |
| Knowledge Delta trigger / skip / deferred structural work | `C1-PLAN-03` | trigger非該当taskを儀式化せず、scope外のstructural workをDeferred/別Issueへ分離したか |
| Safety Net → Preparatory Refactor → Behavior Change → Verification ordering | `C1-PLAN-06` | Knowledge Delta / refactor発火時の依存順が安全側に並んでいるか |
| Test Case minimality | `C1-TEST-14` | **#1358の責務。TASK-1359では変更しない** |
| implementation後の再確認 | C-1ではなく `diff-audit` | Assumption / Unknown / Knowledge Delta / scope expansionをPR前に再検査 |


## Knowledge Delta

This task itself has a Knowledge Delta.

- Newly learned:
  - #933, #810 and #867 are not three independent gates; they form one evidence/uncertainty/knowledge continuity flow.
  - #1335 moved design guidance upstream, reducing the need for checklist expansion.
- Existing representation:
  - Prior artifacts, Unknowns and refactor knowledge are represented in separate issues/PBIs.
  - Current Plan has a generic Questions/Unknowns section but no explicit readiness model.
- Delta:
  - Planning lacks a single flow from evidence -> uncertainty -> knowledge change -> design response -> pre-PR re-check.
- Required structural response:
  - Extend existing Plan guidance/template conditionally.
  - Reuse existing C-1 and pre-PR review surfaces.
- Deferred structural work:
  - Dedicated validator or schema only if operation proves guidance insufficient.

## Approach Comparison

| 案 | Evidence | Complexity Cost | New Abstractions | Current-Need Trace | Verification | Trade-offs | 判定 |
|---|---|---|---|---|---|---|---|
| A: Existing Plan/Skill extension | #1335 and current template already contain adjacent concepts | Low-Medium | none | AC-01..14 | 4 fixtures + sync/CI | Smallest change; relies on guidance discipline | **Adopt** |
| B: New Unknown/Knowledge Gate subsystem | #810 originally considered a shared component | High | new gate/state/schema | weak; no measured need | would require new runtime tests | Strong enforcement but duplicates current flow and increases ceremony | Reject |
| C: Validator-first | #933 proposed validate gate | Medium-High | deterministic validation rules | only some ACs machine-checkable | validator fixtures | Can catch missing fields but risks making artifact shape the source of truth | Defer |

### Recommended Approach

Adopt **A**. Add the minimum conditional representation to existing Plan generation and reviews. Only add deterministic validation if a fixed fixture demonstrates that guidance alone cannot reliably preserve a safety invariant.

#### Why this is the minimum sufficient design

- Required AC / constraints: AC-01..14, critical mode, no HO changes, no new C-1 IDs.
- New abstractions / interfaces / dependencies: none in Phase 1.
- Why each is needed now: no new abstraction is needed.
- Simpler alternative considered: document-only guidance without template changes; rejected because #933 is specifically a retrieval-to-artifact continuity failure.
- Observable behavior:
  - material prior artifacts appear in Plan trace;
  - Blocking Unknown prevents ready;
  - Knowledge Delta appears only when triggered;
  - refactor ordering is explicit when triggered;
  - pre-PR re-check reports new/resolved Unknowns.
- Verification strategy: four fixed fixtures + canonical/mirror sync + CI.
- Conditional guidance fired: Compatibility/Failure only in fixtures where relevant; Knowledge Delta is itself conditional.
- Deferred extensions: validator/schema/new gate.

## Change Type / Verification Strategy

- Change type: mixed (workflow docs/templates/skills + fixture validation)
- Pre-change evidence:
  - current template/skill behavior and fixed negative fixtures.
- Post-change evidence:
  - fixed fixtures show required/omitted sections as expected;
  - sync checks green;
  - no C-1 count change.
- Test trace: `test-cases.md` TC-01..TC-13.

## Files / Interfaces

| File | Operation | Purpose | Boundary |
|---|---|---|---|
| `docs/working/templates/plan.md` | modify | conditional prior-artifact / readiness / Knowledge Delta representation | task-context protected |
| `docs/ai-driven-development.md` | modify | canonical Prompt 1 guidance alignment | canonical doc |
| `.agents/skills/ai-dev-plan/SKILL.md` | modify | execution guidance | canonical skill |
| `docs/working/templates/review-self.md` | modify | strengthen C1-B1B2-16 / C1-PLAN-02 / C1-PLAN-03 / C1-PLAN-06 only | C-1 count unchanged; C1-TEST-14 untouched |
| `.agents/skills/diff-audit/SKILL.md` | modify | pre-PR re-check of Unknown/Assumption/Knowledge Delta | canonical generic pre-PR self-review |
| `examples/eval-fixtures/*` or equivalent | create | four fixed scenarios | no fake completion artifacts |
| plugin/Codex mirrors | sync | distribution | generated through existing route |

## Work Breakdown

> 実行粒度の正本は `todo.md`。本節も reviewer が変更理由ごとに approve/reject できる単位へ合わせる。

### Task 0: Preserve #1337 evaluation order

**Purpose**: prevent TASK-1359 from contaminating the frozen Plan Design Principles evaluation.

**Steps**:
- [ ] Wait until #1337 paired evaluation result is fixed.
- [ ] Read the final #1337 decision and determine whether TASK-1359 Plan requires replan.
- [ ] Reconfirm #1347 still owns Human Decision Surface / compression concerns.

**Completion Criteria**:
- EB-01 resolved.
- #1337 result and downstream decision are referenced in decision-log.
- No TASK-1359 production change occurred before resolution.

**Rollback**:
- N/A (dependency gate only)

### Task 1: Rebase / review boundary reconfirmation

**Purpose**: #1358を取り込んだmain上で共有surfaceとreview責務境界を確定する。

**Files**:
- Read: `.agents/skills/ai-dev-plan/SKILL.md`
- Read: `.agents/skills/diff-audit/SKILL.md`
- Read: `.agents/skills/review-gate/SKILL.md`

**Steps**:
- [ ] #1358 merge後にrebaseする
- [ ] `diff-audit` = generic pre-PR self-inspection を再確認
- [ ] `review-gate` = independent implementation-completion review を再確認
- [ ] #960 HO境界を再確認

**Completion Criteria**:
- BU-01解消
- shared file conflict 0、またはPlanをreplan済み

**Rollback**:
- rebase前branch SHAへ戻す

### Task 2: Plan template — evidence / uncertainty continuity

**Purpose**: prior artifact / Facts / Assumptions / Unknowns / ReadinessをPlan artifactへ最小表現する。

**Files**:
- Modify: `docs/working/templates/plan.md`

**Steps**:
- [ ] conditional `Prior Artifact Impact` を追加
- [ ] Known Facts / Assumptions / Known Unknowns / Blocking Unknowns / Human Decisions / Readinessを追加
- [ ] material prior artifact無し・low-risk時の省略規則を明記

**Completion Criteria**:
- TC-01 / TC-02 / TC-03 / TC-05 / TC-06 を表現可能
- 空sectionの強制なし

**Rollback**:
- Task 2 commitをrevert

### Task 3: Prompt 1 canonical guidance — evidence / uncertainty

**Purpose**: templateだけでなくPlan生成の正本へrepository-firstとreadiness semanticsを反映する。

**Files**:
- Modify: `docs/ai-driven-development.md`

**Steps**:
- [ ] same-TASK inventoryをrepository scanに含める
- [ ] repository-resolvable-firstを明記
- [ ] Blocking Unknownがある場合はreadyにしない
- [ ] template語彙と1:1対応させる

**Completion Criteria**:
- TC-03 / TC-04 / TC-05の生成規範が正本に存在

**Rollback**:
- Task 3 commitをrevert

### Task 4: ai-dev-plan — evidence / uncertainty execution guidance

**Purpose**: 配布可能なSkillへPrior Artifact Discovery / Unknown classificationを落とす。

**Files**:
- Modify: `.agents/skills/ai-dev-plan/SKILL.md`

**Steps**:
- [ ] B-1前のsame-TASK artifact inventoryを追加
- [ ] material selection ruleを追加
- [ ] repository-resolvable-firstを追加
- [ ] Blocking Unknown / Readinessを追加

**Completion Criteria**:
- generic Unknown subsystemを新設していない
- TC-01..05をSkillだけでも実行可能

**Rollback**:
- Task 4 commitをrevert

### Task 5: Plan template — conditional Knowledge Delta

**Purpose**: 現在の理解が構造表現とずれた場合だけ構造応答をPlanする。

**Files**:
- Modify: `docs/working/templates/plan.md`

**Steps**:
- [ ] trigger / skip条件を追加
- [ ] Newly learned / Existing representation / Delta / Required structural response / Deferred structural workを追加
- [ ] Safety Net → Preparatory Refactor → Behavior Change → Post-change Refactor → Verificationの順序規則を接続

**Completion Criteria**:
- TC-06ではsection省略
- TC-07/08では必要情報が出る

**Rollback**:
- Task 5 commitをrevert

### Task 6: Prompt 1 canonical guidance — Knowledge Delta

**Purpose**: Knowledge Deltaをコード美化でなく知識差分同期として正本化する。

**Files**:
- Modify: `docs/ai-driven-development.md`

**Steps**:
- [ ] trigger / skip / behavior-vs-structure separationを追加
- [ ] Characterization / Preparatory Refactoring条件を追加
- [ ] #794 / existing refactor evidenceは参照し再実装しない
- [ ] Trust Ledger schemaは変更しない

**Completion Criteria**:
- AC-06..08 / AC-12を正本で説明可能

**Rollback**:
- Task 6 commitをrevert

### Task 7: ai-dev-plan — Knowledge Delta execution guidance

**Purpose**: Skillへsafe refactor orderingを実行規範として反映する。

**Files**:
- Modify: `.agents/skills/ai-dev-plan/SKILL.md`

**Steps**:
- [ ] trigger時だけKnowledge Deltaをmaterialize
- [ ] RED baselineからstructural changeを進めない
- [ ] deferred structural workをscope外へ分離

**Completion Criteria**:
- TC-07/08をSkillから導出可能

**Rollback**:
- Task 7 commitをrevert

### Task 8: Existing C-1 conformance

**Purpose**: 新しいgate/check IDを作らずupstream guidanceへの適合を確認する。

**Files**:
- Modify: `docs/working/templates/review-self.md`

**Steps**:
- [ ] `C1-B1B2-16` へ repository-first / same-TASK prior artifact discovery を追加
- [ ] `C1-PLAN-02` へ Facts / Assumptions / Blocking Unknown / Readiness conformance を追加
- [ ] `C1-PLAN-03` へ Knowledge Delta trigger/skip + deferred structural work のscope disciplineを追加
- [ ] `C1-PLAN-06` へ Safety Net → Preparatory Refactor → Behavior Change → Verification のdependency orderingを追加
- [ ] `C1-TEST-14` は #1358 の責務として変更しない
- [ ] `### C1-` heading countがbaselineと同じことを確認

**Completion Criteria**:
- new C-1 check ID = 0
- heading count unchanged

**Rollback**:
- Task 8 commitをrevert

### Task 9: diff-audit pre-PR re-check

**Purpose**: Plan時点の仮定・Unknown・Knowledge Deltaを実装後差分に対して再検査する。

**Files**:
- Modify: `.agents/skills/diff-audit/SKILL.md`

**Steps**:
- [ ] Plan-time Assumptionの解消/残存を確認
- [ ] newly discovered Unknownを確認
- [ ] Blocking Unknownが残ればPR readyにしない
- [ ] Knowledge Delta / scope expansionをPlanとdiffで照合
- [ ] review-gateの独立review責務は取り込まない

**Completion Criteria**:
- TC-09を満たす
- diff-audit / review-gate責務分界を維持

**Rollback**:
- Task 9 commitをrevert

### Task 10: Distribution sync

**Purpose**: canonical skills/templatesの変更を既存配布経路へ反映する。

**Files**:
- Modify/generated: plugin/Codex mirrors

**Steps**:
- [ ] existing sync routeを実行
- [ ] canonical/mirror blob差分を確認
- [ ] 手編集でしか揃わない場合は停止

**Completion Criteria**:
- sync drift 0
- stale reference 0

**Rollback**:
- sync commitをrevert

### Task 11: Fixed fixtures

**Purpose**: guidanceが存在するだけでなく、conditional behaviorを固定ケースで検証する。

**Files**:
- Create/modify: `examples/eval-fixtures/**`

**Steps**:
- [ ] simple case
- [ ] prior-artifact case
- [ ] blocking-unknown case
- [ ] knowledge-delta/refactor case
- [ ] positive/negative controlsを明示

**Completion Criteria**:
- TC-01..10の意味論を4fixtureでカバー
- TC-12で#1358 dependency compatibilityを独立検証
- redundant test fixtureを増やさない

**Rollback**:
- fixture commitをrevert

### Task 12: Repository verification / completion record

**Purpose**: distribution・C-1不変・repo testをfresh evidenceで確認する。

**Steps**:
- [ ] `grep -c '^### C1-' docs/working/templates/review-self.md`
  - expected: baselineと同値
- [ ] #1358 merge後baselineの `C1-TEST-14` blockを保存し、TASK-1359差分後もbyte-equivalentであることを確認
  - expected: no diff
- [ ] `python3 scripts/check-stale-skill-refs.py`
  - expected: exit 0
- [ ] `sh scripts/sync-plugin-plangate.sh --dry-run`
  - expected: no changes
- [ ] `sh tests/run-tests.sh`
  - expected: 0 failed
- [ ] PR CI / CodeQL / sync checksを確認

**Completion Criteria**:
- TC-11 PASS
- critical/major finding 0
- TASK review/current-stateを更新

**Rollback**:
- 検証のみ。変更が必要なら該当Taskへ戻る

## Verification Plan

| Type | Method | Expected |
|---|---|---|
| Fixture | four scenario outputs | each scenario matches its required conditional behavior |
| C-1 count | count `### C1-` headings | unchanged from baseline |
| Sync | existing plugin sync CI | success |
| Stale refs | existing stale-ref checker | success |
| Markdown/CI | repository CI | success |
| Dependency compatibility | preserve #1358-owned `C1-TEST-14` | no diff after TASK-1359 C-1 changes |
| Evaluation integrity | changed paths before T-00 | only `docs/working/TASK-1359/**` |
| Review | independent plan/diff review | no unresolved critical/major |

## Review Lane Plan

- Lane 1: architecture/responsibility — check source-of-truth and no duplicate gate.
- Lane 2: workflow/governance — check task-context, C-1 count, HO boundary.
- Lane 3: test/evaluation — check fixtures distinguish required vs skipped behavior.
- Lane 4: adversarial simplicity — look for schema/gate/framework expansion without evidence.

## Plan Review Readiness

### Success Criteria

- #1337 evaluation order preserved; no candidate contamination.
- AC-01..14 mapped to TC-01..TC-11.
- Dependency contract `COMP-1358-01` mapped to TC-12.
- Evaluation-integrity contract `COMP-1337-01` mapped to TC-13.
- Completion boundary: non-HO planning/review integration + fixtures; any HO patch is separate.

### Review Criteria

- Design alignment: #1335 upstream-guidance architecture.
- Minimum sufficient design: no new gate/schema/C-1 ID unless evidence requires it.
- Test expectations: conditional fixtures include positive and negative controls.
- Security: N/A unless discovered pre-PR surface touches HO.
- Maintainability: one vocabulary across Prior Artifact / Unknown / Knowledge Delta.
- Backward compatibility: low-risk Plans remain compact.
- Operational risk: workflow definition change requires critical-mode C-3.

### Required Context

- #1359 / #933 / #810 / #867
- #1335 / #1358 / #960
- `docs/working/TASK-0810/pbi-input.md`
- `docs/working/TASK-0867/pbi-input.md`
- current Plan template / ai-dev-plan / review surfaces

## Replan Triggers

Replan if:
- #1337 result identifies a regression, no-effect, or guidance change that invalidates TASK-1359 assumptions.
- #1347 changes the Human-facing Plan projection boundary in a way that overlaps TASK-1359 artifact representation.
- post-#1358 baselineから `ai-dev-plan` / C-1 ownership が変化し、Minimum Sufficient Test SetとTASK-1359 guidanceが責務混在する。
- `diff-audit` cannot express the re-check without a new artifact or responsibility conflict.
- existing decision/evidence records cannot represent Knowledge Delta in fixture 4.
- a required change enters an HO path.
- C-1 count would need to change、または #1358 所有の `C1-TEST-14` をTASK-1359側で変更する必要が生じる。
- deterministic enforcement is shown necessary by a failing fixture.

## Stop Condition

Stop for human decision if:
- HO path change is required.
- schema or `bin/plangate` change becomes necessary.
- a new gate/framework is proposed.
- any Blocking Unknown remains before exec.
- rollback or compatibility risk becomes materially higher than this Plan describes.

## Human Approval Boundary

#1337 result fixed is a prerequisite to Human C-3.
Critical-mode C-3 is mandatory before implementation.
Merge remains C-4 Human-owned.
