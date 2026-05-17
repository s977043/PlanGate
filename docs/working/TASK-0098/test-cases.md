# テストケース — TASK-0098 / #200
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | report --from --to で期間 report md/json 生成・from>to は exit2 | smoke |
| T2 | AC2 | c3/c4/eval-result/keep-rate/status 集計（C-3/C-4/V-1/blocker/keep）| smoke |
| T3 | AC3 | retrospective 貼付可能 Markdown（TASK 内訳表 + サマリ）| 構造突合 |
| T4 | AC4 | docs/ai/reporting.md §4 運用手順 | 構造突合 |
| T5 | AC5 | retrospective-template.md に AI harness improvement 用の問い | 構造突合 |
| T6 | AC6 | report に「次の harness improvement PBI 候補」抽出指針 | 構造突合 |
## Edge
- E1: fix_loop が日付（2026 等）を誤集計しない（上限50・非日付）
- E2: advisory/C-3・C-4 非緩和が report/doc/テンプレに明記・keep-rate 無→'-'
