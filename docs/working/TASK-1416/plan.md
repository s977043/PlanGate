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

Execution Readinessは新しい6個の正本ではなく、**既存Plan情報から導出するprojection** とする。

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
- Current PR #1417 is therefore a **planning-baseline PR only**.

## Scope

### In Scope

- AI Execution Readinessの6 dimensionsのresponsibility mapを定義する。
- #810/#1359のUnknown/Assumptionを入力として再利用する。
- dependencyを declared / available / verified に分離する。
- detectabilityをREADY条件へ含める。
- recovery / escalationを既存のReplan Triggers / Stop Condition / Human Approval / runtime owner参照からprojectionする。
- readiness stateを `ready / needs_clarification / blocked` の一意ルールで判定する。
- simple taskではmaterial-only projectionとし儀式化を避ける。
- C-1/C-2は既存check/rubricへの最小統合を優先する。
- Plan → ai-loop handoffで必要情報が失われないようにする。
- fixed fixturesでreadiness判定を検証する。

### Out of Scope

- 新しいUnknown subsystem / runtime state machine / retry engine。
- schema / validator / Trust Ledger拡張の先行実装。
- Human C-3/C-4の置換。
- #1337 frozen candidateの変更。
- #1359より先に同じproduction surfaceを変更すること。
- HO pathをHuman承認なしで変更すること。
- production file pathをupstream unblock前に推測で固定すること。

## Global Constraints

- #1337 paired evaluation結果固定までは production execution を開始しない。
- #1359 T-10 downstream impact reviewとHuman C-3 / production integrationを先に完了する。
- #1359の実装後、同じ概念を重複実装せず差分だけを追加する。
- runtime recovery semanticsは #894 / #1383 を正本とする。
- new C-1 check IDは、既存checkへ統合不能な根拠がない限り作らない。
- simple / low-risk taskに6項目の空sectionを強制しない。
- canonical / distributed mirrorのdriftを残さない。
- critical modeでは、具体的Files / commands / expected resultsを確定した **Plan v2** とC-1/C-2が揃うまでHuman C-3へ進まない。
- production taskはHuman C-3 APPROVEDへ `depends_on` を物理的に接続する。

## Evidence / Current State

### Known Facts

- #1416のscopeと6 dimensionsはIssueに定義済み。
- #1359はFacts / Assumptions / Unknowns / Blocking Unknowns / Readinessを統合予定。
- #1359 production implementationは#1337 pair-level result固定までBLOCKED。
- #1337 current effectiveness resultは `INCONCLUSIVE_NOT_RUN`。
- #894 / #1383はruntime retry / stop / convergenceの責務を持つ。
- 現行Plan templateにはGoal、Questions / Unknowns、Verification Plan、Replan Triggers、Stop Condition、Human Approval Boundaryが既にある。
- `review-self.schema.json` のverdict enumは `PASS / WARN / FAIL`。
- Current C-1 templateは25項目。
- Current Working Contextはplan生成時の `INDEX.md`、B+の `current-state.md` / `decision-log.jsonl`、phase/blocker trackingの `status.md` を定義している。

### Assumptions

- AI Execution Readinessは独立artifactではなく、既存Plan evidenceのprojectionとして実装できる。
- #1359実装後の差分は主に Dependencies / Detectability / projection semantics / runtime handoffになる。
- C-1既存項目へ統合可能で、新規check IDは不要。
- runtime handoffは新しいpolicy engineなしで既存契約へ参照を渡せる。

### Known Unknowns

- #1337 evaluation結果によるPlan Design Principlesの下流判断。
- #1359 merge後の最終artifact shape。
- ai-loop handoff側で必要な最小参照形式。
- dogfood後にdeterministic validationが必要になるか。
- unblock後の具体的 production paths / fixture paths / verification commands。

### Blocking Unknowns

- Internal planning blocker: なし。
- External production blockers:
  - EB-01: #1337 pair-level evaluation result未固定。
  - EB-02: #1359 T-10 downstream impact review + Human C-3 / production integration未完了。

## AI Execution Readiness as Projection

### Responsibility map

| Dimension | Canonical source | #1416 responsibility |
|---|---|---|
| Why / Outcome | Plan Goal / PBI Why / AC | outcomeがwork breakdownと接続しているかをprojection |
| Assumptions | #810 / #1359 Facts / Assumptions | verified / unverifiedをreadinessへ反映 |
| Dependencies | Plan prerequisites / repository evidence | declared / available / verifiedを区別 |
| Unknowns / Surprises | #810 / #1359 Unknowns / Blocking Unknowns | blocking/non-blockingをreadinessへ反映 |
| Detectability | Verification Plan / tests / verifier refs | material failureを検出可能か判定 |
| Recovery / Escalation | Replan Triggers / Stop Condition / Human Approval + #894/#1383 refs | retry policyを複製せず、実行停止・再計画・Human escalation可能性を判定 |

### State semantics

#### ready

次をすべて満たす:
- outcomeが明確;
- materialなunverified assumptionが安全に扱われる;
- required dependencyがavailableかつ必要な範囲でverified;
- Blocking Unknown = 0;
- material failureがcredibly detectable;
- task riskに見合うre-plan / stop / escalation boundaryがある。

#### needs_clarification

Humanの仕様・優先度・risk tolerance判断が不足しており、その回答で実行条件を解消できる状態。

例:
- 仕様A/Bのどちらを採るかHuman決定が必要;
- compatibility優先かmigration優先かHuman判断が必要。

#### blocked

Human回答だけでは解消できず、外部前提または安全/証拠能力が利用不能な状態。

例:
- required dependency unavailable;
- required environment / permission / upstream PR unavailable;
- material failure detectorが存在しない;
- required evidenceを取得不能;
- high-impact changeで必要なstop/recovery boundaryを確立不能。

## TASK-1416 Dogfood

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

| Dependency | Declared | Available | Verified | Evidence / Impact |
|---|---:|---:|---:|---|
| #1337 pair-level decision | yes | no | no | issue state; production blocker |
| #1359 T-10 + Human C-3 + production integration | yes | no | no | issue state; overlapping-surface blocker |
| #894/#1383 runtime semantics | yes | yes | yes at issue-contract level | reuse only |
| current templates/skills | yes | yes | yes for planning inventory | planning work possible |

### 4. Unknowns / Surprises

- #1337結果でPlan Design Principlesの採用判断が変わる可能性。
- #1359がDependencies/Readiness surfaceまで吸収する可能性。
- runtime handoffの正本が実装時点で更新される可能性。

### 5. Detectability

Production implementation後に最低限以下で検出する。

- simple-ready fixture: `ready` / ceremonial section増加なし。
- dependency-blocked fixture: `blocked`。
- detection-missing fixture: `blocked`。
- human-clarification fixture: `needs_clarification`。
- recovery-required fixture: `blocked`。
- mirror sync / stale reference checks。
- C-1 check count不変。
- existing test suite / CI。

### 6. Recovery / Escalation

TASK-1416自身では既存sectionsをsourceにする。

- Re-plan:
  - #1337結果が現Plan assumptionsを崩した場合。
  - #1359実装が想定surfaceを吸収した場合。
  - handoff contract ownerが想定と異なる場合。
- Stop:
  - HO path変更が必要。
  - schema / validator / runtime state追加が必要。
  - new C-1 IDなしでは安全に表現できない。
  - #1359と責務競合する。
- Human escalation:
  - Plan v2へのHuman C-3。
  - HO patch。
  - schema/validator expansion。
  - scope変更。
- Runtime retry / convergence behavior:
  - #894 / #1383へ委譲し、本Planには複製しない。

### Readiness

- **Planning artifact readiness: ready**
- **Production execution readiness: blocked**
- Rationale: EB-01 / EB-02によりrequired dependenciesがunavailable。

## Approach Comparison

| 案 | Evidence | Complexity Cost | New Abstractions | Verification | 判定 |
|---|---|---|---|---|---|
| A. #1359後に既存Plan情報からreadinessをprojection | current Plan already owns adjacent fields | low-medium | none | fixed fixtures + existing checks | **採用** |
| B. #1416独立のReadiness Gate/subsystem | no measured need | high | new gate/state | new runtime/schema needed | 不採用 |
| C. validator-first | only some semantics are deterministic | medium-high | validator rules | deterministic but premature | defer |

### Recommended Approach

**A**。#1359がEvidence / Assumptions / Unknowns / Readinessの基礎を提供した後、#1416は不足する Dependencies / Detectability / projection semantics / runtime handoffを差分統合する。

Execution Readiness自体は、既存のGoal / Assumptions / Unknowns / Verification / Replan / Stop / Human Approvalを読み、最終判定だけをprojectionする。

## Pre-C3 Replan Gate

Upstream unblock後に、現在のplanning baselineをそのままHuman C-3へ渡してはいけない。

必須順序:

```text
#1337 result fixed
  -> #1359 production integration complete
  -> T-10 fresh dependency check
  -> T-11 current production-surface inventory
  -> T-12 ai-loop handoff owner inventory
  -> T-03 regenerate/finalize Plan v2 + todo v2 + test-cases v2
       - concrete files
       - concrete commands
       - exact expected values/verdicts
       - production task dependency graph
       - every production task depends transitively on Human C-3
  -> T-04 canonical 25-item C-1
  -> T-05 independent C-2
  -> Human H-01 C-3
  -> only then production execution
```

Current planning baseline intentionally does **not** contain speculative production implementation tasks.

## Current Planning Work Breakdown

### T-10: Fresh upstream readiness check

**Purpose**: upstream dependenciesが解消したかを確認する。

**Files**:
- Read: GitHub Issues #1337, #1359, #894, #1383
- Read: current main

**Steps**:
- [ ] #1337 pair-level resultを確認。
- [ ] #1359 production integration / downstream decisionを確認。
- [ ] 未解消なら `BLOCKED` を維持し、production planningを進めない。

**Completion Criteria**:
- [ ] EB-01 / EB-02の状態とevidenceが記録される。

**Rollback**: 不要（read-only）

### T-11: Fresh production-surface inventory

**Purpose**: #1359後のmainで#1416の差分だけを確定する。

**Files**:
- Read: `docs/ai/plan-design-principles.md`
- Read: `.agents/skills/ai-dev-plan/SKILL.md`
- Read: `docs/working/templates/plan.md`
- Read: `docs/working/templates/review-self.md`
- Read: relevant distribution mirrors

**Steps**:
- [ ] #1359による新規/変更責務をinventory。
- [ ] six dimensionsのowner matrixを更新。
- [ ] duplicateになるproposed changeを削除。

**Completion Criteria**:
- [ ] #1416 deltaが明示される。
- [ ] speculative duplicate changeが0。

**Rollback**: 不要（read-only）

### T-12: Fresh ai-loop handoff inventory

**Purpose**: runtime handoffのcanonical ownerを確定する。

**Files**:
- Read: #894 / #1383
- Read: current ai-loop V2 canonical docs resolved by repository search

**Steps**:
- [ ] expected outcome / verifier refs / blocker / escalation hintの既存格納先を確認。
- [ ] runtime policy ownerを確認。
- [ ] HO pathが必要ならStop Conditionで停止。

**Completion Criteria**:
- [ ] handoff ownerが具体的file/pathレベルで確定する。

**Rollback**: 不要（read-only）

### T-03: Regenerate production Plan v2

**Purpose**: T-10〜T-12のfresh evidenceでcritical-mode executable planへ更新する。

**Files**:
- Modify: `docs/working/TASK-1416/plan.md`
- Modify: `docs/working/TASK-1416/todo.md`
- Modify: `docs/working/TASK-1416/test-cases.md`
- Append: `docs/working/TASK-1416/decision-log.jsonl`

**Steps**:
- [ ] production filesを具体パスで固定。
- [ ] fixture pathsを具体パスで固定。
- [ ] verification commands / exact expected resultsを固定。
- [ ] production taskを2-5分/reviewable unitへ分割。
- [ ] Human C-3をproduction taskのhard dependencyとしてgraphへ記録。
- [ ] AC→TC traceを更新。

**Completion Criteria**:
- [ ] `TBD/TODO/決定後/determined by/confirmed later` 相当のexec placeholderが0。
- [ ] production tasksにconcrete Files / Steps / Completion / Rollbackがある。
- [ ] production tasksはH-01へtransitively依存する。

**Rollback**: planning artifact commitをrevert。

### T-04: Canonical C-1

**Purpose**: Plan v2を正規25項目で検査する。

**Files**:
- Modify: `docs/working/TASK-1416/review-self.md`

**Steps**:
- [ ] current `docs/working/templates/review-self.md` の全checkを実行。
- [ ] FAILを0にする。
- [ ] WARNは根拠・owner・扱いを明示。

**Completion Criteria**:
- [ ] schema-valid frontmatter。
- [ ] 25 checks全件が結果を持つ。
- [ ] C1-TODO-09 / C1-TODO-11がproduction graphを検査済み。

**Rollback**: review artifact更新をrevert。

### T-05: Independent C-2

**Purpose**: makerと独立したreview laneでPlan v2をレビューする。

**Files**:
- Modify: `docs/working/TASK-1416/review-external.md`

**Steps**:
- [ ] independent reviewerを実行。
- [ ] unavailableなら理由 / residual riskを正直に記録し、Human C-3へ進まない。
- [ ] major以上をPlanへ反映し、必要ならC-1を再実行。

**Completion Criteria**:
- [ ] C-2がexecuted。
- [ ] unresolved major/critical = 0。
- [ ] latest Plan v2 hash/内容に対するreviewである。

**Rollback**: review artifact更新をrevert。

## Verification Plan

| 種別 | 確認方法 | 期待結果 | Timing |
|---|---|---|---|
| Current baseline scope | PR diff | `docs/working/TASK-1416/**` only | now |
| Review schema | `schemas/review-self.schema.json`とのfrontmatter整合 | PASS/WARN/FAIL enum only | now + v2 |
| C-3 graph | todo `depends_on` review | production task -> H-01 dependency | Plan v2 |
| Simple fixture | fixed scenario | `ready` | Plan v2 |
| Dependency fixture | fixed scenario | `blocked` | Plan v2 |
| Detectability fixture | fixed scenario | `blocked` | Plan v2 |
| Human clarification fixture | fixed scenario | `needs_clarification` | Plan v2 |
| Recovery fixture | fixed scenario | `blocked` | Plan v2 |
| C-1 | canonical 25 checks | FAIL=0 | Plan v2 |
| C-2 | independent review | unresolved major/critical=0 | Plan v2 |
| Runtime boundary | #894/#1383 trace | retry/convergence duplicated=0 | Plan v2 |
| Distribution | sync/stale scan | canonical/mirror drift=0 | production |
| Regression | repo CI/tests | PASS | production |

## Replan Triggers

- #1337 final result changes the applicable Plan Design Principles baseline.
- #1359 merges a conflicting or broader readiness model.
- ai-loop handoff owner differs from current assumption.
- new schema / validator / C-1 ID becomes necessary.
- simple fixture cannot stay minimal without weakening safety.
- required HO path change is discovered.
- T-10〜T-12でproduction paths / responsibilitiesが本Planのassumptionsと異なる。

## Stop Condition

- #1337 pair-level result未固定。
- #1359 T-10 + Human C-3 / production integration未完了。
- Plan v2 / todo v2 / test-cases v2が未確定。
- T-16 canonical C-1が未完了またはFAILあり。
- T-17 independent C-2が未実施、またはunresolved major/criticalあり。
- overlapping production changes would bypass #1359 ordering。
- HO path / irreversible workflow contract change is required without Human approval。
- runtime semantics would be duplicated from #894/#1383。

## Human Approval Boundary

- Production exec開始: **Plan v2 + canonical C-1 + independent C-2後のHuman C-3 APPROVED**
- HO patch: Human-owned
- schema / validator expansion: separate Human decision
- merge: Human C-4

## Current C-1 Preparation Checklist

- [x] Goal / outcomeとplanning work breakdownが接続している
- [x] Assumptions / dependencies / unknownsを分離した
- [x] required dependency availabilityを実測状態で区別した
- [x] readiness state semanticsを一意化した
- [x] Execution Readinessを既存正本からのprojectionとして定義した
- [x] failure detectabilityをfixed fixtureへ接続した
- [x] recovery / escalationをruntime ownerと分離した
- [x] Pre-C3 Replan Gateを明示した
- [x] #1337 / #1359 blockerを無視していない
- [x] simple task ceremonyをnon-goal化した
