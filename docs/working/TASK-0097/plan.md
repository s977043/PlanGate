# EXECUTION PLAN — TASK-0097 / #199 PBI-HI-005

## Goal
phase/mode/profile 別に context を解決する Context Engine v1 を opt-in で
追加し、契約/作業コンテキストを分離（Prompt Assembly・EH-3 と整合）。

## Constraints / Non-goals
- Vector DB/embedding / 全 prompt 移行 / C-3・C-4 緩和 / Keep Rate /
  provider runtime 刷新 はしない。
- 既存 workflow 非破壊（opt-in・明示 CLI のみ）。EH-3 を代替しない。

## Approach Overview
context-manifest.schema.json（contract/dynamic 分離・budget・stale_guard）→
context-engine.py（contract 固定+plan_hash 実照合 / dynamic 記述子 / mode
budget / stale→invalidated exit1）→ bin/plangate context → context-engine.md
正本（policy/budget/EH-3 整合/Prompt Assembly 接続/opt-in/Non-goal）。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | context-manifest.schema.json + mapping | agent | 中 | 🚩 AC1/2 |
| S2 | context-engine.py | agent | 中 | 🚩 AC2/4/5 |
| S3 | bin/plangate context | agent | 低 | 🚩 AC3/7 |
| S4 | context-engine.md 正本 | agent | 中 | 🚩 AC5/6 |

## Files / Components to Touch
- schemas/context-manifest.schema.json（新規）
- scripts/context-engine.py（新規）
- scripts/schema_mapping.py（登録）
- bin/plangate（cmd_context + dispatch + help）
- docs/ai/context-engine.md（新規・正本）

## Testing Strategy
- Verification: AC1-7 を smoke（TASK で contract 解決 + stale 注入で
  invalidated/exit1）+ 生成 JSON validate-schemas + grep + ast/sh -n +
  既存 workflow 非破壊 diff。
- Unit/E2E: 該当なし（決定論 resolver・runtime 連携なし）。

## Risks & Mitigations
- EH-3 矛盾 → plan_hash 実照合・stale=invalidated・ゲート非代替を doc 明記
- opt-in 破壊 → 明示 CLI のみ・bin/plangate diff で context 追加のみ確認
- Vector 化誘惑 → 決定論記述子に限定（Non-goal 明記）

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 5 → 中
- 受入基準数: 7 → 中
- 変更種別: feat（schema+script+CLI+doc 新規・opt-in）→ 中
- リスク: 中（EH-3/Prompt Assembly 整合・承認境界注意）
- **最終判定**: standard（V-3 外部レビュー実施）
