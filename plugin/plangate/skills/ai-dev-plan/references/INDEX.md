# TASK-XXXX INDEX

> 最終更新: YYYY-MM-DD HH:MM
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

{PBIの核心を1-2文で要約。例: 記事タイプ不一致時に同一slugの別タイプ記事へ301リダイレクトする機能を追加する}

## 現在のフェーズ

{brainstorm | plan | C-1 | C-2 | C-3 待ち | exec | verify（L-0 / V-1〜V-4）| PR 作成済 | C-4 待ち | done | BLOCKED}

> 値域は `status.md` と共通（正本: `.claude/rules/working-context.md`）。
> V-1 等の**総合判定をここに書く場合は `status.md` / `handoff.md` の判定語をそのまま転記する**。
> INDEX 側で要約・丸めない（WARN / 条件付き PASS を PASS と書かない）。
> 判定の正本は `handoff.md` §1 > `status.md` > 本ファイル。矛盾時に是正するのは本ファイル側。

## 次のアクション

{具体的な次ステップ。例: "C-3 人間レビュー待ち → 承認後 exec を実行"}

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 承認済み実行計画 |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義 |
| review-self.md | C-3, review | C-1 結果 |
| review-external.md | C-3, review | C-2 結果 |
| status.md | status, 復旧 | フェーズ履歴・変更記録 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |
| evidence/ | レビュー根拠 | テスト実行ログ・スクリーンショット |

## 変更ファイル一覧（概要）

{plan.md の Files/Components to Touch から抽出した1行サマリ。例: "ArticleDetailQueryService, routes.php, 4サイトのルーティング"}
