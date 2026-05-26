# TASK-0117 EXECUTION TODO

## 🤖 Agent タスク

- [ ] **T-01**: `.claude/skills/ai-dev-plan/` 構造把握 + PocketEitan PR #371 該当セクション参照 (owner=agent / Risk=low / 🚩 構造マップ)
- [ ] **T-02 (R-001/R-003)**: `.agents/skills/ai-dev-plan/SKILL.md` に「事前メトリクス検証」セクション追加 (B-1→B-2 mandatory gate 配置) (owner=agent / Risk=medium / depends_on=T-01 / 🚩 markdownlint pass + plan.md template に Metrics Evidence 欄サンプル)
- [ ] **T-03**: `docs/ai/plan-metrics-verification.md` 運用ガイド (owner=agent / Risk=low / depends_on=T-02 / 🚩 Human/AI 参照可能)
- [ ] **T-04**: `tests/extras/ta-19-plan-metrics-verification.sh` (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-19 PASS)
- [ ] **T-05**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..7 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] ~~H-02 maintenance window~~ (R-001 反映で `.agents/skills/` 配下、Hardening Override 対象外のため不要)
- [ ] **H-03**: C-4 + merge
