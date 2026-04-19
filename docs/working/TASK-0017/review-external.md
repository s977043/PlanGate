# TASK-0017 外部AIレビュー結果

> 実施日: 2026-04-19
> レビュアー: Codex (codex-cli 0.115.0)
> 対象: pbi-input.md / plan.md / todo.md / test-cases.md

## 総合判定

**判定**: Human review recommended
**総合スコア**: 82/100

## Severity 集計

| Severity | 件数 |
|----------|------|
| critical | 0 |
| major    | 4 |
| minor    | 2 |
| info     | 0 |

## 5観点スコア

| 観点 | スコア | 所感 |
|-----|-------|-----|
| 可読性 | 15/20 | 文書の骨格は揃っているが、Step 2 の checkpoint と TC-8 の記述が実行順序・再現性の面で分かりにくい。 |
| 拡張性 | 17/20 | 親 TASK-0016 からの段階分割は適切。ただし `C-3` ゲート依存が todo の機械可読な依存関係に落ちていない。 |
| パフォーマンス | 18/20 | 最小スケルトンに絞った計画で効率は良いが、検証不足のまま進むと後戻りが発生しやすい。 |
| セキュリティ | 20/20 | 機密情報や危険な hook 実装は計画外で、現時点のセキュリティ懸念は見当たらない。 |
| 保守性 | 12/20 | schema validation と settings defaults の受入条件が曖昧で、完了判定と後続レビューの再現性が弱い。 |

## PlanGate B-phase チェック (C1-PLAN-01〜07)

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | WARN | `plugin.json` の schema validation と `settings.json` の defaults 定義が plan/test-cases で十分に閉じていない。 |
| C1-PLAN-02 | Unknowns処理 | WARN | Unknowns は列挙されているが、`settings.json` の必須キーと schema validation 手段の着地条件が未具体化。 |
| C1-PLAN-03 | スコープ制御 | PASS | 親 TASK-0016 で後続 issue に回した skills/agents/rules 実体移植を持ち込まず、最小スケルトンに留めている。 |
| C1-PLAN-04 | テスト戦略 | FAIL | JSON parse を schema validation の代替にしており、`settings.json` の中身も検証されない。 |
| C1-PLAN-05 | Work Breakdown Output | WARN | Step 2 の checkpoint が Step 3/4 完了を前提にしており、Step 7 も保存先のないログ出力になっている。 |
| C1-PLAN-06 | 依存関係 | FAIL | `C-3` ゲート後にのみ実装着手と書かれている一方、T-4 以降の `depends_on` に human gate が入っていない。 |
| C1-PLAN-07 | 動作検証自動化 | WARN | JSON parse / diff 自動化はあるが、schema validation と install 検証の具体コマンドが不足している。 |

## 指摘事項

### Critical (0件)
なし

### Major (4件)
- **[保守性]** `plugin.json` の「スキーマ検証をパス」という受入基準が、実質的に JSON parse 成功へ置き換わっている。
  - 対象ファイル: `docs/working/TASK-0017/pbi-input.md:59`, `docs/working/TASK-0017/plan.md:94-101`, `docs/working/TASK-0017/test-cases.md:10-16`, `docs/working/TASK-0017/test-cases.md:27-32`
  - 改善案: Step 1 の調査成果に「どの schema / validator / 公式手順で検証するか」を明記し、JSON valid とは別に schema validation 専用のテストケースを追加する。

- **[保守性]** `settings.json` の「デフォルト設定が定義されている」が未定義のままで、空オブジェクトでもテストを通せてしまう。
  - 対象ファイル: `docs/working/TASK-0017/pbi-input.md:56`, `docs/working/TASK-0017/pbi-input.md:111`, `docs/working/TASK-0017/plan.md:49-55`, `docs/working/TASK-0017/plan.md:114`, `docs/working/TASK-0017/test-cases.md:52-57`
  - 改善案: Step 1 で必須キーと初期値を列挙し、TC-5 を「存在 + JSON valid」ではなく「期待キー/値が入っている」検証へ変更する。

- **[保守性]** Step 2 の checkpoint が Step 3/4 で作るファイルの存在まで要求しており、Work Breakdown が自己矛盾している。
  - 対象ファイル: `docs/working/TASK-0017/plan.md:35-40`
  - 改善案: Step 2 は `plugin/plangate/` と 5 サブディレクトリ作成の確認だけに絞り、`plugin.json` / `settings.json` / `README.md` の確認は Step 4 以降へ移す。

- **[拡張性]** `C-3` ゲート後のみ実装開始というルールが `depends_on` に反映されておらず、todo の機械可読な依存関係だけを見ると実装着手を止められない。
  - 対象ファイル: `docs/working/TASK-0017/todo.md:21-32`, `docs/working/TASK-0017/todo.md:101-112`
  - 改善案: T-4 を `depends_on: [C-3, T-3]` にするなど、実装フェーズ先頭タスクへ human gate を明示的に入れる。

### Minor (2件)
- **[保守性]** Step 7 の Output が「差分確認ログ」だけで、証跡の保存先が定義されていない。
  - 対象ファイル: `docs/working/TASK-0017/plan.md:70-75`
  - 改善案: `docs/working/TASK-0017/evidence/non-destructive-check.md` のように保存先を固定する。

- **[可読性]** TC-8 の `HEAD~N` は N が未定義で、第三者が同じ条件で再実行できない。
  - 対象ファイル: `docs/working/TASK-0017/test-cases.md:75-77`
  - 改善案: `git diff --stat -- .claude/` のような現在差分確認へ寄せるか、開始時点の commit SHA を evidence に記録して比較対象を固定する。

### Info (0件)
なし

## 推奨アクション

- [ ] Step 1 の調査成果に schema validation 手段と `settings.json` 必須キー一覧を追加し、plan/test-cases に反映する
- [ ] Step 2 の checkpoint と Step 7 の Output を修正し、各 step の完了条件を自己完結にする
- [ ] `todo.md` の実装フェーズ先頭へ `C-3` human gate の明示的依存関係を追加してから人間レビューへ回す

## 結論

親 TASK-0016 から「最小スケルトン」に切り出す方針自体は妥当で、スコープも概ね制御できています。  
ただし、schema validation・settings defaults・C-3 gate dependency の3点は完了判定を誤らせるので、文書修正後に C-3 へ進めるのが安全です。

