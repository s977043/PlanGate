# TASK-1636 INDEX

> 最終更新: 2026-11-05 19:18
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従う。

## チケット概要（1-2文）

`install.sh` が導入前のファイルを撤去で削除する #1636 の修正（PR #1639）について、敵対レビューの major 2 件と minor 5 件を是正する。symlink を含む導入先への導入と v1 利用者の更新を、成功に見せかけず動く形にする。

## 現在のフェーズ

BLOCKED

- blocker: `plan.md` を配置できない。Hook EH-3 が `PLANGATE_HOOK_TASK` のないセッションからの書き込みを block した
- owner: human
- unblock_condition: `PLANGATE_HOOK_TASK=TASK-1636` を付けて起動したセッションで `plan.md` を配置する。その後フェーズを `C-3 待ち` に更新する

C-1 判定: PASS（`review-self.md`。WARN は `C1-B1B2-16` の 1 件）。C-2 は未実施（`plan.md` Q-3）。

## 次のアクション

1. `PLANGATE_HOOK_TASK=TASK-1636` 付きで再起動し、`plan.md` を配置する。
2. Human が C-3 を判断する（`pbi-input.md` の確認と `plan.md` Q-1〜Q-4）。
3. 承認後に `bin/plangate approve TASK-1636` を実行してから exec に入る。c3.json は未発行。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準（AI の下書き、Human 確認待ち） |
| plan.md | exec, review | 実行計画（**未配置**。他の成果物の `plan.md` 参照はこの配置を前提とする） |
| todo.md | exec | タスク一覧 |
| test-cases.md | exec, review | テストケース定義 |
| review-self.md | C-3, review | C-1 結果 |
| current-state.md | status, 復旧 | 現在状態 |
| installer-ownership-review.md | review | PR #1639 時点のレビュー記録（exec で更新） |

`status.md` / `decision-log.jsonl` / `evidence/` は exec の T-01 以降に作る。

## 変更ファイル一覧（概要）

`install.sh`、`tests/test_installer_ownership.py`、`docs/plangate-plugin-migration.md`、`docs/working/TASK-1636/installer-ownership-review.md`
