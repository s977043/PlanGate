# TASK-1636 INDEX

> 最終更新: 2026-11-06 02:55
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従う。

## チケット概要（1-2文）

`install.sh` が導入前のファイルを撤去で削除する #1636 の修正（PR #1639）について、敵対レビューの major 2 件と minor 5 件を是正する。symlink を含む導入先への導入と v1 利用者の更新を、成功に見せかけず動く形にする。

## 現在のフェーズ

C-3 待ち

C-1 判定: PASS（簡易 C-1 再実行後。`review-self.md`。WARN は `C1-B1B2-16` の 1 件）。C-2 判定: WARN（`review-external.md`。R-001〜R-007 を計画へ反映済み。担当エージェントは unavailable で代替実施）。

## 次のアクション

1. Human が C-3 を判断し（`pbi-input.md` の確認と `plan.md` Q-1〜Q-5）、`bin/plangate approve TASK-1636` を実行する。c3.json は未発行。
2. exec に入る。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準（AI の下書き、Human 確認待ち） |
| plan.md | exec, review | 実行計画 |
| todo.md | exec | タスク一覧 |
| test-cases.md | exec, review | テストケース定義 |
| review-self.md | C-3, review | C-1 結果 |
| review-external.md | C-3, review | C-2 結果と R-NNN の監査表 |
| current-state.md | status, 復旧 | 現在状態 |
| installer-ownership-review.md | review | PR #1639 時点のレビュー記録（exec で更新） |

`status.md` / `decision-log.jsonl` / `evidence/` は exec の T-01 以降に作る。

## 変更ファイル一覧（概要）

`install.sh`、`tests/test_installer_ownership.py`、`docs/plangate-plugin-migration.md`、`docs/working/TASK-1636/installer-ownership-review.md`
