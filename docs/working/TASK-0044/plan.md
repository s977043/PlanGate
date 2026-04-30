# EXECUTION PLAN — TASK-0044 (PBI-116-05 / Issue #121)

> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / **Phase 4 / 最終子 PBI** / Mode: **standard**

## Goal

PlanGate のモデル移行を安全にする **Eval cases と評価観点** を `docs/ai/eval-plan.md` + `docs/ai/eval-cases/*.md`（最低 7 件）+ `eval-comparison-template.md` に確立する。**doc-only**（実 eval runner は別 PBI）。

## Constraints / Non-goals

### Constraints

- 既存 `core-contract.md` / `model-profiles.yaml` / `prompt-assembly.md` 等は **変更しない**
- 既存 `schemas/` は変更しない
- doc-only PBI

### Non-goals

- 自動 eval runner 実装
- 外部ダッシュボード
- 全モデル・全 provider 網羅
- CI/CD 統合
- 実運用ログ収集基盤

## Approach Overview

3 ステップ:

1. `docs/ai/eval-plan.md` 本体（8 観点 + 合格基準 + Model Profile 変更時チェックリスト + 4 層独立検証）
2. `docs/ai/eval-cases/*.md` 7 件 + `eval-comparison-template.md`
3. 検証 + handoff

## Work Breakdown (Steps)

### Step 1: eval-plan.md 本体

- **Output**: `docs/ai/eval-plan.md`
- **Risk**: 中
- 🚩 チェックポイント:
  - 8 観点表（trigger / 検出方法 / 合否基準）
  - release blocker 2 件（verification honesty / scope discipline）
  - Model Profile 変更時 checklist
  - 4 層独立検証方針（Phase 3 引き継ぎ）
  - schema 準拠率 95% 基準（Phase 2 PBI-116-04 引き継ぎ）

### Step 2: eval-cases/*.md + eval-comparison-template.md

- **Output**: 7 eval-cases ファイル + 1 比較表テンプレ
- **Risk**: 低
- 🚩 チェックポイント:
  - 各 eval-cases ファイル 50 行以下、Trigger / Detection / Pass/Fail criteria
  - eval-comparison-template.md は構造化テーブル + 記入例

### Step 3: 検証 + handoff

- **Output**: `evidence/verification.md` + `handoff.md`
- **Risk**: 低
- 🚩 チェックポイント: 受入基準 8 項目すべて確認

## Files / Components to Touch

### 新規作成

- `docs/ai/eval-plan.md`
- `docs/ai/eval-cases/scope-discipline.md`
- `docs/ai/eval-cases/approval-gate.md`
- `docs/ai/eval-cases/ac-coverage.md`
- `docs/ai/eval-cases/verification-honesty.md`
- `docs/ai/eval-cases/stop-behavior.md`
- `docs/ai/eval-cases/tool-overuse.md`
- `docs/ai/eval-cases/format-adherence.md`
- `docs/ai/eval-cases/latency-cost.md`（8 観点目、C-2 Gemini 対応）
- `docs/ai/eval-comparison-template.md`
- `docs/working/TASK-0044/evidence/verification.md`
- `docs/working/TASK-0044/handoff.md`

### 触らない（forbidden_files）

- CLAUDE.md, AGENTS.md
- `.claude/rules/**`, `.claude/commands/**`, `.claude/agents/**`
- `plugin/plangate/**`
- 既存 `docs/ai/*.md`（Phase 1〜3 成果物、参照のみ）
- 既存 `schemas/*.schema.json`
- `.github/workflows/**`

## Testing Strategy

- markdown lint
- ファイル数: eval-cases 7 + eval-plan + comparison-template = 9 件
- 各ファイル行数（過剰肥大化防止）
- 8 観点 grep 確認
- release blocker 2 件 grep 確認

### Verification Automation

- `ls docs/ai/eval-cases/*.md | wc -l` = **8**（8 観点と一致、C-2 Gemini 対応）
- `grep -E "scope discipline|approval discipline|AC coverage|verification honesty|stop behavior|tool overuse|format adherence|latency" docs/ai/eval-plan.md` で 8 観点
- `grep -E "release blocker" docs/ai/eval-plan.md` で blocker 基準
- `wc -l docs/ai/eval-plan.md docs/ai/eval-cases/*.md docs/ai/eval-comparison-template.md` で総行数（500 行以下目安）

## Risks & Mitigations

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| L1 | Eval 観点 8 件が冗長 | medium | 各ファイル 50 行以下、簡潔記述 |
| L2 | release blocker 基準が厳しすぎ | medium | 2 観点に限定、他は WARN |
| L3 | 4 層独立検証が実装困難 | low | 方針のみ、実装は別 PBI |
| L4 | schema 準拠率 95% が非現実的 | low | 暫定値、調整は別 PBI |

## Mode判定

**モード**: **standard**

判定根拠: 9 ファイル新規 doc-only、リスク中、ロールバック容易 → standard

## Stop rules

| Step | Stop trigger |
|------|------------|
| Step 1 | release blocker 基準が一意定義不能 |
| Step 2 | eval-cases ファイル数が 7 件未達 |
| Step 3 | AC 8 項目に未達 |
