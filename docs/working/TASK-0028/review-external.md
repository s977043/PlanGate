# TASK-0028 外部AIレビュー結果

> 実施日: 2026-04-19
> レビュアー: Codex (codex-cli 0.115.0)
> 対象: pbi-input.md / plan.md / todo.md / test-cases.md

## 総合判定

**判定**: Human review recommended
**総合スコア**: 78/100

## Severity 集計

| Severity | 件数 |
|----------|------|
| critical | 0 |
| major    | 3 |
| minor    | 1 |
| info     | 0 |

## 5観点スコア

| 観点 | スコア | 所感 |
|-----|-------|-----|
| 可読性 | 16/20 | 各文書の章立ては明快だが、plan/todo/test-cases 間で「何をいつ検証するか」の対応が一部ずれている。 |
| 拡張性 | 14/20 | 本 TASK 単体で閉じるはずの計画に #23-#27 への仮参照要件を持ち込み、サブ issue 間の結合が強くなっている。 |
| パフォーマンス | 16/20 | light 相当の文書作業としては効率的だが、未完了 sibling task への仮参照を必須化すると手戻りが増える。 |
| セキュリティ | 19/20 | 文書計画として機密情報や危険な操作は含まれず、顕著なセキュリティ懸念はない。 |
| 保守性 | 13/20 | C-1/C-2/C-3 のゲート順序と todo の実行順が噛み合っておらず、受入基準の一部もテストで担保し切れていない。 |

## PlanGate B-phase チェック (C1-PLAN-01〜07)

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | WARN | AC「v5/v6 との整合（差分・位置付け）」に対し、TC-5 は既存文書から v7 への導線確認しかしておらず、差分・位置付けの記述自体を検証していない。 |
| C1-PLAN-02 | Unknowns処理 | PASS | PBI の Unknowns（ファイル名、rules 配置先）は plan で実質確定されている。 |
| C1-PLAN-03 | スコープ制御 | WARN | plan/test-cases が #23-#27 成果物への仮参照を要求しており、PBI の並行実施前提より踏み込みが強い。 |
| C1-PLAN-04 | テスト戦略 | WARN | 主要 AC の一部がテストに落ち切っておらず、TC-4 は実行コマンドではなく目視確認のまま残っている。 |
| C1-PLAN-05 | Work Breakdown Output | PASS | plan の各 Step に Output が明記されている。 |
| C1-PLAN-06 | 依存関係 | WARN | #23-#27 は「並行可能」とされている一方で、plan/test-cases が仮参照を追加し、todo には対応タスクもない。 |
| C1-PLAN-07 | 動作検証自動化 | WARN | grep ベースの自動確認はあるが、接続表と v5/v6 差分の検証が部分的に手動のまま。 |

## 指摘事項

### Critical (0件)
なし

### Major (3件)
- **[保守性]** `todo.md` が C-1 セルフレビューを exec 後の agent タスクとして配置しており、PlanGate のレビューゲート順序と衝突している。
  - 対象ファイル: docs/working/TASK-0028/todo.md:32, docs/working/TASK-0028/todo.md:34
  - 改善案: `todo.md` から `/self-review` タスクを外し、C-1/C-2 は `review-self.md` / `review-external.md` 側で完了させる前提にそろえる。exec 用 TODO には C-3 承認後の実装・検証タスクだけを残す。

- **[保守性]** 受入基準「既存 v5/v6 との整合（差分・位置付け）」が plan/test-cases で十分に検証されていない。
  - 対象ファイル: docs/working/TASK-0028/pbi-input.md:70, docs/working/TASK-0028/plan.md:39, docs/working/TASK-0028/plan.md:45, docs/working/TASK-0028/test-cases.md:44, docs/working/TASK-0028/test-cases.md:49
  - 改善案: `docs/plangate-v7-hybrid.md` に「v5/v6 との差分・位置付け」節を必須セクションとして明示し、その節の存在と主要キーワードを検証する TC を追加する。

- **[拡張性]** plan/test-cases が #23-#27 成果物への仮参照を必須化しており、PBI の「#23-#27 と並行可能」という依存前提に不要な結合を追加している。
  - 対象ファイル: docs/working/TASK-0028/pbi-input.md:58, docs/working/TASK-0028/pbi-input.md:117, docs/working/TASK-0028/plan.md:23, docs/working/TASK-0028/plan.md:61, docs/working/TASK-0028/test-cases.md:64
  - 改善案: #23-#27 への言及は issue 番号レベルの参考記述にとどめ、未完了成果物への仮リンクを完成条件やテスト条件から外す。残す場合は `todo.md` にも対応タスクと非ブロッキング条件を明記する。

### Minor (1件)
- **[パフォーマンス]** 接続表の確認が TC-4 だけ目視前提で、Verification Automation の粒度がそろっていない。
  - 対象ファイル: docs/working/TASK-0028/plan.md:78, docs/working/TASK-0028/test-cases.md:36
  - 改善案: `grep -E "GATE|STATUS|APPROVAL|ARTIFACT|Workflow|Skill|Agent"` のような機械確認コマンドを追加し、TC-4 を自動化寄りに寄せる。

### Info (0件)
なし

## 推奨アクション

- [ ] `todo.md` から C-1 相当タスクを除去し、review artifact と exec TODO の境界を整理する
- [ ] `docs/plangate-v7-hybrid.md` の「v5/v6 との差分・位置付け」を検証する TC とチェックポイントを追加する
- [ ] #23-#27 への仮参照を完成条件から外すか、非ブロッキング前提を plan/todo/test-cases で明文化する
- [ ] 接続表の確認コマンドを追加して Verification Automation を補強する

## 結論

主要な論点は、レビューゲート順序の混線、受入基準の一部未検証、そして sibling task への不要な結合です。文書の骨格は整っていますが、この 3 点を直してから C-3 に進めるのが安全です。

