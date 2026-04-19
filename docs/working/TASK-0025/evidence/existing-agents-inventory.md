# TASK-0025 既存 Agent インベントリと責務マッピング

> 作成日: 2026-04-20

## 既存 `.claude/agents/` 18 体（+README）

| Agent | 責務（要約） | TASK-0025 新規 5 体との関係 |
|-------|-------------|---------------------------|
| orchestrator | マルチエージェント調整と専門タスク委譲 | **兼任**: `orchestrator` の責務を満たす（新規作成不要） |
| workflow-conductor | フェーズ遷移管理、L-0/V-1〜V-4 制御 | 重複あり: PlanGate 特化版。共存（legacy） |
| spec-writer | PBI INPUT PACKAGE 構造化、plan/todo/test-cases 生成 | 部分重複: 新規 `requirements-analyst` は「曖昧さ解消」に特化 |
| implementer | TDD 実装、テスト駆動開発 | 部分重複: 新規 `implementation-agent` は「小単位自己レビュー」を明示 |
| acceptance-tester | test-cases.md 完了条件と PASS/FAIL 判定 | 部分重複: 新規 `qa-reviewer` は「V1/V2 境界整理」を含む |
| code-optimizer | V-2 リファクタ、可読性 | 重複なし: 別責務（optimize）として共存 |
| linter-fixer | L-0 リンター自動修正 | 重複なし: 別責務として共存 |
| agile-coach | アジャイル支援、フィードバック設計 | 重複なし: 別責務 |
| scrum-master | Sprint Planning、Daily Scrum 支援 | 重複なし: 別責務 |
| documentation-writer | テクニカルドキュメント | 重複なし: 別責務 |
| migration-agent | 依存関係アップグレード | 重複なし |
| explorer-agent | コードベース探索 | 重複なし |
| research-analyst | 技術調査・実現可能性分析 | 重複なし |
| prompt-engineer | エージェント・スキル定義の品質改善 | 重複なし |
| skill-designer | スキル設計・SKILL.md 作成 | 重複なし |
| retrospective-analyst | 振り返り分析 | 重複なし |
| claude-code-reviewer | Claude Code レビュー | 重複なし |
| project-planner | プロジェクト計画立案 | 重複なし |

## 新規 5 体の配置方針

| 新規 Agent | 配置方針 |
|-----------|---------|
| `orchestrator` | **既存を採用**、新規作成不要（責務が一致） |
| `requirements-analyst` | **新規作成**、既存 spec-writer と共存（責務が異なる） |
| `solution-architect` | **新規作成**、既存に該当なし |
| `implementation-agent` | **新規作成**、既存 implementer と共存 |
| `qa-reviewer` | **新規作成**、既存 acceptance-tester と共存 |

## 結論

本 TASK で新規作成するのは **4 体**（orchestrator は既存を採用）。

既存と責務が部分重複する 3 件（spec-writer / implementer / acceptance-tester）は、PlanGate 特化版として legacy に残し、新規は汎用的な責務ベース版として共存させる。
