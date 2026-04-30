# TASK-0041 INDEX

> Progressive Disclosure 用索引

## 基本情報

| 項目 | 値 |
|------|---|
| TASK ID | TASK-0041 |
| 子 PBI ID | PBI-116-06 |
| Issue | [#122](https://github.com/s977043/plangate/issues/122) |
| Title | Tool Policy / Hook enforcement 境界整理（最新モデル向け） |
| 親 PBI | [PBI-116](../PBI-116/parent-plan.md) |
| Mode | standard |
| Phase | **EXEC-READY**（Child C-3 APPROVED 2026-04-30、exec 開始可） |
| 起票 | 2026-04-30 |

## 現在のフェーズ

⏳ Child C-3 ゲート待ち（C-1 PASS、C-2 Codex は次セッション）

## ファイル一覧

| ファイル | 状態 |
|---------|------|
| pbi-input.md | ✅ 作成済（Issue #122 構造化、interface-preflight 参照） |
| INDEX.md | ✅ 本ファイル |
| current-state.md | ✅ 作成済 |
| plan.md | ✅ 作成済（Mode: standard、Step 1-4） |
| todo.md | ✅ 作成済 |
| test-cases.md | ✅ 作成済 |
| review-self.md | ✅ C-1 完了 |
| review-external.md | ⏳ C-2 Codex（次セッション） |
| approvals/c3.json | ⏳ Child C-3 |
| status.md / handoff.md | ⏳ exec / WF-05 時 |
| evidence/ | ✅ 空 |

## ネクストアクション

1. 本 PR の C-4 ゲート
2. C-2 Codex 外部AIレビュー（次セッション）
3. Child C-3 ゲート判断 👤
4. exec → 子 PR → Child C-4

## 並行関係（Codex Phase 2 戦略）

- 順序: PBI-116-02 → **本 TASK** → PBI-116-04
- Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)
- 02 が定義した `tool_policy` 値域を本 TASK が参照（実 tool セット射影）
- 02 が定義した `validation_bias: strict` 時の追加 Hook 条件を本 TASK が定義
