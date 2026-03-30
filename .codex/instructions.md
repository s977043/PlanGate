# Codex CLI プロジェクト指示

> 本ファイルは Codex CLI 向けの薄いラッパー。プロジェクトルールの正本は `CLAUDE.md` にある。
> ワークフロー: PlanGate v5（`docs/plangate.md`）

## 読み込み順序

1. **`CLAUDE.md`** — プロジェクトの憲法（セクション A〜F を必ず読むこと）
2. **本ファイル** — Codex 固有の補足

## CLAUDE.md から適用するセクション

| セクション | 内容 | Codex での適用 |
|---|---|---|
| A. リポジトリの目的 | ナレッジベースの位置づけ | そのまま適用 |
| B. ディレクトリ構造 | docs/, .claude/ 構造 | そのまま適用 |
| C. 開発ルール | ブランチ命名・PR運用 | そのまま適用 |
| D. 作業コンテキスト | docs/working/ の管理 | そのまま適用 |
| E. 禁止事項 | 編集禁止ファイル等 | そのまま適用 |
| F. 迷ったらの判断基準 | `.claude/` パス参照あり | **下記の読み替え表を使用** |

## Codex 固有の読み替え

CLAUDE.md セクション F 内の参照先を Codex では以下に読み替える:

| CLAUDE.md の記載 | Codex での対応先 |
|---|---|
| `.claude/agents/*.md` | `.codex/agents/*.toml`（要約版）+ `.claude/agents/*.md`（詳細版） |
| `.claude/rules/*.md` | そのまま参照可（共通ルール） |
| `.claude/skills/README.md` | `.codex/README.md` の Skills セクション |

## Codex 固有の設定

- **エージェント定義**: `.codex/agents/*.toml` — 各エージェントの `name`, `description`, `sandbox_mode`, `model_reasoning_effort`, `developer_instructions` を保持
- **config.toml**: `.codex/config.toml` — Codex CLI のコア設定（approval_policy, sandbox_mode, agent 参照）
- **起動ラッパー**: `sh ./scripts/codex-local.sh exec --json "..."` で `CODEX_HOME` を repo 内の `.codex/` に固定する

## CLAUDE.md で無視してよい項目

以下は Claude Code 固有の記法であり、Codex では無視する:

- `<language>`, `<character_code>`, `<law>` の XML タグ
- `Grep`/`Glob` ツール名への言及（Codex は独自のファイル探索手段を使用）

## 言語

日本語で出力・コミットメッセージ・PR文面を記述する。
