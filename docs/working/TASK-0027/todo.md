# TASK-0027 EXECUTION TODO

> 生成日: 2026-04-20

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準再掲 [Owner: agent]
  - files: [docs/working/TASK-0027/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: #23 の 05_verify_and_handoff.md 読み、深化ポイント洗い出し [Owner: agent]
  - files: [docs/working/TASK-0027/evidence/wf05-enhancement-points.md]
  - depends_on: [T-1]

### 実装フェーズ（C-3 APPROVE 後）

- [ ] 🚩 T-3: `docs/working/templates/handoff.md` テンプレ作成（6 要素） [Owner: agent]
  - files: [docs/working/templates/handoff.md]
  - depends_on: [T-2, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-4: `05_verify_and_handoff.md` 深化 [Owner: agent]
  - files: [docs/workflows/05_verify_and_handoff.md]
  - depends_on: [T-3]
- [ ] 🚩 T-5: `.claude/rules/working-context.md` に handoff 節追加 [Owner: agent]
  - files: [.claude/rules/working-context.md]
  - depends_on: [T-4]
- [ ] 🚩 T-6: サンプル handoff.md 作成（TASK-0017 題材） [Owner: agent]
  - files: [docs/working/TASK-0027/evidence/sample-handoff.md]
  - depends_on: [T-5]

### セルフレビュー

- [ ] 🚩 T-7: `/self-review` 実行 [Owner: agent]
  - depends_on: [T-6]

### 検証

- [ ] 🚩 T-8: handoff.md テンプレに 6 要素が存在 [Owner: agent]
  - depends_on: [T-7]
- [ ] 🚩 T-9: `.claude/rules/working-context.md` に handoff 節が追加、既存構造破壊なし [Owner: agent]
  - depends_on: [T-8]
- [ ] 🚩 T-10: サンプルが 6 要素全て埋める [Owner: agent]
  - depends_on: [T-9]
- [ ] 🚩 T-11: 受入基準 6 項目確認 [Owner: agent]
  - depends_on: [T-10]

### 完了

- [ ] 🚩 T-12: コミット、status.md 更新 [Owner: agent]
  - files: [docs/working/TASK-0027/status.md]
  - depends_on: [T-11]

## 👤 Humanタスク

- [ ] 🚩 C-3: Plan/ToDo/Test Cases 人間レビュー（exec 前ゲート）[Owner: human]
  - 確認観点: Rule 1 遵守、phase 共通契約維持、6 要素カバー、handoff 命名規約、Skill 連携
  - ゲート条件: APPROVE / CONDITIONAL / REJECT の三値判断 → status.md に記録
- [ ] 🚩 C-4: PR レビュー・承認（GitHub 上）[Owner: human]
  - 確認観点: 05_verify_and_handoff.md 深化内容、handoff.md テンプレ、rules 節追加、サンプル
  - ゲート条件: APPROVE → マージ / REQUEST CHANGES → 修正

## ⚠️ 依存関係

- **前提**: #23 / #24 / #25 完了
- 実装フェーズ直列
