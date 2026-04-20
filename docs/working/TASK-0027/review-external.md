# TASK-0027 外部AIレビュー結果

> 実施日: 2026-04-19
> レビュアー: Codex (codex-cli 0.115.0)
> 対象: pbi-input.md / plan.md / todo.md / test-cases.md

## 総合判定

**判定**: Human review recommended
**総合スコア**: 80/100

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
| 可読性 | 15/20 | 全体の骨格は追いやすいが、`todo.md` の human gate が粗く、承認完了条件が読み取りにくい。 |
| 拡張性 | 14/20 | WF-05 深化の観点は整理されている一方、親チケットが要求する「標準 phase の共通契約」を維持するチェックが抜けている。 |
| パフォーマンス | 16/20 | 作業量は light 相当で妥当。ただし検証が目視寄りで、実行効率と再現性を少し落としている。 |
| セキュリティ | 20/20 | 機密情報や危険な操作を増やす計画は見当たらず、ドキュメント計画として問題なし。 |
| 保守性 | 15/20 | 受入基準ベースの骨格はあるが、Unknown の処理漏れとゲートタスクの粒度不足が後続運用で効く。 |

## PlanGate B-phase チェック (C1-PLAN-01〜07)

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | WARN | TASK-0027 の 6 AC は概ね対応しているが、AC1「標準 phase として深化」を親チケット整合まで落とし込めていない。 |
| C1-PLAN-02 | Unknowns処理 | FAIL | `handoff.md` の命名規約を「テンプレに記載」とした Unknown が、タスク/TC に落ちていない。 |
| C1-PLAN-03 | スコープ制御 | PASS | handoff 自動生成や他 phase 深化には踏み込んでいない。 |
| C1-PLAN-04 | テスト戦略 | WARN | 6 要素や V-1 関係は見ているが、標準 phase 契約と命名規約の検証が抜けている。 |
| C1-PLAN-05 | Work Breakdown Output | PASS | 各 Step に Output / Owner / Risk があり、概ね具体的。 |
| C1-PLAN-06 | 依存関係 | PASS | `#23 / #24 / #25` 依存は明記されている。 |
| C1-PLAN-07 | 動作検証自動化 | WARN | `grep` ベースの自動確認は一部あるが、主要な内容確認が目視前提のまま。 |

## 指摘事項

### Critical (0件)
なし

### Major (3件)
- **[拡張性]** WF-05 を「標準 phase」として保つための共通契約が、作業項目にもテストにも落ちていません。親チケットでは phase ごとに「目的／入力／完了条件／呼び出しSkill／主担当Agent」を持つことが全体受入基準ですが、TASK-0027 側は 6 要素・Skill 連携・V-1 関係の追加確認に寄っており、WF-05 深化の結果として phase テンプレートを崩しても検知できません。
  - 対象ファイル: `docs/working/TASK-0021/pbi-input.md:148-156`, `docs/working/TASK-0023/plan.md:40,79-82`, `docs/working/TASK-0027/plan.md:19-23,40-66`, `docs/working/TASK-0027/test-cases.md:20-22,42-58`
  - 改善案: `plan.md` に「WF-05 が共通 phase テンプレートを維持する」Step/チェックポイントを追加し、`test-cases.md` に目的・入力・完了条件・呼び出しSkill・主担当Agent の存在確認 TC を追加する。

- **[保守性]** PBI が Unknown として挙げた「`handoff.md` の命名規約をテンプレに記載」が未処理です。`plan.md` では固定パスを決めていますが、その決定をどの成果物に反映するかが未定義で、`todo.md` と `test-cases.md` にも確認項目がありません。
  - 対象ファイル: `docs/working/TASK-0027/pbi-input.md:88-90`, `docs/working/TASK-0027/plan.md:33-38,95-99`, `docs/working/TASK-0027/todo.md:18-30`, `docs/working/TASK-0027/test-cases.md:24-68`
  - 改善案: Step 2 か Step 3 の checkpoint に「`docs/working/TASK-XXXX/handoff.md` 固定であることをテンプレまたは WF-05 文書に明記」を追加し、対応する TC を 1 件増やす。

- **[可読性]** `todo.md` の human task が `C-3 / C-4` の 1 行だけで、Owner・チェックポイント・依存の情報が不足しています。プロジェクトルール上、human タスクも gate 条件を持つべきで、現状だと「何を確認したら C-3 完了なのか」「C-4 で何を渡すのか」が TODO だけでは判断できません。
  - 対象ファイル: `docs/working/TASK-0027/todo.md:54-60`, `.claude/rules/working-context.md:115-119,206-220`
  - 改善案: `C-3: review-self/review-external を確認して APPROVE|CONDITIONAL|REJECT を決める`、`C-4: PR 上で最終レビュー` の 2 タスクに分け、Owner と checkpoint を明記する。

### Minor (1件)
- **[パフォーマンス]** 検証コマンドが部分的で、TC-1/3/4/6 は実質的に目視確認です。ドキュメント案件でも `rg` ベースで見出しやキーワードを機械確認できる箇所は自動化した方が再レビューコストを下げられます。
  - 対象ファイル: `docs/working/TASK-0027/plan.md:78-85`, `docs/working/TASK-0027/test-cases.md:18-58`
  - 改善案: phase 契約や V-1/handoff の文言に対して `rg` コマンド例を追加し、Verification Automation を増やす。

### Info (0件)
なし

## 推奨アクション

- [ ] WF-05 共通契約（目的 / 入力 / 完了条件 / 呼び出しSkill / 主担当Agent）を確認する Step と TC を追加する
- [ ] `handoff.md` 命名規約をどの成果物に書くか明示し、その確認項目を `todo.md` / `test-cases.md` に追加する
- [ ] `todo.md` の human gate を C-3 と C-4 に分解し、Owner / checkpoint / 判定条件を記載する
- [ ] 目視前提の TC を `rg` / `grep` ベースの検証コマンドで補強する

## 結論

計画の骨格自体は成立していますが、WF-05 を「標準 phase」として維持する観点と、Unknown の処理完了条件がまだ弱いです。C-3 へ進める前に上記 3 点を詰めた方が、親チケット整合と運用の再現性が上がります。

