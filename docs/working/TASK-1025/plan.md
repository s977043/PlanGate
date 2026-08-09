---
task_id: TASK-1025
artifact_type: plan
schema_version: 1
status: ready_for_review
mode: critical
lite_eligible: false
related_issue: https://github.com/s977043/PlanGate/issues/1025
created_by: orchestrator
---

# TASK-1025 Implementation Plan

## Goal

ai-loopの現在状態と未完了actionをプロセス外へ永続化し、Human / External待機後に別Agent・別Sessionが同一requestから安全かつ冪等に再開できるDurable Run State v1を実装する。

## Context

- 背景: #1023 / PR #1024でTTY入力ハンドル消失後にnonceを反復発行し、承認疲労と誤配送リスクが顕在化した。
- 関連Issue: https://github.com/s977043/PlanGate/issues/1025
- Parent Epic: https://github.com/s977043/PlanGate/issues/870
- 関連artifact: `pbi-input.md` / `test-cases.md` / `decision-log.jsonl`
- 既存パターン: `scripts/ai-loop/delivery.py` のstable action ID、intent / receipt、append-only record、fail-closed検証

## Scope

### In Scope

- JSON stateとhash-chain付きappend-only recordの契約
- revision compare-and-swap、atomic replace、read-time validation
- `RUNNING` / `WAITING_HUMAN` / `WAITING_EXTERNAL` / `BLOCKED` / `COMPLETED`
- Human / External requestのstable action IDと冪等再提示
- Human C-3 artifactとExternal receiptのread-only検証
- restart / duplicate / tamper / binding mismatch / stale writerのunit tests
- Durable Run Contract文書

### Out of Scope

- `bin/plangate`統合、schema追加、hook / policy / HO変更
- c3.json、Human approval receipt、C-4、mergeの生成
- GitHub API / CI polling / daemon
- RunEvidence producerや#869 Evolution実装への直接配線
- 過去TASK stateのmigration

## Global Constraints

- C-3成立前にproduction fileを変更しない。
- Python標準ライブラリ以外を追加しない。
- `scripts/ai-loop/durable_run.py`は`approvals/**`へ書き込まない。
- mutationは`expected_revision`不一致を拒否し、暗黙のlast-write-winsを許さない。
- state / recordの未知キー、未知enum、chain不一致、binding不一致はfail-closedにする。
- timestampはCLI入力で注入し、純粋な判定関数内で現在時刻を取得しない。
- stateは同一directoryへの一時write + flush + fsync + `os.replace`で更新する。
- action IDはtimestampを含まないcanonical payloadから生成する。
- C-3 / C-4 / merge / HO / policyのHuman-owned境界を変更しない。

## 前提の実測検証（#786）

| 前提 | 検証コマンド | 実測結果 | 判定 |
|---|---|---|---|
| mainの正本SHA | `git rev-parse HEAD` | `9f9af9451e396eec52b7a737ac3db3166ff60fb1` | ✅ |
| intent / receiptの既存実装 | `rg -n "def action_id|def entry_id|def append_entries" scripts/ai-loop/delivery.py` | 3関数とreceipt抑止ロジックを確認 | ✅ |
| ai-loop script数 | `rg --files scripts/ai-loop | wc -l` | 30 | ✅ |
| ai-loop contract文書数 | `rg --files docs/workflows/ai-loop | wc -l` | 16 | ✅ |
| 変更先のrollout境界 | `rg -n "判定基盤 carve-out|scripts/ai-loop" docs/workflows/ai-loop/rollout-policy.md` | scripts / docs corpusはHuman escalate固定 | ✅ |

## Questions / Unknowns（#786）

- 該当なし。`bin/plangate`への正式統合、JSON Schema昇格、Human receiptの署名強化は別PBIで判断する。

## 確認事項（B-1）

- Q1: 自己改善全体を一括実装するか。A: しない。今回の実害を直接防ぐDurable Runの最小縦切りに限定する。
- Q2: Human承認を会話経由に変更するか。A: 変更しない。既存CLI artifactをread-onlyで消費する。
- Q3: stateの正本をMarkdownにするか。A: しない。JSONを機械正本、Markdownを人間向けviewとする。

## Metrics Evidence

| 指標 | 見積り | 実測 / 計画値 | ratio | 判定 |
|---|---:|---:|---:|---|
| production変更ファイル | 3 | 3 | 1.0 | 採用 |
| 新規module | 1 | 1 | 1.0 | 採用 |
| 新規unit test file | 1 | 1 | 1.0 | 採用 |
| 既存関連module | 2 | `delivery.py` / `c3_contract.py` | 1.0 | read-only再利用 |

「全件」系の対象はない。scopeはproduction 3ファイルに固定する。

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | `delivery.py`へpre-PR stateを直接統合 | intent / receiptを即再利用 | PR後の収束責務とpre-PR run責務が混在し、回帰範囲が広い | 不採用 |
| B | 独立`durable_run.py`でcontractを実証し、既存canonical hashだけ再利用 | 最小差分、単体検証可能、将来adapterで段階統合可能 | v1では`plangate resume`へ未接続 | 採用 |
| C | `bin/plangate`とschemasへ最初から統合 | UXが一つのCLIに揃う | HO 3層を同時変更しblast radiusが大きい | 不採用 |

### Recommended Approach

案Bを採用する。state transitionとI/Oを独立moduleで固定し、既存`c3_contract.canonical_hash`を再利用する。Human承認は既存artifactをread-onlyで検証し、本moduleからは発行しない。初回PRでrestart・idempotency・tamper・bindingを十分に検証後、CLI adapter / schema昇格を別Human判断へ分離する。

## Files / Components to Touch

| ファイル | 操作 | 目的 | 公開インターフェース / 依存 |
|---|---|---|---|
| `scripts/ai-loop/durable_run.py` | create | state transition、atomic I/O、intent / receipt、CLI | `init_run`, `request_wait`, `resume_run`, `load_state`, `load_record` |
| `scripts/ai-loop/test_durable_run.py` | create | AC-01〜AC-09のunit / regression | `unittest` |
| `docs/workflows/ai-loop/durable-run-contract.md` | create | 状態・遷移・binding・責務境界の正本 | implementation contract |

## Work Breakdown

### Task 1: Contract-first failing tests

**Purpose**: restart・idempotency・binding・tamperの期待を実装前に固定する。

**Files**:

- Create: `scripts/ai-loop/test_durable_run.py`
- Test target: `scripts/ai-loop/durable_run.py`

**Interfaces**:

- Consumes: `c3_contract.canonical_hash`
- Produces: AC-01〜AC-09を表すfailing tests

**Steps**:

- [ ] state初期化 / 別process読込 / revision CASのtestsを追加する
- [ ] Human / External requestのstable action ID / duplicate抑止testsを追加する
- [ ] c3 receipt / external receipt / binding mismatch testsを追加する
- [ ] state / record tamper / unknown enum / chain break testsを追加する
- [ ] `python3 -m unittest scripts/ai-loop/test_durable_run.py` がmodule未実装理由でFAILすることを記録する

**Completion Criteria**:

- [ ] 各ACが具体的なtest methodへ対応している
- [ ] RED理由が「module不存在またはinterface不存在」に限定される

**Rollback**:

- 新規test fileのみを当該commitのrevertで除去する。既存testは変更しない。

### Task 2: Durable state core

**Purpose**: state / recordの検証、stable ID、atomic persistence、CASを最小実装する。

**Files**:

- Create: `scripts/ai-loop/durable_run.py`
- Test: `scripts/ai-loop/test_durable_run.py`

**Interfaces**:

- Consumes: `c3_contract.canonical_hash`
- Produces: `contract_dict`, `init_run`, `load_state`, `load_record`, `request_wait`

**Steps**:

- [ ] enum / required keys / transition表と純粋validatorを実装する
- [ ] self digest付きstateとprev-entry chain付きrecordを実装する
- [ ] temporary file + fsync + replaceのatomic writerを実装する
- [ ] expected revisionのcompare-and-swapを実装する
- [ ] stable request payload / action IDと同一pending requestの冪等返却を実装する
- [ ] core testsをGREENにする

**Completion Criteria**:

- [ ] restart後にstate / pending actionを復元できる
- [ ] stale writer、corrupt state、record chain不一致が制御されたerrorになる

**Rollback**:

- moduleと対応testを同一commitのrevertで戻す。既存state形式へのmigrationはない。

### Task 3: Receipt verification and resume

**Purpose**: Human / External receiptをread-onlyで検証し、pending actionを一度だけ消費する。

**Files**:

- Modify: `scripts/ai-loop/durable_run.py`
- Modify: `scripts/ai-loop/test_durable_run.py`

**Interfaces**:

- Consumes: pending action、legacy Human C-3 JSON、external receipt JSON
- Produces: `resume_run`、receipt entry、`RUNNING` state

**Steps**:

- [ ] Human C-3 receiptをstrict JSONでtask / status / plan hash / source=cliへ束縛する
- [ ] current source SHAをstateへ照合し、driftを拒否する
- [ ] External receiptをtask / plan / source / action ID / success statusへ束縛する
- [ ] receipt entryをintentへ束縛し、receipt済みactionの再消費を拒否する
- [ ] binding mismatch / duplicate /別Run流用testsをGREENにする

**Completion Criteria**:

- [ ] Human / External両経路で正規receiptのみ一度消費できる
- [ ] 本moduleが`approvals/**`へwriteするコードを持たない

**Rollback**:

- Task 3のcommitをrevertし、Task 2のWAITING state生成のみへ戻す。

### Task 4: Contract documentation and verification

**Purpose**: 実装と利用者の責務境界を一意にし、回帰を検証する。

**Files**:

- Create: `docs/workflows/ai-loop/durable-run-contract.md`
- Verify: `scripts/ai-loop/test_durable_run.py`

**Interfaces**:

- Consumes: Task 2 / 3のcontract output
- Produces: 状態表、遷移表、request / receipt binding、CLI examples、non-goals

**Steps**:

- [ ] state / record / transition / failure codeを文書化する
- [ ] Human-owned境界と`approvals/**` read-only制約を明記する
- [ ] restart・duplicate・tamper・binding fixtureを文書のAC表へ対応させる
- [ ] targeted regressionと`git diff --check`を実行する

**Completion Criteria**:

- [ ] contract outputと文書のenum / transitionが一致する
- [ ] AC-01〜AC-10のevidenceを保存できる

**Rollback**:

- contract文書とmodule / testをPR単位でrevertする。外部state migrationはない。

## Verification Plan

Verification Automation: `python3 -m unittest scripts/ai-loop/test_durable_run.py && python3 -m unittest scripts/ai-loop/test_delivery.py scripts/ai-loop/test_run_evidence.py && git diff --check`

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence保存先 |
|---|---|---|---|
| RED | `python3 -m unittest scripts/ai-loop/test_durable_run.py` | 実装前はexpected import/interface failure | `evidence/tdd/red.log` |
| Unit | `python3 -m unittest scripts/ai-loop/test_durable_run.py` | 0 failed | `evidence/tdd/green.log` |
| Regression | `python3 -m unittest scripts/ai-loop/test_delivery.py scripts/ai-loop/test_run_evidence.py` | 0 failed | `evidence/verification/ai-loop-regression.log` |
| Contract | `python3 scripts/ai-loop/durable_run.py contract` | 文書と同一enum / transition | `evidence/verification/contract.json` |
| Static boundary | `rg -n "approvals.*write|merge|c4" scripts/ai-loop/durable_run.py` + code review | approval write / merge経路0 | `evidence/verification/boundary.log` |
| Diff | `git diff --check` | exit 0 | `evidence/verification/diff-check.log` |

### レビューレーン計画（#786）

| 成果物 | レーン（観点/独立性） | unavailable 時の代替 |
|---|---|---|
| Plan Package | Makerと会話contextを共有しない独立Checker: contract / security / testability | C-2 unavailableをWARN記録しHuman C-3へ未充足リスクを提示 |
| 実装diff | Makerと別contextの独立Checker: tamper / self-approval / concurrency | targeted adversarial fixture + Human C-4 |

## Plan Review Readiness

### Success Criteria

- AC: `test-cases.md` TC-01〜TC-15
- Completion boundary: 独立module・tests・contract文書・evidenceをPRへ含める。CLI/schema/Evolution接続は別PBI。

### Review Criteria

- Design alignment: #873/#917のintent / receipt / deterministic / fail-closedを踏襲し、pre-PR責務を分離する。
- Test expectations: restart、same-request idempotency、stale writer、tamper、binding mismatch、duplicate receiptを値レベルで検証する。
- Security: approval artifactはread-only、source=cli、APPROVED、task / plan / current source bindingを必須にする。
- Maintainability: standard libraryのみ、pure validationとI/Oを分離し、error codeをenum化する。
- Backward compatibility: 既存CLI / state / delivery recordを変更せずadditiveに導入する。
- Operational risk: v1は手動adapterであり、正式入口へ未接続であることを明記する。

### Required Context

- Referenced issues: #870 / #873 / #874 / #869 / #920 / #923 / #938 / #945 / #981 / #982 / #1023 / #1025
- ADR / docs: `docs/workflows/ai-loop/rollout-policy.md`、`docs/workflows/ai-loop/delivery-state-machine.md`
- Existing implementation: `scripts/ai-loop/delivery.py`、`scripts/ai-loop/c3_contract.py`
- Related tests: `scripts/ai-loop/test_delivery.py`、`scripts/ai-loop/test_run_evidence.py`
- Constraints: ai-loop判定基盤carve-out、C-3/C-4/merge Human-owned、HO path変更禁止

### Non-goals and Scope Boundary

- Out of scope: CLI / schema / hook / policy / migration / daemon / merge
- Change-prohibited zones: `bin/plangate`、`schemas/**`、`scripts/hooks/**`、`.claude/**`、`docs/ai/**`
- Forbidden new dependencies: すべて。Python標準ライブラリのみ。

## Replan Triggers

以下に該当した場合はexecを止め、plan更新・C-1/C-2再実行・C-3再承認を行う。

- production変更が3ファイルを超える
- `bin/plangate` / schema / hook / policy / HOへの変更が必要になる
- existing `delivery.py`または`run_evidence.py`の変更が必要になる
- Human C-3 artifactの追加fieldまたは生成経路変更が必要になる
- targeted baseline testに1件以上のFAILがある
- receiptをapproval artifactへ安全に束縛できずAC-04/05/07が同時成立しない
- atomic write / CASを標準ライブラリだけで成立させられない

## Stop Condition

- Human C-3未承認
- C-2でcritical / major findingが未解決
- approval自己発行、merge、policy変更につながる設計が必要
- rollback不能、外部権限、秘密情報、破壊操作が必要
- RED / GREEN evidenceを保存できない

## Human Approval Boundary

- Security-sensitive changes: receipt検証・approval boundary隣接のためHuman C-3 / C-4必須
- Auth / billing / permissions: 変更しない。必要になれば別PBIで停止
- Production operations: 実施しない
- Data deletion / migration: 実施しない
- Irreversible changes: 実施しない
- Policy / HO / Core Contract: 変更しない

## Mode判定

- mode: `critical`
- lite_eligible: `false`
- 根拠: production変更は3ファイルで可逆だが、`scripts/ai-loop/**`と`docs/workflows/ai-loop/**`がrollout-policy §2の判定基盤carve-outに該当し、approval / resume境界へ隣接する。Human C-3へ固定escalateする。
