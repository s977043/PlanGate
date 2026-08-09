# TASK-1025 Execution TODO

> Mode: critical / lite_eligible: false
> C-3: PENDING
> delegation_commit_boundary: no-commit

## Phase 1: TDD contract

- [ ] T-01 RED: state初期化と別process復元testを追加
  - Owner: agent
  - depends_on: []
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: test method名とAC-01対応を確認
  - rollback: 新規test fileをrevert
- [ ] T-02 RED: revision CAS / stale writer testを追加
  - Owner: agent
  - depends_on: [T-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: expected / actual revisionをassert
  - rollback: T-02のtest commitをrevert
- [ ] T-03 RED: Human request stable ID / duplicate抑止testを追加
  - Owner: agent
  - depends_on: [T-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: record intent数が1で固定されるassertを確認
  - rollback: T-03のtest commitをrevert
- [ ] T-04 RED: Human / External receipt bindingと再消費拒否testを追加
  - Owner: agent
  - depends_on: [T-03]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: task / plan / source / action全不一致ケースを列挙
  - rollback: T-04のtest commitをrevert
- [ ] T-05 RED: state / record tamper、unknown enum、chain break testを追加
  - Owner: agent
  - depends_on: [T-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: 各破損が制御errorになるassertを確認
  - rollback: T-05のtest commitをrevert
- [ ] T-06 RED実行証跡を保存
  - Owner: agent
  - depends_on: [T-01, T-02, T-03, T-04, T-05]
  - files: `docs/working/TASK-1025/evidence/tdd/red.log`
  - checkpoint: failure原因がmodule/interface不存在に限定
  - rollback: evidence fileのみrevert

## Phase 2: Durable state core

- [ ] T-07 enum / required keys / transition contractを実装
  - Owner: agent
  - depends_on: [T-06]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: `contract` outputをtestで固定
  - rollback: 新規moduleをrevert
- [ ] T-08 canonical state digest / record hash chainを実装
  - Owner: agent
  - depends_on: [T-07]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: load時の全件再計算を確認
  - rollback: T-08のcommitをrevert
- [ ] T-09 atomic writerとrevision CASを実装
  - Owner: agent
  - depends_on: [T-08]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: temp + flush + fsync + replace + directory fsyncを確認
  - rollback: T-09のcommitをrevert
- [ ] T-10 init / request_waitと冪等pending actionを実装
  - Owner: agent
  - depends_on: [T-09]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: duplicate要求でrevision / recordが増えないことを確認
  - rollback: T-10のcommitをrevert

## Phase 3: Receipt / resume

- [ ] T-11 Human C-3 strict read-only validatorを実装
  - Owner: agent
  - depends_on: [T-10]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: approvalsへのwrite callが0件
  - rollback: T-11のcommitをrevert
- [ ] T-12 External receipt validatorを実装
  - Owner: agent
  - depends_on: [T-10]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: task / plan / source / action / statusをstrict照合
  - rollback: T-12のcommitをrevert
- [ ] T-13 receipt entry / resume / duplicate消費拒否を実装
  - Owner: agent
  - depends_on: [T-11, T-12]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: pending clearとRUNNING遷移が同一atomic state write
  - rollback: T-13のcommitをrevert
- [ ] T-14 CLI `contract|init|request|status|resume`を実装
  - Owner: agent
  - depends_on: [T-13]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: unknown / missing argsはexit 2、contract errorはexit 3
  - rollback: CLI adapter部分のみrevert

## Phase 4: Contract / verification

- [ ] T-15 Durable Run Contract文書を作成
  - Owner: agent
  - depends_on: [T-14]
  - files: `docs/workflows/ai-loop/durable-run-contract.md`
  - checkpoint: implementation `contract` outputとのenum / transition一致
  - rollback: 新規文書をrevert
- [ ] T-16 GREEN unit testを実行・保存
  - Owner: agent
  - depends_on: [T-14]
  - files: `docs/working/TASK-1025/evidence/tdd/green.log`
  - checkpoint: 0 failures / exit 0
  - rollback: evidence fileのみrevert
- [ ] T-17 ai-loop regressionを実行・保存
  - Owner: agent
  - depends_on: [T-16]
  - files: `docs/working/TASK-1025/evidence/verification/ai-loop-regression.log`
  - checkpoint: delivery / run_evidence 0 failures
  - rollback: evidence fileのみrevert
- [ ] T-18 boundary / diff検査を実行・保存
  - Owner: agent
  - depends_on: [T-15, T-17]
  - files: `docs/working/TASK-1025/evidence/verification/`
  - checkpoint: approval write / merge経路0、diff check exit 0
  - rollback: evidence filesのみrevert
- [ ] T-19 C-2 plan findingsの実装反映漏れを監査
  - Owner: agent
  - depends_on: [T-18]
  - files: `docs/working/TASK-1025/review-external.md`, `docs/working/TASK-1025/status.md`
  - checkpoint: R-NNN全件 disposition済み
  - rollback: 監査記録の誤りはappend訂正し履歴を消さない

## Human tasks

- [ ] H-01 確定Plan hashをHuman C-3で承認
  - Owner: human
  - depends_on: [C-1, C-2]
  - files: `docs/working/TASK-1025/approvals/c3.json`
  - checkpoint: source=cli / APPROVED / plan hash一致
  - rollback: REJECTED / CONDITIONALを正規CLIで記録しexecしない
- [ ] H-02 PRをC-4レビューしmerge可否を判断
  - Owner: human
  - depends_on: [全Agent task, CI, review]
  - files: GitHub PR
  - checkpoint: CI / findings / conflict / plan drift / evidence確認
  - rollback: mergeせずREQUEST_CHANGES
