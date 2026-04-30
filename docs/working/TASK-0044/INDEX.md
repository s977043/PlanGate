# TASK-0044 INDEX

## 基本情報

| 項目 | 値 |
|------|---|
| TASK ID | TASK-0044 |
| 子 PBI ID | PBI-116-05 |
| Issue | [#121](https://github.com/s977043/plangate/issues/121) |
| Title | Model migration Eval cases 追加（最新モデル移行の回帰確認） |
| 親 PBI | [PBI-116](../PBI-116/parent-plan.md) |
| Mode | standard |
| Phase | **C3-WAIT**（preparatory + plan/todo/test-cases + C-1 完了）|
| **PBI-116 最後の子 PBI** | Phase 4、Parent Integration Gate 直前 |
| 起票 | 2026-04-30 |

## 現在のフェーズ

⏳ Child C-3 ゲート待ち

## 依存関係

全子 PBI に依存（**Phase 1〜3 すべて main マージ済**）:
- ✅ PBI-116-01 done（core-contract.md）
- ✅ PBI-116-02 done（model-profiles.yaml + schema）
- ✅ PBI-116-03 done（prompt-assembly.md + 7 contracts + 4 adapters）
- ✅ PBI-116-04 done（structured-outputs.md + 4 schema）
- ✅ PBI-116-06 done（responsibility-boundary / tool-policy / hook-enforcement）

→ 本 PBI は **PBI-116 統合検証** の最終 phase

## ファイル一覧

| ファイル | 状態 |
|---------|------|
| pbi-input.md / INDEX / current-state | ✅ |
| plan.md / todo.md / test-cases.md | ✅ |
| review-self.md | ✅ C-1 PASS |
| review-external.md | ⏳ C-2 Codex |
| approvals/c3.json | ⏳ Child C-3 |
| status.md / handoff.md / evidence | ⏳ exec / WF-05 時 |

## ネクストアクション

1. 本 PR C-4
2. C-2 Codex 外部AIレビュー
3. Child C-3 ゲート判断 👤
4. exec → 子 PR → Child C-4
5. **Parent Integration Gate**（PBI-116 完了判定）👤
