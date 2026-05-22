# TASK-0108 INDEX

> L0 entry per `.claude/rules/working-context.md` Progressive Disclosure protocol.

- **Source**: GitHub issue #310 (parent), 短期 PR #311 で #1+#2 完了済
- **Title**: 公開ドキュメント外部 UX 改善 (#310 残 5 項目: #3-#7)
- **Phase**: B 完了 (plan/todo/test-cases/review-self 揃った) / C-3 待ち (Human-owned)
- **Mode 判定（参考）**: standard
- **Labels**: `documentation` / `enhancement` / `priority:P2`
- **Status**: PBI INPUT PACKAGE のみ作成済。plan/todo/test-cases は **C-3 ゲート前**の生成段階で着手

## Files

| File | Role | Status |
|------|------|--------|
| `pbi-input.md` | A: PBI INPUT PACKAGE | ✅ |
| `plan.md` | B: EXECUTION PLAN (standard) | ✅ |
| `todo.md` | B: EXECUTION TODO (T-01..T-11) | ✅ |
| `test-cases.md` | B: テストケース定義 (TC-01..TC-13) | ✅ |
| `review-self.md` | C-1: セルフレビュー (総合 94, blocker 0) | ✅ |
| `current-state.md` | 現状スナップショット | ✅ |
| `approvals/c3.json` | C-3 ゲート判定 | ⏳ 未発行 (Human) |
| `handoff.md` | WF-05 完了パッケージ | ⏳ exec 完了後 |


## Next action

#311 マージ後、人間が pbi-input.md をレビュー → plan 生成許可
→ AI が plan / todo / test-cases / review-self → 必要なら C-2 外部レビュー
（Codex+Gemini に #310 反映評価を再委任）→ C-3 → exec → AC-6 で再評価。
