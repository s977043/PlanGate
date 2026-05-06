# EXECUTION PLAN: TASK-0065 (v8.6.0 PR4)

## Goal
baseline 正式化 — schema による形式保証 + 自動再生成スクリプト + テスト。

## Mode
high-risk

## Approach
1. schemas/eval-baseline.schema.json 新規（draft-2020-12、$defs/task / verdictOrNa）
2. scripts/baseline-snapshot.py 新規（eval-runner.py を subprocess で叩き、結果を集約）
3. tests/extras/ta-09-metrics.sh に D-2 + C-3 = 3 cases 追加
4. docs/ai/eval-baselines/2026-05-04-baseline.md に §7.1 §8 加筆

## Files
- schemas/eval-baseline.schema.json (new)
- scripts/baseline-snapshot.py (new, executable)
- tests/extras/ta-09-metrics.sh (修正)
- docs/ai/eval-baselines/2026-05-04-baseline.md (修正)
- docs/working/TASK-0065/* (new)

## Test
- L-0: shellcheck / markdown lint
- V-1: 8 AC 突合
- 自動: tests/run-tests.sh 39 → 42
