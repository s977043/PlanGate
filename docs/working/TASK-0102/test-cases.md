# テストケース — TASK-0102 / #200 v2
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1/AC4 | reporting に _events_signals + from metrics_reporter import load_events・再実装なし | 構造突合 |
| T2 | AC2 | events.ndjson 不在で main 版と report.json 等価（2026-05-01..31 / 05-17..18）| in-place 等価 |
| T3 | AC3 | 合成 events: TASK-0095 v1=True / TASK-0090 v1=False,fix_loop=2 / observed 増 | smoke |
| T4 | AC5 | sh tests/run-tests.sh 68 passed 0 failed | テスト |
## Edge
- E1: precedence events>status.md>unknown（events 部分のみ有でも status.md 補完）
- E2: scope = reporting.py のみ（metrics_reporter/_paths/shell/bin 無変更）
