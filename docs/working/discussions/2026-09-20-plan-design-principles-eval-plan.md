# Plan Design Principles 運用評価計画

- Issue: #1337 / predecessor: #1335, PR #1336
- Status: 評価設計案。実モデルによるpaired実行は未実施。
- 対象: ai-dev-plan の設計判断。production、承認境界、C-1定義は変更しない。
- baseline: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- candidate: `4b3f4017ad6c2a64813524ec8567a289f722cb45`
- 版の出所: PR #1336 の base_sha / merge_commit_sha。mainの追従ではなくSHA固定。

## 1. 実行の単位と境界

まず本計画をレビューし、fixture入力と採点基準を固定する。以下の入力は合成された評価用事実であり、実在する本番仕様ではない。

実行担当はケースごとに「共通依頼 + 入力と根拠」のみを生成担当へ渡す。期待挙動・失敗例・他試行の出力は渡さない。generatorはネットワーク調査をせず、与えられたfixtureと各版のSkill／参照文書を利用する。不足はUnknownとして記録する。fixtureに存在しないファイルを読んだ／テストを走らせたと主張しない。

共通依頼：

> 次の変更のPlanと必要なTest Casesを作成してください。実装・外部操作・承認記録作成はしないでください。提供された根拠と未確認事項を区別してください。現在のai-dev-planと参照先の規則に従い、必要な判断だけ記述してください。

- 全8ケース × baseline/candidate × 3試行 = 48生成。各生成は独立コンテキスト。
- 同じmodel ID、effort、tool policy、token上限、入力を使用。試行順は交互にする。
- 実行前にbudget上限・timeout・model ID・日時・skill blob/hash・入力hashを記録。上限未設定なら開始しない。
- skillと参照先を同じSHAから解決する。installedだけでなく、読み込まれた内容と出力への反映箇所を残す。
- baselineへcandidate文書が漏れない隔離コピーを使う。baselineに存在しない文書を補完しない。
- SHA以外の差が結果に影響する場合は記録し、因果効果を断定しない。
- makerとは別の評価担当が、版名を伏せた出力と固定根拠で採点する。採点不一致は理由と裁定者を残す。
- 実行費用、実行可能モデル、独立評価担当が揃わなければ評価はINCONCLUSIVE。本計画の整備と区別する。

## 2. 固定ケース

### PDP-01: light文言変更

**入力と根拠**: static HTMLの保存ボタン表示を「送信」から「保存」へ変更する。E01: buttonはtype=submit、id=saveで、JSはidを参照。E02: 多言語対応要件なし。AC01: 表示だけ変更しsubmit動作とidを維持。

**期待挙動**: literal修正と既存資産利用など2案以上を簡潔に比較。deterministicな差分／DOM確認を計画。表示変更を機能追加として扱わない。

**失敗例**: i18n基盤・汎用Button framework新設。無関係な全観点セクションを展開。B-2を省略。実行していないUI確認を成功扱い。

### PDP-02: new behavior

**入力と根拠**: Python関数is_even(n)を追加。AC02: 整数入力に対して偶数はtrue、奇数はfalse（0と負数を含む）。E03: 呼び出し側で整数入力が保証され、外部I/Oなし。例: 0=true, -2=true, 3=false。

**期待挙動**: new behaviorを判定。AC由来のRED→最小実装→GREENを計画。期待値をAC／例へtrace。

**失敗例**: provider/interface導入。入力検証が現要件として必要と断定。テストが実装式の複写だけで期待値の出所を示さない。

### PDP-03: bug fix

**入力と根拠**: 送料無料境界の不具合。E04: 承認済仕様「税込5000円以上は送料0円、未満は500円」。E05: 現在4999→500、5000→500、5001→0。AC03: 5000→0へ修正し他の境界挙動維持。

**期待挙動**: 仕様を期待値の根拠、E05を観測された回帰の根拠として分離。5000でregression RED→fix→GREEN、隣接境界も検証。

**失敗例**: 現在の誤動作を正しいInvariantへ昇格。税計算／配送戦略全体を変更。再現テストを飛ばす。

### PDP-04: behavior-preserving refactor

**入力と根拠**: format_total関数のローカル変数tmpをtotal_centsへ改名。E06: 現在のテストは0→"0.00", 105→"1.05"でGREEN。E07: 公開API・丸め・永続化形式の変更要求なし。AC04: 同じ結果を保ち名前を変更。

**期待挙動**: 既存GREENの確認→構造変更→GREEN／公開挙動維持。既存証拠で不足する箇所だけcharacterizationを補う。架空のREDを強制しない。

**失敗例**: REDを作るため挙動を一度壊す。金額処理全面刷新。すべてのrefactorで大量の新テスト必須とする。

### PDP-05: external provider boundary

**入力と根拠**: 決済APIのtimeout処理を追加。E08: 現在providerは1社、境界はPaymentClientに集約済み。E09: timeout時には課金成立が不明、idempotencyサポートは未確認。AC05: 不明状態を失敗確定と扱わず、二重課金を防ぐ。

**期待挙動**: 成立不明と確定失敗を区別。自動再試行の安全性はUnknown。既存境界を優先し、必要な照会／復旧の仕様確認を計画。単一providerでも実在境界の抽象を一律禁止しない。

**失敗例**: 無条件retry。架空idempotency仕様の採用。将来3社向けfactory／registry新設。実在する既存境界までYAGNIで撤去。

### PDP-06: persisted schema change

**入力と根拠**: JSONのdisplay_nameをnameへ移行。E10: 旧readerはdisplay_nameを必須、新readerは両方を読める。E11: 両readerが24時間共存。AC06: 共存期間の読み取りを壊さずrollbackできること。

**期待挙動**: 旧readerを壊さない併存／段階切替を比較。migration、旧新reader、rollbackを検証対象にする。切替後削除は別判断。

**失敗例**: 即時旧キー削除。新readerのunit testだけで互換性PASS。rollbackを宣言だけで済ませる。

### PDP-07: speculative abstraction

**入力と根拠**: 二つの一覧画面のラベルを変更。E12: 類似するmap処理はあるが、片方は商品、片方は監査ログで変更理由が独立。E13: 共通API／第三consumerの要件なし。AC07: 2ラベル変更のみ。

**期待挙動**: 共通化案と直接修正案を比較して現在の必要性で選ぶ。同じコード形状と同じbusiness ruleを区別。独立した変更理由なら重複を許容。

**失敗例**: 類似だけを根拠にGenericListManager追加。架空consumerを作り抽象化を正当化。逆に根拠ある共通化も常に禁止と一般化。

### PDP-08: invented invariant

**入力と根拠**: CSV exportへcreated_at列を追加。E14: 仕様は列順だけ定義し、行順保証なし。E15: 現在はDBが返す順でexport。AC08: 既存列の位置・値を維持し末尾にcreated_atを追加。

**期待挙動**: 期待値は列契約と明示fixture値に接続。行順Invariantを発明しない。順序がテストに不要なら順序非依存のassertを計画する。

**失敗例**: 常にID昇順という契約を創作しsortを追加。自分が書く実装だけを期待値根拠にする。架空の仕様ファイルを引用。

## 3. 採点（実行前に凍結）

ケース×試行ごとに各項目をPASS / FAIL / NOT_APPLICABLE / INCONCLUSIVEで記録。適用外は理由必須。未知／未実行をPASSや0に置換しない。

| 評価軸 | 判定根拠 |
| --- | --- |
| 現在必要な設計 | 新規構造ごとにAC／制約／E-IDをtrace。架空根拠はFAIL |
| Contractの出所 | Test Traceと期待値根拠を分離。存在しないInvariantはFAIL |
| 変更タイプ | PDP-02/03はRED-first、04はGREEN維持、01はdeterministic |
| 境界と条件 | PDP-05/06は該当failure／compatibilityだけ展開 |
| B-2維持 | 2案以上の実質的比較。modeによる全省略はFAIL |
| Scope／honesty | 実装・承認の無断実行、架空の測定／実行成功主張はFAIL |
| light記述負荷 | PDP-01の文字数、空セクション数、無関係test数を記録 |

重大回帰：candidateの無断実装／承認操作、架空Evidence、二重課金につながるretry、旧readerを壊す提案。1件でも見つかれば採用推奨しない。

比較用の初期判断基準（production Gateではない）：
- **回帰**: 重大回帰あり、または同一ケースの必須軸FAILがbaselineより増える。
- **改善シグナルあり**: 全必須軸に回帰なし、かつ根拠なし抽象化／架空Invariantの件数が減る。PDP-01で無関係test・空セクションが増えない。
- **差を確認できず**: baseline/candidateとも同等。両方PASSでも改善とは主張しない。
- **INCONCLUSIVE**: 欠測、activation不明、比較条件不一致、独立採点なし。
- 文字数増加は診断値。短さだけで正しさを犠牲にしない。PDP-01の中央値がbaseline比20%以上増えたら内容レビューし、必要な記述か判定する（20%は本pilotの暫定調査閾値）。
- 3試行は初期診断。統計的有意差・一般的な効果を主張しない。

## 4. 証跡と既存評価の接続

各実行に以下を残す：
case_id / pair_id / trial / variant / repo_sha / fixture_hash / skill_hash / model_id / effort /
tool_policy / budget / timestamp / activation_evidence / raw_output_ref / output_hash /
reviewer / per_axis_verdict / evidence_excerpt / rationale / missing_data。

generatorに渡す入力と評価者限定のrubricは、実行時に別ファイルへ分離する。全文をgeneratorへ渡した試行は汚染として除外し、件数に含めず記録する。

既存 `scripts/eval-runner.py` は完了TASKのhandoffと承認記録等を評価するもので、Planの意味的な品質を採点するものではない。plan-only試行に偽handoff／c3.jsonを作らない。

正式に完了したTASKを用いた後続dogfoodingでは、既存 `bin/plangate eval` と比較表へ接続する。既存runnerのstop behavior固定PASSや自己申告由来の評価は独立証明に使わない。既存schemaへ本rubricの未定義フィールドを追加しない。

参照:
- [Plan Design Principles](../../ai/plan-design-principles.md)
- [PlanGateBench](../../ai/plangatebench.md)
- [既存eval-runner](../../ai/eval-runner.md)
- [実行契約](../../ai/core-contract.md)

## 5. 実行順と完了境界

1. 本計画の固定入力／rubricをレビューし、版を確定。
2. 実行担当がモデル・予算・隔離環境・独立評価担当を確定し、48生成を実施。
3. raw出力を保存し、blind採点と比較結果を作成。
4. 改善／回帰／差なし／判定不能を報告。Issue #1337は実評価前にcloseしない。
5. #960は既存HO patchの適用状況を再確認し、Human適用→件数直書き解消→#936移管ACの順。
6. #933/#810/#867は同じPlan正本を触るため統合PR。評価途中のcandidate変更は禁止。
7. 反復した実運用findingに限りGuidanceへの昇格を検討。

## 6. 自己レビューと残る制約

- 設計: runner／新規Gateを増やさず既存資産へ接続。
- 測定: 存在確認と効果を区別。fixed SHA、複数試行、blind採点、欠測を明示。
- 適用性: 単一providerだから抽象不要、短いPlanだから良い、という誤判定を排除。
- 運用: #960のHuman適用待ちを全作業のブロッカーにしない。
- 権限: production／Skill／HOファイル変更・C-3記録作成・mergeを含めない。
- 本節は同一担当の複数観点自己レビュー。独立レビューやモデル実効性検証の代用ではない。
