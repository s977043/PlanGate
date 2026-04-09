# Agent Definitions (Claude Code)

> プロジェクト共通制約は `CLAUDE.md` → `docs/ai/project-rules.md`（正本）を参照。

このディレクトリには、Claude Code 向けのエージェント詳細定義（`.md`）が含まれています。
Codex CLI 向けの要約版は `.codex/agents/*.toml` にあります。

---

## エージェント定義一覧

### 計画・調整

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| orchestrator | [orchestrator.md](./orchestrator.md) | `orchestrator.toml` | マルチエージェント調整、タスクオーケストレーション |
| project-planner | [project-planner.md](./project-planner.md) | `project_planner.toml` | タスク分解、計画策定、依存関係グラフ |
| workflow-conductor | [workflow-conductor.md](./workflow-conductor.md) | `workflow_conductor.toml` | ai-dev-workflow のフェーズ遷移管理（司令塔） |

### コンテンツ作成

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| documentation-writer | [documentation-writer.md](./documentation-writer.md) | `documentation_writer.toml` | ドキュメント・ナレッジ整備 |
| skill-designer | [skill-designer.md](./skill-designer.md) | `skill_designer.toml` | Codex/Cloud用スキル設計・作成 |

### レビュー・改善

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| claude-code-reviewer | [claude-code-reviewer.md](./claude-code-reviewer.md) | `claude_code_reviewer.toml` | Claude Code CLI による PR レビュー委譲 |
| prompt-engineer | [prompt-engineer.md](./prompt-engineer.md) | `prompt_engineer.toml` | エージェント/スキル定義の品質改善 |
| migration-agent | [migration-agent.md](./migration-agent.md) | `migration_agent.toml` | 依存関係アップグレード・破壊的変更対応 |

### 実装・品質

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| implementer | [implementer.md](./implementer.md) | `implementer.toml` | exec フェーズのタスク実装（TDD） |
| acceptance-tester | [acceptance-tester.md](./acceptance-tester.md) | `acceptance_tester.toml` | V-1 受け入れ検査 |
| code-optimizer | [code-optimizer.md](./code-optimizer.md) | `code_optimizer.toml` | V-2 コード最適化（full/criticalモード） |
| linter-fixer | [linter-fixer.md](./linter-fixer.md) | `linter_fixer.toml` | L-0 リンター自動修正 |

### 調査・分析

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| explorer-agent | [explorer-agent.md](./explorer-agent.md) | `explorer_agent.toml` | コードベース探索、アーキテクチャ分析 |
| research-analyst | [research-analyst.md](./research-analyst.md) | `research_analyst.toml` | 技術調査・実現可能性分析 |
| retrospective-analyst | [retrospective-analyst.md](./retrospective-analyst.md) | `retrospective_analyst.toml` | exec後の振り返りデータ分析 |

### 要件・仕様

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| spec-writer | [spec-writer.md](./spec-writer.md) | `spec_writer.toml` | 要件構造化、PBI INPUT PACKAGE 作成 |

### アジャイル

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| scrum-master | [scrum-master.md](./scrum-master.md) | `scrum_master.toml` | Sprint イベント支援、impediment 管理 |
| agile-coach | [agile-coach.md](./agile-coach.md) | `agile_coach.toml` | アウトカム志向、仮説検証設計、継続改善 |

---

## Allowed Context（v6）

全エージェントに「Allowed Context（読み込み許可範囲）」セクションが定義されています。
これは PlanGate v6 の Context Isolation 原則に基づき、各エージェントが読む情報を制限してスコープクリープを防ぐものです。

詳細: `.claude/rules/working-context.md`（Progressive Disclosure プロトコル）

---

## 関連ドキュメント

- **[docs/ai/project-rules.md](../../docs/ai/project-rules.md)** — プロジェクトルール正本
- **[.codex/agents/](../../.codex/agents/)** — Codex CLI 向け要約版（`.toml`）
- **[.codex/config.toml](../../.codex/config.toml)** — Codex CLI 設定（エージェント登録）
