# TASK-1393 INDEX

> 最終更新: 2026-09-25 11:40
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 の immutable VerificationResult / FailureRecord と、観測済みの事実だけから Decision（continue / repair / replan / stop と Terminal Outcome）を導く pure Decision Engine を、Delivery 第一リリース境界に必要な最小範囲で実装する（#1393、親 #894）。

## 現在のフェーズ

BLOCKED

> blocker: 設計未収束（C-1 は FAIL（設計未収束））。敵対レビュー R1→R2→R3 で毎ラウンド新クラスが出た（review-external R-015〜R-021 が open）。owner: human。unblock_condition: Human が DecisionInput 契約の設計（review-external「R3 の設計提案」）を判断する。
> Mode = high-risk。C-2 は外部レビューとしては未実施（R2 / R3 は是正差分への独立エージェントの敵対レビュー）。

## 次のアクション

Human の設計判断 → plan の再構成 → C-1 再実行 → C-2 R1 / R2 → Human の C-3（同期）。`approvals/c3.json` は未発行。

未決（Human）:
- DecisionInput 契約を state 別の 1 つの値にまとめ step 0 で一括検査するか（R-015 / R-017）
- Decision と実際の遷移の一致を #1391 / #1392 / #1393 のどこで検査するか（R-016）
- [P1] `HUMAN_REQUIRED` を `WAITING_HUMAN` へ遷移させ記録する所有者（plan「Policy scope」）
- [P1] budget 系の Stop Reason 無しで第一リリースに出してよいか（plan「Out of scope: budget and repetition」、R-021）

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 実行計画（C-3 未承認） |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義（DC-01〜DC-22） |
| review-self.md | C-3, review | C-1 結果（2026-09-25 再実行を含む） |
| review-external.md | C-3, review | 指摘 R-001〜R-006 と監査表。C-2 R1 は未実施 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

実装は新規 pure module（VerificationResult / FailureRecord / assess_progress / decide / decision_to_event_draft）とそのテスト。I/O・#1392 storage・GitHub API・merge API は持たない。
