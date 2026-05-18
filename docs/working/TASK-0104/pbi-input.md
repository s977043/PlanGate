# PBI INPUT — TASK-0104 / roadmap doc 状態同期（Codex 盲点指摘）

## Context / Why
残タスク確認の Codex 相談で盲点指摘: docs/ai/harness-improvement-roadmap.md
が #196-204/#213/#224-231 を 🔵 Open と記載するが GitHub 上は全 CLOSED
（EPIC #193 CLOSED/COMPLETED）。stale ドキュメント。evidence-based 文化に
反するため整合修正（#282 には触れない・実装でなく状態同期のみ）。

## What
- In: docs/ai/harness-improvement-roadmap.md（Status/Progress + 表 Status 列を
  完了状態へ同期。PR 番号付記でトレース可能化）
- Out: #282 着手 / コード変更 / ロードマップ内容（Phase 定義・本文）の変更 /
  EPIC 再オープン

## 受入基準
- AC1: 表の 🔵 Open が GitHub CLOSED 実態に合わせ ✅ Done に同期（残 0）
- AC2: 各完了行に対応 PR 番号を付記（トレーサビリティ）
- AC3: Status/Progress ヘッダが EPIC #193 CLOSED を反映
- AC4: ロードマップの Phase 定義・本文は不変（状態列のみ変更）

## Notes
純 docs 整合（markdown）。run-tests 影響なし。Codex 確認: #282 は Defer 維持
（本 PBI は別件・docs stale 解消）。

## Estimation
Risks: 状態誤記（緩和: GitHub 実 state 全 CLOSED 確認済・PR 番号突合）/
Unknowns: なし
