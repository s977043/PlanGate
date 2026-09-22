# ADR-006: Plan Deliberation Protocol の責務境界

**Status**: Accepted  
**Date**: 2026-09-23  
**PBI**: TASK-1352 / #1352（Parent: #1351）  
**Decision Makers**: mine_take

---

## Context

PlanGate にはすでに、実装前の計画品質と承認境界を守るための次の仕組みがある。

- C-1: plan / todo / test-cases のセルフレビュー
- C-2: 外部 AI による独立レビュー
- C-2 の 2 レーン責務:
  - 設計妥当性レーン
  - コードベース整合レーン
- high-risk / critical 等での複数ラウンドレビュー
- ai-loop の blind-first W チェック:
  - Model A = 順方向・設計妥当性
  - Model B = adversarial・失敗モード
  - minor / low の不一致時のみ Model C / D を追加
- deterministic Arbiter による `AUTO_APPROVED | HUMAN_ESCALATED | BLOCKED` の裁定
- Human-owned C-3 / C-4
- append-only な review / decision record

正本:

- C-2 レビュア責務: [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md) §7-bis
- 外部レビュー IF: [`docs/ai/external-reviewer-interface.md`](../ai/external-reviewer-interface.md)
- review phase contract: [`docs/ai/contracts/review.md`](../ai/contracts/review.md)
- ai-loop W チェック / Arbiter 呼び出し: [`.agents/skills/ai-loop-cycle/SKILL.md`](../../.agents/skills/ai-loop-cycle/SKILL.md)
- ai-loop deterministic decision table: [`docs/workflows/ai-loop/decision-table.md`](../workflows/ai-loop/decision-table.md)
- C-3 / C-4 を含む実行契約: [`docs/ai/core-contract.md`](../ai/core-contract.md)

一方、複数 Reviewer が異なる結論に到達した場合、現行 PlanGate は「複数の findings / verdict を残す」「追加 Reviewer を起動する」「Human へ escalate する」ことはできるが、次を独立した contract としては持っていない。

> Reviewer A が Reviewer B の具体的な反証・証拠を確認した後も立場を維持するのか、どの前提・証拠なら変更するのか、最終的に何が unresolved のまま Human 判断へ残ったのか。

本 ADR は、この不足を **Plan Deliberation** という限定責務で補う。

参考にする考え方は Council of High Intelligence の independent-first / cross-examination / dissent preservation だが、Council の実装・persona・多数決・Chairman を PlanGate に導入するものではない。

## Problem Statement

C-2 の複数レビュー結果をそのまま集約すると、以下を区別しにくい。

1. Reviewer が異なる前提を置いている
2. 同じ事実について証拠が競合している
3. 推奨アプローチだけが異なる
4. 一方が他方の見落としを示している
5. 十分な証拠がなく、合意不能である
6. 単に Reviewer 数の多数 / 少数が違うだけである

これらを verdict の多数決や新しい LLM Judge で潰すと、PlanGate の既存設計である「LLM は判断材料を提供し、機械的裁定は deterministic logic、人間の governance decision は Human が所有する」という責務分離を壊す。

必要なのは新しい裁定者ではなく、**不一致を反証可能な形へ整理し、未解決点を失わず C-3 へ渡す層**である。

## Decision Drivers

- **承認境界を弱めない**: C-3 / C-4 の Human ownership を維持する
- **deterministic authority を重複させない**: Arbiter と競合する Judge を作らない
- **Independent-first を維持する**: 他 Reviewer の結論を見る前に initial position を確定する
- **Consensus bias を避ける**: 多数決・confidence weighting を correctness とみなさない
- **Dissent を保存する**: 解消できない不一致を無理に収束させない
- **監査可能性**: claim / evidence / assumption / final position を追跡可能にする
- **flow efficiency**: 全 finding へ常時 deliberation を実行しない
- **後方互換**: Phase 0〜3 では production WF-00〜07 の裁定挙動を変更しない
- **プライバシー / 再現性**: hidden CoT / raw session transcript を契約入力にしない

## Considered Options

### Option A: C-2 の複数 Reviewer を増やすだけ

Reviewer 数を増やし、最終的に既存の集約または Human 判断へ渡す。

**Pros**:
- 現行構造をほぼ変えない
- 実装が単純

**Cons**:
- 不一致の原因を構造化しない
- Reviewer 同士の反証が起きない
- Reviewer 数を増やすほど token / latency が増える
- 多数意見が暗黙に強く見える

**Decision**: 不採用。追加 Reviewer は必要に応じて使うが、本課題の解決策とはしない。

### Option B: Majority vote / confidence-weighted vote

Reviewer verdict の多数決または confidence weight で結論を決める。

**Pros**:
- 自動集約しやすい
- UI が単純

**Cons**:
- consensus は correctness を保証しない
- critical singleton や minority evidence を落としうる
- model 間の相関が高い場合、票数は独立証拠にならない
- C-3 / Arbiter と競合する新しい decision authority になる

**Decision**: 不採用。

### Option C: LLM Chairman / Judge を追加する

複数 Reviewer の出力を別 LLM が読んで最終 verdict を決める。

**Pros**:
- 自然言語の不一致をまとめやすい
- 実装例が多い

**Cons**:
- deterministic Arbiter と責務重複
- Human C-3 を実質的に弱める可能性
- Judge 自身の誤判定・prompt drift・model drift が新しい failure mode になる
- #910 の calibration 対象とは別に、承認前 Judge という新しい信頼境界を作る

**Decision**: 不採用。

### Option D: Selective Plan Deliberation

C-2 の independent review 後、deterministic selector が material disagreement の候補だけを抽出し、必要なものだけ匿名化した challenge を 1 ラウンド実行する。Deliberation は verdict を出さず、final positions / unresolved / evidence needed / Human decisions を出力する。

**Pros**:
- existing C-2 / Arbiter / C-3 を維持できる
- disagreement の理由を構造化できる
- minority evidence を保持できる
- selective 実行により flow cost を制御できる
- Human が「何を判断すべきか」に集中できる

**Cons**:
- artifact / provenance が増える
- cross-examination 自体の token / latency が増える
- challenge prompt の品質が悪いと同調圧力または人工的な反対意見を生む
- selector の誤検出 / 見逃しを評価する必要がある

**Decision**: 採用。

## Decision

PlanGate に **Plan Deliberation Protocol** を、C-2 と C-3 の間に置く **additive / selective な disagreement clarification layer** として導入する。

### 1. Responsibility model

| Layer | Owns | Does not own |
| --- | --- | --- |
| B-2 / Plan Author | alternatives / selected approach / plan | review verdict |
| C-1 | self review / plan package の自己検査 | cross-review synthesis |
| C-2 | independent findings / source positions / evidence | final governance decision |
| **Plan Deliberation** | challenge / counter-evidence / final positions / unresolved / evidence needed | approval / block / merge |
| ai-loop Arbiter | deterministic adjudication | semantic debate / governance decision |
| C-3 | Human plan approval | finding generation |
| Exec / Verify | approved plan の実行 / verification evidence | plan approval |
| C-4 | Human PR approval / merge | plan deliberation |

責務を次の式で固定する。

```text
C-2 != Deliberation != Arbiter != C-3
```

より具体的には:

```text
C-2          = Discover / Critique
Deliberation = Challenge / Clarify disagreement
Arbiter      = Deterministic adjudication
C-3          = Human governance decision
```

### 2. Placement

production plan review の基本位置は次とする。

```text
PBI / Requirements
      ↓
Plan / Alternatives
      ↓
C-1
      ↓
C-2 independent review
      ↓
Deliberation Selector
      ↓
[eligible only] Plan Deliberation
      ↓
C-3 decision brief
      ↓
Human C-3
      ↓
Exec
```

Phase 0〜3 では selector は shadow mode とし、C-3 input / verdict / Arbiter input を変更しない。

### 3. Independent-first invariant

Deliberation の前提となる initial position は、他 Reviewer の結論を見せずに生成する。

ai-loop W チェックに既に存在する Model A / Model B の blind-first 方針を、Plan Deliberation の設計原則として再利用する。

Cross Examination が導入された後も、challenge は **initial position が固定された後**にのみ実行する。

### 4. Challenge invariant

challenge が扱う論点は、最低限次に限定する。

- factual error
- wrong assumption
- missing constraint
- counter evidence
- incompatible approach / fix

次は position 変更理由として扱わない。

- 他 Reviewer の人数
- 多数派であること
- model confidence の大小だけ
- authority / persona
- 「念のため反対する」のような根拠のない dissent

**人工的に dissent を作らない。存在する dissent を保存する。**

### 5. Outcome invariant

Deliberation は approval verdict を持たない。

最低限の outcome status:

- `converged`: challenge 後に material disagreement が解消
- `split`: material disagreement が残存
- `insufficient_evidence`: 結論に必要な証拠が不足

次の語彙は Deliberation outcome として使用しない。

- `APPROVED`
- `REJECTED`
- `AUTO_APPROVED`
- `HUMAN_ESCALATED`
- `BLOCKED`
- `MERGE_READY`
- `MERGED`

これらは既存 gate / Arbiter / delivery layer の責務である。

### 6. Consensus / majority invariant

```text
agreement != truth
single != noise
consensus != confirmed
majority != approval
```

特に、critical / security / approval-boundary に関わる singleton finding は、他 Reviewer の非同意や多数決だけを理由に降格・抑制しない。

### 7. Dissent preservation

challenge 後も意見が割れる場合は `split` として残し、最低限以下を Human へ渡せる形にする。

- agreed points
- disputed points
- each final position
- evidence refs
- unresolved assumptions
- evidence needed
- explicit Human decisions required
- falsification / replan candidate

Human が判断した後にのみ、既存の approval / execution contract へ進む。

### 8. Failure / safety semantics

#### Reviewer / provider unavailable

外部 Reviewer が unavailable の場合は、既存 `external-reviewer-interface.md` §10 の規約に従い、実行不可理由・代替観点・未充足リスクを記録する。

unavailable を:

- finding 0 件
- agreement
- convergence

のいずれにも読み替えない。

#### Partial C-2

期待した lane / reviewer の一部しか実行されていない場合、参加者不足を理由に `converged` としない。limitations を保持し、必要に応じて `insufficient_evidence` または Human decision material とする。

#### Stale plan

Deliberation artifact は対象 plan identity に束縛する。

新しい hash algorithm / competing SSoT は作らず、既存 Plan Package / C-3' contract が所有する `plan_hash` / plan identity を参照する。

current plan と一致しない deliberation artifact は **current C-3 の判断材料として valid 扱いしない**。再利用する場合は current plan で再レビュー / 再生成する。

#### Deliberation unavailable

Phase 4 以降で Deliberation 実行自体が unavailable の場合も、未実行を `converged` としない。

初期 rollout では Deliberation は opt-in / selective のため、未実行で既存 C-2 → C-3 経路へ戻すこと自体は許容できるが、その場合は「Deliberation が実行された」と記録しない。

### 9. Data / privacy boundary

保存対象:

- reviewer / lane identity
- claim
- concise rationale summary
- evidence refs
- explicit assumptions
- challenge statement
- final position
- changed / unchanged とその公開可能な理由
- limitations

保存しないもの:

- hidden chain-of-thought
- raw reasoning transcript
- secret-bearing session transcript
- provider 内部状態

Deliberation は監査可能な **結論・根拠・証拠**を扱い、私的な推論過程を contract にしない。

### 10. River Review との境界

PlanGate と River Review は同じ deliberation 原則を共有できるが、decision boundary が異なる。

| System | Deliberation target | Main question |
| --- | --- | --- |
| **PlanGate** | requirements / plan / design / approach | 実装前に、どの前提・設計・リスク判断を Human が承認すべきか |
| **River Review** | implementation findings / review claims | 実装後に、その finding が証拠上成立するか・何が unresolved か |

PlanGate は River Review の finding adjudication logic を重複実装しない。
River Review は PlanGate の C-3 approval semantics を所有しない。

### 11. No production behavior change in Phase 0-3

Phase 0〜3:

1. ADR
2. Experimental sidecar contract
3. C-2 source position provenance
4. deterministic selector shadow mode

では、次を変更しない。

- production WF-00〜07 の phase transition
- C-3 approval requirement
- C-4 / merge ownership
- ai-loop Arbiter decision table
- `AUTO_APPROVED | HUMAN_ESCALATED | BLOCKED` の terminal semantics
- existing C-2 verdict
- existing review severity definition

Cross Examination 本体は shadow evaluation 後の Phase 4 で別 Issue として着手する。

## Phase 1-3 Entry Criteria

### Phase 1 — Experimental contract

着手条件:

- 本 ADR が Accepted
- approval vocabulary を sidecar に持たせない
- stale plan semantics が固定されている
- provider unavailable / partial review を convergence と扱わない

### Phase 2 — C-2 source position provenance

着手条件:

- initial position と final position を別 identity で追跡できる設計
- claim / evidence / assumption を machine-readable に参照可能
- append-only `review-external.md` の既存監査運用を壊さない
- raw CoT を保存しない

### Phase 3 — Deterministic selector shadow mode

着手条件:

- closed reason-code vocabulary
- LLM call 0
- production verdict 変更 0
- C-3 / Arbiter input 変更 0
- trigger / miss / false candidate を評価可能

Phase 3 の representative cases を確認するまで Phase 4 を開始しない。

## Consequences

### Positive

- C-2 の不一致を「票数」でなく claim / assumption / evidence の差として扱える
- Human C-3 が判断すべき論点を縮約できる
- minority evidence / unresolved risk を失いにくい
- Arbiter / Human approval との責務境界を維持できる
- Cross Examination を selective にし、常時 multi-agent 化を避けられる
- River Review と共通原則を持ちながら責務重複を避けられる

### Negative / Risks

- artifact / provenance の管理対象が増える
- Phase 4 以降は追加 agent call により token / latency が増える
- selector が material disagreement を見逃す可能性がある
- challenge prompt が弱いと、同調または無意味な反対意見を生む
- stale plan / partial reviewer の扱いを誤ると false convergence を作りうる

### Mitigations

- Phase 0〜3 は behavior change なし
- Phase 3 は shadow mode
- Cross Examination は one-round / selective から開始
- 10 件以上の representative cases で GO / MODIFY / STOP を判断
- critical disagreement の missed candidate を 0 目標で追跡
- approval-boundary regression / Arbiter bypass / stale acceptance は 0 を rollout 条件とする

## Non-goals

- Council of High Intelligence への runtime dependency
- historical persona
- 18-member panel
- forced dissent
- majority voting
- confidence-weighted approval
- LLM Chairman / new Judge / new Arbiter
- automatic C-3 approval
- automatic C-4 approval / merge
- hidden CoT / raw session transcript 保存
- Phase 0〜3 での production WF-00〜07 変更
- ai-loop W-check への即時適用
- River Review の review logic の重複実装

## ADR Numbering Note

現 main の `docs/decisions/` に実在する ADR は ADR-001 のみだが、既存 working context では:

- TASK-0981 / #981 が ADR-002 を占有する前提を記録
- TASK-0980 / #980 がその後の ADR 番号を使用する設計を記録

している。

未マージ作業との番号衝突を避けるため、本 ADR は **ADR-006** を使用する。
本 ADR は ADR 採番基盤や予約台帳そのものを新設しない。

## Related

- Parent Epic: #1351
- Phase 0 Issue: #1352
- Phase 1: #1353
- Phase 2: #1354
- Phase 3: #1355
- Harness Evolution: #869
- Run Eval: #908
- PlanGateBench: #909
- LLM Judge Calibration: #910
- C-2 reviewer contract: `.claude/rules/review-principles.md` §7-bis / §7-quater
- External Reviewer IF: `docs/ai/external-reviewer-interface.md`
- ai-loop skill: `.agents/skills/ai-loop-cycle/SKILL.md`
- ai-loop decision table: `docs/workflows/ai-loop/decision-table.md`
- Core Contract: `docs/ai/core-contract.md`
- Council reference: https://github.com/0xNyk/council-of-high-intelligence
