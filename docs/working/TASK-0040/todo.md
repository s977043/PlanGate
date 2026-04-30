# EXECUTION TODO — TASK-0040 (PBI-116-02 / Issue #118)

> [`plan.md`](./plan.md) の Work Breakdown を 2-5 分粒度に分解。
> Iron Law: `NO SCOPE CHANGE WITHOUT USER APPROVAL`

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定する [Owner: agent] [depends_on: -] [files: -]
- [ ] 🚩 T-2: interface-preflight.md を再読込し、tool_policy / validation_bias 値域を確認 [Owner: agent] [depends_on: T-1] [files: docs/working/PBI-116/interface-preflight.md]

### 実装フェーズ

#### Step 1: schema 定義
- [ ] 🚩 T-3: schemas/model-profile.schema.json skeleton 作成（JSON Schema 2020-12 準拠） [Owner: agent] [depends_on: T-2] [files: schemas/model-profile.schema.json]
- [ ] 🚩 T-4: schema フィールド 9 種を定義（family/role/reasoning_effort_by_mode/verbosity_by_phase/max_context_policy/tool_policy/validation_bias/structured_outputs/adapter） [Owner: agent] [depends_on: T-3] [files: schemas/model-profile.schema.json]
- [ ] 🚩 T-5: docs/ai/model-profiles.md skeleton 作成（schema 仕様 + 用途説明） [Owner: agent] [depends_on: T-4] [files: docs/ai/model-profiles.md]

#### Step 2: 4 プロファイル定義
- [ ] 🚩 T-6: docs/ai/model-profiles.yaml skeleton 作成（version + defaults + models セクション） [Owner: agent] [depends_on: T-5] [files: docs/ai/model-profiles.yaml]
- [ ] 🚩 T-7: gpt-5_5 プロファイル定義 [Owner: agent] [depends_on: T-6] [files: docs/ai/model-profiles.yaml]
- [ ] 🚩 T-8: gpt-5_5_pro プロファイル定義 [Owner: agent] [depends_on: T-7] [files: docs/ai/model-profiles.yaml]
- [ ] 🚩 T-9: gpt-5_mini プロファイル定義（disallowed_modes: [critical] 含む） [Owner: agent] [depends_on: T-8] [files: docs/ai/model-profiles.yaml]
- [ ] 🚩 T-10: legacy_or_unknown プロファイル定義 [Owner: agent] [depends_on: T-9] [files: docs/ai/model-profiles.yaml]

#### Step 3: マトリクス + verbosity + context budget
- [ ] 🚩 T-11: model-profiles.md に reasoning_effort × mode × profile マトリクス（5×4）追加 [Owner: agent] [depends_on: T-10] [files: docs/ai/model-profiles.md]
- [ ] 🚩 T-12: model-profiles.md に verbosity_by_phase × profile（5×4）表追加 [Owner: agent] [depends_on: T-11] [files: docs/ai/model-profiles.md]
- [ ] 🚩 T-13: model-profiles.md に context_budget_policy 3 段階定義追加 [Owner: agent] [depends_on: T-12] [files: docs/ai/model-profiles.md]
- [ ] 🚩 T-14: critical mode で gpt-5_mini disallow 方針を明記 [Owner: agent] [depends_on: T-13] [files: docs/ai/model-profiles.md]

### 検証フェーズ

- [ ] 🚩 T-15: schema-validate 実行（YAML が JSON Schema を満たすか） [Owner: agent] [depends_on: T-14] [files: -]
- [ ] 🚩 T-16: markdown lint 実行（全更新ファイル 0 error） [Owner: agent] [depends_on: T-15] [files: -]
- [ ] 🚩 T-17: interface-preflight.md との整合性確認（tool_policy / validation_bias 値域一致） [Owner: agent] [depends_on: T-16] [files: -]
- [ ] 🚩 T-18: 受入基準 8 項目の全確認 [Owner: agent] [depends_on: T-17] [files: -]
- [ ] 🚩 T-19: evidence/verification.md 記録 [Owner: agent] [depends_on: T-18] [files: docs/working/TASK-0040/evidence/verification.md]

### 完了フェーズ

- [ ] 🚩 T-20: handoff.md 作成（必須 6 要素） [Owner: agent] [depends_on: T-19] [files: docs/working/TASK-0040/handoff.md]
- [ ] 🚩 T-21: status.md 更新 [Owner: agent] [depends_on: T-20] [files: docs/working/TASK-0040/status.md]
- [ ] 🚩 T-22: コミット作成 [Owner: agent] [depends_on: T-21] [files: -]
- [ ] 🚩 T-23: push + PR 作成 [Owner: agent] [depends_on: T-22] [files: -]

## 👤 Humanタスク

- [ ] **C-3**: plan/todo/test-cases の人間レビュー（exec 前ゲート） [Owner: human]
- [ ] **C-4**: PR レビュー・承認（GitHub 上） [Owner: human]

## ⚠️ 依存関係

- 親 PBI Parent C-3: ✅ APPROVED（2026-04-30）
- Phase 1 (PBI-116-01): ✅ done（Core Contract 確立）
- 本 TASK Child C-3: ⏳ 待機中（C-2 Codex レビュー後）
- exec 完了 → L-0 → V-1 → V-2 → V-3 → 子 PR → Child C-4

## タスク粒度ルール

- 各タスク 2-5 分粒度（YAML/Markdown 編集の小単位）
- スコープ外作業禁止（Iron Law）
- Stop rule（plan.md 末尾）に該当する状況では即停止
