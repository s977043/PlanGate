# STATUS — TASK-0131 (#565)

## C-3 Gate: APPROVED
- c3.json: APPROVED（plan_hash sha256:1e90e1f…）
- 人間承認: presence gate 通過（通常ターミナルで `bin/plangate approve`）

## exec 進捗
- [x] T1 精読（ai-dev-plan SKILL / working-context / plan-quality-check / review-self）
- [x] T2/T3 ai-dev-plan SKILL（正本 .agents + .codex + plugin 2ミラー）に rollback 規約
- [x] T4 working-context.md(HO) 追記の apply-script 生成（`scripts/apply-task-0131-rollback.sh`・**人間適用待ち**）
- [x] T5 plan-quality-check SKILL（補足2）+ review-self.md（C1-TODO-RB）に rollback 欠落検出
- [x] T6 本 todo.md は各タスク rollback: 記載済（PR #568 で確立）
- [ ] T7 検証
- [ ] T8 handoff

## HO 適用（人間）
- `sh scripts/apply-task-0131-rollback.sh` 実行 → working-context.md に rollback 規約反映（AI は直接編集不可）
