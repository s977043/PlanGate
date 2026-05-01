# EXECUTION TODO: TASK-0049 / Issue #156

> Mode: **high-risk**

## Tasks

### 準備
- [x] PBI INPUT
- [x] plan + test-cases

### 実装
- [x] schemas/eval-result.schema.json
- [x] scripts/eval-runner.py
- [x] bin/plangate eval wrapper
- [x] tests/fixtures/eval-runner/sample-task/（schema 適合 c3.json + 6 要素 handoff）
- [x] tests/run-tests.sh TA-07
- [x] docs/ai/eval-runner.md

### 検証
- [x] sh tests/run-tests.sh → 13 PASS
- [x] sh bin/plangate eval TASK-0044 --no-write で実 PBI 動作（既知制限の通り schema fail）
- [x] handoff.md

### 完了
- [x] commit + push + PR
- [ ] CI 緑確認 → C-4
