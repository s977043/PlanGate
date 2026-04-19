# TASK-0020 ドキュメント間リンク検証結果

> 実施日: 2026-04-20

## 検証方法

Read ツールで各リンク先を実在確認（外部ツール `markdown-link-check` 等は使用せず、repo 前提で再現可能な方法）。

## 検証対象リンク

### Root README.md から

| リンク先 | 存在 | 備考 |
|---------|------|------|
| `docs/plangate-plugin-migration.md` | ✅ | 本 TASK で新規作成 |
| `docs/plangate.md` | ✅ | 既存 |
| `.claude/agents/README.md` | ✅ | 既存 |
| `.claude/skills/README.md` | ✅ | 既存 |

### docs/plangate-plugin-migration.md から

| リンク先 | 存在 | 備考 |
|---------|------|------|
| `../plugin/plangate/.claude-plugin/plugin.json` | ✅ | TASK-0017 で作成 |
| `../plugin/plangate/README.md` | ✅ | TASK-0017 で作成、本 TASK で本文化 |
| GitHub Issues #16-#20 URL | ✅ | GitHub 上で確認可能 |

### plugin/plangate/README.md から

| リンク先 | 存在 | 備考 |
|---------|------|------|
| `../../docs/plangate-plugin-migration.md` | ✅ | 本 TASK で作成 |
| `../../docs/plangate.md`（間接） | ✅ | 既存 |

## 判定

全リンク ✅ OK。切れなし。

## 手動確認の自動化案（将来）

継続的な整合確保のため、以下のスクリプトを用意可能（TASK 外）:

```bash
# ドキュメント内の相対リンクを抽出、ファイル存在を確認するシェル
find docs/ plugin/ README.md -name "*.md" -exec \
  awk '/\[.*\]\(([^)]+)\)/ { match($0, /\]\(([^)]+)\)/, a); print FILENAME":"a[1] }' {} \;
# → 出力を解析して test -f でチェック
```

外部ツール非依存で実行可能だが、本 TASK のスコープ外。
