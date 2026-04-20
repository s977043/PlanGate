# TASK-0026 EXECUTION TODO

> 生成日: 2026-04-20

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準再掲 [Owner: agent]
  - files: [docs/working/TASK-0026/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: #23 の 03_solution_design.md を読み、深化ポイントを洗い出し [Owner: agent]
  - files: [docs/working/TASK-0026/evidence/wf03-enhancement-points.md]
  - depends_on: [T-1]

### 実装フェーズ（C-3 Gate APPROVE 後）

- [ ] 🚩 T-3: `docs/working/templates/design.md` テンプレート作成 [Owner: agent]
  - files: [docs/working/templates/design.md]
  - depends_on: [T-2, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-4: `03_solution_design.md` 深化更新 [Owner: agent]
  - files: [docs/workflows/03_solution_design.md]
  - depends_on: [T-3]
- [ ] 🚩 T-5: #25 solution-architect との整合確認 [Owner: agent]
  - files: []
  - depends_on: [T-4]
- [ ] 🚩 T-6: PlanGate フロー図（挿入位置）作成 [Owner: agent]
  - files: [docs/workflows/plangate-insertion-map.md]
  - depends_on: [T-5]
- [ ] 🚩 T-7: サンプル design.md 作成 [Owner: agent]
  - files: [docs/working/TASK-0026/evidence/sample-design.md]
  - depends_on: [T-6]

### セルフレビュー

- [ ] 🚩 T-8: `/self-review` 実行 [Owner: agent]
  - depends_on: [T-7]

### 検証フェーズ

- [ ] 🚩 T-9: 全 7 要素がテンプレに存在 [Owner: agent]
  - depends_on: [T-8]
- [ ] 🚩 T-10: サンプルが全要素を埋めている [Owner: agent]
  - depends_on: [T-9]
- [ ] 🚩 T-11: 受入基準 6 項目確認 [Owner: agent]
  - depends_on: [T-10]

### 完了

- [ ] 🚩 T-12: コミット、status.md 更新 [Owner: agent]
  - files: [docs/working/TASK-0026/status.md]
  - depends_on: [T-11]

## 👤 Humanタスク

- [ ] C-3: plan レビュー
- [ ] C-4: PR 承認

## ⚠️ 依存関係

- **前提**: #23 / #24 / #25 完了
- T-1 → T-2 → T-3 → T-4 → T-5 → T-6 → T-7（実装）
