# TASK-1025 Execution TODO

> Mode: critical / lite_eligible: false
> C-3: PENDING
> delegation_commit_boundary: no-commit

## Human gate

- [ ] H-01 確定Plan hashをHuman C-3で承認
  - Owner: human
  - depends_on: [C-1, C-2]
  - files: `docs/working/TASK-1025/approvals/c3.json`
  - checkpoint: `source=cli` / `APPROVED` / task ID・Plan hash一致
  - rollback: `REJECTED` / `CONDITIONAL`を正規CLIで記録しexecしない

## Phase 1: TDD contract

- [ ] T-01 RED: restart / pending / block-unblock / terminal transition tests
  - Owner: agent
  - depends_on: [H-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: 別process復元、recoverable BLOCKEDのprior/pending保存とunblock復帰、arbiter terminal語彙との区別、COMPLETED terminal idempotency、禁止遷移を固定
  - rollback: 新規test fileをrevert
- [ ] T-02 RED: true concurrent CAS / task lock tests
  - Owner: agent
  - depends_on: [T-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: `subprocess` + `sys.executable`のbarrier 2 processで成功1 / `revision_conflict` 1 / fork 0、common-dir external lockと全ancestor rename/replacement拒否。禁止`multiprocessing`は使わない
  - rollback: T-02差分をrevert
- [ ] T-03 RED: WAL durable syscallごとのcrash / recovery tests
  - Owner: agent
  - depends_on: [T-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: bootstrap 8 + initial WAL 17 + request update 17 + Human resume update 17 + External resume update 17のexact labelを全列挙し、fault subcase=76をassert
  - rollback: T-03差分をrevert
- [ ] T-04 RED: stable request / duplicate suppression tests
  - Owner: agent
  - depends_on: [T-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: Human/External両requestでtask-wide action reservation 1件、同一payload再提示でaction ID・intent/ledger数・revision・manifest generationが増殖せず、消費済みrequestは完了済み結果をartifact不変で返してWAITINGへ戻らない
  - rollback: T-04差分をrevert
- [ ] T-05 RED: Human semantic authority / source binding tests
  - Owner: agent
  - depends_on: [T-04]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: JSON再整形・`^_`注釈・approved_at変更でも同一Plan authority、非`_`未知key・duplicate key/NaN拒否、same/cross-run再消費拒否、request SHAとactual HEADを分離したapproval-only descendant許可、初回検証後/prepare前のHEAD・dirty変更をartifact不変で拒否
  - rollback: T-05差分をrevert
- [ ] T-06 RED: External receipt one-shot / provenance boundary tests
  - Owner: agent
  - depends_on: [T-04]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: External request生成とcanonical receipt path、run binding、same/cross-run replay、same-action-different-result拒否、消費済みrequest完了応答、exact HEAD、untrusted producer limitを固定
  - rollback: T-06差分をrevert
- [ ] T-07 RED: manifest rollback / path / harness drift tests
  - Owner: agent
  - depends_on: [T-01]
  - files: `scripts/ai-loop/test_durable_run.py`
  - checkpoint: proper subset 14組、parent symlink/traversal/TOCTOU、hostile valid pyc/shadow/preloaded module/PYTHONPATH/sitecustomize、PATH/HOME/XDG/global+local Git config、loaded-source/loader/Python+Git fingerprint drift、linked worktree共有を拒否/確認
  - rollback: T-07差分をrevert
- [ ] T-08 RED evidence保存
  - Owner: agent
  - depends_on: [T-01, T-02, T-03, T-04, T-05, T-06, T-07]
  - files: `docs/working/TASK-1025/evidence/tdd/red.log`
  - checkpoint: failure原因がmodule/interface不存在に限定
  - rollback: evidenceのみrevert

## Phase 2: Git-common-dir durable core

- [ ] T-09 strict contract / transition / error taxonomy実装
  - Owner: agent
  - depends_on: [T-08]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: 5 status、許可遷移、WAITING→BLOCKEDのprior/pending保存と明示unblock復帰、arbiter terminal語彙との区別、COMPLETEDだけのterminal規則、state/record/ledger/manifest/transaction/receiptのduplicate key・non-standard number・未知key/enum拒否とC-3の`^_`注釈例外を`contract` outputで固定
  - rollback: 新規moduleをrevert
- [ ] T-10 canonical repository/runtime context + safe dirfd traversal + lock実装
  - Owner: agent
  - depends_on: [T-09]
  - files: `scripts/ai-loop/durable_run.py`, `scripts/ai-loop/gh_exec.py`, `scripts/ai-loop/test_gh_exec.py`
  - checkpoint: root-owned isolated Python main、private empty pycache prefix、exact SourceFileLoader identity、`gh_exec.run_git(..., isolated_env=True, binary_output=True)`のfixed `/usr/bin/git`・caller env全除去・fixed config override・exact read-only allowlist・既定caller互換、module anchor、bytes NUL parser、absolute/fallback common-dir、external lock、flat bootstrap、TASK exact 4桁、O_NOFOLLOW dirfd、全ancestor dev/ino再照合、unwritable preflight、CLI権威入力0
  - rollback: T-10差分をrevert
- [ ] T-11 state / record / ledger / task manifest cross-binding実装
  - Owner: agent
  - depends_on: [T-10]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: flat inventory、manifest generation/txと全run/ledger digest・count・tailが一致しないproper subset 14組を全拒否。record/ledgerも共通strict JSON loaderを通し、duplicate key・非標準数・未知key/event enumを拒否
  - rollback: T-11差分をrevert
- [ ] T-12 single task-wide redo WAL / recovery実装
  - Owner: agent
  - depends_on: [T-11]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: target allowlist・absent sentinel・old/new digest・full payload・task/run/generation binding、8 bootstrap / 17 WAL exact labelからsafe retryまたはroll-forward
  - rollback: T-12差分をrevert
- [ ] T-13 init / request / block / unblock / complete / duplicate no-op実装
  - Owner: agent
  - depends_on: [T-12]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: golden action ID、Human/External request idempotency、BLOCKED prior/pending保存とunblock復帰、COMPLETED terminal、integrity error非永続化、loaded-source + executable harness fingerprint保存
  - rollback: T-13差分をrevert

## Phase 3: Canonical receipt / resume

- [ ] T-14 legacy C-3 strict schema-equivalent validator実装
  - Owner: agent
  - depends_on: [T-13]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: 同一fd raw read/digest、required/type/phase/status/hash/allowed keys、トップレベル`^_`注釈key受理と非`_`未知key拒否、duplicate key/NaN/Infinity、空approved_by/不正approved_at拒否
  - rollback: T-14差分をrevert
- [ ] T-15 semantic Plan authority ledger + Human source policy実装
  - Owner: agent
  - depends_on: [T-14]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: exact domain-separated payload + golden ID、task+plan authorityを全Run一度消費、same HEADまたはC-3-only descendant/dirtyだけ許可。task lock内のprepare直前にHEAD-before / status・diff・ancestor / HEAD-afterを再観測し、初回snapshot同一の線形化点だけをrequest/actual/relation/raw digest証拠として保持
  - rollback: T-15差分をrevert
- [ ] T-16 canonical External receipt validator / one-shot ledger実装
  - Owner: agent
  - depends_on: [T-13]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: flat canonical path、exact payload + golden ID、task/run/action/plan/request/resume/result/SUCCEEDED、action ID + semantic IDの二重unique、result変異replay拒否、producer真正性非保証を返却contractへ明記
  - rollback: T-16差分をrevert
- [ ] T-17 transactional resume + harness drift guard実装
  - Owner: agent
  - depends_on: [T-15, T-16]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: receipt/source最終snapshot再照合後にledger/record/state/manifestが1 transaction、pending clear、RUNNING、Human/External resume各17 fault point、初回検証→prepare前barrierのHEAD/dirty競合はtransaction未作成、同一authorityを競合消費する2 runでsuccess 1/replay 1、全CLI operationでgh_exec.py + durable_run.py source/loaderとPython+Git executable fingerprint一致
  - rollback: T-17差分をrevert
- [ ] T-18 CLI `contract|init|request|status|resume|block|unblock|complete`実装
  - Owner: agent
  - depends_on: [T-17]
  - files: `scripts/ai-loop/durable_run.py`
  - checkpoint: usage=2、integrity=3、success=0。isolated operational CLIのみ、task/run/non-authoritative argsだけでpath/hash/SHA/receipt option/in-process mutation exportなし
  - rollback: CLI adapterのみrevert

## Phase 4: Contract / CI / verification

- [ ] T-19 Durable Run Contract作成
  - Owner: agent
  - depends_on: [T-18]
  - files: `docs/workflows/ai-loop/durable-run-contract.md`
  - checkpoint: isolated main + controlled source loader + 2 source/2 executable harness、`gh_exec` isolated Git context、common-dir external lock + flat layout/bootstrap、recoverable BLOCKEDとCOMPLETED terminal transition、manifest/WAL labels、canonical IDs、source policy、trust limits、TTY未接続を実装と一致
  - rollback: 新規文書をrevert
- [ ] T-20 標準CI extras / plugin sync導線追加
  - Owner: agent
  - depends_on: [T-18, T-19]
  - files: `tests/extras/ta-61-durable-run.sh`, `scripts/sync-plugin-plangate.sh`, `plugin/plangate/skills/ai-loop-cycle/references/durable-run-contract.md`, `plugin/plangate/skills/ai-loop-cycle/scripts/durable_run.py`, `plugin/plangate/skills/ai-loop-cycle/scripts/test_durable_run.py`, `plugin/plangate/skills/ai-loop-cycle/scripts/gh_exec.py`, `plugin/plangate/skills/ai-loop-cycle/scripts/test_gh_exec.py`
  - checkpoint: standalone/source両対応、isolated direct test実行、unit TC 42 + gh_exec boundary 4 exact method + shell TC 4、最低46 tests、fault 76/rollback 14、exact sentinel 1回、敵対Python/Git case、正規sync後plugin差分0、plugin direct operational `unsupported_runtime_layout`を確認
  - rollback: ta-61 / sync allowlist / plugin生成差分を同時revert
- [ ] T-21 GREEN unit/adversarial evidence
  - Owner: agent
  - depends_on: [T-18]
  - files: `docs/working/TASK-1025/evidence/tdd/green.log`
  - checkpoint: unit TC 42 + gh_exec boundary 4 exact method全実行、shell TC 4 mapping、46 tests以上、fault subcase 76、rollback subcase 14、0 failures、exit 0
  - rollback: evidenceのみrevert
- [ ] T-22 full suite evidence
  - Owner: agent
  - depends_on: [T-20, T-21]
  - files: `docs/working/TASK-1025/evidence/verification/full-suite.log`
  - checkpoint: `sh tests/run-tests.sh` exit 0、ta-61 sentinel到達
  - rollback: evidenceのみrevert
- [ ] T-23 targeted ai-loop regression evidence
  - Owner: agent
  - depends_on: [T-21]
  - files: `docs/working/TASK-1025/evidence/verification/ai-loop-regression.log`
  - checkpoint: delivery / run_evidence / check_exec_boundary 0 failures
  - rollback: evidenceのみrevert
- [ ] T-24 boundary / refs / approval tree / diff evidence
  - Owner: agent
  - depends_on: [T-19, T-22, T-23]
  - files: `docs/working/TASK-1025/evidence/verification/`
  - checkpoint: CLI前後のapproval tree・Git refs同一、write instrumentation 0、`git diff --check` 0
  - rollback: evidenceのみrevert
- [ ] T-25 C-2 findings実装反映監査
  - Owner: checker
  - depends_on: [T-24]
  - files: `docs/working/TASK-1025/review-external.md`, `docs/working/TASK-1025/status.md`
  - checkpoint: R-001〜R-007 / R-101〜R-131 / N-001〜N-004の全findingがdiff+testへ紐付き、critical/major 0
  - rollback: 監査記録はappend訂正し履歴を消さない
- [ ] T-26 evidence / handoff / Draft PR整備
  - Owner: agent
  - depends_on: [T-25]
  - files: `docs/working/TASK-1025/`
  - checkpoint: AC-01〜AC-10、Plan列挙のroot正本7 + plugin生成5の計12ファイル、未接続/真正性/whole rollback/cross-clone残リスクをverify-then-report
  - rollback: working artifact差分のみrevert

## Final Human gate

- [ ] H-02 PRをC-4レビューしmerge可否を判断
  - Owner: human
  - depends_on: [T-26, CI, review]
  - files: GitHub PR
  - checkpoint: CI / findings / conflict / Plan drift / evidence / trust limits確認
  - rollback: mergeせずREQUEST_CHANGES
