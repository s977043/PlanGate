# EXECUTION PLAN — TASK-0033

## メタ情報

```yaml
task: TASK-0033
issue: https://github.com/s977043/plangate/issues/58
author: implementation-agent
created_at: 2026-04-26
mode: full
```

## Goal

エージェント統制層を定義し、マルチエージェント実行の品質を担保する。
Context Packager / Subagent Roles / Subagent Dispatch / Worktree Policy / PR Decision の 5 コンポーネントを実装することで、情報汚染・責務曖昧・PR 可否の属人的判断を排除する。

## Constraints / Non-goals

**Constraints**:

- Rule 2 遵守: Skill にプロジェクト固有情報を入れない
- Rule 5 遵守: handoff.md を必須出力とする
- 既存 Gate System（TASK-0032）の変更は行わない
- `plugin/plangate/skills/skill-policy-router/SKILL.md` の `requiresWorktree` フラグとの整合を保つ

**Non-goals**:

- Codex CLI への統合
- CI フック化
- 既存エージェント定義の修正

## Approach Overview

Agent D と Agent E を並列実行する分割実装を採用する。

- **Agent D**: context-packager / subagent-roles / subagent-dispatch を担当
- **Agent E**: worktree-policy / pr-decision / working context を担当

各エージェントは独立したブランチで作業し、acceptance-tester が 5 AC を突合して統合検証する。

## Work Breakdown

### Phase 1: 準備

| Step | Output | Owner | Risk |
|------|--------|-------|------|
| 既存 Rule / Skill の参照確認 | 参照リスト | agent | 既存定義との不整合 |
| worktree 作成 | `feature/task-0033-agent-control-worktree-pr` | agent | — |

🚩 チェックポイント: 参照ファイルを全て読み込み、整合性を確認した

### Phase 2: 実装（Agent E 担当）

| Step | Output | Owner | Risk |
|------|--------|-------|------|
| worktree-policy.md 作成 | `plugin/plangate/rules/worktree-policy.md` | agent | Rule 2 違反 |
| pr-decision/SKILL.md 作成 | `plugin/plangate/skills/pr-decision/SKILL.md` | agent | Rule 2 違反 |
| working context 作成 | `docs/working/TASK-0033/*.md` | agent | — |

🚩 チェックポイント: 各ファイルが Rule 2 チェック（プロジェクト固有情報なし）を通過した

### Phase 3: 検証・完了

| Step | Output | Owner | Risk |
|------|--------|-------|------|
| handoff.md 作成 | `docs/working/TASK-0033/handoff.md` | agent | — |
| PR 作成 | GitHub PR | agent | — |
| acceptance-tester による 5 AC 突合 | テスト結果 | agent | — |

🚩 チェックポイント: 5 AC が全て突合完了

## Files / Components to Touch

### 新規作成（Agent E 担当）

| ファイル | 種別 |
|---------|------|
| `plugin/plangate/rules/worktree-policy.md` | Rule |
| `plugin/plangate/skills/pr-decision/SKILL.md` | Skill |
| `docs/working/TASK-0033/pbi-input.md` | Working Context |
| `docs/working/TASK-0033/plan.md` | Working Context |
| `docs/working/TASK-0033/todo.md` | Working Context |
| `docs/working/TASK-0033/test-cases.md` | Working Context |
| `docs/working/TASK-0033/INDEX.md` | Working Context |
| `docs/working/TASK-0033/current-state.md` | Working Context |
| `docs/working/TASK-0033/handoff.md` | Working Context |

### 新規作成（Agent D 担当）

| ファイル | 種別 |
|---------|------|
| `plugin/plangate/skills/context-packager/SKILL.md` | Skill |
| `plugin/plangate/rules/subagent-roles.md` | Rule |
| `plugin/plangate/skills/subagent-dispatch/SKILL.md` | Skill |

### 参照のみ（変更なし）

- `plugin/plangate/rules/completion-gate.md`
- `plugin/plangate/rules/evidence-ledger.md`
- `plugin/plangate/rules/review-gate.md`
- `plugin/plangate/rules/mode-classification.md`
- `plugin/plangate/skills/skill-policy-router/SKILL.md`

## Testing Strategy

| レイヤー | 手法 | 実施タイミング |
|---------|------|-------------|
| 文書確認 | acceptance-tester による 5 AC 突合 | PR 作成前 |
| Rule 2 チェック | grep による固有情報の不在確認 | 実装完了後 |
| 構造確認 | frontmatter / 必須セクションの存在確認 | 実装完了後 |

## Risks & Mitigations

| リスク | Severity | Mitigation |
|-------|---------|-----------|
| Agent D の成果物と整合しない | major | working context で設計共有、AC マッピングで整合確認 |
| Rule 2 違反（固有情報混入） | major | 実装後に grep でチェック |
| Skill の frontmatter 欠落 | minor | テンプレートを参照して作成 |

## Questions / Unknowns

- Agent D の成果物（context-packager / subagent-roles / subagent-dispatch）は別ブランチで実装されるため、統合 PR でのコンフリクトに注意

## Mode 判定

**モード**: full

**判定根拠**:

- 変更ファイル数: 9 件（Agent E 担当分） → full
- 受入基準数: 5 件 → standard〜full
- 変更種別: 機能追加（Rule + Skill 新規定義） → full
- リスク: 高（マルチエージェント統制の新設） → full
- **最終判定**: full
