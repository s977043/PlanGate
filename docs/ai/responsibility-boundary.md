# Responsibility Boundary — Prompt / Tool Policy / Hook / CLI validate

> **Status**: v1（PBI-116-06 で初版確立、Phase 2 / PBI-116）
> 関連: [`docs/ai/core-contract.md`](./core-contract.md) / [`docs/ai/model-profiles.md`](./model-profiles.md) / [`docs/ai/tool-policy.md`](./tool-policy.md) / [`docs/ai/hook-enforcement.md`](./hook-enforcement.md)
> Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../working/PBI-116/interface-preflight.md)

## 1. 目的

PlanGate ワークフローにおいて、**モデルに判断させるべきもの** と **runtime で決定論的にブロックすべきもの** を明確に分離する。プロンプトに不変制約を全部書き込むと再び肥大化するため、「ソフト」「ハード」の境界を 4 layer で整理する。

## 2. 4 Layer 責務マトリクス

| Layer | 強制力 | 責務 | 主な配置 |
|-------|------|------|---------|
| **Prompt** | ソフト（モデル判断）| 目的、成功条件、判断基準、不明点の扱い、報告形式 | [`core-contract.md`](./core-contract.md) / `CLAUDE.md` / `AGENTS.md` |
| **Tool Policy** | ソフト + 制限 | phase 別の利用可能ツールを限定 | [`tool-policy.md`](./tool-policy.md)（本 PBI）|
| **Hook** | **ハード（決定論ブロック）** | 不変条件を runtime で 100% 強制 | [`hook-enforcement.md`](./hook-enforcement.md)（本 PBI、定義のみ）+ `.claude/settings.json` の hooks（実装）|
| **CLI / validate** | **ハード（事後検証）** | 成果物・承認状態・plan_hash・検証証拠を検査 | `bin/plangate validate` 等（本 PBI scope 外）|

## 3. 判断基準（モデル判断 vs runtime 強制）

### Prompt（モデル判断）に置くもの

- **outcome の定義**（Goal / Success criteria）
- **判断基準** — 曖昧時の確認、不明点の扱い、停止条件
- **報告形式** — 出力の構造化方針（schema 経由可）
- **コンテキスト依存の選択肢** — 例: 複数のリファクタ候補から 1 つを選ぶ判断

### Hook（runtime 強制）に置くもの

- **不変条件** — Iron Law 7 項目相当（Core Contract Hard constraints）
- **承認境界** — C-3 / C-4 ゲート遵守
- **scope 境界** — `allowed_files` / `forbidden_files` 違反検出
- **整合性** — `plan_hash` 改竄検知、`approvals/c3.json` の必須キー
- **検証証跡** — V-1 受入結果なし PR 禁止

### Tool Policy（ソフト + phase 制限）に置くもの

- **phase 別 allowed tools** — plan で write tool 不可、approve-wait で全 write 不可、等
- **Model Profile 接続** — `tool_policy: narrow / allowed_tools_by_phase / expanded` の射影

### CLI / validate（事後検証）に置くもの

- **成果物形式チェック** — JSON Schema validate、Markdown lint
- **承認記録の整合性** — `approvals/c3.json` の plan_hash と現 plan.md SHA-256 一致
- **検証ログの存在** — `evidence/verification.md`、test 実行ログ

## 4. 重複時の解釈

複数 layer が同一事項に触れる場合（例: 「scope 外編集禁止」を Prompt にも Hook にも書く）:

- **Hook が最終判断**（決定論ブロック）
- Prompt は「Hook で block されるべき内容」を **要約して伝える**（モデルに無駄な試行をさせない）
- Tool Policy は phase 別の **事前フィルタ**（許可 tool を制限）
- CLI / validate は **事後検証** で「Hook が見逃した」場合の二重防御

## 5. プロンプトで強制 vs runtime で強制（具体例）

| 制約 | プロンプト | Tool Policy | Hook | CLI |
|-----|----------|------------|------|-----|
| C-3 承認前は production code 編集禁止 | Iron Law として明示 | approve-wait phase で write 全禁止 | **runtime block** | approvals/c3.json なしなら fail |
| scope 外ファイル編集禁止 | Iron Law として明示 | allowed_files に制限 | **runtime block**（forbidden_files 検出）| diff の対象外チェック |
| 検証証拠なし PR 禁止 | Iron Law として明示 | review phase で diff/test のみ | **runtime block**（evidence なし PR）| evidence ディレクトリ存在チェック |
| plan_hash 改竄禁止 | Iron Law として明示 | — | **runtime block**（hash 不一致検出）| approvals/c3.json の plan_hash と現 plan.md SHA 比較 |
| 承認なし sub-issue 追加禁止 | Iron Law として明示 | — | **runtime block** | — |

## 6. 本 PBI のスコープ境界

- **境界定義** ✅: 本ファイル + [`tool-policy.md`](./tool-policy.md) + [`hook-enforcement.md`](./hook-enforcement.md)
- **実装** ❌: 実 Hook の実装 / `.claude/settings.json` の hooks 追加 / CLI validate 拡張 はすべて **別 PBI**

実装方法は [`hook-enforcement.md`](./hook-enforcement.md) で「強制すべき不変条件」を定義し、別 PBI で実装する。

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- TASK: [`docs/working/TASK-0041/`](../working/TASK-0041/)
- Phase 1 成果（不変基盤）: [`core-contract.md`](./core-contract.md)
- Model Profile（接続元）: [`model-profiles.md`](./model-profiles.md)
- 同 PBI 子ドキュメント: [`tool-policy.md`](./tool-policy.md) / [`hook-enforcement.md`](./hook-enforcement.md)
