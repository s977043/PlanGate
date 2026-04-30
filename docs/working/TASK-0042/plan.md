# EXECUTION PLAN — TASK-0042 (PBI-116-04 / Issue #120)

> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Mode: **standard**

## Goal

PlanGate の機械判定向け成果物（mode classification / review results / acceptance / handoff summary）を **Structured Outputs / JSON Schema** に寄せる方針を確立する。新規 schema 4 件と境界定義ドキュメントを整備（実装は本 PBI scope 外）。

## Constraints / Non-goals

### Constraints

- **既存 `schemas/*.schema.json` 全 12 件** は変更しない（c3-approval / c4-approval / handoff / pbi-input / plan / **review-external** / **review-self** / run-event / status / **test-cases** / todo + README.md。C-2 EX-04-01 対応で 5 件 → 12 件に拡張）
- JSON Schema 2020-12 を採用（既存と統一）
- doc-only PBI（実装コード変更なし）
- 02/06 と完全独立（tool_policy / validation_bias は参照しない）

### Non-goals

- 全 Markdown 成果物の JSON 化
- 実 API 統合
- eval runner 実装（→ PBI-116-05）
- 既存成果物の全移行

## Approach Overview

5 つの新規ファイルで対応:

1. `docs/ai/structured-outputs.md`: 対象一覧 + Markdown vs JSON 境界 + 削るべき形式指定
2. `schemas/review-result.schema.json`: 共通基底（C-1/C-2/V-1/V-3）
3. `schemas/acceptance-result.schema.json`: V-1 受入結果
4. `schemas/mode-classification.schema.json`: mode 判定結果
5. `schemas/handoff-summary.schema.json`: handoff 要約

## Work Breakdown (Steps)

### Step 1: structured-outputs.md

- **Output**: `docs/ai/structured-outputs.md`
- **Risk**: 低
- 🚩 チェックポイント:
  - 対象 6 件以上一覧
  - Markdown vs JSON 責務境界明示
  - 削減対象の形式指定 3 種以上
  - 既存 schemas/ 互換性方針
  - PBI-116-05 への eval 引き継ぎ言及

### Step 2: review-result.schema.json（共通基底）

- **Output**: `schemas/review-result.schema.json`
- **Risk**: 中（4 schema の基盤）
- 🚩 チェックポイント:
  - JSON Schema 2020-12
  - taskId / phase(C-1/C-2/V-1/V-3) / decision(PASS/WARN/FAIL) / findings[] / gateRecommendation
  - findings[] 内の severity / category 列挙

### Step 3: acceptance-result.schema.json

- **Output**: `schemas/acceptance-result.schema.json`
- **Risk**: 中
- 🚩 チェックポイント:
  - V-1 専用、test-cases 突合結果含む
  - review-result と独立（別ファイル、参照なし）

### Step 4: mode-classification.schema.json

- **Output**: `schemas/mode-classification.schema.json`
- **Risk**: 低
- 🚩 チェックポイント:
  - 5 mode (ultra-light / light / standard / high-risk / critical) 列挙
  - 判定根拠フィールド（指標 + 値）

### Step 5: handoff-summary.schema.json

- **Output**: `schemas/handoff-summary.schema.json`
- **Risk**: 低
- 🚩 チェックポイント:
  - 必須 6 要素のメタ情報（要件適合 / 既知課題 / V2 / 妥協点 / 引き継ぎ / テスト）
  - 本文 Markdown へのリンク

### Step 6: 検証 + handoff

- **Output**: `evidence/verification.md` + `handoff.md` + 子 PR
- **Risk**: 低
- 🚩 チェックポイント:
  - 4 schema が JSON Schema 2020-12 として well-formed
  - 既存 schemas/ との命名・互換性衝突なし
  - 受入基準 6 項目すべて確認

## Files / Components to Touch

### 新規作成

- `docs/ai/structured-outputs.md`
- `schemas/review-result.schema.json`
- `schemas/acceptance-result.schema.json`
- `schemas/mode-classification.schema.json`
- `schemas/handoff-summary.schema.json`
- `docs/working/TASK-0042/evidence/verification.md`
- `docs/working/TASK-0042/handoff.md`

### 触らない（forbidden_files、PBI-116-04.yaml 準拠）

- CLAUDE.md, AGENTS.md
- `.claude/rules/**`, `.claude/commands/**`, `.claude/agents/**`
- `plugin/plangate/**`
- 既存 `schemas/*.schema.json` 全件（c3-approval / c4-approval / handoff / pbi-input / plan / review-external / review-self / run-event / status / test-cases / todo）— 既存 review-* は本 PBI の review-result とは別責務として共存（C-2 EX-04-01 対応）

## Testing Strategy

### Unit
- 該当なし（doc-only）

### Integration
- markdown lint 0 error
- JSON Schema 妥当性（jsonschema CLI で `$schema` 認識確認）
- 既存 schemas/ との命名衝突確認（`ls schemas/` で重複なし）

### E2E
- 該当なし

### Edge cases
- 既存 schema との fields 重複（review-result の `taskId` vs c3-approval の `task_id`）
- Markdown / JSON 境界が曖昧な成果物（plan.md 等）
- schema 内 `additionalProperties: false` の適用範囲

### Verification Automation
- `python -m json.tool < schemas/*.schema.json` で JSON 妥当性
- `grep -E "\\\$schema.*2020-12" schemas/*.schema.json` で version 統一確認
- `wc -l docs/ai/structured-outputs.md` で過剰肥大化防止（200 行以下目安）

## Risks & Mitigations

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| L1 | 既存 schemas/ schema との互換性崩壊 | medium | 既存 schema **全 12 件** 変更禁止、命名衝突チェック、特に `review-self` / `review-external` と新規 `review-result` の責務境界を `structured-outputs.md` に明記（C-2 EX-04-01 対応） |
| L2 | 新規 schema が冗長 / Markdown 重複 | medium | structured-outputs.md で境界明示 |
| L3 | schema 準拠率が PBI-116-05 で扱いにくい | low | AC-6 で eval 観点明示、引き継ぎ |
| L4 | 4 schema 同時設計で内部矛盾 | low | review-result が共通基底、他は specialization |

## Questions / Unknowns

- Q1: JSON Schema version → 2020-12（既存と統一）
- Q2: review-result の共通基底 → phase フィールドで識別、phase 固有 optional
- Q3: handoff-summary の本文 → メタ情報のみ、本体 Markdown は別

## Mode判定

**モード**: **standard**

判定根拠:
- 変更ファイル数: 7（全新規）→ standard
- 受入基準数: 6 → standard
- 変更種別: schema 新規 + Markdown → standard
- リスク: 中（既存互換性、4 schema 整合）→ standard
- ロールバック: PR revert 容易 → standard
- **最終判定**: **standard**

## Stop rules

| Step | Stop trigger |
|------|------------|
| Step 1 | Markdown vs JSON 境界が一意定義不能 |
| Step 2 | review-result の共通基底が他 3 schema と矛盾 |
| Step 3-5 | 既存 schemas/ と命名・fields 衝突 |
| Step 6 | jsonschema 妥当性 FAIL or 受入基準未達 |
