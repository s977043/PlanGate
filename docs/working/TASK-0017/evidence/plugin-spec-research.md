# Claude Code Plugin 仕様調査結果

> 調査日: 2026-04-19
> 調査方法: ローカル `/Users/user/.claude/plugins/cache/` 配下の実働 plugin を分析
> 参照 plugin: `claude-plugins-official/code-review`, `claude-plugins-official/agent-sdk-dev`, `openai-codex/codex`

## 1. ディレクトリ構造（実働 plugin の共通パターン）

```text
{plugin-name}/
├── .claude-plugin/
│   └── plugin.json          # manifest（必須）
├── agents/                  # *.md（frontmatter 付き）
├── commands/                # *.md
├── skills/                  # <skill-name>/SKILL.md
├── hooks/                   # hooks.json + scripts
├── scripts/                 # ヘルパースクリプト（bin/ ではない）
├── prompts/                 # prompt テンプレート（任意）
├── schemas/                 # JSON schema（任意）
├── README.md                # 任意
└── LICENSE                  # 任意
```

**重要な発見**:
- manifest は **`.claude-plugin/plugin.json`**（ルート直下ではない）
- scripts ディレクトリは **`scripts/`**（`bin/` は使用されていない）
- `rules/` は標準ディレクトリではない（plugin 内で独自配置する場合は agent から参照）

## 2. plugin.json の最小スキーマ

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "plugin の説明",
  "author": {
    "name": "作者名",
    "email": "optional@example.com"
  }
}
```

**重要**:
- **skills / agents / rules / hooks / commands エントリは不要**（ディレクトリから auto-discovery）
- version は semver 形式
- author は object、`name` のみ必須

## 3. 各資産の配置ルール

| 種別 | 配置 | ファイル形式 |
|-----|------|------------|
| agents | `agents/<agent-name>.md` | frontmatter（name, description, tools, skills）+ 本文 |
| commands | `commands/<command-name>.md` | frontmatter + 本文 |
| skills | `skills/<skill-name>/SKILL.md` | frontmatter（name, description, user-invocable）+ 本文 |
| hooks | `hooks/hooks.json` | SessionStart/SessionEnd/Stop 等のフック設定 |
| scripts | `scripts/*.{mjs,sh,py}` | `${CLAUDE_PLUGIN_ROOT}/scripts/` で参照 |

## 4. 環境変数

- `${CLAUDE_PLUGIN_ROOT}` — plugin ルートの絶対パス（hooks/scripts から参照可能）

## 5. 計画からの変更点（plan.md への反映必要）

| 項目 | 元の計画 | 調査結果 | 影響範囲 |
|------|--------|---------|---------|
| plugin.json 配置 | `plugin/plangate/plugin.json` | `plugin/plangate/.claude-plugin/plugin.json` | plan.md / todo.md / test-cases.md |
| scripts ディレクトリ | `bin/` | `scripts/` | 全 4 TASK（特に 0019, 0020） |
| plugin.json エントリ | skills/agents/rules/hooks を明示列挙 | manifest metadata のみ、資産は auto-discovery | test-cases TC-3（エントリ数検証）を削除または変更 |
| settings.json | 含める | **Claude Code plugin に settings.json は存在しない**（user/project 側の .claude/settings.json と混同） | settings.json 関連タスク全削除 |
| rules/ | plugin 標準ディレクトリ | **非標準**。agent から参照する独自配置として維持可能 | TASK-0019 で要再検討 |

## 6. 推奨される plangate plugin の最終構造

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json
├── agents/              # TASK-0019 で 8 agents 配置
├── skills/              # TASK-0018 で 7 skills 配置（各サブディレクトリ）
├── rules/               # TASK-0019 で 3 rules 配置（非標準、agent から参照）
├── hooks/               # 将来拡張（hooks.json は初版では空 or 雛形のみ）
├── scripts/             # TASK-0019 で中核スクリプト配置
└── README.md            # TASK-0020 で本文化
```

## 7. 結論

- TASK-0017 の `settings.json` 関連タスクは削除
- TASK-0017 の `plugin.json` は metadata のみのシンプル構造
- `bin/` → `scripts/` に変更
- plugin.json の schema validation は公式 validator 未発見 → JSON valid + インストール試行で担保
- TASK-0019 で `rules/` の扱いを再確認（非標準ディレクトリとして維持）
