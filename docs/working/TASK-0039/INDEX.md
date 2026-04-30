# TASK-0039 INDEX

> Progressive Disclosure 用索引（Level 0、常時読み込み対象）
> 関連: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) のコンテキスト読み込みプロトコル

## 基本情報

| 項目 | 値 |
|------|---|
| TASK ID | TASK-0039 |
| 子 PBI ID | PBI-116-01 |
| Issue | [#117](https://github.com/s977043/plangate/issues/117) |
| Title | Outcome-first Core Contract への移行（prompt slimming） |
| 親 PBI | [PBI-116](../PBI-116/parent-plan.md) |
| Mode | high-risk |
| Phase | **PREPARATORY**（Parent C-3 ゲート APPROVED 待ち） |
| 起票 | 2026-04-30 |

## 現在のフェーズ

⏳ **Parent C-3 ゲート待ち**

`docs/working/PBI-116/approvals/parent-c3.json` の `decision` が `"APPROVED"` になるまで、本 TASK の plan / todo / test-cases 作成には進まない。

## ファイル一覧（現時点）

| ファイル | 状態 |
|---------|------|
| `pbi-input.md` | ✅ 作成済（Issue #117 を構造化） |
| `INDEX.md` | ✅ 本ファイル |
| `current-state.md` | ✅ 作成済 |
| `plan.md` | ⏳ 未作成（Parent C-3 APPROVED 後） |
| `todo.md` | ⏳ 未作成 |
| `test-cases.md` | ⏳ 未作成 |
| `review-self.md` | ⏳ 未作成（C-1 時） |
| `review-external.md` | ⏳ 未作成（C-2 時） |
| `status.md` | ⏳ 未作成（exec 開始時） |
| `current-state.md` | ⏳ 未更新（タスク完了ごと） |
| `handoff.md` | ⏳ 未作成（WF-05 時） |
| `evidence/` | ✅ 空ディレクトリ |

## Progressive Disclosure 読み込み順

| Level | 対象 | 読み込みタイミング |
|-------|------|-----------------|
| **L0** | INDEX.md → current-state.md | セッション開始時必須 |
| **L1** | pbi-input.md（PREPARATORY 段階）| Parent C-3 ゲート判定時 |
| **L1** | plan.md / todo.md / test-cases.md | exec フェーズ（Parent C-3 APPROVED 後） |
| **L2** | evidence/ | レビュー根拠確認時 |

## ネクストアクション

1. **Parent C-3 ゲート判断** 👤
   - 場所: `docs/working/PBI-116/approvals/parent-c3.json`
   - 判定: APPROVED / CONDITIONAL / REJECTED
2. APPROVED 後: 本 TASK で `plan.md` / `todo.md` / `test-cases.md` を別 PR で作成
3. Child C-3 ゲート → exec → L-0 / V-1 / V-2 / V-3 → PR → Child C-4
