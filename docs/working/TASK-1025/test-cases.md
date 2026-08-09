# TASK-1025 Test Cases

## Acceptance Criteria Mapping

| AC | Test Case |
|---|---|
| AC-01 | TC-01, TC-02 |
| AC-02 | TC-03 |
| AC-03 | TC-04, TC-05 |
| AC-04 | TC-06, TC-07 |
| AC-05 | TC-08〜TC-11 |
| AC-06 | TC-12〜TC-15 |
| AC-07 | TC-16 |
| AC-08 | TC-17, TC-18 |
| AC-09 | TC-19 |
| AC-10 | TC-20〜TC-22 |

## Test Cases

### TC-01: 別processによるstate復元

- 前提: temp task dir、revision 0の初期state
- 入力: process Aでinit、process Bでstatus/load
- 期待: run ID、task ID、revision、plan hash、source SHA、harness versionがbyte-equivalentに復元される
- 種別: integration / restart

### TC-02: pending action復元

- 前提: `WAITING_HUMAN`、pending action 1件
- 入力: moduleを再importしてload
- 期待: status、current node、action ID、instructions refが一致する
- 種別: unit / restart

### TC-03: Human requestのstable action ID

- 前提: `RUNNING` revision 0
- 入力: kind=human、action kind=c3_approval、同一binding
- 期待: sha256形式のaction ID、intent 1件、status=`WAITING_HUMAN`
- 種別: unit

### TC-04: 同一Human requestの冪等再提示

- 前提: TC-03完了後
- 入力: 現revisionで同一requestを再実行
- 期待: 同一action ID、revision不変、intent数1、event=`human_request_reissued_prevented`
- 種別: regression

### TC-05: 異なるrequestのpending中発行拒否

- 前提: Human pending actionあり
- 入力: action kindまたはbindingが異なるrequest
- 期待: `pending_action_conflict`、state / record不変
- 種別: negative

### TC-06: Human C-3 receiptの一度だけ消費

- 前提: pending human actionとsource=cli / APPROVED / task・plan一致c3 fixture
- 入力: action ID、expected revision、current source SHA、receipt path
- 期待: receipt 1件、pending action null、status=`RUNNING`、revision+1
- 種別: unit

### TC-07: receipt再消費拒否

- 前提: TC-06完了後
- 入力: 同一action ID / receipt
- 期待: `receipt_already_consumed`、record増分0
- 種別: negative

### TC-08: task ID mismatch

- 入力: c3 fixtureのtask IDを別TASKへ変更
- 期待: `resume_binding_mismatch`、state不変
- 種別: negative / security

### TC-09: plan hash mismatch

- 入力: c3 fixtureのplan hashを変更
- 期待: `resume_binding_mismatch`、state不変
- 種別: negative / security

### TC-10: source SHA drift

- 入力: current source SHAをstateと異なる値にする
- 期待: `resume_binding_mismatch`、receipt未記録
- 種別: negative / security

### TC-11: action ID mismatch / 別Run流用

- 入力: 別Runで生成したaction IDまたはreceipt
- 期待: `resume_binding_mismatch`、receipt未記録
- 種別: negative / security

### TC-12: state JSON破損

- 入力: truncated JSON
- 期待: `state_corrupt`、tracebackではなく制御error、state上書きなし
- 種別: negative

### TC-13: state digest改変

- 入力: bodyだけ変更しdigestを維持
- 期待: `state_corrupt`
- 種別: negative / tamper

### TC-14: record chain break

- 入力: middle entryのprev IDまたはentry IDを変更
- 期待: `record_corrupt`
- 種別: negative / tamper

### TC-15: unknown enum / revision後退 / stale writer

- 入力: unknown status、negative revision、expected revision不一致
- 期待: `state_corrupt`または`revision_conflict`、writeなし
- 種別: boundary

### TC-16: approval write / merge経路の不存在

- 入力: module source / public command contract
- 期待: `approvals/**` write、c3生成、C-4生成、merge commandが存在しない
- 種別: static / security

### TC-17: External request / receipt正常系

- 前提: `WAITING_EXTERNAL`とbinding済みreceipt fixture
- 入力: task / plan / source / action一致、status=`SUCCEEDED`
- 期待: receipt 1件、`RUNNING`へ復帰
- 種別: unit

### TC-18: External receipt不一致

- 入力: status失敗、binding欠落、unknown key、別action ID
- 期待: fail-closed、state不変
- 種別: negative

### TC-19: #1023 TTY消失回帰

- 前提: process AがHuman requestを記録して終了、receiptなし
- 入力: process Bが同じrequestを再開
- 期待: 新nonce / 新actionを生成せず、既存action IDとWAITING_HUMANを返す
- 種別: E2E fixture / regression

### TC-20: 新規unit suite

- command: `python3 -m unittest scripts/ai-loop/test_durable_run.py`
- 期待: exit 0、0 failures
- 種別: automated

### TC-21: 既存ai-loop regression

- command: `python3 -m unittest scripts/ai-loop/test_delivery.py scripts/ai-loop/test_run_evidence.py`
- 期待: exit 0、0 failures
- 種別: regression

### TC-22: diff integrity

- command: `git diff --check`
- 期待: exit 0
- 種別: static

## Edge Cases

- empty / non-object JSON
- unknown top-level key / missing required key
- boolをint revisionとして受理しない
- zero / negative revision
- empty action kind / instructions ref / receipt ref
- same payload with different requested timestamp
- duplicate intent but missing receipt
- receipt exists but result artifact is unreadable
- c3 statusがREJECTED / CONDITIONAL / unknown
- c3 sourceがcli以外
- symlinked receipt pathによるtask dir外参照
- atomic replace前のwrite例外
