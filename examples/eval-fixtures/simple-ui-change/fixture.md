# PlanGateBench Fixture: simple-ui-change

> PlanGateBench 代表 fixture。ハーネス変更（profile/prompt/workflow/context）の
> regression detection 用に **評価ケースを固定**する。実行エンジンは持たない
> （Non-goal: 完全自動実行）。正本: [`docs/ai/plangatebench.md`](../../../docs/ai/plangatebench.md)

## Scenario

ボタン文言/色など低リスクな単一 UI 変更。plan は最小、context も最小で完結する。

## Eval focus

low-risk flow / minimal context（ultra-light〜light で過剰ゲートにならないか）

## Expected gate behavior

規模で分岐: **ultra-light** = 直接実装 + L-0 + V-1 簡易 + PR + C-4（plan/C-1〜C-3 省略）。**light** = 簡易 plan + C-1 簡易(7項目) + C-3 差分確認 + TDD + L-0 + V-1 + PR + C-4、**C-2/V-3 はスキップ**。いずれも過剰な heavy gate（C-2/V-3/V-4）が発火しないこと。

## 関連 eval aspect

format_adherence（最小 plan でも handoff 整形が保たれる）

## 使い方（非実行・記述固定）

本 fixture は **シナリオ定義のみ**。eval は実 TASK に対して
`bin/plangate eval` / `--harness-compare`（[#196](https://github.com/s977043/plangate/issues/196)）
で行い、本 fixture は「どのパターンを代表として固定するか」の参照点。
LLM judge 採点・自動実行は導入しない（Non-goal）。
