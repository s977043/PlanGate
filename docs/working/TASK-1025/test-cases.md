# TASK-1025 Test Cases

## Acceptance Criteria Mapping

| AC | Test Case |
|---|---|
| AC-01 | TC-01, TC-02 |
| AC-02 | TC-03 |
| AC-03 | TC-04, TC-05, TC-32 |
| AC-04 | TC-06〜TC-09, TC-28〜TC-30 |
| AC-05 | TC-10〜TC-15, TC-27, TC-43, TC-45 |
| AC-06 | TC-16〜TC-26, TC-33〜TC-36, TC-43〜TC-45 |
| AC-07 | TC-31, TC-37 |
| AC-08 | TC-02〜TC-04, TC-28〜TC-30, TC-46 |
| AC-09 | TC-32 |
| AC-10 | TC-38〜TC-46 |

## Machine Coverage Manifest

`scripts/ai-loop/test_durable_run.py::COVERAGE_MANIFEST`は次の42組とbyte-for-byte同じID/method mappingを持つ。ta-62はunittest loaderの実method IDへ照合し、欠落・重複・余剰mappingを拒否する。

| TC | exact unittest method |
|---|---|
| TC-01 | `test_tc01_restart_across_process` |
| TC-02 | `test_tc02_pending_action_restore` |
| TC-03 | `test_tc03_stable_request_action_id` |
| TC-04 | `test_tc04_duplicate_request_noop` |
| TC-05 | `test_tc05_pending_conflict` |
| TC-06 | `test_tc06_human_c3_consumption` |
| TC-07 | `test_tc07_human_semantic_replay` |
| TC-08 | `test_tc08_same_run_replay` |
| TC-09 | `test_tc09_cross_run_replay` |
| TC-10 | `test_tc10_strict_json_and_task_id` |
| TC-11 | `test_tc11_task_plan_mismatch` |
| TC-12 | `test_tc12_human_source_policy_allowed` |
| TC-13 | `test_tc13_human_source_policy_rejected` |
| TC-14 | `test_tc14_action_run_mismatch` |
| TC-15 | `test_tc15_c3_no_follow_toctou` |
| TC-16 | `test_tc16_state_strict_validation` |
| TC-17 | `test_tc17_record_chain_validation` |
| TC-18 | `test_tc18_ledger_chain_validation` |
| TC-19 | `test_tc19_manifest_cross_binding` |
| TC-20 | `test_tc20_all_14_proper_subset_rollbacks` |
| TC-21 | `test_tc21_true_concurrent_cas` |
| TC-22 | `test_tc22_external_lock_and_ancestor_replacement` |
| TC-23 | `test_tc23_bootstrap_and_initial_wal_fault_matrix` |
| TC-24 | `test_tc24_update_wal_fault_matrix` |
| TC-25 | `test_tc25_cross_run_recovery_before_cas` |
| TC-26 | `test_tc26_corrupt_and_stale_transaction` |
| TC-27 | `test_tc27_cli_and_git_context_injection` |
| TC-28 | `test_tc28_external_receipt_consumption` |
| TC-29 | `test_tc29_external_action_one_shot` |
| TC-30 | `test_tc30_external_binding_mismatch` |
| TC-31 | `test_tc31_no_approval_or_git_mutation` |
| TC-32 | `test_tc32_module_duplicate_regression` |
| TC-33 | `test_tc33_isolated_source_runtime_fingerprint` |
| TC-34 | `test_tc34_block_preserves_and_unblocks` |
| TC-35 | `test_tc35_complete_terminal_transition` |
| TC-36 | `test_tc36_integrity_error_not_blocked_state` |
| TC-37 | `test_tc37_trust_limit_contract` |
| TC-38 | `test_tc38_suite_coverage_manifest` |
| TC-43 | `test_tc43_linked_worktree_shared_domain` |
| TC-44 | `test_tc44_canonical_id_golden_vectors` |
| TC-45 | `test_tc45_common_dir_fallback_and_unwritable_preflight` |
| TC-46 | `test_tc46_consumed_request_idempotency` |

`tests/extras/ta-62-durable-run.sh::SHELL_COVERAGE_MANIFEST`は次の4組を固定する。

| TC | exact command / evidence |
|---|---|
| TC-39 | isolated direct unit commands exit 0 + unit manifest 42 + GH boundary 4 + ≥46 tests + exact ta-62 sentinel |
| TC-40 | `sh tests/run-tests.sh` exit 0 + ta-62 sentinel exactly once |
| TC-41 | isolated delivery/run_evidence unittest command exit 0 |
| TC-42 | `git diff --check` exit 0 |

`scripts/ai-loop/test_gh_exec.py`には次のisolated mode境界4 methodをexact必須化する。

| support ID | exact unittest method |
|---|---|
| GH-01 | `test_isolated_git_uses_fixed_binary_and_clean_env` |
| GH-02 | `test_isolated_git_injects_config_after_authorization` |
| GH-03 | `test_isolated_git_binary_output_and_argv_allowlist` |
| GH-04 | `test_default_run_git_behavior_is_unchanged` |

## Restart / request / terminal

### TC-01: 別process復元
- process Aでinit後に終了しprocess Bでloadする。
- run/task/revision/plan/source/harness digest、manifest generation、record tailが一致する。

### TC-02: pending action復元
- `WAITING_HUMAN`と`WAITING_EXTERNAL`を別processで読み、action ID / instructions ref / source bindingが一致する。

### TC-03: stable request action ID
- Human/External各kindでtimestampを除くcanonical payloadが同じなら`sha256:` action ID、intent 1件、task-wide ledgerの`action_reserved` 1件を同一transactionで得る。

### TC-04: duplicate request no-op
- Human/External各kindの同一request再提示でaction ID、revision、record count、ledger reservation count、manifest generationが不変、response event=`request_reissued_prevented`。

### TC-05: pending conflict
- pending中の異なるaction kind / instructions refを`pending_action_conflict`で拒否し全artifact不変。

## Human semantic Plan authority

### TC-06: Human C-3正常消費
- canonical C-3をstrict検証し、既存`action_reserved`を参照する`action_consumed` eventへsemantic authority ID、raw digest、run/action、request source、actual HEADを1件記録する。action lifecycle totalは2件となり`RUNNING`へ戻る。

### TC-07: JSON再整形による再消費回避を拒否
- whitespace / key order / `_note` / `approved_at`を変更してraw digestが変わっても、同じtask+plan authority IDとして拒否する。

### TC-08: same-run再消費拒否
- 同じPlan authorityを同一runで再消費すると`receipt_already_consumed`、全artifact不変。

### TC-09: cross-run再消費拒否
- Run A消費後にRun Bが同じtask+plan authorityを消費すると`approval_authority_already_consumed`。

### TC-10: legacy C-3 schema相当検証
- non-object / malformed UTF-8 JSON / required欠落 / 型不正 / phase不一致 / 空approved_by / approved_at不正 / unknown非`_` keyを拒否する。
- 実`bin/plangate approve`が生成する`_approved_by_source` / `_approver_identity_unverified` / `_note`を含むトップレベル`^_`注釈キーは受理し、semantic authority ID入力には含めない。非`_`未知キーは拒否する。
- duplicate keyを`object_pairs_hook`、`NaN` / `Infinity` / `-Infinity`を`parse_constant`で拒否する。同じstrict loaderをC-3、External receipt、state、record、ledger、manifest、transactionへ適用する。
- task IDは`TASK-[0-9]{4}`だけを許可し、3桁/5桁/英字をlegacy schema受理前に拒否する。

### TC-11: task / plan mismatch
- task IDまたは実plan bytesがC-3と不一致なら`resume_binding_mismatch`、ledger不変。

### TC-12: Human source policy正常系
- dirty/untracked pathがcanonical C-3 pathのsubsetであることを両relationの前提とする。`request_source_sha`と内部観測`actual_resume_head`が同一ならrelation=`same`を許可する。request SHAの子孫でcommit/worktree差分の和集合がcanonical C-3 pathだけならrelation=`c3_only_descendant`を許可し、両SHAとrelationをledgerへ保存する。
- 初回検証後、task lock内のWAL prepare直前に`HEAD-before → status/diff/ancestor → HEAD-after`を再観測する。前後HEADが一致し、path集合・relation・HEADが初回snapshotと同一なら、この最終snapshotをsource relationの線形化点として保存する。

### TC-13: Human source policy異常系
- 非ancestor、C-3以外のcommit差分、C-3以外のdirty/untracked path、NUL解析を壊す改行入りfilenameを含む未承認source relationを拒否する。
- Human / External両経路で初回source検証直後にbarrierを置き、別processがprepare前にHEADを進める、またはdirty/untracked pathを追加する。最終snapshotが初回と異なる場合は`source_context_changed`、receipt未消費、transaction未作成、state/record/ledger/manifest不変をassertする。

### TC-14: action / run mismatch
- pendingにないaction、別run actionを拒否する。

### TC-15: canonical C-3 no-follow / TOCTOU
- task/approvals parent symlink、leaf symlink、path traversal、open後差替えをdirfd traversal・inode/digest再照合で拒否する。

## Manifest / concurrency / WAL

### TC-16: state strict validation
- truncated JSON、digest改変、unknown status/key、bool/負revisionを`state_corrupt`で拒否する。

### TC-17: record chain validation
- middle改変、reorder、duplicate、truncation、別run chainを拒否する。
- record JSONLのduplicate key、`NaN` / `Infinity` / `-Infinity`、unknown key、unknown event kindを各々拒否し、共通strict loaderを経由しない実装ではFAILする値レベルassertを置く。

### TC-18: ledger chain validation
- semantic ID/raw digest entry改変、reorder、duplicate、truncation、別task chainを拒否する。
- ledger JSONLのduplicate key、`NaN` / `Infinity` / `-Infinity`、unknown key、unknown event kindを各々拒否し、共通strict loaderを経由しない実装ではFAILする値レベルassertを置く。

### TC-19: task manifest cross-binding
- manifestのgeneration/tx、run state/record digest・count・tail、ledger digest・count・tailのどれかが不一致なら拒否する。

### TC-20: proper subset rollback全組合せ
- 同一generationの`state`, `record`, `ledger`, `manifest`について非空proper subset全14組（$2^4-2$）を旧snapshotへ戻し、全保存領域同時rollback以外をmanifest mismatchで拒否する。実行subcase数が14であること自体をassertする。

### TC-21: true concurrent CAS
- barrier 2 writerで成功1、`revision_conflict` 1、generation +1、record fork 0。

### TC-22: external lock / ancestor replacement
- common-dir直下task lock取得後にlock leaf、task root、`durable-run`、`plangate`の各rename+replacementをbarrier注入する。held common-dirから全dev/ino再照合して`runtime_path_changed`、writer 2は同じexternal lockで待機し別lock/ledger domainを作らない。

### TC-23: bootstrap + initial transaction crash matrix
- common-dir external lock create/fsyncと各mkdir/parent fsyncのexact 8 bootstrap label後にfaultを入れ、empty task rootから同じcommon-dir lock inode domainへretryする。unknown file・orphan sibling・symlinkはcleanupせず`bootstrap_conflict`。
- target absentの初回transactionでPlanの17 WAL label全てにfaultを入れ、次processが一意にnew generationへ回復する。bootstrap 8 + initial WAL 17のsubcase数をassertする。

### TC-24: update transaction crash matrix
- `action_reserved`を追加するrequest、同actionを`action_consumed`へ遷移させるHuman resume、External resumeそれぞれで4 targetのPlan 17 WAL label全てにfaultを入れ、new generationへroll-forwardする。各17、合計51 update subcaseをassertし、TC-23の25件と合わせfault subcase floor=76をassertする。

### TC-25: Run A crash後のRun B lock取得
- Run Bは最初にRun Aのtask-wide WALを回復してから自身のCASを評価する。

### TC-26: corrupt/stale transaction
- truncated/unknown key、task/run/generation mismatch、target allowlist外、old/new以外のthird digestを上書きせずBLOCK。all-new stale WALは冪等cleanup。

### TC-27: CLI / Git context injection拒否
- operational CLIにrepo-root/task-dir/plan-hash/source-sha/receipt-path/action-binding optionがなく、unknown option/dict JSONでも注入不能。in-process mutation entrypointをexportしない。
- 偽`git`を先頭にしたPATH、hostile HOME/XDG global config、`GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, `GIT_INDEX_FILE`, `GIT_CONFIG_*`を設定しても、`gh_exec.run_git(..., isolated_env=True, binary_output=True)`がroot-owned `/usr/bin/git`、caller非継承allowlist env、caller非指定global config override、exact read-only rule、bytes stdoutだけを使う。既存default callerのargv/env/text outputが不変であることも確認する。productionのdirect `subprocess` / `multiprocessing` importはboundary scanで拒否する。
- local `core.fsmonitor` executable、`core.untrackedCache=true`、`status.showUntrackedFiles=no`、`core.worktree` redirect、hook/diff externalを設定しても、fixed command-line overrideまたはread-only subcommand性により実行/redirect/false-cleanせず、module anchorのrepo/common-dir/HEAD/statusだけを観測する。上書き対象外のGit object/index/worktree configを含むlocal admin metadataはTCBとしてcontractへ列挙する。

## External receipt

### TC-28: External正常消費
- flat task rootのcanonical receiptがtask/run/action/plan/request source/resume HEAD/result digest/SUCCEEDED一致し、actual HEADがrequest SHAとexactかつworktree cleanならsemantic receipt IDをledgerへ記録し`RUNNING`。

### TC-29: External same-run replay
- JSON再整形を含むsemantic cloneの再消費を拒否する。ledger上の同actionはreserved 1件からconsumed最大1件へだけ遷移し、消費済みactionの同一requestは完了済みbindingをartifact不変で返す。同じaction IDでresult/raw/semantic receipt IDだけを変えた2件目は`receipt_conflict`で拒否し、ledger/action一意性を維持する。

### TC-30: External cross-run / binding mismatch
- 別run、別action、HEAD drift、failure status、missing/unknown key、symlinkを拒否する。action/semantic IDのtask-wide unique indexがcross-run cloneでも増えないことをassertする。

## Boundaries / incident regression / harness drift / terminal

### TC-31: approval write / Git mutation不存在
- 全CLI command前後でworktree approval treeとGit refsをsnapshotし、write instrumentationも併用してmoduleによるC-3/C-4生成、commit、mergeが0。

### TC-32: #1023 module-level duplicate regression
- process AがHuman requestを記録して終了し、process Bの同一requestが既存actionを返す。
- `bin/plangate` nonce/TTY producer未接続のため、既存CLI実害を解消済みとは主張しない。

### TC-33: isolated source execution / runtime fingerprint
- CLIをroot-owned `/usr/bin/python3 -I -S -B`以外、module/runpy import、またはhostile `PYTHONPATH` / `PYTHONHOME` / sitecustomize / timestamp-valid ignored `gh_exec.pyc` / shadow package / preloaded fake `sys.modules["gh_exec"]`付きで起動する。前者とpreloadはartifact I/O前に`unsafe_python_runtime`、ambient/shadow/pycは無視してcanonical main source + canonical `gh_exec.py` sourceだけを実行する。
- byte-identical plugin生成copyから`contract`は読めるが、mutation/status commandはcaller CWDをrepo authorityへ使わず、artifact I/O前に`unsupported_runtime_layout`となる。root/plugin 5生成fileのsync parityもassertする。
- import前のmode 0700 empty private pycache prefix、stdlib path末尾へのcanonical directory追加、import後の`__file__` / `__spec__.origin` / `SourceFileLoader.path` / source digest / private `__cached__`を値レベルでassertする。repo-owned runtime importは`gh_exec`だけで、canonical hashはself-containedかつtest-only `c3_contract.canonical_hash` parityを満たす。
- HEAD不変で`gh_exec.py`または`durable_run.py`のbytes、persist済みPython/Git invoked path・realpath・owner/mode・bytes digestのいずれかを変えたfixtureは、全load/mutation/resumeを`harness_drift`で拒否する。

### TC-34: BLOCKED transition
- RUNNING/WAITINGからexplicit blockを許可し、`blocked_context`へ直前status、pending全体/action ID、reasonを保存する。本状態がarbiterの同名terminal decisionではなくrecoverable orchestration statusであることをcontractへ固定する。
- 同一reason再実行はno-op。異なるreason、通常request/resume/completeは`blocked_state`で拒否し全artifact不変。正しいreasonを伴うexplicit unblockだけが保存済みstatus/pendingへ復帰し、再起動後も同じ結果になる。

### TC-35: COMPLETED transition
- RUNNINGかつpendingなしだけcompleteを許可し、再実行no-op。WAITINGから直接completeを拒否する。

### TC-36: integrity errorとBLOCKED stateの区別
- store破損時は安全にstateを書けないためcontrolled errorを返し、BLOCKEDへ書換えたと偽らない。

### TC-37: trust limit contract
- `source=cli`はprovenance署名でない、Human/External identity未検証、whole-storage rollback・cross-clone durability・実TTY integration・plugin direct adapter非対応、OS-owned interpreter/stdlib/shared libraries/GitとGit object/index/local admin metadataがTCBであることをcontract/output/PRで明記する。

## Automated verification / anti-false-pass

### TC-38: unit/adversarial suite
- `/usr/bin/python3 -I -S -B scripts/ai-loop/test_durable_run.py`と同`test_gh_exec.py`を直接実行する。ta-62が両loader resultを合算して最低46 tests、`COVERAGE_MANIFEST`のunit TC 42 ID→exact methodと`GH_EXEC_REQUIRED_METHODS` 4件を重複/欠落/余剰なく全loadし、0 failure。

### TC-39: standalone extras
- `sh tests/extras/ta-62-durable-run.sh`がexit 0、unit 42 / GH boundary 4 / shell 4 coverage、最低46 tests、fault 76、rollback 14を独立確認し、`TA-62-DURABLE-RUN: PASS tests=<N> unit_tc=42 gh_boundary=4 fault=76 rollback=14`を成功時だけ1回出す。敵対Python/Git env caseも含む。

### TC-40: standard CI entry
- `sh tests/run-tests.sh`がexit 0、ta-62固有sentinelをちょうど1回出力する。
- `sh tests/extras/ta-61-extra-contract.sh`がexit 0。TC-09/TC-10が新規`ta-62-durable-run.sh`のcapability marker（先頭20行にちょうど1個）とbasename一致initを検証し、TC-20がbasename一意性を検証する（#1046共有exit契約 / R-135）。

### TC-41: existing ai-loop regression
- `/usr/bin/python3 -I -S -B`で`test_delivery.py` / `test_run_evidence.py` / `test_check_exec_boundary.py`を各file直接実行し、全て0 failure。

### TC-42: diff integrity
- `git diff --check`がexit 0。

### TC-43: actual linked worktree shared domain
- 一時Git repoにprimary checkoutと`git worktree add --detach`したlinked worktreeを作り、各worktree内の同一module sourceをisolated CLIで起動する。両者が同じabsolute common-dir、runtime root、common-dir直下lock dev/ino、manifestを観測する。
- 両worktreeのwriterを`subprocess` + `sys.executable` barrierで競合させ成功1 / `revision_conflict` 1とする。同じHuman authorityまたはExternal receiptを別runから同時消費させた場合も成功1 / replay拒否1となり、同じtask-wide ledgerへ重複記録されないことを確認する。

### TC-44: canonical ID golden vectors
- Planのaction / Human authority / External receipt / 2 source + 2 executable harnessのexact payloadをself-contained canonical hashへ渡し、4つのliteral expected SHA-256と一致する。同じbytesをtest-only `c3_contract.canonical_hash`へ渡してparityを確認し、key順変更では同一、field/domain/version/array order変更では不一致。

### TC-45: common-dir fallback / runtime preflight
- `--path-format=absolute`対応結果と、非対応を模擬したraw relative `--git-common-dir`のanchor基準解決が同じreal pathになる。
- runtime rootのwrite / file fsync / directory fsync不能を各々注入し、`runtime_unwritable`でartifact mutation前に停止する。

### TC-46: consumed request idempotency
- Human/Externalのreceipt消費後に同じrequestを再提示すると、元のaction/result bindingを`action_already_completed`として返す。state、record、ledger、manifest generationを一切変更せず、WAITING状態や新actionを再生成しない。

## Trust boundary

task manifestは全proper subset rollbackを検出するが、runtime store全体を同じ過去snapshotへ戻す攻撃は外部anchorなしでは検出できない。semantic authority ledgerはserialization変更による再利用を防ぐが、legacy C-3やExternal receiptの発行者identityを署名検証しない。v1 durability domainは同一local Git common-dirであり、別clone/machineは対象外である。
