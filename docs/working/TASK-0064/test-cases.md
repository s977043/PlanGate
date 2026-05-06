# TEST CASES: TASK-0064

| ID | AC | 検証 |
|----|----|------|
| TC-01 | hook_violation 自動 emit | fixture audit log で 2 violations 抽出 |
| TC-02 | filter (PASS/BYPASS/other-task 除外) | 期待 2 件のみ |
| TC-03 | hook_id mapping | check-c3-approval → EH-2 |
| TC-04 | result mapping | VIOLATION→block, WARNING→warn |
| TC-05 | pr_created 自動抽出 | TASK-0061 で pr_number=208 抽出 |
| TC-06 | schema 妥当 | hook_violation events を jsonschema.validate |
| TC-07 | privacy: message column 除外 | events に message 列が含まれない |
| TC-08 | git なし / commit なしで silent skip | エラーなし |
| TC-09 | 既存テスト regress なし | tests/run-tests.sh 34 → 39 |
