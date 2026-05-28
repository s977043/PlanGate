# TASK-0118 EXECUTION TODO

## 🤖 Agent タスク

- [ ] **T-01**: 既存 `.claude/commands/` / `.agents/skills/ai-dev-plan/` 構造 + PocketEitan PR #371 参照 (owner=agent / Risk=low / 🚩 既存 pattern マップ)
- [ ] **T-02 (HO)**: `.claude/commands/codex-mvp-split.md` 新規 (slash command + 質問テンプレ) (owner=agent / Risk=medium / depends_on=T-01 / 🚩 動作確認)
- [ ] **T-03**: `.agents/skills/codex-mvp-split/SKILL.md` 新規 (薄い skill、入出力規約のみ) (owner=agent / Risk=low / depends_on=T-01 / 🚩 ai-dev-plan と同 pattern)
- [ ] **T-04**: `docs/ai/codex-mvp-split.md` 運用ガイド (PocketEitan 実例 2 件 + TASK-0117 連携) (owner=agent / Risk=low / depends_on=T-02/T-03 / 🚩 Human/AI 参照可能)
- [ ] **T-05**: `docs/working/templates/pbi-input.md` に Phase 分割表 section 追加 (owner=agent / Risk=low / depends_on=T-04 / 🚩 既存 template 整合)
- [ ] **T-06**: `tests/extras/ta-21-codex-mvp-split.sh` 機械検証 (owner=agent / Risk=low / depends_on=T-02/T-03/T-04 / 🚩 ta-21 全 PASS)
- [ ] **T-07**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..8 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] **H-02**: C-4 + merge
