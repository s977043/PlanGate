# EXECUTION PLAN — TASK-0041 (PBI-116-06 / Issue #122)

> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Mode: **standard**
> Interface preflight 準拠

## Goal

PlanGate でモデル判断とプログラム強制の **責務境界** を整理し、不変条件は Hook / CLI で決定論的にブロックできる方針を **境界定義として** 確立する（実装は別 PBI）。

## Constraints / Non-goals

### Constraints

- 実 Hook 実装には踏み込まない（境界定義のみ）
- `tool_policy` 値域は PBI-116-02 (Model Profile) で定義済を参照
- Core Contract / Gate / 既存運用ルールは変更しない
- doc-only PBI

### Non-goals

- Hook 実装本体（別 PBI）
- GitHub Actions 連携
- Provider runtime 改修
- C-3 / C-4 人間承認フロー削除

## Approach Overview

3 つの新規ドキュメントで境界を整理:

1. `responsibility-boundary.md`: 4 layer（Prompt / Tool Policy / Hook / CLI）の責務境界
2. `tool-policy.md`: phase 別 allowed tools + tool_policy 値ごとの射影
3. `hook-enforcement.md`: Hook で強制すべき不変条件 + validation_bias: strict 時の追加条件

## Work Breakdown (Steps)

### Step 1: responsibility-boundary.md

- **Output**: `docs/ai/responsibility-boundary.md`
- **Owner**: agent
- **Risk**: 低
- 🚩 チェックポイント: 4 layer × 責務マトリクス完備、判断基準（モデル判断 vs runtime 強制）の境界明示

### Step 2: tool-policy.md

- **Output**: `docs/ai/tool-policy.md`
- **Owner**: agent
- **Risk**: 中（PBI-116-02 値域との整合）
- 🚩 チェックポイント:
  - 5 phase × allowed tools 表（plan / approve-wait / exec / review / handoff）
  - `tool_policy: narrow / allowed_tools_by_phase / expanded` 各値の射影
  - PBI-116-02 の Model Profile schema と整合（interface-preflight 準拠）

### Step 3: hook-enforcement.md

- **Output**: `docs/ai/hook-enforcement.md`
- **Owner**: agent
- **Risk**: 中（既存 hooks との衝突）
- 🚩 チェックポイント:
  - 不変条件 6 件以上（plan なし production 編集ブロック / C-3 承認なし exec ブロック / plan_hash 改竄検知 / test-cases なし V-1 ブロック / 検証ログなし PR ブロック / scope 外編集検知）
  - `validation_bias: strict` 時の追加条件 3 件以上
  - 既存 `.claude/settings.json` hooks との関係明示

### Step 4: 検証 + handoff

- **Output**: `evidence/verification.md` + `handoff.md`
- **Owner**: agent
- **Risk**: 低
- 🚩 チェックポイント:
  - 受入基準 7 項目すべて確認
  - interface-preflight.md と整合（tool_policy 値域）
  - PBI-116-02 model-profiles.yaml（マージされていれば）と clip relation 確認

## Files / Components to Touch

### 新規作成

- `docs/ai/responsibility-boundary.md`
- `docs/ai/tool-policy.md`
- `docs/ai/hook-enforcement.md`
- `docs/working/TASK-0041/evidence/verification.md`
- `docs/working/TASK-0041/handoff.md`

### 触らない（forbidden_files、PBI-116-06.yaml 準拠）

- CLAUDE.md, AGENTS.md
- `.claude/settings.json`, `.claude/settings.local.json`, `.claude/hooks/**`
- `bin/**`, `.github/workflows/**`
- `plugin/plangate/**`

## Testing Strategy

### Unit
- 該当なし（doc-only）

### Integration
- markdown lint 0 error
- リンク到達性

### E2E
- 該当なし

### Edge cases
- 既存 `.claude/settings.json` の hooks との重複・衝突
- `tool_policy: narrow` で特定 tool が必要な phase との矛盾
- `validation_bias: strict` で過剰な block

### Verification Automation
- `grep -rE "tool_policy|validation_bias" docs/ai/tool-policy.md docs/ai/hook-enforcement.md` で interface-preflight 準拠確認
- `wc -l docs/ai/{responsibility-boundary,tool-policy,hook-enforcement}.md` で過剰肥大化を防止（合計 300 行以下目安）

## Risks & Mitigations

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| L1 | tool_policy 値域が PBI-116-02 と乖離 | medium | interface-preflight.md 準拠、PBI-116-02 完了前提 |
| L2 | Hook enforcement 候補が既存と衝突 | low | 既存 `.claude/settings.json` を参照確認 |
| L3 | 境界定義のみという制約に違反、実装に踏み込み | medium | plan.md で「実装禁止」明記、Stop rule 設定 |
| L4 | Plugin 配布版との乖離 | medium | Plugin 限定 rules（completion-gate 等）と本 PBI（ai/* 一般化）の役割明示 |

## Questions / Unknowns

- Q1: Hook 実装方法 → 本 PBI 範囲外
- Q2: validation_bias: strict の追加条件数 → 最低 3 件
- Q3: Plugin 限定 rules との関係 → 共存（一般化 vs 配布形態固有）

## Mode判定

**モード**: **standard**

判定根拠:
- 変更ファイル数: 5（全新規、既存変更なし）→ standard
- 受入基準数: 7 → standard
- 変更種別: doc-only（boundary 定義 + マッピング） → standard
- リスク: 中（PBI-116-02 接続）→ standard
- ロールバック: PR revert 容易 → standard
- **最終判定**: **standard**

## Stop rules

| Step | Stop trigger |
|------|------------|
| Step 1 | 責務境界の 4 layer が一意定義不能 |
| Step 2 | tool_policy 値域が PBI-116-02 から乖離 |
| Step 3 | Hook 候補が既存 hooks と直接衝突 |
| Step 4 | 受入基準 7 項目に未達 or interface-preflight.md と不整合 |
