# Model Adapter: outcome_first_strict

> [`prompt-assembly.md`](../prompt-assembly.md) の model_adapter / 4 種の 1 つ
> 想定モデル: **gpt-5_5_pro**（強力推論モデル、[`model-profiles.yaml`](../model-profiles.yaml) `gpt-5_5_pro`）

## Style

- `outcome_first` の派生で **検証厳格化**:
  - 各 Stop rule の検証ログ強制
  - C-2 / V-3 必須化
  - 検証 evidence 不足時は明示的に「未検証」と記録
- 高度な推論を要する high-risk / critical 向け

## Verbosity

| Phase | verbosity |
|-------|----------|
| classify | low |
| plan | medium |
| execute | low |
| review | **high**（詳細レビュー）|
| handoff | medium |
| approve-wait | （不適用） |
| verify | high（review 継承）|

## Output discipline

- `outcome_first` と同等 + 検証 evidence の詳細記録
- review / verify 段階で findings の category / severity を明示
- [`schemas/review-result.schema.json`](../../../schemas/review-result.schema.json) 準拠厳格

## Reasoning

- `reasoning_effort_by_mode`: standard 以上で high、critical で **xhigh 選択肢あり**（`allowed_efforts: [low, medium, high, xhigh]`）
- 探索範囲拡張（`tool_policy: expanded`）

## validation_bias: strict

[`hook-enforcement.md`](../hook-enforcement.md) の追加条件 EHS-1〜EHS-3 が適用される:
- V-3 必須化
- handoff 必須 6 要素チェック厳格化
- V-1 fix loop 上限 5 で ABORT

## 関連

- [`model-profiles.yaml`](../model-profiles.yaml) `models.gpt-5_5_pro`
- [`tool-policy.md`](../tool-policy.md) `tool_policy: expanded` の射影
