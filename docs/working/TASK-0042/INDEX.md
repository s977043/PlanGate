# TASK-0042 INDEX

## 基本情報

| 項目 | 値 |
|------|---|
| TASK ID | TASK-0042 |
| 子 PBI ID | PBI-116-04 |
| Issue | [#120](https://github.com/s977043/plangate/issues/120) |
| Title | Structured Outputs / JSON Schema 方針を PlanGate 成果物に適用 |
| 親 PBI | [PBI-116](../PBI-116/parent-plan.md) |
| Mode | standard |
| Phase | **C3-WAIT**（preparatory + plan/todo/test-cases + C-1 完了） |
| 起票 | 2026-04-30 |

## 現在のフェーズ

⏳ Child C-3 ゲート待ち（C-1 PASS、C-2 Codex は次セッション）

## ファイル一覧

| ファイル | 状態 |
|---------|------|
| pbi-input.md | ✅ 作成済 |
| INDEX.md | ✅ 本ファイル |
| current-state.md | ✅ 作成済 |
| plan.md | ✅ Mode standard、Step 1-4 |
| todo.md | ✅ T-1〜T-20 |
| test-cases.md | ✅ TC-1〜TC-8 + TC-E1〜TC-E3 |
| review-self.md | ✅ C-1 完了 |
| review-external.md | ⏳ C-2 Codex（次セッション） |
| approvals/c3.json | ⏳ Child C-3 |
| status.md / handoff.md | ⏳ exec / WF-05 時 |
| evidence/ | ✅ 空 |

## 並行関係

- 順序: PBI-116-02 → PBI-116-06 → **本 TASK**
- **02/06 とは独立** — Structured Outputs schema は Model Profile / Tool Policy と直交
- PBI-116-03 (Prompt Assembly) も意図的に独立（参照が必要なら別 PBI）

## ネクストアクション

1. 本 PR C-4
2. C-2 Codex
3. Child C-3 👤
4. exec → 子 PR → Child C-4
