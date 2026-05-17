# EXECUTION PLAN — TASK-0095 / #197 PBI-HI-003

## Goal
Model Profile を v2 に拡張し、モデル別実行特性（編集形式/回復/文脈取得/
capability/telemetry）を表現可能にする（v1 後方互換維持）。

## Constraints / Non-goals
- プロンプト全文 fork / provider runtime 全面刷新 / Cursor等完全実装 /
  Dynamic Context Engine 実装 / Keep Rate 算出 はしない。
- Core Contract/Gate/Artifact schema をモデル別に変更しない（不変）。
- schema は additive（version enum[1,2]・新フィールド optional）。

## Approach Overview
schema $defs/profile に 5 optional フィールド追加 + version enum[1,2] →
model-profiles.yaml 4 profile を v2 移行（legacy_or_unknown 安全側維持）→
model-profiles.md §8-bis v2 doc（#203 retry 責務分離・#196 比較を前方参照明記）。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | model-profile.schema.json v2 additive | agent | 中 | 🚩 AC1-4 |
| S2 | model-profiles.yaml v2 移行 | agent | 中 | 🚩 AC5/6 |
| S3 | model-profiles.md §8-bis v2 doc | agent | 低 | 🚩 AC7/8 |

## Files / Components to Touch
- schemas/model-profile.schema.json（additive）
- docs/ai/model-profiles.yaml（v2 移行）
- docs/ai/model-profiles.md（§8-bis）

## Testing Strategy
- Verification: AC1-8 を schema json.load + jsonschema validate（v2 yaml /
  v1 後方互換）+ grep 構造突合。
- Unit/E2E: 該当なし（schema/設定/doc、runtime 非実装）。

## Risks & Mitigations
- v1 破壊 → optional + version enum[1,2]、v1 最小 profile を jsonschema 確認
- #203/#196 前方参照 → 依存・推奨マージ順を doc に明記
- telemetry privacy → pattern 制約 + §4 準拠注記

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 3 → 中
- 受入基準数: 8 → 中
- 変更種別: feat（schema v2 + 設定移行 + doc）→ 中
- リスク: 中（共有 schema への version 拡張・後方互換注意）
- **最終判定**: standard（V-3 外部レビュー実施）
