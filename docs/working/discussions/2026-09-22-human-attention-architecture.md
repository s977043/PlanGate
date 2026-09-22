# Human Attention Architecture — ai-loop V2 Canon Gap Analysis

> Tracking: #1343 / WS0 #1344
> Empirical input: s977043/river-review#2368

## 1. Decision

Human Attention Architecture は新しい subsystem / artifact / Judge / Gate として作らない。

ai-loop V2 North Star が既に持つ以下の原則を、Human-facing projection の観点で接続する。

- Evidence before judgment
- Human-owned authority
- Context selection / retrieval / compression / handoff
- Delivery / Evolution responsibility separation
- deterministic verifier first
- human intervention / decision-wait measurement
- hidden CoT / raw transcript non-goal
- artifact budget

追加するのは次の横断原則だけ。

> **Machine complexity should not become Human complexity.**

```text
Think deeply, materialize selectively.
Visibility is complete, attention is selective.
Compress before escalating.
Escalate decisions, not process logs.
```

## 2. Gap matrix

| Concern | Existing V2 canon | Gap | Decision |
| --- | --- | --- | --- |
| Human authority | North Star §3 / §15 | なし | 既存境界を維持 |
| Evidence before judgment | §6 | なし | Human surfaceもEvidence refを保持 |
| Context compression | §11 | Human向け出力との関係が未明示 | attention原則へ接続 |
| Human intervention | §14 / §18 | 介入量はあるが「読解量」概念は弱い | #1349で測定契約を定義 |
| Decision waiting | §18 | 既存 | Time to Human Requiredとの関係を#1349で整理 |
| Human-facing projection | 明示ownerなし | **gap** | layer-specific Decision Surfaceを採用 |
| Compression safety | 明示なし | **gap** | Compression != Suppression |
| Visibility guarantee | 暗黙 | **gap** | Visibility complete / Attention selective |
| Raw reasoning | §19 non-goal | なし | hidden CoT / transcriptをHuman surfaceへ要求しない |
| Artifact budget | Phase 0 migration §6 | なし | Human Attention専用artifactを追加しない |

## 3. Ownership matrix

| Layer | Human-facing surface | Existing SSoT / owner | This initiative owns |
| --- | --- | --- | --- |
| River Review | Review Decision Surface | Review Artifact / Coverage / Resolution | deterministic projection |
| ai-loop V2 | Loop Decision Surface | RunState / Outcome / Stop / Verdict / Evidence | deterministic projection |
| ai-dev | PR_CREATED Handoff Surface | current ai-dev workflow / verification evidence | handoff presentation |
| PlanGate Plan | Plan Decision Surface | Plan / Plan Design Principles | generation presentation after #1337 |
| Evolution | Promotion Surface | Improvement Candidate / Evaluation / PromotionDecision | promotion projection |

原則:

```text
Projection != Judgment
Compression != Suppression
Summary != SSoT
```

## 4. Why no new artifact

Human Decision Surface は既存状態から再生成できる projection であり、独立した authoritative state を持つ必要がない。

新artifactを作ると:

- SSoTが二重化する
- state同期が必要になる
- projection内容が古くなる
- artifact budgetを消費する
- Human-facing concernがDecision Engineへ侵入する

ため、初期設計では採用しない。

## 5. Layer-specific rollout

### WS1 — River Review

先行実証。

検証すること:

- attentionを減らしても重要finding visibilityを落とさない
- coverage uncertaintyを隠さない
- summaryがJudge化しない

### WS2 — ai-loop V2

既存4軸:

- Lifecycle State
- Terminal Outcome
- Stop Reason
- Policy Verdict

とVerification / Failure / EvidenceをHumanへ投影する。

新stateは作らない。

### WS3 — ai-dev

`PR_CREATED` terminal contractは変更せず、handoff presentationだけを改善する。

### WS4 — PlanGate Plan

#1337のpaired評価結果固定後だけ着手する。

既存candidateを汚染しない。

### WS5 — Evolution

#869のCandidate / Evaluation / PromotionDecisionを再利用し、Human向けPromotion Surfaceだけを追加する。

## 6. Safety invariants

Human Attention削減によって以下を失ってはならない。

- blocking / critical material issue
- unresolved uncertainty
- incomplete verification / coverage
- Human-owned decision requirement
- evidence provenance
- rejected / inconclusive state
- rollback / stop information

固定文字数やtop-Nだけを唯一のHuman surfaceにしない。

## 7. Measurement boundary

Human Attentionを単独KPIにしない。

最低限:

```text
Human Attention decreases
AND
Correctness / Safety >= baseline
AND
Critical visibility >= baseline
AND
no material provenance / coverage regression
```

共通metric glossaryは #1349 がowner。

V2 RunEvidenceの時刻fieldは #1285 の責務とし、WS0ではschemaを変更しない。

## 8. Dependency policy

```text
#1344 Canon
   ↓
River Review #2368 empirical proof
   ↓
#1345 ai-loop V2
   ├─> #1346 ai-dev handoff
   └─> #1348 Evolution

#1337 result fixed
   +
River Review evidence
   ↓
#1347 Plan Decision Surface
```

## 9. Non-goals

- Legacy ai-loop変更
- ai-dev public contract変更
- new Judge / Gate
- Human Attention専用DB / memory
- hidden CoT保存
- raw transcript表示
- Human authority削減
- auto merge / auto promotion
- fixed character limit
- attentionSecondsだけの最適化

## 10. Review conclusion

Human Attention Architecture は ai-loop V2 の既存North Starを置換しない。

**既存のEvidence / authority / responsibility separationをHuman-facing projectionまで貫通させる横断原則**として扱うのが最小で安全な設計である。
