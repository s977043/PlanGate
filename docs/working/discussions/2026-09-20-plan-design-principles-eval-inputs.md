# Plan Design Principles Eval — Generator Inputs

- Issue: #1337
- Purpose: #1335 / PR #1336 の before/after paired evaluation 用の **generator-visible input**。
- Visibility: 本ファイルは **operator-side source**。generatorには本ファイル全体をmountせず、選択1ケースからmaterializeした `pbi-input.md`、共通依頼、対象variantの ai-dev-plan Skill / bundled referencesだけを渡す。
- Prohibited for generator: 他7ケース、本source全文、rubric、期待挙動、失敗例、他 trial の出力、採点結果。
- All scenarios below are synthetic evaluation facts, not production requirements.

## Execution contract

各 run は独立コンテキストで実施する。

共通依頼:

> 次の PBI INPUT PACKAGE から、対象Skillが要求する Plan / ToDo / Test Cases を作成してください。実装・外部操作・承認記録作成はしないでください。提供された Evidence / Assumption / Unknown を区別してください。対象 variant の ai-dev-plan と、その variant と同じ repo SHA から解決した参照規約に従ってください。実行していないコマンド・テスト・測定を成功したと主張しないでください。

- 対話は行わない。B-1で確認が必要なら Questions / Unknowns として出力する。
- fixtureに無い事実をネットワークや別repoから補完しない。
- generator sandbox から reviewer-only rubric を読める状態にしない。
- baseline/candidateで同一の本ファイル bytes を使用し、input hash を ledger に記録する。
- plan / todo / test-cases のうち、評価対象は主に plan と test-cases。todo生成有無は対象 Skill の契約に従う。
- Metrics Evidence が fixture から実測不能なら、未取得・非該当・追加調査必要を明示し、架空値を作らない。

## Materialization contract

本ファイルそのものを `ai-dev-plan` の入力ファイルとして渡さない。各runのoperatorは、選択した1ケースだけを**意味変更なし**で次の実体へmaterializeする。

- PDP-01 → `docs/working/TASK-EVAL-PDP01/pbi-input.md`
- PDP-02 → `docs/working/TASK-EVAL-PDP02/pbi-input.md`
- PDP-03 → `docs/working/TASK-EVAL-PDP03/pbi-input.md`
- PDP-04 → `docs/working/TASK-EVAL-PDP04/pbi-input.md`
- PDP-05 → `docs/working/TASK-EVAL-PDP05/pbi-input.md`
- PDP-06 → `docs/working/TASK-EVAL-PDP06/pbi-input.md`
- PDP-07 → `docs/working/TASK-EVAL-PDP07/pbi-input.md`
- PDP-08 → `docs/working/TASK-EVAL-PDP08/pbi-input.md`

frontmatterは固定する。

```yaml
---
task_id: TASK-EVAL-PDPXX
artifact_type: pbi-input
schema_version: 1
status: draft
---
```

case blockは、固定wrapperへ機械的に写す。

```markdown
# PBI INPUT PACKAGE — TASK-EVAL-PDPXX

## Context / Why
<Context / Why を逐語コピー>

## What — Scope

### In scope
<In scope を逐語コピー>

### Out of scope
<Out of scope を逐語コピー>

## Acceptance Criteria
<Acceptance Criteria を逐語コピー>

## Notes from Refinement

### Evidence
<Evidence を逐語コピー>

## Estimation Evidence

**Risks**: fixtureに明記がなければ `未評価 — Planで判断`
**Unknowns**: <Unknowns を逐語コピー>
**Assumptions**: <Assumptions を逐語コピー>
```

規則:
- 要約・言い換え・追加仕様を行わない。
- baseline/candidateで**同一bytesのmaterialized pbi-input.md**を使う。
- materialized fileのSHA256をrun ledgerへ記録する。
- generator workspaceには選択した1ケースのmaterialized PBIだけを置き、本8ケース一覧やreviewer rubricを置かない。
- `ai-dev-plan` が要求するその他の通常参照は対象variantと同一SHAから解決する。
- materialization差分が生じたpairは比較不能として `INCONCLUSIVE`。

---

## PDP-01 — light wording change

### Context / Why
保存ボタンの表示文言だけを、現在の「送信」から「保存」へ変える。

### In scope
- static HTML 上の表示文言

### Out of scope
- submit挙動の変更
- JS selector変更
- i18n導入
- 共通Button framework導入

### Acceptance Criteria
- AC01: 表示が「保存」になる
- AC02: submit動作を維持する
- AC03: button id=`save` を維持する

### Evidence
- E01: button は `type=submit`, `id=save`
- E02: 現在の JS は `id=save` を参照している
- E03: 多言語対応要件はない

### Unknowns
- なし

### Assumptions
- fixture外のデザイン変更要求はない

---

## PDP-02 — new behavior

### Context / Why
Python に `is_even(n)` を追加する。

### In scope
- 整数の偶奇判定
- unit test

### Out of scope
- 外部I/O
- provider/interface新設
- 入力型の拡張

### Acceptance Criteria
- AC01: 偶数は true
- AC02: 奇数は false
- AC03: 0 と負数を含む

### Evidence
- E01: 呼び出し側で整数入力が保証される
- E02: 例 — `0 -> true`, `-2 -> true`, `3 -> false`
- E03: 外部I/Oなし

### Unknowns
- なし

### Assumptions
- 既存API互換性への影響なし

---

## PDP-03 — bug fix

### Context / Why
税込5000円ちょうどで送料無料にならない回帰を修正する。

### In scope
- 送料無料境界条件
- regression test

### Out of scope
- 税計算方式変更
- 配送strategy全面再設計

### Acceptance Criteria
- AC01: 4999円 -> 送料500円
- AC02: 5000円 -> 送料0円
- AC03: 5001円 -> 送料0円

### Evidence
- E01: 承認済み仕様は「税込5000円以上は送料0円、未満は500円」
- E02: 現在観測は `4999 -> 500`, `5000 -> 500`, `5001 -> 0`

### Unknowns
- なし

### Assumptions
- 他の料金ルールは今回変更しない

---

## PDP-04 — behavior-preserving refactor

### Context / Why
`format_total` 内のローカル変数 `tmp` を `total_cents` に改名し、意味を明確にする。

### In scope
- ローカル変数名変更

### Out of scope
- 公開API変更
- 金額丸め変更
- 永続化形式変更
- 金額処理全体の再設計

### Acceptance Criteria
- AC01: 既存の外部挙動を変えない
- AC02: ローカル変数名を `total_cents` にする

### Evidence
- E01: 既存testは `0 -> "0.00"`, `105 -> "1.05"` で GREEN
- E02: 公開API・丸め・永続化形式の変更要求はない

### Unknowns
- 既存testが全外部挙動を網羅するかは未確認

### Assumptions
- 追加characterizationが必要なら不足箇所だけを対象にする

---

## PDP-05 — external provider boundary

### Context / Why
決済API timeout時の扱いを安全にする。

### In scope
- timeout時の状態分類
- 二重課金防止
- 必要な回復/照会の計画

### Out of scope
- provider追加
- 将来3社向けfactory/registry
- 根拠のない自動retry

### Acceptance Criteria
- AC01: timeoutを即「課金失敗確定」と扱わない
- AC02: 二重課金を防ぐ
- AC03: 不明状態から安全に確認/回復できる計画を持つ

### Evidence
- E01: 現在providerは1社
- E02: provider境界は既存 `PaymentClient` に集約済み
- E03: timeout時は課金成立が不明

### Unknowns
- U01: providerのidempotencyサポートは未確認
- U02: 課金状態照会APIの有無は未確認

### Assumptions
- U01/U02を推測で埋めない

---

## PDP-06 — persisted schema change

### Context / Why
persisted JSON の `display_name` を `name` へ移行する。

### In scope
- 24時間の旧新reader共存
- migration / rollback
- 互換性検証

### Out of scope
- 即時の旧key削除
- 共存期間短縮

### Acceptance Criteria
- AC01: 24時間の共存期間に旧readerを壊さない
- AC02: 新readerは移行中データを読める
- AC03: rollback可能

### Evidence
- E01: 旧readerは `display_name` 必須
- E02: 新readerは `display_name` と `name` の両方を読める
- E03: 両readerは24時間共存する

### Unknowns
- 切替後の旧key削除日は未確定

### Assumptions
- 旧key削除は本変更の完了条件に含めない

---

## PDP-07 — speculative abstraction

### Context / Why
商品一覧と監査ログ一覧のラベルをそれぞれ1箇所変更する。

### In scope
- 2画面のラベル変更

### Out of scope
- 一覧基盤の共通化
- GenericListManager新設
- 第三consumer想定

### Acceptance Criteria
- AC01: 指定2ラベルだけ変更する

### Evidence
- E01: 両画面には形の似た map 処理がある
- E02: 一方は商品、一方は監査ログで変更理由は独立
- E03: 共通API要件なし
- E04: 第三consumer要件なし

### Unknowns
- なし

### Assumptions
- コード形状の類似だけでは同じbusiness ruleを意味しない

---

## PDP-08 — invented invariant

### Context / Why
CSV export の既存列末尾へ `created_at` を追加する。

### In scope
- column追加
- 既存列位置/値の維持

### Out of scope
- row sort変更
- 行順contract追加

### Acceptance Criteria
- AC01: 既存列の位置と値を維持する
- AC02: `created_at` を末尾へ追加する

### Evidence
- E01: 仕様は列順だけ定義する
- E02: 行順保証は仕様にない
- E03: 現在はDBが返した順でexportする
- E04: 固定fixture例は `id=42`, `created_at=2026-09-20T00:00:00Z`

### Unknowns
- なし

### Assumptions
- 行順はテストの判定条件ではない
