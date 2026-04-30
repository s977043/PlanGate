# TEST CASES — TASK-0040 (PBI-116-02 / Issue #118)

> doc-only PBI のため、テストケースは schema-validate / grep / リンク到達性 / 表完備性が中心。

## 受入基準 → テストケース マッピング

| 受入基準 | TC ID | 種別 |
|---------|------|------|
| AC-1: model-profiles.yaml/md 追加 | TC-1, TC-2 | 自動（ls）+ doc-review |
| AC-2: 4 プロファイル定義 | TC-3 | 自動（grep） |
| AC-3: reasoning effort × mode マトリクス | TC-4 | doc-review + 自動 |
| AC-4: verbosity × phase 表 | TC-5 | doc-review |
| AC-5: context budget policy | TC-6 | doc-review |
| AC-6: critical mode で gpt-5_mini disallow | TC-7 | 自動（grep） |
| AC-7: Core / Gate / Artifact schema 不変宣言 | TC-8 | doc-review |
| AC-8: tool_policy / validation_bias 値域整合 | TC-9 | 自動（grep） |

## テストケース一覧

### TC-1: docs/ai/model-profiles.yaml が存在
- 入力: `ls docs/ai/model-profiles.yaml`
- 期待: ファイル存在
- 種別: 自動

### TC-2: docs/ai/model-profiles.md が存在し schema 仕様を含む
- 入力: `grep -E "^## " docs/ai/model-profiles.md`
- 期待: schema 仕様 / プロファイル説明 / マトリクスの各セクション
- 種別: 自動 + doc-review

### TC-3: 4 プロファイル定義
- 入力: `grep -E "^  (gpt-5_5|gpt-5_5_pro|gpt-5_mini|legacy_or_unknown):" docs/ai/model-profiles.yaml`
- 期待: 4 件すべてマッチ
- 種別: 自動

### TC-4: reasoning effort × mode マトリクス
- 入力: model-profiles.md の該当表を目視確認
- 期待: 5 mode (ultra-light / light / standard / high-risk / critical) × 4 profile = 20 セル全埋め
- 種別: doc-review + 自動（テーブル行数 grep）

### TC-5: verbosity × phase 表
- 入力: 該当表を目視確認
- 期待: 5 phase (classify / plan / execute / review / handoff) × 4 profile = 20 セル全埋め
- 種別: doc-review

### TC-6: context budget policy
- 入力: `grep -E "compact|standard|expanded" docs/ai/model-profiles.md`
- 期待: 3 段階すべてヒット + 用途説明あり
- 種別: 自動 + doc-review

### TC-7: critical mode で gpt-5_mini disallow
- 入力: `grep -A 2 "gpt-5_mini" docs/ai/model-profiles.yaml | grep -E "disallowed_modes|critical"`
- 期待: `disallowed_modes: [critical]` または同等表現
- 種別: 自動

### TC-8: Core / Gate / Artifact schema 不変宣言
- 入力: `grep -E "Core Contract|Gate|Artifact" docs/ai/model-profiles.md`
- 期待: 「これらはモデル別に変えない」旨の明示
- 種別: doc-review

### TC-9: tool_policy / validation_bias 値域整合
- 入力:
  - `grep -E "narrow|allowed_tools_by_phase|expanded" docs/ai/model-profiles.yaml`
  - `grep -E "lenient|normal|strict" docs/ai/model-profiles.yaml`
- 期待: interface-preflight.md と完全一致
- 種別: 自動 + doc-review

## エッジケース

### TC-E1: schema-validate
- 入力: `python -m jsonschema -i docs/ai/model-profiles.yaml schemas/model-profile.schema.json`（または yajsv）
- 期待: PASS
- 種別: 自動（手動可）

### TC-E2: profile 値域逸脱検出
- 入力: わざと不正な reasoning_effort 値を入れて schema-validate
- 期待: FAIL を返す
- 種別: 自動（手動）

### TC-E3: 既存 schemas/ との命名衝突
- 入力: `ls schemas/ | grep -i model`
- 期待: `model-profile.schema.json` のみ（既存と衝突なし）
- 種別: 自動

## 自動化サマリ

| TC | 自動化可否 |
|----|----------|
| TC-1 | ✅ ls |
| TC-2 | △ grep + 目視 |
| TC-3 | ✅ grep |
| TC-4 | △ grep（行数）+ 目視 |
| TC-5 | ✗ doc-review |
| TC-6 | △ grep + 目視 |
| TC-7 | ✅ grep |
| TC-8 | ✗ doc-review |
| TC-9 | ✅ grep |
| TC-E1 | ✅ jsonschema CLI |
| TC-E2 | ✅ negative test |
| TC-E3 | ✅ ls |

自動化率: 9/12 が完全 / 部分自動化可能。
