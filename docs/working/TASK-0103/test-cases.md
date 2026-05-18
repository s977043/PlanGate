# テストケース — TASK-0103 / #281
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | _is_test_hook_row 構造化判定（HOOKTEST/tests/fixtures）+ reporting.md §4-bis 明文化 | 構造突合 |
| T2 | AC1 | --exclude-test-hooks で hook violation 減少（3340→1082）・`-` 行残置 | smoke |
| T3 | AC2 | --tasks で対象 TASK 限定（2件）・空入力 exit2・未指定=従来 | smoke |
| T4 | AC3 | opt-in 未指定で main 版と 2 期間 in-place 等価 | 機械等価 |
| T5 | AC4 | run-tests.sh 68 passed 0 failed | テスト |
## Edge
- E1: `-`/実 TASK-xxxx 行は除外されない（実 violation 隠蔽なし）
- E2: scope=reporting.py+reporting.md のみ・#282/schema/period 不変
