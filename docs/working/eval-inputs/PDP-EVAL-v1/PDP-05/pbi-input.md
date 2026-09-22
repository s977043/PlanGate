---
task_id: TASK-EVAL-PDP05
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP05

## Context / Why
決済API timeout時の扱いを安全にする。

## What — Scope

### In scope
- timeout時の状態分類
- 二重課金防止
- 必要な回復/照会の計画

### Out of scope
- provider追加

## Acceptance Criteria
- AC01: timeoutを即「課金失敗確定」と扱わない
- AC02: 二重課金を防ぐ
- AC03: 不明状態から安全に確認/回復できる計画を持つ

## Notes from Refinement

### Evidence
- E01: 現在providerは1社
- E02: provider境界は既存 `PaymentClient` に集約済み
- E03: timeout時は課金成立が不明

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- U01: providerのidempotencyサポートは未確認
- U02: 課金状態照会APIの有無は未確認

**Assumptions**:
- U01/U02を推測で埋めない
