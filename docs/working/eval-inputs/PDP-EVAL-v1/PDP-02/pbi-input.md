---
task_id: TASK-EVAL-PDP02
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP02

## Context / Why
Python に `is_even(n)` を追加する。

## What — Scope

### In scope
- 整数の偶奇判定
- unit test

### Out of scope
- 外部I/O
- 入力型の拡張

## Acceptance Criteria
- AC01: 偶数は true
- AC02: 奇数は false
- AC03: 0 と負数を含む

## Notes from Refinement

### Evidence
- E01: 呼び出し側で整数入力が保証される
- E02: 例 — `0 -> true`, `-2 -> true`, `3 -> false`
- E03: 外部I/Oなし

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- なし

**Assumptions**:
- 既存API互換性への影響なし
