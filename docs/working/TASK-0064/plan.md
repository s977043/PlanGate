# EXECUTION PLAN: TASK-0064 (v8.6.0 PR3)

## Goal
metrics 自動化進化 — hook_violation と pr_created を自動 emit。

## Mode
high-risk

## Approach
1. metrics_collector.py に HOOK_NAME_TO_ID / HOOK_LEVEL_TO_RESULT 定数を追加
2. derive_hook_events(task_id) を実装（audit log を TSV パースして filter + map）
3. derive_pr_event(task_id, handoff_path) を実装（git log -1 で subject から (#NN) 抽出）
4. derive_events() の末尾で両者を呼び出して merge
5. ta-09 に A-1 系 5 test cases (auto-derive / hook_id mapping / result mapping / events valid / schema 妥当)
6. docs/ai/metrics.md §3.2 表 + §3.3 / §3.4 を更新

## Files
- scripts/metrics_collector.py (修正)
- tests/extras/ta-09-metrics.sh (修正、+5 cases)
- docs/ai/metrics.md (修正)
- docs/working/TASK-0064/* (new)

## Test
- L-0: shellcheck / markdown lint
- V-1: 9 AC 突合
- 自動: tests/run-tests.sh 34→39
