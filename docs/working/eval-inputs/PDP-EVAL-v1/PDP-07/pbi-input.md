---
task_id: TASK-EVAL-PDP07
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP07

## Context / Why
商品一覧と監査ログ一覧のラベルをそれぞれ1箇所変更する。

## What — Scope

### In scope
- 2画面のラベル変更

### Out of scope
- 今回の受入基準に含まれない機能変更

## Acceptance Criteria
- AC01: 指定2ラベルだけ変更する

## Notes from Refinement

### Evidence
- E01: 両画面には形の似た map 処理がある
- E02: 一方は商品、一方は監査ログで変更理由は独立
- E03: 共通API要件なし
- E04: 第三consumer要件なし

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- なし

**Assumptions**:
- 入力に記載した2画面を対象にする
