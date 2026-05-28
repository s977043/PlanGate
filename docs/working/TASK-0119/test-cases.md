# TASK-0119 TEST CASES

| AC | TC |
|----|-----|
| AC-1 noise 検知 + exit 1 | TC-01/02 |
| AC-2 TASK-0113 重複回避 | TC-03 |
| AC-3 allowlist | TC-04 |
| AC-4 doc | TC-05 |
| AC-5 ta-22 | TC-06 |
| AC-6 regression | TC-07 |

| ID | 内容 | 期待 |
|----|------|------|
| TC-01 | skip-log 未追認 staged → 検知 | exit 1 |
| TC-02 | 他 TASK eval-result staged → 検知 | exit 1 |
| TC-03 | TASK-0113 hook と共存 (両方発火 or 統合) | 重複なし |
| TC-04 | allowlist marker でスキップ | exit 0 |
| TC-05 | doc 主要 section | grep 該当 |
| TC-06 | ta-22 dispatcher 認識 | PASS |
| TC-07 | 既存テスト regression なし | 全 PASS |
