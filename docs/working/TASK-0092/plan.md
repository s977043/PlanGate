# EXECUTION PLAN — TASK-0092 / #196 PBI-HI-002

## Goal
ハーネス変更（profile/prompt/workflow）を PBI-HI-000 baseline と比較し
release blocker を明示する eval 比較を additive に追加する。

## Constraints / Non-goals
- 新 LLM judge を導入しない（既存 8 観点再利用）。
- 外部ダッシュボード / 全 provider session log parser / Keep Rate /
  Dynamic Context は実装しない。
- 既存 eval / --baseline / --dogfood の挙動を変更しない（additive のみ）。

## Approach Overview
eval-runner.py に _task_summary/harness_compare/render_harness_compare_md を
追加し、main() に --harness-compare 独立 early-return（--dogfood と同型）。
新 schema eval-comparison.schema.json + schema_mapping 登録。docs 2 件に
運用手順 + PBI-HI-000 接続を追記。CLI は cmd_eval 素通しで対応。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | eval-runner.py additive harness_compare | agent | 中 | 🚩 AC1-5 |
| S2 | eval-comparison.schema.json + mapping | agent | 中 | 🚩 AC2 schema validate |
| S3 | eval-runner.md / eval-comparison-template.md 追記 | agent | 低 | 🚩 AC6/7 |

## Files / Components to Touch
- scripts/eval-runner.py（additive）
- schemas/eval-comparison.schema.json（新規）
- scripts/schema_mapping.py（登録）
- docs/ai/eval-runner.md / docs/ai/eval-comparison-template.md（追記）

## Testing Strategy
- Verification: AC1-7 を smoke（代表 TASK 3 件で --harness-compare 実行）+
  生成 JSON を validate-schemas + grep 構造突合 + ast.parse 構文。
- Unit/E2E: 既存 eval 非破壊を smoke（通常 eval が従来どおり動くか）。

## Risks & Mitigations
- 既存 eval 破壊 → additive early-return、task_id を nargs="?" にしつつ
  非 harness-compare 経路の必須チェック維持
- judge 改変誤解 → build_eval_result 再利用、Non-goal 明記

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 5 → 中
- 受入基準数: 7 → 中
- 変更種別: feat（eval 比較 additive 拡張）→ 中
- リスク: 中（既存 eval 基盤への additive・回帰注意）
- **最終判定**: standard（V-3 外部レビュー実施）
