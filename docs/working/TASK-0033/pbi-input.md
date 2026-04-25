# PBI INPUT PACKAGE — TASK-0033

## メタ情報

```yaml
task: TASK-0033
issue: https://github.com/s977043/plangate/issues/58
epic: "#53 Phase 3: エージェント統制層"
author: human
created_at: 2026-04-26
```

## Context / Why（なぜやるか）

Phase 2（TASK-0032 Gate System）が完了し、Gate System による実行品質の担保が実現された。
Phase 3 では、マルチエージェント実行において発生しうる以下の問題を解決するためのエージェント統制層を追加する:

- **情報汚染**: エージェントが必要以上の情報を参照し、意図しない変更を加える
- **責務曖昧**: サブエージェントのロールが明確でなく、レビュー品質が属人的になる
- **PR 可否の属人的判断**: 「たぶん通過した」による曖昧な PR 作成を排除できていない

## What（Scope）

### In scope

| コンポーネント | 担当エージェント |
|-------------|--------------|
| Context Packager（コンテキスト制限） | Agent D |
| Subagent Roles（サブエージェント役割定義） | Agent D |
| Subagent Dispatch（サブエージェント指示） | Agent D |
| Worktree Policy（worktree 適用条件） | Agent E（本タスク） |
| PR Decision（PR 可否判定） | Agent E（本タスク） |
| Working Context 一式（TASK-0033） | Agent E（本タスク） |

### Out of scope

- Codex CLI への統合（別 Epic で対応）
- CI フック化（別 PBI で対応）
- 既存エージェント定義（`.claude/agents/`）の修正
- Gate System（TASK-0032）の変更

## 受入基準（5 件）

| AC | 内容 |
|----|------|
| AC-1 | タスクごとに Allowed Context を生成できる（context-packager/SKILL.md） |
| AC-2 | high-risk/critical で worktree requirement を表現できる（worktree-policy.md + skill-policy-router 接続） |
| AC-3 | subagent ごとに渡す文脈を制限できる（subagent-dispatch/SKILL.md） |
| AC-4 | review 結果を severity 付きで統合できる（subagent-roles.md の reviewer ロール定義） |
| AC-5 | Evidence Ledger + Review Gate + GateStatus から PR 判断を出せる（pr-decision/SKILL.md） |

## Notes from Refinement

- Agent D と Agent E は並列実行可能（依存関係なし）
- AC-2 は `skill-policy-router` の `requiresWorktree` フラグとの接続を明記すること
- AC-5 の PR 判断は structured output で出力し、APPROVE / BLOCK / CONDITIONAL の 3 値判定とすること
- 全成果物は Rule 2（Skill にプロジェクト固有情報を入れない）に準拠すること
- Rule 5 に従い handoff.md を必須出力とする

## Estimation Evidence

### Risks

| リスク | 対応 |
|-------|------|
| Agent D / E の成果物が整合しない | working context（plan.md）で全体設計を共有 |
| Rule 2 違反（プロジェクト固有情報の混入） | Skill 作成時に Rule 2 チェックリストを適用 |

### Unknowns

- subagent-roles.md の reviewer 定義は TASK-0032 の review-gate.md の severity 定義と整合する必要がある

### Assumptions

- TASK-0032 の Gate System は main にマージ済みであること
- `plugin/plangate/skills/skill-policy-router/SKILL.md` の `requiresWorktree` フラグが存在すること
