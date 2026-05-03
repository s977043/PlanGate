# EXECUTION PLAN: TASK-0061 (PBI-HI-000)

## Goal
v8.5.0 直後の baseline を固定し、後続改善の比較起点を作る。

## Mode
light

## Approach
1. 代表 TASK 5 件選定: TASK-0050 / 0054 / 0055 / 0056 / 0057
2. 各 TASK で `bin/plangate eval <TASK>` 実行 → eval-result.{md,json} 生成
3. `docs/ai/eval-baselines/2026-05-04-baseline.{md,json}` に集約
4. 比較ポイントを doc 化

## Files
- `docs/ai/eval-baselines/2026-05-04-baseline.md`（新規）
- `docs/ai/eval-baselines/2026-05-04-baseline.json`（新規）
- `docs/working/TASK-005[0,4,5,6,7]/eval-result.{md,json}`（自動生成、副作用）

## Testing
- L-0 markdown lint
- V-1 受入基準 6 項目突合
