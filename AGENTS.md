# AGENTS.md

> Codex CLI 向けエントリーポイント。共通ルールの正本は `docs/ai/project-rules.md` にある。

## プロジェクトルール（共通）

**必読**: `docs/ai/project-rules.md`

開発ルール、ブランチ命名規則、禁止事項、AI運用4原則はすべて上記ファイルに定義されている。

## Codex 固有の参照先

| カテゴリ | パス |
| ------- | ---- |
| 実行設定 | `.codex/config.toml` |
| Codex補足ガイド | `.codex/instructions.md` |
| エージェント定義 | `.codex/agents/*.toml` |
| スキル（正本） | `.claude/skills/`（Claude Code と共有） |
| PlanGate ワークフロー | `docs/plangate.md` |
| 役割分担 | `docs/ai/tool-roles.md` |

## Codex 固有の注意点

- `<language>`, `<law>` 等の XML タグは Claude Code 固有の記法。Codex では無視する
- `Grep`/`Glob` ツール名への言及は Claude Code 固有。Codex は独自のファイル探索手段を使用
- Codex 詳細設定と読み替え表: `.codex/instructions.md` を参照

## 迷ったらの判断基準

**優先順位**: `docs/ai/project-rules.md`（正本）> `AGENTS.md`（ツール固有設定）> `.codex/instructions.md` > `.codex/config.toml`

- 既存コードを探索し、既存パターンに従う。一般論で上書きしない
- 不明点はユーザーに確認する（AI運用原則第1原則に従う）

## 言語

日本語で出力・コミットメッセージ・PR文面を記述する。
