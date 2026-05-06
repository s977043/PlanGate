# TEST CASES: TASK-0067

| ID | AC | 検証 |
|----|----|------|
| TC-01 | handoff template §7 | grep "Metrics summary" docs/working/templates/handoff.md |
| TC-02 | current-state template | grep "Metrics スナップショット" docs/working/templates/current-state.md |
| TC-03 | reporter text by_mode | --aggregate 出力に "By mode (H-3)" |
| TC-04 | reporter json by_mode | --json 出力に "by_mode" キー |
| TC-05 | collector mode regex | TASK-0059 / 0061 で mode=light が抽出される |
| TC-06 | CLAUDE.md v8.6.0 section | grep "v8.6.0 Metrics & Governance" CLAUDE.md |
| TC-07 | metrics.md 加筆 | §3.5 §3.6 存在 |
| TC-08 | tests +2 cases | ta-09 で H-3 text / H-3 json |
| TC-09 | 既存 regress | tests/run-tests.sh 46 → 48 |
