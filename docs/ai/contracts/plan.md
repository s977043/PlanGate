# Phase Contract: plan

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ

## Goal

PBI INPUT PACKAGE から `plan.md` / `todo.md` / `test-cases.md` を生成する。「作文」ではなく「実行可能な計画」。

## Success criteria

- Goal / Constraints / Approach Overview / Work Breakdown / Files / Testing Strategy / Risks / Mode 判定がすべて含まれる
- todo.md は 2-5 分粒度、depends_on / Owner / files が全タスクに記述
- test-cases.md は AC → TC マッピングと自動化可否
- Iron Law: `NO EXECUTION WITHOUT REVIEWED PLAN FIRST`

## Stop rules

- 受入基準が plan / test-cases に完全カバーできない → ユーザーに仕様確認
- scope 外作業が必要と判明 → 別 PBI として起票し、本 PBI では扱わない

## Output discipline

- Markdown 3 ファイル（plan / todo / test-cases）
- frontmatter 不要（schema 化は plan-output 等で別 PBI）

## 関連

- [`docs/working/templates/`](../../working/templates/) テンプレ
- [`schemas/plan.schema.json`](../../../schemas/plan.schema.json)（既存 frontmatter schema）
