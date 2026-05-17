# テストケース — TASK-0094 / #204
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | examples/eval-fixtures/ ディレクトリ存在 | ファイル存在 |
| T2 | AC2 | fixture 5 件以上（fixture.md を持つ dir）| 構造突合 |
| T3 | AC3 | 各 fixture.md に Scenario/Eval focus/Expected gate behavior/関連 eval aspect | 構造突合 |
| T4 | AC4 | scope-creep-trap/stale-plan-hash/failing-test-recovery が存在 | ファイル存在 |
| T5 | AC5 | plangatebench.md に bin/plangate eval 接続方針 + eval-runner.md 注記 | 構造突合 |
| T6 | AC6 | plangatebench.md に #196 整合（schema 非変更・補完）記載 + eval-comparison.schema.json 未変更 | 構造突合+diff |
| T7 | AC7 | plangatebench.md に fixture 追加ルール（6 項目）| 構造突合 |
## Edge
- E1: 各 fixture に「非実行・記述固定」注記（Non-goal 侵食防止）
- E2: fixture 名 kebab-case で重複なし
