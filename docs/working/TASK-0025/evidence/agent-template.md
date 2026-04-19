# Agent 共通テンプレート（既存定義パターン準拠）

> 作成日: 2026-04-20

## frontmatter

```yaml
---
name: <agent-name>         # kebab-case
description: <1 文要約>    # 責務・主担当 phase・参照先を含む
tools: <Tool1>, <Tool2>    # 既存 agents と同形式
model: inherit             # 既定値
---
```

## 本文構造

```markdown
# <Agent 名>

> プロジェクト共通制約は `CLAUDE.md` を参照。

## 責務

<責務の詳細（箇条書き）>

## 呼び出し Skill

<skill 名と役割の箇条書き>

## 委譲関係

<From / To / きっかけ の表>

## 出力

<成果物の箇条書き>

## ツール使用方針

<Read/Grep/Glob, Bash, Edit/Write 等の使い方指針>
<Rule 3 遵守を明記（ツール固有手順・案件固有仕様なし）>

## 参照

<親 PBI、Workflow、関連テンプレート>
```

## Rule 3 遵守チェック

- [ ] 責務以外のこと（実装ノウハウ、ツール固有手順）を本文に書かない
- [ ] 案件固有情報（プロジェクト名、特定フレームワーク、特定 DB）を書かない
- [ ] 呼び出し Skill は本文セクションで表現（frontmatter 拡張ではない）
- [ ] 既存 `.claude/agents/*.md` の定義パターンと整合

## 既存パターンとの比較

既存 `.claude/agents/` の例（例: `orchestrator.md`）:
- frontmatter: name, description, tools, model
- 本文: Your Role, Available Agents, Phases 等

本テンプレートは既存パターンを踏襲しつつ、**責務ベース** として以下を明示:
- 責務セクション（単一責任の明示）
- 呼び出し Skill セクション（`docs/workflows/skill-mapping.md` と対応）
- 委譲関係セクション（Agent 間の動的協働）
