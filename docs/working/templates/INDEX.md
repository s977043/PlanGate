# TASK-XXXX INDEX

> 最終更新: YYYY-MM-DD HH:MM

## チケット概要（1-2文）

{PBIの核心を1-2文で要約。例: 記事タイプ不一致時に同一slugの別タイプ記事へ301リダイレクトする機能を追加する}

## 現在のフェーズ

{brainstorm | plan | C-1 | C-2 | C-3待ち | exec | done}

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
