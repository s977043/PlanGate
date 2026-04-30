# TASK-0040 INDEX

> Progressive Disclosure 用索引（Level 0、常時読み込み対象）

## 基本情報

| 項目 | 値 |
|------|---|
| TASK ID | TASK-0040 |
| 子 PBI ID | PBI-116-02 |
| Issue | [#118](https://github.com/s977043/plangate/issues/118) |
| Title | Model Profile layer 追加（実行モデル別 reasoning / verbosity / context policy） |
| 親 PBI | [PBI-116](../PBI-116/parent-plan.md) |
| Mode | standard |
| Phase | **C3-WAIT**（preparatory + plan/todo/test-cases 完了、C-2 Codex → Child C-3 ゲート待ち） |
| 起票 | 2026-04-30 |

## 現在のフェーズ

⏳ **Child C-3 ゲート待ち**（C-1 完了、C-2 Codex は次セッション）

## ファイル一覧

| ファイル | 状態 |
|---------|------|
| `pbi-input.md` | ✅ 作成済（Issue #118 を構造化、interface-preflight 参照） |
| `INDEX.md` | ✅ 本ファイル |
| `current-state.md` | ✅ 作成済 |
| `plan.md` | ✅ 作成済（Mode: standard、Step 1-4） |
| `todo.md` | ✅ 作成済（2-5 分粒度） |
| `test-cases.md` | ✅ 作成済 |
| `review-self.md` | ✅ C-1 完了 |
| `review-external.md` | ⏳ C-2 Codex（次セッション） |
| `approvals/c3.json` | ⏳ Child C-3（人間判断） |
| `status.md` | ⏳ exec 開始時 |
| `handoff.md` | ⏳ WF-05 時 |
| `evidence/` | ✅ 空（exec 時に inventory.md / verification.md） |

## ネクストアクション

1. ✅ 本 PR の C-4 ゲート（Gemini レビュー対応 + マージ）
2. ⏳ C-2 Codex 外部AIレビュー（次セッション）
3. ⏳ Child C-3 ゲート判断 👤
4. ⏳ exec 開始（model-profiles.yaml + 4 プロファイル定義）→ L-0 → V-1〜V-3 → 子 PR → Child C-4

## 並行実行関係（Codex Phase 2 戦略）

- 順序: PBI-116-02 (本 TASK) → PBI-116-06 → PBI-116-04
- Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)
- 02 と 06 の `tool_policy` / `validation_bias` 接続点は事前合意済み
