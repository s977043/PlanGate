# Agent Definitions (Codex)

> プロジェクト共通制約は `AGENTS.md` → `docs/ai/project-rules.md`（正本）を参照。Codex固有の登録一覧は `.codex/README.md` を参照。

このディレクトリには、Codex CLI向けのエージェント定義（`.toml`）が含まれています。
ペルソナ詳細定義の正本は `.claude/agents/*.md` にあり、本ディレクトリの `.toml` は Codex固有設定（sandbox_mode, model_reasoning_effort）と要約版の指示を保持します。

Codex から利用する repo-owned skill の正本は `.agents/skills/*/SKILL.md` にあります。
`.claude/skills/` は Claude Code 側の資産であり、Codex 実行対象としては直接 bridge しません。

---

## エージェント定義一覧

### 計画・調整

- **[orchestrator.toml](./orchestrator.toml)** - マルチエージェントの調整
- **[project_planner.toml](./project_planner.toml)** - タスク分解と計画策定
- **[workflow_conductor.toml](./workflow_conductor.toml)** - ai-dev-workflow のフェーズ遷移管理

### コンテンツ作成

- **[documentation_writer.toml](./documentation_writer.toml)** - ドキュメント・ナレッジ整備
- **[skill_designer.toml](./skill_designer.toml)** - スキル設計・テンプレート作成

### レビュー

- **[claude_code_reviewer.toml](./claude_code_reviewer.toml)** - Claude Code CLI による PR レビュー委譲

### 調査

- **[explorer_agent.toml](./explorer_agent.toml)** - ドキュメント・設定ファイル探索

---

## 関連ドキュメント

- **[docs/ai/project-rules.md](../../docs/ai/project-rules.md)** - プロジェクトルール正本
- **[.codex/README.md](../README.md)** - Codex固有の設定と登録一覧
- **[.codex/config.toml](../config.toml)** - Codex CLI設定（エージェント登録・スレッド数等）
- **[.claude/agents/](../../.claude/agents/)** - ペルソナ詳細定義の正本（Markdown）
- **[.agents/skills/](../../.agents/skills/)** - Codex Cloud / CLI 向け repo-owned skill 定義
- **[.claude/skills/](../../.claude/skills/)** - Claude Code 側の参考資産
