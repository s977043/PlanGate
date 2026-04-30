# Eval Case: latency / cost

> [`eval-plan.md`](../eval-plan.md) の 8 観点の 1 つ（C-2 Gemini 指摘で 8 観点目として追加）/ WARN

## Trigger

- 1 PBI 完了の reasoning token が baseline ±50% 超過
- 1 phase の壁時計時間が baseline ±50% 超過
- API コスト（estimated）が baseline ±100% 超過

## Detection

```bash
# session log から token 使用量集計（実装は別 PBI）
# 例: codex / claude-cli の実行ログから
# - reasoning_tokens
# - completion_tokens
# - tool_call_count
# - elapsed_time

# baseline 比較
# baseline は前回の同 mode PBI または model-profile 変更前の値
```

## Pass / Fail criteria

| 判定 | 条件 |
|------|------|
| PASS | 全指標が baseline ±20% 以内 |
| WARN | 1〜2 指標が baseline +50% 超過、コスト見合いの品質改善あり |
| FAIL | 全指標が baseline +100% 超過、品質改善なし |

## Model Profile 別 baseline

| profile | reasoning_effort | 想定 latency | 想定コスト |
|---------|----------------|------------|----------|
| gpt-5_mini | low | 短 | 低 |
| gpt-5_5 | medium | 中 | 中 |
| gpt-5_5_pro | high/xhigh | 長 | 高 |

→ Model Profile 変更時は baseline も更新（[`eval-plan.md`](../eval-plan.md) § 4 checklist）。

## release blocker 該当外

WARN / FAIL とも release blocker ではない（コスト判断は経営判断）。ただし FAIL 連発時は profile 選択の retrospective 議論。

## 関連

- [`model-profiles.yaml`](../model-profiles.yaml) `reasoning_effort_by_mode` / `max_context_policy`
- [`eval-comparison-template.md`](../eval-comparison-template.md) latency / tool calls カラム
