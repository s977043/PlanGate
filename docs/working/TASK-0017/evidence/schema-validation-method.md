# plugin.json Schema Validation 手段

> 調査日: 2026-04-19

## 調査結果

### 公式スキーマの有無

Claude Code 公式には **公開されている JSON Schema は見つからなかった**。
`/Users/user/.claude/plugins/cache/` 配下の plugin を確認したところ、各 plugin の `.claude-plugin/plugin.json` は手書きで、スキーマ検証用ファイルは同梱されていない。

### 採用する検証手段

| 検証レベル | 手段 | 実装 |
|----------|------|------|
| Level 1: JSON 構文 | `python3 -c "import json; json.load(open(...))"` | 必須 |
| Level 2: 必須フィールド存在 | python で `name`, `version`, `description`, `author.name` の存在を確認 | 必須 |
| Level 3: 型チェック | `name` (str)、`version` (semver str)、`author` (object) | 必須 |
| Level 4: インストール試行 | Claude Code に実際に読み込ませて validation エラーが出ないことを確認 | 必須 |

### Level 2-3 検証コマンド

```bash
python3 -c "
import json, re, sys
d = json.load(open('plugin/plangate/.claude-plugin/plugin.json'))
assert isinstance(d.get('name'), str) and d['name'], 'name missing or empty'
assert isinstance(d.get('version'), str) and re.match(r'^\d+\.\d+\.\d+$', d['version']), 'version invalid semver'
assert isinstance(d.get('description'), str) and d['description'], 'description missing or empty'
assert isinstance(d.get('author'), dict) and d['author'].get('name'), 'author.name missing'
print('OK: plugin.json passes basic validation')
"
```

### Level 4: インストール試行

Claude Code の marketplace API / ローカル plugin 読み込み機構経由で読み込ませ、エラーが出ないことを確認する。具体手順は `install-verification.md` に記録する。

### 将来の改善

- 公式 JSON Schema が公開された場合は `ajv` 等の validator へ切り替え
- 今回は Level 1-4 の手動 + 手動実行で担保
