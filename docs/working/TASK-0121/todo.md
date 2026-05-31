# TASK-0121 EXECUTION TODO

> Source: plan.md / Mode: high-risk

## 🤖 Agent タスク

- [ ] **T-01**: `scripts/check-retro-scoring-consistency.sh` を新規作成する [Owner: agent] [depends_on: H-01] [files: `scripts/check-retro-scoring-consistency.sh`] [Risk: medium] [🚩 `sh -n` PASS]
- [ ] **T-02**: consistency script を旧状態で実行し RED を確認する [Owner: agent] [depends_on: T-01] [files: -] [Risk: medium] [🚩 旧配点検出で non-zero]
- [ ] **T-03**: `docs/ai-driven-development.md` の振り返りメトリクス表を新配点と新評価基準へ更新する [Owner: agent] [depends_on: T-02] [files: `docs/ai-driven-development.md`] [Risk: medium] [🚩 計画精度30 / 効率性10 / 成果物品質30]
- [ ] **T-04**: `plugin/plangate/agents/workflow-conductor.md` の評価スコア行を新配点へ同期する [Owner: agent] [depends_on: T-03] [files: `plugin/plangate/agents/workflow-conductor.md`] [Risk: medium] [🚩 plugin 側旧配点なし]
- [ ] **T-05**: `.codex/agents/retrospective_analyst.toml` が未変更であることを確認する [Owner: agent] [depends_on: T-04] [files: `.codex/agents/retrospective_analyst.toml`] [Risk: low] [🚩 thin pointer diff なし]
- [ ] **T-06**: human HO 更新後に consistency script を GREEN 確認する [Owner: agent] [depends_on: T-04,H-02,H-03] [files: -] [Risk: medium] [🚩 旧配点 0 / 新 5 軸 / 合計 100]
- [ ] **T-07**: human pre-push / CI 配線後、配線先から consistency script が参照されることを確認する [Owner: agent] [depends_on: H-04,H-05] [files: -] [Risk: medium] [🚩 pre-push または CI 経由の呼び出し確認]

## 👤 Human タスク

- [ ] **H-01**: C-3 APPROVED の `docs/working/TASK-0121/approvals/c3.json` を発行する [Owner: human] [depends_on: -] [files: `docs/working/TASK-0121/approvals/c3.json`] [Risk: medium] [🚩 APPROVED + plan_hash]
- [ ] **H-02**: `.claude/agents/workflow-conductor.md` を新配点へ更新する [Owner: human] [depends_on: H-01] [files: `.claude/agents/workflow-conductor.md`] [Risk: high] [🚩 HO 人間編集]
- [ ] **H-03**: `.claude/agents/retrospective-analyst.md` を新配点と Plan-primacy 根拠へ更新する [Owner: human] [depends_on: H-01] [files: `.claude/agents/retrospective-analyst.md`] [Risk: high] [🚩 HO 人間編集]
- [ ] **H-04**: consistency script を pre-push に配線する [Owner: human] [depends_on: T-01] [files: `scripts/templates/pre-push.sample` または既存 hook dispatcher] [Risk: high] [🚩 push 前に script 起動]
- [ ] **H-05**: CI 連携が必要な場合、`.github/workflows/` を人間編集で配線する [Owner: human] [depends_on: T-01] [files: `.github/workflows/*.yml` / `.github/workflows/*.yaml`] [Risk: high] [🚩 workflow で script 起動]
- [ ] **H-06**: C-4 PR レビューを行う [Owner: human] [depends_on: T-06,T-07] [files: -] [Risk: medium] [🚩 PR APPROVE / REQUEST CHANGES / REJECT]

## ⚠️ 依存関係

- Agent による非HO実装は H-01（C-3 artifact 発行）後に開始する。
- T-06 は H-02 / H-03 の HO 人間編集が完了するまで GREEN にならない。
- H-04 / H-05 は script 実体である T-01 完了後に実施する。
- `.claude/agents/` 2 件と `.github/workflows/` は agent が編集しない。
- L-0〜V-4 と PR 作成は workflow-conductor が自動制御するため、この todo には含めない。
