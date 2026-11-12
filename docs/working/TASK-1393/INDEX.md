# TASK-1393 INDEX

> 最終更新: 2026-11-02 07:45（C-3 APPROVED 2026-10-29T10:09:18Z を反映。PR #1619 / #1622 merge 済み）
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 の immutable VerificationResult / FailureRecord と、観測済みの事実だけから Decision（continue / repair / replan / stop と Terminal Outcome）を導く pure Decision Engine を、Delivery 第一リリース境界に必要な最小範囲で実装する（#1393、親 #894）。

## 現在のフェーズ

exec

> C-3 Gate: APPROVED（Human、`bin/plangate approve`、2026-10-29T10:09:18Z、`plan_hash` `sha256:ed637f48…`。origin/main `46685615` の plan.md の sha256 と一致することを照合済み）。c3.json は承認に使った worktree に untracked で保管されている。plan Revision 2.8 は PR #1619（`62b9a5df`）、exec 第 1 歩の `limits.py` は PR #1622（`46685615`）で main に merge 済み。
> exec 開始済み（第 1 歩 = #1622 merge）。以降のタスク（records / progress assessment / decision / event draft adapter / caller migration 等）は PF-1〜PF-8・#1391 event contract consumable・#1392 RunState input shape frozen・#1422 B-8 / B-13 の語彙決定待ち（todo.md「Preflight」、status.md「残タスク」の BLOCKED 行）。
> 以下は 2026-10-22 時点の記述（履歴）。
> Revision 2.7（PF-5 Human 決定 R-085〜R-088、2026-10-22）を確定反映。改訂後 plan の sha256 は `404c432a60157932cda967b4c3d90c77979c6d00df874a295828bfd8b0af35b3` で、既存 c3.json（Revision 2.6、`ec2a0db8…`）とは一致しない＝当時は Human の c3.json 再発行待ちだった（解消済み: 2026-10-29 に Rev2.10 / `sha256:ed637f48…` で APPROVED、上記）。下記 exec 前依存は現在も残る。
> 前回 C-3 Gate: APPROVED（Human、2026-10-21T09:15:23Z = JST 18:15、Revision 2.6、`plan_hash` `sha256:ec2a0db8…`）。Mode = high-risk。
> - blocker: exec 前依存（#1391 / #1392 / #1422 の owner 実装、PF-2〜PF-8）が未解消（[dependency-reconciliation.md](dependency-reconciliation.md)）
> - owner: #1391 / #1392 / #1422 の各 owner（担当割り当ては Human）
> - unblock_condition: 上記 owner 実装の完了と PF-2〜PF-8 の解消
> - exec 時要件: R-083（ratchet.py で `pr_convergence.scope` を導出、RT-04 に名指し回帰）/ R-084（RT-03 の注入方法と `DecisionInputError` → `ERROR` 明示 assert）。plan 本体は C-3 後のため不変（review-external.md）

## 次のアクション

依存解消後に Preflight PF-1〜PF-8（[dependency-reconciliation.md](dependency-reconciliation.md) の owner/残差）→ RED/GREEN（R-083 / R-084 を含む）。

依存（リリース条件）: #1392 は (state, action) からの遷移導出と `decision_made` の 4 キー読み取りを**方針として**採用済み（#1406 `e4aaeb91`。model-B の実装・`state_transitioned` は未完で、todo.md の該当行は未チェックのまま。dependency-reconciliation.md の #1392 行を参照）。stream 束縛は #1422（B-1〜B-12 は issue 記載、B-1 の表記と B-13 は追加提案。担当割り当ては Human）。#1395 の budget。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 実行計画 Revision 2.10（sha256 `ed637f48…`、2026-10-29 C-3 APPROVED。履歴: Revision 2.7 `404c432a…` / 2.6 `ec2a0db8…`） |
| status.md | status | フェーズ履歴（2026-10-21 新規） |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義（DI / DV / DD / DP / PR / AV / DC / IT） |
| review-self.md | C-3, review | C-1 結果（2026-09-25 再実行を含む） |
| review-external.md | C-3, review | 指摘 R-001〜R-080（C-2 R1 / R2）と Human 決定 R-081 / R-082、exec 時要件 R-083 / R-084、回避クラス台帳と監査表 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| dependency-reconciliation.md | preflight, handoff | 2026-10-08 の現行 owner gap・#1381 AC-6 acceptance・Human decision gate |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

実装は新規 pure module（VerificationResult / FailureRecord / assess_progress / decide / decision_to_event_draft）とそのテスト。I/O・#1392 storage・GitHub API・merge API は持たない。
