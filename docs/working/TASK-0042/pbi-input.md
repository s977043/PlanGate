# PBI INPUT PACKAGE — TASK-0042 (PBI-116-04 / Issue #120)

> Status: C-1 完了 / C-2 Codex 待ち / Child C-3 待ち
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Codex 戦略採用順序の **3 番目**
> Issue: [#120 Structured Outputs / JSON Schema 方針を PlanGate 成果物に適用する](https://github.com/s977043/plangate/issues/120)
> Mode: standard

## Context / Why

最新モデル対応では、プロンプト内に巨大な JSON 形式説明を書いて出力を縛るよりも、**Structured Outputs / JSON Schema に形式保証を任せる**方が保守しやすい。

PlanGate には mode classification、review result、acceptance result、handoff summary など、機械判定に向いた出力が複数ある。これらを自然文プロンプトだけで制御すると、モデル変更時に schema 準拠率や欠落率が揺れやすい。

本 PBI では、**PlanGate のどの成果物・判定結果を Structured Outputs / JSON Schema に寄せるかを整理**し、モデル移行時にも壊れにくい出力契約を定義する。

## What

### In scope

1. **Structured Outputs 化対象の整理**

   優先対象:
   - mode classification result
   - C-1 self review result
   - C-2 external review result
   - V-1 acceptance result
   - V-3 design review result
   - handoff summary

2. **Schema 候補の定義**（最低 4 件の新規 schema 案）

   - `schemas/review-result.schema.json`（C-1/C-2/V-1/V-3 共通レビュー結果）
   - `schemas/acceptance-result.schema.json`（V-1 受入結果）
   - `schemas/mode-classification.schema.json`（mode 判定結果）
   - `schemas/handoff-summary.schema.json`（handoff 要約）

   各 schema は最低限以下を含む:
   - `taskId`, `phase`, `decision`(PASS/WARN/FAIL), `findings[]`, `gateRecommendation`(APPROVE/CONDITIONAL/REJECT)

3. **Markdown 成果物との境界整理**

   `docs/ai/structured-outputs.md` で:
   - 人間が読む成果物は Markdown 維持（plan.md / todo.md / handoff.md 本体）
   - 機械判定が必要な結果は JSON / schema に寄せる
   - frontmatter と schema の整合方針

4. **プロンプトから削るべき形式指定の整理**

   巨大な JSON 例や「絶対にこの形式」の出力強制を減らし、API / schema 側に寄せる対象を明記。

### Out of scope

- すべての Markdown 成果物の JSON 化
- 実際の API 統合実装
- eval runner 実装（→ PBI-116-05）
- 既存成果物の全移行
- 既存 `schemas/*.schema.json` 全 12 件の変更（互換性確認のみ。c3-approval / c4-approval / handoff / pbi-input / plan / review-external / review-self / run-event / status / test-cases / todo を含む。C-2 EX-04-01 対応で 5 件 → 12 件に拡張）

## 受入基準

- [ ] AC-1: Structured Outputs 化する対象成果物・判定結果が `docs/ai/structured-outputs.md` に一覧化されている（最低 6 件）
- [ ] AC-2: `schemas/review-result.schema.json` / `acceptance-result.schema.json` / `mode-classification.schema.json` / `handoff-summary.schema.json` の 4 schema が新規定義されている
- [ ] AC-3: Markdown 成果物と JSON 判定結果の責務境界が明文化されている
- [ ] AC-4: プロンプトから削るべき巨大な出力形式指定が整理されている（最低 3 種類）
- [ ] AC-5: 既存の `schemas/` 方針や frontmatter 標準化と矛盾していない（**12 件すべての互換性検証**、特に `review-self` / `review-external` と新規 `review-result` の責務境界を `structured-outputs.md` に明記。C-2 EX-04-01 対応）
- [ ] AC-6: schema 準拠率を eval 対象に含める方針が明記されている（PBI-116-05 への引き継ぎ）

## Notes from Refinement

- **Phase 2 戦略**: Codex 相談で確定（PR #136）
- **着手順序**: 本 TASK は Phase 2 の 3 番目（最も独立性が高い）
- **02/06 とは独立**: Structured Outputs は Model Profile / Tool Policy と直交。tool_policy 等の値域には影響しない
- **既存 schemas/ の保持**: `handoff/plan/status/c3-approval/c4-approval` は変更しない（互換性確認のみ）

## Estimation Evidence

### Risks

| ID | Risk | Severity | Mitigation |
|----|------|---------|----------|
| L1 | 既存 `schemas/` schema との互換性が崩れる | medium | C-1 / C-2 で互換性確認、既存 schema は変更しない（forbidden_files に明記） |
| L2 | 新規 schema が冗長 / Markdown と重複 | medium | structured-outputs.md で「機械判定のみ schema 化」と境界明示 |
| L3 | schema 準拠率が PBI-116-05 (Eval Cases) で扱いにくい | low | AC-6 で eval 観点を明示、PBI-116-05 へ引き継ぎ |
| L4 | 4 schema 同時設計で内部矛盾 | low | review-result が共通基盤、他 3 件は specialization |

### Unknowns

- Q1: schema は JSON Schema 2020-12 か 2019-09 どちらを採用？
  - A1: 既存 `schemas/c3-approval.schema.json` 等が 2020-12 なので統一
- Q2: review-result.schema.json は C-1 / C-2 / V-1 / V-3 共通？
  - A2: 共通基底にする。phase フィールドで識別、phase 固有フィールドは optional に
- Q3: handoff-summary はテキスト本体なしで構造化情報のみ？
  - A3: 構造化情報のみ（必須 6 要素のメタ + リンク）。本体 Markdown は別

### Assumptions

- Phase 1 (Core Contract) は変更しない
- 既存 schemas/ は本 PBI scope 外
- doc-only PBI（schema JSON + Markdown のみ、コード変更なし）
- 02/06 と完全独立

## Parent PBI との関係

| 親 AC | カバー |
|------|--------|
| parent-AC-4 | Structured Outputs schema 整理（直接対応） |

## 関連リンク

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- 子 PBI YAML: [`docs/working/PBI-116/children/PBI-116-04.yaml`](../PBI-116/children/PBI-116-04.yaml)
- Issue: https://github.com/s977043/plangate/issues/120
- 既存 schemas: `schemas/c3-approval.schema.json` 等
- Phase 1 成果: [`docs/ai/core-contract.md`](../../ai/core-contract.md)
