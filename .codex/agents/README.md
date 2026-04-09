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

### 実装・品質

- **[implementer.toml](./implementer.toml)** - exec フェーズのタスク実装（TDD）
- **[acceptance_tester.toml](./acceptance_tester.toml)** - V-1 受け入れ検査
- **[code_optimizer.toml](./code_optimizer.toml)** - V-2 コード最適化
- **[linter_fixer.toml](./linter_fixer.toml)** - L-0 リンター自動修正

### 調査・分析

- **[research_analyst.toml](./research_analyst.toml)** - 技術調査・実現可能性分析
- **[retrospective_analyst.toml](./retrospective_analyst.toml)** - exec後の振り返りデータ分析

### 要件・仕様

- **[spec_writer.toml](./spec_writer.toml)** - 要件構造化、PBI INPUT PACKAGE 作成

### レビュー・改善

- **[prompt_engineer.toml](./prompt_engineer.toml)** - エージェント/スキル定義の品質改善
- **[migration_agent.toml](./migration_agent.toml)** - 依存関係アップグレード・破壊的変更対応

### アジャイル

- **[scrum_master.toml](./scrum_master.toml)** - Sprint イベント支援、impediment 管理
- **[agile_coach.toml](./agile_coach.toml)** - アウトカム志向、仮説検証設計、継続改善

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
