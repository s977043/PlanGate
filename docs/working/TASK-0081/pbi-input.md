---
task_id: TASK-0081
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0081

> TASK-0071 S4: 責務 4 分類（AI / Human / CI / Workflow-owned）rules 正本化
> 起源: TASK-0071 D-1 第3スライス / direction-codex-gemini.md C4 / 本セッション
> 通底の「AI 不可侵領域（settings/merge）」の正式責務分界

## Context / Why

本セッションを通じ「AI が触れない領域（settings 自己改変 / merge）」が
繰り返し摩擦になり、Codex×Gemini 方針統合（direction-codex-gemini.md C4）で
**責務 4 分類の正式化**が合意された。TASK-0077（AC-4）/ TASK-0080
（settings-wiring-contract の責務分離表）でも個別に責務境界を定義したが、
**横断する単一の rules 正本が無い**。散在した責務分界を 1 つの正本に集約し、
今後の PBI が一貫して参照できるようにする（TASK-0071 D-1 S4）。

## What — Scope

### In scope

- `.claude/rules/responsibility-classes.md`（新規・正本）を作成:
  - **AI-owned**: 実装 / テスト / 検証 / PR 準備 / manual patch・script 生成
  - **Human-owned**: self-mod 対象ファイル適用 / C-3・C-4 / merge / 権限操作
  - **CI-owned**: drift 検出 / 必須 contract 検証 / 未適用 manual action 検出
  - **Workflow-owned**: handoff artifact / 未完了 manual action の追跡 / DoD
  - 各クラスの境界・例（settings 適用=Human、settings-drift=CI 等）・
    既存ルール（hybrid-architecture Rule1-5 / orchestrator-mode / working-context
    タスクロック / mode-classification lite_eligible）との対応
- `.claude/rules/hybrid-architecture.md` から本正本を参照（重複させず参照）
- 既存の個別責務記述（TASK-0077 AC-4 / settings-wiring-contract 責務分離表）
  との整合確認（矛盾なし・本正本が上位集約）

### Out of scope

- 既存ルールの責務記述の書き換え（本 PBI は集約正本の新設＋参照付け。
  個別ルールは参照を足すのみで本文改変しない）
- TASK-0071 S3（EH-3 メンテモード）
- 強制機構の実装（分類の正本化のみ・強制は各既存機構が担う）

## Acceptance Criteria

- [ ] AC-1: `.claude/rules/responsibility-classes.md` が4分類（AI/Human/CI/Workflow-owned）の境界・例を定義する正本として存在
- [ ] AC-2: 各クラスに具体例（settings適用=Human / settings-drift=CI / handoff=Workflow / 実装=AI 等）が示される
- [ ] AC-3: 既存ルール（hybrid-architecture / orchestrator-mode / working-context タスクロック / mode-classification）との対応が明記される
- [ ] AC-4: hybrid-architecture.md から本正本への参照が追加される（重複定義なし）
- [ ] AC-5: 既存の個別責務記述（TASK-0077 AC-4 / settings-wiring-contract）と矛盾しない（整合確認）
- [ ] AC-6: 既存ルール本文の責務記述を改変しない（additive・参照付けのみ）。hook テスト/doc 整合 回帰なし

## Notes from Refinement

- direction-codex-gemini.md C4 が本分類の出典（Codex×Gemini 合意）
- TASK-0080 settings-wiring-contract の責務分離表（CI=reference/doctor=実体）は
  本正本の CI-owned / Workflow-owned の具体適用例
- merge=Human-owned 固定（sockpuppet 禁止と一貫）

## Estimation Evidence

**Risks**: rules 正本新設。既存責務記述と矛盾すると混乱 → AC-5 整合確認・
additive（既存本文改変なし）で抑制
**Unknowns**: なし（分類は direction-codex-gemini.md で確定）
**Assumptions**: docs/rules のみ・強制機構変更なし。Mode 想定: standard
