---
name: subagent-dispatch
description: high-risk/critical モードでタスクをロール別エージェントに分配する。依存関係グラフを生成し、並列実行可能タスクを特定して Allowed Context と共に dispatch する。
---

# Subagent Dispatch

high-risk/critical モードでタスクをロール別エージェントに分配するスキル。
依存関係グラフを生成し、並列実行可能なタスクを特定する。

## 目的

マルチエージェント実行を安全に行うために、以下を保証する。

- 各エージェントが適切なロールを担う（`subagent-team-design` Skill のロール定義に基づく）
- 並列実行による競合（同一ファイルの同時変更）を防ぐ
- 依存関係のある処理が正しい順序で実行される

## 手順（5 ステップ）

1. `plan.md` の Work Breakdown からタスクを列挙する
2. 各タスクに `subagent-team-design` Skill のロール定義（6 ロール）からロールを割り当てる
3. タスク間の依存関係を特定し、依存関係グラフを生成する
4. 依存がないタスクを「並列実行可能」としてグループ化する
5. 各タスクに `context-packager` を適用して Allowed Context を生成する

## 並列実行判定基準

| 条件 | 判定 |
|------|------|
| Allowed Context（Target Files）が重複しない | 並列可 |
| 共有状態（同一ファイル）を変更する | 逐次 |
| reviewee が実装完了するまで reviewer は待機 | 逐次 |
| 同一 pbi-input.md への仕様参照のみ | 並列可 |

## 入力

- 実行モード（high-risk / critical）
- `docs/working/TASK-XXXX/plan.md`（Work Breakdown）
- `docs/working/TASK-XXXX/test-cases.md`
- `.agents/skills/subagent-team-design/SKILL.md` §ステップ 2（6 ロール定義）

## 出力: Dispatch パッケージ

```markdown
## Dispatch パッケージ

### Mode: {high-risk | critical}

### フェーズ構成

#### Phase A（並列実行可能）

| エージェント | ロール | 担当タスク | Allowed Context |
|------------|--------|----------|----------------|
| Agent-1 | implementer | {タスク名} | {context-packager 出力へのリンク} |
| Agent-2 | implementer | {タスク名} | {context-packager 出力へのリンク} |

#### Phase B（Phase A 完了後）

| エージェント | ロール | 担当タスク | 入力 |
|------------|--------|----------|-----|
| Agent-3 | reviewer | 全実装のレビュー | Phase A の出力 |
| Agent-4 | security-reviewer | セキュリティレビュー | Phase A の出力 |

### 依存関係グラフ（Mermaid）

\`\`\`mermaid
graph TD
  A[planner] --> B[implementer-1]
  A --> C[implementer-2]
  B --> D[reviewer]
  C --> D
  D --> E[Completion Gate]
\`\`\`

### 並列実行判定結果

- Agent-1 と Agent-2: Target Files が重複しない → 並列可
- Agent-3 と Agent-4: 同じ実装を入力として受け取る → 並列可
- Agent-1/2 → Agent-3/4: 実装完了後にレビュー開始 → 逐次
```

## 想定 phase

- WF-03 Solution Design（マルチエージェント設計時）
- WF-04 Build & Refine（実行前）

## カテゴリ

- multi-agent
- orchestration

## ファイルベース受け渡し（#581 要素3）

subagent へは会話履歴でなく **`dispatch/` 配下のファイル**で渡す:

- task brief: `dispatch/task-NNN-brief.md`（context-packager の Allowed Context）
- report: `dispatch/task-NNN-report.md`（実行コマンド・テスト結果・変更サマリ・懸念）
- review package: `dispatch/task-NNN-review-package.md`（reviewer 入力を brief/report/diff/evidence へのリンクで固定）
- progress ledger: `dispatch/progress-ledger.md`（進捗。compaction・モデル切替後はここから再開）

reviewer は review-package ファイルのみを入力とし、会話履歴は渡さない。テンプレは `docs/working/templates/dispatch/`。

## 関連

- Skill: `context-packager`（各エージェントへの Allowed Context 生成）
- Skill: `subagent-team-design` §ステップ 2（6 ロール定義の正本）
- Skill: `pr-decision`（Gate / Evidence / Review を集約した最終 go/no-go 判定）

> 旧 `plugin/plangate/rules/subagent-roles.md` / `plugin/plangate/rules/completion-gate.md` は
> **削除済み**（TASK-0124 / `2645848`, 2026-06-02 の plugin 初回同期適用）。
> ロール定義は `subagent-team-design` Skill が引き継いだ。
> Completion Gate の 5 条件チェックポイントを定義した正本は**後継なし**であり、
> 実務上の統合判定は `pr-decision` Skill が担う（本 Skill の Mermaid 図中の
> `Completion Gate` は概念ノードであり、参照可能な正本ファイルは存在しない）。
