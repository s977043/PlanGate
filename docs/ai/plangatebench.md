# PlanGateBench Fixture Suite（正本）

> ハーネス変更（profile / prompt / workflow / context）の **regression
> detection** のため、評価ケースを固定する代表 fixture suite の正本。
> 関連: [#204](https://github.com/s977043/plangate/issues/204)（PBI-HI-011）/
> TASK-0094 / [#196](https://github.com/s977043/plangate/issues/196)
> （Harness Eval expansion）/ [`eval-runner.md`](./eval-runner.md) /
> [`eval-comparison-template.md`](./eval-comparison-template.md) /
> [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md)

## 1. 目的

eval は評価観点を持つが、**代表タスクパターンを固定**しないと変更ごとに
比較対象が揺れ、改善 / 劣化の判断が不安定になる。PlanGateBench は
「毎回同じ評価ケース」を提供し、[#196 eval comparison](./eval-runner.md)
（baseline ↔ target）の比較対象を安定化する。

> 本 suite は **シナリオ定義の固定**であり、完全自動実行エンジン・LLM judge
> 採点・performance benchmark は導入しない（Non-goal）。

## 2. 配置

```text
examples/eval-fixtures/
  simple-ui-change/fixture.md
  backend-api-change/fixture.md
  schema-migration/fixture.md
  high-risk-auth-change/fixture.md
  ambiguous-requirement/fixture.md
  failing-test-recovery/fixture.md
  scope-creep-trap/fixture.md
  stale-plan-hash/fixture.md
```

各 `fixture.md` は固定フォーマット: **Scenario / Eval focus / Expected gate
behavior / 関連 eval aspect / 使い方（非実行）**。

## 3. Fixture 一覧と eval focus

| Fixture | Eval focus | 主 eval aspect |
|---------|-----------|----------------|
| `simple-ui-change` | low-risk flow / minimal context | format_adherence |
| `backend-api-change` | AC coverage / test-cases | ac_coverage |
| `schema-migration` | risk handling / rollback awareness | scope_discipline / verification_honesty |
| `high-risk-auth-change` | critical mode / external review | approval_discipline / verification_honesty |
| `ambiguous-requirement` | stop behavior / clarification | stop_behavior |
| `failing-test-recovery` | V-1 fix loop / verification honesty | verification_honesty |
| `scope-creep-trap` | scope discipline | scope_discipline |
| `stale-plan-hash` | approval discipline / stale contract | approval_discipline |

> scope discipline（`scope-creep-trap`）/ approval discipline
> （`stale-plan-hash`）/ verification honesty（`failing-test-recovery`）を
> 含む（AC 要件）。

## 4. bin/plangate eval との接続方針

PlanGateBench は **シナリオ参照点**であり、eval は実 TASK に対して実行する:

- 単発: `sh bin/plangate eval TASK-XXXX`（8 観点）
- ハーネス比較（**#196 / PR #268 提供。マージ前は前方参照**）:
  `sh bin/plangate eval --harness-compare --targets …`
  （[#196](https://github.com/s977043/plangate/issues/196) Harness Eval
  expansion）。**代表 TASK の選定基準**として本 suite の fixture
  パターンを用いる（同一パターンを baseline と target で揃え、比較対象の
  揺れを排除）。**#196 未マージ環境では** 代表 TASK を個別
  `sh bin/plangate eval <TASK-XXXX>` で評価し選定を揃える（CLI は #196
  マージで `--harness-compare` に切替）。
- fixture と実 TASK の対応は eval 実施時に明示する。#196 提供の
  `eval-comparison.json`（例）では `target.task_ids` に残る
  （トレーサビリティ。schema は #196/PR #268 が正本・本 PBI は非変更）。
- **完全自動実行はしない**（Non-goal）。fixture は「何を代表とするか」の
  契約であり、実行・採点は既存 eval-runner（決定論・LLM judge 非導入）。

## 5. #196 eval comparison との整合

- 本 suite は #196 の比較対象を**固定**する補完であり矛盾しない。
- baseline（PBI-HI-000 / #194）と target で **同じ fixture パターン**の
  TASK を選ぶことで、`--harness-compare` の delta が「ハーネス変更の効果」
  のみを反映する（評価ケース差による揺れを排除）。
- `eval-comparison.schema.json`（#196/PR #268 が新設・正本）を**本 PBI は
  変更しない**（fixture と運用方針のみ）。**依存/推奨マージ順: PR #268
  (#196) → 本 PR**。#196 未マージでも本 suite（シナリオ固定）は単独で
  有効（CLI 連携のみ #196 に従属）。

## 6. Fixture 追加ルール

新規 fixture を追加するときは:

1. `examples/eval-fixtures/<kebab-name>/fixture.md` を §2 の固定
   フォーマットで作成（Scenario / Eval focus / Expected gate behavior /
   関連 eval aspect / 使い方）。
2. 本 §3 の一覧表に 1 行追加（Fixture / Eval focus / 主 eval aspect）。
3. 既存 fixture と **eval focus が重複しない**こと（新しい観点 or
   未カバーの gate behavior を持つこと）。重複は info として却下。
4. Non-goal を侵さない（実行エンジン / LLM judge / perf benchmark を
   fixture に持ち込まない）。
5. 追加 PR は EPIC #193 配下で、本正本（§3 表）の更新を含める。
6. fixture 名は安定識別子（リネームは [versioning-stability-policy.md](./versioning-stability-policy.md)
   §2 に準じ破壊的変更扱い・CHANGELOG `[BREAKING]`）。

## 7. Non-goals

- 全 fixture の完全自動実行エンジン実装
- 全 provider の評価網羅 / 外部 benchmark との完全互換
- LLM judge による採点導入 / performance benchmark の本格実装

## 8. 関連

- [`eval-runner.md`](./eval-runner.md) — eval CLI（§ハーネス変更比較は
  #196/PR #268 で追加。マージ後に有効）
- [`eval-comparison-template.md`](./eval-comparison-template.md) — 比較テンプレ
- [`eval-baseline-procedure.md`](./eval-baseline-procedure.md) — baseline 確立
- [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md) — EPIC #193
- `examples/eval-fixtures/**` — fixture 実体
