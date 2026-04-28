# AGENTS.md

> Codex CLI 向けの入口。共通ルールの正本は `docs/ai/project-rules.md`、再利用可能な学びは `AGENT_LEARNINGS.md` に置く。

## まず読むもの

1. `docs/ai/project-rules.md`
2. 本ファイル
3. `.codex/instructions.md`
4. `docs/ai/tool-roles.md`

## このリポジトリの性質

- PlanGate のワークフロー、設定、運用ドキュメントを管理するリポジトリ
- 現時点で `package.json` などの package manager 定義はない
- そのため、一般的な `lint` / `test` / `typecheck` コマンドもこのリポジトリには定義されていない
- 実行可能な入口は `./scripts/ai-dev-workflow` と `./scripts/codex-local.sh`

## コンテキスト読み込みプロトコル（v6）

チケット作業時は Progressive Disclosure に従い段階的に読み込む。詳細は `.claude/rules/working-context.md` を参照。

| Level | ファイル | タイミング |
|-------|---------|----------|
| L0 | INDEX.md → current-state.md | 常に最初に読む |
| L1 | フェーズに応じて（plan→pbi-input / exec→plan,todo,test-cases / review→plan,review-*） | フェーズ確認後 |
| L2 | evidence/, decision-log.jsonl | 根拠が必要な時のみ |
| L3 | status.md全体, 他チケット | 履歴全体が必要な時のみ |

> INDEX.md が存在しない旧形式チケットでは L1 から開始（従来動作）。

## Codex 固有の参照先

| カテゴリ | パス |
| --- | --- |
| 実行設定 | `.codex/config.toml` |
| Codex補足ガイド | `.codex/instructions.md` |
| エージェント定義 | `.codex/agents/*.toml` |
| 共有スキル | `.agents/skills/` |
| PlanGate ワークフロー（v5 現行） | `docs/plangate.md` |
| PlanGate v7 ハイブリッド | `docs/plangate-v7-hybrid.md` / `.claude/rules/hybrid-architecture.md` |
| Orchestrator Mode（親 PBI 分解、Spec only） | `docs/orchestrator-mode.md` / `.claude/rules/orchestrator-mode.md` |
| v7 Workflow 定義（WF-01〜WF-05 + Orchestrator） | `docs/workflows/README.md` |
| 役割分担 | `docs/ai/tool-roles.md` |
| 作業コンテキスト | `docs/working/README.md` |
| 学びの蓄積 | `AGENT_LEARNINGS.md` |

## 作業ルール

- 既存のコマンドや構成に合わせ、存在しないコマンドは書かない
- 変更前に既存の README、docs、scripts を確認する
- secrets、認証情報、個人情報は残さない
- 一時メモや進行中の検討は `AGENT_LEARNINGS.md` に書かない
- 不明点は推測で埋めず、必要ならユーザーに確認する

## 判断基準

**優先順位**: `docs/ai/project-rules.md` > `AGENTS.md` > `.codex/instructions.md` > `.codex/config.toml`

- 既存パターンを優先し、一般論で上書きしない
- 日本語で出力、コミットメッセージ、PR文面を記述する
