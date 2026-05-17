# EXECUTION PLAN — TASK-0093 / #203 PBI-HI-010

## Goal
Tool Error Taxonomy と Recovery Policy を正本化し、Model Profile v2
retry_strategy / Metrics v1 tool_error event に接続する。

## Constraints / Non-goals
- provider runtime 全面実装 / 全 provider エラー形式 / 自動修復完全実装 /
  外部監視連携 / C-3・C-4 ゲート緩和 はしない。
- schema は additive のみ（既存 event / schema_version を破壊しない）。
- core-contract.md §5 を再定義せず本正本へ集約（参照化）。

## Approach Overview
tool-error-taxonomy.md 正本（category/severity/recovery/classification/
metrics/backlog/profile 接続）→ schema additive（tool_error event +
tool_error_category, 1.1）→ core-contract §5 参照化 → model-profiles
§8-bis retry_strategy → metrics §3.5 tool_error 記録。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | tool-error-taxonomy.md 正本 | agent | 中 | 🚩 AC1-4,AC7 |
| S2 | plangate-event.schema.json additive | agent | 中 | 🚩 AC6 非破壊 |
| S3 | core-contract/model-profiles/metrics 接続 | agent | 中 | 🚩 AC5/AC6 |

## Files / Components to Touch
- docs/ai/tool-error-taxonomy.md（新規・正本）
- schemas/plangate-event.schema.json（additive）
- docs/ai/core-contract.md（§5 参照化）
- docs/ai/model-profiles.md（§8-bis retry_strategy）
- docs/ai/metrics.md（§3.5 tool_error）

## Testing Strategy
- Verification: AC1-7 を grep 構造突合 + tool_error event を jsonschema
  validate + 既存 event 非破壊 validate（schema_version 1.0/1.1）。
- Unit/E2E: 該当なし（定義 + schema additive、runtime 実装なし）。

## Risks & Mitigations
- schema 破壊 → additive enum/optional のみ、新旧 event を jsonschema 検証
- core-contract 二重定義 → §5 を正本参照に置換、最小定義のみ残置
- 承認境界誤解 → Non-goal で C-3/C-4 緩和なしを明記

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 5 → 中
- 受入基準数: 7 → 中
- 変更種別: feat（正本 + schema additive + 多正本接続）→ 中
- リスク: 中（共有 schema への additive・回帰注意）
- **最終判定**: standard（V-3 外部レビュー実施）
