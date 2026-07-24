# TASK-0877 INDEX

> Issue: [#877](https://github.com/s977043/plangate/issues/877)（P1 / bug / area:workflow）
> Mode: `high-risk` / `lite_eligible=false` / HO 非該当
> 現在フェーズ: **C-3 Human 判断待ち**（B → C-1 PASS → C-2 反映 → 簡易 C-1 PASS → C-3' run-027 = HUMAN_ESCALATED）

| ファイル | 役割 | 状態 |
|---------|------|------|
| [`pbi-input.md`](./pbi-input.md) | A: PBI INPUT PACKAGE | ✅ 2026-07-20 |
| [`plan.md`](./plan.md) | B: EXECUTION PLAN | ✅ 2026-07-25 |
| [`todo.md`](./todo.md) | B: EXECUTION TODO | ✅ 2026-07-25 |
| [`test-cases.md`](./test-cases.md) | B: テストケース定義 | ✅ 2026-07-25 |
| [`review-self.md`](./review-self.md) | C-1: セルフレビュー（25 項目） | ✅ PASS |
| [`review-external.md`](./review-external.md) | C-2: 外部レビュー 2 レーン | 🔄 実施中 |
| [`current-state.md`](./current-state.md) | 現在状態スナップショット | ✅ |
| `approvals/c3.json` | C-3 承認記録 | ⬜ Human 待ち |
| `ai-loop-runs/` | C-3' 裁定 record | ⬜ |
| `status.md` | フェーズ履歴 | ⬜ exec 開始時 |
| `handoff.md` | 完了時引き継ぎ | ⬜ |

## 関連

- 実行方式: ai-loop（`/ai-loop-workflow run TASK-0877`）— rollout-policy §2 の carve-out 外で eligible
- 前提: `sh tests/run-tests.sh` ベースライン = **422 passed / 0 failed（exit 0）**（2026-07-25 実測・main ee9a1b5）
