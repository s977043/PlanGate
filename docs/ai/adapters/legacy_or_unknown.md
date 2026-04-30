# Model Adapter: legacy_or_unknown

> [`prompt-assembly.md`](../prompt-assembly.md) の model_adapter / 4 種の 1 つ
> 想定モデル: **legacy_or_unknown**（フォールバック、[`model-profiles.yaml`](../model-profiles.yaml) `legacy_or_unknown`）

## Style

- **安全側に倒す**:
  - outcome の表現は明示的に（推論能力が低いモデル想定）
  - Iron Law / Hard constraints はプロンプト本文に再掲（base_contract 参照だけで効かない可能性に備え）
  - tool_policy は標準（`allowed_tools_by_phase`）
- 未知モデル / レガシーモデル / プロファイル未設定時のフォールバック

## Verbosity

| Phase | verbosity |
|-------|----------|
| classify | low |
| plan | medium |
| execute | medium |
| review | medium |
| handoff | medium |
| approve-wait | （不適用） |
| verify | medium（review 継承）|

→ `gpt-5_5` よりやや冗長（モデル理解力に余裕を持たせる）

## Output discipline

- schema 準拠は維持するが、JSON 出力で多少のずれを許容（`additionalProperties: true` 寄り、ただし機械検証は別 phase で）
- Markdown 成果物の必須要素は省略しない

## Reasoning

- `reasoning_effort_by_mode`: `gpt-5_5` と同等（low/low/medium/high/high）
- xhigh は使わない

## フォールバック条件

以下の場合、本 adapter が選択される:

1. `model-profiles.yaml` に該当 profile が見つからない
2. `family: legacy` 指定
3. profile.adapter が未指定

## 関連

- [`model-profiles.yaml`](../model-profiles.yaml) `models.legacy_or_unknown`
- 安全動作優先のため [`hook-enforcement.md`](../hook-enforcement.md) の不変条件強制が特に重要
