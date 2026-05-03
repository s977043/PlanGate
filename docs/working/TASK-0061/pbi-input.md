# PBI INPUT PACKAGE: TASK-0061 (PBI-HI-000 / Issue #194)

## Why
EPIC #193 後続改善 (Metrics v1 / Eval expansion / Model Profile v2 / Keep Rate / Dynamic Context Engine) を「感覚」ではなく「比較」で判断するため、改善前の PlanGate baseline を固定する。

## What
In scope:
- 代表 TASK 3-5 件で `bin/plangate eval` 実行
- 8 観点 baseline を MD/JSON に保存
- hook violation / C-3 / V-1 / C-4 / handoff 現状を記録
- 後続改善との比較ポイントを定義

Out: metrics collector 実装、Keep Rate 算出、Dynamic Context、Model Profile v2 移行

## Mode
light（doc + eval 実行のみ、runtime 変更なし）

## AC（Issue #194 から）
6 項目
