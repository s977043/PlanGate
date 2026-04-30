# AGENTS.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）
> **再利用可能な学び**: `AGENT_LEARNINGS.md`（一時メモ・進行中検討は書かない）

## 読む順序

1. `docs/ai/project-rules.md`
2. 本ファイル
3. `.codex/instructions.md`

## このリポジトリの性質

- PlanGate のワークフロー / 設定 / 運用ドキュメント管理
- `package.json` なし → 一般的な lint / test / typecheck コマンドは未定義
- 実行入口: `./scripts/ai-dev-workflow` / `./scripts/codex-local.sh` / `bin/plangate`

## Codex 固有参照

- 実行設定: `.codex/config.toml` / `.codex/instructions.md` / `.codex/agents/*.toml`
- 共有スキル: `.agents/skills/`（Claude Code と共用）
- 役割分担: `docs/ai/tool-roles.md`
- 作業コンテキストプロトコル（Progressive Disclosure）: `.claude/rules/working-context.md`
- ワークフロー: `docs/ai-driven-development.md` / Orchestrator: `docs/orchestrator-mode.md`

## 出力

- 日本語（コミットメッセージ・PR 文面含む）
