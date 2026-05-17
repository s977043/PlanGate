---
name: plan-quality-check
description: "計画の不足情報・リスク・暗黙の前提・完了条件・次アクションを軽量に構造化抽出する。Use when: 計画の品質を実装前に確認したい時、Missing Items / Risks / Assumptions / Done Criteria を JSON 化したい時、重い Gate を使わず計画健全性を素早く見える化したい時。"
---

# Plan Quality Check

計画文書（目的・スコープ・成功条件・完了条件）を読み、品質を構造化して
返す軽量 Check の Skill。重い Gate / Agent orchestration / PR review /
QA automation には依存しない（手動実行可能・補助情報）。

## カテゴリ

Design

## 想定 Phase

計画レビュー前後の軽量確認（計画作成直後・実装着手前）

## 役割

3 種の Check を単独または統合（combined）で実行する:

| Check | 目的 | 主出力 |
| --- | --- | --- |
| `plan_check` | 目的・対象・成功条件・スコープの明確さを確認 | score / missing_items / summary |
| `risk_check` | 失敗要因・依存関係・未決事項・暗黙の前提を確認 | risks / assumptions / next_actions |
| `done_check` | 完了条件・検証方法・リリース後確認を確認 | done_criteria / validation_notes |

## 入力

- 計画文書（目的 / スコープ / 受入基準 / 完了条件を含むテキスト）
- 任意: 確認したい Check 種別（plan_check / risk_check / done_check / combined）

## 出力

- 結果 JSON（`score`, `decision`, `summary`, `missing_items`, `risks`,
  `assumptions`, `done_criteria`, `next_actions`, 任意 `score_breakdown`,
  `validation_notes`）
- 出力構造はリポジトリ側スキーマ（`schemas/plan-quality-check.schema.json`）
  に準拠させる
- 自由文サマリも併記してよいが、機械処理対象は JSON とする

## Plan Health Score の考え方

0-100。最小内訳: goal_clarity / scope_defined / success_metric /
risks_identified / done_criteria_defined。閾値で助言的に
`ready` / `needs_clarification` / `insufficient` を返す。

## 制約

- 本 Check の `decision` は **助言**であり、人間承認・ゲート判定の
  代替にしない。
- 重い自動実行（PR review / browser QA / pair-agent）を呼び出さない。
- 不足が判定不能なときは安全側（より低い score / needs_clarification）。
