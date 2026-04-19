# TASK-0018 Plugin 経由呼び出し Syntax

> 調査日: 2026-04-19
> 参照: TASK-0017 evidence/plugin-spec-research.md、`/Users/user/.claude/plugins/cache/openai-codex/codex/1.0.1/`

## Claude Code における plugin 資産の解決

Claude Code は plugin インストール時に plugin 内の `skills/` `agents/` `commands/` を自動検出し、プロジェクト/ユーザー側の同名資産と並列に登録する。

### Skills 呼び出し

plugin 内 skill は `<plugin-name>:<skill-name>` 形式で明示呼び出し可能。名前衝突時は prefix 必須。

例:
- `plangate:brainstorming`（plugin 側）
- `brainstorming`（プロジェクト/ユーザー側、名前衝突時は prefix なしでの解決先は実装依存）

### Commands 呼び出し

plugin 内 commands は `/<command>` で自動検出されるが、名前衝突時の挙動は plugin / 既存側の優先順位により決まる（Claude Code 内部）。

例:
- `/working-context`（解決は自動、プロジェクト優先 or plugin 優先かは CC 内部仕様）
- 明示的に plugin 側を呼ぶには: plugin からの `CLAUDE_PLUGIN_ROOT` 参照 or UI 選択

### 本 TASK で採用する検証 syntax

| 対象 | 呼び出し syntax | 成功判定 |
|------|----------------|---------|
| plugin 側 skills | `plangate:brainstorming` 等 | skill が起動し、起動ログ or 応答内容から plugin 由来が識別できる |
| plugin 側 commands | `/working-context`（CC が plugin を優先解決する前提）or plugin-specific syntax | command が動作する |
| legacy skills | `brainstorming`（plugin prefix なし） | legacy 側が起動する |
| legacy commands | `/working-context`（plugin 削除状態でのみ legacy が起動） | legacy が起動する |

## 各 skill/command の具体テスト呼び出し

### Skills（5 件）

```
plangate:brainstorming
plangate:self-review
plangate:subagent-driven-development
plangate:systematic-debugging
plangate:codex-multi-agent
```

### Commands（2 件）

```
/working-context    # plugin 由来
/ai-dev-workflow    # plugin 由来
```

## 識別方法

Claude Code がどこから skill/command を解決したかは以下で確認:
- `<system-reminder>` タグ内の user-invocable skills 表示
- 実行時のデバッグ出力（`/debug` 等）
- 手動: plugin 側のコンテンツをわずかに変えてテスト実行し、応答内容で判別
