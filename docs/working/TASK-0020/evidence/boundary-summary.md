# TASK-0020 Commands/Skills 境界ルール要約

> 作成日: 2026-04-20
> 参照元: TASK-0018 evidence/command-skill-boundary.md

## 配置ルール（実装済み）

| 種別 | 配置先 | 対象 |
|-----|-------|------|
| Commands | `plugin/plangate/commands/` | 主要導線（スラッシュコマンド直接呼び）: `working-context`, `ai-dev-workflow` |
| Skills | `plugin/plangate/skills/` | 専門スキル（能動呼び出し / 自動起動）: `brainstorming`, `self-review`, `subagent-driven-development`, `systematic-debugging`, `codex-multi-agent` |
| Agents | `plugin/plangate/agents/` | ワークフロー中核 agents: `workflow-conductor`, `spec-writer`, `implementer`, `linter-fixer`, `acceptance-tester`, `code-optimizer` |
| Rules | `plugin/plangate/rules/` | 判定ルール（agents から参照）: `working-context`, `review-principles`, `mode-classification` |

## 使い分けの基準

### Command vs Skill

| 判定軸 | Command 推奨 | Skill 推奨 |
|--------|-------------|-----------|
| 呼び出し UX | ユーザーが明示的に `/foo` でトリガー | LLM が文脈に応じて自動選択 |
| 実行頻度 | セッション開始/終了など特定タイミング | 任意時点で何度でも |
| 複雑度 | 単一工程 | 多段階の判断・プロンプト |
| ステートフル | なし | あり（対話的） |

## デュアル運用

- `.claude/{skills,commands,agents,rules}/` の既存資産は **温存**
- plugin 経由呼び出し: `plangate:` prefix 使用
- 優先順位は Claude Code 内部仕様
- 利用者は必要に応じて片方を無効化可能

## 未同梱（除外理由）

| 名称 | 種別 | 除外理由 |
|-----|------|---------|
| pr-review-response | skill | 存在しない |
| pr-code-review | skill | 存在しない |
| setup-team | skill | 存在しない（`codex-multi-agent` から broken reference あり） |
| test-engineer | agent | 存在しない（implementer が兼務） |
| release-manager | agent | 存在しない（critical モード時のみ必要） |
| プロジェクト固有 agents | agent | Laravel/PostgreSQL/ECS 等依存のため汎用配布に不適合 |
| 専門 agents | agent | opt-in（security-auditor 等）、別 plugin 想定 |
