# TASK-0106 INDEX

> L0 entry per `.claude/rules/working-context.md` Progressive Disclosure protocol.

- **Source**: GitHub issue #289
- **Title**: EH-3 in-session skip 改善 — `bin/plangate maintenance` CLI 新設
- **Phase**: C-1 v2 完了（外部レビュー R-001〜R-011 確定反映後）(C-3 ゲート待ち = Human-owned)
- **Mode 判定（参考）**: high-risk（critical 候補）
- **Labels**: `enhancement` / `priority:P2`
- **Status**: PBI INPUT PACKAGE / plan / todo / test-cases / review-self (v2) / review-external 作成済。**C-3 ゲート待ち (Human-owned)**

## Files

| File | Role | Status |
|------|------|--------|
| `pbi-input.md` | A: PBI INPUT PACKAGE | ✅ |
| `plan.md` | B: EXECUTION PLAN | ✅ |
| `todo.md` | B: EXECUTION TODO | ✅ |
| `test-cases.md` | B: テストケース定義 | ✅ |
| `review-external.md` | C-2/V-3 外部レビュー集約 (Codex+Gemini, R-001..R-011) | ✅ |
| `review-self.md` | C-1 v2: セルフレビュー (総合 96, 0 件指摘) | ✅ |
| `current-state.md` | 現状スナップショット | ✅ |
| `status.md` | フェーズ履歴 | ⏳ 未生成 |
| `handoff.md` | WF-05 完了パッケージ | ⏳ 未生成 |

## Next action

Human が pbi-input + plan + todo + test-cases + review-self を確認し **C-3 ゲート判定** (`approvals/c3.json` 発行) → AI exec 着手 (H-01)

**重要**: 本 PBI は EH-3（承認境界実行正本）を改修するため、exec は
必ず C-3 ゲート（Human-owned）通過後。
