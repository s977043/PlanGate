# TASK-0025 EXECUTION TODO

> 生成日: 2026-04-20

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準再掲 [Owner: agent]
  - files: [docs/working/TASK-0025/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: 既存 18 agents の責務調査、5 新規との対応マッピング作成 [Owner: agent]
  - files: [docs/working/TASK-0025/evidence/existing-agents-inventory.md]
  - depends_on: [T-1]
- [ ] 🚩 T-3: Agent 共通テンプレート策定 [Owner: agent]
  - files: [docs/working/TASK-0025/evidence/agent-template.md]
  - depends_on: [T-2]

### 実装フェーズ（C-3 Gate APPROVE 後）

> ⚠️ T-4 は C-3 承認必須。

- [ ] 🚩 T-4: `orchestrator.md` 作成 [Owner: agent]
  - files: [.claude/agents/orchestrator.md]
  - depends_on: [T-3, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-5: `requirements-analyst.md` 作成（T-4 と並列可、T-3 のみ依存） [Owner: agent]
  - files: [.claude/agents/requirements-analyst.md]
  - depends_on: [T-3, C-3]
- [ ] 🚩 T-6: `solution-architect.md` 作成（並列可） [Owner: agent]
  - files: [.claude/agents/solution-architect.md]
  - depends_on: [T-3, C-3]
- [ ] 🚩 T-7: `implementation-agent.md` 作成（並列可） [Owner: agent]
  - files: [.claude/agents/implementation-agent.md]
  - depends_on: [T-3, C-3]
- [ ] 🚩 T-8: `qa-reviewer.md` 作成（並列可） [Owner: agent]
  - files: [.claude/agents/qa-reviewer.md]
  - depends_on: [T-3, C-3]
- [ ] 🚩 T-9: `docs/workflows/execution-sequence.md` 作成 [Owner: agent]
  - files: [docs/workflows/execution-sequence.md]
  - depends_on: [T-5, T-6, T-7, T-8]

### セルフレビュー①

- [ ] 🚩 T-10: `/self-review` 実行、Rule 3 遵守確認 [Owner: agent]
  - depends_on: [T-9]

### 検証フェーズ

- [ ] 🚩 T-11: 5 新規 Agent ファイル存在確認 [Owner: agent]
  - depends_on: [T-10]
- [ ] 🚩 T-12: Rule 3 遵守チェック（ツール固有/案件固有なし） [Owner: agent]
  - files: [docs/working/TASK-0025/evidence/rule3-check.md]
  - depends_on: [T-11]
- [ ] 🚩 T-13: 実行シーケンスが 5 agent 全てをカバーしていることを確認 [Owner: agent]
  - depends_on: [T-12]
- [ ] 🚩 T-14: 受入基準 5 項目の全確認 [Owner: agent]
  - depends_on: [T-13]

### セルフレビュー②

- [ ] 🚩 T-15: `/self-review` 再実行 [Owner: agent]
  - depends_on: [T-14]

### 完了フェーズ

- [ ] 🚩 T-16: コミット、status.md 更新 [Owner: agent]
  - files: [docs/working/TASK-0025/status.md]
  - depends_on: [T-15]

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases レビュー
- [ ] C-4: PR レビュー・承認

## ⚠️ 依存関係

- **前提 TASK**: #23 完了、**#24 完了**（Skill 名凍結のため）
- T-1 → T-2 → T-3（準備）
- T-4〜T-8 並列可能（全て T-3 + C-3 依存）
- T-9 は T-4〜T-8 全完成後
