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
| Phase | **EXEC-COMPLETE**（PR-B で全 Step 完了、Child C-4 ゲート待ち） |
| 起票 | 2026-04-30 |

## 現在のフェーズ

✅ **Parent C-3 APPROVED**（2026-04-30、s977043）

`docs/working/PBI-116/approvals/parent-c3.json` で `decision: "APPROVED"`。本 TASK の plan / todo / test-cases 作成に進める。

## ファイル一覧（現時点）

| ファイル | 状態 |
|---------|------|
| `pbi-input.md` | ✅ 作成済（Issue #117 を構造化、Iron Law 対応表追加 / C-2 EX-02） |
| `INDEX.md` | ✅ 本ファイル |
| `current-state.md` | ✅ 更新済 |
| `plan.md` | ✅ 作成済（C-2 EX-01/03/04/05 反映済） |
| `todo.md` | ✅ 作成済 |
| `test-cases.md` | ✅ 作成済（C-2 EX-04 反映済） |
| `review-self.md` | ✅ C-1 完了（16 PASS / 1 WARN / 0 FAIL → PASS） |
| `review-external.md` | ✅ C-2 完了（CONDITIONAL → 同 PR で対応） |
| `status.md` | ⏳ 未作成（exec 開始時） |
| `handoff.md` | ⏳ 未作成（WF-05 時） |
| `evidence/` | ✅ 空ディレクトリ（exec 時に inventory.md / verification.md 作成） |
| `_codex-prompt.txt` | ✅ Codex C-2 入力プロンプト（再現性のため保持） |

## Progressive Disclosure 読み込み順

| Level | 対象 | 読み込みタイミング |
|-------|------|-----------------|
| **L0** | INDEX.md → current-state.md | セッション開始時必須 |
| **L1** | pbi-input.md（PREPARATORY 段階）| Parent C-3 ゲート判定時 |
| **L1** | plan.md / todo.md / test-cases.md | exec フェーズ（Parent C-3 APPROVED 後） |
| **L2** | evidence/ | レビュー根拠確認時 |

## ネクストアクション

1. ✅ Parent C-3 ゲート APPROVED（2026-04-30、s977043）
2. **本 TASK で `plan.md` / `todo.md` / `test-cases.md` を別 PR で作成**（次セッション）
3. C-1 セルフレビュー（17 項目）→ C-2 外部AIレビュー（Codex 必須）
4. Child C-3 ゲート判断 👤
5. APPROVED 後 exec → L-0 → V-1 → V-2 → V-3 → PR → Child C-4
