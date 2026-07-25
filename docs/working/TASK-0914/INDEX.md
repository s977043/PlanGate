# TASK-0914 INDEX

> Issue: [#914](https://github.com/s977043/plangate/issues/914)（P2 / bug / area:workflow）
> Mode: `high-risk` / `lite_eligible=false` / HO 非該当（`scripts/` 直下 + `tests/**`）
> 現在フェーズ: **C-3 Human 判断待ち**（B 生成 → C-2 2 レーン（major 7）→ 反映 → C-1 PASS → River Review（major 4）→ 反映）

| ファイル | 役割 | 状態 |
|---------|------|------|
| [`pbi-input.md`](./pbi-input.md) | A: PBI INPUT PACKAGE | ✅ 2026-07-25（PR #918 で main 実在） |
| [`plan.md`](./plan.md) | B: EXECUTION PLAN | ✅ 2026-07-25 |
| [`todo.md`](./todo.md) | B: EXECUTION TODO | ✅ 2026-07-25 |
| [`test-cases.md`](./test-cases.md) | B: テストケース定義 | ✅ 2026-07-25 |
| [`review-external.md`](./review-external.md) | C-2: 外部レビュー 2 レーン + River Review | ✅ WARN（C-2: major 7 / River: major 4）→ 全 24 件 reflected |
| [`review-self.md`](./review-self.md) | C-1: セルフレビュー（25 項目） | ✅ PASS（critical 0 / major 0） |
| [`current-state.md`](./current-state.md) | 現在状態スナップショット | ✅ |
| `approvals/c3.json` | C-3 承認記録 | ⬜ **Human 待ち**（`bin/plangate approve`。対話 TTY 必須・AI 実行不可） |
| `status.md` | フェーズ履歴 | ⬜ exec 開始時 |
| `evidence/` | 検証証跡（verification / test-runs） | ⬜ exec 時 |
| `handoff.md` | 完了時引き継ぎ | ⬜ |

## 関連

- 由来: TASK-0877 AC-6（F5 の別 issue 分離）+ C-2 コードベース整合レーン R-204
- 前提: `sh tests/run-tests.sh` ベースライン = **430 passed / 0 failed（exit 0）**（2026-07-25 実測・main `90c313d`）
- スコープ決定: **案 C**（R-204 = 判別式統一 + standalone env 無害化まで。exit code 伝播は別 issue）— 2026-07-25 Human 決定
- テスト: 新規 **14 TC**（TC-20〜30 / 32 / 33 / 34）+ 変異注入 **8 件**（M-1〜M-7 + M-6b）。目標 = 444 passed / 0 failed
- 受入基準: **AC-1〜AC-9**（pbi-input の 6 件 + AC-6 強化 + AC-7/8/9 追加。差分は plan「受入基準（確定版）」表）
