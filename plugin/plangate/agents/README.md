# Agent Definitions (Claude Code)

> プロジェクト共通制約は `CLAUDE.md` → `docs/ai/project-rules.md`（正本）を参照。

このディレクトリには、Claude Code 向けのエージェント詳細定義（`.md`）が含まれています。
Codex CLI 向けの要約版は `.codex/agents/*.toml` にあります。

---

## エージェント定義一覧

> **2 層構成（2026-06-10 スリム化）**: ゲート列（WF-01〜06 / C / V / L-0）を担う
> **コア**（orchestrator / workflow-conductor / requirements-analyst /
> solution-architect / spec-writer / implementation-agent / implementer /
> qa-reviewer / acceptance-tester / code-optimizer / linter-fixer /
> retrospective-analyst / setup-coordinator）と、必要時に description マッチで
> 起動する **支援**（explorer-agent / project-planner / documentation-writer /
> skill-designer）の 2 層。実使用の証跡がない 6 体（agile-coach / scrum-master /
> migration-agent / prompt-engineer / research-analyst / claude-code-reviewer）は
> 2026-06-10 監査で削除（git 履歴から復元可能）。

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

### 実装・品質

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| implementer | [implementer.md](./implementer.md) | `implementer.toml` | exec フェーズのタスク実装（TDD） |
| acceptance-tester | [acceptance-tester.md](./acceptance-tester.md) | `acceptance_tester.toml` | V-1 受け入れ検査 |
| code-optimizer | [code-optimizer.md](./code-optimizer.md) | `code_optimizer.toml` | V-2 コード最適化（high-risk/criticalモード） |
| linter-fixer | [linter-fixer.md](./linter-fixer.md) | `linter_fixer.toml` | L-0 リンター自動修正 |

### 調査・分析

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| explorer-agent | [explorer-agent.md](./explorer-agent.md) | `explorer_agent.toml` | コードベース探索、アーキテクチャ分析 |
| retrospective-analyst | [retrospective-analyst.md](./retrospective-analyst.md) | `retrospective_analyst.toml` | exec後の振り返りデータ分析 |

### 要件・仕様

| エージェント | ファイル | Codex toml | 説明 |
|------------|---------|------------|------|
| spec-writer | [spec-writer.md](./spec-writer.md) | `spec_writer.toml` | 要件構造化、PBI INPUT PACKAGE 作成 |

### v7 ハイブリッドアーキテクチャ（責務ベース 5 体）

v7（`docs/plangate-v7-hybrid.md`）で導入された責務ベース Agent。WF-01〜WF-05 実行層の主担当。Rule 3 準拠（責務のみ、ツール固有/案件固有なし）。

| エージェント | ファイル | 主担当 Phase | 責務 |
|------------|---------|------------|------|
| orchestrator | [orchestrator.md](./orchestrator.md) | WF-01〜WF-05 全体 | phase 遷移 / 委譲 / 完了判定 / handoff 発行（汎用マルチエージェント調整も兼務） |
| requirements-analyst | [requirements-analyst.md](./requirements-analyst.md) | WF-01 / WF-02 | 初期要求 → 仕様変換、曖昧さ整理 |
| solution-architect | [solution-architect.md](./solution-architect.md) | WF-03 | モジュール境界 / データフロー / 状態管理 / 失敗時扱い |
| implementation-agent | [implementation-agent.md](./implementation-agent.md) | WF-04 | design artifact に基づく最小単位実装（TDD） |
| qa-reviewer | [qa-reviewer.md](./qa-reviewer.md) | WF-02 締め / WF-05 | AC 照合・既知課題整理・handoff 中核作成 |

実行シーケンス: [docs/workflows/execution-sequence.md](../../docs/workflows/execution-sequence.md)

**既存 Agent との共存**: 汎用・補助系の既存 11 体は引き続き利用可能。詳細な棲み分けは [docs/working/TASK-0025/evidence/existing-agents-inventory.md](../../docs/working/TASK-0025/evidence/existing-agents-inventory.md) 参照。

---

## Allowed Context（v6）

全エージェントに「Allowed Context（読み込み許可範囲）」セクションが定義されています。
これは PlanGate v6 の Context Isolation 原則に基づき、各エージェントが読む情報を制限してスコープクリープを防ぐものです。

詳細: `.claude/rules/working-context.md`（Progressive Disclosure プロトコル）

## Rule 3 遵守（v7）

v7 責務ベース 5 体は **Rule 3**（Agent は責務だけを持つ。ツール固有手順・案件固有仕様を持たせない）に準拠しています。Rule 1〜5 の統合ルールは [.claude/rules/hybrid-architecture.md](../rules/hybrid-architecture.md) 参照。

---

## 関連ドキュメント

- **[docs/ai/project-rules.md](../../docs/ai/project-rules.md)** — プロジェクトルール正本
- **[.codex/agents/](../../.codex/agents/)** — Codex CLI 向け要約版（`.toml`）
- **[.codex/config.toml](../../.codex/config.toml)** — Codex CLI 設定（エージェント登録）
