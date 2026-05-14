# 外部ユーザー視点ラウンド: OSS 利用者・チーム導入視点での自己進化設計再評価

- 日時: 2026-05-15
- 主題: 1 人運用前提で進めてきた自己進化設計を、OSS 利用者・チーム導入視点で批判的に再評価する
- 参加者: Claude Code（Opus 4.7）/ Codex CLI
- 前提ログ:
  - `2026-05-14-steering-loop-codex.md`
  - `2026-05-14-self-evolution-codex.md`
  - `2026-05-14-self-evolution-gemini.md`
  - `2026-05-14-devils-advocate-codex.md`

## Claude のプロンプト（要旨）
これまで全議論が 1 人運用前提だったことを認め、外部ユーザー視点で 5 つの問いを投げた:
- Q1: 新規 OSS 利用者の摩擦点・離脱ポイント
- Q2: チーム導入（3〜10 人）で破綻する箇所
- Q3: OSS 価値貢献 vs 作者個人最適化の判別
- Q4: Docs / onboarding が v8.7.0 で追いつくか
- Q5: 自己進化より優先すべき OSS 整備項目（#224 plugin / #225 versioning / #226 段階導入ガイド / #191 認知獲得との比較）

## Codex の回答全文

## Q1. 新規 OSS 利用者の摩擦点

**結論/推奨: 最大の離脱点は「install 直後」ではなく、最初の TASK で `docs/working/TASK-XXXX/`、C-3、handoff、metrics、eval が一気に見えた瞬間。v8.7.0 の自己進化機能は quickstart から隠し、まず “optional after-run review” として段階導入すべき。**

具体的な摩擦点は以下。

1. **概念量が多い**
   新規利用者は「AI に実装させる前に plan を承認する」だけなら理解できる。だが Trace Timeline / Outcome Review / Eval が同時に出ると、PlanGate が “開発補助” ではなく “運用監査基盤” に見える。最初の離脱はここ。

2. **Markdown 中心は良くも悪くも強い**
   良い点は、外部 store や SaaS なしで読める、git diff に乗る、導入が軽いこと。悪い点は、成果物が多いほど「どれを読めばいいのか」が不明になること。外部利用者には、Markdown 中心そのものより **Markdown の入口順が見えないこと** が重い。

3. **日本語ドキュメントは実害があるが、全面英訳が先ではない**
   OSS 利用者にとって README_en があるだけでは不十分。実際に詰まるのは README より、plugin 登録、quickstart、最小 TASK 例、troubleshooting、release compatibility。まず英訳すべきは思想文書ではなく、導入経路と失敗回復経路。

4. **自己進化という名前が過大に見える**
   外部ユーザーは “self-evolution” より “run review” “timeline” “regression check” の方が理解しやすい。自己進化を前面に出すと、作者の研究テーマに見える。機能名は実務語彙に寄せた方がよい。

推奨は、v8.7.0 では外部向けにこう見せること。

- 初回: `working-context` → `plan` → `exec` → `handoff`
- 任意: `bin/plangate metrics --report`
- 任意: `run-outcome-review.md` を 5 項目だけ記入
- Trace Timeline は “debug / audit view” 扱いで quickstart には出さない

## Q2. チーム導入時の破綻箇所

**結論/推奨: 現設計は 3〜10 人チームでは `ownership` と `merge protocol` が未定義な箇所から破綻する。自己進化機能をチーム向けに出すなら、機能追加より先に責任境界を明文化すべき。**

破綻箇所は具体的にこれ。

1. **Outcome Review の競合**
   1 run に 1 ファイルだと、実装者、レビュアー、PM が同じ `outcome-review.md` を編集して競合する。さらに「誰の評価が正」とするかが決まらない。  
   推奨: `outcome-review.md` は owner 1 名が集約。複数人入力は `reviews/outcome/<user>.md` かコメント断片に分離し、最終版だけ統合。

2. **events.ndjson の共有**
   現状の `docs/working/_metrics/events.ndjson` は public repo に commit 禁止の設計なので、チーム共有ログには向かない。個人ローカルに置くと横断分析できず、repo commit すると privacy 方針と衝突する。  
   推奨: v8.7.0 では共有 store を作らない。チーム対応は `events.ndjson` を個人ローカル、成果だけ `metrics-summary.md` または `outcome-review.md` に転記、で止める。外部 store は v8.8 以降。

3. **handoff.md の作成責任**
   1 人運用なら最後に作者が書けばよい。チームでは「実装者が書くのか、QA が確定するのか、レビュアーが承認するのか」が曖昧になる。  
   推奨: handoff owner は実装 owner。C-4 前に reviewer が確認。merge 後の追記は禁止または別ファイルにする。

4. **Skill / Playbook の所有権**
   チーム導入で一番危険なのは、各メンバーが便利だからと skill を直接変えること。自己進化が “勝手に skill を改善する文化” に見えると、品質が崩れる。  
   推奨: skill/playbook 更新は通常 PR と同じ扱いにし、owner 承認必須。Outcome Review は改善候補を出すだけで、直接反映しない。

5. **Mode 判定の揺らぎ**
   人によって light / standard / high-risk の判断がズレると、必要 artifact と review gate が変わる。これはチーム導入で確実に揉める。  
   推奨: Mode 判定の decision table と例外集を先に整備する。自己進化機能で mode を賢くするより、まず人間間の判定を揃える方が先。

## Q3. OSS 価値 vs 作者個人最適化

**結論/推奨: Trace Timeline 単体は作者個人最適化に寄りやすい。Outcome Review と Eval は、表現を絞れば OSS 価値になり得る。v8.7.0 は “Trace Timeline を主役にしない” 方がよい。**

分類するとこう。

| 機能 | OSS としての価値 | 個人最適化リスク | 判断 |
| --- | --- | --- | --- |
| Trace Timeline | 監査・再現・debug に効く | イベント粒度が作者の運用に最適化されやすい | 補助機能に格下げ |
| Run Outcome Review | チームでも個人でも振り返り型として使える | 項目が多いと作者メモ化する | v8.7.0 の主役にしてよい |
| Dogfooding Eval | ハーネス変更の退行検知に効く | 評価ケースが作者 repo だけだと閉じる | v8.8.0 で最小公開価値あり |
| events.ndjson 拡張 | 自動分析の材料 | privacy / store / schema 互換の負債が重い | 最小 additive のみ |
| 自動学習 / skill 更新 | 将来価値はある | OSS では危険に見える | 延期 |

外部利用者にとっての本当の価値は、「PlanGate 作者の作業を改善すること」ではない。次の 3 つ。

- 自分の AI 開発 run がなぜ失敗したかを後で説明できる
- チームで plan / review / handoff の品質を揃えられる
- PlanGate 自体の更新で既存運用が壊れないと判断できる

この観点では、v8.7.0 の価値ある最小単位は **Outcome Review template + metrics summary + optional timeline**。Trace Timeline を前面に出すと、OSS 機能ではなく作者の観測趣味に見えやすい。

撤回・延期すべきものは、自動学習、multi-judge、OTel 準拠、token/cost 必須化。外部 OSS 価値より維持費が勝つ。

## Q4. Docs / Onboarding は v8.7.0 で追いつくか

**結論/推奨: Option B をそのまま v8.7.0 に入れると docs は追いつかない。2〜4 週なら、外部向け docs は “Outcome Review を任意追加” に絞れば間に合う。Trace Timeline を quickstart に載せる余裕はない。**

更新必須 docs は以下。

1. **README.md**
   最新状態に v8.7.0 の位置づけを追加。ただし quickstart 本線には入れない。  
   追加するなら「実行後に振り返りを残す optional step」程度。

2. **README_en.md**
   外部 OSS 利用者向けには日本語 README より重要。v8.7.0 で日本語だけ更新すると、外部視点では機能が存在しないのと同じ。

3. **plugin/plangate/README.md**
   plugin 形式で使う人が最初に見る。Outcome Review / Timeline の追加コマンドや生成 artifact があるならここに最小説明が必要。

4. **docs/plangate.md**
   ワークフロー詳細側で、WF-05 後の任意 artifact として `run-outcome-review.md` を説明する。

5. **docs/working/templates/**
   `outcome-review.md` テンプレートが必須。既存 `handoff.md` と役割が重複しないように、「handoff = 引き継ぎ」「outcome review = run 改善学習」と明記する。

6. **TROUBLESHOOTING.md**
   metrics / timeline / plugin 解決 / events.ndjson が見つからないケースを追加する。外部利用者はここで救えるかが大きい。

7. **docs/plangate-plugin-migration.md**
   既存 v8.6.0 利用者向けに、追加 artifact が必須か任意か、既存 `.claude/` コピー運用で何を更新すべきかを書く。

v8.6.0 利用者の移行コストは、Outcome Review を任意にすれば低い。必須 artifact にすると高い。Trace Timeline を schema 変更込みで必須導線にすると、2〜4 週では docs と実装の整合が崩れる。

推奨する v8.7.0 の外部向け表現はこれ。

- 必須変更: なし
- 任意追加: `run-outcome-review.md`
- 既存 metrics: 互換維持
- Timeline: debug / audit 用 experimental
- schema 1.1: additive、既存 reader を壊さない

## Q5. 自己進化より優先すべき OSS 整備項目

**結論/推奨: 外部ユーザー視点を本気で重視するなら、v8.7.0 の最優先 3 件は #226、#224、#225。自己進化は “Outcome Review 最小版” まで縮小し、Trace Timeline はその補助に落とすべき。**

優先順位は以下。

1. **#226 段階的導入ガイド**
   これが最優先。理由は、PlanGate の最大摩擦が機能不足ではなく「どこまで使えばよいか分からないこと」だから。  
   外部利用者には、いきなり full governance ではなく、次の導入段階が必要。

   - Level 1: plan 承認だけ
   - Level 2: handoff まで
   - Level 3: hooks / validate
   - Level 4: metrics / outcome review
   - Level 5: eval / timeline

   自己進化機能は Level 4 以降に置くべきで、初回導線に混ぜるべきではない。

2. **#224 Plugin 形式の成熟化**
   OSS として使われるには、機能の思想より配布の確実性が先。現状は clone + plugin 登録または `.claude/` コピーで、手動運用の匂いが強い。  
   外部利用者は「これを自分の repo に入れて壊れないか」を先に見る。plugin 解決順、prefix、更新手順、二重 install の回避が曖昧だと、自己進化以前に導入されない。

3. **#225 バージョニング安定性ポリシー**
   自己進化機能は schema、artifact、workflow、skill を動かす。だからこそ、何が breaking change で、何が additive で、既存 TASK artifact をどう扱うかを先に固定する必要がある。  
   後方互換重視を掲げるなら、v8.7.0 の Trace Timeline / Outcome Review はこのポリシーなしに強く出すべきではない。

#191 認知獲得計画は重要だが、上位 3 件ではない。理由は、導入摩擦が高いまま認知を増やすと、第一印象で落ちるから。まず “入れて試せる” 状態を作る方が先。

最終判断としては、v8.7.0 はこう組み替えるのが現実的。

- 主: #226 段階的導入ガイド
- 主: #224 plugin 成熟化の最低限
- 主: #225 互換性ポリシーの最低限
- 副: Run Outcome Review v1
- 実験: Trace Timeline v1 は optional / experimental
- 延期: Dogfooding Eval v1 は v8.8.0、ただし外部 fixture を意識して設計

忖度なしで言うと、今のまま “自己進化” を v8.7.0 の顔にすると、OSS 利用者には刺さりにくい。PlanGate の OSS 価値は「AI 開発の安全な型を配布すること」であって、「作者の運用ログを高度化すること」ではない。自己進化は残してよいが、外部向けには **段階導入・配布安定・互換性保証の上に乗る optional advanced feature** として扱うべき。
## Q1. 新規 OSS 利用者の摩擦点

**結論/推奨: 最大の離脱点は「install 直後」ではなく、最初の TASK で `docs/working/TASK-XXXX/`、C-3、handoff、metrics、eval が一気に見えた瞬間。v8.7.0 の自己進化機能は quickstart から隠し、まず “optional after-run review” として段階導入すべき。**

具体的な摩擦点は以下。

1. **概念量が多い**
   新規利用者は「AI に実装させる前に plan を承認する」だけなら理解できる。だが Trace Timeline / Outcome Review / Eval が同時に出ると、PlanGate が “開発補助” ではなく “運用監査基盤” に見える。最初の離脱はここ。

2. **Markdown 中心は良くも悪くも強い**
   良い点は、外部 store や SaaS なしで読める、git diff に乗る、導入が軽いこと。悪い点は、成果物が多いほど「どれを読めばいいのか」が不明になること。外部利用者には、Markdown 中心そのものより **Markdown の入口順が見えないこと** が重い。

3. **日本語ドキュメントは実害があるが、全面英訳が先ではない**
   OSS 利用者にとって README_en があるだけでは不十分。実際に詰まるのは README より、plugin 登録、quickstart、最小 TASK 例、troubleshooting、release compatibility。まず英訳すべきは思想文書ではなく、導入経路と失敗回復経路。

4. **自己進化という名前が過大に見える**
   外部ユーザーは “self-evolution” より “run review” “timeline” “regression check” の方が理解しやすい。自己進化を前面に出すと、作者の研究テーマに見える。機能名は実務語彙に寄せた方がよい。

推奨は、v8.7.0 では外部向けにこう見せること。

- 初回: `working-context` → `plan` → `exec` → `handoff`
- 任意: `bin/plangate metrics --report`
- 任意: `run-outcome-review.md` を 5 項目だけ記入
- Trace Timeline は “debug / audit view” 扱いで quickstart には出さない

## Q2. チーム導入時の破綻箇所

**結論/推奨: 現設計は 3〜10 人チームでは `ownership` と `merge protocol` が未定義な箇所から破綻する。自己進化機能をチーム向けに出すなら、機能追加より先に責任境界を明文化すべき。**

破綻箇所は具体的にこれ。

1. **Outcome Review の競合**
   1 run に 1 ファイルだと、実装者、レビュアー、PM が同じ `outcome-review.md` を編集して競合する。さらに「誰の評価が正」とするかが決まらない。  
   推奨: `outcome-review.md` は owner 1 名が集約。複数人入力は `reviews/outcome/<user>.md` かコメント断片に分離し、最終版だけ統合。

2. **events.ndjson の共有**
   現状の `docs/working/_metrics/events.ndjson` は public repo に commit 禁止の設計なので、チーム共有ログには向かない。個人ローカルに置くと横断分析できず、repo commit すると privacy 方針と衝突する。  
   推奨: v8.7.0 では共有 store を作らない。チーム対応は `events.ndjson` を個人ローカル、成果だけ `metrics-summary.md` または `outcome-review.md` に転記、で止める。外部 store は v8.8 以降。

3. **handoff.md の作成責任**
   1 人運用なら最後に作者が書けばよい。チームでは「実装者が書くのか、QA が確定するのか、レビュアーが承認するのか」が曖昧になる。  
   推奨: handoff owner は実装 owner。C-4 前に reviewer が確認。merge 後の追記は禁止または別ファイルにする。

4. **Skill / Playbook の所有権**
   チーム導入で一番危険なのは、各メンバーが便利だからと skill を直接変えること。自己進化が “勝手に skill を改善する文化” に見えると、品質が崩れる。  
   推奨: skill/playbook 更新は通常 PR と同じ扱いにし、owner 承認必須。Outcome Review は改善候補を出すだけで、直接反映しない。

5. **Mode 判定の揺らぎ**
   人によって light / standard / high-risk の判断がズレると、必要 artifact と review gate が変わる。これはチーム導入で確実に揉める。  
   推奨: Mode 判定の decision table と例外集を先に整備する。自己進化機能で mode を賢くするより、まず人間間の判定を揃える方が先。

## Q3. OSS 価値 vs 作者個人最適化

**結論/推奨: Trace Timeline 単体は作者個人最適化に寄りやすい。Outcome Review と Eval は、表現を絞れば OSS 価値になり得る。v8.7.0 は “Trace Timeline を主役にしない” 方がよい。**

分類するとこう。

| 機能 | OSS としての価値 | 個人最適化リスク | 判断 |
| --- | --- | --- | --- |
| Trace Timeline | 監査・再現・debug に効く | イベント粒度が作者の運用に最適化されやすい | 補助機能に格下げ |
| Run Outcome Review | チームでも個人でも振り返り型として使える | 項目が多いと作者メモ化する | v8.7.0 の主役にしてよい |
| Dogfooding Eval | ハーネス変更の退行検知に効く | 評価ケースが作者 repo だけだと閉じる | v8.8.0 で最小公開価値あり |
| events.ndjson 拡張 | 自動分析の材料 | privacy / store / schema 互換の負債が重い | 最小 additive のみ |
| 自動学習 / skill 更新 | 将来価値はある | OSS では危険に見える | 延期 |

外部利用者にとっての本当の価値は、「PlanGate 作者の作業を改善すること」ではない。次の 3 つ。

- 自分の AI 開発 run がなぜ失敗したかを後で説明できる
- チームで plan / review / handoff の品質を揃えられる
- PlanGate 自体の更新で既存運用が壊れないと判断できる

この観点では、v8.7.0 の価値ある最小単位は **Outcome Review template + metrics summary + optional timeline**。Trace Timeline を前面に出すと、OSS 機能ではなく作者の観測趣味に見えやすい。

撤回・延期すべきものは、自動学習、multi-judge、OTel 準拠、token/cost 必須化。外部 OSS 価値より維持費が勝つ。

## Q4. Docs / Onboarding は v8.7.0 で追いつくか

**結論/推奨: Option B をそのまま v8.7.0 に入れると docs は追いつかない。2〜4 週なら、外部向け docs は “Outcome Review を任意追加” に絞れば間に合う。Trace Timeline を quickstart に載せる余裕はない。**

更新必須 docs は以下。

1. **README.md**
   最新状態に v8.7.0 の位置づけを追加。ただし quickstart 本線には入れない。  
   追加するなら「実行後に振り返りを残す optional step」程度。

2. **README_en.md**
   外部 OSS 利用者向けには日本語 README より重要。v8.7.0 で日本語だけ更新すると、外部視点では機能が存在しないのと同じ。

3. **plugin/plangate/README.md**
   plugin 形式で使う人が最初に見る。Outcome Review / Timeline の追加コマンドや生成 artifact があるならここに最小説明が必要。

4. **docs/plangate.md**
   ワークフロー詳細側で、WF-05 後の任意 artifact として `run-outcome-review.md` を説明する。

5. **docs/working/templates/**
   `outcome-review.md` テンプレートが必須。既存 `handoff.md` と役割が重複しないように、「handoff = 引き継ぎ」「outcome review = run 改善学習」と明記する。

6. **TROUBLESHOOTING.md**
   metrics / timeline / plugin 解決 / events.ndjson が見つからないケースを追加する。外部利用者はここで救えるかが大きい。

7. **docs/plangate-plugin-migration.md**
   既存 v8.6.0 利用者向けに、追加 artifact が必須か任意か、既存 `.claude/` コピー運用で何を更新すべきかを書く。

v8.6.0 利用者の移行コストは、Outcome Review を任意にすれば低い。必須 artifact にすると高い。Trace Timeline を schema 変更込みで必須導線にすると、2〜4 週では docs と実装の整合が崩れる。

推奨する v8.7.0 の外部向け表現はこれ。

- 必須変更: なし
- 任意追加: `run-outcome-review.md`
- 既存 metrics: 互換維持
- Timeline: debug / audit 用 experimental
- schema 1.1: additive、既存 reader を壊さない

## Q5. 自己進化より優先すべき OSS 整備項目

**結論/推奨: 外部ユーザー視点を本気で重視するなら、v8.7.0 の最優先 3 件は #226、#224、#225。自己進化は “Outcome Review 最小版” まで縮小し、Trace Timeline はその補助に落とすべき。**

優先順位は以下。

1. **#226 段階的導入ガイド**
   これが最優先。理由は、PlanGate の最大摩擦が機能不足ではなく「どこまで使えばよいか分からないこと」だから。  
   外部利用者には、いきなり full governance ではなく、次の導入段階が必要。

   - Level 1: plan 承認だけ
   - Level 2: handoff まで
   - Level 3: hooks / validate
   - Level 4: metrics / outcome review
   - Level 5: eval / timeline

   自己進化機能は Level 4 以降に置くべきで、初回導線に混ぜるべきではない。

2. **#224 Plugin 形式の成熟化**
   OSS として使われるには、機能の思想より配布の確実性が先。現状は clone + plugin 登録または `.claude/` コピーで、手動運用の匂いが強い。  
   外部利用者は「これを自分の repo に入れて壊れないか」を先に見る。plugin 解決順、prefix、更新手順、二重 install の回避が曖昧だと、自己進化以前に導入されない。

3. **#225 バージョニング安定性ポリシー**
   自己進化機能は schema、artifact、workflow、skill を動かす。だからこそ、何が breaking change で、何が additive で、既存 TASK artifact をどう扱うかを先に固定する必要がある。  
   後方互換重視を掲げるなら、v8.7.0 の Trace Timeline / Outcome Review はこのポリシーなしに強く出すべきではない。

#191 認知獲得計画は重要だが、上位 3 件ではない。理由は、導入摩擦が高いまま認知を増やすと、第一印象で落ちるから。まず “入れて試せる” 状態を作る方が先。

最終判断としては、v8.7.0 はこう組み替えるのが現実的。

- 主: #226 段階的導入ガイド
- 主: #224 plugin 成熟化の最低限
- 主: #225 互換性ポリシーの最低限
- 副: Run Outcome Review v1
- 実験: Trace Timeline v1 は optional / experimental
- 延期: Dogfooding Eval v1 は v8.8.0、ただし外部 fixture を意識して設計

忖度なしで言うと、今のまま “自己進化” を v8.7.0 の顔にすると、OSS 利用者には刺さりにくい。PlanGate の OSS 価値は「AI 開発の安全な型を配布すること」であって、「作者の運用ログを高度化すること」ではない。自己進化は残してよいが、外部向けには **段階導入・配布安定・互換性保証の上に乗る optional advanced feature** として扱うべき。

---

## 決定事項の大幅修正（Claude 統合）

### 致命的な発見
> **PlanGate の OSS 価値は「AI 開発の安全な型を配布すること」であって、「作者の運用ログを高度化すること」ではない**

これまで 4 ディスカッションは全て「Steering Loop / 自己進化をどう設計するか」を議論してきたが、Codex の外部視点評価により、**v8.7.0 の顔として自己進化を出すこと自体が OSS 価値とミスマッチ** という結論。

### v8.7.0 主軸の根本的組み替え（Option B → Option D）

| 順位 | 元計画 (Option B) | 新計画 (Option D) | 理由 |
|------|------------|------------|------|
| 主 | Trace Timeline v1 | **#226 段階的導入ガイド** | 最大摩擦は機能不足ではなく「どこまで使えばよいか不明」 |
| 主 | Run Outcome Review v1 | **#224 Plugin 成熟化** | 配布の確実性が機能思想より先 |
| 主 | （なし）| **#225 バージョニング安定性ポリシー** | schema/artifact を動かす前提 |
| 副 | Gate Event Normalization | **Run Outcome Review v1** | 振り返り型として OSS 価値あり |
| 実験 | （なし）| **Trace Timeline v1** | optional / experimental 扱い |
| 延期 | （v8.8.0）| Dogfooding Eval v1 | 外部 fixture 意識して設計 |

### OSS 利用者にとっての真の価値（Codex 整理）
1. 自分の AI 開発 run がなぜ失敗したかを後で説明できる
2. チームで plan / review / handoff の品質を揃えられる
3. PlanGate 自体の更新で既存運用が壊れないと判断できる

→ Trace Timeline 中心では (1)(2)(3) いずれも直接満たさない。**Outcome Review** は (1) を、**段階的導入ガイド** は (2) を、**バージョニング安定性** は (3) を直接満たす。

### 段階的導入レベル（Codex 提案、#226 の具体化）
- **Level 1**: plan 承認だけ
- **Level 2**: handoff まで
- **Level 3**: hooks / validate
- **Level 4**: metrics / outcome review
- **Level 5**: eval / timeline

自己進化機能は **Level 4 以降** に置く。初回導線に混ぜない。

### チーム導入で破綻する 5 箇所（事前に明文化必要）
1. Outcome Review の競合 → owner 集約モデル
2. events.ndjson 共有 → v8.7.0 では共有 store を作らない
3. handoff 作成責任 → 実装 owner、C-4 前 reviewer 確認
4. Skill/Playbook 所有権 → 通常 PR と同じ扱い、自動更新禁止
5. Mode 判定揺らぎ → decision table + 例外集を先に整備

### Docs 更新の現実
v8.7.0 2-4 週で間に合う範囲:
- 必須変更: **なし**
- 任意追加: `run-outcome-review.md` テンプレート
- 既存 metrics: 互換維持
- Timeline: debug/audit 用 experimental
- schema 1.1: additive、既存 reader を壊さない

→ 「必須変更なし」が外部利用者への最大メッセージ

### 撤回・延期確定（Round 4 の決定を強化）
- ❌ 自動学習 / skill 自動更新 → 延期（OSS では危険）
- ❌ multi-judge consensus → 撤回（Round 4 で既に）
- ❌ OTel GenAI 準拠 → 撤回（Round 4 で既に）
- ❌ Token/Cost 必須化 → 撤回（Round 4 で既に）
- 🔻 Trace Timeline v1 → **experimental 扱いに格下げ**（Round 5 新）
- 🔻 「自己進化」という用語 → **実務語彙（run review / regression check 等）に置換**（Round 5 新）

## 統合後の最終戦略（Option D, Round 5 確定版）

### v8.7.0
- **#226 段階的導入ガイド** 完成（Level 1-5 定義 + docs）
- **#224 Plugin 成熟化** 最低限（解決順 / prefix / 更新手順 / 二重 install 回避）
- **#225 バージョニング安定性ポリシー** 最低限（breaking vs additive 定義）
- **Run Outcome Review v1**（template + 任意導入）
- Trace Timeline v1 は experimental（schema 1.1 additive のみ、quickstart 非掲載）
- Gate Event Normalization は v8.8.0 以降に延期

### v8.8.0
- Dogfooding Eval v1（single judge + human rationale、外部 fixture 意識）
- Trace Timeline v1 の正式化（v8.7.0 experimental の昇格）

### v8.9.0
- 計画しない（v8.8.0 完了後に判断）

### 言語と命名
- 「自己進化（self-evolution）」→ 内部用語に。外部表現は **run review / timeline / regression check** に
- 「Steering Loop」→ 設計議論の用語に。外部表現は **observability for development workflow** 等

## 次アクション（Option D 採用前提）

- [ ] Option D を最終採用するか **ユーザー確認**（Option B から大幅変更のため）
- [ ] `docs/ai/harness-improvement-roadmap.md` v8.7.0 セクションを Option D に書き換え
- [ ] #226 #224 #225 を v8.7.0 milestone の P0 に昇格
- [ ] Trace Timeline v1 (PBI-HI-009 仮想) の Issue 本文を experimental 表記で書き直し
- [ ] Run Outcome Review v1 を新規 PBI として起票
- [ ] Dogfooding Eval v1 (PBI-HI-010 仮想) を v8.8.0 で起票（外部 fixture 意識）
- [ ] README / README_en / plugin/plangate/README / TROUBLESHOOTING の更新計画

