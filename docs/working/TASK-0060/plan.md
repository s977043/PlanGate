# EXECUTION PLAN: TASK-0060 (PBI-HI-008)

## Goal
Metrics v1 実装前に metrics privacy policy を確定する。

## Mode 判定
light（doc 1 件、リスク低）。

## Approach
1. `docs/ai/metrics-privacy.md` を新規作成
2. PBI-HI-001 (#195) で実装される event schema との接続点を明記（schema 詳細は #195 で別途）

## Files
- `docs/ai/metrics-privacy.md`（新規）

## Testing
- L-0 markdown lint
- V-1 受入基準 8 項目突合
