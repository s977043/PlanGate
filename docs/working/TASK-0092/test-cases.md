# テストケース — TASK-0092 / #196
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | --harness-compare で baseline↔target 比較 MD/JSON 生成 | smoke |
| T2 | AC2 | 出力に release_blocker_summary + delta.release_blocker_status | 構造突合 |
| T3 | AC3 | per-target に latency_cost/fix_loop_count/hook_violation_count/v1_first_pass | 構造突合 |
| T4 | AC4 | harness_metadata に profile/prompt_rev/workflow_rev | 構造突合 |
| T5 | AC5 | 代表 TASK 3 件（TASK-0087/0088/0089）で task_count=3 | smoke |
| T6 | AC6 | eval-runner.md に「ハーネス変更比較」運用手順 | 構造突合 |
| T7 | AC7 | baseline-file 既定が PBI-HI-000 baseline + template に接続記載 | 構造突合 |
## Edge
- E1: 既存 eval（通常/--baseline/--dogfood）非破壊（ast.parse + 通常 eval smoke）
- E2: 生成 eval-comparison.json が schema validate PASS
