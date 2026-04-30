# EXECUTION TODO — TASK-0042 (PBI-116-04 / Issue #120)

## 🤖 Agentタスク

### 準備
- [ ] 🚩 T-1: Scope/受入基準を再掲、作業範囲固定 [Owner: agent] [depends_on: -]
- [ ] 🚩 T-2: 既存 schemas/*.schema.json を一覧確認、命名衝突候補洗い出し [Owner: agent] [depends_on: T-1] [files: schemas/]

### Step 1: structured-outputs.md
- [ ] 🚩 T-3: skeleton 作成（対象一覧 / 境界 / 削減対象 / 互換性 / eval 引き継ぎ） [Owner: agent] [depends_on: T-2] [files: docs/ai/structured-outputs.md]
- [ ] 🚩 T-4: 対象 6 件以上の一覧記述 [Owner: agent] [depends_on: T-3] [files: docs/ai/structured-outputs.md]
- [ ] 🚩 T-5: Markdown vs JSON 責務境界明示 [Owner: agent] [depends_on: T-4] [files: docs/ai/structured-outputs.md]

### Step 2: review-result.schema.json
- [ ] 🚩 T-6: skeleton 作成（JSON Schema 2020-12） [Owner: agent] [depends_on: T-5] [files: schemas/review-result.schema.json]
- [ ] 🚩 T-7: 主要フィールド定義（taskId / phase / decision / findings / gateRecommendation） [Owner: agent] [depends_on: T-6]
- [ ] 🚩 T-8: findings[] 内の severity / category 列挙 [Owner: agent] [depends_on: T-7]

### Step 3: acceptance-result.schema.json
- [ ] 🚩 T-9: skeleton + V-1 受入結果フィールド [Owner: agent] [depends_on: T-8] [files: schemas/acceptance-result.schema.json]

### Step 4: mode-classification.schema.json
- [ ] 🚩 T-10: skeleton + 5 mode 列挙 + 判定根拠 [Owner: agent] [depends_on: T-9] [files: schemas/mode-classification.schema.json]

### Step 5: handoff-summary.schema.json
- [ ] 🚩 T-11: skeleton + 必須 6 要素のメタ + 本文リンク [Owner: agent] [depends_on: T-10] [files: schemas/handoff-summary.schema.json]

### 検証
- [ ] 🚩 T-12: 各 schema の JSON 妥当性確認（python -m json.tool） [Owner: agent] [depends_on: T-11]
- [ ] 🚩 T-13: $schema が 2020-12 で統一されているか grep 確認 [Owner: agent] [depends_on: T-12]
- [ ] 🚩 T-14: 既存 schemas/ との命名衝突 0 件確認 [Owner: agent] [depends_on: T-13]
- [ ] 🚩 T-15: markdown lint 0 error [Owner: agent] [depends_on: T-14]
- [ ] 🚩 T-16: 受入基準 6 項目の全確認 [Owner: agent] [depends_on: T-15]
- [ ] 🚩 T-17: evidence/verification.md 記録 [Owner: agent] [depends_on: T-16] [files: docs/working/TASK-0042/evidence/verification.md]

### 完了
- [ ] 🚩 T-18: handoff.md 作成（必須 6 要素） [Owner: agent] [depends_on: T-17] [files: docs/working/TASK-0042/handoff.md]
- [ ] 🚩 T-19: status.md 更新 [Owner: agent] [depends_on: T-18]
- [ ] 🚩 T-20: コミット + push + PR 作成 [Owner: agent] [depends_on: T-19]

## 👤 Humanタスク

- [ ] **C-3** plan/todo/test-cases レビュー
- [ ] **C-4** PR レビュー

## ⚠️ 依存関係

- 親 PBI Parent C-3: ✅ APPROVED
- Phase 1: ✅ done
- 02/06: 独立（schema 設計のみ、tool_policy/validation_bias 不参照）
