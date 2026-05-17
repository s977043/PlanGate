# EXECUTION PLAN — TASK-0091 / #213 PBI-PQ-001

## Goal
軽量 Plan Quality Layer（plan/risk/done check + Health Score + JSON 出力 +
手動実行 + Plan 状態保存）を定義し、将来拡張の土台を作る。

## Constraints / Non-goals
- heavy Gate/Agent/PR review/QA automation/browser daemon を導入しない。
- gstack 直接移植しない（参考思想のみ）。AI 判定は人間承認の代替にしない。
- CLI は scaffold(--init)/validate(--validate) のみ（AI 実行を内蔵しない）。

## Approach Overview
schema（出力構造正規化）→ skill（再利用 Check 観点・Rule 2 準拠）→
doc 正本（責務/Score/保存方針/Non-goals）→ bin/plangate 軽量サブコマンド。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | plan-quality-check.schema.json | agent | 中 | 🚩 AC2/AC4 |
| S2 | .claude/skills/plan-quality-check/SKILL.md | agent | 低 | 🚩 AC1 Rule2 |
| S3 | docs/ai/plan-quality-checks.md 正本 | agent | 中 | 🚩 AC1/3/6/8 |
| S4 | bin/plangate plan-check（--init/--validate）| agent | 中 | 🚩 AC5/7 |

## Files / Components to Touch
- schemas/plan-quality-check.schema.json（新規）
- .claude/skills/plan-quality-check/SKILL.md（新規）
- docs/ai/plan-quality-checks.md（新規・正本）
- bin/plangate（cmd_plan_check + dispatch + help）

## Testing Strategy
- Verification: AC1-8 を grep 構造突合 + schema json.load + CLI smoke
  （--init で雛形→--validate で schema 検証、sh -n 構文）。
- Unit/E2E: 該当なし（定義 + 軽量 scaffold、AI 実行系なし）。

## Risks & Mitigations
- skill 案件固有混入 → Rule 2 機械検出（grep）で 0 件確認
- CLI 肥大化 → --init/--validate に限定、AI 起動を内蔵しない
- 承認境界誤解 → doc/schema/skill すべてに「decision は助言」明記

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 4 → 中
- 受入基準数: 8 → 中
- 変更種別: feat（schema+skill+doc+CLI 新規）→ 中
- リスク: 中（CLI 追加・将来拡張土台・承認境界整合）
- **最終判定**: standard（V-3 外部レビュー実施）
