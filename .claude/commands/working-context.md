# /working-context

チケット作業の開始・再開・中断時に、作業コンテキストを管理する。

ルール詳細: `.claude/rules/working-context.md`

## 引数

$ARGUMENTS に以下のいずれかが渡される:

- `TASK-XXXX` — チケット番号（新規作成 or 既存読み込み）
- `save` — 現在作業中のチケットのstatus.mdを更新
- 引数なし — `docs/working/` 配下の一覧を表示

## 実行フロー

### 1. 引数解析

引数を解析し、以下のいずれかのモードを決定する:

- **一覧表示モード**: 引数なし → `docs/working/` 配下のディレクトリ一覧と各status.mdの先頭5行を表示
- **読み込みモード**: `TASK-XXXX` が渡され、かつ `docs/working/TASK-XXXX/` が存在する
- **新規作成モード**: `TASK-XXXX` が渡され、かつ `docs/working/TASK-XXXX/` が存在しない
- **保存モード**: `save` が渡された

### 2. 読み込みモード（セッション開始・再開）

以下のファイルを順に読み、現在の状態をユーザーに報告する:

1. `docs/working/TASK-XXXX/status.md` を読む
2. `docs/working/TASK-XXXX/plan.md` を読む（存在すれば）
3. `docs/working/TASK-XXXX/todo.md` を読む（存在すれば）

報告内容:
- PR一覧と各PRの状態
- 残タスク一覧
- 計画からの変更点
- 次のアクション候補

### 3. 新規作成モード

1. `docs/working/TASK-XXXX/` ディレクトリを作成
2. ユーザーに以下を確認:
   - 外部チケットURL（任意）
   - PBIの概要（Why / What）
3. `docs/working/TASK-XXXX/status.md` をテンプレートとしてコピーし、チケット番号・PBI情報を埋めて生成する

### 4. 保存モード（セッション中断・終了）

1. 現在のgitブランチを確認し、対応するチケット番号を特定（`TASK-XXXX` を含まないブランチ名の場合はユーザーにチケット番号を尋ねる）
2. `docs/working/TASK-XXXX/status.md` を読み込む
3. 以下を更新:
   - 最終更新日
   - PR一覧の状態（`gh pr list` やgit logで確認）
   - コミット履歴（ブランチ固有のコミットを追記）
   - 残タスクのチェック状態
   - 計画からの変更点（作業中に発生した差分）
   - Claude Codeプロンプト（次回作業用のプロンプトを整備）
4. 更新内容をユーザーに報告

## 重要ルール

- **第1原則を遵守**: ファイル生成・更新前にユーザー確認を取る
- status.md の更新は差分が分かる形で報告する
- 外部チケットURLが分かる場合は参照リンクとしてコンテキストに記録する
