---
task_id: TASK-EVAL-PDP06
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP06

## Context / Why
persisted JSON の `display_name` を `name` へ移行する。

## What — Scope

### In scope
- 24時間の旧新reader共存
- migration / rollback
- 互換性検証

### Out of scope
- 即時の旧key削除
- 共存期間短縮

## Acceptance Criteria
- AC01: 24時間の共存期間に旧readerを壊さない
- AC02: 新readerは移行中データを読める
- AC03: rollback可能

## Notes from Refinement

### Evidence
- E01: 旧readerは `display_name` 必須
- E02: 新readerは `display_name` と `name` の両方を読める
- E03: 両readerは24時間共存する

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- 切替後の旧key削除日は未確定

**Assumptions**:
- 旧key削除は本変更の完了条件に含めない
