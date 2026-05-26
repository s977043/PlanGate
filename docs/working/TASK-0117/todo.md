# TASK-0117 EXECUTION TODO

## 🤖 Agent タスク

- [ ] **T-01**: `.claude/skills/ai-dev-plan/` 構造把握 + PocketEitan PR #371 該当セクション参照 (owner=agent / Risk=low / 🚩 構造マップ)
- [ ] **T-02**: ai-dev-plan skill に「事前メトリクス検証」セクション追加 (owner=agent / Risk=medium / depends_on=T-01 / 🚩 maintenance window 経由 + markdownlint)
- [ ] **T-03**: `docs/ai/plan-metrics-verification.md` 運用ガイド (owner=agent / Risk=low / depends_on=T-02 / 🚩 Human/AI 参照可能)
- [ ] **T-04**: `tests/extras/ta-19-plan-metrics-verification.sh` (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-19 PASS)
- [ ] **T-05**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..7 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] **H-02**: maintenance window 発行 (`scripts/check-tag-main-parity.sh` 参考の手順、`.claude/skills/ai-dev-plan/` を含む paths)
- [ ] **H-03**: C-4 + merge
