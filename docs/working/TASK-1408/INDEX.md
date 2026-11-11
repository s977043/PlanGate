# TASK-1408 INDEX

> 最終更新: 2026-11-12 07:57。基準 `origin/main` = `9445df17`。canon commit = `e5573cc8`。
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従う。

## チケット概要

PR #1402 により失効した canon 7 本の I1 例外を §7 に記録し、以後を I4 へ移行する（#1408 + #1329）。記録自身も I4 で採用する。

## 現在のフェーズ

verify（L-0 / V-1〜V-4）

> C-3 は CONDITIONAL（2026-11-07）。確定後の plan_hash で c3.json を発行済み。Mode = critical（Human 決定）。
> V-1 の総合判定は handoff.md §1 の判定語を転記する。現時点の判定: **WARN**（I4 の機械証跡は未充足。T-10 未実施、記録欄 TODO）

## 次のアクション

レビュアーが記録欄を埋めて T-10（独立再実行）を実行 → handoff を確定 → PR → C-4

## ファイルマップ

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | C-3 で確定 |
| plan.md | exec, review | 計画、AC 対応表、§7 文案、I4 証跡（承認済み。編集禁止） |
| todo.md | exec | タスク |
| test-cases.md | exec, review | TC |
| review-self.md | C-3, review | C-1 結果 |
| review-external.md | review | C-2 の R-001〜R-014 / R2-n / R3-n と、末尾に exec レビュー R-101〜R-112 |
| status.md | status, 復旧 | フェーズ履歴、計画からの変更点、独立再実行の手順、記録欄、残存脅威モデル、回避クラス台帳 |
| current-state.md | status, 復旧 | 現在状態 |
| handoff.md | C-4 | 引き継ぎ（下書き） |
| evidence/ | レビュー根拠 | measure.sh / measurements.txt / manifest.txt / make-manifest.sh / regen.sh / check.sh |

## 変更ファイル一覧（概要）

`docs/ai/ai-loop-v2/phase0-migration.md`（§7 失効節、§8 Phase 1 exit criteria。追記のみ）、`.github/PULL_REQUEST_TEMPLATE.md`（1 項目）、`docs/working/TASK-1408/`。
