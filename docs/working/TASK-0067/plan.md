# EXECUTION PLAN: TASK-0067

## Goal
v8.6.0 機能をワークフロー成果物 + reporter + AI agent 入口に統合。

## Mode
high-risk

## Approach
1. metrics_reporter.py summarize() に task_to_mode index と by_mode bucket
2. render_text() に By mode 節
3. metrics_collector.py mode regex 強化（後方互換、3 形式対応）
4. handoff template §7 / current-state template §Metrics スナップショット
5. CLAUDE.md v8.6.0 セクション
6. metrics.md §3.5 / §3.6 加筆
7. ta-09 +2 cases

## Files
- scripts/metrics_reporter.py (修正)
- scripts/metrics_collector.py (修正)
- docs/working/templates/handoff.md (修正)
- docs/working/templates/current-state.md (修正)
- CLAUDE.md (修正)
- docs/ai/metrics.md (修正)
- tests/extras/ta-09-metrics.sh (修正)
- docs/working/TASK-0067/* (新規)

## Test
- 自動: tests/run-tests.sh 46 → 48
- 手動: --aggregate text + --json で by_mode 確認
