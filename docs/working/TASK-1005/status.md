# STATUS — TASK-1005

Last updated: 2026-08-05

## Current Phase

`PLAN_DRAFTED / C-2_NOT_STARTED / C-3_WAITING`

コード実装、HO apply、merge は未実施。

## Baseline Snapshot

| Metric | Value | Source / note |
|---|---:|---|
| Open Issues | 48 | 2026-08-05 backlog audit |
| Plan reached | 2 | 4.2% |
| PBI input only | 19 | 39.6% |
| No working directory | 27 | 56.3% |
| Never updated after creation | 33 | 68.8% |
| Partial resolution | 12 | close不可、AC一部充足 |
| June net change | -1 | opened 51 / closed 52 |
| July net change | +35 | opened 120 / closed 85 |
| Aug 1-4 net change | +13 | opened 18 / closed 5; +2.9/day |

## Proposed Queue Limits

| Queue | Limit | Current | Evidence status |
|---|---:|---:|---|
| Plan authoring | 2 | 未計測 | cycle 1から記録 |
| C-3 waiting | 2 | 未計測 | cycle 1から記録 |
| Implementation | 2 | 未計測 | cycle 1から記録 |
| C-4 waiting | 2 | 未計測 | cycle 1から記録 |
| Milestone committed | target 6 / max 8 | milestone 9に15件との棚卸し結果 | Human再裁定待ち |

## Reliability Recovery 1 Candidate Set

| Order | Issue | Role | Commitment status |
|---:|---:|---|---|
| 1 | #921 | failure signal integrity | proposed |
| 2 | #997 | operation前後のobservation fidelity | proposed |
| 3 | #994 | guardが実条件を観測するnegative control | proposed |
| 4 | #991 | canonical side全損guard | proposed; #970との実装競合を再確認 |
| 5 | #970 | guard/action set symmetry | proposed; #991との実装競合を再確認 |
| 6 | #942 | CI reachability / Human HO apply | proposed |
| 7 | #978 | vertical slice | proposed; start gate付き |
| reserve | #947 | interruption/accounting/relative-state | split review後にcommit判断 |

候補は7 + reserve 1で maximum 8。Human が milestone 9 の他Issueとの比較後に確定する。

## Start Gates

### #921

- Human C-3
- 対象 inventory の実測
- source / standalone 判別契約の確認
- intentional failure fixture 設計

### #978

- #921 completion
- 異なる欠陥クラスの negative-control evidence >= 2
- implementation WIP < 2
- #978 個別 plan の Human C-3

## Cycle Ledger Template

| Item | Qualified at | Committed at | Plan start/end | C-3 wait | Impl start/end | C-4 wait | Completion class | Follow-ups | Writeback |
|---|---|---|---|---|---|---|---|---:|---|
| Cycle 1 | | | | | | | | | |
| Cycle 2 | | | | | | | | | |

Completion class:

- `fully_satisfied`
- `partially_delivered`
- `moved_to_rfc`
- `not_planned`
- `superseded`

## Open Human Decisions

1. TASK-1005 C-3
2. milestone 9 のCommitted 6〜8件
3. lifecycle labelの表現方法
4. #991 / #970 の同一PR可否（同一canonical enumeratorを導入する場合のみ統合候補）
5. #947をRR1へcommitするかreserveのままにするか
6. #942 HO patch apply / test PR
7. 2-cycle後のWIP limit

## Completed in this planning session

- [x] #1005 created
- [x] pbi-input.md
- [x] plan.md
- [x] todo.md
- [x] test-cases.md
- [x] decision-log.jsonl
- [x] status.md baseline
- [ ] target Issue writeback
- [ ] draft PR
- [ ] C-2 review
- [ ] Human C-3
