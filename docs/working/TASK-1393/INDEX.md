# TASK-1393 INDEX

> 最終更新: 2026-09-29（PR #1407 は 2026-09-28 22:39Z に main へ merge。C-3 承認記録は未発行のまま）
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 の immutable VerificationResult / FailureRecord と、観測済みの事実だけから Decision（continue / repair / replan / stop と Terminal Outcome）を導く pure Decision Engine を、Delivery 第一リリース境界に必要な最小範囲で実装する（#1393、親 #894）。

## 現在のフェーズ

C-3 待ち

> Revision 2.5。C-2 は R1 / R2 の 2 ラウンドで収束（R2 は新クラス 0）。簡易 C-1 PASS（R-071 は Human y で反映済み）。C-3 承認記録は未発行。
> Mode = high-risk。C-3 は Human 同期。

## 次のアクション

Human の C-3（同期）。exec 前に Preflight PF-1〜PF-8。

> 2026-09-29 追記（範囲レビュー）: plan が義務を負わせている #1391 / #1392 / #1395 は、PR #1402 の merge（`Closes`）で 2026-09-29 00:01Z に CLOSED（COMPLETED）になった。#1392 の plan（#1406 のモデル B）は未実装のまま。plan の Dependency を「#1402 で実装済み（file:行）」と「未実装 → 新しい issue」に振り分け直すまで、C-3 の前提が崩れている（Human 判断）。plan.md 本文の Rev 2.5 の文言更新は `PLANGATE_HOOK_TASK=TASK-1393` のセッションで行う。

依存（リリース条件）: #1392 は (state, action) からの遷移導出と `decision_made` の 4 キー読み取りを採用済み（#1406 `e4aaeb91`）。stream 束縛は #1422（B-1〜B-12 は issue 記載、B-1 の表記と B-13 は追加提案。担当割り当ては Human）。#1395 の budget。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 実行計画（C-3 未承認） |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義（DI / DV / DD / DP / PR / AV / DC / IT） |
| review-self.md | C-3, review | C-1 結果（2026-09-25 再実行を含む） |
| review-external.md | C-3, review | 指摘 R-001〜R-080（C-2 R1 / R2）、回避クラス台帳と監査表 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

実装は新規 pure module（VerificationResult / FailureRecord / assess_progress / decide / decision_to_event_draft）とそのテスト。I/O・#1392 storage・GitHub API・merge API は持たない。
