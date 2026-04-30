# EXECUTION TODO — TASK-0041 (PBI-116-06 / Issue #122)

> [`plan.md`](./plan.md) を 2-5 分粒度で分解。Iron Law: `NO SCOPE CHANGE WITHOUT USER APPROVAL`

## 🤖 Agentタスク

### 準備
- [ ] 🚩 T-1: Scope/受入基準を再掲、作業範囲固定 [Owner: agent] [depends_on: -] [files: -]
- [ ] 🚩 T-2: interface-preflight.md と PBI-116-02 model-profiles.yaml（マージ済の場合）を参照確認 [Owner: agent] [depends_on: T-1] [files: docs/working/PBI-116/interface-preflight.md]

### Step 1: responsibility-boundary.md
- [ ] 🚩 T-3: skeleton 作成（4 layer × 責務テーブル） [Owner: agent] [depends_on: T-2] [files: docs/ai/responsibility-boundary.md]
- [ ] 🚩 T-4: モデル判断 vs runtime 強制の境界基準を明示 [Owner: agent] [depends_on: T-3] [files: docs/ai/responsibility-boundary.md]

### Step 2: tool-policy.md
- [ ] 🚩 T-5: skeleton 作成（5 phase × allowed tools） [Owner: agent] [depends_on: T-4] [files: docs/ai/tool-policy.md]
- [ ] 🚩 T-6: tool_policy 値（narrow/allowed_tools_by_phase/expanded）ごとの射影定義 [Owner: agent] [depends_on: T-5] [files: docs/ai/tool-policy.md]
- [ ] 🚩 T-7: PBI-116-02 Model Profile schema との整合確認 [Owner: agent] [depends_on: T-6] [files: -]

### Step 3: hook-enforcement.md
- [ ] 🚩 T-8: skeleton 作成（不変条件カテゴリ） [Owner: agent] [depends_on: T-7] [files: docs/ai/hook-enforcement.md]
- [ ] 🚩 T-9: 不変条件 6 件以上を一覧化（plan なし禁止 / C-3 承認なし禁止 / plan_hash 改竄 / test-cases なし V-1 / 検証ログなし PR / scope 外検知） [Owner: agent] [depends_on: T-8] [files: docs/ai/hook-enforcement.md]
- [ ] 🚩 T-10: validation_bias: strict 時の追加条件 3 件以上を定義 [Owner: agent] [depends_on: T-9] [files: docs/ai/hook-enforcement.md]
- [ ] 🚩 T-11: 既存 `.claude/settings.json` hooks との関係を明示 [Owner: agent] [depends_on: T-10] [files: docs/ai/hook-enforcement.md]

### 検証
- [ ] 🚩 T-12: markdown lint 0 error 確認 [Owner: agent] [depends_on: T-11] [files: -]
- [ ] 🚩 T-13: interface-preflight.md との tool_policy / validation_bias 整合確認 [Owner: agent] [depends_on: T-12] [files: -]
- [ ] 🚩 T-14: 受入基準 7 項目の全確認 [Owner: agent] [depends_on: T-13] [files: -]
- [ ] 🚩 T-15: evidence/verification.md 記録 [Owner: agent] [depends_on: T-14] [files: docs/working/TASK-0041/evidence/verification.md]

### 完了
- [ ] 🚩 T-16: handoff.md 作成（必須 6 要素） [Owner: agent] [depends_on: T-15] [files: docs/working/TASK-0041/handoff.md]
- [ ] 🚩 T-17: status.md 更新 [Owner: agent] [depends_on: T-16] [files: docs/working/TASK-0041/status.md]
- [ ] 🚩 T-18: コミット + push + PR 作成 [Owner: agent] [depends_on: T-17] [files: -]

## 👤 Humanタスク

- [ ] **C-3**: plan/todo/test-cases の人間レビュー [Owner: human]
- [ ] **C-4**: PR レビュー [Owner: human]

## ⚠️ 依存関係

- 親 PBI Parent C-3: ✅ APPROVED
- Phase 1 (PBI-116-01): ✅ done
- PBI-116-02 (#118): plan 完了（PR #137 / cb3f644 マージ済）、exec は本 PBI と並行可能だが、本 PBI 着手時に Model Profile schema が確定していると整合確認が容易
- 本 TASK Child C-3: ⏳ 待機中
