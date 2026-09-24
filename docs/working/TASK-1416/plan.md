---
task_id: TASK-1416
artifact_type: plan
schema_version: 1
status: draft
mode: critical
related_issue: https://github.com/s977043/PlanGate/issues/1416
created_by: orchestrator
---

# TASK-1416 Implementation Plan

## Goal

AIへPlanを引き渡す前に、目的・前提・依存・不確実性・検出可能性・回復境界が十分かを **AI Execution Readiness** として判断できるようにし、Plan作成・レビュー・ai-loop handoffへ既存責務を壊さず統合する。

## Context

- 関連Issue: #1416
- Upstream / adjacent:
  - #810 / #1359 — Facts / Assumptions / Unknowns / Blocking Unknowns / Readiness
  - #1335 / #1337 — Plan Design Principles + frozen paired evaluation
  - #894 / #1383 — runtime Loop Control / convergence / NO_PROGRESS
- Current critical constraint:
  - #1337 effectiveness result = `INCONCLUSIVE_NOT_RUN`
  - #1359 production implementation = `BLOCKED`
  - #1359と同じ production planning surfaces を先行変更しない

## Scope

### In Scope

- AI Execution Readinessの6 dimensionsをcanonicalに定義する。
- #810/#1359のUnknown/Assumptionを入力として再利用する。
- dependencyを declared / available / verified に分離する。
- detectabilityをREADY条件へ含める。
- recovery / escalationをPlan-level handoff contractとして定義し、runtime policyは#894/#1383へ委譲する。
- simple taskではmaterial-only projectionとし儀式化を避ける。
- C-1/C-2は既存check/rubricへの最小統合を優先する。
- Plan → ai-loop handoffで必要情報が失われないようにする。
- 4 fixtureで主要readiness状態を固定する。

### Out of Scope

- 新しいUnknown subsystem / runtime state machine / retry engine。
- schema / validator / Trust Ledger拡張の先行実装。
- Human C-3/C-4の置換。
- #1337 frozen candidateの変更。
- #1359より先に同じproduction surfaceを変更すること。
- HO pathをHuman承認なしで変更すること。

## Global Constraints

- #1337 paired evaluation結果固定までは production execution を開始しない。
- #1359 T-00 downstream impact reviewとHuman C-3を先に完了する。
- #1359の実装後、同じ概念を重複実装せず差分だけを追加する。
- runtime recovery semanticsは #894 / #1383 を正本とする。
- new C-1 check IDは、既存checkへ統合不能な根拠がない限り作らない。
- simple / low-risk taskに6項目の空sectionを強制しない。
- canonical / distributed mirrorのdriftを残さない。

## Evidence / Current State

### Known Facts

- #1416のscopeと6 dimensionsはIssueに定義済み。
- #1359はFacts / Assumptions / Unknowns / Blocking Unknowns / Readinessを統合予定。
- #1359 production implementationは#1337 pair-level result固定までBLOCKED。
- #1337 current effectiveness resultは `INCONCLUSIVE_NOT_RUN`。
- #894 / #1383はruntime retry / stop / convergenceの責務を持つ。
- 現行Plan templateにはQuestions / Unknowns、Verification Plan、Replan Triggers、Stop Conditionが既にある。

### Assumptions

- AI Execution Readinessは独立artifactではなく、既存Plan evidenceのprojectionとして実装できる。
- #1359実装後のPlan shapeに追加する差分は主に Dependencies / Detectability / Recovery-Handoff になる。
- C-1既存項目へ統合可能で、新規check IDは不要。
- runtime handoffは新しいpolicy engineなしで既存契約へ参照を渡せる。

### Known Unknowns

- #1337 evaluation結果によるPlan Design Principlesの下流判断。
- #1359 merge後の最終artifact shape。
- ai-loop handoff側で必要な最小参照形式。
- dogfood後にdeterministic validationが必要になるか。

### Blocking Unknowns

- Internal design blocker: なし。
- External execution blocker:
  - EB-01: #1337 pair-level evaluation result未固定。
  - EB-02: #1359 T-00 downstream impact review + Human C-3未完了。

## AI Execution Readiness — TASK-1416 Dogfood

### 1. Why / Outcome

- Outcome: AIへ安全に渡せるPlanと、まだ人間判断・調査・依存解消が必要なPlanを区別できる。
- Non-goals: AIの自律度最大化、Human approvalの削除、Unknownの完全排除。

### 2. Assumptions

- Verified:
  - #1359 / #1337 / #894 / #1383の現行責務境界はIssue本文で確認済み。
  - #1359 production implementationは明示的にBLOCKED。
- Unverified:
  - #1359実装後の最終surface。
  - ai-loop handoffの最小field shape。

### 3. Dependencies

| Dependency | Declared | Available | Verified | Impact |
|---|---:|---:|---:|---|
| #1337 pair-level decision | yes | no | no | production exec blocker |
| #1359 T-00 + Human C-3 | yes | no | no | overlapping surface blocker |
| #894/#1383 runtime semantics | yes | yes | yes at issue-contract level | reuse only |
| current templates/skills | yes | yes | yes | planning inventory possible |

### 4. Unknowns / Surprises

- #1337結果でPlan Design Principlesの採用判断が変わる可能性。
- #1359がDependencies/Readiness surfaceまで吸収する可能性。
- runtime handoffの正本が実装時点で更新される可能性。

### 5. Detectability

Production implementation後に最低限以下で検出する。

- simple fixture: ceremonial section増加なし。
- dependency-blocked fixture: unavailable required dependencyでREADYにならない。
- detection-missing fixture: high-impact failureにdetectorがない場合READYにならない。
- recovery-required fixture: stop/escalation boundary不足でREADYにならない。
- mirror sync / stale reference checks。
- C-1 check count不変。
- existing test suite / CI。

### 6. Recovery / Escalation

- Retry: docs/fixtureレベルのdeterministic failureのみ修正して再検証。
- Re-plan:
  - #1337結果が現Plan assumptionsを崩した場合。
  - #1359実装が想定surfaceを吸収した場合。
  - handoff contractが別のcanonical ownerを持つと判明した場合。
- Stop:
  - HO path変更が必要。
  - schema / validator / runtime state追加が必要。
  - new C-1 IDなしでは安全に表現できない。
  - #1359と責務競合する。
- Human escalation:
  - Human C-3。
  - HO patch。
  - schema/validator expansion。
  - scope変更。

### Readiness

- **Planning artifact readiness: ready**
- **Production execution readiness: blocked**
- Rationale: 設計自体にBlocking Unknownはないが、EB-01 / EB-02がhard dependency。

## Approach Comparison

| 案 | Complexity | 重複リスク | 検証 | 判定 |
|---|---|---|---|---|
| A. #1359後に既存Plan/Skill/Reviewへ差分統合 | 低〜中 | 低 | fixtures + existing checks | **採用** |
| B. #1416独立のReadiness Gate/subsystemを作る | 高 | 高 | 新runtime/schemaが必要 | 不採用 |
| C. validator-firstで強制する | 中〜高 | 中 | deterministic | defer |

### Recommended Approach

**A**。#1359がEvidence / Assumptions / Unknowns / Readinessの基礎を提供した後、#1416は不足する **Dependencies / Detectability / Recovery-Handoff** を中心に差分統合する。

これにより、同じPlan template / ai-dev-plan / C-1 surfaceを二重に変更するリスクを避ける。

## Candidate Canonical Responsibility

| Concern | Canonical owner |
|---|---|
| Why / Outcome | Plan intent / Goal |
| Assumptions | #810 / #1359 |
| Unknowns / Blocking Unknowns | #810 / #1359 |
| Dependency readiness | #1416 Plan guidance |
| Detectability | Plan Verification / verifier references |
| Retry / convergence / NO_PROGRESS | #894 / #1383 runtime |
| Recovery / escalation hints | #1416 Plan → runtime handoff |
| Human approval | existing C-3 / C-4 |

## Expected Production Files after Unblock

> 実際の変更対象はT-00でfresh inventoryして確定する。

- `docs/ai/plan-design-principles.md`
- `.agents/skills/ai-dev-plan/SKILL.md`
- `docs/working/templates/plan.md`
- `docs/working/templates/review-self.md`
- relevant fixture/evaluation files
- relevant plugin/Codex mirrors
- ai-loop handoff canonical doc **only if** T-00 confirms ownership and no HO boundary

## Work Breakdown

### Task 0: Downstream impact re-check

**Purpose**: #1337 / #1359完了後のmainで責務・surfaceを再確認する。

**Steps**:
- [ ] #1337 final resultを読む。
- [ ] #1359 merged diffを読む。
- [ ] #894/#1383 current contractを読む。
- [ ] overlap matrixを更新する。
- [ ] production execution readinessを再判定する。

**Completion Criteria**:
- [ ] EB-01 / EB-02が解消、またはPlanをre-plan済み。

### Task 1: Canonical guidance

**Purpose**: 6 dimensionsを重複なしでPlan design guidanceへ統合する。

**Completion Criteria**:
- [ ] responsibility boundaryが明示される。
- [ ] declared / available / verified dependencyを区別する。
- [ ] detectability / recovery handoffがREADY条件に入る。
- [ ] material-only ruleを維持する。

### Task 2: Planning Skill / template projection

**Purpose**: ai-dev-planがrepository-firstにreadinessを評価し、materialな結果だけartifactへ投影する。

**Completion Criteria**:
- [ ] fixed six-question Human questionnaireになっていない。
- [ ] simple taskは不要sectionを出さない。
- [ ] blocked条件が明確。

### Task 3: Review integration

**Purpose**: 既存C-1/C-2へ最小統合する。

**Completion Criteria**:
- [ ] new check IDなしを優先。
- [ ] #1359 review responsibilityと重複しない。
- [ ] Human approval boundary不変。

### Task 4: Handoff integration

**Purpose**: expected outcome / verifier refs / known blockers / stop-escalation hintsをruntimeへ失わず渡す。

**Completion Criteria**:
- [ ] runtime policyをPlan側へコピーしない。
- [ ] #894/#1383を参照する。
- [ ] handoff ownerが明確。

### Task 5: Fixed fixtures + validation

**Purpose**: readinessのpositive/negative behaviorを固定する。

**Fixtures**:
1. simple-ready
2. dependency-blocked
3. detection-missing
4. recovery-required

**Completion Criteria**:
- [ ] 4 fixtures期待判定一致。
- [ ] existing test suite / sync checks PASS。
- [ ] C-1 count driftなし。

## Verification Plan

| 種別 | 確認方法 | 期待結果 |
|---|---|---|
| Responsibility | owner matrix review | duplicate ownerなし |
| Simple | simple-ready fixture | ready / ceremony増加なし |
| Dependency | dependency-blocked fixture | blocked |
| Detectability | detection-missing fixture | blocked |
| Recovery | recovery-required fixture | blocked or needs_clarification per explicit rule |
| Review | C-1/C-2 mapping check | unnecessary new rubricなし |
| Runtime boundary | #894/#1383 trace | runtime semantics copiedなし |
| Distribution | sync/stale scan | canonical/mirror driftなし |
| Regression | repo CI/tests | PASS |

## Replan Triggers

- #1337 final result changes the applicable Plan Design Principles baseline.
- #1359 merges a conflicting or broader readiness model.
- ai-loop handoff owner differs from current assumption.
- new schema / validator / C-1 ID becomes necessary.
- simple fixture cannot stay minimal without weakening safety.
- required HO path change is discovered.

## Stop Condition

- #1337 pair-level result未固定。
- #1359 T-00 + Human C-3未完了。
- overlapping production changes would bypass #1359 ordering.
- HO path / irreversible workflow contract change is required without Human approval.
- runtime semantics would be duplicated from #894/#1383.

## Human Approval Boundary

- Production exec開始: Human C-3
- HO patch: Human-owned
- schema / validator expansion: separate Human decision
- merge: Human C-4

## C-1 Self Review Checklist

- [x] Goal / outcomeとwork breakdownが接続している
- [x] Assumptions / dependencies / unknownsを分離した
- [x] required dependency availabilityを実測状態で区別した
- [x] failure detectabilityをfixtureへ接続した
- [x] recovery / escalationをruntime ownerと分離した
- [x] Replan / Stop conditionを明示した
- [x] #1337 / #1359 blockerを無視していない
- [x] simple task ceremonyをnon-goal化した
