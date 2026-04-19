# settings.json デフォルト設定 — **採用しないことを決定**

> 調査日: 2026-04-19

## 調査結果

Claude Code plugin には **`settings.json` という標準ファイルは存在しない**。

`/Users/user/.claude/plugins/cache/` 配下の plugin（code-review, agent-sdk-dev, codex 等）を精査したが、いずれも plugin 内に `settings.json` を持たない。

`settings.json` は **user/project レベル**で `.claude/settings.json` として存在し、plugin 側は `.claude-plugin/plugin.json`（manifest）のみを持つ構造。

## 決定

- TASK-0017 の「`settings.json` 作成」タスクは**削除**する
- plan.md / todo.md / test-cases.md の `settings.json` 関連記述は削除 or 該当項目をスキップ
- plugin 利用者のカスタマイズは、plugin 導入後に利用者側 `.claude/settings.json` で行う（TASK-0020 の README で案内）

## 計画からの変更点への反映

本件は `status.md` の「計画からの変更点」セクションに記録済み。
