# EXECUTION TODO — TASK-0043 (PBI-116-03 / Issue #119)

> [`plan.md`](./plan.md) を 2-5 分粒度。Iron Law: `NO SCOPE CHANGE WITHOUT USER APPROVAL`

## 🤖 Agentタスク

### 準備
- [ ] 🚩 T-1: Scope/受入基準再掲 [Owner: agent]
- [ ] 🚩 T-2: Phase 1 (core-contract.md) と Phase 2 (model-profiles.yaml) の確認 [files: docs/ai/]

### Step 1: prompt-assembly.md 本体
- [ ] 🚩 T-3: skeleton（4 層定義 / 責務境界 / 7 phase / 4 adapter / 解決ロジック / 不変方針）[files: docs/ai/prompt-assembly.md]
- [ ] 🚩 T-4: 4 層の責務マトリクス記述
- [ ] 🚩 T-5: 7 phase 各々の概要記述（phase_contract への導線）
- [ ] 🚩 T-6: 4 adapter 概要記述（model_adapter への導線、Phase 2 schema 整合）
- [ ] 🚩 T-7: 解決ロジック（TypeScript 型定義 + 擬似コード）
- [ ] 🚩 T-8: モデル別 prompt full fork 回避方針明記

### Step 2: phase_contract skeleton（7 phase）
- [ ] 🚩 T-9: docs/ai/contracts/classify.md（Goal / Success criteria / Stop rules、各 50 行以下）
- [ ] 🚩 T-10: docs/ai/contracts/plan.md
- [ ] 🚩 T-11: docs/ai/contracts/approve-wait.md
- [ ] 🚩 T-12: docs/ai/contracts/execute.md
- [ ] 🚩 T-13: docs/ai/contracts/review.md
- [ ] 🚩 T-14: docs/ai/contracts/verify.md
- [ ] 🚩 T-15: docs/ai/contracts/handoff.md

### Step 2 続き: model_adapter skeleton（4 adapter）
- [ ] 🚩 T-16: docs/ai/adapters/outcome_first.md（Style / Verbosity / Output discipline、各 50 行以下）
- [ ] 🚩 T-17: docs/ai/adapters/outcome_first_strict.md
- [ ] 🚩 T-18: docs/ai/adapters/explicit_short.md
- [ ] 🚩 T-19: docs/ai/adapters/legacy_or_unknown.md

### 検証
- [ ] 🚩 T-20: 自動検証（grep / wc / ls）→ AC-1〜AC-7 確認
- [ ] 🚩 T-21: Phase 1 / 2 成果物との整合性確認
- [ ] 🚩 T-22: markdown lint
- [ ] 🚩 T-23: evidence/verification.md 記録

### 完了
- [ ] 🚩 T-24: handoff.md（必須 6 要素）
- [ ] 🚩 T-25: status.md
- [ ] 🚩 T-26: コミット + push + 子 PR

## 👤 Humanタスク

- [ ] **C-3** plan/todo/test-cases レビュー
- [ ] **C-4** PR レビュー

## ⚠️ 依存関係

- 親 PBI Parent C-3: ✅ APPROVED
- Phase 1 (PBI-116-01): ✅ done
- Phase 2 (PBI-116-02): ✅ done（model-profiles.yaml が main にあること）
- 本 TASK Child C-3: ⏳ 待機中（high-risk のため C-2 Codex 必須）
