# TASK-XXXX 作業ステータス

> 最終更新: YYYY-MM-DD
> PBI: {タイトル}
> チケットURL: {URL}（任意）

---

## 全体構成

| PR | ブランチ | 内容 | 状態 |
|----|---------|------|------|
| PR1 | `feature/TASK-XXXX-{description}` | {内容} | {状態} |

---

## PR1: {PR名}

### コミット履歴（新しい順）

1. `{hash}` - {メッセージ}

### 計画からの変更点

{計画との差分があれば記載。なければ「なし」}

### 変更ファイル一覧

| 種別 | ファイルパス |
|------|-----------|
| 新規 | {パス} |
| 修正 | {パス} |

### 残タスク

- [ ] {タスク}
- [ ] レビュー承認・マージ

---

## Claude Codeプロンプト

### 次の作業用プロンプト

```
## コンテキスト
- チケット: TASK-XXXX（{タイトル}）
- 作業ドキュメント: docs/working/TASK-XXXX/status.md
- チケットURL: {URL}

## 現在の状態
{現在の状態の説明}

## タスク
1. {具体的なタスク}
```

---

## 参照ファイル

| 用途 | パス |
|------|------|
| 実行計画 | `docs/working/TASK-XXXX/plan.md` |
| ToDo | `docs/working/TASK-XXXX/todo.md` |
| テストケース | `docs/working/TASK-XXXX/test-cases.md` |
| このステータスファイル | `docs/working/TASK-XXXX/status.md` |
| CLAUDE.md | `CLAUDE.md` |
