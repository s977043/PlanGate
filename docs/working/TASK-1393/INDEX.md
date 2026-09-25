# TASK-1393 INDEX

> 最終更新: 2026-09-25 13:30
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 の immutable VerificationResult / FailureRecord と、観測済みの事実だけから Decision（continue / repair / replan / stop と Terminal Outcome）を導く pure Decision Engine を、Delivery 第一リリース境界に必要な最小範囲で実装する（#1393、親 #894）。

## 現在のフェーズ

BLOCKED

> blocker: 設計未収束（C-1 は FAIL（未収束・上限ラウンド到達））。Human 設計判断に沿った Revision 2 に敵対レビュー Rev2-R1〜R3 を実施し、新クラスが 1 / 3 / 1 件。freshness モデルは安定したが R-037〜R-041 が open。owner: human。unblock_condition: Human が「打ち切り（残存脅威として明記）」か「局所是正 + 追加ラウンド」かを判断する。
> Mode = high-risk。C-2 は外部レビューとしては未実施（敵対レビューは独立エージェント）。

## 次のアクション

Human の判断 → （追加ラウンドなら R-037〜R-041 を是正して Rev2-R4）→ C-1 再実行 → C-2 R1 / R2 → Human の C-3（同期）。`approvals/c3.json` は未発行。

依存（リリース条件）: #1392 に 3 件依頼済み（(state, action) からの遷移導出 / decided_in_state 照合 / event_seq の CAS、PR #1406 コメント）。#1391 の `plan_contract_bound` に `loop_contract_ref` を束縛する件は所有者未定。#1395 の budget。

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
