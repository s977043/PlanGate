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
- **推奨ガード入口**: `scripts/codex-guarded.sh` (PR #343 / #347。session 前後の plan_hash drift 検知と物理 hook bridge を有効化)

## Cursor 固有参照

- 導入手順: [`docs/cursor/quickstart.md`](docs/cursor/quickstart.md)
- RFC: [`docs/rfc/provider-cursor.md`](docs/rfc/provider-cursor.md)
- Hook 配線: `.cursor/hooks.json` → `scripts/hooks/cursor-adapter.sh`
- ルール: `.cursor/rules/plangate.mdc`
- スキル symlink: `.cursor/skills/` → `.agents/skills/`（正本は `.agents/skills/`）

## Codex 固有参照

- 実行設定: `.codex/config.toml` / `.codex/instructions.md` / `.codex/agents/*.toml`
- **Agent Bridge**: `.codex/agents/` の各 agent は Claude Code 側の agent 定義を `instructions` で参照する bridge 構成 (#341)。
- 共有スキル: `.agents/skills/`（Claude Code と共用）
- 役割分担: `docs/ai/tool-roles.md`
- 作業コンテキストプロトコル（Progressive Disclosure）: `.claude/rules/working-context.md`
- ワークフロー: `docs/ai-driven-development.md` / Orchestrator: `docs/orchestrator-mode.md`
- サブエージェント委譲プロトコル: `docs/ai/subagent-delegation/README.md`（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範。既存の C-3/C-4 ゲートおよび orchestrator-mode の Gate 不変条件は変更しない）

## 出力

- 日本語（コミットメッセージ・PR 文面含む）




## Codex CLI 固有参照 (PR #343/#347)

- 正規入口: `scripts/codex-guarded.sh --task TASK-XXXX exec --full-auto`
- 物理 hook: `.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` (EH-1/2/3/6/9 を Codex 側でも発火)
- 強制等価: `docs/ai/settings-wiring-contract.md` §Codex CLI parity
