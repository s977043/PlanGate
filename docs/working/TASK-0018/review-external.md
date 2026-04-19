# TASK-0018 外部AIレビュー結果

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
| minor    | 0 |
| info     | 1 |

## 5観点スコア

| 観点 | スコア | 所感 |
|-----|-------|-----|
| 可読性 | 16/20 | 文書構造は揃っているが、`plugin 経由` の意味がテストで具体化されておらず判定条件がやや曖昧。 |
| 拡張性 | 15/20 | 親TASK-0016のハイブリッド方針は踏襲できているが、公開ドキュメント化の責務が TASK-0020 へ実質先送りになっている。 |
| パフォーマンス | 17/20 | 作業分解は概ね素直だが、曖昧な検証条件が残っており実装後の手戻りが発生しやすい。 |
| セキュリティ | 20/20 | 本計画範囲では機密情報や危険な入力処理は見当たらず、明確な懸念はない。 |
| 保守性 | 12/20 | 受入基準の一部が「ファイル差分確認」で代替されており、デュアル運用の実動保証としては弱い。 |

## PlanGate B-phase チェック (C1-PLAN-01〜07)

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | WARN | AC5/AC7/AC8 の検証が plan/todo/test で弱く、特に「plugin prefix 経由」「既存 `.claude/skills/` 側動作」「文書化先」が曖昧。 |
| C1-PLAN-02 | Unknowns処理 | WARN | 呼び出し syntax と `plugin.json` 登録方式が Questions に残る一方、完了条件へ十分に落ちていない。 |
| C1-PLAN-03 | スコープ制御 | PASS | 7 skills コピー、dual-run 維持、他 skill 非移植という境界は概ね守られている。 |
| C1-PLAN-04 | テスト戦略 | WARN | runtime のデュアル運用確認が不足し、主要 Unknown の解消が手順化し切れていない。 |
| C1-PLAN-05 | Work Breakdown Output | PASS | 各 Step に Output はあるが、Step 6 の成果物は受入基準の文書化先とずれている。 |
| C1-PLAN-06 | 依存関係 | PASS | TASK-0017 前提と TASK-0019/TASK-0020 後続は整理されている。 |
| C1-PLAN-07 | 動作検証自動化 | WARN | 自動コマンドは件数確認中心で、prefix 指定や legacy 側実動確認は手動前提のまま。 |

## 指摘事項

### Critical (0件)
なし

### Major (3件)
- **[保守性]** 受入基準「既存 `.claude/skills/` 側の動作が壊れていない」が、実行時確認ではなく「変更していないこと」の確認に置き換わっています。
  - 対象ファイル: `docs/working/TASK-0018/pbi-input.md:58`, `docs/working/TASK-0018/plan.md:71`, `docs/working/TASK-0018/todo.md:48`, `docs/working/TASK-0018/test-cases.md:62`
  - 改善案: `.claude/skills/working-context` など legacy 側を明示的に起動・確認するテストを追加し、`git diff` は補助確認に下げる。少なくとも「dual-run でも legacy 側を呼び分けられる/壊れていない」証跡を test-cases に入れる。
- **[可読性]** PBI が要求する `plangate:...` prefix 検証と Unknown の解消が、plan/todo/test-cases では「plugin 経由」の抽象表現に留まっており、何をもって plugin 側呼び出し成功と判定するか不明瞭です。
  - 対象ファイル: `docs/working/TASK-0018/pbi-input.md:35`, `docs/working/TASK-0018/pbi-input.md:109`, `docs/working/TASK-0018/plan.md:57`, `docs/working/TASK-0018/todo.md:57`, `docs/working/TASK-0018/test-cases.md:34`
  - 改善案: `plangate:working-context` / `plangate:ai-dev-workflow` / 残り5 skills の具体コマンド表記を固定し、期待結果に「plugin 側 skill が選択された証拠」を含める。syntax が別案に確定した場合は PBI/plan/test を同じ記法に更新する。
- **[拡張性]** 受入基準では「ハイブリッド方針の境界ルールを文書化」とされているのに、plan/todo/test-cases は `docs/working/TASK-0018/evidence/command-skill-boundary.md` を TASK-0020 の素材として残すだけで、実際の公開ドキュメント更新先がありません。
  - 対象ファイル: `docs/working/TASK-0018/pbi-input.md:38`, `docs/working/TASK-0018/pbi-input.md:59`, `docs/working/TASK-0018/plan.md:64`, `docs/working/TASK-0018/todo.md:69`, `docs/working/TASK-0018/test-cases.md:69`
  - 改善案: この TASK の成果物を「README/`docs/` を更新する」に変えるか、逆に PBI 側を「TASK-0020 向けの境界記録作成」に修正してスコープを揃える。現状のままだと AC8 を満たしたか判定できない。

### Minor (0件)
なし

### Info (1件)
- `TC-7` の入力例 `git diff --stat HEAD~N .claude/skills/` は `N` が未定義で、そのままでは再現不能です。major 1 を直す際にコマンド例も固定した方がよいです。
  - 対象ファイル: `docs/working/TASK-0018/test-cases.md:65`

## 推奨アクション

- [ ] plugin 側呼び出しの正式 syntax と成功判定条件を PBI/plan/todo/test-cases で統一する
- [ ] dual-run 下で legacy `.claude/skills/` 側が壊れていないことを runtime ベースで検証するテストを追加する
- [ ] 境界ルール文書化の成果物を `docs/` または plugin README に置くか、TASK-0018 の受入基準を実際のスコープに合わせて修正する

## 結論

全体として構成は揃っていますが、dual-run の実動保証と plugin prefix 検証、文書化成果物の置き先に重要な曖昧さが残っています。C-3 に進む前に上記3点を plan/todo/test-cases へ反映してから再確認するのが妥当です。

