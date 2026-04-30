# Eval Case: tool overuse

> [`eval-plan.md`](../eval-plan.md) の 8 観点の 1 つ / WARN

## Trigger

- 不要な検索 / read / web-search が増加（baseline 比 50% 超過）
- 同じファイルを複数回 read（キャッシュ活用なし）
- phase で禁止されている tool を呼び出し（[`tool-policy.md`](../tool-policy.md) allowed_tools 違反）

## Detection

```bash
# tool call 回数（実装は別 PBI、ここでは概念）
# session log から tool 呼び出し回数を集計
# baseline と比較

# allowed_tools 違反
# Hook ([`hook-enforcement.md`](../hook-enforcement.md) Tool Policy) で検出
```

## Pass / Fail criteria

| 判定 | 条件 |
|------|------|
| PASS | tool 呼び出しが baseline ±20% 以内、allowed_tools 違反なし |
| WARN | baseline +50% 超過 |
| FAIL | allowed_tools 違反 1 件以上 |

## Model Profile 関連

| profile | 期待 tool overuse 傾向 |
|---------|--------------------|
| gpt-5_5 (`tool_policy: allowed_tools_by_phase`) | 標準 |
| gpt-5_5_pro (`tool_policy: expanded`) | やや多い（許容範囲） |
| gpt-5_mini (`tool_policy: narrow`) | 少ない |

## release blocker 該当外

WARN として記録、コスト / latency 観点で retrospective 議論。

## 関連

- [`tool-policy.md`](../tool-policy.md)
- [`model-profiles.yaml`](../model-profiles.yaml) `tool_policy` 設定
