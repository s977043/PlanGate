# TEST CASES — TASK-0044 (PBI-116-05 / Issue #121)

## 受入基準 → テストケース

| AC | TC | 種別 |
|----|----|----|
| AC-1: eval-plan.md | TC-1 | 自動 + doc-review |
| AC-2: 8 観点 eval cases (7 ファイル+) | TC-2 | 自動 |
| AC-3: 比較表テンプレ | TC-3 | 自動 + doc-review |
| AC-4: release blocker 基準 | TC-4 | 自動（grep） |
| AC-5: Model Profile 変更時 checklist | TC-5 | doc-review |
| AC-6: eval 結果ベース判断方針 | TC-6 | doc-review |
| AC-7: 4 層独立検証方針 | TC-7 | 自動（grep） |
| AC-8: schema 準拠率 eval 対象化 | TC-8 | 自動（grep） |

## TC

### TC-1: eval-plan.md 存在 + 主要セクション
```bash
ls docs/ai/eval-plan.md && grep -E "^## " docs/ai/eval-plan.md
```
期待: 主要セクション（観点 / 合格基準 / Model Profile / 4 層 / schema）含む

### TC-2: 8 観点 eval cases
```bash
ls docs/ai/eval-cases/*.md | wc -l
```
期待: **8 件**（8 観点と完全一致、C-2 Gemini 対応）

### TC-3: eval-comparison-template.md 存在
```bash
ls docs/ai/eval-comparison-template.md
```

### TC-4: release blocker 基準
```bash
grep -E "release blocker" docs/ai/eval-plan.md
```
期待: verification honesty / scope discipline の 2 件以上明示

### TC-5: Model Profile 変更時 checklist
docs/ai/eval-plan.md にチェックリストあり

### TC-6: eval 結果ベース判断
```bash
grep -E "感覚|eval 結果" docs/ai/eval-plan.md
```

### TC-7: 4 層独立検証
```bash
grep -E "base_contract|phase_contract|risk_mode_contract|model_adapter" docs/ai/eval-plan.md
```
期待: 4 層すべて言及

### TC-8: schema 準拠率
```bash
grep -E "schema 準拠率|95%" docs/ai/eval-plan.md
```
期待: 95% 基準明示

## エッジケース

### TC-E1: 行数チェック
```bash
wc -l docs/ai/eval-plan.md docs/ai/eval-cases/*.md docs/ai/eval-comparison-template.md
```
期待: 各 50 行以下、合計 500 行以下

### TC-E2: 既存 docs/ai 衝突なし
```bash
ls docs/ai/eval-cases/ docs/ai/eval-plan.md docs/ai/eval-comparison-template.md
```
期待: サブディレクトリ + 新規ファイルで既存と衝突なし

## 自動化サマリ

10 TC 中 8 件自動可能。
