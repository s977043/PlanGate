# Eval Comparison Template

> [`eval-plan.md`](./eval-plan.md) § 3 で参照される比較表テンプレート
> Model Profile 変更時 / プロンプト変更時 / モデル世代変更時に記入

## 比較表（最低限の 4 行）

```text
| prompt version | model profile      | reasoning effort | accuracy | latency | tool calls | format adherence | scope discipline | verification honesty | notes |
|---             |---                 |---               |---:      |---:     |---:        |---:              |---:              |---:                  |---    |
| old            | default            | medium           |          |         |            |                  |                  |                      |       |
| new            | gpt-5_5            | low              |          |         |            |                  |                  |                      |       |
| new            | gpt-5_5            | medium           |          |         |            |                  |                  |                      |       |
| new            | gpt-5_5_pro        | high             |          |         |            |                  |                  |                      |       |
```

### カラム定義

| カラム | 単位 / 値 |
|-------|---------|
| prompt version | old / new / その他 ID |
| model profile | [`model-profiles.yaml`](./model-profiles.yaml) のキー（gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown / その他） |
| reasoning effort | low / medium / high / xhigh |
| accuracy | %（AC PASS 率）|
| latency | 秒（1 PBI あたり） |
| tool calls | 回数（1 PBI あたり）|
| format adherence | %（schema 準拠率）|
| scope discipline | PASS / FAIL |
| verification honesty | PASS / FAIL |
| notes | 備考、retrospective 議論ポイント |

## 記入例（架空）

| prompt version | model profile | reasoning effort | accuracy | latency | tool calls | format adherence | scope discipline | verification honesty | notes |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| v8.1 | default | medium | 95% | 45s | 23 | 92% | PASS | PASS | baseline |
| v8.2 | gpt-5_5 | low | 92% | 32s | 18 | 95% | PASS | PASS | latency -29%、accuracy -3% 許容範囲 |
| v8.2 | gpt-5_5 | medium | 96% | 48s | 21 | 96% | PASS | PASS | baseline 同等 + 改善 |
| v8.2 | gpt-5_5_pro | high | 98% | 75s | 32 | 98% | PASS | PASS | accuracy 高、latency +66% コスト見合い |

## 採用判定の例

- **採用 (deploy)**: scope/verification honesty PASS + accuracy 維持 + latency 削減 + コスト改善
- **保留 (WARN)**: latency / cost が baseline +50% 超過だが accuracy 大幅改善
- **却下 (release blocker)**: scope discipline FAIL or verification honesty FAIL or schema 準拠率 < 95%

## eval 実行手順

1. baseline 取得（変更前の同条件で 8 観点測定、最低 3 PBI）
2. 変更（profile 追加 / reasoning_effort 調整 等）
3. 変更後測定（同 3 PBI）
4. 本テンプレートに記入
5. 8 観点判定（[`eval-plan.md`](./eval-plan.md) § 2）
6. release blocker 該当時はリリース停止、それ以外は WARN 記録 + retrospective

## 関連

- [`eval-plan.md`](./eval-plan.md) § 3 比較対象テンプレート、§ 4 Model Profile 変更時 checklist
- 全 eval-cases [`eval-cases/`](./eval-cases/)
