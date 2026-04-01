# Codex Cloud Manual Task Handoff

このファイルは、Codex Cloud の手動 task 起動時に使う tracked handoff packet です。
実作業チケット分の `docs/working/` 配下ファイルは `.gitignore` 対象で PR に含まれないため、Cloud task から直接読める前提にしません。
初期状態の `TODO` / `pending` はテンプレート値です。`./scripts/ai-dev-workflow TASK-XXXX prepare-cloud` を実行すると、承認済みの ticket 情報で置き換わります。

## 使い方

1. 人間がローカルの ticket コンテキストから、承認済みの内容をこのファイルに転記する
2. `./scripts/ai-dev-workflow TASK-XXXX prepare-cloud` を使う場合は、このテンプレートが承認済み内容で上書きされる
3. Cloud task 起動時は、このファイルを最初に読む
4. Cloud task はこのファイルに書かれた内容だけを作業指示として扱う

## Task

- Task ID: TODO
- C-3 approval: pending

## 追記する内容

- ticket 番号
- ブランチ名
- 目的
- 承認済みスコープ
- 主要な制約
- 参照すべき検証コマンド
- 修正箇所に絞った検証方針
- 未解決事項
- 人間への承認依頼メモ

## 起動時テンプレート

```text
Read .codex/manual-cloud-task.md first.
Execute only the approved scope described here.
Do not assume docs/working ticket files are directly visible.
If the handoff packet is missing information, stop and ask a question.
Update only the files listed in the handoff packet.
Prioritize tests and checks for the modified area during implementation.
Treat task completion as provisional until human approval is requested.
Return a concise summary with changed files, targeted verification results, and the approval request note.
```
