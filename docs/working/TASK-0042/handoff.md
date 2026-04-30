---
task_id: TASK-0042
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-04-30
author: Claude (PBI-116-04 exec)
v1_release: TBD (本 PR マージ後)
---

# TASK-0042 Handoff Package

> WF-05 Verify & Handoff の出力。PBI-116-04（Issue #120 Structured Outputs / JSON Schema 方針）。
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Codex 戦略順序 3 番目（最終）

## メタ情報

```yaml
task: TASK-0042
related_issue: https://github.com/s977043/plangate/issues/120
parent_pbi: PBI-116
covers_parent_ac: [parent-AC-4]
mode: standard
author: Claude
issued_at: 2026-04-30
exec_pr: TBD
```

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|---------|
| AC-1: 対象一覧（6 件以上） | PASS | structured-outputs.md § 2 で 6 件記載 |
| AC-2: 4 新規 schema | PASS | review-result / acceptance-result / mode-classification / handoff-summary |
| AC-3: Markdown vs JSON 境界 | PASS | structured-outputs.md § 3 |
| AC-4: 削減対象形式指定（3 種以上） | PASS | structured-outputs.md § 4 で 3 種類 |
| AC-5: 既存 schemas 互換性（全 12 件） | PASS | § 5 で責務境界明文化、命名衝突なし |
| AC-6: eval 引き継ぎ方針 | PASS | § 6 で PBI-116-05 への引き継ぎ + 準拠率 < 95% で release blocker |

**総合: 6/6 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補 |
|------|---------|------|---------|
| 実 API 統合（schema を Structured Outputs として実 LLM 呼び出しに渡す）は本 PBI scope 外 | info | accepted | Yes（Phase 3 / PBI-116-03 連携 or 別 PBI） |
| 既存 Markdown 成果物の JSON 化移行は本 PBI scope 外 | info | accepted | Yes（必要時に別 PBI） |
| handoff-summary の本文 Markdown は別ファイル管理（schema はメタのみ） | minor | accepted | No（設計上の意図的分離） |
| `review-self` / `review-external` schema との互換性は責務境界で対応、技術的統合はなし | info | accepted | No（責務分離の意図的維持） |

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|------|
| 実 API での Structured Outputs 呼び出し統合 | 本 PBI は schema 設計のみ | High（PBI-116-03 / 別 PBI） |
| 既存 review-self / review-external の `summary` メタ追加で review-result との連携強化 | 責務境界を保ちつつデータ連携 | Medium |
| schema 準拠率 eval 自動化 | PBI-116-05 で扱う | High（PBI-116-05） |
| schema バージョン管理ポリシー | $id に version を含めるか等 | Low |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| review-result を共通基底（C-1/C-2/V-1/V-3 phase 識別） | phase ごとに別 schema | DRY、findings / decision / gateRecommendation の構造が共通 |
| acceptance-result は独立（review-result と分離）| review-result に統合 | V-1 固有の AC × TC マトリクスが必要 |
| handoff-summary は本文と分離（schema はメタのみ） | 全文を schema 化 | 人間可読性維持 + 機械判定の分離 |
| 既存 review-self / review-external は不変 | review-result への統合 | 責務分離（Markdown 全体 vs 判定結果） |
| `additionalProperties: false` を主要オブジェクトに適用 | 緩い柔軟性維持 | schema 厳格性を優先（モデル変更時の壊れにくさ）|

## 5. 引き継ぎ文書

### 概要

PBI-116-04 (#120 Structured Outputs / JSON Schema 方針) の exec 完了。Phase 2 の最終子 PBI。

5 つの新規ファイル:
- `docs/ai/structured-outputs.md`: 対象 6 件 + Markdown/JSON 境界 + 削減対象 + 既存互換性 + eval 引き継ぎ
- `schemas/review-result.schema.json`: C-1/C-2/V-1/V-3 共通基底（phase 識別、findings 構造化）
- `schemas/acceptance-result.schema.json`: V-1 専用、AC × TC マトリクス
- `schemas/mode-classification.schema.json`: classify 結果 + 判定根拠 5 指標
- `schemas/handoff-summary.schema.json`: handoff 必須 6 要素のメタ + testLayer 構造

JSON Schema 2020-12 統一、既存 schemas/ 12 件は不変、新規 4 件で計 15 schema となる。

### 触れないでほしいファイル

- `schemas/review-result.schema.json`: phase enum / decision enum / category enum は固定（実装側参照キー）
- `schemas/handoff-summary.schema.json`: 必須 6 要素フィールドは固定（handoff template と整合）
- 既存 `schemas/{c3-approval, c4-approval, handoff, pbi-input, plan, review-external, review-self, run-event, status, test-cases, todo}.schema.json` 全 11 件: 変更禁止
- `docs/ai/structured-outputs.md` § 5「責務境界」: 既存 schema との関係定義の正本

### 次に手を入れるなら

- **V2-1（High, PBI-116-05）**: schema 準拠率を eval 観点に組み込み、準拠率 < 95% で release blocker
- **V2-2（High, PBI-116-03 / 別 PBI）**: Prompt Assembly で本 schema を Structured Outputs として実 API 呼び出しに渡す
- **V2-3（Medium）**: 既存 review-self / review-external の summary メタ追加で連携強化
- **V2-4（Low）**: schema バージョン管理ポリシー策定

### 参照リンク

- 親 PBI: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- Issue: https://github.com/s977043/plangate/issues/120
- Phase 1 成果: [`docs/ai/core-contract.md`](../../ai/core-contract.md)
- 接続元 PBI-116-02 (Model Profile): [`docs/working/TASK-0040/handoff.md`](../TASK-0040/handoff.md)
- 接続元 PBI-116-06 (Tool Policy / Hook): [`docs/working/TASK-0041/handoff.md`](../TASK-0041/handoff.md)
- C-1 / C-2 / Child C-3: [`review-self.md`](./review-self.md) / [`review-external.md`](./review-external.md) / [`approvals/c3.json`](./approvals/c3.json)

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| 自動（grep / ls / json.tool） | 9 | 9 | 0 | 高 |
| doc-review | 3 | 3 | 0 | 高 |
| 手動 E2E | — | — | — | 該当なし |

**FAIL / SKIP の詳細**: なし
**注**: 単体テストは schema-only PBI のため対象外。jsonschema CLI による完全 validate は環境依存のため省略（python3 -m json.tool で代替、4 ファイルすべて syntactically valid）。
