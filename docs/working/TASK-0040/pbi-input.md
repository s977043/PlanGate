# PBI INPUT PACKAGE — TASK-0040 (PBI-116-02 / Issue #118)

> **Status**: C-1 完了 / C-2 Codex 待ち / Child C-3 ゲート待ち
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Codex 戦略採用順序の **1 番目**
> Issue: [#118 Model Profile layer 追加（実行モデル別 reasoning / verbosity / context policy）](https://github.com/s977043/plangate/issues/118)
> Mode: standard
> Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)

## Context / Why

PlanGate の Core Contract（[`docs/ai/core-contract.md`](../../ai/core-contract.md)、Phase 1 成果）と Gate 条件はモデル非依存であるべきだが、実行モデルごとに最適な runtime parameter は異なる。

特に、GPT-5.5 / GPT-5.5 Pro / Mini / legacy model では、reasoning effort、verbosity、context budget、tool policy、validation depth の適切な初期値が変わる。これをプロンプト全文の分岐で吸収すると、保守負荷が高くなり、Gate 条件のズレやルール更新漏れが起きやすい。

本 PBI では、モデル差分を `model-profiles.yaml` のような薄い設定層に閉じ込め、PlanGate Core を共通に保ったまま、実行モデルに応じた安全な制御を可能にする。

## What

### In scope

1. **Model Profile schema の定義**

   設定項目:
   - `family`: gpt-5 / gpt-5-pro / gpt-5-mini / legacy
   - `role`: default_reasoning / advanced_reasoning / fast_lightweight / unknown
   - `reasoning_effort_by_mode`: ultra_light / light / standard / high_risk / critical 各モードでの effort 値
   - `verbosity_by_phase`: classify / plan / execute / review / handoff 各 phase での verbosity 値
   - `max_context_policy`: compact / standard / expanded
   - **`tool_policy`**: `narrow` / `allowed_tools_by_phase` / `expanded`（interface-preflight 合意）
   - **`validation_bias`**: `lenient` / `normal` / `strict`（interface-preflight 合意）
   - `structured_outputs`: bool
   - `adapter`: outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown

2. **4 プロファイル定義**
   - `gpt-5_5`: 標準実行モデル
   - `gpt-5_5_pro`: 強力推論モデル
   - `gpt-5_mini`: 高速軽量モデル
   - `legacy_or_unknown`: フォールバック

3. **PlanGate 5 mode と reasoning effort のマッピング**

   | PlanGate mode | gpt-5_5 | gpt-5_5_pro | gpt-5_mini | legacy_or_unknown |
   |---|---|---|---|---|
   | ultra-light | low | low | low | low |
   | light | low | low/medium | low | low |
   | standard | medium | medium/high | low/medium | medium |
   | high-risk | high | high | medium 推奨外 | high |
   | critical | high | high/xhigh | disallow | high |

4. **phase 別 verbosity の定義**

   - classify: low / plan: medium / execute: low / review: medium-high / handoff: medium

5. **context budget policy の定義**

   - compact / standard / expanded（用途・コスト・品質のトレードオフ）

### Out of scope

- モデル別プロンプト全文の fork（→ PBI-116-03 Prompt Assembly で対応）
- provider 実行ランタイムの大規模改修
- eval runner の実装（→ PBI-116-05 Eval Cases で対応）
- Structured Outputs schema の実装詳細（→ PBI-116-04 で対応）
- Tool Policy の実 tool 列挙（→ PBI-116-06 で対応、本 PBI は値域定義のみ）

## 受入基準

- [ ] AC-1: `model-profiles.yaml` または同等のドキュメント（`docs/ai/model-profiles.yaml` + `docs/ai/model-profiles.md`）が追加されている
- [ ] AC-2: GPT-5.5 / Pro / Mini / legacy_or_unknown のプロファイルが定義されている（4 件すべて）
- [ ] AC-3: reasoning effort が PlanGate mode 別に定義されている（5 mode × 4 profile マトリクス）
- [ ] AC-4: verbosity が phase 別に定義されている（5 phase × 4 profile）
- [ ] AC-5: context budget policy が compact / standard / expanded 等で定義されている
- [ ] AC-6: critical mode で小型/高速モデル (gpt-5_mini) を disallow できる方針がある
- [ ] AC-7: Core Contract / Gate / Artifact schema はモデル別に変えないことが明記されている
- [ ] AC-8: `tool_policy` / `validation_bias` 値域が interface-preflight.md と整合している（PBI-116-06 と接続可能）

## Notes from Refinement

- **Phase 2 戦略**: Codex 相談で確定（PR #136 / interface-preflight.md）
- **着手順序**: 本 TASK が Phase 2 の最初（PBI-116-06 の前提となる schema 確立）
- **接続合意**: 02 (本 TASK) が `tool_policy` / `validation_bias` の値域を定義、06 がそれを参照して実 tool 列挙

## Estimation Evidence

### Risks

| ID | Risk | Severity | Mitigation |
|----|------|---------|----------|
| L1 | tool_policy / validation_bias の値域が PBI-116-06 と乖離 | medium | interface-preflight.md 準拠（既に合意済）、plan.md で値域を明示転記 |
| L2 | reasoning effort × mode マトリクスの値が実モデル挙動と乖離 | medium | 設計段階で確定、検証は PBI-116-05 (Eval Cases) で実施 |
| L3 | schema YAML が既存 `schemas/` と命名衝突 | low | `docs/ai/model-profiles.yaml` 配置、`schemas/model-profile.schema.json` で別配置 |
| L4 | プロファイル定義が大きくなり保守負荷増 | low | 4 プロファイルに限定、追加は別 PBI |

### Unknowns

- Q1: `model-profiles.yaml` を YAML / JSON Schema どちらで本体定義するか？
  - A1: YAML（人間可読性優先）+ JSON Schema を `schemas/model-profile.schema.json` に併設
- Q2: `gpt-5_5_pro` の `reasoning_effort` で `xhigh` を採用するか？
  - A2: critical mode で `high/xhigh` 候補表現で柔軟性を持たせる
- Q3: `gpt-5_mini` を critical mode で `disallow` する強制方法は？
  - A3: profile レベルで `disallowed_modes: [critical]` を許容、解決は PBI-116-03 Prompt Assembly で

### Assumptions

- Phase 1 成果（Core Contract）がモデル非依存であることを前提
- interface-preflight.md の合意が PBI-116-06 でも維持される
- 本 PBI は doc-only（実装は YAML / Markdown のみ、コード変更なし）
- Plugin 配布版との同期は本 PBI scope 外（V2 候補）

## Parent PBI との関係

| 親 AC | 本 PBI でのカバー |
|------|-----------------|
| parent-AC-2 | Model Profile として設定化（直接対応） |

## 関連リンク

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- 子 PBI YAML: [`docs/working/PBI-116/children/PBI-116-02.yaml`](../PBI-116/children/PBI-116-02.yaml)
- Issue: https://github.com/s977043/plangate/issues/118
- Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)
- Codex Phase 2 戦略: [`docs/working/PBI-116/_codex-phase2-consult-result.md`](../PBI-116/_codex-phase2-consult-result.md)
- Phase 1 成果（基盤）: [`docs/ai/core-contract.md`](../../ai/core-contract.md)
