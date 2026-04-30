# PBI INPUT PACKAGE — TASK-0043 (PBI-116-03 / Issue #119)

> Status: C-1 完了 / C-2 Codex 待ち / Child C-3 待ち
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / **Phase 3**（Phase 2 全完了後）
> Issue: [#119 Prompt assembly を Core / Phase / Risk / Model Adapter に分層化](https://github.com/s977043/plangate/issues/119)
> Mode: **high-risk**
> Depends on: PBI-116-01 ✅ + PBI-116-02 ✅（両方 done）

## Context / Why

最新モデル対応で、モデル別にプロンプト全文を複製すると保守負荷が急増する。PlanGate の不変制約（Iron Law）、phase ごとの成功条件、risk mode ごとの検証深度、実行モデルごとの補正は、それぞれ **変更頻度と責務が異なる**。

本 PBI では、**プロンプトを 4 層で組み立てる設計** にし、Core Contract（Phase 1）を共通化しつつ、Model Profile（Phase 2）の差分は薄い adapter に閉じ込める。

## What

### In scope

1. **Prompt assembly 4 層の定義**

   ```text
   base_contract        ← Phase 1 / docs/ai/core-contract.md
   + phase_contract     ← classify / plan / approve-wait / execute / review / verify / handoff
   + risk_mode_contract ← ultra_light / light / standard / high_risk / critical
                          （schema 識別子。人間可読 docs は ultra-light / high-risk のハイフン表記を維持）
   + model_adapter      ← Phase 2 / Model Profile の adapter
   = 実プロンプト
   ```

2. **各層の責務定義**（`docs/ai/prompt-assembly.md`）

   | Layer | 役割 |
   |---|---|
   | base_contract | PlanGate 全体の不変ルール（Iron Law / scope discipline / verification honesty）|
   | phase_contract | phase 別の成功条件・停止条件・出力 |
   | risk_mode_contract | mode 別の検証深度と Gate 要件 |
   | model_adapter | モデルごとの最小限の補正、verbosity、reasoning 方針 |

3. **Phase contract の定義**（最低 7 phase）

   - classify / plan / approve-wait / execute / review / verify / handoff

4. **Model adapter の定義**（最低 4 種、Phase 2 との整合）

   - `outcome_first` / `outcome_first_strict` / `explicit_short` / `legacy_or_unknown`

5. **解決ロジック / 擬似コード**（Markdown / TypeScript / shell いずれか）

   ```ts
   type PlanGatePromptContext = {
     baseContract: string;          // core-contract.md
     phaseContract: string;          // phase 別
     riskModeContract: string;       // mode 別
     modelAdapter: string;           // model_profile.adapter から解決
     taskContext: string;            // TASK 固有
   };
   ```

6. **CLI / 擬似実装**（任意）: `bin/plangate-prompt-assemble` skeleton（doc-only でも可）

### Out of scope

- 各モデル別の完全 prompt fork
- Provider runtime の全面刷新
- eval runner の実装（→ PBI-116-05）
- 実 AI API 呼び出し統合（schema は PBI-116-04 で完成、本 PBI は組み立てロジックのみ）
- Hook 実装（→ PBI-116-06 / 別 PBI）

## 受入基準

- [ ] AC-1: prompt assembly が Core / Phase / Risk / Model Adapter の **4 層** として定義されている
- [ ] AC-2: 各層の責務境界がドキュメント化されている
- [ ] AC-3: plan / exec / review / handoff の **phase contract** が定義されている（最低 7 phase）
- [ ] AC-4: outcome_first / explicit_short / legacy_or_unknown の **model adapter** が定義されている（最低 4 種）
- [ ] AC-5: モデル別 prompt full fork を避ける方針が明記されている
- [ ] AC-6: 既存の `.claude/` と plugin の両方に適用できる構造になっている
- [ ] AC-7: 解決ロジックが擬似コード or 実装で示されている

## Notes from Refinement

- **Phase 3 単独実行**: 並行 PBI なし
- **依存**: PBI-116-01 (Core Contract) + PBI-116-02 (Model Profile) が既に main にマージ済
- **接続**: Phase 4 (PBI-116-05 Eval) の主要前提となる

## Estimation Evidence

### Risks

| ID | Risk | Severity | Mitigation |
|----|------|---------|----------|
| L1 | 4 層化が複雑すぎて保守困難になる | high | 各層を 100 行以下、責務境界を明確に |
| L2 | base_contract と phase_contract の境界が曖昧（重複） | medium | core-contract.md は不変、phase_contract は phase 固有のみ |
| L3 | model_adapter が Phase 2 model-profiles.yaml と乖離 | medium | adapter enum を model-profile.schema.json と一致させる |
| L4 | 実装が doc-only に収まらず CLI 実装に踏み込む | medium | plan.md で「擬似コード or skeleton のみ、本格実装は別 PBI」明記 |
| L5 | Plugin 配布版（plugin/plangate/commands/）への適用が後回しになる | low | docs/ai/* が一般化された定義、Plugin 同期は別 PBI |

### Unknowns

- Q1: 解決ロジックは TypeScript 例 / shell / 純 Markdown のどれを採用？
  - A1: Markdown（型定義例 + 擬似コード）。実装言語選択は別 PBI で。
- Q2: phase_contract の数（7 phase で十分？）
  - A2: 7 phase（classify / plan / approve-wait / execute / review / verify / handoff）。必要に応じて拡張可。
- Q3: model_adapter は Phase 2 schema と完全一致が必須？
  - A3: 必須（schema の `adapter` enum と整合）。

### Assumptions

- Phase 1 / Phase 2 成果物が main にマージ済み（前提条件達成）
- doc-only PBI（実装は擬似コード or skeleton まで）
- 既存 `.claude/commands/ai-dev-workflow.md` 等は本 PBI scope 外（参照のみ、変更しない）

## Parent PBI との関係

| 親 AC | カバー |
|------|--------|
| parent-AC-3 | 4 層構造で Prompt assembly を整理 |

## 関連リンク

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- 子 PBI YAML: [`docs/working/PBI-116/children/PBI-116-03.yaml`](../PBI-116/children/PBI-116-03.yaml)
- Issue: https://github.com/s977043/plangate/issues/119
- 依存元 PBI-116-01: [`docs/ai/core-contract.md`](../../ai/core-contract.md)
- 依存元 PBI-116-02: [`docs/ai/model-profiles.yaml`](../../ai/model-profiles.yaml) / [`docs/ai/model-profiles.md`](../../ai/model-profiles.md)
- 接続先 PBI-116-04: [`docs/ai/structured-outputs.md`](../../ai/structured-outputs.md)（独立だが補完関係）
- 接続先 PBI-116-06: [`docs/ai/responsibility-boundary.md`](../../ai/responsibility-boundary.md)（4 layer 責務の上位概念）
