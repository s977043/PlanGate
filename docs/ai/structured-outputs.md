# Structured Outputs / JSON Schema 方針

> **Status**: v1（PBI-116-04 で初版確立、Phase 2 / PBI-116）
> 関連: [`core-contract.md`](./core-contract.md) / [`model-profiles.md`](./model-profiles.md) / [`responsibility-boundary.md`](./responsibility-boundary.md)

## 1. 目的

PlanGate の **機械判定向け成果物** を、自然文プロンプト（出力形式の冗長指定）ではなく **Structured Outputs / JSON Schema に形式保証を任せる**。これにより:

- モデル変更時の schema 準拠率が安定（プロンプトに依存しない）
- プロンプトを薄型化（PBI-116-01 達成）後も形式強制が維持
- eval（PBI-116-05）で機械検証可能な指標を提供

## 2. Structured Outputs 化対象（最低 6 件）

| 成果物 / 判定結果 | 用途 | 新規 schema |
|----------------|------|-----------|
| **mode classification result** | classify phase の mode 判定 | [`mode-classification.schema.json`](../../schemas/mode-classification.schema.json) |
| **C-1 self review result** | C-1 17 項目セルフレビュー結果 | [`review-result.schema.json`](../../schemas/review-result.schema.json)（共通基底） |
| **C-2 external review result** | Codex 等の外部 AI レビュー | 同上（phase 識別） |
| **V-1 acceptance result** | test-cases 突合の受入結果 | [`acceptance-result.schema.json`](../../schemas/acceptance-result.schema.json) |
| **V-3 design review result** | exec 後の外部モデルレビュー | [`review-result.schema.json`](../../schemas/review-result.schema.json)（phase 識別） |
| **handoff summary** | WF-05 完了時の引き継ぎ要約 | [`handoff-summary.schema.json`](../../schemas/handoff-summary.schema.json) |

**4 新規 schema（合計）**:
- `review-result.schema.json` — C-1 / C-2 / V-1 / V-3 共通基底（phase で識別）
- `acceptance-result.schema.json` — V-1 専用、test-cases 突合
- `mode-classification.schema.json` — mode 判定 + 根拠
- `handoff-summary.schema.json` — handoff 必須 6 要素のメタ

## 3. Markdown 成果物 vs JSON 判定結果の境界

### Markdown を維持するもの（人間が読む）

| 成果物 | 理由 |
|-------|------|
| `pbi-input.md` | 自然言語の要件記述 |
| `plan.md` | 設計判断・思考プロセスの記録 |
| `todo.md` | チェックボックス + 構造化（人間が確認）|
| `test-cases.md` | テスト記述（自然言語 + 構造）|
| `status.md` | フェーズ履歴（時系列）|
| `current-state.md` | スナップショット（人間が判読）|
| `handoff.md` 本文 | 必須 6 要素の自然言語記述 |
| `evidence/*.md` | 検証ログ（再現可能性）|

### JSON / schema に寄せるもの（機械判定）

| 成果物 | 理由 |
|-------|------|
| `approvals/c3.json` | gate 判定の機械検証（既存）|
| `approvals/c4-approval.json` | 同上（既存）|
| C-1 / C-2 / V-1 / V-3 review result | スコア・ findings の機械集計 |
| handoff summary（メタ）| 完了判定・eval 入力 |
| mode classification | 自動 mode 判定の機械検証 |

### Markdown と JSON を併存させるもの

- `handoff.md` 本文（Markdown） + `handoff.summary.json`（schema 準拠メタ）
- `review-self.md`（Markdown 詳細） + `review-result.json`（C-1 phase スコア）

## 4. プロンプトから削るべき形式指定

以下の **巨大な出力形式説明** をプロンプトから削減し、schema 側に寄せる:

### 削減対象 1: review result の長文 JSON 例

旧: プロンプト内に「以下の形式で出力してください」と JSON 例を 30 行記載
新: schema 側で形式強制、プロンプトは「[`review-result.schema.json`](../../schemas/review-result.schema.json) に従って出力」と一行参照

### 削減対象 2: handoff の必須 6 要素テンプレ重複

旧: プロンプトに「必須 6 要素はこちら…」と詳細テンプレ
新: schema + handoff template への参照のみ

### 削減対象 3: mode classification の判定基準巨大表

旧: プロンプトに 5×複数項目の mode 分類表
新: schema の enum + `.claude/rules/mode-classification.md` への参照

## 5. 既存 `schemas/` との互換性（C-2 EX-04-01 対応）

既存 12 schema（c3-approval / c4-approval / handoff / pbi-input / plan / **review-external** / **review-self** / run-event / status / **test-cases** / todo + README）は **本 PBI で変更しない**。

### 既存 review-self / review-external と新規 review-result の責務境界

| schema | 用途 |
|--------|------|
| **`review-self.schema.json`**（既存） | C-1 セルフレビューの **Markdown 成果物全体** に対する frontmatter / メタ schema（17 項目チェックの記録方式） |
| **`review-external.schema.json`**（既存） | C-2 外部 AI レビューの **Markdown 成果物全体** の frontmatter / メタ schema |
| **`review-result.schema.json`**（新規） | C-1 / C-2 / V-1 / V-3 の **判定結果のみ** を機械集計用に構造化（phase / decision / findings / gateRecommendation）|

→ 既存 schema は Markdown 全体の構造を、新規 schema は判定結果のみを扱う。**重複なし、共存**。

## 6. schema 準拠率を eval 対象に含める方針（PBI-116-05 への引き継ぎ）

PBI-116-05 (Model migration Eval cases) で以下を機械検証:

- review-result.schema.json 準拠率（C-1 / C-2 / V-1 / V-3 出力）
- acceptance-result.schema.json 準拠率（V-1 出力）
- mode-classification.schema.json 準拠率（classify 出力）
- handoff-summary.schema.json 準拠率（WF-05 出力）

→ モデル変更時に **schema 準拠率 < 95% で release blocker** とする。

## 7. JSON Schema バージョン

統一: **2020-12**（既存 `c3-approval.schema.json` 等と整合）

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- TASK: [`docs/working/TASK-0042/`](../working/TASK-0042/)
- Phase 1 成果（基盤）: [`core-contract.md`](./core-contract.md)
- 接続先: PBI-116-05 (Eval Cases) で schema 準拠率を eval 観点に
