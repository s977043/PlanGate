# Codex CLIプロジェクト指示

> 本ファイルはCodex CLI向けの補足ガイド。
> プロジェクトルールの正本は`docs/ai/project-rules.md`にある。

## 読み込み順序

1. **`docs/ai/project-rules.md`** — プロジェクト共通ルール（正本）
2. **本ファイル** — Codex固有の補足
3. **`.codex/config.toml`** — Codex実行設定

## Codex固有の読み替え

Claude Code向けドキュメント内の参照先をCodexでは以下に読み替える:

| Claude Codeの記載 | Codexでの対応先 |
| --- | --- |
| `.claude/agents/*.md` | `.codex/agents/*.toml`（要約版）+`.claude/agents/*.md`（詳細版） |
| `.claude/rules/*.md` | そのまま参照可（共通ルール） |
| `.claude/skills/README.md` | `.codex/README.md`のSkillsセクション |

## Codex固有の設定

- **エージェント定義**: `.codex/agents/*.toml` — 各エージェントの`name`, `description`, `sandbox_mode`, `model_reasoning_effort`, `developer_instructions`を保持
- **config.toml**: `.codex/config.toml` — Codex CLIのコア設定（approval_policy, sandbox_mode, agent参照）
- **起動ラッパー**: `sh ./scripts/codex-local.sh exec --json "..."`で`CODEX_HOME`をrepo内の`.codex/`に固定する

## Claude Code固有の記法（Codexでは無視）

以下はClaude Code固有であり、Codexでは無視する:

- `<language>`, `<character_code>`, `<law>`のXMLタグ
- `Grep`/`Glob`ツール名への言及（Codexは独自のファイル探索手段を使用）

## 言語

日本語で出力・コミットメッセージ・PR文面を記述する。
