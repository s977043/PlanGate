# Model Adapter: explicit_short

> [`prompt-assembly.md`](../prompt-assembly.md) の model_adapter / 4 種の 1 つ
> 想定モデル: **gpt-5_mini**（高速軽量モデル、[`model-profiles.yaml`](../model-profiles.yaml) `gpt-5_mini`）

## Style

- **明示的かつ短い指示**:
  - outcome の代わりに「具体手順を 1〜3 ステップ」
  - Success criteria は 1 行で
  - 探索範囲を抑制（`tool_policy: narrow`）
- 軽量タスク向け（ultra-light / light モード中心）

## Verbosity

| Phase | verbosity |
|-------|----------|
| classify | low |
| plan | low |
| execute | low |
| review | low |
| handoff | low |
| approve-wait | （不適用） |
| verify | low（review 継承）|

すべて `low`（軽量・短文）。

## Output discipline

- 自然言語は短く
- Markdown 成果物の構造は維持（必須要素は省かない）
- schema 準拠出力は schema 側で形式強制（プロンプトに JSON 例を埋めない）

## Reasoning

- `reasoning_effort_by_mode`: 全 mode で low（critical 除く）
- **critical mode は disallowed**（[`model-profiles.yaml`](../model-profiles.yaml) `disallowed_modes: [critical]`）

## 制限

- critical mode タスクには使用不可
- 探索 / 多段推論を要するタスク（high-risk）には推奨しない（`gpt-5_5` / `gpt-5_5_pro` を使う）

## 関連

- [`model-profiles.yaml`](../model-profiles.yaml) `models.gpt-5_mini`
- [`tool-policy.md`](../tool-policy.md) `tool_policy: narrow` の射影
