# EXECUTION PLAN: TASK-0059 (PBI-HI-007)

## Goal

Issue / Label / Milestone Governance を文書化し、再発防止と運用標準化を実現する。

## Mode 判定

- 変更ファイル数: 3 → light
- 受入基準数: 15 → standard 寄り
- 変更種別: doc 追加 → light
- リスク: 低 → light
- **最終判定**: light（doc only）

## Approach

1. `docs/ai/issue-governance.md` を新規作成（Issue 運用の正本）
2. `.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml` を新規作成
3. `pages/guides/governance/documentation-management.md` に Issue governance への参照追加

## Files to Touch

| File | Action |
|------|--------|
| `docs/ai/issue-governance.md` | 新規 |
| `.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml` | 新規 |
| `pages/guides/governance/documentation-management.md` | 参照追記 |

## Testing Strategy

- L-0: markdown lint（CI）
- V-1: 受入基準 15 項目突合（test-cases.md と照合）

## Risks

- 既存 EPIC #193 の child issue policy との矛盾 → 引用して整合性担保
