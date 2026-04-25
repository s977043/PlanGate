# INDEX — TASK-0032

## チケット概要

| 項目 | 内容 |
|------|------|
| **TASK 番号** | TASK-0032 |
| **Issue** | [#57](https://github.com/s977043/plangate/issues/57) |
| **タイトル** | PlanGate 4 Gate システム Phase B — Completion Gate + Mode マトリクス |
| **ステータス** | In Progress（Phase B 実装中） |
| **Mode** | high-risk |
| **作成日** | 2026-04-26 |

## 現在フェーズ

**Phase B: Completion Gate + Mode マトリクス + Working Context 作成中**

- Phase A（design-gate / tdd-gate / review-gate）: 完了済み
- Phase B: 実装中 → コミット後 C-4 PRレビュー待ち

## 主要ファイル一覧

### Working Context

| ファイル | 役割 | L0 |
|---------|------|-----|
| [`INDEX.md`](./INDEX.md) | チケット索引（このファイル） | L0 常読 |
| [`current-state.md`](./current-state.md) | 現在状態スナップショット | L0 常読 |
| [`pbi-input.md`](./pbi-input.md) | PBI INPUT PACKAGE | L1 |
| [`plan.md`](./plan.md) | EXECUTION PLAN | L1 |
| [`todo.md`](./todo.md) | EXECUTION TODO | L1 |
| [`test-cases.md`](./test-cases.md) | テストケース定義 | L1 |
| [`handoff.md`](./handoff.md) | 完了時の引き継ぎパッケージ | WF-05 完了後 |

### 実装ファイル（Phase A: 完了済み）

| ファイル | 概要 |
|---------|------|
| `plugin/plangate/rules/design-gate.md` | Design Gate ルール正本 |
| `plugin/plangate/skills/design-gate/SKILL.md` | Design Gate Skill |
| `plugin/plangate/commands/pg-tdd.md` | TDD Gate コマンド定義 |
| `plugin/plangate/rules/review-gate.md` | Review Gate ルール正本 |
| `plugin/plangate/skills/review-gate/SKILL.md` | Review Gate Skill |

### 実装ファイル（Phase B: 本フェーズ）

| ファイル | 概要 |
|---------|------|
| `plugin/plangate/rules/completion-gate.md` | Completion Gate ルール正本（新規） |
| `plugin/plangate/rules/mode-classification.md` | Gate 適用マトリクス追加（更新） |

## ブランチ構成

| ブランチ | 内容 | 状態 |
|---------|------|------|
| `feature/task-0032-gate-system-design` | Phase A: Design Gate | マージ済み |
| `feature/task-0032-gate-system-tdd-review` | Phase A: TDD + Review Gate | マージ済み |
| `feature/task-0032-gate-system-completion` | Phase B: Completion Gate + Working Context | 作業中 |

## 関連リンク

- 親 Epic: #53
- Issue: #57
- Workflow: `docs/workflows/04_build_and_refine.md`
