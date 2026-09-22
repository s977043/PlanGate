---
task_id: TASK-EVAL-PDP03
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP03

## Context / Why
税込5000円ちょうどで送料無料にならない回帰を修正する。

## What — Scope

### In scope
- 送料無料境界条件
- regression test

### Out of scope
- 税計算方式変更
- 配送strategy全面再設計

## Acceptance Criteria
- AC01: 4999円 -> 送料500円
- AC02: 5000円 -> 送料0円
- AC03: 5001円 -> 送料0円

## Notes from Refinement

### Evidence
- E01: 承認済み仕様は「税込5000円以上は送料0円、未満は500円」
- E02: 現在観測は `4999 -> 500`, `5000 -> 500`, `5001 -> 0`

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- なし

**Assumptions**:
- 他の料金ルールは今回変更しない
