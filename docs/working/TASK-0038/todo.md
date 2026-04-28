# EXECUTION TODO — TASK-0038

> 関連 Issue: [#109](https://github.com/s977043/plangate/issues/109)
> モード: high-risk

## 凡例

- 🤖 Agent タスク（claude が実行）
- 👤 Human タスク（人間が実行）
- 🚩 チェックポイント（次フェーズに進む前に確認）

## Phase A: 準備

- [x] 🤖 working context 作成（`docs/working/TASK-0038/`）
- [x] 🤖 ブランチ作成（`feat/task-0038-parent-child-pbi`）
- [x] 🤖 pbi-input.md 作成（Issue #109 から整形）
- [x] 🤖 plan.md 生成
- [x] 🤖 todo.md 生成（本ファイル）
- [x] 🤖 test-cases.md 生成
- [ ] 🤖 review-self.md 生成（C-1, 17 項目）
- [ ] 🚩 **C-3 ゲート**: 👤 人間による plan / todo / test-cases / review-self レビュー
  - 判定: APPROVE / CONDITIONAL / REJECT
  - 結果は status.md と `approvals/c3.json` に記録

## Phase B: 仕様策定（exec, C-3 APPROVE 後に開始）

depends_on: C-3 APPROVE

### B-1. アーキテクチャ正本作成

- [ ] 🤖 `docs/orchestrator-mode.md` の骨子作成（必須セクション: 概要 / Parent-Child モデル / 分解フロー / Sub Agent / Gate 条件 / 既存アーキとの責務境界 / 参照）
- [ ] 🤖 既存 v7 hybrid 5 Agent との責務境界表を埋める
- [ ] 🚩 既存 `.claude/agents/orchestrator.md` 等との重複が解消されているか
- [ ] AC カバー: AC-1 / AC-7 / AC-8 / AC-9

### B-2. スキーマ定義

- [ ] 🤖 `docs/schemas/child-pbi.yaml` 作成（id / parent_id / scope / dependencies / allowed_files / forbidden_files / acceptance_criteria / required_checks / pr_strategy + 説明コメント）
- [ ] 🤖 `python3 -c "import yaml; yaml.safe_load(open(...))"` で構文検証
- [ ] 🚩 `forbidden_files` が glob で表現できているか
- [ ] AC カバー: AC-2

### B-3. 分解フロー Workflow

- [ ] 🤖 `docs/workflows/orchestrator-decomposition.md` 作成（状態遷移図、各状態の入出力 / 完了条件、Sub Agent 割当、Gate 挿入位置）
- [ ] 🚩 PlanGate C-3 / C-4 ゲートとの対応図が含まれているか
- [ ] AC カバー: AC-7 / AC-9

### B-4. 統合 Workflow

- [ ] 🤖 `docs/workflows/orchestrator-integration.md` 作成（親 PBI 完了判定フロー、統合チェック、Integration Agent 責務、ParentDone 不変条件運用）
- [ ] 🚩 カバレッジ未達時の差し戻し条件が記述されているか
- [ ] AC カバー: AC-8 / AC-9

### B-5. テンプレート 4 種

- [ ] 🤖 `docs/working/templates/parent-plan.md` 作成（必須セクション: Goal / Children / Integration Plan / Risk / Gates）
- [ ] 🤖 `docs/working/templates/dependency-graph.md` 作成（mermaid graph フォーマット + 凡例）
- [ ] 🤖 `docs/working/templates/parallelization-plan.md` 作成（並行可能 / 不可テーブル + 判定根拠）
- [ ] 🤖 `docs/working/templates/integration-plan.md` 作成（統合チェックリスト + 完了条件）
- [ ] 🚩 4 テンプレートの用語が `docs/orchestrator-mode.md` と一致しているか
- [ ] AC カバー: AC-4 / AC-6

### B-6. Rule 正本

- [ ] 🤖 `.claude/rules/orchestrator-mode.md` 作成（Gate 条件の機械可読定義 + アーキ正本リンク）
- [ ] 🤖 既存 `mode-classification.md` との関係を明記
- [ ] 🚩 アーキ正本リンクのみで内容が一意に定まるか
- [ ] AC カバー: AC-9

### B-7. CLI RFC

- [ ] 🤖 `docs/rfc/plangate-decompose.md` 作成（Status: Draft、入出力、フラグ、期待動作、実装フェーズ提案）
- [ ] 🤖 ローカル決定論 / 外部 LLM 補助の 2 案を併記
- [ ] 🚩 `Status: Draft` で、実装は別 PBI と明記されているか
- [ ] AC カバー: AC-3 / AC-5

### B-8. PR 戦略の追記

- [ ] 🤖 `pr_strategy` フィールド仕様を schema + RFC に統合
- [ ] 🚩 既存 `release-manager` との重複・競合がレビュー済みか
- [ ] AC カバー: AC-5

### B-9. README / index 更新

- [ ] 🤖 `README.md` Read Next 表に `docs/orchestrator-mode.md` 追加
- [ ] 🤖 `README_en.md` 同等更新
- [ ] 🤖 `docs/index.md` に新規 9 ファイルへのリンク追加
- [ ] 🤖 `docs/workflows/README.md` に orchestrator-decomposition / integration リンク追加
- [ ] 🚩 全 9 ファイルが entry-point から到達可能か

### B-10. 検証スクリプト

- [ ] 🤖 `scripts/check-orchestrator-docs.sh` 作成（9 ファイル存在 + 必須セクション grep）
- [ ] 🤖 ローカルで実行し全件 PASS を確認

## Phase C: 検証（全 B 完了後）

- [ ] 🤖 `scripts/check-orchestrator-docs.sh` 実行 → 全件 PASS
- [ ] 🤖 `test-cases.md` の AC ↔ 文書セクション対応表を全件 PASS で更新
- [ ] 🤖 status.md 更新（V-1 結果記録）

## Phase D: 完了処理

- [ ] 🤖 handoff.md 生成（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ / テスト結果）
- [ ] 🤖 PR 作成（base: main / `Closes #109` / Test plan 含む）
- [ ] 🚩 **C-4 ゲート**: 👤 GitHub PR レビュー
  - APPROVE → squash merge → Done
  - REQUEST CHANGES → exec へ戻る

## 依存関係

```text
A (準備) → C-3 (gate) → B-1 → B-2 → B-3 → B-4 → B-5 → B-6 → B-7 → B-8 → B-9 → B-10 → C → D → C-4 (gate) → Done
                                                                                    ↑
                                                                  並列化可: B-3/B-4, B-5 内部 4 ファイル
```

- B-2 〜 B-9 は B-1（アーキ正本）に depends_on（用語統一のため）
- B-3 と B-4 は並列実行可
- B-5 の 4 テンプレートは並列実行可
- B-10（検証スクリプト）は B-9 完了後に実行

## Iron Law

| Phase | Iron Law |
|-------|---------|
| A | `NO EXECUTION WITHOUT REVIEWED PLAN FIRST` |
| B | `NO SCOPE CHANGE WITHOUT USER APPROVAL`（new child PBI 提案は再承認必須）|
| C | `NO MERGE WITHOUT VERIFICATION PASSED` |
| D | `NO HANDOFF WITHOUT KNOWN-ISSUES LOGGED` |

## 完了条件

- 受入基準 9 項目すべて PASS
- `scripts/check-orchestrator-docs.sh` 全件 PASS
- handoff.md 必須 6 要素を満たす
- C-4 ゲート APPROVE
