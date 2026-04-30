# PlanGate Model Profiles — 仕様 + マトリクス

> **Status**: v1（PBI-116-02 で初版確立、Phase 2 / PBI-116）
> 本体定義: [`docs/ai/model-profiles.yaml`](./model-profiles.yaml)
> Schema: [`schemas/model-profile.schema.json`](../../schemas/model-profile.schema.json)
> Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../working/PBI-116/interface-preflight.md)
> 関連: [`docs/ai/core-contract.md`](./core-contract.md)（Phase 1 / 実行契約の正本）

## 1. 目的

実行モデルごとの差分（reasoning effort / verbosity / context budget / tool policy / validation depth / adapter）を **薄い設定層に閉じ込める**。**PlanGate Core / Gate / Artifact schema はモデル非依存で維持** し、モデル変更時の影響を本ファイルと参照層に限定する。

## 2. 不変ポリシー（モデル別に変更しない）

以下は **すべてのプロファイルで共通**。Model Profile では変更しない:

- **Core Contract**（[`core-contract.md`](./core-contract.md) Hard constraints / Iron Law 7 項目 / Stop rules / Output discipline）
- **Gate 条件**（C-3 / C-4 / Parent C-3 / Parent Integration）
- **Artifact schema**（plan / handoff / status / approvals 等）
- **AI 運用 4 原則**（[`project-rules.md`](./project-rules.md) F セクション）

## 3. プロファイル一覧（4 件）

| プロファイル | family | role | adapter |
|------------|--------|------|---------|
| `gpt-5_5` | gpt-5 | default_reasoning | outcome_first |
| `gpt-5_5_pro` | gpt-5-pro | advanced_reasoning | outcome_first_strict |
| `gpt-5_mini` | gpt-5-mini | fast_lightweight | explicit_short |
| `legacy_or_unknown` | legacy | unknown | legacy_or_unknown |

## 4. reasoning_effort × mode × profile マトリクス

PlanGate 5 mode 別の推奨 reasoning effort:

| PlanGate mode | gpt-5_5 | gpt-5_5_pro | gpt-5_mini | legacy_or_unknown |
|---|---|---|---|---|
| ultra-light | low | low | low | low |
| light | low | medium | low | low |
| standard | medium | high | low | medium |
| high-risk | high | high | medium | high |
| critical | high | high (xhigh 可) | **disallowed** | high |

### 補足

- `gpt-5_5_pro` の critical で `xhigh` を選択する場合、`allowed_efforts: [low, medium, high, xhigh]` により構造的に許容
- `gpt-5_mini` は `disallowed_modes: [critical]` で **critical mode を実効的に禁止**（高リスクタスクを軽量モデルで実行しない）

## 5. verbosity_by_phase × profile

phase 別の出力 verbosity（low / medium / high）:

| Phase | gpt-5_5 | gpt-5_5_pro | gpt-5_mini | legacy_or_unknown |
|---|---|---|---|---|
| classify | low | low | low | low |
| plan | medium | medium | low | medium |
| execute | low | low | low | medium |
| review | medium | high | low | medium |
| handoff | medium | medium | low | medium |

## 6. context_budget_policy

3 段階。`max_context_policy` フィールドで指定:

| 値 | 用途 | コスト | プロファイル例 |
|----|------|------|--------|
| `compact` | トークン節約優先、軽量タスク | 低 | gpt-5_mini |
| `standard` | 標準、汎用 | 中 | gpt-5_5 / legacy_or_unknown |
| `expanded` | 長文・大規模コンテキスト | 高 | gpt-5_5_pro |

## 7. tool_policy（PBI-116-06 接続）

interface-preflight.md で合意した値域:

| 値 | 意味 | 射影先 |
|----|------|--------|
| `narrow` | 限定 tool セット | PBI-116-06 `docs/ai/tool-policy.md` で定義 |
| `allowed_tools_by_phase` | phase 別 allowed tools リスト | 同上 |
| `expanded` | 広範 tool セット | 同上 |

## 8. validation_bias（PBI-116-06 接続）

| 値 | 意味 | 追加 Hook 条件 |
|----|------|--------------|
| `lenient` | 軽い検証 | なし |
| `normal` | 標準検証 | なし |
| `strict` | 厳格検証 | PBI-116-06 `docs/ai/hook-enforcement.md` で定義（最低 3 件） |

## 9. critical mode 禁止の運用

`gpt-5_mini` は `disallowed_modes: [critical]` を持つ。これにより:

- critical mode タスクで `gpt-5_mini` プロファイルを選択した場合、**実行前に block** すべき
- block の実装は本 PBI scope 外（runtime / Hook で実装、PBI-116-06 / 別 PBI で対応）
- 本 schema は **判定根拠** を提供する

## 10. プロファイル拡張・追加方針

- 新規モデルのプロファイル追加は **別 PBI** で実施
- 本 PBI では **4 プロファイルに限定**
- 既存プロファイルの値変更は eval (PBI-116-05) の結果に基づく

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- TASK: [`docs/working/TASK-0040/`](../working/TASK-0040/)
- Phase 1 成果: [`core-contract.md`](./core-contract.md)
- Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../working/PBI-116/interface-preflight.md)
- 接続先（次フェーズ）:
  - PBI-116-06 (Tool Policy): `tool_policy` / `validation_bias` の射影
  - PBI-116-03 (Prompt Assembly): `adapter` の利用
  - PBI-116-05 (Eval Cases): プロファイル比較・回帰検証
