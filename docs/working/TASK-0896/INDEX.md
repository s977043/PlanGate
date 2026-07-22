# TASK-0896 INDEX

> Issue: [#896](https://github.com/s977043/plangate/issues/896)（P1）refactor(ai-loop): 検証ロジックの共通契約層化 — 定数/hash/snapshot三つ組照合の重複解消
> 関連 EPIC: #870（#873/#874 前の基盤整理）/ Mode: **high-risk**（人間 C-3 必須・非 HO）

## 現在フェーズ

**C-1 PASS → C-2 完了（R-001〜R-010 確定反映済み）→ C-3 Human 承認待ち**（2026-07-22）

## ファイル一覧

| ファイル | 状態 |
|---------|------|
| [pbi-input.md](./pbi-input.md) | ✅ PR #898 merge 済み（作成前レビュー完了） |
| [plan.md](./plan.md) | ✅ B-3 生成済み |
| [todo.md](./todo.md) | ✅ B-3 生成済み |
| [test-cases.md](./test-cases.md) | ✅ B-3 生成済み |
| [current-state.md](./current-state.md) | ✅ |
| [decision-log.jsonl](./decision-log.jsonl) | ✅ 初期化済み |
| [review-self.md](./review-self.md) | ✅ C-1 PASS（WARN 1）+ 簡易 C-1 PASS |
| [review-external.md](./review-external.md) | ✅ C-2 2 レーン完了（R-001〜R-010 集約・裁定済み） |
| approvals/c3.json | ⏳ C-3（Human） |

## C-3 で人間が確定する論点

1. **#873（P0）との実装順**: (a) #896 逐次先行 or (b) #873 と並行（c3_contract 先行 merge → #873 rebase）
2. EPIC #870 本体への位置づけ追記コメントの要否
