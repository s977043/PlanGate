---
task_id: TASK-EVAL-PDP08
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP08

## Context / Why
CSV export の既存列末尾へ `created_at` を追加する。

## What — Scope

### In scope
- column追加
- 既存列位置/値の維持

### Out of scope
- 今回の受入基準に含まれない機能変更

## Acceptance Criteria
- AC01: 既存列の位置と値を維持する
- AC02: `created_at` を末尾へ追加する

## Notes from Refinement

### Evidence
- E01: 仕様は列順だけ定義する
- E02: 行順保証は仕様にない
- E03: 現在はDBが返した順でexportする
- E04: 固定fixture例は `id=42`, `created_at=2026-09-20T00:00:00Z`

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- なし

**Assumptions**:
- 入力に記載のない行順保証は未確認
