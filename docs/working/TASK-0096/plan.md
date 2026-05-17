# EXECUTION PLAN — TASK-0096 / #198 PBI-HI-004

## Goal
AI 成果物残存率（Code/Plan/Acceptance/Handoff Keep Rate）を決定論・軽量に
算出し、改善対象を「採用・残存」へ移す（advisory・ゲート非使用）。

## Constraints / Non-goals
- 外部分析基盤 / GitHub 全履歴完全解析 / LLM judge / DCE / release blocker
  強制 はしない。
- metrics event schema を変更しない（別系統 artifact・#203/#197 と非衝突）。

## Approach Overview
keep-rate.py（git log --grep + artifact 軽量近似、unknown フォールバック）→
keep-rate-result.schema.json → schema_mapping 登録 → bin/plangate keep-rate
→ keep-rate.md 正本（4 メトリクス/Handoff 定義方針/metrics 接続/運用/Non-goal）。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | scripts/keep-rate.py | agent | 中 | 🚩 AC1-3,AC5,AC6 |
| S2 | schema + schema_mapping | agent | 中 | 🚩 AC6 validate |
| S3 | bin/plangate keep-rate | agent | 低 | 🚩 AC6 |
| S4 | docs/ai/keep-rate.md 正本 | agent | 中 | 🚩 AC4,AC7,AC8 |

## Files / Components to Touch
- scripts/keep-rate.py（新規）
- schemas/keep-rate-result.schema.json（新規）
- scripts/schema_mapping.py（登録）
- bin/plangate（cmd_keep_rate + dispatch + help）
- docs/ai/keep-rate.md（新規・正本）

## Testing Strategy
- Verification: AC1-8 を smoke（main 在席 TASK で各メトリクス算出 + unknown
  経路）+ 生成 JSON を validate-schemas + grep 構造突合 + ast.parse/sh -n。
- Unit/E2E: 該当なし（決定論スクリプト・runtime 連携なし）。

## Risks & Mitigations
- 全履歴解析化 → git log --grep + 存続率の軽量近似に限定（Non-goal 明記）
- ゲート誤用 → advisory/ゲート非使用を doc/JSON note/出力に明記
- schema 衝突 → 独立 artifact・event schema 非変更

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 5 → 中
- 受入基準数: 8 → 中
- 変更種別: feat（スクリプト+schema+CLI+doc）→ 中
- リスク: 中（決定論計測・ゲート誤用注意）
- **最終判定**: standard（V-3 外部レビュー実施）
