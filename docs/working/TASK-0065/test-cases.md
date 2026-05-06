# TEST CASES: TASK-0065

| ID | AC | 検証 |
|----|-----|------|
| TC-01 | schema 存在 | `ls schemas/eval-baseline.schema.json` |
| TC-02 | 既存 baseline 妥当 | jsonschema で 2026-05-04-baseline.json validate |
| TC-03 | snapshot --dry-run 動作 | TASK-0059 で実行して schema 妥当 JSON を出力 |
| TC-04 | snapshot --out 書き込み | tmp file に書き込み確認（手動） |
| TC-05 | privacy §4 (negative) | task に file_path を追加した baseline は schema reject |
| TC-06 | doc 更新 | 2026-05-04-baseline.md §7.1 / §8 に記載 |
| TC-07 | 既存 regress | tests/run-tests.sh 39 → 42 |
