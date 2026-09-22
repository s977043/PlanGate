# Plan Design Principles Eval — Reviewer-only Rubric

- Issue: #1337
- Visibility: **reviewer / adjudicator only**。generatorへ渡してはならない。
- Freeze rule: paired generation開始後は判定基準を変更しない。変更が必要なら評価versionを上げ、既存runと混ぜない。
- Verdicts: PASS / FAIL / NOT_APPLICABLE / INCONCLUSIVE。
- Unknown / missing evidence / unexecuted verification を PASS に変換しない。

## Blind review contract

1. reviewerへ渡す出力から baseline/candidate 名を隠す。
2. reviewerは generator と別担当にする。
3. reviewerは当該runで使った materialized PBI、raw output、本rubricだけを使用する。他caseやvariant identityは採点前に見ない。
4. variant identity は採点完了後に開示する。
5. reviewer間不一致は adjudication と理由を ledger に残す。
6. evidence excerpt は短い抜粋または位置参照で残し、結論だけを書かない。

## Common axes

| Axis | PASS | FAIL |
| --- | --- | --- |
| current_need | 新規 abstraction/interface/dependency/extension がAC・制約・E-IDへtraceされる | 将来予測・コード類似・架空consumerだけで追加 |
| contract_source | Contract/InvariantとTestの存在理由が明示sourceへtraceされる | Testを正当化するためInvariantを創作 |
| verification_strategy | change typeに合う事前/事後証拠 | 全変更に機械的RED-first、または必要なREDを省略 |
| conditional_guidance | 該当するfailure/compat/security等だけ展開 | 全観点を儀式的に展開、または該当リスクを無視 |
| b2_comparison | 2案以上を実質比較し採否理由がある | modeを理由にB-2全省略、名目だけ2案 |
| scope_honesty | fixture外事実をUnknownとして扱い、未実行を未実行と書く | 架空の測定/テスト成功/仕様/ファイルを主張 |
| output_load | materialな判断だけを出す | 空section/N/A/無関係testが大量増加 |

## Case expectations

### PDP-01
PASS:
- literal直接修正と既存pattern踏襲など、軽量な2案以上を比較
- submit/id維持を検証
- deterministic diff/DOM確認を計画
- light変更を機能基盤化しない

FAIL:
- i18n基盤、汎用Button framework新設
- B-2省略
- 実行していないUI確認を成功扱い

Diagnostics:
- plan文字数
- 空/N/A section数
- ACにtraceしないtest数

### PDP-02
PASS:
- new behavior判定
- AC由来 RED -> minimum implementation -> GREEN
- 0/負数/奇数偶数の期待値sourceをAC/E-IDへtrace

FAIL:
- provider/interface導入
- 入力検証を新要件として発明
- 実装式そのものをexpected sourceにする

### PDP-03
PASS:
- E01の仕様とE02の観測回帰を分離
- 5000のregression RED -> fix -> GREEN
- 4999/5001も境界保持確認

FAIL:
- 現在の誤動作をInvariant扱い
- 税/配送全体再設計
- regression reproduction省略

### PDP-04
PASS:
- existing GREEN -> refactor -> GREEN / behavior preservation
- 追加characterizationは既存証拠の不足分だけ

FAIL:
- REDを作るため挙動を壊す
- 金額処理全面刷新
- 全refactorへ大量新規testを一律強制

### PDP-05
PASS:
- timeoutを成立不明として扱う
- idempotency/照会APIはUnknown
- 既存PaymentClient境界を再利用
- retry/repair/replan/escalateの安全条件を分ける

FAIL:
- 無条件retry
- idempotencyを架空仕様として採用
- 将来provider用factory/registry
- 既存境界を「単一providerだから不要」と削除

Critical regression:
- 二重課金につながるretry案

### PDP-06
PASS:
- old/new reader coexistenceを前提にmigration/cutover/rollback比較
- 旧reader、新reader、rollbackをverificationへ含める

FAIL:
- 即時旧key削除
- 新reader unit testだけで互換性PASS
- rollbackを実証方法なしで「可能」と断定

Critical regression:
- 共存中の旧readerを壊す提案

### PDP-07
PASS:
- 直接修正と共通化を比較
- code similarity と knowledge/change reason を区別
- 現在根拠がなければ共通化しない
- 「抽象化は常に禁止」と一般化しない

FAIL:
- GenericListManager追加
- 架空第三consumer
- 根拠ある既存共通化まで一律禁止

### PDP-08
PASS:
- 列契約とfixture値へtrace
- 行順Invariantを作らない
- 順序非依存assertを選べる

FAIL:
- 常にID昇順という契約を創作
- sort実装を追加
- 架空仕様ファイル引用

Critical regression:
- 架空Evidenceを根拠にcontractを追加

## Pair-level comparison

Caseごとに3 trialを集約する。

- Regression:
  - critical regression が1件以上、または
  - candidateの必須axis FAILがbaselineより増加
- Improvement signal:
  - critical regression 0
  - 必須axisで新規回帰なし
  - unsupported abstraction / invented invariant / wrong verification strategy のFAIL件数が減少
  - PDP-01で無関係test/空sectionが増加していない
- No demonstrated difference:
  - baseline/candidateが同等。両者PASSでも「改善」とは呼ばない
- INCONCLUSIVE:
  - activation不明、条件不一致、raw output欠測、blind review未実施、variant漏洩

## Pilot diagnostics

- PDP-01の文字数中央値がbaseline比20%以上増えた場合、内容レビューを必須にする。
- 20%はpilotの調査閾値でありproduction Gateではない。
- 3 trialsは初期診断であり、統計的有意差や一般化された効果を主張しない。
