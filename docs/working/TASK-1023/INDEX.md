# TASK-1023 INDEX

> 最終更新: 2026-08-10 12:30 JST

## チケット概要

承認token書き込みガードのexit code・stdin bypass・jq不在fail-openを修正し、AI自己承認を技術的に停止する。

## 現在のフェーズ

Human C-3待ち

## 次のアクション

初回C-2指摘R-001〜R-025を確定反映（両独立レーンAPPROVE）。その後、PR #1024 の敵対的レビュー
（major 5 / minor 3 / info 1）を **R-026〜R-034** として `review-external.md`「追記 2」へ集約し、
plan / todo / test-cases / pbi-input へ **1 回確定反映**した。

**TASK-1023 は未承認**（`approvals/` が tracked・worktree ともに不在 / git 履歴 0 件・2026-08-10 実測）。
`24fcdf9f...53de1` は PR #1024 本文記載の plan hash であって承認トークンの hash ではない。
確定後 plan_hash に対する **c3.json の初回発行（Human-owned）** のうえで Human C-3 判断を仰ぐ。未決の Human 判断は
G-6（EH-10 採番衝突）/ G-7（TTY block 統一の副作用）/ G-8（parsed-safe tool 集合の導出方式）。

## ファイルマップ

| ファイル | 説明 |
|---|---|
| `pbi-input.md` | Issue要件とAC |
| `plan.md` | 実行計画 |
| `todo.md` | Human/Agent依存順 |
| `test-cases.md` | AC↔TCとmutation |
| `review-self.md` | C-1結果 |
| `review-external.md` | C-2追記専用集約 |
| `current-state.md` | 現在状態 |
| `decision-log.jsonl` | 判断履歴 |

## 変更ファイル一覧

実装scopeは`check-approval-token-write.sh`と`ta-25-approval-token-guard.sh`。現時点の差分はPlan Packageのみ。
