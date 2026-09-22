---
task_id: TASK-EVAL-PDP04
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-PDP04

## Context / Why
`format_total` 内のローカル変数 `tmp` を `total_cents` に改名し、意味を明確にする。

## What — Scope

### In scope
- ローカル変数名変更

### Out of scope
- 公開API変更
- 金額丸め変更
- 永続化形式変更
- 金額処理全体の再設計

## Acceptance Criteria
- AC01: 既存の外部挙動を変えない
- AC02: ローカル変数名を `total_cents` にする

## Notes from Refinement

### Evidence
- E01: 既存testは `0 -> "0.00"`, `105 -> "1.05"` で GREEN
- E02: 公開API・丸め・永続化形式の変更要求はない

## Estimation Evidence

**Risks**: 未評価 — Planで判断

**Unknowns**:
- 既存testが全外部挙動を網羅するかは未確認

**Assumptions**:
- 変数名以外の変更要求はない
