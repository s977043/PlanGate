# TEST CASES: TASK-0062 (PBI-HI-001 Metrics v1)

| ID | AC (Issue #195) | 検証 | 期待 |
|----|----------------|------|------|
| TC-01 | schema 存在 | `ls schemas/plangate-event.schema.json` | exists |
| TC-02 | append-only NDJSON 記録 | `bin/plangate metrics TASK-XXXX --collect` 後に events.ndjson に追記 | 行数増加 |
| TC-03 | TASK summary CLI | `bin/plangate metrics TASK-XXXX --report` | summary 表示 |
| TC-04 | hook violation / C-3 / V-1 / C-4 集計 | reporter 出力に各カウント | reported |
| TC-05 | 既存 workflow 不影響 | `tests/run-tests.sh` 全 PASS | PASS |
| TC-06 | 運用手順 doc | `ls docs/ai/metrics.md` + 内容に CLI 使用例 + privacy 言及 | exists |
| TC-07 | baseline 互換 | metrics.md §6 で 2026-05-04-baseline.json とのマッピング表 | exists |
| TC-A | schema validation | jsonschema で events.ndjson 全行検証 | 全件 valid |
| TC-B | privacy 準拠 | events.ndjson に file path / stack trace / prompt が含まれない | unwritten |
| TC-C | gitignore | `git check-ignore docs/working/_metrics/events.ndjson` → 除外 | ignored |
