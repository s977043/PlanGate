---
name: working-context
description: ローカル worktree の ticket コンテキストを読込・更新する。Cloud task 用の handoff packet を準備したい時にも使う。
---

# Working Context

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `docs/ai-driven-development.md`
   - 最低限読む範囲: `## ワークフロー全体像`、`## ゲート条件`、`## 成果物の保存先`、`## workflow-conductor（v3追加）`
4. `docs/working/TASK-XXXX/status.md`
5. `docs/working/TASK-XXXX/plan.md`
6. `docs/working/TASK-XXXX/todo.md`
7. `docs/working/TASK-XXXX/test-cases.md`
8. `.codex/manual-cloud-task.md`

## Rules

- セッション開始時は status → plan → todo → test-cases の順で確認する
- 計画からの逸脱は status.md に記録する
- 完了したタスクは todo.md と status.md の両方に反映する
- 次回再開時に困らない粒度で記録する
- Cloud task に渡す前に、承認済み内容を `.codex/manual-cloud-task.md` に転記する
