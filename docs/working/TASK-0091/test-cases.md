# テストケース — TASK-0091 / #213
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | doc に plan_check/risk_check/done_check 責務表 + skill に同表 | 構造突合 |
| T2 | AC2 | schema に missing_items/risks/assumptions/done_criteria/next_actions 定義 | 構造突合 |
| T3 | AC3 | doc に Plan Health Score 最小内訳5軸 + schema score_breakdown | 構造突合 |
| T4 | AC4 | schema が JSON 妥当 + check_type/score/decision/summary required | 機械検証 |
| T5 | AC5 | bin/plangate plan-check --init/--validate が手動実行可（smoke）| 機械検証 |
| T6 | AC6 | doc に「Plan 状態として保存」方針（plan-quality-check.json）| 構造突合 |
| T7 | AC7 | doc/skill に heavy Gate/PR review/browser QA 非依存明記 + CLI が AI 非起動 | 構造突合 |
| T8 | AC8 | doc に gstack 参考思想留め・直接移植しない明記 | 構造突合 |
## Edge
- E1: skill が Rule 2 準拠（TASK-/PlanGate/特定FW 名なし）
- E2: decision は助言で人間承認の代替にしない（schema description + doc）
