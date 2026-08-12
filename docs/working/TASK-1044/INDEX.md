# TASK-1044 INDEX

> Issue: [#1044](https://github.com/s977043/plangate/issues/1044)（P2 / bug）
> extras bootstrap の harness 誤判定（3 env 漏出 + 直接実行）で silent pass になる経路の封鎖

## 現在フェーズ

**B 完了（plan パッケージ + C-1 済）→ C-2 / C-3 待ち**（mode: high-risk = 人間 C-3 必須）

## ファイル

| ファイル | 内容 |
|---|---|
| [pbi-input.md](pbi-input.md) | PBI INPUT PACKAGE（Context / Scope / 受入基準 AC-1〜7 / Risks） |
| [plan.md](plan.md) | EXECUTION PLAN（**### Mode resolution v2 = bootstrap 述語の新正本** / F-3 是正 / Mode 判定） |
| [todo.md](todo.md) | EXECUTION TODO（T-01〜T-10 / H-01〜02） |
| [test-cases.md](test-cases.md) | TC-30〜36 + EV-1〜4（変異注入） |
| [review-self.md](review-self.md) | C-1 セルフレビュー（17 項目） |
| [current-state.md](current-state.md) | 現在状態スナップショット |
| [decision-log.jsonl](decision-log.jsonl) | 判断履歴（append-only） |

## キーポイント

- 再実測済み（2026-08-12 / main `48f6971`）: helper 欠落 = dash/zsh rc=0、
  **helper 存在でも 4 シェル rc=0**（実測 2 / issue 未記載の拡大所見）
- 修正 = harness 判定へ direct-exec ガード（`${0##*/}` の `ta-*.sh` glob）を AND。
  issue 案のファイル名 literal はバイト一致 DoD を壊すため不採用。
  **`$0` 評価は bootstrap トップレベル 1 回のみ・helper は変数消費形**
  （zsh FUNCTION_ARGZERO で関数内 `$0` = 関数名 → 関数内評価はガード不発 —
  river-review F-1 是正、変数消費形を 4 シェル再実測済み）
- F-3（finalize 既定値非対称）は **In scope**（fail-closed 化。Q-1 = C-3 裁定事項）
- 正本管理: TASK-0921 plan「### Mode resolution」は不変のまま、本 plan
  「### Mode resolution v2」が新正本
