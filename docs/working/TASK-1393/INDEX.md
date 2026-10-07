# TASK-1393 INDEX

> 最終更新: 2026-10-08（依存状況を #1519 で再照合。PR #1407 は 2026-09-28 22:39Z に main へ merge。C-3 は Human が 22:45:37Z に APPROVED を発行）
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 の immutable VerificationResult / FailureRecord と、観測済みの事実だけから Decision（continue / repair / replan / stop と Terminal Outcome）を導く pure Decision Engine を、Delivery 第一リリース境界に必要な最小範囲で実装する（#1393、親 #894）。

## 現在のフェーズ

BLOCKED

> Revision 2.5。C-2 は R1 / R2 の 2 ラウンドで収束（R2 は新クラス 0）。簡易 C-1 PASS（R-071 は Human y で反映済み）。
> **C-3 Gate: APPROVED**（Human 発行の `approvals/c3.json`、`approved_at` 2026-09-28T22:45:37Z、`plan_hash` は main の plan.md の sha256 `799c8526…` と一致。承認トークンは Human が発行したもので、repo には commit されていない）。Mode = high-risk。
> **BLOCKED**（2026-10-08 再照合。詳しくは [dependency-reconciliation.md](dependency-reconciliation.md)）:
>
> - blocker: #1391 / #1392 / #1393 / #1395 / #1422 は現在 OPEN。#1392 model-B と #1393 owner Decision は未実装。#1516 で `_canonical_path` private 依存は解消済みだが、`ratchet.py` の provisional `DecisionError` / `decide` 依存および PF-1 caller migration は残る。既承認 plan の追加範囲と再 C-3 は Human 判断待ち
> - owner: Human（Plan scope / 再C-3裁定）。未実装箇所の owner は各OPEN Issue #1391/#1392/#1393/#1395/#1422
> - unblock_condition: dependency-reconciliation.md の owner table に沿って未実装部分を帰属決定し、Human が plan scope / 必要な C-3 の再発行を裁定し、PF-1〜PF-8 を通すこと

## 次のアクション

[dependency-reconciliation.md](dependency-reconciliation.md) の owner/残差を解決し、BLOCKED の解除（Human 判断）→ exec 前に Preflight PF-1〜PF-8。plan.md 本文の Rev 2.5 の文言は承認済み（plan_hash）なので直さない。逸脱は exec 時に status.md / decision-log に記録する。

依存（リリース条件）: #1392 は (state, action) からの遷移導出と `decision_made` の 4 キー読み取りを採用済み（#1406 `e4aaeb91`）。stream 束縛は #1422（B-1〜B-12 は issue 記載、B-1 の表記と B-13 は追加提案。担当割り当ては Human）。#1395 の budget。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 承認済み実行計画（Revision 2.5 / C-3 APPROVED。追加 scope は未承認） |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義（DI / DV / DD / DP / PR / AV / DC / IT） |
| review-self.md | C-3, review | C-1 結果（2026-09-25 再実行を含む） |
| review-external.md | C-3, review | 指摘 R-001〜R-080（C-2 R1 / R2）、回避クラス台帳と監査表 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| dependency-reconciliation.md | preflight, handoff | 2026-10-08 の現行 owner gap・#1381 AC-6 acceptance・Human decision gate |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

実装は新規 pure module（VerificationResult / FailureRecord / assess_progress / decide / decision_to_event_draft）とそのテスト。I/O・#1392 storage・GitHub API・merge API は持たない。
