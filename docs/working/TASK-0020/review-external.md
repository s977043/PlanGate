# TASK-0020 外部AIレビュー結果

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
| minor    | 2 |
| info     | 0 |

## 5観点スコア

| 観点 | スコア | 所感 |
|-----|-------|-----|
| 可読性 | 17/20 | 文書構成は明快だが、一部の in-scope 要件が Step / TC に落ち切っていない。 |
| 拡張性 | 14/20 | 依存関係の方向性は概ね妥当だが、C-3 ゲートと前提調査の接続が弱い。 |
| パフォーマンス | 15/20 | 作業量は light 相当で効率的だが、未処理 Unknowns により手戻り余地が残る。 |
| セキュリティ | 19/20 | 機密情報や危険な操作を伴う計画ではなく、明確な懸念は見当たらない。 |
| 保守性 | 15/20 | テスト方針は揃っているが、一部の検証コマンドが repo 前提と整合せず実行性が低い。 |

## PlanGate B-phase チェック (C1-PLAN-01〜07)

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | 9件の受入基準は plan / test-cases に対応付けられている。 |
| C1-PLAN-02 | Unknowns処理 | FAIL | `plugin` install syntax の Unknown が T-7 / E2E 検証前に解消される設計になっておらず、採用フィードバック Unknown も処理方針が落ちていない。 |
| C1-PLAN-03 | スコープ制御 | WARN | Root README の in-scope 詳細（同梱範囲、未同梱 agents の理由/入手方法）が Step / TC に明示されていない。 |
| C1-PLAN-04 | テスト戦略 | WARN | 観点は揃っているが、install syntax 未確定と未定義ツール依存で実行性が弱い。 |
| C1-PLAN-05 | Work Breakdown Output | WARN | Step 2 / Step 6 の Output が durable artifact ではなく、レビュー証跡として残りにくい。 |
| C1-PLAN-06 | 依存関係 | FAIL | C-3 人間ゲートと TASK-0017 調査結果への依存が `depends_on` に落ちていない。 |
| C1-PLAN-07 | 動作検証自動化 | FAIL | `markdown-link-check` 前提の自動検証が repo 既存コマンドと整合していない。 |

## 指摘事項

### Critical (0件)
なし

### Major (3件)
- **[拡張性/保守性]** 実装フェーズが C-3 ゲートに機械的に紐付いておらず、`depends_on` だけを見る実行器だと人間承認前に `T-5` へ進める構成です。
  - 対象ファイル: `docs/working/TASK-0020/todo.md:24-35`, `docs/working/TASK-0020/todo.md:113-124`
  - 改善案: `T-5` 以降を `depends_on: [C-3]` 相当に分離するか、pre-gate / post-gate を別セクションに切り出して Agent ↔ Human 依存を明示してください。
- **[可読性/保守性]** `plugin` install syntax が Unknown のまま `plugin/plangate/README.md` の執筆と E2E 検証に進む計画で、T-7 / TC-7 / TC-E5 が推測ベースになり得ます。
  - 対象ファイル: `docs/working/TASK-0020/pbi-input.md:124-128`, `docs/working/TASK-0020/plan.md:66-75`, `docs/working/TASK-0020/plan.md:122-125`, `docs/working/TASK-0020/todo.md:27-35`, `docs/working/TASK-0020/test-cases.md:73-82`, `docs/working/TASK-0020/test-cases.md:135-140`
  - 改善案: TASK-0017 の plugin 仕様調査/インストール検証の成果物を明示依存に追加し、syntax 確定を T-5 / T-7 の前提条件として固定してください。
- **[保守性]** 自動検証に `markdown-link-check` を置いていますが、この repo には package manager や汎用 `test` コマンド定義が無く、計画どおりの検証を再現できません。
  - 対象ファイル: `AGENTS.md:15-17`, `AGENTS.md:47-48`, `docs/working/TASK-0020/plan.md:106-110`, `docs/working/TASK-0020/test-cases.md:84-93`
  - 改善案: 既存スクリプトだけで実行できる確認手順に置き換えるか、完全に手動検証として定義し直してください。新規ツールを使うなら導入方法と実行前提を plan に明記してください。

### Minor (2件)
- **[可読性]** Root README の in-scope で要求している「同梱範囲の記載」「未同梱 agents の理由と入手方法」が Step 3 / T-5 / TC 群に明示されておらず、実装時に抜けやすいです。
  - 対象ファイル: `docs/working/TASK-0020/pbi-input.md:27-29`, `docs/working/TASK-0020/plan.md:48-52`, `docs/working/TASK-0020/todo.md:24-35`, `docs/working/TASK-0020/test-cases.md:28-44`
  - 改善案: Step 3 と TC-2 を分割し、README に載せるべき bundle / exclusion 情報を独立チェック項目化してください。
- **[保守性]** Step 2 / Step 6 の Output が成果物名ではなく作業説明に寄っており、後からレビュー根拠を追いにくいです。
  - 対象ファイル: `docs/working/TASK-0020/plan.md:36-41`, `docs/working/TASK-0020/plan.md:77-82`
  - 改善案: `evidence/...md` や「リンク検証結果一覧」など、残る出力名に置き換えてください。

### Info (0件)
なし

## 推奨アクション

- [ ] `todo.md` の実装タスクを C-3 承認後にしか進めない依存関係へ修正する
- [ ] `plugin` install syntax の確定元を TASK-0017 成果物に結び付け、T-7 / TC-7 / TC-E5 の前提条件にする
- [ ] 未定義の link checker 依存を除去し、repo 前提で再現可能な検証手順に置き換える

## 結論

文書の骨子自体は整理されていますが、PlanGate のゲート依存と検証実行性に穴があり、このままでは推測ベースのドキュメント執筆や承認前実装を招く可能性があります。上記 3 点を補強すれば、C-3 に回せる計画品質に近づきます。

