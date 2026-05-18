# EXECUTION PLAN — TASK-0104 / roadmap doc 状態同期

## Goal
harness-improvement-roadmap.md を GitHub 実態（全 CLOSED）に同期し
トレース可能化。

## Constraints / Non-goals
- #282 着手 / コード変更 / ロードマップ本文・Phase 定義変更 / EPIC 再オープン
  はしない。状態列と Status/Progress のみ。

## Approach Overview
表の `🔵 Open (vX / #NNN)` を `✅ Done (vX / #NNN / PR #MMM)` へ機械置換
（issue→マージ PR マップ）。Status/Progress ヘッダを EPIC #193 CLOSED 反映。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | 表 Status 列 + ヘッダ同期 | agent | 低 | 🚩 AC1-4 |

## Files / Components to Touch
- docs/ai/harness-improvement-roadmap.md（単独）

## Testing Strategy
- Verification: 残 🔵 Open=0 / 各行 PR 番号付記 / GitHub 実 state 全 CLOSED
  突合 / 本文 diff が状態列のみ / run-tests 影響なし（markdown）。

## Risks & Mitigations
- 状態誤記 → 全子 PBI CLOSED を gh で確認済・PR マップ突合

## Questions / Unknowns
なし

## Mode判定
**モード**: light
**判定根拠**: 単一 docs ファイルの状態同期・コード/挙動非変更 → light
