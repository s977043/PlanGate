---
task_id: TASK-1025
artifact_type: review-external
schema_version: 1
status: completed
verdict: approve
review_independence: no-maker-context
---

# TASK-1025 外部レビュー結果（C-2 Round 2）

> レビュー日: 2026-08-09
> 対象Plan SHA-256: `21a00241dc5b6c687e0e23c5033b2d8d0b422e5b73276b9eb4098de6ee3c26e2`
> Lane A: contract / implementation — reject（major 5 / minor 1）
> Lane B: focused adversarial — reject（critical 2 / major 6 / minor 1）
> 総合: reject。production変更およびC-3移行を停止した。

Historical C-2 Round 2 verdict: reject plan=sha256:21a00241dc5b6c687e0e23c5033b2d8d0b422e5b73276b9eb4098de6ee3c26e2

## Merged findings

### R-101 — critical — raw digest一意性ではsemantic replay / provenanceを保証できない

- evidence: 同じJSON semanticsでもwhitespace / key order / `_`注釈 / approved_at変更でraw SHAが変わる。legacy schemaはrun/action/source署名を持たず、`source=cli`と`approved_by` identityも暗号学的に検証されない。
- required: serialization非依存のsemantic authority keyへ変更する。scope Aを維持する場合は自己承認provenanceを保証済みと主張しない。
- disposition in revised Plan: task+plan authority IDを全Run一度消費し、raw digestはsnapshot証拠へ降格。Human/External provenanceは明示的trust limit。

### R-102 — critical — artifact pair間のproper subset rollbackを検出できない

- evidence: state↔record、ledger↔metaの個別照合だけでは整合pair単位rollbackが通る。
- required: task全体のgeneration / transaction / digestを一つのanchorで相互束縛し、proper subset rollbackを全件testする。
- disposition: ledger-metaを廃止し、task manifestが全run state/recordとledgerを一括inventory/cross-bindする。

### R-103 — major — WALのdurable syscall / initial target / stale transaction網羅不足

- evidence: ledger replaceとmeta replace間、prepare directory fsync、unlink前後、target absent、Run B recoveryが独立testでない。
- required: canonical task-wide WAL、target allowlist、absent sentinel、全durable syscall後のfault matrix。
- disposition: Plan Task 1/2、TC-23〜TC-26へ反映。

### R-104 — major — parent symlink / TOCTOU / lock inode / output path防御不足

- evidence: leaf `O_NOFOLLOW`だけではsymlink parentを追従する。task/run ID grammarとruntime output traversalも未定義。
- required: strict ID、directory FD traversal、leaf fstat、lock inode再照合、swap race test。
- disposition: Plan Global Constraints / T-10 / TC-15, TC-22へ反映。

### R-105 — major — public APIからcaller bindingを注入できる余地

- evidence: CLI option不存在だけではpublic `init_run` / `resume_run` direct callを拘束しない。
- required: public function signatureも非権威入力だけに限定しnegative testする。
- disposition: Plan Task 3 / T-10, T-18 / TC-27へ反映。

### R-106 — major — legacy C-3 strict schema相当検証不足

- evidence: phase / approved_by / approved_at / allowed key / typeのnegative caseがない。
- required: schema変更なしでrequired/type/phase/status/hash/allowed-keyを同一fd bytesで検証する。
- disposition: T-14 / TC-10へ反映。

### R-107 — major — External receiptのrun / one-shot / provenance未定義

- evidence: canonical path、run ID、same/cross-run replay、producer trust boundaryがない。
- required: exact path/schema/run binding/semantic ledger/replay tests。署名なしなら真正性非保証を明記。
- disposition: Global Constraints / T-06, T-16 / TC-28〜TC-30へ反映。

### R-108 — major — `BLOCKED` / `COMPLETED`が到達不能

- evidence: status enumにはあるがAPI/CLI/transition/testがない。
- required: explicit block/completeまたはscope削除。
- disposition: explicit API/CLI、terminal規則をT-01, T-09, T-13, T-18 / TC-34〜TC-36へ反映。

### R-109 — major — incident regression / boundary / CI testが誤PASS可能

- evidence: `bin/plangate` nonce producer未接続でも旧TCがPASS可能。grepとexit 0だけでは必須case到達を証明しない。
- required: module-level証明へACを精緻化し、before/after snapshot + instrumentation、必須method/最低件数/sentinelを固定する。
- disposition: TC-31, TC-32, TC-38〜TC-40へ反映。TTY integration未完了を残リスク化。

### R-110 — major — active runのharness bytes driftをHEADだけで検出できない

- required: module content digestをstate/actionへ束縛し全operationで再照合する。
- disposition: Global Constraints / T-07, T-13, T-17 / TC-33へ反映。

### N-001 — minor — L0 metadataが現Planと不整合

- required: INDEX/current-state/statusを新hash・C-1/C-2・TODO/TC範囲へ同期する。
- disposition: Round 3判定と同時に同期する。

## Round 3 entry conditions

1. revised Plan/TODO/TCがR-101〜R-110を追跡する。
2. 新Plan hashでC-1を再実行する。
3. maker-context非共有C-2を新Planへ再実行し、critical/major 0にする。

Round 3 approve前はproduction変更を行わない。

---

# C-2 Round 3

> 対象Plan SHA-256: `8249e738ff3eb7f1b4a99ec672ab8d28c097316671e94f1eb65afcd143b72123`
> Lane A: contract / implementation — reject（critical 0 / major 4 / minor 3 / info 4）
> Lane B: focused adversarial — reject（critical 1 / major 5 / minor 2）
> 総合: reject。production変更およびC-3移行を継続停止した。

Historical C-2 Round 3 verdict: reject plan=sha256:8249e738ff3eb7f1b4a99ec672ab8d28c097316671e94f1eb65afcd143b72123

## Round 3 merged findings

### R-111 — major — 初回namespace生成がWAL crash domain外

- evidence: run directory生成後・prepare前のcrashでmanifest未参照directoryが残り、安全なretry経路がない。
- required: flat layoutまたはstaging rename、task root/lock bootstrap、mkdir/parent fsync fault test。
- disposition: flat file layout、empty/lock-only bootstrap prestate、8 bootstrap fault label、unknown/orphan fail-closedへ変更。

### R-112 — major — harness digestがruntime dependency closureを束縛しない

- evidence: `c3_contract.canonical_hash`を実行依存にする一方、旧digestは`durable_run.py`だけだった。
- required: repo-owned runtime dependency closureまたはself-contained hash、dependency-only drift test。
- disposition: `c3_contract.py` + `durable_run.py`のdomain-separated closure fingerprint、import audit、2 dependency drift caseへ変更。

### R-113 — major — linked worktree共有の実証不足

- evidence: `--git-common-dir`のabsolute/relative差と、primary/linked worktreeが同じlock/ledgerを観測するtestがなかった。
- required: actual `git worktree add`、absolute fallback、same lock inode/ledger、unwritable preflight。
- disposition: TC-43/TC-45とT-10へ追加。

### R-114 — major — AC-05 source SHA strictnessとHuman descendant例外が矛盾

- evidence: source SHA不一致拒否とC-3-only descendant許可が同じ入力へPASS/FAIL双方を要求した。
- required: `request_source_sha` / `actual_resume_head` / relationを分離しHuman/External policyを明記。
- disposition: AC-05、Global Constraints、TC-12/13、T-15へ反映。

### R-115 — critical — ambient Git environmentでrepository / common-dirをredirect可能

- evidence: `GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, `GIT_INDEX_FILE`, `GIT_CONFIG_*`でcanonical contextとledger domainを分断できた。
- required: verified module anchor、clean Git env、NUL path parser、injection tests。
- disposition: module-file anchor、prefix `GIT_`全除去、sanitized `git -C`、`-z` parser、TC-27へ反映。

### R-116 — major — action / External semantic IDのexact payloadとgolden不足

- required: domain/version、exact field集合、precomputed literal IDs。
- disposition: Canonical ID Contract、4 golden vectors、TC-44へ反映。

### R-117 — major — anti-false-passの定量contract不足

- required: exact method names、numeric floor、fault label集合、proper subset件数。
- disposition: required 17 methods、minimum 45 tests、8+17+17 fault subcases、14 rollback subsets、exact ta-61 sentinelへ固定。

### R-118 — major — AC-09が未接続TTY producerのend-to-end解消を要求

- required: ACをmodule-levelへ狭めるHuman確認、または`bin/plangate`統合へscope拡大。
- disposition: Human選択AのHO不変更境界に従いAC-09をmodule-levelへ明確化し、end-to-end統合はfollow-up、確定PlanのC-3承認対象とする。

### N-001 — minor — Human判断Aとsemantic refinementの帰属不一致

- disposition: Aはlegacy C-3 + ledger + HO不変更、semantic IDはchecker-driven refinementでC-3待ちとPBI/Plan/decision logへ同期。

### N-002 — minor — strict JSONがduplicate key / non-standard numberを拒否しない

- disposition: common strict loaderとC-3/External/state/manifest/transaction negative casesへ追加。

### N-003 — minor — evidence/TODO/status drift

- disposition: main実測commandを`origin/main`へ修正し、T-25範囲とstatus件数をRound 3へ同期。

### N-004 — minor — BLOCKED時のpending action不変条件不足

- disposition: `run_blocked` recordへprior pending/action/reasonを保存後、terminal stateのpendingをnull。再実行/異なるmutation規則を固定。

## Round 4 entry conditions

1. R-111〜R-118 / N-001〜N-004をPlan/PBI/TODO/TCへ追跡する。
2. 新Plan hashでC-1を再実行する。
3. maker-context非共有の同じ2 laneでC-2 Round 4を実行し、critical/major 0にする。

Round 4 approve前はproduction変更を行わない。

---

# C-2 Round 4

> 対象Plan SHA-256: `dc0035afb31a42c4e9af88033cd9f5be35e5ec2c0b6c41fdd89fb1cc4526063b`
> Lane A: design / contract — reject（critical 0 / major 3 / minor 1 / info 0）
> Lane B: codebase / policy fit — reject（critical 0 / major 3 / minor 0 / info 0）
> 総合: reject（critical 0 / major 6 / minor 1 / info 0）。production変更およびC-3移行を継続停止した。

Historical C-2 Round 4 verdict: reject plan=sha256:dc0035afb31a42c4e9af88033cd9f5be35e5ec2c0b6c41fdd89fb1cc4526063b

## Round 4 merged findings

### R-119 — major — External request生成・復元・再提示の検証不足

- evidence: AC-08はHuman / External共通intentを要求する一方、旧mappingはTC-28〜TC-30のreceipt消費だけで、request生成・別process復元・重複再提示を検証しなかった。
- required: Human / External両kindのstable action、restart、同一requestでrevision / record / generation不変をmachine coverageへ追加する。
- disposition: AC-02/03/08、TC-02〜TC-04、T-04/T-06を両kindへ拡張した。

### R-120 — major — receipt消費後の同一request契約が未定義

- evidence: 消費済みactionで同じrequestを再実行すると再WAITINGし、one-shot ledgerによりresume不能となる余地があった。
- required: 完了済み結果の冪等再提示または明示errorを定義し、artifact不変・再WAITINGなしをHuman / External両方で検証する。
- disposition: 完了済みbindingを`action_already_completed`で返す契約、TC-46、T-04/T-13を追加した。

### R-121 — major — resume transaction固有のcrash / 競合検証不足

- evidence: 旧17 update fault matrixはHuman / External resumeをfixtureへ固定せず、別runの同一authority同時消費も検証しなかった。
- required: request / Human resume / External resumeそれぞれ17 fault pointを実行し、同一authorityのbarrier競合をsuccess 1 / replay 1へ収束させる。
- disposition: fault floorをbootstrap 8 + initial 17 + update 17×3 = 76へ変更し、TC-24/TC-43、T-03/T-17へ追加した。

### R-122 — minor — BLOCKED semanticsが既存運用契約と逆

- evidence: 旧Planは`BLOCKED`をterminalとしたが、`.claude/rules/working-context.md`は解除条件を持つ回復可能状態として定義する。
- required: 明示unblock契約へ変更するかscopeから外す。
- disposition: `blocked_context`へprior status / pending / reasonを保存し、明示`unblock_run`だけが復帰させる契約とTC-34を追加した。`COMPLETED`だけをterminalとする。

### R-123 — major — repository execution boundary違反

- evidence: 旧案の`durable_run.py` direct subprocessとtestの`multiprocessing`は`check_exec_boundary.py` / ta-57に抵触する。external process境界は既存`gh_exec.py`だけに限定される。
- required: productionは`gh_exec`を再利用し、test processは`subprocess` + `sys.executable`を使い、`multiprocessing`を使わない。boundary regressionを必須化する。
- disposition: `gh_exec.run_git(..., isolated_env=True)`と必要最小read-only allowlistをPlan scopeへ追加し、TC-21/27/33/41/43、T-02/T-10/T-23へ反映した。

### R-124 — major — TASK ID grammarがcanonical contractと不一致

- evidence: 旧runtime案の`TASK-[0-9]{4,10}`はschema / plan package / C-3 / deliveryの`TASK-[0-9]{4}`と不整合で、5桁以上のtaskは正規C-3を生成できない。
- required: HO/schemaを変更しない本PBIではexact 4桁へ固定する。
- disposition: PBI / Plan / TC-10 / T-10へexact `TASK-[0-9]{4}`を固定した。

### R-125 — major — plugin sync派生成果物がscope外

- evidence: rootへcontract/runtime/testを追加・変更すると`sync-plugin-plangate.sh`とplugin drift checkが派生差分を要求するが、旧Planは4 fileだけを列挙した。
- required: sync allowlistと生成対象をPlanへ含め、正規sync後のplugin差分0を検証する。
- disposition: root正本7 + plugin生成5の計12 file、T-20、Verificationのplugin sync gate、Replan条件へ追加した。

## Round 5 entry conditions

1. R-119〜R-125をPBI / Plan / TODO / TCへ追跡する。
2. 新Plan hashでC-1を再実行する。
3. maker-context非共有のdesign / codebase 2 laneでC-2 Round 5を実行し、critical/major 0にする。

Round 5 approve前はproduction変更を行わない。

## Round 4 supplemental independent findings（同一snapshot）

Round 4の同一Plan hashを別のcontract/adversarial 2 laneでも検証した。既存R-119〜R-125を補強し、以下の追加findingを検出した。これらもRound 5 entry conditionへ加える。

### R-126 — critical — External同一actionをresult差替えで再消費可能

- evidence: 旧PlanはExternal semantic receipt IDへ`result_digest`を含めたが、`action_id`自体のtask-wide unique indexがなかった。同一stable actionへ別resultを提示すると別semantic IDになり得た。
- required: 全kindの`action_id`をtask-wide一度だけ消費し、同一action + 異result/raw/semantic IDの2件目をartifact不変で拒否する。
- disposition: request作成時とledger append前のtask-wide action index、`receipt_conflict`、TC-29、T-06/T-16へ反映した。

### R-127 — major — fingerprint対象sourceと実際のloaded codeが分離可能

- evidence: ignoredかつtimestamp-validな`__pycache__/c3_contract.cpython-312.pyc`が実在し、preloaded `sys.modules`もsource path fingerprintの外でimportを差替え得た。
- required: verified source loaderを採用するかhash primitiveをself-contained化し、valid pyc / shadow / preloadをnegative testへ固定する。
- disposition: canonical hashをself-contained化し、operational mainをroot-owned isolated Pythonへ限定。空private pycache prefix、stdlib path末尾のcanonical directory、static `gh_exec` import、`__file__` / origin / loader path / source bytes照合、TC-33へ反映した。

### R-128 — major — task-root置換でlock / ledger domainを分裂可能

- evidence: swappable task root内lockでは、取得後のtask root rename + replacementにより旧/new processが別lockへ入れる。
- required: lockをtask root外のheld common-dirへ置き、全ancestor dev/inoをcanonical parentから各critical boundaryで再照合する。
- disposition: common-dir直下external lock、held dirfd chain再照合、TC-22/23/43、T-02/T-10へ反映した。

### R-129 — major — ambient Git contextがPATH/HOME/global/local configから汚染可能

- evidence: `GIT_CONFIG_NOSYSTEM=1`だけではHOME global configとlocal configが残り、PATH上の偽git、`core.fsmonitor`、`core.worktree`、untracked/status設定がrepository/clean判定へ影響し得る。
- required: executable・environment・configを固定するか明示TCBへ降格し、hostile PATH/HOME/XDG/global/local config testを追加する。
- disposition: root-owned `/usr/bin/git`、caller非継承allowlist env、caller非指定command-line override、bytes NUL parserを`gh_exec` isolated modeへ固定し、残るGit local admin metadataを明示TCB化。TC-27/33/37へ反映した。

### R-130 — major — test count floorと一部method名だけではno-op fillerを防げない

- evidence: 旧ta-61は17 exact method + 45件floorのみで、未列挙28 TCをfillerへ置換してもPASSできた。
- required: 全functional/adversarial TCをmachine-readable ID/method manifestへ一対一束縛し、shell routeも別manifestで到達を検証する。
- disposition: unit TC 42件のexact `COVERAGE_MANIFEST`、shell TC 4件の`SHELL_COVERAGE_MANIFEST`、最低46 tests、fault 76/rollback 14/sentinelをPlan・test-cases・T-20/T-21へ固定した。

### R-131 — minor — tracking metadataとscope記録がstale

- evidence: T-25がR-118/N-004までを明示せず、decision logの旧3-file scopeと現行scopeが不一致だった。
- required: finding範囲とscope correctionをappend-onlyで同期する。
- disposition: T-25をR-131まで明示し、decision logへ12-file scope・loader/Git boundary refinementの訂正entryを追記する。

### Supplemental corroboration

- R-124のTASK exact 4桁不一致は両追加laneでも再現した。
- 4 golden hash、C-3前production diff=0、bootstrap/WAL/rollback本体は同snapshotで整合を確認した。

## Extended Round 5 entry conditions

1. R-119〜R-131をPBI / Plan / TODO / TCへ追跡する。
2. 新Plan hashでC-1を再実行する。
3. maker-context非共有のcontract / adversarial 2 laneでC-2 Round 5を実行し、critical/major 0にする。

Round 5 approve前はproduction変更を行わない。

---

# C-2 Round 7（latest main reconciliation後）

> 対象Plan SHA-256: `d35c47a102bcdf2e9ed6700a2fb8d28b60326d06ec8b72baca0214c6bb68cc39`
> Lane A: design / contract — reject（critical 0 / major 2 / minor 0 / info 0）
> Lane B: codebase / policy fit — approve（critical 0 / major 0 / minor 1 / info 2）
> 総合: reject（critical 0 / major 2 / minor 1 / info 2）。production変更およびC-3移行を継続停止した。

Historical C-2 Round 7 verdict: reject plan=sha256:d35c47a102bcdf2e9ed6700a2fb8d28b60326d06ec8b72baca0214c6bb68cc39

## Round 7 merged findings

### R-132 — major — source relationの線形化点とprepare前再照合が未定義

- evidence: receipt pathはprepare直前に再照合する一方、初回HEAD/status/diff/ancestor確認後に別processがHEADまたはdirty stateを変更できた。
- required: task lock内のWAL prepare直前にHEAD-before / status・diff・ancestor / HEAD-afterを再観測し、安定かつ初回snapshot同一の最終snapshotを線形化点として保存する。Human/External両経路へbarrier競合testを追加する。
- disposition: AC-05、Plan Global/Task 3/Review Criteria、T-05/T-15/T-17、TC-12/TC-13へ反映。

### R-133 — major — record / ledger strict JSONの負側coverage不足

- evidence: 共通strict loader契約は全JSONを対象にしたが、旧TC-10/17/18ではrecord/ledgerのduplicate key・非標準数・未知key/eventを固定していなかった。
- required: record/ledger各々にduplicate key、`NaN`/`Infinity`、unknown key、unknown event kindの負側subcaseを追加する。
- disposition: AC-06、Plan/T-09/T-11、TC-10/TC-17/TC-18へ反映。

### R-134 — minor — canonical CLI C-3の`^_`注釈key受理を明示する

- evidence: `schemas/c3-approval.schema.json`はトップレベル`^_`を許可し、`bin/plangate approve`は3つの注釈keyを生成する。
- required: 実CLI生成C-3の`^_`注釈は受理し、非`_`未知keyだけを拒否するfixtureを固定する。
- disposition: Plan Global/Task 3、T-05/T-09/T-14、TC-10へ反映。

## Round 8 entry conditions

1. R-132〜R-134をPBI / Plan / TODO / TCへ追跡する。
2. 新Plan hashでC-1を再実行する。
3. maker-context非共有のdesign / codebase 2 laneでC-2 Round 8を実行し、critical/major 0にする。

Round 8 approve前はproduction変更を行わない。

---

# C-2 Round 8（R-132〜R-134反映後）

> レビュー日: 2026-08-11
> 対象Plan SHA-256: `c864c06ab1b52b68a298756b7c0050904ba8ed3713faa208b6cb637da949d516`
> Lane A: design / contract — approve（critical 0 / major 0 / minor 0 / info 0）
> Lane B: codebase / policy fit — approve（critical 0 / major 0 / minor 0 / info 0）
> 総合: **approve**（critical 0 / major 0 / minor 0 / info 0）。Human C-3へ進行可能。

C2-VERDICT: APPROVE plan=sha256:c864c06ab1b52b68a298756b7c0050904ba8ed3713faa208b6cb637da949d516

## Round 8 verification

| finding | 判定 | evidence |
|---|---|---|
| R-132 source relation linearization | resolved | AC-05、Task 3、T-15/T-17、TC-12/13がprepare直前のstable HEAD snapshot、初回snapshot一致、競合時artifact不変拒否を固定 |
| R-133 record/ledger strict JSON | resolved | AC-06、T-09/T-11、TC-10/17/18がduplicate key、NaN/Infinity、unknown key/event enumを固定 |
| R-134 canonical C-3 annotations | resolved | schema/CLIとPlan/TODO/Testが`^_`注釈key受理、非注釈未知key拒否、注釈のsemantic authority ID除外で一致 |

両laneとも指定文書および既存契約をread-onlyで検証した。production実装・C-3 artifact生成・C-4・mergeは未実施。
