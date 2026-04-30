# TEST CASES — TASK-0042 (PBI-116-04 / Issue #120)

## 受入基準 → テストケース マッピング

| AC | TC | 種別 |
|----|----|----|
| AC-1: 対象一覧（6 件以上） | TC-1 | 自動 + doc-review |
| AC-2: 4 新規 schema | TC-2, TC-3 | 自動（ls） |
| AC-3: Markdown vs JSON 境界 | TC-4 | doc-review |
| AC-4: 削減対象形式指定（3 種以上） | TC-5 | 自動 + doc-review |
| AC-5: 既存 schemas 互換性 | TC-6 | 自動（ls / grep） |
| AC-6: eval 引き継ぎ方針 | TC-7 | doc-review |

## テストケース一覧

### TC-1: structured-outputs.md に対象 6 件以上一覧
- 入力: `grep -cE "^- \\\*\\\*|^\\| " docs/ai/structured-outputs.md`
- 期待: 対象成果物 6 件以上
- 種別: 自動 + doc-review

### TC-2: 4 新規 schema 存在
- 入力: `ls schemas/{review-result,acceptance-result,mode-classification,handoff-summary}.schema.json`
- 期待: 4 ファイルすべて存在
- 種別: 自動

### TC-3: 各 schema が JSON Schema 2020-12
- 入力: `grep -l "json-schema.org/draft/2020-12" schemas/{review-result,acceptance-result,mode-classification,handoff-summary}.schema.json`
- 期待: 4 ファイルすべてマッチ
- 種別: 自動

### TC-4: Markdown vs JSON 責務境界
- 入力: `grep -E "Markdown|JSON" docs/ai/structured-outputs.md`
- 期待: 境界記述あり、責務分離明示
- 種別: doc-review

### TC-5: 削減対象形式指定 3 種以上
- 入力: structured-outputs.md の該当セクション目視
- 期待: 削減対象 3 種以上明記（例: 巨大 JSON 例 / 出力強制句 / 形式テンプレ重複）
- 種別: doc-review

### TC-6: 既存 schemas 互換性（全 12 件、命名衝突なし）
- 入力:
  - `ls schemas/*.schema.json | wc -l`（変更前: 11、変更後: 15 を期待）
  - `git diff main -- schemas/c3-approval.schema.json schemas/c4-approval.schema.json schemas/handoff.schema.json schemas/pbi-input.schema.json schemas/plan.schema.json schemas/review-external.schema.json schemas/review-self.schema.json schemas/run-event.schema.json schemas/status.schema.json schemas/test-cases.schema.json schemas/todo.schema.json`
  - `grep -E "review-self|review-external" docs/ai/structured-outputs.md`
- 期待:
  - 既存 11 schema が変更なし（diff 出力空）
  - 新規 4 schema 追加（review-result / acceptance-result / mode-classification / handoff-summary）
  - structured-outputs.md に既存 review-self / review-external と新規 review-result の責務境界が明記
- 種別: 自動 + doc-review
- C-2 EX-04-01 対応

### TC-7: eval 引き継ぎ方針
- 入力: `grep -E "eval|PBI-116-05" docs/ai/structured-outputs.md`
- 期待: 「schema 準拠率を eval 対象に含める」旨の記述
- 種別: doc-review

## エッジケース

### TC-E1: review-result の phase 値
- 入力: `grep -A 5 "phase" schemas/review-result.schema.json | grep -E "C-1|C-2|V-1|V-3"`
- 期待: 4 phase すべて enum
- 種別: 自動

### TC-E2: review-result の decision 値
- 入力: `grep -A 5 "decision" schemas/review-result.schema.json | grep -E "PASS|WARN|FAIL"`
- 期待: 3 値すべて enum
- 種別: 自動

### TC-E3: handoff-summary 必須 6 要素
- 入力: `grep -E "要件適合|既知課題|V2|妥協点|引き継ぎ|テスト結果" schemas/handoff-summary.schema.json`
- 期待: 6 要素すべて反映
- 種別: 自動

## 自動化サマリ

| TC | 自動化 |
|----|------|
| TC-1〜TC-7 | 5 件自動、2 件 doc-review |
| TC-E1〜TC-E3 | 全件自動 |

自動化率: 8/10。
