# TASK-0043 INDEX

## 基本情報

| 項目 | 値 |
|------|---|
| TASK ID | TASK-0043 |
| 子 PBI ID | PBI-116-03 |
| Issue | [#119](https://github.com/s977043/plangate/issues/119) |
| Title | Prompt assembly を Core / Phase / Risk / Model Adapter に分層化する |
| 親 PBI | [PBI-116](../PBI-116/parent-plan.md) |
| Mode | **high-risk** |
| Phase | **EXEC-READY**（C-1 / C-2 完了、Child C-3 APPROVED、exec 開始可） |
| 起票 | 2026-04-30 |

## 現在のフェーズ

⏳ Child C-3 ゲート待ち（C-1 PASS、C-2 Codex は次セッション推奨）

## ファイル一覧

| ファイル | 状態 |
|---------|------|
| pbi-input.md / INDEX / current-state | ✅ |
| plan.md / todo.md / test-cases.md | ✅ |
| review-self.md | ✅ C-1 PASS |
| review-external.md | ⏳ C-2 Codex（high-risk のため必須）|
| approvals/c3.json | ⏳ Child C-3 |
| status.md / handoff.md / evidence | ⏳ exec / WF-05 時 |

## 依存関係

- **Depends on**: PBI-116-01 ✅ done + PBI-116-02 ✅ done（両方マージ済）
- 後続: PBI-116-05 (Eval Cases) の主要前提

## 並行関係

- Phase 3 単独実行（並行なし）
- PBI-116-04 ✅ / PBI-116-06 ✅ とは独立だが、Prompt Assembly が両者を統合する設計層

## ネクストアクション

1. 本 PR C-4
2. C-2 Codex 外部AIレビュー（high-risk のため必須）
3. Child C-3 ゲート判断 👤
4. exec 開始
