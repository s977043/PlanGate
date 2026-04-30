# EXECUTION PLAN — TASK-0043 (PBI-116-03 / Issue #119)

> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / **Phase 3** / Mode: **high-risk**
> Depends on: PBI-116-01 ✅ + PBI-116-02 ✅

## Goal

Prompt を **Core / Phase / Risk / Model Adapter の 4 層** で組み立てる設計を `docs/ai/prompt-assembly.md` に確立する。Core Contract（Phase 1）と Model Profile（Phase 2）を統合する設計層。**doc-only**（擬似コード or skeleton のみ、本格実装は別 PBI）。

## Constraints / Non-goals

### Constraints

- 既存 `.claude/commands/ai-dev-workflow.md` 等は **変更しない**（参照のみ）
- Core Contract / Model Profile schema は **変更しない**（Phase 1 / 2 の成果物）
- 実装言語選択（TypeScript / shell / Python）は本 PBI scope 外
- doc-only PBI

### Non-goals

- 完全 prompt fork
- Provider runtime 改修
- eval runner 実装（→ PBI-116-05）
- 実 AI API 呼び出し統合
- Hook 実装

## Approach Overview

3 ステップで進める:

1. `docs/ai/prompt-assembly.md` 本体作成（4 層定義 + 責務境界 + 解決ロジック + Core Contract v1 互換説明）
2. `docs/ai/contracts/`（phase_contract）と `docs/ai/adapters/`（model_adapter）の skeleton 作成（最低限の例）
3. 検証 + handoff

### 上位概念との接続（C-2 EX-03-05 対応）

Prompt Assembly の 4 層は、PBI-116-06 [`responsibility-boundary.md`](../../ai/responsibility-boundary.md) で定義された **Prompt layer 内のサブ構造**。Hook / Tool Policy / CLI validate は別 layer であり、本 PBI の責務範囲外。`prompt-assembly.md` で接続関係を明記する（PBI-116-05 Eval で検証対象を切り出しやすくする）。

## Work Breakdown (Steps)

### Step 1: prompt-assembly.md 本体

- **Output**: `docs/ai/prompt-assembly.md`
- **Risk**: 中（4 層化の妥当性）
- 🚩 チェックポイント:
  - 4 層の責務境界明示
  - 7 phase 各々の phase_contract サマリ
  - 4 model_adapter（outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown）サマリ
  - 解決ロジック（TypeScript 型定義 + 擬似コード）
  - モデル別 prompt full fork を避ける方針明示

### Step 2: phase_contract / model_adapter skeleton

- **Output**: `docs/ai/contracts/{classify,plan,approve-wait,execute,review,verify,handoff}.md` + `docs/ai/adapters/{outcome_first,outcome_first_strict,explicit_short,legacy_or_unknown}.md`
- **Risk**: 低
- 🚩 チェックポイント:
  - 7 phase × 1 ファイル（Goal / Success criteria / Stop rules を簡潔記述）
  - 4 adapter × 1 ファイル（Style / Verbosity / Output discipline を記述）
  - 各ファイル 50 行以下（過剰肥大化防止）

### Step 3: 検証 + handoff

- **Output**: `evidence/verification.md` + `handoff.md` + 子 PR
- **Risk**: 低
- 🚩 チェックポイント:
  - 受入基準 7 項目すべて確認
  - Phase 1 / Phase 2 成果物との整合性確認
  - markdown lint 0 error
  - リンク到達性

## Files / Components to Touch

### 新規作成

- `docs/ai/prompt-assembly.md`
- `docs/ai/contracts/classify.md`
- `docs/ai/contracts/plan.md`
- `docs/ai/contracts/approve-wait.md`
- `docs/ai/contracts/execute.md`
- `docs/ai/contracts/review.md`
- `docs/ai/contracts/verify.md`
- `docs/ai/contracts/handoff.md`
- `docs/ai/adapters/outcome_first.md`
- `docs/ai/adapters/outcome_first_strict.md`
- `docs/ai/adapters/explicit_short.md`
- `docs/ai/adapters/legacy_or_unknown.md`
- `docs/working/TASK-0043/evidence/verification.md`
- `docs/working/TASK-0043/handoff.md`

### 触らない（forbidden_files、PBI-116-03.yaml 準拠）

- CLAUDE.md, AGENTS.md
- `.claude/rules/**`, `.claude/commands/**`, `.claude/agents/**`
- `plugin/plangate/**`
- `.github/workflows/**`
- `docs/ai/model-profiles.yaml`（Phase 2 成果、参照のみ）

## Testing Strategy

### Unit / Integration / E2E

- 該当なし（doc-only）
- markdown lint 0 error

### Edge cases

- 4 層の責務重複（base/phase の境界曖昧）
- adapter enum と Phase 2 schema の不一致
- phase_contract が未定義 phase で参照される

### Verification Automation

- `grep -E "^### " docs/ai/prompt-assembly.md` で 4 層 + 7 phase + 4 adapter が記載されているか
- `wc -l docs/ai/prompt-assembly.md docs/ai/contracts/*.md docs/ai/adapters/*.md` で総行数（目安 700 行以下、各 50 行以下）
- `ls docs/ai/contracts/*.md | wc -l` = 7
- `ls docs/ai/adapters/*.md | wc -l` = 4
- `grep -E "outcome_first|outcome_first_strict|explicit_short|legacy_or_unknown" docs/ai/prompt-assembly.md` で adapter enum 整合確認

## Risks & Mitigations

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| L1 | 4 層化が複雑すぎて保守困難 | high | 各層 100 行以下、責務境界明確 |
| L2 | base / phase の境界曖昧 | medium | core-contract.md 不変、phase_contract は phase 固有のみ |
| L3 | model_adapter が Phase 2 と乖離 | medium | adapter enum を model-profile.schema.json と一致 |
| L4 | doc-only に収まらず実装に踏み込む | medium | 「擬似コード or skeleton のみ」明記、Stop rule 設定 |
| L5 | Plugin 配布版への適用後回し | low | docs/ai/* 一般化、Plugin 同期は別 PBI |

## Questions / Unknowns

- Q1: 解決ロジックの形式 → Markdown（TS 型定義 + 擬似コード）
- Q2: phase 数 → 7（classify/plan/approve-wait/execute/review/verify/handoff）
- Q3: adapter enum → Phase 2 schema と完全一致

## Mode判定

**モード**: **high-risk**

判定根拠:
- 変更ファイル数: 14（全新規）→ high-risk
- 受入基準数: 7 → standard / high-risk
- 変更種別: アーキテクチャ層追加（4 層構造）→ high-risk
- リスク: 高（Phase 1 / 2 を統合する設計層） → high-risk
- ロールバック: PR revert 容易 → standard
- **最終判定**: **high-risk**（子 PBI YAML PBI-116-03 mode と整合）

## Stop rules

| Step | Stop trigger |
|------|------------|
| Step 1 | 4 層の責務境界が一意定義不能 |
| Step 2 | adapter enum が Phase 2 schema と乖離 |
| Step 3 | 受入基準 7 項目に未達 or markdown lint FAIL |
