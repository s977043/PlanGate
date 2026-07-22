# PBI INPUT PACKAGE — TASK-0867

> Issue: [#867](https://github.com/s977043/plangate/issues/867)（P2 / enhancement / area:workflow）
> 作成: 2026-07-22（調査・main b632a91 裏取り済み。AC / 検証シナリオ / Non-goals は issue verbatim + 2026-07-18 棚卸しコメント反映）

## Context / Why

Uzabase Agile Journey の記事「リファクタリングは、なぜ必要なのか？」（issue 参照リンク）は、リファクタリングを**開発で更新されたチームの理解と、コードが表現する過去の理解との差分（Knowledge Delta）を同期する活動**として捉える。AI 駆動開発では実装速度が上がる一方、(1) 新しく得たドメイン知識が名前・責務・境界へ反映されない、(2) 振る舞い変更と構造変更が同一 diff へ混在する、(3) 将来予測に基づく過剰抽象化、(4) テスト不十分な状態での広範囲リファクタリング、(5) 「なぜ構造を変えたか」が Plan / PR / 記録に残らない、という問題が拡大しやすい（issue 本文）。PlanGate はこれを独立した美化作業ではなく **Knowledge Delta を検出し安全にコードへ反映する計画・実行パターン**として組み込む価値がある。

2026-07-18 の Issue 棚卸しコメント（[permalink](https://github.com/s977043/PlanGate/issues/867#issuecomment-5011251311)・verbatim）により、本 Issue は次の **genuine gap** に限定して維持されている:

- 条件付き `Knowledge Delta`（新しく得たドメイン理解と現行コード表現の差分）
- behavior change と structural change の識別可能な分割
- Characterization Test / Preparatory Refactoring の適用条件

既存で対応済みのため新規実装しない（棚卸しコメント verbatim）: YAGNI / 投機的抽象化検査 = `.agents/skills/review-gate`（#794・CLOSED）、refactor 前後の検証証跡 = `evidence-tdd-ledger.json` の `refactor_verify`、一般的な Facts / Assumptions / Unknowns = #810、恒久ルールへの昇格 = #811。Trust Ledger のスコープ狭義化は同コメント verbatim「**Trust Ledger schema の新規フィールド追加は初期スコープから外し、既存 decision/evidence で不足が実測された場合のみ additive に検討します。**」に準拠する（出典: [棚卸しコメント permalink](https://github.com/s977043/PlanGate/issues/867#issuecomment-5011251311)。issue 本文の提案 5「Trust Ledger へ記録項目を追加」の yaml フィールド案・AC-7 に対する scope narrowing であり、この読み替えは **C-3 承認対象**とする）。

実測（2026-07-22・main b632a91）:

- **概念の正本不在**: `Knowledge Delta` / `Behavior Preservation` / `Preparatory Refactoring` は `docs/working/` を除く全リポジトリで grep **0 件**。唯一の近縁は V-2 `code-optimizer` の Iron Law「`OPTIMIZE BEHAVIOR-PRESERVING CHANGES ONLY. BREAK NOTHING.`」（`.claude/agents/code-optimizer.md` L16）で、これは V-2 フェーズ限定の原則であり Plan / タスク分割 / 完了ゲートの規約ではない
- **Characterization は「テスト実装の命名」としてのみ実在**: `scripts/ai-loop/test_arbiter.py` に `ArbitrateCharacterizationTests`（既存挙動固定の characterization test 実践例）が実在する（事前調査の「grep 0 件」は現 main では不正確）。ただし **Plan / ゲート正本での「Characterization Test の適用条件」定義は 0 件**で、genuine gap は不変
- **投機的抽象化検査は既存**: `.agents/skills/review-gate/SKILL.md` L179「YAGNI / 過剰実装: 投機的抽象・未使用の拡張点・過度な汎用化がないか」（#794 で導入済み）→ 再実装しない
- **refactor 検証証跡は既存**: `refactor_verify` は `docs/working/templates/evidence-tdd-ledger.json` / `docs/ai/quality-command-evidence.md` / `plugin/plangate/skills/evidence-ledger/SKILL.md` に実在 → 再実装しない
- **#810 は OPEN・pbi-input 合意済（plan 未正式化）**: `docs/working/TASK-0810/pbi-input.md` は `docs/working/templates/plan.md` の `## Questions / Unknowns（#786）` 節拡張 + C-1 17 項目への Blocking Unknown gate 追加を In scope に持つ。本 PBI も同一アーティファクト（plan テンプレート + C-1）を拡張するため、**実装順は #810 後が安全**（同一ファイルへの 2 回の非同期改訂を避ける。#810 pbi-input が 2 issue 統合を決めたのと同じ理由）
- **大規模負債の別 Issue 化は既存規約**: handoff テンプレートの「V2 候補」欄 + 「実装で勝手に作らず提案として handoff の V2 候補・別 Issue へ分離する」前例（`docs/ai/design-ui-addendum.md` L61、#578 系・CLOSED）→ Case 3 の受け皿は既存で、重複定義しない
- **HO 分岐**: issue「想定する組み込み箇所」の `.claude/commands/ai-dev-workflow.md`（C-1 17 項目の正本）/ `.claude/rules/*.md` は HO-rules（`docs/ai/ai-loop/ho-paths.md` L29/L38「AI 直接編集不可」）。加えて **`docs/ai/*.md`（トップレベルの md のみ）は HO-contract**（ho-paths.md L35。`docs/ai/ai-loop/` 配下と `docs/workflows/` / `docs/` 直下は対象外）→ 説明文書はトップレベル `docs/ai/` を避ければ非 HO で AI 完結。非 HO で AI が完結できるのは `docs/working/templates/plan.md`（#786 系で改訂実績あり）/ `docs/` 直下・`docs/workflows/` 配下の説明文書 / fixture

## What（Scope）

### In scope（棚卸しコメントの genuine gap 3 点 + それを運ぶ最小の組み込み）

1. **条件付き Knowledge Delta 節**: issue 本文の 4 部構成（Newly learned / Existing representation / Delta / Required structural response）を plan テンプレートへ**条件付き**で導入。適用条件（issue verbatim 4 条件: 既存コードの責務・境界・命名を変更する / ドメインルールの理解が更新された / 変更前の構造が新しい要件を不自然にしている / リファクタリングを含む可能性が高い）と省略条件（Case 1 相当）を定義。**入力層は #810 の Facts / Assumptions / Unknowns 構造と共有**し、plan テンプレートに重複記入欄を作らない
2. **タスク分割パターン**: A. Characterization / Safety Net → B. Preparatory Refactoring → C. Behavior Change → D. Post-change Refactoring → E. Independent Verification の順序分解と原則 4 点（issue verbatim: Red で構造変更を進めない / 振る舞い変更と構造変更を識別可能な単位へ分ける / Preparatory は最小範囲 / 広範囲負債は隠さず別 Issue/Epic 候補として報告）を todo / Work Breakdown 規約へ導入
3. **Characterization Test / Preparatory Refactoring の適用条件定義**: どういう場合に A / B を先行させるか（テスト不足 × 構造変更範囲）の判定条件を正本化。実践例として既存 `ArbitrateCharacterizationTests` を参照
4. **過剰設計チェックの参照統合（C-1 + PR 前セルフレビュー配線）**: issue 提案の 5 チェック項目のうち、YAGNI / 投機的抽象化系は既存 `review-gate` 観点（#794）への**参照**で充足し二重実装しない。新規追加は Knowledge Delta 固有の項目（「新しい名前・責務・境界が Knowledge Delta を正しく表現する」「今回触る必要のない範囲まで変更していない」）に限定（充足方式は C-3 論点 2）。配線先は issue「想定する組み込み箇所」verbatim の **C-1 セルフレビュー**と **C-4 前後の実行前・PR 前セルフレビュー（`review-self.md` の C-1 相当運用 / `diff-audit` 系）**の両方とし、後者には「構造変更と振る舞い変更が識別可能な単位に分かれているか」の再検査観点を含める（#810 が同レビューへ Unknown 再検査観点を追加するのと同型・増分最小）
5. **Behavior Preservation の完了確認**: 構造変更を含む場合の完了判定項目（issue verbatim: 既存 + 追加テスト PASS / 型チェック・静的解析 PASS / 外部 IF 互換 / 振る舞い変更と構造変更の区別説明 / rollback 可能または不可逆性の Plan 承認）を条件付きで定義。V-2 `code-optimizer` Iron Law・`refactor_verify`（evidence-tdd-ledger）と整合させ、既存機構の重複再定義をしない（配線先は plan で確定）
6. **記録層は既存拡張にスリム化**: 変更理由と検証結果は `decision-log.jsonl`（append-only）と handoff（妥協点 / V2 候補）の**既存構造の記載規約拡張**で残す。新スキーマ・Trust Ledger schema 新フィールドは追加しない（棚卸しコメント verbatim。不足が実測された場合のみ additive に後続検討）
7. **docs 説明 + 3 ケースのサンプル / fixture**: 「コード美化ではなく知識差分の同期」であることの説明文書と、Case 1（小さな機能追加 = 省略経路）/ Case 2（ドメイン理解更新の既存機能変更 = A→B→C 分割）/ Case 3（構造的負債 = 別 Issue/Epic 候補出力）のサンプルまたは fixture

### Out of scope（issue Non-goals verbatim + 棚卸しコメント）

- すべてのタスクでリファクタリングを必須にすること
- コードスメルを網羅的に自動修正すること
- 将来利用を想定した抽象化を一律禁止すること
- テストがない状態で AI に大規模変更を許可すること
- River Review の詳細な diff レビュー観点を PlanGate 側へ重複実装すること（責務分担: PlanGate = Knowledge Delta の明示・変更順序・Safety Net・実行条件・完了ゲート / River Review = diff が Knowledge Delta を適切に表現するかのレビュー。用語と判定形式は揃えるが同じチェックを二重実装しない）
- **YAGNI / 投機的抽象化検査の再実装**（`.agents/skills/review-gate` #794 既存 → 参照統合のみ）
- **refactor 前後検証証跡の再実装**（`evidence-tdd-ledger.json` `refactor_verify` 既存）
- **一般的な Facts / Assumptions / Unknowns の再定義**（#810 の責務 → 入力層共有のみ）
- **恒久ルールへの昇格機構**（#811 の責務）
- **Trust Ledger schema の新規フィールド追加**（棚卸しコメントで初期スコープ外が確定。既存 decision / evidence で不足が実測された場合のみ additive 検討）
- **HO 対象パス（`.claude/commands/ai-dev-workflow.md` / `.claude/rules/*.md` 等）への実適用**（AI は差分提案まで・適用は Human ワンアクション。TASK-0810 In scope 4 と同型）

## 受入基準（issue #867 Acceptance Criteria verbatim・10 項目）

- AC-1: 現行 PlanGate の Plan・レビュー・ゲート構造との重複を調査した
- AC-2: Knowledge Delta を記録する条件と省略条件が定義されている
- AC-3: 振る舞い変更と構造変更を分離するタスク分割ルールが定義されている
- AC-4: Characterization Test / Preparatory Refactoring の利用条件が定義されている
- AC-5: 投機的抽象化と不要な変更範囲を検出するレビュー項目が追加されている
  - **本 PBI の充足水準（棚卸しコメント整合）**: YAGNI / 投機的抽象化の検出本体は既存 `review-gate`（#794）への参照統合で充足し、新規追加は Knowledge Delta 固有項目に限定する（充足方式は C-3 論点 2 で確定）
- AC-6: 構造変更前後の振る舞い維持を確認するゲートが追加されている
- AC-7: Trust Ledger への記録方法が既存スキーマと整合している
  - **本 PBI の充足水準（棚卸しコメント verbatim 準拠・C-3 承認対象の読み替え）**: 新規フィールドを追加せず、既存 `decision-log.jsonl` / handoff の記載規約拡張で表現できることをもって「整合」とする（出典: [棚卸しコメント permalink](https://github.com/s977043/PlanGate/issues/867#issuecomment-5011251311)）。充足の具体化として、**既存 Trust Ledger 4 系列（decision record / provenance / 摩擦台帳 / review-feedback）のどこへ何（変更理由 / Knowledge Delta / 検証結果 / 投機的抽象化の有無）を記録するかの対応表を plan で作成**する
- AC-8: サンプルまたは fixture で、単純機能変更・既存コード変更・大規模負債の 3 ケースを確認できる
- AC-9: ドキュメントに「コード美化ではなく知識差分の同期」であることが説明されている
- AC-10: 既存フローを不必要に重くしない適用条件・スキップ条件がある

### In scope↔AC 対応（issue AC に無いが In scope 実装物に紐づく検証条件）

- AC-11（In scope 1 対応）: Knowledge Delta の入力層が #810 の Facts / Assumptions / Unknowns 構造と共有され、plan テンプレートに同種の記入欄が二重に存在しない（#810 完了後の plan テンプレート実体に対して機械確認）
- AC-12（In scope 4・6・Out of scope 対応）: 棚卸しコメントの吸収先 4 点（review-gate #794 / `refactor_verify` / #810 / #811）との突合表があり、本 PBI 成果物がそれらを重複再実装していない

### In scope↔AC マッピング

| In scope | 対応 AC |
|----------|---------|
| 1 条件付き Knowledge Delta 節 | AC-2, AC-10（+ AC-11） |
| 2 タスク分割パターン A〜E | AC-3 |
| 3 Characterization / Preparatory 適用条件 | AC-4 |
| 4 過剰設計チェックの参照統合（C-1 + PR 前セルフレビュー配線） | AC-5, AC-3（PR 前の分離再検査観点）（+ AC-12） |
| 5 Behavior Preservation 完了確認 | AC-6 |
| 6 記録層の既存拡張スリム化 | AC-7（+ AC-12） |
| 7 docs 説明 + 3 ケース fixture | AC-1, AC-8, AC-9 |

## 実装順の依存（Deferred / BLOCKED 構造）

本 PBI は **#810（TASK-0810）実装後の着手を強推奨**とする。理由: 両者が同一アーティファクト（`docs/working/templates/plan.md` の Unknowns 系節 + C-1 17 項目）を拡張し、In scope 1 の「入力層共有」は #810 側の構造化節（Known Facts / Assumptions / Known Unknowns 等）が先に確定していることを前提とするため（後着が安全）。`working-context.md` の BLOCKED 記法で管理する:

| フィールド | 内容 |
|-----------|------|
| `blocker` | TASK-0810（#810 + #786 F-3/F-5 統合 PBI）の plan テンプレート + C-1 改訂が main 未 merge（2026-07-22 時点 #810 OPEN・pbi-input 合意済 / plan 未正式化） |
| `owner` | 前段 PBI（TASK-0810）の完了。human（C-3 / C-4）+ AI exec |
| `unblock_condition` | TASK-0810 の C-4 merge（plan テンプレート改訂の確定）。または C-3 論点 3 で人間が並行着手 / 順序入替を明示裁定 |

## C-3 論点（pbi-input では確定せず C-3 / plan で確定）

1. **HO 分岐（AI-owned 範囲の確定・対象パス列挙）**: 本 PBI が新設 / 更新するパスと HO 区分（`docs/ai/ai-loop/ho-paths.md` 実測）は下表のとおり。HO 側は **AI は差分提案（パッチ相当テキストを plan / handoff に明示）まで**とし、実適用は Human ワンアクション（TASK-0810 In scope 4 と同型）。この分界の承認

   | パス | HO 区分 | 用途 / 扱い |
   |------|---------|-------------|
   | `docs/working/templates/plan.md` | 非 HO | 条件付き Knowledge Delta 節（In scope 1）。AI 完結 |
   | todo テンプレート / Work Breakdown 規約（`docs/working/templates/todo.md`。#810 で新設予定・実体は TASK-0810 の確定に追従） | 非 HO | 分割パターン A〜E（In scope 2）。AI 完結 |
   | `docs/refactoring-knowledge-sync.md`（新設・仮称。`docs/` 直下 = 非 HO。名称・配置は plan で確定） | 非 HO | 説明文書「コード美化ではなく知識差分の同期」+ River Review 分担 + 適用条件（In scope 7）。**トップレベル `docs/ai/*.md` は HO-contract（ho-paths.md L35）のため置かない**。どうしても `docs/ai/` 直下に置く判断となった場合は HO patch + Human 適用へ分類変更 |
   | Case 1〜3 サンプル / fixture（`docs/working/templates/` 配下または `tests/fixtures/`。plan で確定） | 非 HO | In scope 7。AI 完結 |
   | `.claude/commands/ai-dev-workflow.md`（C-1 17 項目正本） | **HO-rules** | C-1 追加項目の差分提案まで（In scope 4） |
   | `.claude/rules/*.md`（review-principles.md 等。対象範囲は plan で確定） | **HO-rules** | 運用注記の差分提案まで |

2. **AC-5 の充足方式**: (a) `review-gate` 既存観点への参照統合 + Knowledge Delta 固有項目のみ追加（推奨・二重実装回避）vs (b) issue 記載 5 項目をそのまま C-1 へ追加。棚卸しコメント「YAGNI / 投機的抽象化検査は新規実装しない」との整合裁定
3. **#810 後着（BLOCKED）の承認**: 上記 Deferred 構造の承認、または並行着手 / 順序入替の明示裁定
4. **Knowledge Delta の配置**: plan テンプレート内で #810 拡張節（Questions / Unknowns 系）に同居させるか、独立節とするか
5. **Behavior Preservation の配線先**: V-1 受け入れ検査の条件付き確認項目とするか、todo の E（Independent Verification）完了条件とするか（新規ゲートフェーズは追加しない前提。V-2 Iron Law / `refactor_verify` との重複回避）

## Notes from Refinement（調査で確定した設計方針）

- **#810 への完全吸収は非推奨（直交性）**: #810 = **認識ゲート**（Unknown / 前提を認識し blocking 判定する）、#867 = **構造応答ゲート**(更新された理解に構造＝名前・責務・境界で応答し、その変更を安全に分割・検証する)。責務が直交するため別 PBI を維持。ただし**入力層（何を新しく知ったか）は #810 の Facts / Assumptions 構造と共有**し、**記録層は decision-log / handoff の既存拡張**にスリム化する（新スキーマを作らない）
- **既存部品との突合表（棚卸しコメント 4 点 + 実測補強）**:

  | 既存部品 | 本 PBI での扱い |
  |---------|----------------|
  | `.agents/skills/review-gate` YAGNI / 投機的抽象観点（#794） | 参照統合（再実装しない） |
  | `evidence-tdd-ledger.json` `refactor_verify` | 検証証跡としてそのまま利用（再実装しない） |
  | #810 Facts / Assumptions / Unknowns | 入力層を共有（再定義しない） |
  | #811 恒久ルール昇格 | 接続のみ（昇格機構は持たない） |
  | V-2 `code-optimizer` Iron Law（behavior-preserving） | Behavior Preservation 完了確認と整合（V-2 は最適化フェーズ限定、本 PBI は構造変更を含む全タスクの条件付き確認） |
  | handoff V2 候補 + 別 Issue 分離規約（#578 系前例） | Case 3 の受け皿として参照（重複定義しない） |

- **HO 分岐**: 差分提案まで AI-owned / 適用 Human（`responsibility-classes.md` に整合）。HO に一切触れない縮退案（非 HO の templates + docs のみで完結）も plan で比較する
- **fixture の形式**: サンプル plan（Case 1/2/3 の記入例）を第一候補とし、機械検証可能な検査（例: Knowledge Delta 節の条件判定）が生じる場合のみ `tests/extras/ta-NN` を追加（plan で確定）
- **River Review との分担**: issue verbatim の責務分担表を docs 説明側に転記し、用語（Knowledge Delta / Behavior Preservation）を両者で揃える。レビュー実装は持ち込まない

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| #810 未完了のまま着手し plan テンプレート + C-1 を二重改訂（非同期競合） | BLOCKED 構造で着手条件を機械的に明示（unblock = TASK-0810 C-4 merge） | 長期停滞時は C-3 論点 3 で順序入替を人間裁定（その場合 #810 側へ同居節の申し送り） |
| HO 対象（ai-dev-workflow.md / rules）への変更範囲拡大で AI が適用不能に | 差分提案まで AI-owned に固定（C-3 論点 1）+ HO patch は Human 適用に分割 | 非 HO（templates / docs / fixture）のみへ縮退し、HO 側は followup issue |
| 適用条件が緩く全タスクが重くなる（AC-10 違反・Non-goals「全タスク必須化」抵触） | Case 1 fixture で省略経路（Knowledge Delta 簡潔 / 省略）を明示検証 | 条件付き節を opt-in（該当条件宣言時のみ要求）へ弱める |
| 既存部品との二重実装（review-gate / refactor_verify / V-2 Iron Law） | AC-12 突合表で機械確認 + C-2 コードベース整合レーン | 重複検出時は参照統合へ置換（本 PBI 側を削る） |
| 記録層で表現力不足が発覚（decision-log / handoff で足りない） | Case 2/3 サンプルで記載規約の充足を確認 | 棚卸しコメントどおり「不足の実測」を根拠に additive なフィールド追加を後続 issue 化 |

### Unknowns

- AC-5 充足方式（参照統合 vs C-1 追加）→ **C-3 で確定**（論点 2）
- Knowledge Delta の配置（#810 拡張節と同居 vs 独立節）→ C-3 / plan で確定（論点 4）
- Behavior Preservation の配線先（V-1 条件項目 vs todo E 完了条件）→ plan で確定（論点 5）
- fixture 形式（サンプル plan vs `tests/extras/ta-NN`）→ plan で確定
- HO 差分提案の対象範囲（ai-dev-workflow.md C-1 のみか、review-principles.md 等 rules も含むか）→ plan で確定

### Assumptions

- 変更対象（非 HO・AI 完結）: `docs/working/templates/plan.md`（条件付き Knowledge Delta 節）/ todo・Work Breakdown 規約（分割パターン A〜E）/ `docs/refactoring-knowledge-sync.md`（新設・仮称。`docs/` 直下 = 非 HO。トップレベル `docs/ai/*.md` は HO のため置かない）/ Case 1〜3 サンプルまたは fixture。変更対象（HO・差分提案まで）: `.claude/commands/ai-dev-workflow.md`（C-1 項目案）/ `.claude/rules/*.md`（運用注記案）。確定パス一覧と HO 区分は C-3 論点 1 の表を正とする。既存正本（review-gate SKILL / evidence-tdd-ledger / code-optimizer Iron Law / #810 pbi-input）は変更しない
- **Mode: critical で確定**（`mode-classification.md` の機械判定: **受入基準数 = issue verbatim 10 + In scope 対応 2 = 12 → 11+ で超高（critical）が決定論**。定性基準でも「ワークフロー定義変更」= critical 対象例に該当し同判定。変更ファイル数は plan テンプレ + todo 規約 + docs + fixture 複数 + HO 差分提案で 6-15（高）。「各軸の最大値を採用」で critical 確定）。**autonomous APPROVE 不可・人間 C-3 必須・V-4 リリース前チェック要**。事前調査の「high-risk〜critical 見込み」は AC 数の機械判定で critical へ確定（hedge しない）。HO 対象パス（`.claude/commands/*.md` / `.claude/rules/*.md`）に実適用が及ぶ場合は **Hardening Override 発火**（lite_eligible 無効化・Standard 同期 C-3・HO patch の Human 適用）が追加で確定
