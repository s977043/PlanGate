# TASK-0019 Plugin 内参照方式決定ログ

> 調査日: 2026-04-19
> 目的: plugin 内で agents が rules や他 agents を参照する規則を確定

## 決定

### Rules 参照

**規則**: agents 内から rules を参照する際は、plugin ルート相対パス `plugin/plangate/rules/<file>.md` を記載する。

- plugin インストール後、この参照は Claude Code が plugin ルートを解決して正しく機能する
- 絶対パス（`/Users/...`）や環境依存パス（`$CLAUDE_PLUGIN_ROOT`）は agent 定義内では使わない（Markdown として読みづらくなる）
- runtime で実際のパス解決を確認する必要がある（統合 runtime 検証で実施）

### 参照修正対象

| Agent | 元の参照 | 修正後 |
|-------|---------|--------|
| workflow-conductor.md:216 | `.claude/rules/mode-classification.md` | `plugin/plangate/rules/mode-classification.md` |

### Agent 間参照

**規則**: plugin 内 agent 同士の呼び出しは、Claude Code の `Task(subagent_type="<plugin>:<agent>")` 形式を使用。

- plugin prefix: `plangate:workflow-conductor`, `plangate:implementer` など
- prefix なしでの呼び出しは legacy 側（`.claude/agents/`）との衝突時に曖昧になるため避ける

今回の 6 agents には agent 間の直接呼び出し（Task ツール使用の記述）は存在しないため、修正不要。将来追加される場合にこの規則を適用する。

### Commands/Skills からの参照

plugin 内 commands/skills から plugin 内 agents を参照する場合も同様に `plangate:<agent>` prefix を使用。

## Legacy 側との衝突時の優先順位

- Claude Code の plugin 解決順序は実装依存（公式ドキュメント未確認）
- 統合 runtime 検証で以下を確認予定:
  - prefix あり（`plangate:workflow-conductor`） → plugin 側が呼ばれる
  - prefix なし（`workflow-conductor`） → 不定（legacy 優先か plugin 優先か）

## TASK-0020 での公開

本決定ログは、TASK-0020 の migration note に以下の形で反映:
- 「plugin 内参照」セクション → rules 参照規則と agent prefix
- 「legacy との衝突」セクション → 優先順位の注意と確認結果（runtime 検証後に追記）
