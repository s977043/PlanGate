# EXECUTION PLAN — TASK-0032

## メタ情報

```yaml
task: TASK-0032
related_issue: https://github.com/s977043/plangate/issues/57
phase: B（EXECUTION PLAN）
created_at: 2026-04-26
```

## Goal

4 Gate システム（Design Gate / TDD Gate / Review Gate / Completion Gate）を定義し、Mode 別に適用条件を明確化する。
「動くはず」「たぶん通過した」という曖昧な完了主張を排除し、証拠に基づく Gate 通過を強制する仕組みを Markdown 定義として完成させる。

## Constraints / Non-goals

**制約**:
- `mode-classification.md` は既存内容を壊さず、セクション追加のみ行うこと
- 全ファイルを日本語で作成すること
- Rule 2 違反（Skill にプロジェクト固有情報を入れる）を避けること
- Markdown の見出し構造を正しく保つこと（markdownlint CI が走る）

**Non-goals**:
- CI hook の自動化（GitHub Actions / pre-commit フック実装）
- TypeScript / JSON スキーマ実装
- 4 Gate 以外の追加 Gate

## Approach Overview

Phase A（完了済み）: Design Gate / TDD Gate / Review Gate の個別ルール・Skill を定義
Phase B（本計画）: Completion Gate で全 Gate を統合し、Mode マトリクスを mode-classification.md に追加。Working Context 一式を作成してチケットを完了させる。

## Work Breakdown

### Phase A（完了済み）

| Step | Output | Owner | 状態 |
|------|--------|-------|------|
| A-1 | `plugin/plangate/rules/design-gate.md` | Agent A | 完了 |
| A-2 | `plugin/plangate/skills/design-gate/SKILL.md` | Agent A | 完了 |
| A-3 | `plugin/plangate/commands/pg-tdd.md` | Agent B | 完了 |
| A-4 | `plugin/plangate/rules/review-gate.md` | Agent B | 完了 |
| A-5 | `plugin/plangate/skills/review-gate/SKILL.md` | Agent B | 完了 |

### Phase B（本計画）

| Step | Output | Owner | Risk | チェックポイント |
|------|--------|-------|------|----------------|
| B-1 | `plugin/plangate/rules/completion-gate.md` 作成 | Agent C | 低: Phase A との整合性 | 5 ブロック条件が全て記述されているか |
| B-2 | `plugin/plangate/rules/mode-classification.md` 更新 | Agent C | 低: 既存内容を破壊しない | Gate 適用マトリクスが正しく追加されたか |
| B-3 | `docs/working/TASK-0032/` 一式作成 | Agent C | 低 | 7 ファイルが全て作成されたか |
| B-4 | コミット | Agent C | 低 | git log で確認 |

## Files / Components to Touch

| ファイル | 操作 |
|---------|------|
| `plugin/plangate/rules/completion-gate.md` | 新規作成 |
| `plugin/plangate/rules/mode-classification.md` | 更新（Gate 適用マトリクスセクション追加） |
| `docs/working/TASK-0032/pbi-input.md` | 新規作成 |
| `docs/working/TASK-0032/plan.md` | 新規作成 |
| `docs/working/TASK-0032/todo.md` | 新規作成 |
| `docs/working/TASK-0032/test-cases.md` | 新規作成 |
| `docs/working/TASK-0032/INDEX.md` | 新規作成 |
| `docs/working/TASK-0032/current-state.md` | 新規作成 |
| `docs/working/TASK-0032/handoff.md` | 新規作成 |

## Testing Strategy

- **文書確認テスト**: acceptance-tester が test-cases.md の 6 AC を突合確認
- **自動化**: markdownlint CI による Markdown 構造チェック
- **手動確認**: 各 Gate ルールファイルの参照関係が正しいか確認

## Risks & Mitigations

| リスク | 対策 |
|--------|------|
| `mode-classification.md` の既存セクションを壊す | セクション追加のみ、既存行は変更しない |
| `completion-gate.md` と `evidence-ledger.md` の整合性ズレ | 参照パスを明示し、ブロック条件を evidence-ledger.md の正本に合わせる |
| handoff.md のテスト結果が pending | acceptance-tester 実施前は「pending」と明記し、V1 リリース後に更新 |

## Questions / Unknowns

- なし（Phase A で全ての前提情報が確定済み）

## Mode 判定

**モード**: `high-risk`

**判定根拠**:
- 変更ファイル数: 9 件 → high-risk（6-15 件）
- 受入基準数: 6 件 → high-risk（6-10 件）
- 変更種別: 機能追加（Gate システム完成） → high-risk
- リスク: 中程度（複数ファイル・複数レイヤーへの変更） → high-risk
- **最終判定**: `high-risk`
