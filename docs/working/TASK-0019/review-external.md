# TASK-0019 外部AIレビュー結果

> 実施日: 2026-04-19
> レビュアー: Codex (codex-cli 0.115.0)
> 対象: pbi-input.md / plan.md / todo.md / test-cases.md

## 総合判定

**判定**: Human review recommended
**総合スコア**: 81/100

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
| 可読性 | 16/20 | 文書構造と受入基準マッピングは明快だが、一部の調査結果が別用途の evidence に混在する。 |
| 拡張性 | 15/20 | 親 TASK-0016 の中核 agents/rules 配布方針には沿っているが、plugin 内参照方式と bin 対象の決定が遅く、後工程で設計判断がぶれやすい。 |
| パフォーマンス | 17/20 | 作業分解は素直だが、Unknowns を実装直前まで持ち越しているため手戻りリスクが残る。 |
| セキュリティ | 19/20 | 文書上で機密情報や危険な操作は見当たらない。レビュー時点の懸念は主に工程管理と検証品質。 |
| 保守性 | 14/20 | テストケース網羅は良いが、C-3 ゲート依存と `.claude/` 非破壊確認の検証方法が不十分で再現性に欠ける。 |

## PlanGate B-phase チェック (C1-PLAN-01〜07)

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | 9件の受入基準は `plan.md` / `todo.md` / `test-cases.md` に一通り対応付けされている。 |
| C1-PLAN-02 | Unknowns処理 | WARN | `bin/` 対象スクリプトと plugin 内参照方式が Unknown のまま残っており、決定の証跡出力が不足している。 |
| C1-PLAN-03 | スコープ制御 | WARN | Out of scope は概ね維持されているが、`bin/` の具体リスト未確定のため過剰コピーの余地が残る。 |
| C1-PLAN-04 | テスト戦略 | WARN | 受入基準の対応はあるが、`.claude/` 非破壊確認と prefix 解決確認が再現可能な手順に落ち切っていない。 |
| C1-PLAN-05 | Work Breakdown Output | PASS | `plan.md` の各 Step には Output が設定されている。 |
| C1-PLAN-06 | 依存関係 | FAIL | `C-3` が注記にはあるが、実装フェーズ開始条件として `depends_on` に組み込まれていない。 |
| C1-PLAN-07 | 動作検証自動化 | WARN | 自動化コマンドはあるが、`HEAD~N` のような未確定引数を含み、そのままでは実行できない。 |

## 指摘事項

### Critical (0件)
なし

### Major (3件)
- **[保守性]** `C-3` 人間ゲートが実行依存として明示されておらず、TODO の依存解決だけを見ると `T-5` 以降の実装に進めてしまいます。
  - 対象ファイル: [docs/working/TASK-0019/pbi-input.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/pbi-input.md:138), [docs/working/TASK-0019/todo.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/todo.md:24), [docs/working/TASK-0019/todo.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/todo.md:119), [docs/working/TASK-0019/todo.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/todo.md:128)
  - 改善案: `C-3` を明示的な prerequisite task にし、少なくとも `T-5` を `depends_on: [T-4, C-3]` に変更するか、実装フェーズを「C-3 後」セクションへ分離してください。

- **[保守性]** `.claude/agents/` / `.claude/rules/` の非破壊確認テストが再現不能です。`todo.md` は作業ツリー差分のみを見ており、`test-cases.md` は `HEAD~N` という未定義プレースホルダを使っています。
  - 対象ファイル: [docs/working/TASK-0019/todo.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/todo.md:60), [docs/working/TASK-0019/test-cases.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/test-cases.md:73)
  - 改善案: 着手前に比較基準コミット SHA を記録するタスクを追加し、`git diff --stat <recorded-base> -- .claude/agents/ .claude/rules/` のように固定参照で検証してください。

- **[拡張性]** PBI の Unknowns にある「plugin 内 agent 参照方式」と「`bin/` に入れる具体スクリプト」が、plan/todo/test-cases でも未決のまま実装直前まで持ち越されています。現状の TC-9 は「1件以上存在」で通ってしまい、受入基準の意図より弱いです。
  - 対象ファイル: [docs/working/TASK-0019/pbi-input.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/pbi-input.md:113), [docs/working/TASK-0019/plan.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/plan.md:60), [docs/working/TASK-0019/plan.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/plan.md:138), [docs/working/TASK-0019/test-cases.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/test-cases.md:80), [docs/working/TASK-0019/test-cases.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/test-cases.md:96)
  - 改善案: `reference-resolution.md` と `script-inventory.md` のような決定ログを実装前に作成し、`T-8` / `T-9` / `T-10` の前提に加えてください。TC-9 は「具体ファイル名一致」、TC-6/TC-E2 は「期待する prefix/解決規則一致」まで固定した方が安全です。

### Minor (1件)
- **[可読性]** `T-3` の rules / scripts 依存調査結果を `agents-scan.md` に追記する設計だと、agent 固有前提スキャンと別テーマの証跡が混在します。
  - 対象ファイル: [docs/working/TASK-0019/todo.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/todo.md:15), [docs/working/TASK-0019/plan.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0019/plan.md:34)
  - 改善案: `dependency-scan.md` を分けるか、`agents-scan.md` の Output 定義に rules/scripts 依存調査を明示してください。

### Info (0件)
なし

## 推奨アクション

- [ ] `C-3` 承認を `T-5` 以降の明示的依存に組み込み、ゲート違反で実装が始まらない TODO に修正する
- [ ] `.claude/` 非破壊確認の基準コミットを固定し、`HEAD~N` を使わない再現可能な検証コマンドへ差し替える
- [ ] `bin/` 対象スクリプト一覧と plugin 内 agent/rules 参照方式を実装前に確定し、evidence とテスト期待値へ反映する

## 結論

文書全体の構成と受入基準マッピングは良好ですが、PlanGate のゲート制御と検証再現性に関わる重要な穴が残っています。特に `C-3` 依存と Unknowns の決定証跡を補強してから実装へ進むのが安全です。

