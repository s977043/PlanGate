# Plan Design Principles — Decision Rationale / Multi-perspective Review

Date: 2026-09-17  
Related Issue: #1335  
Status: Working Decision Record

## 1. この文書の目的

この文書は `docs/ai/plan-design-principles.md` の規範そのものではなく、**なぜその形にしたか、どの論点を検討し、何を採用・却下したかを残す判断記録**である。

正本の役割分担は次の通り。

```text
docs/ai/plan-design-principles.md
  = 現時点の規範・設計判断原則

docs/working/discussions/2026-09-17-plan-design-principles-rationale.md
  = 検討過程・レビュー結果・トレードオフ・再検討条件

Issue #1335
  = 実装計画・Acceptance Criteria・進捗
```

ここでは生の思考ログではなく、後から再検討できる形で `Context / Observation / Alternatives / Decision / Trade-offs / Revisit Triggers` を残す。

---

## 2. Context

PlanGate の Plan はすでに、前提の実測、Unknown、複数案比較、Work Breakdown、Verification、Replan / Stop Condition を備えている。

一方、AI coding agent の実装能力が高くなるほど、次の問題が増える。

- 将来用途を先回りした abstraction / interface / config / extension point を低コストで増やす
- 実装後の Review Gate に設計知識が集まり、「どう作るべきか」がレビューまで遅延する
- review finding を増やすたびに C-1 / review checklist が肥大化する
- TDD が `実装したものを確認するテスト` へ後退し、設計入力として機能しにくくなる
- Principle をそのまま check item / test item に変換すると、儀式と test matrix が増える

ここから、レビュー観点を増やすより、**良い判断を作成時にさせる設計原則・ガイドへ左シフトする**方針を検討した。

---

## 3. 最初に検討した候補

元の問題意識では、SOLID / DRY / KISS / YAGNI / SRP / OCP / DIP / Composition / Separation of Concerns / Fail Fast / Measure First などの原則を Plan / Self Review へ取り込む案を検討した。

### 却下した案: 原則を1つずつ C-1 にする

理由:

- SOLID の内部に SRP / OCP / DIP が含まれ粒度が揃っていない
- OCP / DIP / Composition は常時適用すると過剰設計を誘発する
- DRY は `似たコード → 共通化` と誤解されやすい
- C-1 の項目数 drift (#960) をさらに悪化させる
- AI が checklist completion を目的化し、設計判断の質が上がらない

Decision:

> **原則群をそのままチェックリストへ変換せず、PlanGate向けの少数の設計判断原則へ翻訳する。**

---

## 4. Review から Guide へ移すという判断

### Observation

Review に存在する観点には2種類ある。

1. 実装前に選択できる設計判断
2. actual diff / behavior / evidence を見ないと確認できない実装事実

両方を Review に置くと、Review が設計知識の正本になりやすい。

### Decision

```text
Principles = どう考えるか
Guide      = どう Plan に落とすか
Review     = 実際にそうなったかを独立確認する
Validator  = 機械判定可能な契約だけ
```

採用した原則:

1. Evidence Before Design
2. Minimum Sufficient Design
3. Explicit Responsibility & Boundary
4. Abstraction Requires Evidence
5. Extension Is Conditional
6. Design for Verification

Review に残すもの:

- logic correctness
- off-by-one / null / race / swallowed error
- hallucinated API / nonexistent reference
- claim-vs-actual
- actual security vulnerability
- actual N+1 / resource leak
- test evidence completeness
- Plan vs diff の scope leakage

### なぜこの分離か

Review の価値は `maker が正しく考えたか` をもう一度同じ観点でなぞることではなく、**独立 checker が actual artifact / behavior / evidence を確認すること**にある。

したがって Review は薄くするが、弱くはしない。

---

## 5. Core Principles を6つにした理由

### Evidence Before Design

Measure First / Unknown Discovery を設計前提として統合する。

AIは存在しない API / config / pattern を推測して Plan を作れるため、設計より前に current state の観測が必要。

### Minimum Sufficient Design

KISS / YAGNI を精神論で終わらせず、Current-Need Trace にする。

新しい abstraction / interface / dependency / config / extension point は、現在の AC / constraint / observed problem のどれかへ trace できる必要がある。

### Explicit Responsibility & Boundary

SRP / Separation of Concerns を OOP に限定せず、Task / Agent / Skill / module / workflow / state / interface に適用する。

特に PlanGate では task boundary が reviewability / test boundary / execution autonomy に直結する。

### Abstraction Requires Evidence

DRY を `duplicate code removal` ではなく `knowledge duplication` として扱う。

判断順序:

```text
similar code
  ↓
same knowledge / invariant / business rule?
  ↓ yes
same reason to change?
  ↓ yes
real consumers / variation / current need?
  ↓ yes
abstraction candidate
```

### Extension Is Conditional

OCP / DIP / Composition は常時原則ではなく conditional lens とする。

重要な優先順位:

> Extensibility < Simplicity unless current evidence requires extensibility.

### Design for Verification

設計が良いかを、`説明が綺麗か` ではなく `正しさをどう証明するか` まで含めて考える。

ここから TDD / test-cases.md への接続が生まれた。

---

## 6. 原則衝突時の優先順位

採用:

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

特に `Maintainability / Extensibility` を上に置かない。

理由:

AIは将来保守性や拡張性を理由に現在の複雑性を正当化しやすい。現在要求と evidence を優先することで speculative design を抑える。

---

## 7. Review 観点から Conditional Guidance へ移したもの

Core Principles へ全部入れると肥大化するため、以下を条件付きガイドへ分離した。

- Failure & Recovery
- Compatibility / Change
- Observability / Diagnosability
- Security by Design
- Performance / Cost Awareness
- UI / UX / Accessibility

### 理由

これらは重要だが全タスクで必要ではない。

例:

- external API / async → Failure & Recovery
- schema / public API → Compatibility
- non-trivial runtime state → Observability
- auth / permission / secret → Security
- expensive I/O / model usage → Performance
- UI task → UI/UX/Accessibility

Decision:

> **Principles は常時使う。Conditional Guidance は該当条件でのみ発火する。**

---

## 8. TDDへの接続で得た重要な変更

### 最初の案

```text
Requirement / AC
  ↓
Observable Behavior / Contract / Invariant
  ↓
Test Case
  ↓
RED
  ↓
Implementation
  ↓
GREEN
  ↓
Refactor
```

この方向性自体は良いが、複数視点レビューで問題が見つかった。

### Finding 1: RED-first を全変更へ適用すると不自然

#867 の Knowledge Delta / refactoring 方針では、behavior-preserving refactor は Characterization / existing behavior を GREEN で固定してから構造変更する方が自然。

#### Revised Decision

変更タイプ別に事前証拠を変える。

```text
New behavior
  RED → minimum implementation → GREEN → Refactor

Bug fix
  regression RED → fix → GREEN

Behavior-preserving refactor
  characterization/existing tests GREEN
      → refactor
      → GREEN + behavior-preservation evidence

Docs / config / generated artifact
  deterministic baseline
      → change
      → deterministic validation
```

上位原則は `Always RED first` ではなく、

> **変更の性質に適した事前証拠を持ち、変更後に同じ契約を再検証する。**

とする。

---

## 9. Contract / Invariant をAIに発明させない

### Risk

TDDを強化すると、AIが次の逆流を起こす可能性がある。

```text
テストを書きたい
  ↓
Invariant を作る
  ↓
Invariant を守る abstraction を作る
  ↓
不要な設計を自己正当化
```

### Decision: Contract / Invariant Requires Source

```text
AC
Existing Behavior
Domain Rule
Architecture Constraint
Measured Evidence
        ↓
Contract / Invariant
        ↓
Test Case
```

Contract / Invariant も evidence へ trace する。

これは `Abstraction Requires Evidence` と同型の防御である。

---

## 10. test-cases.md の trace を2種類に分ける

現行 `test-cases.md` には `対応 AC` と `期待値の出所` がある。

今後は概念的に次を分離する。

```text
trace_to
  = なぜこのテストが存在するか
  = AC / Contract / Invariant / Regression / Conditional Requirement

expected_value_source
  = なぜその期待値が正しいか
  = measured evidence / existing behavior / specification / approved rule
```

理由:

`test existence rationale` と `expected-value correctness` は別問題だから。

この分離により、ACだけでは表現しにくい architecture contract / invariant / regression も追跡できる。

---

## 11. Mode-awareにする

### Risk

14段階のPlanning Guideをultra-light / lightへそのまま文章出力させると、PlanGateが儀式化する。

### Decision

> Apply every principle mentally. Materialize only relevant decisions.

Principles は常時判断に使うが、artifactへ記録するのは material な判断だけ。

単純変更では次で十分な場合がある。

```text
Evidence
  ↓
minimum change
  ↓
verification
```

空のarchitecture sectionや `N/A` の大量生成を目的化しない。

---

## 12. Distribution / Plugin / Codexのレビュー結果

### Major Finding

`docs/ai/plan-design-principles.md` を正本にしても、そのままでは plugin / Codex / install.sh 導入先へ届かない。

現行 `ai-dev-plan` は `docs/**` を配布対象とせず、skill の `references/` を bundled resource として利用する契約になっている。

### Decision

```text
docs/ai/plan-design-principles.md        # canonical
        ↓ sync
ai-dev-plan/references/plan-design-principles.md
        ↓
Claude plugin / Codex / install.sh
```

要件:

- bundled copy を手編集しない
- canonical から sync する
- deterministic drift check を持つ
- existing reference-resolution contract を壊さない

これは #1335 のAcceptance Criteriaへ昇格する。

---

## 13. Review independence

Principles を充実させても、reviewer を不要にしない。

Maker:

```text
Principles / Guide
  → good design / plan / tests
```

Checker:

```text
Principles conformance
  + actual diff
  + actual behavior
  + independent evidence
  + adversarial / claim-vs-actual check
```

Review が maker と同じ checklist を再生するだけになれば価値が落ちる。

---

## 14. Review → Guidance Promotion Policy

今後の進化原則として採用する。

```text
Repeated Review Finding
        ↓
Preventable before implementation?
        ├─ No  → Review/Test/Validatorに残す
        └─ Yes
             ↓
        Generalizable?
        ├─ No  → task/domain guidance
        └─ Yes
             ↓
        Promote to Design Guidance / Principle
             ↓
        Review keeps conformance + actual verification
```

狙いは、Review checklist を増やし続けるのではなく、**再発する設計ミスの学習を上流へ戻す**こと。

---

## 15. 複数視点レビューまとめ

### Architecture / Design

判定: Proceed with refinements

良い点:

- Principles → Guide → Artifact → Review の責務分離
- over-engineeringをreview後ではなくplan時に予防
- conditional guidanceでcore肥大化を抑制

注意:

- Principles自体を新しい巨大フレームワークにしない
- 既存 #581 / #794 / #810 / #867 を再実装しない

### TDD / Verification

判定: Proceed after change-type split

良い点:

- AC → Behavior / Contract / Invariant → Test へ拡張できる
- testabilityが設計品質になる

修正:

- 一律RED-firstをやめる
- Contract / Invariantのsource traceを必須化
- trace_to と expected_value_source を分離

### AI Agent Behavior

判定: Positive with anti-gaming guard

良い点:

- speculative abstractionを抑制
- future-proofingを現在根拠へ戻せる

リスク:

- testを作るためのcontract発明
- checklist completion目的化
- light taskでartifact過剰生成

対策:

- Contract / Invariant Requires Source
- Mode-aware Output

### Governance / Distribution

判定: Major fix required before implementation complete

問題:

- docs canonicalだけでは配布先で参照できない

対策:

- bundled reference + sync + drift check

### Review / Quality Assurance

判定: Good separation

Reviewからdesign knowledgeを減らしても、actual verificationは維持する。

### Maintainability

判定: Good if rationale is retained

正本は規範だけにし、今回の判断理由・却下案・再検討条件を本Rationaleへ分離する。

---

## 16. Revised Implementation Plan

### Phase 0: Rebaseline

実装に入る前に設計を固定する。

- [x] Multi-perspective review
- [x] TDDを変更タイプ別へ修正する方針
- [x] Contract / Invariant Requires Source
- [x] Mode-aware Output
- [x] canonical → bundled reference 方針
- [x] Rationale記録

### Phase 1: Canonical Principles

- `docs/ai/plan-design-principles.md` を正本化
- 6 Core Principles
- Conditional Guidance
- Review → Guidance Promotion Policy
- TDD strategy
- Distribution contract

### Phase 2: ai-dev-plan integration

- `ai-dev-plan` がPrinciplesを参照
- bundled `references/plan-design-principles.md` を生成/同期
- plugin / Codex / install.sh で解決可能にする
- drift detection

### Phase 3: test-cases.md

- ACだけでなく Contract / Invariant / Regression / Conditional Requirement へtrace可能にする
- `trace_to` と `expected_value_source` の責務を分離
-既存Convention Evidenceと競合させない

### Phase 4: plan.md / Work Breakdown

- Approach Comparisonへ Evidence / Complexity / Current-Need Trace / Verification を反映
- Recommended Approachに minimum sufficient design の理由を残す
- Change Typeに応じたTDD strategyを選択

### Phase 5: C-1 / Review references

- 新規check_idを増やさない
- existing C1項目の wording / reference のみ調整
- #960 解決前にitem countを動かさない

### Phase 6: Verification Fixtures

最低限:

1. simple/light one-file change
2. new behavior
3. bug fix
4. behavior-preserving refactor
5. external provider
6. schema/contract change
7. speculative future abstraction rejection
8. test-driven invented invariant rejection
9. canonical/bundled drift detection

---

## 17. Rejected Alternatives

### A. 11 principlesを個別check化

却下。重複・粒度不整合・C-1肥大化。

### B. Review GateをPrinciplesの正本にする

却下。feedbackが遅く、makerが良い判断をする助けにならない。

### C. すべての変更をRED-first

却下。behavior-preserving refactor / config/docsには不自然。

### D. 全タスクで全Conditional Guidanceを実行

却下。軽量タスクの儀式化とover-planningを誘発。

### E. docs/aiのみ作ってskillから直接参照

却下。plugin/Codex配布契約上、導入先でdocsが解決できない。

---

## 18. Revisit Triggers

以下が観測されたらPrinciples / Guideを再検討する。

- reviewで同じ設計findingが複数回繰り返される
- light taskのPlan量が明確に増え、実装速度を落とす
- Contract / Invariant trace が形式的に埋められるだけになる
- test case数が増えるが defect detection / confidence が改善しない
- bundled reference driftが発生する
- reviewerがPrinciples再実行だけになり、独立性が落ちる
- speculative abstractionが依然として頻発する
- characterization / refactor flowが通常TDDと衝突する

---

## 19. Final Decision

採用する北極星は次。

> **Gateから作らない。Principlesから作る。**
>
> **AIに良い設計判断をするための思考モデルを与え、Testでその判断から導かれたBehavior / Contract / Invariantを証明し、Reviewはactual diff / evidenceを独立確認する。**

最終的な流れ:

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
Change-type appropriate Test Strategy
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

この構造により、PlanGateを checklist を増やすシステムではなく、**Evidenceに基づき設計し、検証し、学習を上流へ戻すAI開発ハーネス**として進化させる。
