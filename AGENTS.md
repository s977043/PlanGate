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

## Codex 固有の参照先

| カテゴリ | パス |
| --- | --- |
| 実行設定 | `.codex/config.toml` |
| Codex補足ガイド | `.codex/instructions.md` |
| エージェント定義 | `.codex/agents/*.toml` |
| 共有スキル | `.agents/skills/` |
| PlanGate ワークフロー | `docs/plangate.md` |
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
