# PBI INPUT PACKAGE: {タイトル}

> フェーズ A（PBI INPUT）で**人間が作成**する。正本: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) の「pbi-input.md」節。

## Context / Why

{なぜやるか。ユーザーの課題・目的。「便利だから」ではなく課題ベースで書く}

## What（Scope）

### In scope

{やること。具体的な機能・振る舞い}

### Out of scope

{やらないこと。明示的な除外範囲}

## 受入基準

- [ ] AC-01: {検証可能な粒度で書く}
- [ ] AC-02:

## Notes from Refinement

> 議論で決まったことの**要約**を記す。判断の正本は [`decision-log.jsonl`](./decision-log.jsonl)（スキーマ: [`decision-log-schema.md`](./decision-log-schema.md)）。
> **不採用にした案とその理由は decision-log の `alternatives_rejected`（`[{option, rationale}]`）に構造化記録**し、ここはその参照・要約に留める（二重管理しない）。high-risk / critical / human decision では `alternatives_rejected` の記録が必須。

## Estimation Evidence

### Risks

{リスク}

### Unknowns

{不明点}

### Assumptions

{前提条件}
