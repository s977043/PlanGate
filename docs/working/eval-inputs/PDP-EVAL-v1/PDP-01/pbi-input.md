---
task_id: TASK-EVAL-PDP01
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP01

## Context / Why
保存ボタンの表示文言だけを、現在の「送信」から「保存」へ変える。

## What — Scope

### In scope
- static HTML 上の表示文言

### Out of scope
- submit挙動の変更
- JS selector変更

## Acceptance Criteria
- AC01: 表示が「保存」になる
- AC02: submit動作を維持する
- AC03: button id=`save` を維持する

## Notes from Refinement

### Evidence
- E01: button は `type=submit`, `id=save`
- E02: 現在の JS は `id=save` を参照している
- E03: 多言語対応要件はない

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- なし

**Assumptions**:
- fixture外のデザイン変更要求はない
