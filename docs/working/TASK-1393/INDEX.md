# TASK-1393 INDEX

> 最終更新: 2026-09-25 20:40
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 の immutable VerificationResult / FailureRecord と、観測済みの事実だけから Decision（continue / repair / replan / stop と Terminal Outcome）を導く pure Decision Engine を、Delivery 第一リリース境界に必要な最小範囲で実装する（#1393、親 #894）。

## 現在のフェーズ

C-2

> Revision 2.3（C-2 R1 の R-055〜R-069 を反映、簡易 C-1 PASS）。R-055（DENIED + FAIL）と R-058（#1402 の decision_core との関係）は Human 判断待ち。C-2 R2 は未実施。
> Mode = high-risk。C-2 は外部レビューとしては未実施（敵対レビューは独立エージェント）。

## 次のアクション

Human 判断（R-055 / R-058）→ 反映 → C-2 R2 → Human の C-3（同期）。`approvals/c3.json` は未発行。

依存（リリース条件）: #1392 に依頼済み（(state, action) からの遷移導出 / decided_in_state 照合 / `decision_made.event_seq == input_last_event_seq + 1`、PR #1406 コメント。CAS 依頼は +1 規則に差し替え済み）。stream 束縛は #1422（B-1〜B-7 は issue 記載、B-8〜B-11 は追加提案で未反映。担当割り当ては Human）。#1395 の budget。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 実行計画（C-3 未承認） |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義（DI / DV / DD / DP / PR / AV / DC / IT） |
| review-self.md | C-3, review | C-1 結果（2026-09-25 再実行を含む） |
| review-external.md | C-3, review | 指摘 R-001〜R-069（C-2 R1 を含む）、回避クラス台帳と監査表 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

実装は新規 pure module（VerificationResult / FailureRecord / assess_progress / decide / decision_to_event_draft）とそのテスト。I/O・#1392 storage・GitHub API・merge API は持たない。
