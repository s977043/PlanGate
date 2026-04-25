# INDEX — TASK-0033

## メタ情報

```yaml
task: TASK-0033
issue: https://github.com/s977043/plangate/issues/58
epic: "#53 Phase 3: エージェント統制層"
status: In Progress（Agent E 実装中）
mode: full
created_at: 2026-04-26
updated_at: 2026-04-26
```

## 概要

マルチエージェント実行における情報汚染・責務曖昧・PR 可否の属人的判断を排除するためのエージェント統制層を定義する。

Agent D と Agent E が並列実行し、5 つのコンポーネントを実装する。

## 担当エージェントと成果物

| エージェント | ブランチ | 担当コンポーネント |
|------------|---------|----------------|
| Agent D | `feature/task-0033-agent-control-context-dispatch` | context-packager / subagent-roles / subagent-dispatch |
| Agent E | `feature/task-0033-agent-control-worktree-pr` | worktree-policy / pr-decision / working context |

## ファイル一覧

| ファイル | 種別 | フェーズ | 状態 |
|---------|------|---------|------|
| `pbi-input.md` | Working Context | A | 完了 |
| `plan.md` | Working Context | B | 完了 |
| `todo.md` | Working Context | B | 完了 |
| `test-cases.md` | Working Context | B | 完了 |
| `INDEX.md` | Working Context | B | 完了 |
| `current-state.md` | Working Context | B〜 | 更新中 |
| `handoff.md` | Working Context | WF-05 | 完了（事前発行） |

## 受入基準サマリ

| AC | 対応コンポーネント | 担当 | 状態 |
|----|----------------|-----|------|
| AC-1 | context-packager/SKILL.md | Agent D | — |
| AC-2 | worktree-policy.md | Agent E | 実装中 |
| AC-3 | subagent-dispatch/SKILL.md | Agent D | — |
| AC-4 | subagent-roles.md | Agent D | — |
| AC-5 | pr-decision/SKILL.md | Agent E | 実装中 |

## Progressive Disclosure プロトコル

| Level | 読み込み対象 | タイミング |
|-------|------------|----------|
| L0 | INDEX.md → current-state.md | セッション開始時 |
| L1 | plan.md, todo.md, test-cases.md | exec フェーズ |
| L2 | evidence/, decision-log.jsonl | レビュー根拠確認時 |
