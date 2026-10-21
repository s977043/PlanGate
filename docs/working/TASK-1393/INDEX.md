# TASK-1393 INDEX

> 最終更新: 2026-10-21 14:50（plan Revision 2.6 = R-081 / R-082 の確定反映。C-3 再発行待ち）
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 の immutable VerificationResult / FailureRecord と、観測済みの事実だけから Decision（continue / repair / replan / stop と Terminal Outcome）を導く pure Decision Engine を、Delivery 第一リリース境界に必要な最小範囲で実装する（#1393、親 #894）。

## 現在のフェーズ

C-3 待ち

> Revision 2.6（2026-10-21）。Human 決定 R-081（PF-1 に ratchet.py / TA-92）と R-082（#1422 部分凍結、issuecomment-6308427967）を確定反映。簡易 C-1 PASS（Unknowns WARN: B-8 / B-13 未凍結）。
> **既存の c3.json（Revision 2.5、`plan_hash` `799c8526…`）は改訂後 plan（sha256 `ec2a0db8…`）と一致しない＝Human の再発行待ち**。AI は c3.json を発行しない。Mode = high-risk。
> exec 前の依存（#1391 / #1392 / #1395 / #1422 の owner 実装、PF-2〜PF-8）は [dependency-reconciliation.md](dependency-reconciliation.md) のとおり未解消。C-3 再発行は BLOCKED 解消を意味しない。

## 次のアクション

Human が Revision 2.6 に対する c3.json を再発行 → exec 前に Preflight PF-1〜PF-8（[dependency-reconciliation.md](dependency-reconciliation.md) の owner/残差）。

依存（リリース条件）: #1392 は (state, action) からの遷移導出と `decision_made` の 4 キー読み取りを**方針として**採用済み（#1406 `e4aaeb91`。model-B の実装・`state_transitioned` は未完で、todo.md の該当行は未チェックのまま。dependency-reconciliation.md の #1392 行を参照）。stream 束縛は #1422（B-1〜B-12 は issue 記載、B-1 の表記と B-13 は追加提案。担当割り当ては Human）。#1395 の budget。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 実行計画 Revision 2.6（C-3 再発行待ち。Revision 2.5 は 2026-09-28 APPROVED） |
| status.md | status | フェーズ履歴（2026-10-21 新規） |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義（DI / DV / DD / DP / PR / AV / DC / IT） |
| review-self.md | C-3, review | C-1 結果（2026-09-25 再実行を含む） |
| review-external.md | C-3, review | 指摘 R-001〜R-080（C-2 R1 / R2）と Human 決定 R-081 / R-082、回避クラス台帳と監査表 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| dependency-reconciliation.md | preflight, handoff | 2026-10-08 の現行 owner gap・#1381 AC-6 acceptance・Human decision gate |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

実装は新規 pure module（VerificationResult / FailureRecord / assess_progress / decide / decision_to_event_draft）とそのテスト。I/O・#1392 storage・GitHub API・merge API は持たない。
