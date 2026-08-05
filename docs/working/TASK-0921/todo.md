# EXECUTION TODO — TASK-0921

> Plan: [`plan.md`](./plan.md) / Tests: [`test-cases.md`](./test-cases.md)
> Mode: **high-risk**（全extrasの実行制御とexit contractを変更するためC-3必須）

## Dependency Graph

```text
H-01 Human C-3
  ↓
T-01 runtime inventory + trap audit
  ├─ conflict → REPLAN (explicit finalizer)
  └─ no conflict
       ↓
T-02 helper RED tests
  ↓
T-03 helper + runner loading
  ↓
T-04 harness-only migration ─┐
T-05 standalone migration ──┤
                             ↓
T-06 inventory/dynamic contract TA
  ↓
T-07 docs + #914/#921 writeback
  ↓
T-08 C-2 code review / verification
  ↓
H-02 Human C-4 / merge
```

## Human Tasks

- [ ] **H-01**: shared helper + standalone-only exit trap案のC-3
- [ ] **H-02**: broad migration PRのC-4 / merge
- [ ] **H-03**: trap競合時にfallback案Dへreplanする判断

## Agent Tasks

### Preparation

- [ ] **T-01: Runtime inventory**
  - `ta-*.sh` 全件をsortしてevidence保存
  - capability候補、fallback、counter、top-level exit/return、trap、cleanup、stdin readを表にする
  - #914対象11本とta-26を再確認
  - exact countはstatusへ記録するがtest期待値に埋め込まない
  - unclassifiedが1件でもあれば停止

### TDD: Shared Contract

- [ ] **T-02: RED tests**
  - harness mode no-op
  - harness-only direct → exit2 before body
  - standalone pass → 0
  - fail → 1
  - original nonzero rc preservation
  - early exit propagation
  - cleanup drain
  - force-fail target match/mismatch
  - invalid capability fail-closed

- [ ] **T-03: helper implementation**
  - create `_extra-contract.sh`
  - runner extras loop前にsource
  - POSIX `sh -n`
  - runner diffはhelper sourceに限定
  - synthetic tests GREEN
  - checkpoint commit

### Migration

- [ ] **T-04: harness-only migration**
  - exactly one capability marker
  - helper bootstrap/initをbody side effect前へ配置
  - direct execution loop: all rc2 + standard error
  - tmp/audit side effectがないこと
  - 10〜15 files単位のreviewable commits

- [ ] **T-05: standalone-capable migration**
  - marker + init
  - file固有root fallbackを保持
  - legacy counter/footer/cleanupをhelper contractへ移す
  - ta-26は最後に移行
  - ta-39 early exitを明示検証
  - 各batch後full suite

### Regression / Evidence

- [ ] **T-06: contract TA**
  - marker exactly-one
  - marker/init一致
  - harness-only dynamic all-files
  - standalone force-fail dynamic all-files
  - standalone normal dynamic all-files
  - source path full suite completion marker
  - self-recursion prevention
  - helper mutation M-01〜M-06

- [ ] **T-07: docs/writeback**
  - README rc table 0/1/2
  - capability selection checklist
  - standalone-only trap exception
  - `</dev/null` rule
  - #914 handoff V2 resolved
  - #921 AC evidence and actual inventory

- [ ] **T-08: final verification**
  - `sh -n`
  - full suite 3 runs
  - dirty environment run
  - interrupted standalone cleanup check
  - C-2 shell/test/workflow lanes
  - PR scope audit

## Commit Strategy

1. `test: add RED tests for extras execution contract`
2. `feat(tests): add shared extras standalone contract`
3. `fix(tests): reject direct execution of harness-only extras`（複数reviewable commits可）
4. `fix(tests): propagate standalone-capable failures`（複数reviewable commits可）
5. `test: enforce extras capability inventory`
6. `docs: define extras execution contract`

各commitは単独でfull suiteを壊さない順序にする。helper導入後、file migration中は未移行fileをcontract TA対象外にする暫定allowlistを置かず、contract TAは全移行と同commitまたは最後に追加する。中間commitをPR上でcheckout可能にする必要がある場合、migration status markerを明示し最終commitで0件を要求する。

## Stop / Escalation

- [ ] C-3前は実装しない
- [ ] source経路でexit trapが設定されたら停止
- [ ] standalone正常実行がhangしたらprocessを止め、stdin/外部dependencyを分類
- [ ] cleanupがrepo内pathを対象にしたら停止
- [ ] ta-26 regressionがhelperで解消できなければlegacy adapter案へreplan
- [ ] broad migration中にmainのextras変更と競合したらrebase後inventory再実測

## Completion

- [ ] test-cases TC-01〜TC-18 PASS
- [ ] mutation M-01〜M-06が期待どおりFAIL
- [ ] all files classified dynamically
- [ ] harness suite 0 failed
- [ ] Issue / handoff writeback
- [ ] Human C-4
