# TEST CASES — TASK-1005

> 対象: backlog admission control / Reliability Recovery 1 execution contract
> 実装コードのテストではなく、運用契約が一意に判定可能であることを検証する acceptance scenarios。

## Traceability

| AC | Test Cases |
|---|---|
| AC-01 | TC-01〜TC-04 |
| AC-02 | TC-05〜TC-07 |
| AC-03 | TC-08〜TC-09 |
| AC-04 | TC-10〜TC-12 |
| AC-05 | TC-13 |
| AC-06 | TC-14 |
| AC-07 | TC-15〜TC-16 |
| AC-08 | TC-17 |
| AC-09 | TC-18 |
| AC-10 | TC-19 |
| AC-11 | TC-20 |
| AC-12 | TC-21 |

## Lifecycle / Admission

### TC-01: Finding は自動で Committed にならない

**Given** 実装中に非 blocker の改善候補を発見した

**When** active Issue / PR の Discovery Log に記録した

**Then** milestone slot、plan WIP、implementation WIP を消費しない

**And** Human triage 前に plan を作成しない

### TC-02: Critical finding は即時に独立 Issue 化できる

**Given** 承認迂回、secret exposure、data loss の再現証拠がある

**When** finding を記録する

**Then** Discovery Log 待ちにせず独立 Issue 化できる

**And** priority / commitment / C-3 は Human が決定する

### TC-03: Qualified の不足項目を検出する

**Given** Current / Expected はあるが既存実装との差分と negative control がない Issue

**When** Discovery → Qualified を要求する

**Then** promotion は blocked

**And** 不足項目が明示される

### TC-04: Priority は commitment を意味しない

**Given** priority:P1 だが plan package がない Issue

**When** current milestone への着手を要求する

**Then** Committed ではないと判定する

## WIP

### TC-05: Plan WIP 上限

**Given** plan authoring が2件進行中

**When** 3件目の Qualified Issue を plan 開始しようとする

**Then** 新規開始を止め、既存 plan の review / completion を優先する

### TC-06: Emergency interrupt

**Given** implementation WIP が2件で上限

**And** critical approval bypass が発見された

**When** emergency work を commit する

**Then** Human が既存1件を decommit / pause して slot を空ける

**And** limit を暗黙に3へ増やさない

### TC-07: Milestone 8件超過

**Given** current milestone に8件 Committed

**When** 9件目を追加しようとする

**Then** Human が既存 item を Backlog へ戻すまで追加しない

## Reliability Recovery sequence

### TC-08: #921 が先行する

**Given** #921 未完了

**When** failure propagation に依存する negative-control evidence を完了扱いにしようとする

**Then** evidence は信頼不足として blocked

### TC-09: Foundation 全完了待ちを要求しない

**Given** #921 が完了

**And** 異なる欠陥クラスの negative control が2件成立

**And** implementation WIP に空きがある

**When** #978 の Human C-3 が承認される

**Then** 残りの foundation Issue が open でも #978 を開始できる

## Negative controls

### TC-10: #921 standalone failure propagation

**Given** extras test に intentional failure を注入

**When** standalone 実行する

**Then** output に failure があり rc != 0

**And** harness source 実行は runner を途中 exit しない

### TC-11: #997 observation fidelity

**Given** operation 前から無関係な untracked run file が存在

**When** classifier が existing record を変更しない

**Then** test は PASS

**When** classifier が existing record を1 byte変更する mutation を注入

**Then** test は FAIL

### TC-12: #994 target condition mutation

**Given** file 内の unset line に `PG_HARNESS_SOURCED` token が残る

**When** target `if` condition を `FIXTURES_DIR` 単独へ戻す mutation を注入

**Then** static guard test は FAIL

## #978 Vertical Slice

### TC-13: Start gate

**Given** #921 未完了、または negative-control class が1件以下、または WIP満杯

**When** #978 を開始しようとする

**Then** start は blocked

### TC-14: Source provenance boundary

**Given** downstream repository に own `ho-paths.md` がなく bundled template のみ解決可能

**When** arbiter が HO source を解決

**Then** `source_kind=bundled_template` を記録

**And** patterns が非空でも `HUMAN_ESCALATED / HO_BOUNDARY_UNDEFINED`

**Given** PlanGate self-run

**Then** bundled template を正当 source として従来動作を維持

**And** #906 domain-gate と #916 common evaluator を本実装へ含めない

## Scope split / writeback

### TC-15: 未充足 AC の単純先送り

**Given** 元 Issue の AC-3 が未実装

**When** AC-3 を follow-up Issue にコピーしただけで元 Issue を close しようとする

**Then** close は blocked

### TC-16: 正式 scope split

**Given** Human が AC-3 を独立 invariant と判断

**When** split_reason、元AC、移管先AC、元Issueのcompletion boundaryを記録

**Then** 残りACが完全充足していれば元 Issue を close 可能

### TC-17: Merge 後 writeback

**Given** PR が merge 済み

**When** Issue に PR/evidence、AC実績、未充足、follow-up理由、completion class がない

**Then** workflow 上は Done ではない

## Concept issues

### TC-18: 未成熟な大型構想

**Given** Current implementation、Desired invariant、Alternatives、Human decision、implementation trigger がない構想 Issue

**When** Committed へ昇格しようとする

**Then** blocked

**And** RFC / Discussion 相当へ分類する

## Metrics

### TC-19: 2-cycle review

**Given** 2つの delivery cycle が完了

**When** WIP limit を見直す

**Then** Discovery→Qualified、triage time、Qualified→plan、C-3/C-4 wait、fully satisfied close、follow-up ratio、writeback ratio、negative-control rate、WIP exceed time が記録済み

**And** limit 変更は metric と Human decision に紐づく

## Trace / Human boundary

### TC-20: Target Issue writeback

**Given** TASK-1005 の C-3 package を提出

**Then** #921、#997、#994、#942、#978 に #1005 link、entry condition、required evidence、out-of-scope がある

### TC-21: AI authority negative test

**Given** TASK-1005 の plan / docs / comments

**When** `AI approve`, `auto merge`, `AI milestone commitment`, `AI applies HO` に相当する経路を検索

**Then** 該当する許可契約が0件

**And** C-3 / C-4 / merge / HO apply / commitment は Human-owned と明記される

## Exit Test

TASK-1005 の planning phase は次で完了する。

- [ ] TC-01〜TC-21 が plan/doc/comment で判定可能
- [ ] C-2 review が完了
- [ ] Human C-3 decision point が明確

TASK-1005 全体は、planning phase だけでは close しない。TC-19 の2-cycle measurement と Human WIP review までを completion boundary とする。
