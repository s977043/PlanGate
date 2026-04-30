# Model Adapter: outcome_first

> [`prompt-assembly.md`](../prompt-assembly.md) の model_adapter / 4 種の 1 つ
> 想定モデル: **gpt-5_5**（標準実行モデル、[`model-profiles.yaml`](../model-profiles.yaml) `gpt-5_5`）

## Style

- **outcome 駆動**: Role / Goal / Success criteria / Hard constraints / Decision rules / Available evidence / Stop rules / Output discipline の 8 セクション順守
- 「やり方」より「達成すべき outcome」を強調
- モデルに判断余地を残す（細かい手順を縛らない）

## Verbosity

[`model-profiles.yaml`](../model-profiles.yaml) の `gpt-5_5.verbosity_by_phase` 値に従う:

| Phase | verbosity |
|-------|----------|
| classify | low |
| plan | medium |
| execute | low |
| review | medium |
| handoff | medium |
| approve-wait | （不適用） |
| verify | medium（review 継承）|

## Output discipline

- Markdown 成果物は `core-contract.md` の Output discipline に従う
- 機械判定結果は [`structured-outputs.md`](../structured-outputs.md) の schema に準拠
- Iron Law / 4 原則は重複転記せず、`base_contract` への参照で十分

## Reasoning

- `reasoning_effort_by_mode` は profile 値（low / medium / high）に従う
- critical mode で xhigh は使わない（`gpt-5_5_pro` の役割）

## 関連

- [`model-profiles.yaml`](../model-profiles.yaml) `models.gpt-5_5`
- [`prompt-assembly.md`](../prompt-assembly.md) § 5 解決ロジック
