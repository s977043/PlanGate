# TEST CASES: TASK-0061 (PBI-HI-000)

| ID | AC | 検証 | 期待 |
|----|-----|------|------|
| TC-01 | baseline 対象 TASK 3 件以上 | baseline.md §3 表 | 5 件 |
| TC-02 | 各 TASK で eval 結果保存 | `ls docs/working/TASK-XXXX/eval-result.{md,json}` 各 5 件 | 全 10 ファイル存在 |
| TC-03 | 8 観点 eval 結果が MD/JSON | baseline.md §4 表 + baseline.json `tasks[]` | 両方存在 |
| TC-04 | release blocker 有無明記 | baseline.md §4 / json `release_blocker_count` | 各 TASK に記録 |
| TC-05 | hook / C-3 / C-4 / V-1 / handoff 現状 | baseline.md §5 | 5 サブセクション存在 |
| TC-06 | 後続変更との比較可能形式 | baseline.md §6 + json schema 提示 | 比較表存在 |
