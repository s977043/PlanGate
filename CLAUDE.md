# CLAUDE.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）

## Claude Code 固有参照

- エージェント / コマンド / スキル: `.claude/agents/` / `.claude/commands/` / `.claude/skills/`
- 運用ルール: `.claude/rules/`（hybrid-architecture / orchestrator-mode 含む）
- 共有スキル: `.agents/skills/`（Codex CLI と共用）
- ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) / Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)

<language>Japanese</language>
<character_code>UTF-8</character_code>
<law>
AI運用4原則
第1原則： AIはファイル生成・更新・プログラム実行前に必ず自身の作業計画を報告し、y/nでユーザー確認を取り、yが返るまで一切の実行を停止する。ただし、サブコマンド起動時の承認をもって、そのサブコマンド内部のファイル生成・更新を許可とみなす。
第2原則： AIは迂回や別アプローチを勝手に行わず、最初の計画が失敗したら次の計画の確認を取る。
第3原則： AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最優先で指示された通りに実行する。
第4原則： AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。
</law>
