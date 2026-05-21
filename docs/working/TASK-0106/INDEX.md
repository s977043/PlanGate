# TASK-0106 INDEX

> L0 entry per `.claude/rules/working-context.md` Progressive Disclosure protocol.

- **Source**: GitHub issue #289
- **Title**: EH-3 in-session skip 改善 — `bin/plangate maintenance` CLI 新設
- **Phase**: exec 完了・V-1 PASS（handoff 6 要素 + AC-1..13 全 PASS + tests 82/0 + 79/0、PR 待ち）
- **Mode 判定（参考）**: high-risk（critical 候補）
- **Labels**: `enhancement` / `priority:P2`
- **Status**: PBI INPUT PACKAGE / plan / todo / test-cases / review-self (v2) / review-external 作成済。**C-3 ゲート待ち (Human-owned)**

## Files

| File | Role | Status |
|------|------|--------|
| `pbi-input.md` | A: PBI INPUT PACKAGE (v3.2 + v3.1 AC ラベル整合) | ✅ |
| `plan.md` | B: EXECUTION PLAN (v3.2) | ✅ |
| `todo.md` | B: EXECUTION TODO (v3.2) | ✅ |
| `test-cases.md` | B: テストケース定義 (TC-01..TC-34) | ✅ |
| `review-self.md` | C-1 v3.1 (総合 98 / blocker 0) | ✅ |
| `review-external.md` | C-2/V-3 外部レビュー集約 (R-001..R-031) | ✅ |
| `approvals/c3.json` | C-3 ゲート判定 APPROVED (2026-05-21、Human) | ✅ |
| `handoff.md` | WF-05 完了パッケージ (Rule 5 必須 6 要素) | ✅ |
| `current-state.md` | 現状スナップショット | ✅ |


## Next action

Human が pbi-input + plan + todo + test-cases + review-self を確認し **C-3 ゲート判定** (`approvals/c3.json` 発行) → AI exec 着手 (H-01)

**重要**: 本 PBI は EH-3（承認境界実行正本）を改修するため、exec は
必ず C-3 ゲート（Human-owned）通過後。
