# TEST CASES — TASK-0043 (PBI-116-03 / Issue #119)

## 受入基準 → テストケース マッピング

| AC | TC | 種別 |
|----|----|----|
| AC-1: 4 層定義 | TC-1 | 自動 + doc-review |
| AC-2: 各層の責務境界 | TC-2 | doc-review |
| AC-3: phase contract 7 件 | TC-3 | 自動（ls / grep） |
| AC-4: model adapter 4 件 | TC-4 | 自動（ls / grep） |
| AC-5: prompt full fork 回避方針 | TC-5 | 自動（grep）|
| AC-6: .claude / plugin 両適用構造 | TC-6 | doc-review |
| AC-7: 解決ロジック（擬似コード）| TC-7 | doc-review |

## テストケース一覧

### TC-1: 4 層定義

```bash
grep -cE "base_contract|phase_contract|risk_mode_contract|model_adapter" docs/ai/prompt-assembly.md
```

期待: 4 層すべての言及あり、各層の責務記述あり。✅ 自動 + doc-review

### TC-2: 各層の責務境界

prompt-assembly.md に 4 層 × 役割の責務マトリクス（Markdown 表）が含まれる。✅ doc-review

### TC-3: 7 phase contract

```bash
ls docs/ai/contracts/*.md | wc -l
# → 7
```

7 phase（classify / plan / approve-wait / execute / review / verify / handoff）すべて存在。各 50 行以下。✅ 自動

### TC-4: 4 model adapter

```bash
ls docs/ai/adapters/*.md | wc -l
# → 4
```

4 adapter（outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown）すべて存在。✅ 自動

### TC-5: prompt full fork 回避方針

```bash
grep -E "fork|フォーク" docs/ai/prompt-assembly.md
```

期待: 「モデル別 prompt 全文 fork を避ける」旨の方針が明示。✅ 自動

### TC-6: .claude / plugin 両適用構造

prompt-assembly.md で `.claude/` と `plugin/plangate/` の両方に適用可能な構造として記述（参照リンクなし、論理的な適用範囲明示）。✅ doc-review

### TC-7: 解決ロジック（擬似コード）

prompt-assembly.md に TypeScript 型定義（PlanGatePromptContext）または同等の構造化記述あり。✅ doc-review

## エッジケース

### TC-E1: adapter enum 完全一致（C-2 EX-03-03 対応で強化）

```bash
# schema 側 enum 抽出
jq -r '."$defs".profile.properties.adapter.enum[]' schemas/model-profile.schema.json | sort > /tmp/schema-adapters.txt

# prompt-assembly.md / adapters/ から定義を抽出（実装時に整形）
ls docs/ai/adapters/*.md | xargs -I {} basename {} .md | sort > /tmp/doc-adapters.txt

# 完全一致確認
diff /tmp/schema-adapters.txt /tmp/doc-adapters.txt && echo "PASS"
```

期待: schema 側 4 enum と adapters/*.md ファイル名が **完全一致**（追加・削除も検出）。grep 単独の存在確認より強い。✅ 自動

### TC-E2: 過剰肥大化防止

```bash
wc -l docs/ai/prompt-assembly.md docs/ai/contracts/*.md docs/ai/adapters/*.md
```

期待:
- prompt-assembly.md: 200 行以下
- 各 contracts/*.md: 50 行以下
- 各 adapters/*.md: 50 行以下
- 合計: 700 行以下

✅ 自動

### TC-E3: 既存 docs/ai/ との命名衝突

```bash
ls docs/ai/contracts/ docs/ai/adapters/ 2>&1
```

期待: 既存 `docs/ai/` 直下のファイルと衝突しない（`contracts/` と `adapters/` がサブディレクトリ）。✅ 自動

## 自動化サマリ

| TC | 自動化 |
|----|------|
| TC-1〜TC-7 | 4 件自動、3 件 doc-review |
| TC-E1〜TC-E3 | 全件自動 |

自動化率: 7/10。
