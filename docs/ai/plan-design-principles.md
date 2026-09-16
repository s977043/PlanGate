# Plan Design Principles

Status: Draft for #1335

## Purpose

PlanGate の Plan を、単なる実装手順ではなく、**Evidence に基づいて最小十分・検証可能な設計を選択するための判断ガイド**として扱う。

この文書は Plan 作成時の設計判断の正本である。

- Principles: どう考えるか
- Planning Guide: どう Plan に落とすか
- Review: 実際に逸脱していないか
- Validator: 機械判定可能な契約だけを検査する

Review / Gate に設計知識を集約しない。実装前に選べる判断は可能な限り上流へ置き、Review は actual diff / behavior / evidence の独立確認に集中する。

```text
Plan Design Principles
        ↓
Planning Guide / ai-dev-plan
        ↓
Observable Behavior / Contract / Invariant
        ↓
Test Cases / Verification Strategy
        ↓
Plan Artifact
        ↓
C-1 / C-2 / Validator
        ↓
Execute / TDD
        ↓
Review Gate
```

## Core Principles

### 1. Evidence Before Design

**設計する前に現状を確認する。**

Plan は推測から始めない。repository、existing implementation、tests、docs、ADR、config、workflow、schema、history、previous artifacts、current behavior、observed metrics を確認する。

```text
Observe
  ↓
Facts / Assumptions / Unknowns
  ↓
Design
```

重要前提は command / repository evidence / artifact / 実測値で裏取りする。検証不能なものは Fact とせず Assumption / Unknown とする。

### 2. Minimum Sufficient Design

**現在の Acceptance Criteria を満たす最小十分な設計を選ぶ。**

新しい abstraction / interface / config / dependency / extension point / generic layer / utility / framework は、現在の必要性へ trace できる場合だけ導入する。

Current-Need Trace の根拠:

1. Acceptance Criterion
2. 現在確認済みの constraint
3. 実測された既存コードまたは運用上の問題

次だけを理由に複雑化しない。

- 将来必要になるかもしれない
- 拡張性が高そう
- 綺麗になる
- 一般化できそう
- AI が実装しやすい

> Extensibility < Simplicity unless current evidence requires extensibility.

### 3. Explicit Responsibility & Boundary

**責務と境界を設計時点で明確にする。**

対象は class だけではない。

- Task
- Agent
- Skill
- module / service / component
- workflow / state
- interface

各要素の責務を 1 文で説明できること。独立した複数の変更理由を 1 つの単位へ混在させない。reviewer が Task 単位で approve / reject できる粒度へ分解する。

責務境界は unit / integration / contract test の境界設計にも利用する。

### 4. Abstraction Requires Evidence

**抽象化には根拠が必要。**

DRY を `similar code → common abstraction` と解釈しない。

```text
似た実装
  ↓
同じ knowledge / invariant / business rule ?
  ├─ No → 重複を許容
  └─ Yes
       ↓
同じ理由で変更される ?
  ├─ No → 分離維持
  └─ Yes
       ↓
実在する consumer / variation または現要件上の必要性がある ?
  ├─ No → まだ抽象化しない
  └─ Yes → abstraction candidate
```

抽象化をテストする場合も、抽象クラスや interface の存在そのものではなく、それが守る knowledge / invariant / contract を検証する。

### 5. Extension Is Conditional

**OCP / DIP / Composition 等は常時適用せず、実在する境界・variation がある場合だけ使う。**

発火例:

- stable core に複数の実在 variation がある
- public extension point が現在要件として必要
- domain ↔ infrastructure / external API / storage / provider / runtime の dependency boundary がある
- inheritance hierarchy を新設・変更する

存在しない将来 variation のために implementation / test matrix を増やさない。

### 6. Design for Verification

**検証方法を説明できない設計は未完成とみなす。**

```text
Design Decision
  ↓
What observable behavior / contract / invariant proves it?
  ↓
How will we verify it?
  ↓
Test Case / Deterministic Check / Evidence
```

Plan 作成時に確認する。

- AC をどの verification method で確認するか
- 重要な Design Decision がどの observable behavior / contract / invariant に現れるか
- 重要な振る舞いを外部から観測できるか
- deterministic check にできる部分はどこか
- failure path / boundary condition を意図的に発火できるか
- positive / negative control を用意できるか
- verification が実装詳細へ過度に結合していないか
- 実行できない検証の残存リスクを説明できるか

> Every important design decision should identify the observable behavior, contract, or invariant that proves the decision works. Tests verify those outcomes—not the principle itself.

## Principle Conflict Resolution

原則が衝突した場合は次の順で判断する。

```text
1. Correctness / Safety
2. User Requirement / Acceptance Criteria
3. Evidence
4. Simplicity
5. Clear Responsibility / Boundary
6. Verifiability
7. Maintainability
8. Extensibility
```

DRY と YAGNI が衝突する場合、抽象化の evidence が不足していれば YAGNI を優先する。

## Planning Guide

`ai-dev-plan` は次の順序を標準とする。

```text
1. Goal / Acceptance Criteria
2. Current State を実測
3. Facts / Assumptions / Unknowns
4. Existing Pattern / Constraints
5. 最小案を含む2案以上
6. Evidence / Complexity / Risk / Abstraction を比較
7. Minimum Sufficient Design を選択
8. Responsibility / Boundary を定義
9. 新規 abstraction を Current-Need Trace へ接続
10. Observable Behavior / Contract / Invariant を定義
11. Verification Strategy / Test Cases を設計
12. Conditional Design Guidance を必要時のみ発火
13. Work Breakdown
14. Replan / Stop / Human Boundary
```

より複雑な案を採用する場合、その追加複雑性が必要な現在の根拠を説明する。

## TDD / Test Case Design

Plan Design Principles は `test-cases.md` の生成にも利用する。

```text
Requirement / Acceptance Criteria
        ↓
Observable Behavior
        ↓
Contract / Invariant
        ↓
Test Case
        ↓
Design Refinement
        ↓
RED
        ↓
Implementation
        ↓
GREEN
        ↓
Refactor
        ↓
Behavior Preservation
```

### Test Case Derivation Rule

各 Test Case は最低限、次のいずれかへ trace できること。

1. Acceptance Criterion
2. 現在守るべき Contract
3. 現在守るべき Invariant
4. Conditional Design Guidance から導かれた failure / boundary / compatibility requirement
5. 回帰として保存すべき観測済み failure

原則そのものをテストしない。テストが検証するのは、その原則から導かれた observable behavior / contract / invariant である。

### Conditional Guidance → Test Cases

全テストに全観点を要求しない。該当 guidance が発火した場合だけ展開する。

```text
Basic
 ├─ happy path
 ├─ negative path
 └─ boundary

Failure & Recovery fired
 ├─ retryable failure
 ├─ non-retryable failure
 ├─ timeout / cancellation
 └─ partial failure / recovery

Compatibility fired
 ├─ old contract
 ├─ new contract
 ├─ migration / coexistence
 └─ rollback

Security fired
 ├─ unauthorized / forbidden
 ├─ invalid / untrusted input
 └─ privilege / trust boundary

Observability fired
 ├─ failure evidence exists
 ├─ observation / hypothesis separation
 └─ reproducible diagnosis
```

### TDD Evidence Flow

```text
AC / Contract / Invariant
        ↓
Test Case
        ↓
RED evidence
        ↓
Implementation
        ↓
GREEN evidence
        ↓
Refactor
        ↓
Behavior preservation evidence
```

Refactor 後も、守るべき Behavior / Contract / Invariant が変わっていないことを証拠で確認する。

## Conditional Design Guidance

Core Principles を肥大化させず、該当条件でのみ発火する。

### Failure & Recovery Design

external API / tool / provider、async / retry / queue、destructive operation、partial failure があり得る場合に使う。

```text
Success
Failure
Retryable failure
Non-retryable failure
Partial failure
Timeout / Cancellation
Recovery / Rollback
Human escalation
```

failure を単純 retry にせず、retry / repair / replan / escalate / fail-closed を区別する。

### Compatibility / Change Design

public API / persisted data / event schema / CLI / config / workflow / plugin contract を変更する場合に使う。

> Preserve contracts by default.

変更する場合は compatibility strategy / migration / coexistence / cutover / rollback を Plan で定義する。

### Observability / Diagnosability

非自明な runtime / workflow / state / integration を変更する場合に使う。

後から次を説明できる設計にする。

- What happened?
- Where did it fail?
- What input / state caused it?
- What is observed fact?
- What is only cause hypothesis?
- Can we reproduce it?

Observation と cause hypothesis を混ぜない。

### Security by Design

trust boundary / auth / permission / secret / destructive capability / untrusted input がある場合に使う。

設計時に trust boundary、least privilege、allowed / denied action、secret handling、destructive boundary、Human-owned boundary を決める。

### Performance / Cost Awareness

large dataset / high-frequency path / external I/O / expensive query / model-token usage 等がある場合のみ使う。全タスクで最適化を要求しない。

### UI / UX / Accessibility

UI変更時のみ使う。既存 Design Gate を参照し、design token / component reuse / states / responsive / accessibility を実装前に決める。

## Review に残すもの

実装後の actual diff / behavior / evidence を見ないと判定できない内容は Review に残す。

- logic correctness
- off-by-one / null / race / swallowed error
- hallucinated API / nonexistent reference
- claim-vs-actual
- actual security vulnerability
- actual N+1 / loop I/O / resource leak
- test evidence completeness
- scope leakage (Plan vs diff)
- compatibility contract が実際に維持されたか
- Design Guidance が実装へ正しく反映されたか

## Review → Guidance Promotion Policy

同型の review finding が繰り返される場合、レビュー項目を増やす前に上流化を検討する。

```text
Repeated Review Finding
        ↓
Preventable before implementation?
        ├─ No  → keep in Review
        └─ Yes
             ↓
        Generalizable?
        ├─ No  → task/domain guidance
        └─ Yes
             ↓
        Promote to Design Guidance / Principle
             ↓
        Review keeps only conformance check
```

昇格候補は、複数タスクで再発し、実装前に判断可能で、原因がコードミスより設計判断にあり、Guide 化で再発率を下げられるものとする。

## Non-goals

- Review Gate を廃止する
- すべての review finding を Principle へ移す
- SOLID / DRY / KISS 等を個別 C-1 項目化する
- 全タスクへ Security / Performance / Compatibility Guidance を強制する
- duplicate code を自動共通化する
- interface / DIP / OCP を常時強制する
- Principle ごとにテストを作る
- 将来想定だけで test matrix を増やす

## Related

- #1335 Plan Design Principles
- #581 Task Sizing / Plan Alignment
- #794 architecture review / YAGNI / over-engineering
- #810 Unknown Discovery
- #867 Knowledge Delta / refactoring contract
- #579 UI Design Gate
- #203 Tool Error Taxonomy / Recovery Policy
- #652 Plan Review Readiness
- #923 Harness / Loop / Graph responsibility
- #894 Loop Control / stop / retry
