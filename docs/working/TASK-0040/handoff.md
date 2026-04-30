---
task_id: TASK-0040
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-04-30
author: Claude (PBI-116-02 exec)
v1_release: TBD (本 PR マージ後)
---

# TASK-0040 Handoff Package

> WF-05 Verify & Handoff の出力。PBI-116-02（Issue #118 Model Profile layer 追加）。
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Codex 戦略順序 1 番目

## メタ情報

```yaml
task: TASK-0040
related_issue: https://github.com/s977043/plangate/issues/118
parent_pbi: PBI-116
covers_parent_ac: [parent-AC-2]
mode: standard
author: Claude
issued_at: 2026-04-30
exec_pr: TBD
```

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|---------|
| AC-1: model-profiles.yaml/md 追加 | PASS | 両ファイル存在、構造化済 |
| AC-2: 4 プロファイル定義 | PASS | gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown |
| AC-3: reasoning effort × mode マトリクス | PASS | 5×4 = 20 セル完備（model-profiles.md § 4）|
| AC-4: verbosity × phase 表 | PASS | 5×4 = 20 セル完備（§ 5）|
| AC-5: context budget policy | PASS | 3 段階 + 用途説明（§ 6）|
| AC-6: critical mode で gpt-5_mini disallow | PASS | `disallowed_modes: [critical]` |
| AC-7: Core / Gate / Artifact schema 不変宣言 | PASS | § 2「不変ポリシー」で明示 |
| AC-8: tool_policy / validation_bias 値域整合 | PASS | interface-preflight.md と完全一致 |

**総合: 8/8 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補 |
|------|---------|------|---------|
| jsonschema CLI による完全 validate は環境依存（json.tool / yaml.safe_load で代替） | minor | accepted | No（CI で対応） |
| プロファイル値（reasoning effort 等）の実モデル挙動との整合性未検証 | medium | accepted | Yes（PBI-116-05 Eval Cases で検証） |
| プロファイル切替の runtime 実装は本 PBI scope 外 | info | accepted | Yes（別 PBI / Phase 3 以降） |
| `gpt-5_mini` の critical mode block は schema 表現のみ、強制は別 PBI | minor | accepted | Yes（PBI-116-06 / Hook 実装 PBI） |

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|------|
| プロファイル値の eval 検証 | 実モデル挙動との整合確認 | High（PBI-116-05）|
| プロファイル切替 runtime 実装 | 設計層のみで実装層なし | Medium |
| disallowed_modes の強制 Hook 実装 | schema 表現のみ | Medium（PBI-116-06 / Hook 実装 PBI）|
| 新規モデル追加（gpt-5_5 後継等） | scope 限定で 4 件のみ | Low（必要時に） |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| `reasoning_effort_by_mode` 単一値 + `allowed_efforts[]` 構造化 | `high/xhigh` 文字列で表現 | C-2 EX-02-01 指摘で schema 値の曖昧性を排除 |
| `gpt-5_mini` の critical を `low` + `disallowed_modes` で表現 | critical 自体を削除 | schema 完備性のため値は埋める、強制は disallowed_modes で |
| jsonschema CLI 完全 validate を省略、json.tool / yaml.safe_load で代替 | jsonschema CLI 必須化 | 環境依存性の回避、CI で対応可 |
| 4 プロファイル限定 | 全モデル網羅 | scope 限定（追加は別 PBI）|

## 5. 引き継ぎ文書

### 概要

PBI-116-02 (#118 Model Profile layer) の exec フェーズ完了。`schemas/model-profile.schema.json` で JSON Schema 2020-12 準拠の薄い設定層を定義し、`docs/ai/model-profiles.yaml` で 4 プロファイル（gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown）を定義、`docs/ai/model-profiles.md` で schema 仕様 + 5×4 reasoning matrix + 5×4 verbosity 表 + context budget 3 段階 + 不変ポリシー宣言を提供。

interface-preflight.md で合意した `tool_policy` / `validation_bias` 値域に準拠し、PBI-116-06（Tool Policy）と接続可能な状態。

### 触れないでほしいファイル

- `schemas/model-profile.schema.json`: 本 PBI の正本。後方互換破壊的変更時に version インクリメント必須
- `docs/ai/model-profiles.yaml` の `version: 1`: schema バージョン
- 既存 `schemas/*.schema.json` 全 12 件: 変更禁止（本 PBI scope 外）
- `core-contract.md`: モデル非依存維持（Phase 1 成果物）

### 次に手を入れるなら

- **V2-1（High, PBI-116-05）**: プロファイル値の実モデル挙動 eval 検証
- **V2-2（Medium）**: プロファイル切替の runtime 実装（adapter 解決ロジック）
- **V2-3（Medium）**: `disallowed_modes` 強制 Hook 実装（PBI-116-06 / 別 PBI）
- **V2-4（Low）**: 新規プロファイル追加（必要時に別 PBI で）

### 参照リンク

- 親 PBI: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- Issue: https://github.com/s977043/plangate/issues/118
- Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)
- C-1 / C-2 / Child C-3 履歴: [`review-self.md`](./review-self.md) / [`review-external.md`](./review-external.md) / [`approvals/c3.json`](./approvals/c3.json)
- Phase 1 成果（不変基盤）: [`docs/ai/core-contract.md`](../../ai/core-contract.md)

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| 自動（grep / wc / json.tool / yaml.safe_load） | 9 | 9 | 0 | 高 |
| doc-review | 3 | 3 | 0 | 高 |
| 手動 E2E | — | — | — | 該当なし |

**FAIL / SKIP の詳細**: なし
**注**: 単体テストは doc/schema-only PBI のため対象外。jsonschema CLI による完全 validate は環境依存のため省略（json.tool / yaml.safe_load で代替）。CI に jsonschema を導入するのは別 PBI。
