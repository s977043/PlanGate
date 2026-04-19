# Skill 共通テンプレート

> 10 新規 Skill 作成で採用した SKILL.md の共通構造。

## 基本構造

```markdown
---
name: {skill-name}
description: "{one-line description including trigger conditions}. Use when: {usage triggers}."
---

# {Skill Title}

{1-2 sentence overview}

## カテゴリ

{Scan / Check / Design / Review / Build}

## 想定 Phase

{WF-01 / WF-02 / WF-03 / WF-04 / WF-05}

## 入力

- {input 1}
- {input 2}
...

## 出力

{output artifact type}:

- {field 1}
- {field 2}
...

## 使い方

- {invocation context}
- {how output is consumed}

## 関連

- Workflow: `docs/workflows/0N_*.md`
- 連携 Skill: {related skill names}
- Rule: Rule 2 / Rule X
```

## 必須フィールド（frontmatter）

- `name`: Skill 名（ディレクトリ名と一致）
- `description`: 1 行の説明 + Use when: トリガー条件

## 必須セクション（本文）

1. タイトル + 概要
2. カテゴリ（Scan / Check / Design / Review / Build のいずれか）
3. 想定 Phase（WF-01〜WF-05 のいずれか or 複数）
4. 入力
5. 出力
6. 使い方
7. 関連

## 採用した方針

### フォーマット

- Markdown ベース（既存 `.claude/skills/brainstorming/SKILL.md` に合わせる）
- 入出力は箇条書きで記述（YAML / JSON は不採用、一貫性優先）

### user-invocable

- 本 TASK の 10 Skill は全て **agent 内部呼び出し前提**
- frontmatter に `user-invocable` は明示しない（デフォルト動作に従う）
- 将来、`/context-load` のようなユーザー直接呼び出しを検討する場合は別タスクで設計

### 案件固有情報の扱い（Rule 2 / Rule 4 遵守）

- 案件固有の技術スタック・プロジェクト名・具体仕様は Skill 内に書かない
- 汎用的な手順・観点のみを記述
- プロジェクト固有情報は CLAUDE.md に委譲

## 既存 Skill との構造比較

既存 `.claude/skills/brainstorming/SKILL.md` が持つ追加構造:

- Iron Law
- Common Rationalizations
- Philosophy
- Prerequisite
- Workflow

これらは議論型 / プロトコル型 Skill に特有で、本 TASK の 10 Skill（観点・手順系）では必須ではない。**シンプル構造を優先**。

## 関連

- SKILL.md ファイル: `.claude/skills/<10 skills>/SKILL.md`
- 既存参考: `.claude/skills/brainstorming/SKILL.md`
