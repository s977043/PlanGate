# Status — TASK-0038

> 関連 Issue: [#109](https://github.com/s977043/plangate/issues/109)
> 関連 Epic: [#72](https://github.com/s977043/plangate/issues/72)
> ブランチ: `feat/task-0038-parent-child-pbi`
> モード: high-risk（仕様策定のみ）

## 全体構成

| 項目 | 値 |
|------|---|
| PR | 未作成（C-3 ゲート前） |
| ブランチ | `feat/task-0038-parent-child-pbi` |
| base | main（80b7bf9）|
| 状態 | **C-3 ゲート待機中** |

## 現在のフェーズ

```text
[Phase A: 準備] ✅ 完了
   ↓
[C-3 ゲート] ← 👤 人間レビュー待ち（現在地）
   ↓
[Phase B: 仕様策定] 未着手
   ↓
[Phase C: 検証] 未着手
   ↓
[Phase D: 完了処理] 未着手
   ↓
[C-4 ゲート]
```

## Phase A 完了記録（2026-04-28）

| 成果物 | ファイル | 状態 |
|-------|---------|------|
| PBI INPUT PACKAGE | `pbi-input.md` | ✅ 作成完了 |
| EXECUTION PLAN | `plan.md` | ✅ 作成完了 |
| EXECUTION TODO | `todo.md` | ✅ 作成完了 |
| テストケース | `test-cases.md` | ✅ 作成完了（TC-01 〜 TC-20 + EC-01 〜 EC-05）|
| C-1 セルフレビュー | `review-self.md` | ✅ 17 項目全 PASS |

C-1 セルフレビュー結果サマリ:

- Plan 7 項目: 全 PASS
- ToDo 5 項目: 全 PASS
- TestCases 3 項目: 全 PASS
- 総合: **WARN / FAIL なし、C-3 提出可**

## 残タスク

### C-3 ゲート前（人間アクション）

- [ ] 👤 `plan.md` レビュー（Approach Overview / Work Breakdown / Testing Strategy）
- [ ] 👤 `review-self.md` 確認（17 項目チェック結果）
- [ ] 👤 `pbi-input.md` の Out of scope と Notes from Refinement 確認
- [ ] 👤 C-3 三値判定（APPROVE / CONDITIONAL / REJECT）

### C-3 APPROVE 後（exec phase, 私が実行）

- [ ] B-1 アーキテクチャ正本（`docs/orchestrator-mode.md`）
- [ ] B-2 子 PBI YAML スキーマ（`docs/schemas/child-pbi.yaml`）
- [ ] B-3 分解 Workflow（`docs/workflows/orchestrator-decomposition.md`）
- [ ] B-4 統合 Workflow（`docs/workflows/orchestrator-integration.md`）
- [ ] B-5 Template 4 種（`docs/working/templates/{parent-plan,dependency-graph,parallelization-plan,integration-plan}.md`）
- [ ] B-6 Rule 正本（`.claude/rules/orchestrator-mode.md`）
- [ ] B-7 CLI RFC（`docs/rfc/plangate-decompose.md`）
- [ ] B-8 PR 戦略仕様の追記
- [ ] B-9 README / index 更新
- [ ] B-10 検証スクリプト（`scripts/check-orchestrator-docs.sh`）
- [ ] V-1 受け入れ検査（`scripts/check-orchestrator-docs.sh` 実行）
- [ ] handoff.md 生成
- [ ] PR 作成（`Closes #109`）
- [ ] 👤 C-4 ゲート（GitHub PR レビュー）

## V 系ステップ進捗

| ステップ | 状態 |
|---------|------|
| L-0 リンター | 未実行（仕様策定のみのためコード変更なし、N/A 可能性大）|
| V-1 受け入れ検査 | 未実行（exec 完了後）|
| V-2 コード最適化 | N/A（コード変更なし）|
| V-3 外部モデルレビュー | 任意（high-risk 推奨）|
| V-4 リリース前チェック | N/A（critical 限定）|

## モード判定結果

**high-risk**（plan.md 末尾の「Mode判定」参照）

- 変更ファイル数 13（新規 9 + 更新 4）
- 受入基準数 9
- アーキテクチャ仕様策定（既存 v7 hybrid 拡張）
- 影響範囲: PlanGate 全体

**ただし実装を含まない**ため、純粋な high-risk より検証コストは低い。

## C-3 ゲート提出 — 人間レビュアーへ

### レビュー対象ドキュメント

1. `docs/working/TASK-0038/pbi-input.md` — PBI INPUT PACKAGE
2. `docs/working/TASK-0038/plan.md` — 実装計画
3. `docs/working/TASK-0038/todo.md` — タスクリスト
4. `docs/working/TASK-0038/test-cases.md` — テストケース
5. `docs/working/TASK-0038/review-self.md` — C-1 セルフレビュー結果

### 重点確認事項

1. スコープが純粋に **仕様策定のみ**で実装を含まない構造か
2. 既存 v7 hybrid（5 Agent / 5 phase）を**破壊しない**設計か
3. AC 9 項目すべてに対応文書が割り当てられているか
4. テスト戦略が妥当か（grep ベース整合性検証で十分か）
5. モード判定（high-risk）が妥当か

### 判定後の記録方法

C-3 判定結果をこの status.md の冒頭に追記:

```markdown
## C-3 Gate: APPROVED / CONDITIONAL / REJECTED
- 判定者: <name>
- 日時: <YYYY-MM-DD>
- コメント: <free text>
```

CONDITIONAL の場合は plan.md に修正点を反映後、C-1 簡易再実行（Plan 7 項目のみ）を依頼。

## 次回セッション用の Claude Code プロンプト

C-3 APPROVE 後、以下のプロンプトで exec を再開:

```
docs/working/TASK-0038/status.md と plan.md を参照して、
TASK-0038 の Phase B（exec）を開始してください。

C-3 ゲートは APPROVED 済み。
todo.md の B-1 から B-10 まで順次実行し、
完了後に PR 作成（Closes #109）まで進めてください。

ブランチ: feat/task-0038-parent-child-pbi
モード: high-risk（仕様策定のみ、実装なし）
```

## 参照ファイル一覧

- `docs/working/TASK-0038/pbi-input.md`
- `docs/working/TASK-0038/plan.md`
- `docs/working/TASK-0038/todo.md`
- `docs/working/TASK-0038/test-cases.md`
- `docs/working/TASK-0038/review-self.md`
- Issue #109: <https://github.com/s977043/plangate/issues/109>
- 親 Epic #72: <https://github.com/s977043/plangate/issues/72>
- v7 hybrid: `docs/plangate-v7-hybrid.md`
- mode 分類: `.claude/rules/mode-classification.md`
