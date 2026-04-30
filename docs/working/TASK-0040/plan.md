# EXECUTION PLAN — TASK-0040 (PBI-116-02 / Issue #118)

> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Parent C-3 APPROVED（PR #128）/ Phase 2 戦略確定（PR #136）
> Issue: [#118 Model Profile layer 追加](https://github.com/s977043/plangate/issues/118)
> Mode: **standard**

## Goal

GPT-5.5 系の実行モデルごとの差分（reasoning effort / verbosity / context budget / tool policy / validation depth）を **`docs/ai/model-profiles.yaml`** という薄い設定層に閉じ込める。PlanGate Core はモデル非依存で維持し、4 プロファイル（gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown）を定義する。

## Constraints / Non-goals

### Constraints

- Core Contract / Gate / Artifact schema は変更しない（モデル非依存維持）
- `tool_policy` / `validation_bias` の値域は [`interface-preflight.md`](../PBI-116/interface-preflight.md) に準拠
- 既存 `schemas/` 配下のスキーマと命名衝突しない
- doc-only PBI（コード変更なし、YAML + Markdown のみ）

### Non-goals

- モデル別プロンプト全文の fork（→ PBI-116-03）
- provider 実行ランタイム改修
- eval runner 実装（→ PBI-116-05）
- Structured Outputs schema 詳細（→ PBI-116-04）
- Tool Policy の実 tool 列挙（→ PBI-116-06）

## Approach Overview

4 ステップで進める:

1. schema 定義（Markdown + JSON Schema）
2. 4 プロファイル定義（YAML）
3. mode × profile マトリクス + verbosity / context budget policy 表
4. 検証（schema-validate / リンク到達性）+ handoff

## Work Breakdown (Steps)

### Step 1: schema 定義

- **Output**: `docs/ai/model-profiles.md`（schema 仕様 Markdown）+ `schemas/model-profile.schema.json`（JSON Schema）
- **Owner**: agent
- **Risk**: 低
- 🚩 チェックポイント: schema フィールド全 9 種（family / role / reasoning_effort_by_mode / verbosity_by_phase / max_context_policy / tool_policy / validation_bias / structured_outputs / adapter）が定義され、interface-preflight.md と整合

### Step 2: 4 プロファイル定義

- **Output**: `docs/ai/model-profiles.yaml`
- **Owner**: agent
- **Risk**: 中（reasoning effort 値の妥当性）
- 🚩 チェックポイント: 4 プロファイル（gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown）が schema 準拠で定義

### Step 3: マトリクス + verbosity + context budget

- **Output**: `docs/ai/model-profiles.md` 内に 3 表追加
- **Owner**: agent
- **Risk**: 低
- 🚩 チェックポイント:
  - reasoning_effort × mode × profile の 5×4 マトリクス完備
  - verbosity_by_phase × profile の 5×4 表完備
  - context_budget_policy 3 段階定義
  - critical mode で gpt-5_mini disallow の方針明記

### Step 4: 検証 + handoff

- **Output**: `evidence/verification.md` + `handoff.md` + 子 PR
- **Owner**: agent
- **Risk**: 低
- 🚩 チェックポイント:
  - YAML が schema-validate で PASS
  - 受入基準 8 項目すべて確認
  - interface-preflight.md と整合（tool_policy / validation_bias 値域一致）

## Files / Components to Touch

### 新規作成

- `docs/ai/model-profiles.md`（schema 仕様 + マトリクス）
- `docs/ai/model-profiles.yaml`（4 プロファイル定義）
- `schemas/model-profile.schema.json`（JSON Schema）
- `docs/working/TASK-0040/evidence/verification.md`
- `docs/working/TASK-0040/handoff.md`

### 触らない（forbidden_files、PBI-116-02.yaml 準拠）

- `CLAUDE.md`, `AGENTS.md`
- `.claude/rules/**`, `.claude/commands/**`, `.claude/agents/**`
- `plugin/plangate/**`
- `bin/**`
- `.github/workflows/**`
- 既存 `schemas/*.schema.json`（model-profile.schema.json は新規追加のみ）

## Testing Strategy

### Unit
- 該当なし（doc-only）

### Integration
- **Markdown lint**: 全更新ファイルで 0 error
- **schema-validate**: `model-profiles.yaml` を `schemas/model-profile.schema.json` で validate（手動 or jsonschema cli）

### E2E
- 該当なし（実装なし）

### Edge cases
- profile に未知の値が含まれる場合の schema validation
- mode × profile マトリクスの欠損セル検出

### Verification Automation
- `python -m jsonschema -i docs/ai/model-profiles.yaml schemas/model-profile.schema.json`（または yajsv 等）
- `grep -E "^(gpt-5_5|gpt-5_5_pro|gpt-5_mini|legacy_or_unknown):"`  で 4 プロファイル存在確認

## Risks & Mitigations

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| L1 | tool_policy / validation_bias の値域が PBI-116-06 と乖離 | medium | interface-preflight.md 準拠、plan.md で値域明示 |
| L2 | reasoning effort × mode マトリクス値が実モデル挙動と乖離 | medium | 設計段階で確定、検証は PBI-116-05 で |
| L3 | schema YAML が既存 schemas/ と命名衝突 | low | `model-profile.schema.json` で命名独立 |
| L4 | プロファイル定義が大きくなり保守負荷増 | low | 4 プロファイルに限定、追加は別 PBI |

## Questions / Unknowns

- Q1: schema は YAML / JSON どちらで本体定義？
  - A1: YAML（人間可読性）+ JSON Schema 併設
- Q2: `xhigh` reasoning_effort 採用？
  - A2: schema では `reasoning_effort` を単一 enum 値（low / medium / high / xhigh）として定義。critical mode で `xhigh` を許容したいプロファイルは `recommended_effort: high` + `allowed_efforts: [high, xhigh]` のように構造化（C-2 EX-02-01 対応）
- Q3: gpt-5_mini の critical mode disallow 強制方法？
  - A3: `disallowed_modes: [critical]` フィールド追加

## Mode判定

**モード**: **standard**

判定根拠:
- 変更ファイル数: 3-5（新規のみ、既存ファイル変更なし）→ standard
- 受入基準数: 8 → standard
- 変更種別: doc-only（YAML + Markdown + JSON Schema） → light/standard
- リスク: 中（schema 設計の妥当性）→ standard
- ロールバック: PR revert で容易 → standard
- **最終判定**: **standard**（子 PBI YAML PBI-116-02 mode と整合）

## Stop rules

各 Step で以下が発生した場合は即停止し、ユーザー確認を求める:

| Step | Stop trigger |
|------|------------|
| Step 1 | schema フィールドが interface-preflight.md と乖離 |
| Step 2 | プロファイル値が plan.md 仕様から逸脱 |
| Step 3 | mode × profile マトリクスに矛盾発生 |
| Step 4 | schema-validate が FAIL、または受入基準 8 項目に未達 |
