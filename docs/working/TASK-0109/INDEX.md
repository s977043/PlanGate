# TASK-0109 INDEX

> L0 entry per `.claude/rules/working-context.md` Progressive Disclosure protocol.

- **Source**: GitHub issue #315 (Codex provider 完璧対応 3 件)
- **Title**: bin/plangate review codex 実装 / .codex/hooks 配線 / provider-codex RFC
- **Phase**: B 完了 (plan/todo/test-cases/review-self 揃った) / C-3 待ち (Human-owned)
- **Mode 判定（参考）**: standard
- **Labels**: `enhancement` / `priority:P2`
- **Status**: PBI INPUT PACKAGE のみ作成（local-only、TASK-0107/0108 と同パターン）

## Files

| File | Role | Status |
|------|------|--------|
| `pbi-input.md` | A: PBI INPUT PACKAGE | ✅ |
| `plan.md` | B: EXECUTION PLAN (standard) | ✅ |
| `todo.md` | B: EXECUTION TODO (T-01..T-10) | ✅ |
| `test-cases.md` | B: テストケース定義 (TC-01..TC-12) | ✅ |
| `review-self.md` | C-1 v1 (総合 93, blocker 0) | ✅ |
| `current-state.md` | 現状スナップショット | ✅ |
| `approvals/c3.json` | C-3 ゲート判定 | ⏳ 未発行 (Human) |
| `handoff.md` | WF-05 完了パッケージ | ⏳ exec 完了後 |


## Next action

人間が pbi-input.md をレビュー → plan 生成許可 → AI が plan/todo/test-cases/
review-self → C-3 → exec (CX-1 review wiring → CX-2 hooks → CX-3 RFC の順想定)。
