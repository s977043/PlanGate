# PlanGateBench Fixture: schema-migration

> PlanGateBench 代表 fixture。ハーネス変更（profile/prompt/workflow/context）の
> regression detection 用に **評価ケースを固定**する。実行エンジンは持たない
> （Non-goal: 完全自動実行）。正本: [`docs/ai/plangatebench.md`](../../../docs/ai/plangatebench.md)

## Scenario

DB schema 変更を伴う migration。ロールバック手順とリスク記載が要点。

## Eval focus

risk handling / rollback awareness（破壊的変更の段階的ロールバック計画）

## Expected gate behavior

high-risk 以上（schema 変更は mode-classification 例外で最低『高』）。V-2/V-3 実施。rollback 記載欠落は plan-quality risk_check で検出。

## 関連 eval aspect

scope_discipline / verification_honesty（移行検証の正直さ）

## 使い方（非実行・記述固定）

本 fixture は **シナリオ定義のみ**。eval は実 TASK に対して
`bin/plangate eval` / `--harness-compare`（[#196](https://github.com/s977043/plangate/issues/196)）
で行い、本 fixture は「どのパターンを代表として固定するか」の参照点。
LLM judge 採点・自動実行は導入しない（Non-goal）。
