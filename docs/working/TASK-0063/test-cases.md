# TEST CASES: TASK-0063

| ID | AC | 検証 | 期待 |
|----|-----|------|------|
| TC-01 | hook 存在 | `ls scripts/hooks/check-metrics-privacy.sh` | exists + executable |
| TC-02 | events.ndjson staging 検出 | `PLANGATE_HOOK_FILES="docs/working/_metrics/events.ndjson" sh hook` | WARNING / strict で BLOCK |
| TC-03 | Forbidden field 検出 | bad-forbidden fixture で実行 | WARNING / strict で BLOCK |
| TC-04 | bypass | `PLANGATE_BYPASS_HOOK=1` で常時 exit 0 | exit 0 + "BYPASS" 出力 |
| TC-05 | hook unit tests | `sh tests/hooks/run-tests.sh` 全 PASS | 48 PASS |
| TC-06 | C-2 collector privacy | ta-09 で collector emit に forbidden なし | PASS |
| TC-07 | D-1 schema negative | ta-09 で schema.validate(forbidden) → ValidationError | PASS |
| TC-08 | doc 更新 | metrics-privacy.md §10 が「v8.6.0 実装済」に変更 | 該当文字列存在 |
| TC-09 | priority labels | gh label list で priority:P0〜P3 存在 | 4 件存在 |
| TC-10 | 既存 regress | tests/run-tests.sh 全 PASS | 34 PASS |
