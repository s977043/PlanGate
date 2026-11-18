# TASK-1197 INDEX

> 最終更新: 2026-11-12 08:14。base `origin/main` = `9c5b3262`、HO 適用 commit = `82395dbe`。

## チケット概要

no-task セッションで未承認 TASK の plan.md を初回作成できるようにする（#1197、案 B 候補）。既存 plan.md の改変と承認済み TASK への書き込みは block のまま。

## 現在のフェーズ

verify（L-0 / V-1〜V-4）

V-1 総合判定: **WARN**（AC 4/4 PASS。`doctor --check-settings` FAIL rc=1、T-02 未実施）。正本は `handoff.md` §1。

> 以下は C-3 時点の経緯。C-2 R1 は River Review = WARN、独立検証 = FAIL で、指摘は R-001〜R-016 として反映済み（`review-external.md`）。Human は Q-1〜Q-5 を推奨どおり裁定したが、plan の Q 欄へは未反映。C-2 R2 = **FAIL**、R3（Codex I2）= **FAIL** で、指摘は反映済みだが**未収束**。Human 裁定により案 B を縮小し、R4 は行わず、打ち切りの可否を C-3 に諮る。pbi-input は C-3 で確定した。c3.json は存在しない。
> Mode = critical（同期 C-3 固定、autonomous APPROVE 不可）。

## 次のアクション

1. Human が `sh scripts/apply-claude-settings.sh` を実行し `doctor --check-settings` を再測定
2. T-02（実 Write payload 確認）→ V-2〜V-4 → push・PR（`Refs #1197`）
3. `approvals/c3.json` は plan worktree にのみあり、本 branch には commit しない（保管先は Human 判断）

## ファイルマップ

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | C-3 で確定 |
| plan.md | exec, review | 計画、攻撃経路評価、Questions |
| todo.md | exec | タスク |
| test-cases.md | exec, review | TC と変異 |
| review-self.md | C-3, review | C-1 結果 |
| status.md | status | フェーズ履歴・逸脱 |
| current-state.md | L0 | 現在状態 |
| handoff.md | done, review | WF-05 完了資産（判定の正本） |

## 変更ファイル一覧（概要）

HO の `scripts/hooks/check-plan-hash.sh`（Human 適用）、patch 文書、適用スクリプト、ta-NN と pending flag、ta-79、rollout-policy.md、ai-loop-cycle SKILL.md 群、hook-enforcement.md。
