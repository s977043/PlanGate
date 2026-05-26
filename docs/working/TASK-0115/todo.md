# TASK-0115 EXECUTION TODO

## 🤖 Agent タスク

- [ ] **T-01**: TASK-0112 適用パターン + responsibility-classes.md 既存セクション構造把握 (owner=agent / Risk=low / 🚩 構造把握)
- [ ] **T-02**: `.claude/rules/responsibility-classes.md` に新セクション追加 (owner=agent / Risk=medium / depends_on=T-01 / 🚩 maintenance window 経由 + markdownlint pass)
- [ ] **T-03**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=T-02 / 🚩 AC-1..5 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] **H-02**: maintenance window 発行 (`bin/plangate maintenance start --paths .claude/rules/responsibility-classes.md --minutes 5`)
- [ ] **H-03**: C-4 + merge
