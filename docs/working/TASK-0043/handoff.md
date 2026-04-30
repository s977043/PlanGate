---
task_id: TASK-0043
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-04-30
author: Claude (PBI-116-03 exec)
v1_release: TBD (本 PR マージ後)
---

# TASK-0043 Handoff Package

> WF-05 Verify & Handoff の出力。PBI-116-03（Issue #119 Prompt Assembly を 4 層化）。
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / **Phase 3** / Mode: high-risk

## メタ情報

```yaml
task: TASK-0043
related_issue: https://github.com/s977043/plangate/issues/119
parent_pbi: PBI-116
covers_parent_ac: [parent-AC-3]
mode: high-risk
author: Claude
issued_at: 2026-04-30
exec_pr: TBD
```

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|---------|
| AC-1: 4 層定義 | PASS | prompt-assembly.md § 2 構造図 + 責務マトリクス |
| AC-2: 各層の責務境界 | PASS | § 2 マトリクスで役割 / 変更頻度 / 配置を明示 |
| AC-3: 7 phase contract | PASS | contracts/*.md 7 ファイル、各 28-36 行 |
| AC-4: 4 model adapter（schema enum 全件） | PASS | adapters/*.md 4 ファイル、jq + diff で schema 一致確認 |
| AC-5: prompt full fork 回避方針 | PASS | § 6 アンチパターン表 + § 1 冒頭明示 |
| AC-6: .claude / plugin 両適用構造 | PASS | § 7 適用範囲明示、Plugin 限定との共存 |
| AC-7: 解決ロジック（擬似コード） | PASS | § 5 TypeScript 型定義 + assemble() / resolveVerbosity() |

**総合: 7/7 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補 |
|------|---------|------|---------|
| 実装言語選択（TypeScript / shell / Python）未確定 | info | accepted | Yes（別 PBI で実装決定） |
| `verify` phase の Core Contract v1 統合は次回更新で | minor | accepted | Yes（core-contract.md v2 で 7 phase 化検討） |
| `risk_mode_contract` ファイル化未実施（概念のみ）| info | accepted | Yes（必要時に contracts/<mode>.md として独立化）|
| Plugin 配布版（`plugin/plangate/commands/`）への適用は別 PBI | info | accepted | Yes（Plugin 同期 PBI） |
| schema 完全 validate（jsonschema CLI）は環境依存で省略 | minor | accepted | No（CI で対応可能）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|------|
| 実 prompt 組み立て CLI 実装（`bin/plangate-prompt-assemble`） | 本 PBI は擬似コードまで | High（Phase 4 / 別 PBI）|
| Core Contract v2 化（7 phase 統合） | v1 は 6 phase で互換扱い | Medium |
| risk_mode_contract のファイル化 | 5 mode × phase の検証深度を独立 | Medium |
| Plugin 配布版（`plugin/plangate/commands/`）への適用 | 一般化された定義の Plugin 同期 | Medium（Plugin 同期 PBI）|
| schema 準拠率 eval（PBI-116-05）で 4 層独立検証 | base/phase/mode/adapter 切り分け検証 | High（PBI-116-05）|

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| `verify` を `review` から分離（Prompt Assembly 7 phase） | Core Contract v1 と同じ 6 phase | Eval（PBI-116-05）で受入確認と設計品質を独立検証可能に |
| verbosity_by_phase 解決を adapter 内 logic で吸収 | Phase 2 schema を 7 phase に拡張 | schema 不変原則を維持、解決層で互換確保 |
| risk_mode_contract をファイル化せず概念のみ | mode 別 contracts/<mode>.md 作成 | 本 PBI 範囲を 4 層 + 7 phase + 4 adapter に絞る、mode は mode-classification.md 参照 |
| 解決ロジックは TypeScript 型定義 + 擬似コード | shell / Python 実装 | doc-only 制約遵守、実装言語は別 PBI で決定 |
| 各 contracts/*.md 50 行以下 | 詳細な仕様記述 | base_contract で詳細を扱い、phase 固有のみに絞る |

## 5. 引き継ぎ文書

### 概要

PBI-116-03 (#119 Prompt Assembly) の exec 完了。Phase 3 / high-risk PBI。

12 個の新規 Markdown ファイル:
- `docs/ai/prompt-assembly.md`（170 行、4 層 + 解決ロジック + 互換説明）
- `docs/ai/contracts/{classify,plan,approve-wait,execute,review,verify,handoff}.md`（7 件、各 28-36 行）
- `docs/ai/adapters/{outcome_first,outcome_first_strict,explicit_short,legacy_or_unknown}.md`（4 件、各 40-49 行）

合計 574 行で目安 700 以下を達成。adapter enum は schema と完全一致（jq + diff PASS）。

Phase 1 (Core Contract) + Phase 2 (Model Profile / Tool Policy / Structured Outputs / Responsibility Boundary) を統合する設計層。Phase 4 (PBI-116-05 Eval) で各層を独立検証する前提を提供。

### 触れないでほしいファイル

- `docs/ai/prompt-assembly.md` § 2 構造図 / § 5 解決ロジック型定義: 実装層からの参照キー
- `docs/ai/adapters/*.md` ファイル名: schema enum と一致必須（変更時は schema も同時更新）
- `docs/ai/contracts/*.md` ファイル名: 7 phase 識別子の正本
- 既存 `core-contract.md` / `model-profiles.yaml` / その他 Phase 1/2 成果物: 不変

### 次に手を入れるなら

- **V2-1（High, PBI-116-05）**: 4 層を独立検証する eval cases 追加、schema 準拠率測定
- **V2-2（High, 別 PBI）**: 実 CLI 実装（`bin/plangate-prompt-assemble`）
- **V2-3（Medium）**: Core Contract v2 化（7 phase 統合）
- **V2-4（Medium）**: Plugin 配布版への適用（同期 PBI）

### 参照リンク

- 親 PBI: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- Issue: https://github.com/s977043/plangate/issues/119
- Phase 1: [`docs/ai/core-contract.md`](../../ai/core-contract.md)
- Phase 2: [`model-profiles.md`](../../ai/model-profiles.md) / [`responsibility-boundary.md`](../../ai/responsibility-boundary.md) / [`tool-policy.md`](../../ai/tool-policy.md) / [`hook-enforcement.md`](../../ai/hook-enforcement.md) / [`structured-outputs.md`](../../ai/structured-outputs.md)
- C-1 / C-2 / Child C-3: [`review-self.md`](./review-self.md) / [`review-external.md`](./review-external.md) / [`approvals/c3.json`](./approvals/c3.json)

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| 自動（grep / wc / ls / jq + diff） | 7 | 7 | 0 | 高 |
| doc-review | 3 | 3 | 0 | 高 |
| 手動 E2E | — | — | — | 該当なし |

**FAIL / SKIP の詳細**: なし
**注**: 単体テストは doc-only PBI のため対象外。実 CLI 実装は別 PBI のため runtime テストは scope 外。
