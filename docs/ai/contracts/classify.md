# Phase Contract: classify

> [`prompt-assembly.md`](../prompt-assembly.md) の 4 層構造 / phase_contract / 7 phase の 1 つ

## Goal

PBI の規模 / リスク / 影響範囲から **PlanGate 5 mode**（ultra-light / light / standard / high-risk / critical）を判定する。

## Success criteria

- 5 mode のいずれかに分類されている
- 判定根拠（fileCountEstimate / acceptanceCriteriaCount / changeKind / riskLevel / rollbackComplexity）が記録されている
- 結果が [`schemas/mode-classification.schema.json`](../../../schemas/mode-classification.schema.json) 準拠

## Stop rules

- 受入基準が曖昧で mode 判定不能 → ユーザーに仕様確定を求めて停止
- 例外ルール適用（security / schema-change / breaking-api）の判定が割れる → 停止

## Output discipline

- Markdown（plan.md の Mode 判定セクション）+ JSON（mode-classification.json、任意）
- 根拠を簡潔に列挙（10 行以内）

## 関連

- [`mode-classification.md`](../../../.claude/rules/mode-classification.md) — 5 mode 分類正本
- [`schemas/mode-classification.schema.json`](../../../schemas/mode-classification.schema.json)
