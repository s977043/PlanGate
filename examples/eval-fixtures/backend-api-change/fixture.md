# PlanGateBench Fixture: backend-api-change

> PlanGateBench 代表 fixture。ハーネス変更（profile/prompt/workflow/context）の
> regression detection 用に **評価ケースを固定**する。実行エンジンは持たない
> （Non-goal: 完全自動実行）。正本: [`docs/ai/plangatebench.md`](../../../docs/ai/plangatebench.md)

## Scenario

新規 API エンドポイント追加。受入基準が複数あり test-cases の網羅が要点。

## Eval focus

AC coverage / test-cases（受入基準とテストの 1:1 紐付け）

## Expected gate behavior

standard 判定。C-1 17項目・C-3・V-1 全件突合・V-3 実施。AC 未網羅なら V-1 FAIL。

## 関連 eval aspect

ac_coverage（受入基準網羅率）

## 使い方（非実行・記述固定）

本 fixture は **シナリオ定義のみ**。eval は実 TASK に対して
`bin/plangate eval` / `--harness-compare`（[#196](https://github.com/s977043/plangate/issues/196)）
で行い、本 fixture は「どのパターンを代表として固定するか」の参照点。
LLM judge 採点・自動実行は導入しない（Non-goal）。
