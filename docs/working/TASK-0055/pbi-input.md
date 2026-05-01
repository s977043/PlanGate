# PBI INPUT PACKAGE: TASK-0055 / retrospective Try T-5

> Source: [retrospective 2026-05-01 (s3) Try T-5 — v8.4 baseline 測定](../retrospective-2026-05-01-s3.md)
> Mode: **standard**（doc-only / 自動測定）

## Context / Why

retrospective 2026-05-01 (s3) Try T-5。v8.4.0 リリース完了後、`bin/plangate eval`（v8.4 ツーリング）を v8.3 baseline と同 PBI 群（PBI-116 配下 6 件）に走らせ、**v8.3 手動測定との一貫性検証** + **v8.5 比較基準確立**。

## What

### In scope
- PBI-116 配下 6 件（TASK-0039〜0044）に `bin/plangate eval` を走らせて結果集計
- `docs/ai/eval-comparison-template.md` に v8.4 baseline 行追加 + v8.3→v8.4 差分セクション
- `docs/working/TASK-0055/evidence/baseline-data-v8.4.md` に生データ
- `docs/ai/eval-baseline-procedure.md` を v2 に更新（v8.4 自動化版を主、v8.3 手動を後方互換）

### Out of scope
- v8.4 で完了した PBI 群（TASK-0045〜0054）の測定 — `approvals/c3.json` 不在のため別 PBI（Auto Mode 包括承認の運用化）
- session log 取得（PBI-116 配下に保存なし）

## Acceptance Criteria

- AC-1: 全 6 PBI で `bin/plangate eval` が exit 0 (release blocker 0)
- AC-2: 集計値が v8.3 手動 baseline と一致（AC 100% / format 100% / 全 PASS）
- AC-3: schema compliance が **100%**（#167 c3 schema 緩和の効果実証）
- AC-4: `eval-comparison-template.md` に v8.4 baseline 行 + v8.3→v8.4 差分テーブルあり
- AC-5: `eval-baseline-procedure.md` の Status が v2 / 自動手順が主
