# Plan Design Principles — Decision Rationale / Multi-perspective Review

Date: 2026-09-17  
Related Issue: #1335  
Status: Working Decision Record

## Purpose

この文書は `docs/ai/plan-design-principles.md` の規範そのものではなく、**なぜその形にしたか、どの案を採用・修正・却下したかを後から追えるようにする判断記録**である。

- `docs/ai/plan-design-principles.md`: 詳細正本
- `.agents/skills/ai-dev-plan/SKILL.md`: Plan作成時の配布可能な実行サマリ
- 本文書: Context / Alternatives / Decisions / Trade-offs / Revisit Triggers
- `2026-09-17-plan-design-principles-implementation-review.md`: 実装途中の再レビューと修正記録
- Issue #1335: 実装計画・Acceptance Criteria・進捗

生の思考ログではなく、判断を再検討できる形で残す。

---

## 1. Context

PlanGate の Plan はすでに、前提の実測、Questions / Unknowns、アプローチ比較、Work Breakdown、Verification、Replan / Stop Conditionを持つ。

一方、AI coding agent の実装能力が高くなるほど、次の問題が目立つ。

- 将来用途を先回りした abstraction / interface / config / extension point を低コストで増やす
- 実装後の Review に設計知識が集まり、「どう作るべきか」がレビューまで遅延する
- review finding のたびに checklist を増やすと C-1 が肥大化する
- TDD が「実装後の確認」に寄り、設計入力として働きにくい
- Principle をそのまま check item / test item に変換すると儀式化する

したがって、**繰り返しレビューで指摘する設計判断を、可能なものからPlan作成ガイドへ左シフトする**方針を採用した。

---

## 2. 却下した案: 原則を1つずつC-1化する

元の検討対象には SOLID / DRY / KISS / YAGNI / SRP / OCP / DIP / Composition / Separation of Concerns / Fail Fast / Measure First があった。

これらを個別C-1項目にする案は却下した。

理由:

- SOLIDとSRP/OCP/DIPが重複し粒度が揃っていない
- OCP / DIP / Compositionは常時適用すると過剰設計を誘発する
- DRYは「似たコード→共通化」と誤解されやすい
- #960 のC-1 count driftを悪化させる
- AIがchecklist completionを目的化しやすい

Decision:

> **原則群を少数のPlan Design Principlesへ翻訳し、Review checklistではなくPlan作成時の判断モデルにする。**

---

## 3. ReviewからGuideへ移す境界

Review観点は2種類に分かれる。

1. 実装前に選択できる設計判断
2. actual diff / behavior / evidenceを見ないと判定できない実装事実

採用した責務分離:

```text
Principles = どう考えるか
Guide      = どうPlanへ落とすか
Artifact   = 今回のmaterialな判断結果
Review     = 実際にそうなったかを独立確認する
Validator  = 機械判定可能な契約だけ
```

Reviewに残すもの:

- logic correctness
- off-by-one / null / race / swallowed error
- hallucinated API / nonexistent reference
- claim-vs-actual
- actual security vulnerability
- actual N+1 / resource leak
- test evidence completeness
- Plan vs diff のscope leakage

Reviewを薄くしても、独立checkerとしての役割は弱めない。

---

## 4. Core Principlesを6つにした理由

### 1. Evidence Before Design

Measure First / Unknown Discoveryの前提を統合する。

```text
Observe
  ↓
Facts / Assumptions / Unknowns
  ↓
Design
```

推測よりrepository / tests / docs / history / current behavior / metricsを優先する。

### 2. Minimum Sufficient Design

KISS / YAGNIを精神論で終わらせず、Current-Need Traceへ変換する。

新しい abstraction / interface / dependency / config / extension point は、現在のAC / constraint / observed problemへtraceできる場合だけ導入する。

### 3. Explicit Responsibility & Boundary

SRP / Separation of ConcernsをOOPに限定せず、Task / Agent / Skill / module / workflow / state / interfaceへ適用する。

PlanGateでは責務境界がreviewability / test boundary / execution autonomyへ直結する。

### 4. Abstraction Requires Evidence

DRYを単なるduplicate-code removalとして扱わない。

```text
similar implementation
  ↓
same knowledge / invariant / business rule?
  ↓ yes
same reason to change?
  ↓ yes
real consumer / variation / current need?
  ↓ yes
abstraction candidate
```

### 5. Extension Is Conditional

OCP / DIP / Compositionは常時ルールではなくconditional lensとする。

> **Extensibility < Simplicity unless current evidence requires extensibility.**

### 6. Design for Verification

設計を「説明が綺麗か」だけでなく「どう正しさを証明するか」まで含めて考える。

```text
Design Decision
  ↓
Observable Behavior / Contract / Invariant
  ↓
Test / Deterministic Check / Evidence
```

---

## 5. Principle Conflict Resolution

採用した優先順位:

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

特にMaintainability / Extensibilityを現在要件より上位に置かない。

AIは将来保守性・拡張性を理由に現在の複雑性を正当化しやすいため、EvidenceとSimplicityを優先する。

---

## 6. Conditional Design Guidance

Core Principlesへ全部を入れると肥大化するため、次は該当条件でだけ発火する。

- Failure & Recovery
- Compatibility / Change
- Observability / Diagnosability
- Security by Design
- Performance / Cost Awareness
- UI / UX / Accessibility

例:

- external API / async → Failure & Recovery
- schema / public API → Compatibility
- non-trivial runtime state → Observability
- auth / permission / secret → Security
- expensive I/O / model usage → Performance
- UI task → UI / UX / Accessibility

Decision:

> **Principlesは常時使う。Conditional Guidanceは条件付きで使う。**

---

## 7. TDDへの接続

初期案は `Requirement → Test → RED → Implementation → GREEN` に寄っていたが、複数視点レビューで一律RED-firstは不適切と判断した。

採用:

```text
New behavior
  RED → minimum implementation → GREEN → Refactor

Bug fix
  regression RED → fix → GREEN

Behavior-preserving refactor
  characterization / existing tests GREEN
    → refactor
    → GREEN + behavior-preservation evidence

Docs / config / generated artifact
  deterministic baseline
    → change
    → deterministic validation
```

上位ルール:

> **変更の性質に適した事前証拠を持ち、変更後に同じ契約を再検証する。**

#867 が扱う Knowledge Delta / Characterization Test / Preparatory Refactoring の詳細契約は #1335 で再実装しない。

---

## 8. Contract / Invariant Requires Source

TDDを強化すると、AIが次の自己正当化を起こす危険がある。

```text
テストを書きたい
  ↓
Invariantを発明
  ↓
Invariantを守るabstractionを発明
```

そのため、Contract / Invariantも現在根拠へtraceする。

```text
AC / Existing Behavior / Domain Rule / Architecture Constraint / Measured Evidence
        ↓
Contract / Invariant
        ↓
Test Case
```

`testが欲しいから invariant を作る`、`abstractionを正当化するためcontractを作る`は禁止する。

---

## 9. Test traceとExpected Value Sourceを分離する

`test-cases.md` では2つの問いを分ける。

```text
Trace
  = なぜこのtestが存在するか
  = AC / Contract / Invariant / Regression / Conditional Requirement

Expected Value Source
  = なぜその期待値が正しいか
  = measured evidence / existing behavior / specification / approved rule
```

さらに完了前レビューで、各Test CaseにTrace Type / Sourceを重複記載する案は肥大化すると判断した。

最終形:

- `Verification Trace` 表をTraceの正とする
- 各Test Caseは `Trace ID` だけ参照する
- 既存 `Convention Evidence` はExpected Value Source側の仕組みとして維持する

#936 の「テスト生成量制御」は #960 に統合済みのため、本PRで新しいC-1削減項目やmode別件数上限は追加しない。

---

## 10. Mode-aware OutputとB-2の境界

原則:

> **Apply every principle mentally. Materialize only relevant decisions.**

ただし、これは既存workflow contractを勝手に省略する意味ではない。

完了前レビューで、ultra-light / lightならApproach Comparisonを省略できるという初期案は、現行B-2の「2〜3案のtrade-off比較」と矛盾すると判明したため撤回した。

最終判断:

- B-2の2〜3案比較はmodeにかかわらず維持する
- light / ultra-lightでは各セルを短くし、追加の説明や空セクションを増やさない
- **必須ステップ数ではなく、記述密度をmode-awareにする**

---

## 11. Distribution Strategy — Initial Plan and Replan

### Initial plan — Superseded

当初は次を想定した。

```text
docs/ai/plan-design-principles.md
  ↓ sync
ai-dev-plan/references/plan-design-principles.md
  ↓
plugin / Codex / install.sh
```

理由は、`docs/**` が配布先へ届かないためだった。

### Implementation finding

調査すると、`.agents/skills/ai-dev-plan/SKILL.md` 自体は既存sync経路ですでに配布される。

新しいreference、allowlist、drift契約を増やすより、詳細正本を1つに保ち、Plan生成に必要な規範だけSkillへ実行サマリとして持たせる方がMinimum Sufficient Designに合う。

### Final decision

```text
docs/ai/plan-design-principles.md       # detailed canonical source
        ↓ semantic alignment
.agents/skills/ai-dev-plan/SKILL.md     # executable summary
        ↓ existing skill sync
plugin / install.sh / Codex
```

Skill summaryが保持する最低契約:

1. 6 Core Principles
2. `Extensibility < Simplicity unless current evidence requires extensibility`
3. Contract / Invariant Requires Source
4. change-type-aware TDD
5. TraceとExpected Value Sourceの分離
6. Mode-aware Output

全文byte-identical copyは要求しない。

派生テンプレートも `docs/**` のみに依存せず、配布可能なSkill summaryを実行規範として参照する。

---

## 12. #960との境界

初期実装では `plan.md` のC-1ローカルチェックリストへ以下を追加しかけた。

- Minimum Sufficient Design
- sourced Contract / Invariant
- change-type-aware Verification

しかし #960 でC-1の項目数・mode別適用が未解決のため撤回した。

最終判断:

- 新規C-1 check IDを作らない
- C-1項目数を変えない
- Design判断はApproach Comparison / Recommended Approach / Verification Strategyへ置く
- C-1は既存項目から成果物を確認する

---

## 13. #810 / #867 / #794との責務分担

#1335では既存・予定責務を再実装しない。

- #794: implementation review側のYAGNI / architecture / anti-pattern review
- #810: Facts / Assumptions / Unknowns、Blocking Unknown
- #867: Knowledge Delta、behavior vs structural change、Characterization / Preparatory Refactoring

#1335の責務は、これらをPlan作成時の上位原則から必要時に発火・参照できるようにすること。

---

## 14. Review → Guidance Promotion Policy

今後の改善原則として採用する。

```text
Repeated Review Finding
        ↓
Preventable before implementation?
        ├─ No → Review / Test / Validatorへ残す
        └─ Yes
             ↓
        Generalizable?
        ├─ No → task / domain guidance
        └─ Yes
             ↓
        Promote to Design Guidance / Principle
             ↓
        Review keeps conformance + actual verification
```

狙いは、Review checklistを増やし続けるのではなく、**再発する設計ミスの学習を上流へ戻す**こと。

---

## 15. Multi-perspective Review Summary

| Perspective | Result | Main decision |
| --- | --- | --- |
| Architecture | PASS | Principles / Guide / Artifact / Review を分離 |
| TDD / Verification | PASS after fix | 一律RED-firstを撤回 |
| AI anti-overengineering | PASS | Current-Need Trace / sourced Contract |
| light / ultra-light | PASS after fix | B-2は維持、記述密度だけ軽くする |
| Test volume | PASS with boundary | Trace重複を削減、#936/#960の件数制御は触らない |
| C-1 governance | PASS after fix | 新規項目を追加しない |
| Related issue overlap | PASS | #810/#867/#794を再実装しない |
| Distribution | PASS after replan | 既存Skill syncを再利用 |
| Review independence | PASS | actual correctness / evidence はReviewに残す |

---

## 16. Rejected / Superseded Alternatives

### 11 principlesを個別C-1化
却下。重複・粒度不整合・C-1肥大化。

### Review GateをPrinciples正本にする
却下。feedbackが遅く、makerの設計判断を改善しない。

### 全変更をRED-first
却下。behavior-preserving refactor / docs / configに不自然。

### 全Conditional Guidanceを全タスクへ適用
却下。light taskを儀式化する。

### ultra-light / lightでB-2比較を省略
却下。既存B-2契約と矛盾する。記述密度だけ下げる。

### 新しいbundled `plan-design-principles.md` を追加
**実装調査後にSuperseded。** 既存Skill syncで必要な実行規範を配れるため、新しい配布経路を増やさない。

---

## 17. Revisit Triggers

以下が観測されたらPrinciples / Guideを再検討する。

- reviewで同じ設計findingが複数回繰り返される
- light taskのPlan量が増え実装速度を明確に落とす
- Contract / Invariant traceが形式的に埋められるだけになる
- test case数が増えるがdefect detection / confidenceが改善しない
- Skill summaryと詳細正本のsemantic driftが発生する
- reviewerがPrinciples再実行だけになり独立性が落ちる
- speculative abstractionが依然として頻発する
- characterization / refactor flowが通常TDDと衝突する
- B-2自体をmode-awareに変える必要性が実運用で観測される

---

## Final Decision

北極星:

> **Gateから作らない。Principlesから作る。**
>
> **AIに良い設計判断をするための思考モデルを与え、その判断から導かれたBehavior / Contract / Invariantを適切なTest / Evidenceで証明し、Reviewはactual diff / evidenceを独立確認する。**

```text
Requirement / AC
        ↓
Evidence / Current State
        ↓
Plan Design Principles
        ↓
Minimum Sufficient Design
        ↓
Sourced Behavior / Contract / Invariant
        ↓
Change-type appropriate Verification
        ↓
Plan / Test Cases
        ↓
Execute
        ↓
Evidence
        ↓
Independent Review
        ↓
Repeated finding → Guidanceへ学習を戻す
```

PlanGateを「checklistを増やす仕組み」ではなく、**Evidenceに基づき設計し、検証し、レビューで得た学習を上流へ戻すAI開発ハーネス**として進化させる。