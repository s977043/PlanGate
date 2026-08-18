---
name: context-packager
description: タスク委譲前に Allowed Context を構造化して出力する。対象ファイル・仕様・既存テスト・変更制約・実行コマンド・禁止スコープを整理し、サブエージェントに渡す文脈を最小化する。
---

# Context Packager

タスクを AI エージェントに委譲する前に、必要最小限の文脈（Allowed Context）を構造化して出力するスキル。
「コンテキスト汚染」（不要な文脈が意思決定を歪める）を防ぐ。

## 目的

サブエージェントが受け取る情報を最小化することで、以下を防ぐ。

- スコープ外のファイル変更
- 無関係な仕様への解釈迷い
- 設計判断の越権（実装者が設計決定をしてしまう）

## Allowed Context の 6 要素

| 要素 | 内容 | 情報源 |
|------|------|--------|
| **対象ファイル（Target Files）** | 変更・参照が許可されるファイルパス一覧 | `plan.md` の Files/Components to Touch |
| **仕様（Spec）** | 受入基準・設計書・API 仕様の要点 | `pbi-input.md` / `design.md` |
| **既存テスト（Existing Tests）** | 関連するテストケース・`test-cases.md` の参照 | `test-cases.md` |
| **変更制約（Constraints）** | 変更してはいけないこと、後方互換性要件 | `plan.md` の Constraints / Non-goals |
| **実行コマンド（Commands）** | ビルド・テスト・lint コマンド | `plan.md` の Testing Strategy |
| **禁止スコープ（Out of Scope）** | このタスクで触れてはいけない領域 | `pbi-input.md` の Out of scope |

## 手順

1. `pbi-input.md` の受入基準・スコープ定義を読む
2. `plan.md` の Work Breakdown・変更ファイル一覧・制約を読む
3. `test-cases.md` から関連テストケースを抽出する
4. 6 要素を構造化して出力形式に整形する
5. Target Files 以外の情報が混入していないか最終確認する

## 出力形式

```markdown
## Allowed Context

### Target Files

- {ファイルパス}: {変更目的}

### Spec

{受入基準・要点（箇条書き）}

### Existing Tests

- {テストファイルパス}: {テスト内容の要約}

### Constraints

- {制約 1}
- {制約 2}

### Commands

- build: {コマンド}
- test: {コマンド}
- lint: {コマンド}

### Out of Scope

- {禁止スコープ 1}
- {禁止スコープ 2}
```

## 入力

- `docs/working/TASK-XXXX/pbi-input.md`（仕様・受入基準）
- `docs/working/TASK-XXXX/plan.md`（変更ファイル一覧・制約）
- `docs/working/TASK-XXXX/test-cases.md`（テストケース）

## 出力

- Allowed Context ブロック（Markdown 形式）
- サブエージェントへの委譲プロンプトに埋め込んで使用する

## 想定 phase

- WF-03 Solution Design（タスク分解後）
- WF-04 Build & Refine（エージェント委譲前）

## カテゴリ

- context-engineering
- subagent-control

## dispatch/ へのファイル保存（#581 要素3）

Allowed Context（6 要素）は委譲プロンプトに埋め込むだけでなく、`docs/working/TASK-XXXX/dispatch/task-NNN-brief.md` に**ファイルとして保存**する。これにより実装者の唯一の要件ファイルとなり、会話 compaction / モデル切替後も再現可能。テンプレは `docs/working/templates/dispatch/task-NNN-brief.md`。

> **参照解決順（導入先で必ずこの順に探す）**: 本 Skill が参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本 Skill 内の記述を代替正本として扱い、推測で内容を補わない。**`<plugin_root>` 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識しないため、`<plugin_root>/docs/...` は構造上存在せず、plugin root 段を置いても必ず空振りする（クラス A の `<plugin_root>/rules/...` が機能するのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

## 関連

- Skill: `subagent-dispatch`（Allowed Context を使ってエージェントに分配）
- Skill: `subagent-team-design` §ステップ 2（6 ロール定義の正本。ロール別の受け取り方の前提）

> 旧 `plugin/plangate/rules/subagent-roles.md` は**削除済み**（TASK-0124 / `2645848`,
> 2026-06-02 の plugin 初回同期適用）。ロール定義は `subagent-team-design` Skill が引き継いだ。
