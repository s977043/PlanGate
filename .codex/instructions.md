# Codex CLI プロジェクト指示

> 本ファイルは Codex CLI 向けの薄いラッパー。プロジェクトルールの正本は `docs/ai/project-rules.md` にある。

## 読み込み順序

1. **`docs/ai/project-rules.md`** — プロジェクト共通ルールの正本
2. **`AGENTS.md`** — Codex / エージェント向けの入口
3. **本ファイル** — Codex 固有の補足
4. **`CLAUDE.md`** — Claude Code 側の補助情報。必要箇所のみ読み替えて参照

## project-rules から適用するセクション

| セクション | 内容 | Codex での適用 |
|---|---|---|
| A. リポジトリの目的 | スタック・構成 | そのまま適用 |
| B. 主要ディレクトリ | ディレクトリ構造 | そのまま適用 |
| C. 開発ルール | ブランチ命名・PR運用 | そのまま適用 |
| D. 作業コンテキスト | `docs/working/` 運用 | そのまま適用 |
| E. 禁止事項 | 編集禁止ファイル等 | そのまま適用 |
| F. AI運用4原則 | 承認・停止・決定権の原則 | そのまま適用 |
| G. 参照先 | 補助ドキュメント一覧 | `CLAUDE.md` / `AGENTS.md` の入口情報と合わせて参照 |

## コンテキスト読み込みプロトコル（v6）

チケット作業時は Progressive Disclosure に従い段階的に読み込む。詳細は `.claude/rules/working-context.md` を参照。

| Level | ファイル | タイミング |
|-------|---------|----------|
| L0 | `INDEX.md` → `current-state.md` | 常に最初に読む |
| L1 | フェーズに応じて（plan→`pbi-input.md` / exec→`plan.md`,`todo.md`,`test-cases.md` / review→`plan.md`,`review-*.md`） | フェーズ確認後 |
| L2 | `evidence/`, `decision-log.jsonl` | 根拠が必要な時のみ |
| L3 | `status.md`全体, 他チケット | 履歴全体が必要な時のみ |

> `INDEX.md` が存在しない旧形式チケットでは L1 から開始（従来動作）。

**Codex Cloud task での適用**: Cloud task 実行時も上記プロトコルに従う。`.codex/manual-cloud-task.md` の handoff packet に `INDEX.md` / `current-state.md` の参照を含めること。

## Codex 固有の読み替え

`CLAUDE.md` / `AGENTS.md` 内の `.claude/` 系参照は Codex では以下に読み替える:

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
- **半自動ワークフロー入口**: `./scripts/ai-dev-workflow TASK-XXXX brainstorm|plan|gate|prepare-cloud|exec|status|sync-cloud`
- **手動Cloud task handoff**: `.codex/manual-cloud-task.md`
- **system/vendor skills**: `.codex/skills/.system/`（通常は Codex 実行時に runtime 側でマウントされ、repo にはコミットしない）

Codex は `.claude/skills/` を bridge しない。Codex から使う skill は `.agents/skills/` に置く。
`.agents/skills/` を正本にする理由は、repo-owned / version-controlled な skill だけを Codex の実行対象に固定し、所有者と更新経路を明確に保つため。

## CLAUDE.md で無視してよい項目

以下は Claude Code 固有の記法であり、Codex では無視する:

- `<language>`, `<character_code>`, `<law>`, `<every_chat>` の XML タグ
- `Grep`/`Glob` ツール名への言及（Codex は独自のファイル探索手段を使用）
- Figma MCP サーバーへの言及（Codex 側の MCP はこのブランチでは設定しない）

## 言語

日本語で出力・コミットメッセージ・PR文面を記述する。
