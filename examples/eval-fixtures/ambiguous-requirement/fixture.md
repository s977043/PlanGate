# PlanGateBench Fixture: ambiguous-requirement

> PlanGateBench 代表 fixture。ハーネス変更（profile/prompt/workflow/context）の
> regression detection 用に **評価ケースを固定**する。実行エンジンは持たない
> （Non-goal: 完全自動実行）。正本: [`docs/ai/plangatebench.md`](../../../docs/ai/plangatebench.md)

## Scenario

受入基準が曖昧で測定不能。実装着手前に明確化が必要なパターン。

## Eval focus

stop behavior / clarification（不明確なまま実装に進まないか）

## Expected gate behavior

**Stop rule 発火（曖昧要件）が exec を止める実機構**。plan-quality plan_check は success_metric 不足を missing_items(major)/decision=needs_clarification として**助言記録（非 blocking・hard gate ではない）**。仕様確定まで**人間判断で** exec に進まない（plan_check 単体は止めない）。

## 関連 eval aspect

stop_behavior（曖昧要件での停止）

## 使い方（非実行・記述固定）

本 fixture は **シナリオ定義のみ**。eval は実 TASK に対して
`bin/plangate eval` / `--harness-compare`（[#196](https://github.com/s977043/plangate/issues/196)）
で行い、本 fixture は「どのパターンを代表として固定するか」の参照点。
LLM judge 採点・自動実行は導入しない（Non-goal）。
