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

- Git common-dir上のJSON state、hash-chain付きappend-only record、task-wide action lifecycle / receipt consumption ledger、全artifactを束縛するtask manifestの契約
- task単位inter-process lock、revision compare-and-swap、redo型WAL、atomic replace、read-time recovery / validation
- `RUNNING` / `WAITING_HUMAN` / `WAITING_EXTERNAL` / `BLOCKED` / `COMPLETED`
- Human / External requestのstable action IDと冪等再提示
- Human C-3 artifactとExternal receiptのcanonical pathからのread-only / no-follow検証
- 実plan bytes・実git HEADの内部解決とcaller supplied bindingの禁止
- restart / duplicate / tamper / binding mismatch / true concurrent writer / crash window / rollbackのunit tests
- `tests/run-tests.sh`から新unit suiteへ到達するextras導線
- explicit `block_run` / `unblock_run` / `complete_run`、recoverable `BLOCKED`、`COMPLETED`だけのterminal idempotency、receipt消費後requestの完了済み冪等再提示
- 既存`gh_exec` read-only Git境界のisolated environment / required argv拡張
- 正規plugin syncによるcontract / runtime / testsのbundle同期
- Durable Run Contract文書

### Out of Scope

- `bin/plangate`統合、schema追加、hook / policy / HO変更
- c3.json、Human approval receipt、C-4、mergeの生成
- GitHub API / CI polling / daemon
- RunEvidence producerや#869 Evolution実装への直接配線
- plugin bundle内のcopyを直接target repositoryへ接続するoperational adapter（生成copyは配布ミラー。v1 mutation/status入口ではない）
- 過去TASK stateのmigration
- 別clone / 別machineへのruntime state同期
- **issue #1025 Scope 1 の`phase` / `current_node`（workflow位置のstate永続fields）**（R-141）。v1 stateはrun status / pending action / revision / bindingだけを持ち、workflow node座標を持たない。
- **issue #1025 Scope 1 の`last_error`（観測事実と原因仮説の分離）**（R-141）。v1はerror codeを戻り値enumとしてのみ返し、stateへ永続化しない。**観測事実と原因仮説を分離するfield設計は後付けが難しい構造要件**であり、v2で最初から設計する。
- **issue #1025 Scope 4 の`approval_session_lost` / `external_wait_resumed` incident event語彙**（R-141）。v1 recordは`action_reserved` / `action_consumed`のlifecycle eventだけを持ち、incident evidence語彙を定義しない。
- 上記4項目は**v1で「触れない」のではなく明示的にv1対象外と宣言**し、**follow-up issueをHumanが起票する**（本PBIでは起票しない）。
- native Windows locking（v1 operational CLIはLinux/WSLの`/usr/bin/python3 -I -S -B`、`/usr/bin/git`、POSIX `fcntl.flock`を前提）

## Global Constraints

- C-3成立前にproduction fileを変更しない。
- Python標準ライブラリ以外を追加しない。
- `scripts/ai-loop/durable_run.py`は`approvals/**`へ書き込まない。
- mutationはtask単位のinter-process lock内でstate / ledgerを再読込し、`expected_revision`不一致を拒否する。暗黙のlast-write-winsを許さない。
- state / record / ledger / manifest / transaction / External receiptの未知キー、未知enum、chain不一致、cross-binding不一致はfail-closedにする。legacy C-3だけは`schemas/c3-approval.schema.json`と同じ既知propertyに加えてトップレベルの`^_`注釈キーを受理し、それ以外の未知キーを拒否する。全JSON readerはUTF-8 strict、`object_pairs_hook`によるduplicate key拒否、`parse_constant`による`NaN` / `Infinity` / `-Infinity`拒否を共通化する。
- timestampはCLI入力で注入し、純粋な判定関数内で現在時刻を取得しない。
- v1 mutation/status operational interfaceはcanonical sourceを`/usr/bin/python3 -I -S -B scripts/ai-loop/durable_run.py`でmain実行するCLIだけとする。起動直後に`sys.flags.isolated` / `no_site` / `dont_write_bytecode` / `safe_path`、`__main__.__spec__ is None`、canonical `__file__`、root-owned `/usr/bin/python3` realpathをartifact I/O前に検証し、不一致は`unsafe_python_runtime`とする。canonical hashはself-contained実装とし、runtime repo importは`gh_exec.py`だけを許可する。
- `gh_exec` import前に同名moduleが`sys.modules`にあれば拒否する。`/tmp`へmode 0700の空private bytecode-cache directoryを作り、`sys.pycache_prefix`をそこへ固定してからcanonical ai-loop directoryをstdlib pathの末尾へ1回だけ追加し、static importする。import後は`__file__` / `__spec__.origin` / `SourceFileLoader.path`が同じcanonical sourceであること、source bytesがimport前後で不変であること、`__cached__`が当該private directory配下であることを検証し、directoryを空のまま除去する。これによりtimestamp-valid ignored `__pycache__`、shadow package、`PYTHONPATH` / `PYTHONHOME` / `sitecustomize` / preloaded fake moduleをruntime候補にしない。
- operational commandは`__file__`がcanonical `<repo>/scripts/ai-loop/durable_run.py` layoutにある場合だけ許可する。正規syncで生成する`plugin/plangate/.../scripts/durable_run.py`はbyte-identical distribution mirrorだが、bundle内からの直接mutation/statusはcaller CWDをrepo authorityへ昇格させず、artifact I/O前に`unsupported_runtime_layout`。`contract`とpure test metadataだけを許可し、direct plugin adapterは別PBIとする。
- repository anchorはmain scriptの`Path(__file__).resolve()`が指す`<root>/scripts/ai-loop/durable_run.py`から導出し、既存唯一境界`gh_exec.run_git(..., isolated_env=True)`の`cwd=<anchor>`で`rev-parse --show-toplevel`を実行して同じreal pathを返すことを検証する。caller cwd / repo rootとambient environmentを権威入力にしない。
- production moduleは直接`subprocess` / `multiprocessing`をimportしない。`gh_exec.run_git(..., isolated_env=True, binary_output=True)`だけが、caller argvを既存read-only ruleで認可した後にroot-owned `/usr/bin/git`と固定global optionを組み立てて実行する。既存callerの既定`isolated_env=False, binary_output=False`は維持する。isolated環境はcaller `PATH` / `HOME` / `XDG_*` / 全`GIT_*`を継承せず、`PATH=/usr/bin:/bin`, `HOME=/dev/null`, `XDG_CONFIG_HOME=/dev/null`, `LC_ALL=C`, `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_OPTIONAL_LOCKS=0`, `GIT_PAGER=cat`, `GIT_TERMINAL_PROMPT=0`のallowlistから再構成する。
- isolated Git argvはcallerから指定できない`--no-pager`と`-c core.fsmonitor=false`, `-c core.untrackedCache=false`, `-c core.worktree=<verified anchor>`, `-c core.bare=false`, `-c status.showUntrackedFiles=all`, `-c diff.external=`, `-c core.attributesFile=/dev/null`をsubcommand前へ固定挿入する。`gh_exec`のread-only allowlistへ本機能が必要な`rev-parse --path-format=absolute --show-toplevel|--git-common-dir`、`status --porcelain --null --untracked-files=all --no-renames`、`diff --name-only --null --no-renames --no-ext-diff`だけをexact追加し、path outputはbytesのNUL単位 + filesystem `surrogateescape`で解釈する。残るGit object/index/common-dir/worktree configを含むlocal admin metadataは明示TCBであり、悪意あるrepo administratorへの隔離はv1保証に含めない。
- runtime rootはsanitized `git -C <anchor> rev-parse --path-format=absolute --git-common-dir`から解決する。未対応Gitでは`git -C <anchor> rev-parse --git-common-dir`をanchor基準でabsolute化し、両方式ともreal pathとdirectory性を検証して`<common-dir>/plangate/durable-run/<TASK>/`へ置く。tracked worktreeへstate/record/ledger/WALを書かない。write / file fsync / directory fsync不能は`runtime_unwritable`でartifact mutation前に停止する。
- runtime storeはrun directoryを作らないflat layoutとし、task root内は`manifest.json` / `ledger.jsonl` / `transaction.json` / `run--<RUN_ID>--state.json` / `run--<RUN_ID>--record.jsonl` / `external-receipt--<ACTION_HEX>.json`だけを許可する。task IDはlegacy C-3/schemaと同じ`TASK-[0-9]{4}`、run IDは`RUN-[A-Z0-9][A-Z0-9_-]{0,63}`、action ID/digestは`sha256:[0-9a-f]{64}`をexact grammarとし、filenameではaction prefixを除く64 hexだけを使う。caller supplied filenameを受け取らない。
- task lockはswappable task root外のheld Git common-dir直下`plangate-durable-run-lock--<TASK>.lock`へ置く。common-dir dirfdからno-follow create/openしてdev/inoを記録し、`fcntl.flock`後に同じcommon-dir fdから再openして一致確認してからbootstrap/recoveryへ進む。
- bootstrapはlock取得後、held common-dir dirfdから`plangate`→`durable-run`→task rootを`mkdirat`相当 + parent directory fsyncで順に作る。manifest/transaction不存在時に再利用できるprestateは空task rootだけ。各lock create/common-dir fsync/mkdir/parent fsyncでcrashしても同じcommon-dir lock domainへretryでき、それ以外のfile・symlink・orphan siblingは`bootstrap_conflict`で拒否する。
- mutationはprepare transactionを先にatomic write + fsyncし、run record→task-wide ledger（action reserve/consume時）→run state→task manifestの順でroll-forward可能にcommitする。各targetは同一directoryへのtemporary write + flush + fsync + dirfd `os.replace` + directory fsyncで更新する。
- recoveryはlock内で各targetがtransactionのold digestまたはnew digestのどちらかであることを確認し、oldのみnewへ進める。第三のdigestは`transaction_conflict`で停止する。
- task manifestは単調`generation`、`last_committed_tx_id`、全run state/record digest・count・tail・tx、ledger digest・count・tailを保持する。全mutationでmanifestを最後に更新し、load時に全artifactを一括照合する。proper subset rollbackは拒否し、全保存領域の同時rollbackだけをtrust limitとする。
- manifestはruntime rootのcanonical inventoryでもある。active transaction / 規定temp / pendingまたはledger参照済みのstrict-name External receiptを除き、未参照state / record / receipt / ledger / 未知fileをdirectory censusで拒否する。run directoryは存在しない。temp名は`transaction.json.tmp`と`<target>.tmp--<TX_HEX>`だけとする。active transactionに紐づくtarget temp以外は拒否し、active transaction不存在時の`transaction.json.tmp`だけはregular/no-follow、strict JSON、task/base generation/current old digests一致を検証してからpromote、truncatedなら未commit操作としてunlink + directory fsyncしてretry可能にする。
- CLIはrepo root、Git common-dir、canonical task dir、plan bytes、実git HEAD、receipt path、action bindingを内部解決する。task dir / plan hash / source SHA / receipt pathを権威入力として受け取らない。module importによるin-process mutation APIはv1非対応で、将来adapterはcanonical CLI subprocessを使用する。
- directory traversalはstrict task/run/action ID allowlistとdirfd `openat`相当（`O_DIRECTORY|O_NOFOLLOW`、leaf `O_NOFOLLOW` + `fstat`）で行い、lstat→openを分離しない。common-dir / `plangate` / `durable-run` / task-root / lockのdev+inoを保持し、lock取得後・recovery前・各replace前後・unlock前にheld common-dirから全chainを再走査して一致を要求する。rename/replacementは`runtime_path_changed`で停止し、別lock/ledger domainへ入らない。
- C-3は正規schema相当のrequired / type / phase / status / allowed-key検証を同一fdから読んだraw bytesに行う。semantic authority IDをtask-wide ledgerへ一度だけ記録し、raw digest、run/action、`request_source_sha`、`actual_resume_head`へ束縛する。
- request作成時にledgerへ`action_reserved` eventを同じtransactionで1件追加し、resume時はそのreservationを参照する`action_consumed` eventをappend-onlyで最大1件追加する。全kind共通で`action_id`はtask-wideにreserved 1件 / consumed最大1件、Humanはconsumed event内のauthority IDをtask-wide一度、Externalは同event内のreceipt IDをtask-wide一度だけ許可する。duplicate requestは既存reservationを返し、ledgerを増やさない。消費済みactionの同一request再提示は`action_already_completed`として既存完了結果を返し、state / record / ledger / manifest generationを変えず再WAITINGへ遷移しない。同じaction IDへraw digest / semantic ID / result digestが異なる2件目は`receipt_conflict`で拒否する。
- Human resumeはNUL解析したdirty/untracked pathがcanonical `docs/working/<TASK>/approvals/c3.json`のsubsetであることを常に要求する。その上で、内部観測した`actual_resume_head == request_source_sha`ならrelation=`same`、request SHAがancestorでcommit diffとdirty/untracked pathの和集合がcanonical C-3 pathだけならrelation=`c3_only_descendant`を許可する。ledgerには両SHAとrelationを別fieldで保存する。External resumeは`actual_resume_head == request_source_sha` + clean worktreeを要求する。Human / Externalとも初回検証後、task lock内のWAL prepare直前にsanitized Gitで`HEAD-before → status/diff/ancestor → HEAD-after`を再観測し、前後HEAD一致かつ初回snapshotと同一であることを要求する。この最終安定snapshotをsource relationの線形化点とし、差異は`source_context_changed`でtransaction作成前に全artifact不変のまま拒否する。線形化点後のGit変更は後続eventであり、v1が防止・排他すると主張しない。
- External receiptはtask root直下`external-receipt--<ACTION_HEX>.json`をcanonical pathとし、strict schemaに`task_id` / `run_id` / `action_id` / `plan_hash` / `request_source_sha` / `resume_head` / `status=SUCCEEDED` / `result_digest`を必須化する。semantic receipt IDとaction IDを同じtask-wide ledgerで一度だけ消費する。
- C-3 / External receiptは同一fdからvalidate+digestし、prepare直前にcanonical pathのdev/ino/raw digestを再照合して差替えraceを拒否する。同じprepare直前区間でsource relationの最終安定snapshotも再取得し、receiptとsourceの両snapshotが初回検証結果と一致した場合だけprepare transactionを作る。
- `harness_fingerprint`は実際に実行/ロードする`gh_exec.py`, `durable_run.py`のcanonical relative path + source bytes SHA-256と、root-owned Python/Git executableのfixed invoked path + realpath + bytes SHA-256を固定順で束縛する。各CLI invocationでsource / loader identity / executable ownership・mode・digestを再検証し、active runのいずれかが変われば`harness_drift`で拒否する。stdlib・shared library・Git object/index/local admin metadataはroot/OS・local repository TCBとして別途明記する。
- action / Human authority / External receipt IDとharness fingerprintは下記「Canonical ID Contract」のdomain/version付きexact payloadをself-contained canonical hashで生成し、testだけが`c3_contract.canonical_hash`とのbyte-for-byte parityを検証する。timestamp / approved_at / annotationを含めない。
- `block_run`は`RUNNING`またはWAITING状態からのみ許可し、`blocked_context`へ直前status / pending action / blockerを保存する。本Durable Runの`BLOCKED`は`.claude/rules/working-context.md`の外部依存taskに対応する**回復可能なorchestration status**で、arbiterの同名terminal decisionとは別語彙である。同一block再実行はno-op、明示`unblock_run`だけが保存済みstatus/pendingへ復帰し、blocker不一致・complete・通常request/resumeは拒否する。store integrity errorは安全にstateを書けないため`BLOCKED`へ変換しない。
- 新規extras `tests/extras/ta-62-durable-run.sh`は#1046の共有exit契約に準拠する。先頭20行に`# PG_EXTRA_CAPABILITY: standalone-capable`をちょうど1個置き、`. "$_pg_extra_dir/_extra-contract.sh"`をsourceして`pg_extra_contract_init ta-62-durable-run standalone-capable`をbasename一致で呼び、rc layer 0/1/2/3と末尾`pg_extra_contract_finalize`を守る。移行期allowlist`_pending_migration()`へは追加しない（新規ファイルは契約準拠が既定）。次の**静的追加要件**を満たす（R-145 / R-146）:
  - `pg_extra_contract_init`は**行頭（インデント無し）**に置く。`ta-61:239`の`grep -E '^pg_extra_contract_init[[:space:]]'`がTC-10の判定に使われるため、インデントすると「init呼び出し無し」と判定される。
  - preambleは`PG_HARNESS_SOURCED=1` / `FIXTURES_DIR` non-empty / `EXTRAS_DIR` non-emptyの**3条件ANDでharness判定**し、harnessなら`_pg_extra_dir="$EXTRAS_DIR"`、standaloneなら`dirname -- "$0"`を使う（`ta-61:15-21`と同型）。harness実行では`$0`が`run-tests.sh`のため`dirname $0`だけではhelperへ到達しない。
  - `FIXTURES_DIR:-`を参照するため、`ta-26` TC-33の静的検査に合わせ、**自ファイル内に`run-tests.sh:20`と同一の7 env unset行**（`PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE`）を持つ。helper initが既にunset済みで機能的には冗長だが、**静的検査のため明示行が必須**（`ta-61:34-39`が実例）。
- `ta-62`は`ta-61`の**per-file実行ループ（`ta-61:282-355`）に1ファイルにつき3回叩かれる**前提で設計し、次の**実行時契約**を満たす（R-138 / R-148）。静的なmarker / init一致（TC-09 / TC-10）だけでは不足する。
  - **実行時間予算: 単体実行60秒未満を目安**とする。`ta-61`のper-file timeoutは180秒で、**timeoutはSKIPでなくFAIL**（`ta-61:58-63,311-314`）。予算を超えて180秒枠に余裕を作れない場合はReplan Triggerとする。
  - **stage-1 clean runのrcは0か3だけ**にする（`ta-61:315-353`はそれ以外をfail-closedでFAIL）。かつ**rc=0のrunは`[FAIL]`文字列を出力しない**（`ta-61:319-321`）。
  - force-fail probeで**rc=1かつ`PG_EXTRA_CONTRACT_PROBE_FIRED:ta-62-durable-run`を出力**する（`ta-61:325-330`）。そのため`ta-62`は**独自の`exit`で終端せず**、失敗を共有`fail`カウンタ経由で末尾`pg_extra_contract_finalize`へ伝播させる。
  - 汚染env（`PG_HARNESS_SOURCED=1` + 全guarded envにjunk）でも**rc=0**にする（`ta-61:332-338`）。
  - **prerequisite未充足（`/usr/bin/python3`不在・`git`不在等）は必ず`pg_extra_contract_skip`経由でrc=3**にする。`ta-61:341-349`は診断出力を伴わないrc=3を「forbidden route」としてFAILにするため、素のrc=3で抜けてはならない。
- `ta-62`は**`tests/run-tests.sh`を実行しない**（R-139）。`ta-61`のper-file実行ループは`PG_T61_NO_RECURSE`を子へ渡さない（`ta-61:310,327,334`。nested full-suite `:766,792,800`とは非対称）ため、`ta-62`がsuiteを起動すると`run-tests.sh → ta-61 → ta-62 → run-tests.sh`で無限再帰し180秒timeoutでTC-12がFAILする。`ta-62`はTC-40のmappingとsentinel出力だけを持ち、**「run-tests.sh経由でsentinelがちょうど1回」の実行主体はVerification PlanのFull suite行**とする（`ta-61:781-783,806-807`の「harness実行時は囲っているrun自体が証拠」という既存の割り切りを踏襲）。
- `ta-62`は**自身専用の失敗カウンタ`_t62_fail`**で成否を判定し、sentinelはそれでgateする（R-140）。`tests/run-tests.sh:26-27`の`pass` / `fail`は全extras共有のグローバル集計で、harnessパスの`pg_extra_contract_finalize`は`return 0`して runnerへ委ねるため、`[ "$fail" -eq 0 ]`で判定すると**`ta-62`より前にsourceされた無関係extrasの失敗でsentinelが抑止され、TC-40が実行順序依存で非決定**になる。共有`fail`へは自身の失敗のみ加算する。
- **書き込み系Git fixtureは`ta-62`（シェル層）で構築し、Python側は生成済みrepoに対する読み取りと`sys.executable`経由のCLI起動だけにする**（R-142）。`scripts/ai-loop/check_exec_boundary.py`は`test_*.py`の`subprocess` argv先頭を`sys.executable`かリテラル`"git"` + 読み取り専用サブコマンド7種（`status` / `rev-parse` / `diff` / `log` / `merge-base` / `ls-remote` / `show`）に限定し、絶対パスは`CODE_ARGV_HEAD`、変数経由は`CODE_ARGV_UNRESOLVED`でfail-closedにする。検査対象は`base.glob("*.py")`で`scripts/ai-loop/`全`.py`、強制点は`tests/extras/ta-57-pr-convergence.sh:80`のcorpus scan（exit 0必須）である。したがって`git init` / `add` / `commit` / `worktree add`（TC-43）と、canonical interpreter以外での起動（TC-33負側）は**Pythonテストから実行できない**。`GRANDFATHER_ARGV_EXCEPTIONS`は「1件から増やさない」と凍結されており、`check_exec_boundary.py`自体の変更はReplan Triggerに該当する。
  - `ta-62`が一時Git repoとlinked worktreeを構築し、`PG_T62_GIT_FIXTURE_ROOT` / `PG_T62_LINKED_WORKTREE`をenvで渡す。`test_durable_run.py`の当該subcaseは**env未設定時にskipせず「fixture依存subcase実行数=0」を明示出力**し、`ta-62`がその件数の下限をassertする（静かなskipによるfalse passを作らない）。
  - `ta-62`が**unit suiteの正規実行入口**である。Verification Planの直接実行行はfixture非依存部分のRED / GREEN確認用途に限定する。
- `ta-62`は**リポジトリ全体状態に依存するassertionを内包しない**（R-143）。`git diff --check`（TC-42）を`ta-62`内で実行すると無関係な作業ツリーの空白エラーで`ta-62`がrc=1になり、`ta-61:352`の「rcが0でも3でもない」でfail-closed→full suite赤になる。TC-41（delivery / run_evidence regression）も3回実行前提では重複コストにしかならない。TC-40 / TC-41 / TC-42は**Verification Plan（PR単位の実行）が実行主体**とし、`ta-62`は`SHELL_COVERAGE_MANIFEST`のmapping保持のみを担う。`ta-62`内でplugin parityを見る場合は**`ta-26`のsandboxパターン（`ta-26:95-99` / #861 実リポジトリ非破壊化）を踏襲**し、`mktemp -d`配下にsandbox repoを構築してそこでsyncを実行する（実`plugin/`へは書き込まない）。
- C-3 / C-4 / merge / HO / policyのHuman-owned境界を変更しない。
- legacy C-3がrun/action/sourceを署名しないこと、`source=cli`がprovenance証明でないこと、Human/External identityを暗号学的に検証しないこと、保存領域全体の同時rollbackと別clone同期は提供しないことをv1 trust limitとして隠さない。OS-owned `/usr/bin/python3` / `/usr/bin/git`とGit local admin metadataはtrusted computing baseとし、root/OS compromiseは対象外とする。

## Canonical ID Contract

canonicalizationは`json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)`のUTF-8 bytesに対するSHA-256で、戻り値は`sha256:<64 lowercase hex>`とする。payloadのkey集合とdomain/versionはexactであり、余剰keyをID入力へ取り込まない。**`ensure_ascii=True`はcontractの一部**であり、`c3_contract.canonical_hash`（`scripts/ai-loop/c3_contract.py:71-74`）の既定と一致させる（R-147）。`instructions_ref`は非ASCIIを含みうるため、下記golden vectorに**非ASCII 1本を必ず含める**（全ASCIIのvectorだけでは`ensure_ascii=False`実装との差が出ずparity testが空振りする）。

| ID | exact payload fields |
|---|---|
| action ID | `domain="plangate.durable-run.action/v1"`, `task_id`, `run_id`, `action_kind`, `plan_hash`, `request_source_sha`, `harness_fingerprint`, `instructions_ref` |
| Human authority ID | `domain="plangate.durable-run.human-plan-authority/v1"`, `task_id`, `phase="C-3"`, `c3_status="APPROVED"`, `source="cli"`, `plan_hash` |
| External receipt ID | `domain="plangate.durable-run.external-receipt/v1"`, `task_id`, `run_id`, `action_id`, `plan_hash`, `request_source_sha`, `resume_head`, `status="SUCCEEDED"`, `result_digest` |
| harness fingerprint | `domain="plangate.durable-run.harness/v1"`, `executables=[python, git]`, `files=[gh_exec.py, durable_run.py]`。各executableは`role`, `invoked_path`, `real_path`, `sha256`、各fileは`path`, `sha256`をexact fieldとし、この配列順を固定する |

Golden vectors:

- action: `TASK-1025`, `RUN-0001`, `WAITING_HUMAN_C3`, plan=`sha256:` + `11`×32、source=`a`×40、harness=`sha256:` + `22`×32、instructions=`docs/working/TASK-1025/plan.md#human-gate` → `sha256:633231d2247a07c0b9f64bfe2681458d775f3455ad2b6280d8611c9f4cf99e8e`
- Human authority: 同task/plan、`C-3` / `APPROVED` / `cli` → `sha256:a3246e6c017b29d629a9a7dea0cd15bcbb1e8ecc5b89c276cb6b820f80d05ecb`
- External receipt: 同task/run/plan/source、action=`sha256:` + `44`×32、resume=`a`×40、result=`sha256:` + `33`×32、`SUCCEEDED` → `sha256:e074b8948dec9573f31cf4cf194be32a315beac25e902f005b86542d17320c53`
- harness: Python invoked=`/usr/bin/python3`, real=`/usr/bin/python3.12`, digest=`sha256:` + `88`×32、Git invoked/real=`/usr/bin/git`, digest=`sha256:` + `99`×32、`gh_exec.py`=`sha256:` + `66`×32、`durable_run.py`=`sha256:` + `77`×32 → `sha256:4370171c049d97a07d8598c34ec9512a5126d37be3ef587072f98cf037b96285`
- **action（非ASCII / R-147）**: 上記actionと同一fieldで`instructions_ref`だけを`docs/working/TASK-1025/plan.md#人間ゲート`にしたもの → `sha256:229416de0910d27876291933936c445e8a57969ae8513030e350d23405d17b88`。`ensure_ascii=False`実装では`sha256:20c5bd76fb362d88c08bef2786df9d7c8c4be3a18f6c29dc69482bb397e8f395`となり**一致しない**（実測）。golden vectorは計**5本**とする。

Golden canonical bytes（改行なし）:

```text
action={"action_kind":"WAITING_HUMAN_C3","domain":"plangate.durable-run.action/v1","harness_fingerprint":"sha256:2222222222222222222222222222222222222222222222222222222222222222","instructions_ref":"docs/working/TASK-1025/plan.md#human-gate","plan_hash":"sha256:1111111111111111111111111111111111111111111111111111111111111111","request_source_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_id":"RUN-0001","task_id":"TASK-1025"}
human={"c3_status":"APPROVED","domain":"plangate.durable-run.human-plan-authority/v1","phase":"C-3","plan_hash":"sha256:1111111111111111111111111111111111111111111111111111111111111111","source":"cli","task_id":"TASK-1025"}
external={"action_id":"sha256:4444444444444444444444444444444444444444444444444444444444444444","domain":"plangate.durable-run.external-receipt/v1","plan_hash":"sha256:1111111111111111111111111111111111111111111111111111111111111111","request_source_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","result_digest":"sha256:3333333333333333333333333333333333333333333333333333333333333333","resume_head":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_id":"RUN-0001","status":"SUCCEEDED","task_id":"TASK-1025"}
harness={"domain":"plangate.durable-run.harness/v1","executables":[{"invoked_path":"/usr/bin/python3","real_path":"/usr/bin/python3.12","role":"python","sha256":"sha256:8888888888888888888888888888888888888888888888888888888888888888"},{"invoked_path":"/usr/bin/git","real_path":"/usr/bin/git","role":"git","sha256":"sha256:9999999999999999999999999999999999999999999999999999999999999999"}],"files":[{"path":"scripts/ai-loop/gh_exec.py","sha256":"sha256:6666666666666666666666666666666666666666666666666666666666666666"},{"path":"scripts/ai-loop/durable_run.py","sha256":"sha256:7777777777777777777777777777777777777777777777777777777777777777"}]}
action_nonascii(ensure_ascii=True の実バイト列)={"action_kind":"WAITING_HUMAN_C3","domain":"plangate.durable-run.action/v1","harness_fingerprint":"sha256:2222222222222222222222222222222222222222222222222222222222222222","instructions_ref":"docs/working/TASK-1025/plan.md#\u4eba\u9593\u30b2\u30fc\u30c8","plan_hash":"sha256:1111111111111111111111111111111111111111111111111111111111111111","request_source_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_id":"RUN-0001","task_id":"TASK-1025"}
```

> `action_nonascii`の`instructions_ref`は原文`docs/working/TASK-1025/plan.md#人間ゲート`で、上記canonical bytesは`ensure_ascii=True`による`\uXXXX`エスケープ後の実バイト列である（この差そのものがR-147のregression対象）。

## Crash and Anti-False-Pass Contract

- bootstrap fault labels（8）: `bootstrap_after_create_common_lock`, `bootstrap_after_fsync_common_dir_for_lock`, `bootstrap_after_mkdir_plangate`, `bootstrap_after_fsync_common_dir_for_plangate`, `bootstrap_after_mkdir_durable_run`, `bootstrap_after_fsync_plangate`, `bootstrap_after_mkdir_task`, `bootstrap_after_fsync_durable_run`
- WAL fault labels（17）: `tx_after_temp_fsync`, `tx_after_replace`, `tx_after_dir_fsync`, `record_after_temp_fsync`, `record_after_replace`, `record_after_dir_fsync`, `ledger_after_temp_fsync`, `ledger_after_replace`, `ledger_after_dir_fsync`, `state_after_temp_fsync`, `state_after_replace`, `state_after_dir_fsync`, `manifest_after_temp_fsync`, `manifest_after_replace`, `manifest_after_dir_fsync`, `tx_after_unlink`, `tx_after_unlink_dir_fsync`
- 初回transactionで空ledgerを含む4 targetの17 WAL labelを全列挙する。request updateは`action_reserved`、Human / External resume updateは`action_consumed` + authority/receiptをledgerへ追加するため、3 fixtureとも4 targetの17 labelを全列挙する。bootstrap 8と合わせ、fault injection subcaseは最低76（8 + 17 + 17×3）とする。
- proper subset rollbackは同一generationの`state`, `record`, `ledger`, `manifest`の非空proper subset全14組（$2^4-2$）を列挙する。
- unit対象は`TC-01`〜`TC-38`と`TC-43`〜`TC-46`のexact 42 ID。`test_durable_run.py`はmodule定数`COVERAGE_MANIFEST`で42 ID→`test-cases.md`記載のexact method nameを一対一mappingし、重複/欠落/余剰を禁止する。さらに`test_gh_exec.py`のisolated mode新規4 methodを`GH_EXEC_REQUIRED_METHODS`へexact固定する。`-I`ではcwdがimport pathから外れるため各test fileを直接実行し、ta-62は両runのloader resultを合算して最低46 tests、42 manifest method + 4 boundary methodが実際にloadされたことを照合する。
- shell/route対象`TC-39`〜`TC-42`はta-62内の`SHELL_COVERAGE_MANIFEST`へexact command / expected exit / sentinel / **実行主体**を一対一mappingする。実行主体を明示するのはR-139 / R-143の是正であり、mappingは4件のまま維持してcoverage orphanを作らない。

| TC | mapping内容 | 実行主体 |
|---|---|---|
| TC-39 | isolated direct unit実行 + 両manifest + GH boundary 4 + ≥46 tests + fixture依存subcase件数 + exact sentinel | **ta-62 in-file** |
| TC-40 | `sh tests/run-tests.sh` exit 0 + ta-62 sentinelちょうど1回 | **Verification PlanのFull suite行**（ta-62はmapping保持のみ・自身では実行しない / R-139） |
| TC-41 | isolated delivery / run_evidence / check_exec_boundary regression exit 0 | **Verification PlanのRegression行**（ta-62はmapping保持のみ / R-143） |
| TC-42 | `git diff --check` exit 0 | **Verification PlanのDiff行**（ta-62内で実行するとリポジトリ全体状態に依存しrc=1→fail-closed / R-143） |

- ta-62は両manifest、GH boundary 4 method、合算件数、fault subcase=76、rollback subcase=14、fixture依存subcase件数の下限を独立照合し、**自身専用カウンタ`_t62_fail`が0のときだけ**`TA-62-DURABLE-RUN: PASS tests=<N> unit_tc=42 gh_boundary=4 fault=76 rollback=14`を出す（共有`fail`でgateしない / R-140）。`tests/run-tests.sh`経由で同sentinelがちょうど1回到達することは**Verification PlanのFull suite行**が検証する。

## 前提の実測検証（#786）

| 前提 | 検証コマンド | 実測結果 | 判定 |
|---|---|---|---|
| mainの正本SHA | `git rev-parse origin/main` | `48f69713f2b651e6788bf075d64628630c74fad4`（2026-08-12 再実測。旧base `5e630f9d…`から2 commit前進） | ✅ |
| common-dir absolute/fallback | `git rev-parse --path-format=absolute --git-common-dir` / `git rev-parse --git-common-dir` | `/workspace/scratch/a0ce72931a7c/plangate-task-1025/.git` / `.git` | ✅ anchor基準absolute化が必要 |
| intent / receiptの既存実装 | `rg -n "def action_id|def entry_id|def append_entries" scripts/ai-loop/delivery.py` | 3関数とreceipt抑止ロジックを確認 | ✅ |
| ai-loop script数 | `rg --files scripts/ai-loop | wc -l` | 30 | ✅ |
| ai-loop contract文書数 | `rg --files docs/workflows/ai-loop | wc -l` | 16 | ✅ |
| 変更先のrollout境界 | `rg -n "判定基盤 carve-out|scripts/ai-loop" docs/workflows/ai-loop/rollout-policy.md` | scripts / docs corpusはHuman escalate固定 | ✅ |
| **extras共有exit契約の発効**（#1046 / `48f6971`） | `git show origin/main:tests/extras/ta-61-extra-contract.sh` のTC-09/TC-10 covered set導出 | 除外は`_pending_migration()`のリテラル列挙のみ。**新規`ta-*.sh`は即covered setに入り契約準拠が必須** | ✅ 反映済（R-135） |
| **既存ta-61の占有** | `git ls-tree --name-only origin/main tests/extras/` | `ta-61-extra-contract.sh`が存在（TC-20はbasename一意性のため衝突ではFAILしないが、番号規約上`ta-62`へ振替） | ✅ 反映済（R-136） |
| **EH-13 token-guardの発効**（#1042 / `15b0c16`） | `scripts/check-approval-token-write.sh`の`_is_token_path`/`_has_write_intent` | `*c3.json*` / `*/approvals/*.json`を含みかつ`>`等のwrite intentを持つBashをblock（`2>&1`もマッチ） | ✅ 反映済（R-137） |

## Questions / Unknowns（#786）

- Human refinement R-003: **Aを採用（2026-08-09）**。HOを変更せず、legacy C-3をPlan authorityとして読み取り、task-wide ledgerで消費する。Round 2 findingへのchecker-driven refinementとしてserialization非依存のsemantic authority IDを全Run一度だけ消費し、raw digestは証拠としてrun/action/sourceへ束縛するが一意キーにはしない。この精緻化は確定PlanのHuman C-3承認待ちである。
- 既知の保証限界: legacy artifact自体のaction-bound署名、Human identity、保存領域全体のrollback検出は提供しない。`bin/plangate`への正式統合、JSON Schema昇格、署名付きHuman receiptは別PBIで判断する。

## 確認事項（B-1）

- Q1: 自己改善全体を一括実装するか。A: しない。今回の実害を防ぐためのDurable Run contract基盤の最小縦切りに限定し、既存TTY producer接続はfollow-upとする。
- Q2: Human承認を会話経由に変更するか。A: 変更しない。既存CLI artifactをread-onlyで消費する。
- Q3: stateの正本をMarkdownにするか。A: しない。JSONを機械正本、Markdownを人間向けviewとする。
- Q4: legacy C-3へrun/action/source fieldを追加するか。A: 追加しない。semantic Plan authorityのtask-wide consumption ledger方式を採用し、非暗号学的trust limitを明記する。

## Metrics Evidence

| 指標 | 見積り | 実測 / 計画値 | ratio | 判定 |
|---|---:|---:|---:|---|
| production変更ファイル | 12 | 12 | 1.0 | 採用 |
| 新規module | 1 | 1 | 1.0 | 採用 |
| 新規unit test file | 1 | 1 | 1.0 | 採用 |
| CI extras file | 1 | 1 | 1.0 | 採用 |
| 既存関連module変更 | 2 | `gh_exec.py` / `test_gh_exec.py` | 1.0 | isolated read-only Git境界 |
| plugin派生成果物 | 5 | reference 1 / scripts 4 | 1.0 | sync生成のみ |

「全件」系の対象はない。scopeはproduction 12ファイルに固定する。

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | `delivery.py`へpre-PR stateを直接統合 | intent / receiptを即再利用 | PR後の収束責務とpre-PR run責務が混在し、回帰範囲が広い | 不採用 |
| B | 独立`durable_run.py` CLIでcontractを実証し、既存`gh_exec`境界をisolated modeで再利用 | 既存exec boundaryを維持し、canonical hashはself-contained + parity testで単体検証可能 | v1では`plangate resume`へ未接続、Linux/WSL isolated runner限定 | 採用 |
| C | `bin/plangate`とschemasへ最初から統合 | UXが一つのCLIに揃う | HO 3層を同時変更しblast radiusが大きい | 不採用 |

### Recommended Approach

実装アーキテクチャ案Bを採用する（Human refinementの選択Aとは別軸）。state transitionとI/Oを独立moduleへ固定し、canonical hashはself-contained、Git観測は唯一の外部process境界`gh_exec`のisolated modeを再利用する。operational CLIはroot-owned isolated Pythonでcanonical sourceをmain実行し、private empty pycache prefixを介してcanonical `gh_exec.py` sourceだけをstatic importする。task lockはswappable task root外のcommon-dirへ置く。flat runtime storeの安全なempty bootstrap後、全mutationをtask manifest・redo型WALへ通し、state / record / receipt ledgerのpartial commitを決定論的にroll-forwardする。実loaded source 2件 + executable 2件のharness fingerprintをactive runへ束縛する。Human承認はcanonical pathの既存artifactをread-only / no-followで正規schema相当検証し、serialization非依存のPlan authority IDを全Run一度だけ消費する。raw digestはsnapshot証拠として束縛する。本moduleから承認artifactは発行せず、`source=cli`を署名provenanceとは扱わない。正規syncでplugin bundleも同一PRへ含め、初回PRでrestart・recoverable BLOCKED・request idempotency・concurrency・resume固有WAL crash・proper subset rollback・linked worktree共有・runtime injection・bindingを検証する。

## Files / Components to Touch

| ファイル | 操作 | 目的 | 公開インターフェース / 依存 |
|---|---|---|---|
| `scripts/ai-loop/durable_run.py` | create | state transition/hash、atomic I/O、manifest / intent / receipt | operational CLI `contract|init|request|status|resume|block|unblock|complete` |
| `scripts/ai-loop/test_durable_run.py` | create | AC-01〜AC-10のunit / regression | `unittest` |
| `scripts/ai-loop/gh_exec.py` | modify | isolated Git env・binary path output・必要最小read-only argv | `run_git(..., isolated_env=True, binary_output=True)`（既定互換） |
| `scripts/ai-loop/test_gh_exec.py` | modify | env除去とallowlist拡張の負側検証 | existing unittest |
| `docs/workflows/ai-loop/durable-run-contract.md` | create | 状態・遷移・binding・責務境界の正本 | implementation contract |
| `tests/extras/ta-62-durable-run.sh` | create | 新unit suiteを標準CI入口へ接続 | `tests/run-tests.sh`からsource |
| `scripts/sync-plugin-plangate.sh` | modify | durable runtime/testをbundle allowlistへ追加 | 正本sync |
| `plugin/plangate/skills/ai-loop-cycle/references/durable-run-contract.md` | generate | contract配布コピー | sync派生 |
| `plugin/plangate/skills/ai-loop-cycle/scripts/durable_run.py` | generate | runtime配布ミラー（direct operational mutationはfail-closed） | sync派生 |
| `plugin/plangate/skills/ai-loop-cycle/scripts/test_durable_run.py` | generate | test配布ミラー | sync派生 |
| `plugin/plangate/skills/ai-loop-cycle/scripts/gh_exec.py` | generate | Git境界配布コピー | sync派生 |
| `plugin/plangate/skills/ai-loop-cycle/scripts/test_gh_exec.py` | generate | Git境界test配布コピー | sync派生 |

## Work Breakdown

### Task 1: Contract-first adversarial tests

**Purpose**: restart、block/unblock/terminal transition、真の並行CAS、bootstrapと全durable syscall後のcrash、semantic ledger再利用、proper subset rollback、canonical path/HEAD/harness bindingを実装前に固定する。

**Files**: Create `scripts/ai-loop/test_durable_run.py`.

**Interfaces**: isolated operational CLI、self-contained canonical hash（test-only `c3_contract` parity）、`gh_exec` read-only Git境界、AC-01〜AC-10・C-2全findingを破るfixtureを先に作る。

**Steps**:

- [ ] `subprocess` + `sys.executable`のbarrierを使う2 writer testを追加し、禁止`multiprocessing`を使わない
- [ ] Human / External両requestの別process復元・pending再提示と、消費後requestの完了済み冪等応答を追加する
- [ ] 8 bootstrap fault label、初回17、request/Human resume/External resume更新各17のfault pointを固定する
- [ ] state/record/ledger/manifestの非空proper subset 14組を旧snapshotへ戻すrollback・truncation・transaction conflictを追加する
- [ ] C-3 semantic authorityの同一Run再消費 / 別Run流用 / JSON再整形、duplicate key / non-standard number、実plan / 実HEAD / parent no-follow / loaded-source + executable harness driftを追加する
- [ ] External receiptのsame-run / cross-run / same-action-different-result replayとprovenance trust limitを追加する
- [ ] recoverable `BLOCKED`のblock/unblock復帰と`COMPLETED` terminal idempotencyを追加する
- [ ] hostile pyc/PYTHONPATH/sitecustomize/sys.modules、plugin direct operational layout、PATH/HOME/XDG/Git config、NUL含みpath、task-root rename/replacement、actual linked worktreeのcommon-dir / external lock inode / ledger共有、absolute fallback、unwritable preflightを追加する
- [ ] Canonical ID Contractの**5 golden vector**（非ASCII `instructions_ref` 1本を含む）をliteral期待値で追加し、`ensure_ascii=False`実装では不一致になることをassertする（R-147）
- [ ] **書き込み系Git fixtureをPythonから作らない**。TC-43のrepo/linked worktreeとTC-33負側の非canonical interpreter起動はta-62（シェル層）が構築・駆動し、Python側は`PG_T62_GIT_FIXTURE_ROOT` / `PG_T62_LINKED_WORKTREE`の読み取りと`sys.executable`経由のCLI起動だけを行う。env未設定時はskipせず「fixture依存subcase実行数=0」を明示出力する（R-142）
- [ ] REDがmodule / interface不存在だけであることを記録する

**Completion Criteria**: `test-cases.md`の全functional / adversarial caseが具体的test methodへ対応し、RED理由が期待どおりである。

**Rollback**: 新規test fileだけをrevertする。

### Task 2: Locked durable state and redo transaction core

**Purpose**: 全mutationをtask単位lockで直列化し、task manifestで全artifactを一括束縛してpartial commit / proper subset rollbackを検出・回復する。

**Files**: Create `scripts/ai-loop/durable_run.py`; modify its tests.

**Interfaces**: `contract_dict`, `init_run`, `load_state`, `load_record`, `request_wait`, `block_run`, `unblock_run`, `complete_run`, internal `recover_transaction`.

**Steps**:

- [ ] strict enum / key / transition / error validatorとduplicate-key / non-standard-number拒否JSON loaderを実装する
- [ ] isolated/no-site/no-bytecode main runner、private empty pycache prefix、preloaded module拒否、exact SourceFileLoader identity、self-contained hash + test-only `c3_contract` parity、2 source + 2 executable harness fingerprintを実装する
- [ ] `gh_exec.run_git(..., isolated_env=True, binary_output=True)`へfixed binary / clean allowlist env / caller非指定global config override / 必要最小read-only argvを追加し、既定callerを不変に保ったままmodule位置からrepository anchor、absolute/fallback common-dir、bytes NUL path parserを解決する
- [ ] common-dir external task lock取得後にflat runtime rootをstrict ID + dirfd traversalで安全にbootstrapし、全ancestor/lock inodeをheld common-dirから各critical boundaryで再照合する。`fcntl` unavailableは`unsupported_platform`、write/fsync不能は`runtime_unwritable`でfail-closedにする
- [ ] task単位`fcntl.flock`取得後にmanifestと全参照artifactを再読込してCASする
- [ ] record hash chain、ledger hash chain、state digestをtask manifestのgeneration / digest / count / tail / txへ一括束縛する
- [ ] manifest inventoryとflat runtime directory censusを照合し、安全なempty/lock-only bootstrap以外の未参照/未知artifactを拒否する
- [ ] target allowlist、absent sentinel、task/run/base-next generation、full new payload、old/new digestを持つ単一prepare transactionを先にfsyncする
- [ ] record→ledger（変更時）→state→manifestの順でatomic replaceし、次回取得時にoldのみnewへroll-forwardする
- [ ] 8 bootstrap、初回17、request/Human resume/External resume各17の全crash recoveryを実装する
- [ ] Human / External stable request / action ID、task-wide `action_reserved`→`action_consumed` lifecycle、pending duplicate no-op、消費済みactionの完了済み冪等応答を実装する
- [ ] explicit block / unblock / completeを実装する。BLOCKEDはprior status/pending/blockerを保持して明示unblockだけで復帰可能、COMPLETEDだけをterminalとし、integrity errorはstateへ書けない制御errorと区別する

**Completion Criteria**: concurrent writerは成功1 / conflict 1、8 bootstrap + 初回17 + 更新51の全crash windowは安全なbootstrap retryまたは同一new generationへ収束し、14 proper subset rollback / third digestは上書きされない。primary/linked worktreeはcommon-dir直下の同一lock inode / ledgerを観測し、task-root rename/replacementは別domainを作らず停止する。

**Rollback**: module / test commitをrevertする。既存state migrationはない。

### Task 3: Canonical receipt verification and one-shot resume

**Purpose**: caller値に依存せず実repo状態を検証し、legacy C-3をtask-wide ledgerで一度だけ消費する。

**Files**: Modify `scripts/ai-loop/durable_run.py` and tests.

**Interfaces**: `resume_run`; canonical repository context; legacy C-3 raw bytes; external receipt.

**Steps**:

- [ ] operational CLIをtask ID・run ID・非権威action入力だけに限定し、repo/task/plan/HEAD/receipt/action bindingを内部解決する。in-process mutation entrypointをexportしない
- [ ] canonical `approvals/c3.json`をdirfd traversal + no-follow regular-fileとして同一fdからread/digestする
- [ ] legacy schemaのrequired/type/phase/status/plan hash/allowed keyと`source=cli`をstrict検証し、トップレベル`^_`注釈キーは受理、その他の未知キーとduplicate key / `NaN` / `Infinity`は拒否する
- [ ] task+planのsemantic authority IDをledgerへrun/action/request source/actual HEAD/raw digestとともに一度だけ記録する
- [ ] Human resumeは内部観測したsame HEADまたはcanonical C-3だけのdescendant/dirty差分に限定し、`request_source_sha` / `actual_resume_head` / relationを別fieldで保存する。Human / External両経路で、初回検証後かつprepare前にHEAD-before / status・diff・ancestor / HEAD-afterを再観測し、安定かつ初回snapshot同一の最終snapshotを線形化点として保存する
- [ ] canonical External receiptをrun / task / plan / exact HEAD / action / successへ束縛し、semantic receipt ID + action IDを同じledgerで一度だけ消費する
- [ ] receiptのdev/ino/raw digestとsource relation最終snapshotをprepare直前に再照合し、一致時のみledger、record、pending clear、RUNNING state、manifestを1 prepared transactionで確定する
- [ ] Human / External resume transactionを17 fault pointずつ検証し、回復後にledger delta=`action_consumed` 1件（lifecycle total 2件）+ RUNNINGへ一意収束させる。初回source検証とprepare直前再観測のbarrierでHEAD/dirtyを変更した場合はtransaction未作成・全artifact不変を検証する
- [ ] 異なる2 runの同一Human authority同時消費を成功1 / replay拒否1へ直列化する
- [ ] loaded-source / loader identity / Python+Git executable fingerprintを全CLI operationで再照合する

**Completion Criteria**: Human / External両経路で正規receiptだけが一度消費され、C-3 JSON再整形・同一Plan authorityの全Run再利用・External replay・caller path/hash/SHA注入・approval writeはharness内で不可能である。Human/External provenance自体は保証済みと主張しない。

**Rollback**: Task 3 commitをrevertし、WAITING state生成だけへ戻す。

### Task 4: Contract and standard CI route

**Purpose**: 実装契約・保証限界を正本化し、新suiteをGitHub Actionsの標準入口へ接続する。

**Files**: Create contract / ta-62; modify `scripts/sync-plugin-plangate.sh`; generate plugin bundle.

**Interfaces**: `durable_run.py contract`; `tests/run-tests.sh` extras loader.

**Steps**:

- [ ] isolated Python、`gh_exec`境界、common-dir external lock、flat runtime/bootstrap、state / record / ledger / manifest / transaction layout、write order、recovery、error codeを文書化する
- [ ] Human-owned境界、read-only approval、trust limitを明記する
- [ ] ta-62を#1046共有exit契約（capability marker 1個 / **行頭**basename一致init / 3条件AND preamble / 7 env unset行 / rc layer 0/1/2/3 / 末尾finalize）に準拠させて追加し、各test fileをisolated direct実行する。最低46 tests・unit TC 42件のexact coverage manifest・gh_exec boundary 4 method・shell TC 4件のmapping・exact sentinel・plugin copy byte parity + direct operational fail-closedを独立検証する（R-145 / R-146）
- [ ] ta-62の**実行時契約**を満たす: 単体60秒未満の予算、clean run rc=0/3のみかつ`[FAIL]`非出力、force-fail probeのrc=1 + `PG_EXTRA_CONTRACT_PROBE_FIRED:ta-62-durable-run`伝播（独自`exit`禁止）、汚染env下でもrc=0、prerequisite未充足は`pg_extra_contract_skip`経由rc=3（R-138 / R-148）
- [ ] ta-62から`tests/run-tests.sh`を実行しない。TC-40 / TC-41 / TC-42はmapping保持のみとし、実行主体をVerification Planへ一本化する（R-139 / R-143）
- [ ] ta-62内の判定を専用カウンタ`_t62_fail`へ分離し、sentinelをそれでgateする。共有`fail`へは自身の失敗のみ加算する（R-140）
- [ ] ta-62が書き込み系Git fixture（一時repo + `git worktree add --detach`）を構築して`PG_T62_GIT_FIXTURE_ROOT` / `PG_T62_LINKED_WORKTREE`をenvで渡し、fixture依存subcase件数の下限をassertする（R-142）
- [ ] plugin parityをta-62で見る場合は`ta-26`のsandboxパターン（`mktemp -d`配下にsandbox repoを構築）を踏襲し、実`plugin/`へ書き込まない（R-143）
- [ ] `sync-plugin-plangate.sh`のscripts allowlistを対称更新して正規syncを実行し、plugin reference/runtime/tests/Git境界の派生差分を含める
- [ ] targeted regression、full suite、boundary scan、`git diff --check`を実行する

**Completion Criteria**: contract outputと文書が一致し、全automated verificationが必須method集合・最低件数・ta-62 sentinel付きでPASSする。

**Rollback**: contract / ta-62をmodule / testとともにPR単位でrevertする。

## Verification Plan

Verification Automation: `/usr/bin/python3 -I -S -B scripts/ai-loop/test_durable_run.py && /usr/bin/python3 -I -S -B scripts/ai-loop/test_gh_exec.py && sh tests/extras/ta-62-durable-run.sh && sh tests/extras/ta-61-extra-contract.sh && sh scripts/sync-plugin-plangate.sh && git diff --exit-code -- plugin/plangate/ && sh tests/run-tests.sh && /usr/bin/python3 -I -S -B scripts/ai-loop/test_delivery.py && /usr/bin/python3 -I -S -B scripts/ai-loop/test_run_evidence.py && /usr/bin/python3 -I -S -B scripts/ai-loop/test_check_exec_boundary.py && python3 scripts/ai-loop/check_exec_boundary.py && git diff --check`

> 直接実行する2 test fileはfixture非依存部分のRED / GREEN確認であり、**fixture依存subcaseを含むunit suiteの正規入口は`sh tests/extras/ta-62-durable-run.sh`**である（R-142）。直接実行時は当該subcase実行数が0であることを明示出力し、静かなskipによるfalse passを作らない。

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence保存先 |
|---|---|---|---|
| RED | `/usr/bin/python3 -I -S -B scripts/ai-loop/test_durable_run.py`、同`test_gh_exec.py` | 実装前はexpected source/interface failure | `evidence/tdd/red.log` |
| Unit | 上記2 test fileをisolated direct実行 | 合算≥46 tests、unit TC 42件 + gh boundary 4件のexact method全load、0 failed | `evidence/tdd/green.log` |
| CI route | `sh tests/extras/ta-62-durable-run.sh` | exit 0、unit/shell両manifestと`TA-62-DURABLE-RUN: PASS tests=<N> unit_tc=42 gh_boundary=4 fault=76 rollback=14`を1回出力 | `evidence/verification/ta-62.log` |
| Plugin sync | `sh scripts/sync-plugin-plangate.sh && git diff --exit-code -- plugin/plangate/` | root正本から生成した5 fileがplugin bundleと一致し、未同期差分0 | `evidence/verification/plugin-sync.log` |
| Full suite（**TC-40の実行主体** / R-139） | `sh tests/run-tests.sh` | exit 0、ta-62 sentinelが**ちょうど1回**到達（log上のgrep件数で判定） | `evidence/verification/full-suite.log` |
| Regression（**TC-41の実行主体** / R-143） | `/usr/bin/python3 -I -S -B scripts/ai-loop/test_delivery.py`、同`test_run_evidence.py`、同`test_check_exec_boundary.py` | 各0 failed、productionのdirect subprocess/multiprocessing import 0 | `evidence/verification/ai-loop-regression.log` |
| **Boundary corpus scan（R-142）** | `python3 scripts/ai-loop/check_exec_boundary.py`（`ta-57-pr-convergence.sh:80`と同経路） | exit 0 / `clean`。`test_durable_run.py`が`sys.executable`以外のargv頭や書き込み系Git subcommandを持たないこと | `evidence/verification/exec-boundary-scan.log` |
| Contract | `/usr/bin/python3 -I -S -B scripts/ai-loop/durable_run.py contract` | 文書と同一enum / transition / runtime boundary | `evidence/verification/contract.json` |
| Boundary | CLI実行前後のapproval tree・Git refs snapshot + write instrumentation + static allowlist（**収集コマンドは §Runtime Guard Constraints（R-137）に従いtoken pathをliteralで書かない** / R-144） | moduleによるapproval write / commit / merge経路0 | `evidence/verification/boundary.log` |
| **extras契約** | `sh tests/extras/ta-61-extra-contract.sh` | exit 0（TC-09/TC-10でta-62のmarker/init一致を検証。新規extras追加の回帰） | `evidence/verification/ta-61-contract.log` |
| Diff（**TC-42の実行主体** / R-143） | `git diff --check` | exit 0 | `evidence/verification/diff-check.log` |

### レビューレーン計画（#786）

| 成果物 | レーン（観点/独立性） | unavailable 時の代替 |
|---|---|---|
| Plan Package | Makerと会話contextを共有しない独立Checker: contract / security / testability | C-2 unavailableをWARN記録しHuman C-3へ未充足リスクを提示 |
| 実装diff | Makerと別contextの独立Checker: tamper / self-approval / concurrency | targeted adversarial fixture + Human C-4 |

## Plan Review Readiness

### Success Criteria

- AC: `test-cases.md`の全case
- Completion boundary: 独立module・tests・`gh_exec`のisolated read-only境界・contract文書・CI extras・plugin生成5 fileのbyte parity/direct operational fail-closed・evidenceをPRへ含める。`bin/plangate` / schema / action-bound署名receipt / plugin direct adapter / Evolution接続は別PBI。

### Review Criteria

- Design alignment: #873/#917のintent / receipt / deterministic / fail-closedを踏襲し、pre-PR責務を分離する。
- Test expectations: restart、true concurrent CAS、8 bootstrap + 初回17 + request更新17 + Human resume更新17 + External resume更新17のfault 76 subcase、14 proper subset rollback、request/消費後request idempotency、actual linked worktree、task-root replacement、Python/Git injection、actual plan/HEAD/path binding、source初回検証→prepare前のHEAD/dirty競合、record/ledger strict JSON負側、same-action result replay、**5 golden ID（非ASCII 1本を含む / R-147）**、unit TC 42件 + gh_exec boundary 4 method・最低46 testsを値レベルで検証する。fixture依存subcase（TC-43 / TC-33負側）はta-62が構築したGit fixture上でのみ実行し、未設定時は0件であることを明示出力する（R-142）。
- Security: approval artifactはdirfd canonical pathからread-only / no-followで正規schema相当検証し、schema予約の`^_`注釈だけを許可してsemantic Plan authorityをtask-wide ledgerで一度だけ消費する。raw digestとprepare直前の最終安定source snapshotはrun/action/request source/actual HEADへ証拠束縛するが、`source=cli`を署名provenanceとは扱わない。
- Maintainability: standard libraryのみ、runtime repo importはcontrolled canonical `gh_exec` sourceだけ、canonical hashはself-contained + test parity、productionのdirect subprocess/multiprocessing import 0、pure validationとI/Oを分離し、error codeをenum化する。
- Backward compatibility: 既存CLI / state / delivery recordを変更せずadditiveに導入し、`gh_exec`は既存callの既定挙動を維持したoptional isolated modeとexact read-only allowlistだけを追加する。
- Operational risk: v1はrepository canonical sourceの独立CLIであり`bin/plangate`のnonce producerとplugin direct adapterへ未接続。AC-09はmodule-level duplicate suppression contractに限定し、既存TTY経路の実害解消はfollow-up integrationが必要。Human/External provenance、whole-storage rollback、cross-clone durabilityは保証外である。

### Required Context

- Referenced issues: #870 / #873 / #874 / #869 / #920 / #923 / #938 / #945 / #981 / #982 / #1023 / #1025
- ADR / docs: `docs/workflows/ai-loop/rollout-policy.md`、`docs/workflows/ai-loop/delivery-state-machine.md`
- Existing implementation: `scripts/ai-loop/delivery.py`（pattern）、`scripts/ai-loop/c3_contract.py`（canonical hash）、`scripts/ai-loop/gh_exec.py`（唯一のexternal process境界）
- Related tests: `scripts/ai-loop/test_delivery.py`、`scripts/ai-loop/test_run_evidence.py`、`scripts/ai-loop/test_gh_exec.py`、`scripts/ai-loop/test_check_exec_boundary.py`
- Constraints: ai-loop判定基盤carve-out、C-3/C-4/merge Human-owned、HO path変更禁止

### Non-goals and Scope Boundary

- Out of scope: CLI / schema / hook / policy / migration / daemon / merge
- Change-prohibited zones: `bin/plangate`、`schemas/**`、`scripts/hooks/**`、`.claude/**`、`docs/ai/**`
- Forbidden new dependencies: すべて。Python標準ライブラリのみ。

## Runtime Guard Constraints（R-137）

- EH-13 token-guard（#1042 / `scripts/check-approval-token-write.sh`）は、`*c3.json*` / `*/approvals/*.json`を含み、かつ`_has_write_intent`（リダイレクト`>`・`cp`/`mv`/`tee`・`sed -i`・`.write(`等）に該当するBashコマンドをexit 2でblockする。`2>&1`も`>`を含むためマッチする。
- 影響: 本PBIはC-3 artifact検証を主題とするため、evidence収集・デバッグのBashが該当しやすい。とくにVerification Planの**Boundary行**（approval treeのsnapshotをlogへ書く）は素直に書くとblockされる。
- 対処: evidence収集コマンドにtoken path文字列をliteralで書かず、`approv*`等のglobで表現する。test内でPythonが実行時にfixtureを書く経路はPreToolUse hookの対象外のため影響しない。
- **`PLANGATE_SKIP_TOKEN_GUARD`はHuman-owned emergency/test-only**であり、exec中のAIがbypassとして使ってはならない。

## Replan Triggers

以下に該当した場合はexecを止め、plan更新・C-1/C-2再実行・C-3再承認を行う。

- production変更がPlan列挙の12ファイルを超える
- `bin/plangate` / schema / hook / policy / HOへの変更が必要になる
- existing `delivery.py`または`run_evidence.py`の変更が必要になる
- `check_exec_boundary.py`自体の変更、またはproduction moduleでdirect `subprocess` / `multiprocessing` importが必要になる
- `gh_exec.py` / `test_gh_exec.py` / `sync-plugin-plangate.sh`でPlan列挙外の挙動変更が必要になる
- Human C-3 artifactの追加fieldまたは生成経路変更が必要になる
- targeted baseline testに1件以上のFAILがある
- receiptをapproval artifactへ安全に束縛できずAC-04/05/07が同時成立しない
- task lock / redo recovery / canonical no-follow readを標準ライブラリだけで成立させられない
- `tests/extras/ta-61-extra-contract.sh`の**TC-09 / TC-10 / TC-12 / TC-13 / TC-15 / TC-17 / TC-20 / TC-25(3)**が新規ta-62に対してFAILし、共有exit契約準拠（静的4条件 + 実行時契約5条件）だけでは解消できない（R-138）
- ta-62単体の実行時間が**60秒予算を超え、`ta-61`のper-file 180秒timeoutに対する余裕を確保できない**（R-138）
- `check_exec_boundary.py`の`GRANDFATHER_ARGV_EXCEPTIONS`追加や`READ_ONLY`サブコマンド拡張なしには、shell層へ責務分割してもTC-43 / TC-33負側が成立しない（R-142。検査器自体の変更は既存Replan Triggerにも該当する）
- EH-13 token-guardによりVerification Planのevidence収集がbypassなしに実行できない

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
- 根拠: production変更はroot正本7ファイル + plugin生成5ファイルの計12ファイルで可逆だが、`scripts/ai-loop/**`と`docs/workflows/ai-loop/**`がrollout-policy §2の判定基盤carve-outに該当し、approval / resume境界へ隣接する。Human C-3へ固定escalateする。
