# Codex CLI プロジェクト指示

> 本ファイルは Codex CLI 向けの薄いラッパー。プロジェクトルールの正本は `CLAUDE.md` にある。

## 読み込み順序

1. **`CLAUDE.md`** — プロジェクトの憲法（セクション A〜E を必ず読むこと）
2. **`AGENTS.md`** — エージェント共通指示・スキル一覧
3. **本ファイル** — Codex 固有の補足

## CLAUDE.md から適用するセクション

| セクション | 内容 | Codex での適用 |
|---|---|---|
| A. リポジトリの目的 | スタック・構成 | そのまま適用 |
| B. 主要ディレクトリ | ディレクトリ構造 | そのまま適用 |
| C. 開発の最短ループ | コマンド・コミット前チェック | そのまま適用 |
| D. 変更時のルール | ブランチ命名・PR運用 | そのまま適用 |
| E. 禁止事項 | 編集禁止ファイル・npm禁止等 | そのまま適用 |
| F. 迷ったらの判断基準 | `.claude/` パス参照あり | **下記の読み替え表を使用** |

## Codex 固有の読み替え

CLAUDE.md セクション F 内の参照先を Codex では以下に読み替える:

| CLAUDE.md の記載 | Codex での対応先 |
|---|---|
| `.claude/agents/*.md` | `.codex/agents/*.toml`（要約版）+ `.claude/agents/*.md`（詳細版） |
| `.claude/agents/README.md` | `.codex/agents/README.md` |
| `.claude/rules/*.md` | そのまま参照可（共通ルール） |
| `AGENTS.md` | そのまま参照可（共通SSoT） |

## Codex 固有の設定

- **エージェント定義**: `.codex/agents/*.toml` — 各エージェントの `name`, `description`, `sandbox_mode`, `model_reasoning_effort`, `developer_instructions` を自己完結で保持
- **project-scoped skills**: `.agents/skills/*/SKILL.md` — Codex Cloud / CLI の repo-owned skill 正本
- **config.toml**: `.codex/config.toml` — Codex CLI のコア設定（approval_policy, sandbox_mode, agent 参照）
- **起動ラッパー**: `./scripts/codex-local.sh exec --json "..."` で repo 内の runtime home を使い、project-local の `.codex/` 設定と `~/.codex` の認証を両立させる
- **半自動ワークフロー入口**: `./scripts/ai-dev-workflow STRATEGY-XXXX brainstorm|plan|gate|prepare-cloud|exec|status|sync-cloud`
- **手動Cloud task handoff**: `.codex/manual-cloud-task.md`
- **system/vendor skills**: `.codex/skills/.system/`

Codex は `.claude/skills/` を bridge しない。Codex から使う skill は `.agents/skills/` に置く。
`.agents/skills/` を正本にする理由は、repo-owned / version-controlled な skill だけを Codex の実行対象に固定し、所有者と更新経路を明確に保つため。

## CLAUDE.md で無視してよい項目

以下は Claude Code 固有の記法であり、Codex では無視する:

- `<language>`, `<character_code>`, `<law>`, `<every_chat>` の XML タグ
- `Grep`/`Glob` ツール名への言及（Codex は独自のファイル探索手段を使用）
- Figma MCP サーバーへの言及（Codex 側の MCP はこのブランチでは設定しない）

## 言語

日本語で出力・コミットメッセージ・PR文面を記述する。
