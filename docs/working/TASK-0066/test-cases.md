# TEST CASES: TASK-0066

| ID | AC | 検証 |
|----|----|------|
| TC-01 | doctor v8.6.0 section | bin/plangate doctor 出力に "v8.6.0 Metrics & Privacy" 含む |
| TC-02 | doctor events.ndjson gitignore | "is .gitignore-d" 文言 |
| TC-03 | doctor EH-8 executable | "EH-8 hook is executable" |
| TC-04 | --validate PASS | valid events で "all events valid" |
| TC-05 | --validate FAIL | forbidden field 入り events で exit 1 |
| TC-06 | schema_mapping J-1 | grep eval-baseline.schema.json scripts/schema_mapping.py |
| TC-07 | validate-schemas integration | python3 scripts/validate-schemas.py docs/ai/eval-baselines/2026-05-04-baseline.json → PASS |
| TC-08 | CI workflow 存在 | ls .github/workflows/metrics-privacy.yml |
| TC-09 | tests +4 cases | ta-09 で H-1×2 / J-1 / F-3 |
| TC-10 | 既存 regress | tests/run-tests.sh 42 → 46 |
