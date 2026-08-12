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

Historical C-2 Round 8 verdict: APPROVE plan=sha256:c864c06ab1b52b68a298756b7c0050904ba8ed3713faa208b6cb637da949d516

## Round 8 verification

| finding | 判定 | evidence |
|---|---|---|
| R-132 source relation linearization | resolved | AC-05、Task 3、T-15/T-17、TC-12/13がprepare直前のstable HEAD snapshot、初回snapshot一致、競合時artifact不変拒否を固定 |
| R-133 record/ledger strict JSON | resolved | AC-06、T-09/T-11、TC-10/17/18がduplicate key、NaN/Infinity、unknown key/event enumを固定 |
| R-134 canonical C-3 annotations | resolved | schema/CLIとPlan/TODO/Testが`^_`注釈key受理、非注釈未知key拒否、注釈のsemantic authority ID除外で一致 |

両laneとも指定文書および既存契約をread-onlyで検証した。production実装・C-3 artifact生成・C-4・mergeは未実施。

---

# C-4 / base drift review（2026-08-12・PR #1043 に対する独立レビュー）

> レビュー日: 2026-08-12
> 対象Plan SHA-256（レビュー時点）: `sha256:c864c06ab1b52b68a298756b7c0050904ba8ed3713faa208b6cb637da949d516`
> レーン: 設計妥当性 / codebase 整合（maker-context 非共有・spec-writer レーン）
> 総合: **conditional** — Plan 内部の整合は critical 0 / major 0。**base drift 起因の major 2 / minor 1** を検出。

Historical C-4 base-drift verdict: conditional plan=sha256:c864c06ab1b52b68a298756b7c0050904ba8ed3713faa208b6cb637da949d516

## 機械照合できた項目（指摘なしを明示記録）

| 検証 | 方法 | 結果 |
|---|---|---|
| Canonical ID golden vector 4 本 | 記載 canonical bytes を SHA-256 で再計算 | 4/4 一致 |
| payload 表 → canonical bytes | 表の field 定義から `json.dumps(sort_keys=True, separators=(",",":"))` を再構成し byte 比較 | 4/4 一致 |
| AC↔TC traceability | レンジ展開して集合演算 | AC-01〜10 全件 / 定義 46 = 被覆 46 / orphan 0 / 未定義参照 0 |
| 件数整合 | 12=7+5 / fault 76=8+17+17×3 / rollback 14=2⁴−2 / 46=42+4 / WAL label 17・bootstrap label 8 の実列挙 | すべて一致 |
| 抽出器契約 | `## Files / Components to Touch` / `Verification Automation:` 行 | 両方あり |
| ゲート鎖の同一性 | PR head の plan.md を `shasum -a 256` | `sha256:c864c06ab1b52b68a298756b7c0050904ba8ed3713faa208b6cb637da949d516` = C-1/C-2 Round 8 の宣言ハッシュと一致 |

## R-135 — major — 新規 extras が #1046「extras 共有 exit 契約」に未対応

- evidence: `main@48f6971`（PR #1046 / TASK-0921 Slice 1）で `tests/extras/_extra-contract.sh` と `ta-61-extra-contract.sh` が発効。TC-09/TC-10 の covered set は全 `ta-*.sh` から `_pending_migration()` の**リテラル列挙**のみを除外するため、**新規ファイルは即 covered set に入り契約準拠が必須**。旧 Plan / test-cases 内の `PG_EXTRA_CAPABILITY` / `_extra-contract` / `pg_extra_contract_init` 出現数は **0 件 / 0 件**だった。
- impact: 計画どおり新規 extras を作ると TC-09 が FAIL する（exec 時に CI レッド）。
- required: capability marker（先頭 20 行にちょうど 1 個）・basename 一致 init・rc layer 0/1/2/3・末尾 finalize を Plan / TODO / test-cases へ落とす。移行期 allowlist へは追加しない。
- disposition in revised Plan: Global Constraints に契約準拠を明記、Task 4 step と T-20 checkpoint を更新、Verification Plan に `sh tests/extras/ta-61-extra-contract.sh` 行を追加、test-cases の Verification 節に TC-09/TC-10/TC-20 の検証を追記。

## R-136 — minor — `ta-61` 番号の占有

- evidence: `ta-61-extra-contract.sh` が既に存在。ただし TC-20 の一意性判定は番号でなく **basename 全体**のため、衝突しても TC-20 は FAIL しない（過大評価しない）。
- required: 番号規約と可読性のため次番へ振り替える。
- disposition in revised Plan: 新規 extras を **`tests/extras/ta-62-durable-run.sh`** へ改名。sentinel も `TA-62-DURABLE-RUN` へ横断更新（plan / todo / test-cases / status / evidence path）。

## R-137 — minor（exec 時は major 化しうる） — EH-13 token-guard が evidence 収集を block しうる

- evidence: `scripts/check-approval-token-write.sh`（#1042 / `15b0c16`）は `*c3.json*` / `*/approvals/*.json` を含み、かつ `_has_write_intent`（`>` 等）に該当する Bash を exit 2 で block する。**`2>&1` も `>` を含むためマッチ**し、読み取り専用コマンドでも発火する（本レビュー中に実測）。
- impact: 本 PBI は C-3 artifact 検証が主題で、とくに Verification Plan の Boundary 行（approval tree snapshot を log へ書く）が該当しやすい。
- required: Risks / Replan Trigger へ明記し、evidence 収集で token path を literal で書かない運用にする。`PLANGATE_SKIP_TOKEN_GUARD` は Human-owned のため AI の bypass に使わない。
- disposition in revised Plan: `## Runtime Guard Constraints（R-137）` を新設し、Replan Triggers に 1 行追加。

## Round 9 entry conditions

1. R-135〜R-137 を Plan / TODO / test-cases / status へ反映する（**本 PR で反映済み**）。
2. 新 Plan hash `sha256:8b0a5018aacb1008d83615c725a1107c627d7e44521d29854dc2445b3d449c55` で **C-1 を再実行する**（本 PR で Round 9 として実行済み・PASS）。
3. **maker-context 非共有の design / codebase 2 lane で C-2 Round 9 を実行し、critical/major 0 にする**（**未実施**）。

> **重要**: 本追補により Round 8 の C-2 APPROVE は対象 Plan hash が変わって失効した。したがって `C2-VERDICT:` の live マーカーは**意図的に存在しない**（`plan_package.check_evidence` は「完全一致 0 回」で fail-closed になる）。これは異常ではなく、**C-2 Round 9 未実施を機械可読に表現した状態**である。Round 9 approve 前に production 変更と C-3 へ進まない。

---

# C-2 Round 9（R-135〜R-137 反映後 / 2 lane）

> レビュー日: 2026-08-12
> 対象 Plan SHA-256: `sha256:8b0a5018aacb1008d83615c725a1107c627d7e44521d29854dc2445b3d449c55`
> Lane A: 設計妥当性（plan / todo / test-cases / pbi-input・maker-context 非共有） — **reject**（critical 0 / major 4 / minor 3）
> Lane B: コードベース整合（既存パターン該当箇所） — **reject**（critical 0 / major 3 / minor 4）
> 統合: **reject**（critical 0 / major 6 / minor 6）。production 変更および C-3 移行を継続停止した。

Historical C-2 Round 9 verdict: reject plan=sha256:8b0a5018aacb1008d83615c725a1107c627d7e44521d29854dc2445b3d449c55

## 両レーンが「問題なし」と確認した項目（指摘なしを明示記録）

| 検証 | 方法 | 結果 |
|---|---|---|
| AC↔TC 網羅 | レンジ展開して集合演算（レビュアーが独自に再計数） | AC-01〜10 全件 / 定義 46 = 被覆 46 / orphan 0 |
| `_pending_migration()` へ `ta-62` を追加しない判断 | `ta-61` TC-25 の "already-migrated file still listed" 経路 | 正しく、かつ機械的に強制される |
| R-136 の改名 | `ta-61\|TA-61` 残存の内訳確認 | 横断的に完了（残存 5 件はすべて `extra-contract` 文脈か履歴行） |
| R-137 の EH-13 記述 | `_is_token_path` / `_has_write_intent` 実装との突合 | 正確 |
| 承認権限 | issue Non-goals との突合 | 増やしていない |
| `ta-62` の番号 | `ta-04`〜`ta-61` の使用状況・リポジトリ全体の参照 | 空き（参照 0 件） |
| HO 境界 | 9 カテゴリ / carve-out / `mode: critical` / `lite_eligible: false` | 判定は妥当 |
| `delivery.py` の独立実装 | `append_entries` が plain append（fsync / atomic replace なし） | 耐久性要件を満たさないため独立実装は妥当 |

## Round 9 findings

### R-138 — major（両レーン一致） — #1046 契約の「実行時半分」が Plan に未反映

- lane: 設計妥当性 + コードベース整合
- evidence: R-135 で反映した準拠条件（marker 1 個 / basename 一致 init / rc layer / 末尾 finalize）は `ta-61` の **TC-09 / TC-10（静的 grep）にしか対応しない**。`tests/extras/ta-61-extra-contract.sh:282-355` の per-file 実行ループは covered な standalone-capable ファイルを **1 ファイルにつき 3 回実行**し、(1) stage-1 clean run の rc が **0 か 3 のみ**（`:315-353` / それ以外は fail-closed で FAIL）、(2) **180 秒 timeout・timeout は SKIP でなく FAIL**（`:58-63`, `:311-314`）、(3) rc=0 の run が `[FAIL]` を出力しない（`:319-321`）、(4) force-fail probe で rc=1 かつ `PG_EXTRA_CONTRACT_PROBE_FIRED:ta-62-durable-run` を出力（`:325-330`）、(5) 汚染 env（`PG_HARNESS_SOURCED=1` + 全 guarded env に junk）でも rc=0（`:332-338`）を要求する。Plan / TODO / test-cases にこの 5 要求は一言も無い。
- impact: `ta-62` は 46+ tests / fault injection 76 subcase / rollback 14 subcase / `git worktree add` を伴う TC-43 / 2-writer 並行の TC-21 を含む重量スイートであり、これが **3 回 × 180 秒枠**で走る。予算・probe 伝播・skip 経路が未定義のまま exec すると CI レッドになる。
- required: Global Constraints へ (a) `ta-62` 単体の実行時間予算（整合レーン提示: **60 秒未満**を目安）、(b) clean run が `[FAIL]` を出さないこと、(c) probe 差分が rc=1 へ伝播すること（＝独自 `exit` 禁止・共有 `fail` カウンタ経由）、(d) prerequisite 未充足（`/usr/bin/python3` 不在等）は必ず `pg_extra_contract_skip` 経由で rc=3（`:341-349` が診断なしの rc=3 を FAIL にする）を明記する。Replan Trigger の TC 列挙を `TC-09/TC-10/TC-20` → `TC-09/TC-10/TC-12/TC-13/TC-15/TC-17/TC-20/TC-25(3)` へ拡張する。
- disposition in revised Plan: Global Constraints に `ta-62` 実行時契約 4 項目を追加、Replan Trigger の TC 列挙を拡張し実行時間予算超過を追加、TODO T-20 checkpoint と test-cases TC-39 / TC-40 へ反映。R-148 を本 finding に統合。

### R-139 — major（両レーン一致） — 無限再帰。`PG_T62_NO_RECURSE` が存在しない

- lane: 設計妥当性 + コードベース整合（オーガナイザーが実物で裏取り）
- evidence: `ta-61` の nested full-suite（`:766` / `:792` / `:800`）は `PG_T61_NO_RECURSE=1` を渡すが、**per-file 実行ループ（`:310` / `:327` / `:334`）は再帰ガードを渡さない**。Plan `:125` の「`tests/run-tests.sh` 経由でも同 sentinel が 1 回到達しなければ FAIL」を「`ta-62` が `run-tests.sh` を実行する」と読むと `run-tests.sh → ta-61 → per-file ループが ta-62 を standalone 実行（ガードなし）→ ta-62 が run-tests.sh を実行 → …` で無限再帰し、180 秒 timeout で切れて TC-12 が FAIL する。実測: `PG_T61_NO_RECURSE=1 sh tests/run-tests.sh` = **255 秒 / 644 passed**（ガードで重い子を skip した下限値）であり、`ta-62` が suite を起動すれば単体で 180s 超は確実。
- required: (a) 推奨 = `ta-62` は `run-tests.sh` を実行しない（mapping と sentinel 出力のみ）と 1 行で明記し、**TC-40 の実行主体を Verification Plan の Full suite 行へ一本化**する（`ta-61:781-783,806-807` の「harness 実行時は囲っている run 自体が TC-14 の証拠」という既存の割り切りの踏襲）。(b) 実行させるなら `PG_T62_NO_RECURSE` を導入（`run-tests.sh:20` の unset 7 変数に含まれないため子へ伝播する）+ `pg_extra_contract_is_standalone` による二重ガード。
- disposition in revised Plan: **(a) を採用**。Global Constraints へ「`ta-62` は `tests/run-tests.sh` を実行しない」を明記し、`SHELL_COVERAGE_MANIFEST` の TC-40 を「実行主体 = Verification Plan Full suite 行 / `ta-62` は mapping 保持のみ」へ変更。test-cases TC-39 / TC-40 と TODO T-20 も同期。

### R-140 — major（設計妥当性レーン） — sentinel が共有 `fail` カウンタに依存し実行順序で非決定になる

- lane: 設計妥当性
- evidence: `tests/run-tests.sh:26-27` の `pass` / `fail` は全 extras 共有のグローバル集計カウンタで、`_extra-contract.sh` の harness パスはこれをそのまま使う（`pg_extra_contract_finalize` は harness では `return 0` して runner に委ねる）。Plan は「成功時だけ sentinel を出す」と要求するが `ta-62` ローカルの成否カウンタを定義していない。素直に `[ "$fail" -eq 0 ]` で判定すると、`ta-62` より前に source された無関係な extras の失敗で sentinel が抑止され、TC-40（ちょうど 1 回）が実行順序依存で非決定になる。
- impact: #1046 が封じようとした「静かに通る／静かに落ちる」の再導入。
- required: Global Constraints へ「`ta-62` は自身の判定に専用カウンタ（例 `_t62_fail`）を用い、sentinel はそれで gate する。共有 `fail` へは自身の失敗のみ加算する」を明記する。
- disposition in revised Plan: Global Constraints へ専用カウンタ契約を追加、TODO T-20 checkpoint と test-cases TC-39 へ反映。

### R-141 — major（設計妥当性レーン） — issue #1025 Scope の一部が Plan Package 全体で 0 件

- lane: 設計妥当性
- evidence: 各ファイル grep 実測 0 件。`phase` / `current_node`（Scope 1・state の永続フィールド）、`last_error`（Scope 1・観測事実と原因仮説を分離）、`approval_session_lost`（Scope 4）、`external_wait_resumed`（Scope 4）が plan / todo / test-cases / pbi-input のいずれにも出現せず、Out of Scope 宣言も無い。AC-01〜10 は「Durable Run State の完全性」を語るが、**state の永続フィールド集合そのものを一度も列挙していない**（`run--<RUN_ID>--state.json` の存在は書くがスキーマを書かない）。AC↔TC の orphan ではなく **issue 要求↔AC の orphan**。とくに `last_error` の「観測事実と原因仮説の分離」は issue が明示的に括弧書きした設計要求で、後付けが難しい構造要件。
- 注記: Round 9 の追補が持ち込んだものではなく **pbi-input 起点の既存ギャップ**で、Round 1〜8 の C-2 でも検出されていない。`plan_hash` が失効している今が是正の適時。
- required: (a) Global Constraints に state.json の必須フィールド集合を列挙し Incident Evidence 5 event の語彙を固定して AC-06 または新 TC に紐付ける、または (b) v1 では扱わないと Out of Scope に明記し follow-up issue を起票する。「触れない」は不可。
- disposition in revised Plan: **(b) を採用**。Scope / Out of Scope に 4 項目を名指しで追加し、`last_error` の retrofit 困難性と follow-up issue 起票が必須である旨を明記。**follow-up issue はまだ未起票**（Human 判断待ち）。

### R-142 — major（コードベース整合レーン） — TC-43 / TC-33 負側が `check_exec_boundary.py` の test 規約で実装不能

- lane: コードベース整合（設計妥当性レーンでは出せない指摘）
- evidence: `scripts/ai-loop/check_exec_boundary.py` は `test_*.py` の `subprocess` について argv 先頭が `sys.executable` か リテラル `"git"` + 読み取り専用サブコマンド 7 種（`status` / `rev-parse` / `diff` / `log` / `merge-base` / `ls-remote` / `show`、`:156`）のみ許可し、絶対パス（`"/usr/bin/git"`）は `CODE_ARGV_HEAD`、変数経由は `CODE_ARGV_UNRESOLVED` で fail-closed。`GRANDFATHER_ARGV_EXCEPTIONS`（`:169`）は「1 件から増やさない」と明記（`:275`）。TC-43 の `git init` / `add` / `commit` / `worktree add --detach` はすべて allowlist 外、TC-33 の「root-owned `/usr/bin/python3 -I -S -B` 以外で起動する」負側も argv[0] が `sys.executable` でないため同じく violation。検査は `base.glob("*.py")`（`:1142`）で `scripts/ai-loop/` 全 .py が自動対象、強制点は `tests/extras/ta-57-pr-convergence.sh:80` の corpus scan（exit 0 必須）。Plan の Regression 行が回す `test_check_exec_boundary.py` は**検査器自身のテストであり corpus scan ではない**。既存 ai-loop テストで実 Git repo を作っているものは 0 件（全て `git status/show/diff` かスパイ）。回避のため `check_exec_boundary.py` を触ると `plan.md:362` の Replan Trigger が発火する。
- required: 書き込み系 Git fixture を `ta-62`（シェル層・boundary scan の対象外）で構築し、Python 側は生成済み repo に対する読み取り＋`sys.executable` 経由の CLI 起動だけにする責務分割を Work Breakdown へ明記する。あわせて Verification Plan へ `python3 scripts/ai-loop/check_exec_boundary.py` exit 0（ta-57 経路）を**独立行**として追加する。
- disposition in revised Plan: Global Constraints へ責務分割契約と fixture env 受け渡し（`PG_T62_GIT_FIXTURE_ROOT` / `PG_T62_LINKED_WORKTREE`）を追加、Task 1 / Task 4 step と TODO T-07 / T-20 を更新、Verification Plan へ boundary corpus scan 行を独立追加、test-cases TC-33 / TC-43 / TC-39 を更新。

### R-143 — major（コードベース整合レーン） — `ta-62` がリポジトリ全体状態に依存する assertion を内包している

- lane: コードベース整合
- evidence: `plan.md:124` は `SHELL_COVERAGE_MANIFEST` に TC-41 / TC-42 を含める。`git diff --check`（TC-42）を `ta-62` 内で実行すると無関係な作業ツリーの空白エラーで `ta-62` が rc=1 → `ta-61:352` の「rc が 0 でも 3 でもない」で fail-closed → full suite 赤になる。TC-41（delivery / run_evidence regression）も `ta-62` が 3 回実行される前提では純粋な重複コスト。plugin sync を実リポジトリに対して走らせる場合の既存パターンは `ta-26` の sandbox 構築（`ta-26:95-99` / #861「実リポジトリ非破壊化」）か `ta-54` の `plugin/plangate` バックアップ（`ta-54:39-44`）だが、Plan はどちらに従うか書いていない。
- required: TC-41 / TC-42 は Verification Plan（PR 単位の実行）に残し `ta-62` の in-file 実行からは外す。plugin parity を `ta-62` で見るなら `ta-26` / `ta-54` のどちらの非破壊パターンを踏襲するか明記する。
- disposition in revised Plan: `SHELL_COVERAGE_MANIFEST` を「実行主体」列付きへ変更し TC-40 / TC-41 / TC-42 を Verification Plan 実行・`ta-62` は mapping 保持のみへ変更（coverage の orphan を作らない）。plugin parity は **`ta-26` の sandbox パターン踏襲**を Global Constraints と Task 4 へ明記。

### R-144 — minor — `plan.md:307` の Boundary 行本体が未修正

- evidence: EH-13 回避策は `:348-353` の新設節（Runtime Guard Constraints）にしかなく、Verification Plan の表だけを見た実装者は block される。
- required: Boundary 行に「§Runtime Guard Constraints 参照」の相互参照を 1 語入れる。
- disposition in revised Plan: Verification Plan の Boundary 行へ相互参照を追加。

### R-145 — minor — `ta-26` TC-33 の静的要件が準拠条件に入っていない

- evidence: `FIXTURES_DIR:-` を含む extras は自ファイル内に `run-tests.sh` と同一の 7 env unset 行を持つことが**静的に**要求される（helper が unset していても静的検査のため冗長行が必須。`ta-61:34-39` が実例）。
- required: `plan.md:86` の準拠条件へ追記する。
- disposition in revised Plan: Global Constraints の `ta-62` 準拠条件へ 7 env unset 行を追加、TODO T-20 checkpoint へ反映。

### R-146 — minor — init 呼び出しの行頭必須と harness 実行時の `$0` 差

- evidence: `ta-61:239` の `grep -E '^pg_extra_contract_init[[:space:]]'` により init 呼び出しは行頭（インデント無し）必須。かつ harness 実行では `$0` が `run-tests.sh` なので `dirname $0` では helper に到達しない。
- required: preamble（`PG_HARNESS_SOURCED` / `FIXTURES_DIR` / `EXTRAS_DIR` の 3 条件 AND による mode 判定 + `EXTRAS_DIR` 分岐）を `ta-62` の必須要素として明記する。
- disposition in revised Plan: Global Constraints の準拠条件へ preamble 契約と行頭 init を追加。

### R-147 — minor — canonical hash の `ensure_ascii` が契約に無い

- evidence: `c3_contract.canonical_hash`（`scripts/ai-loop/c3_contract.py:71-74`）は `json.dumps(..., sort_keys=True, separators=(",", ":"))` で `ensure_ascii` 既定 `True` だが、`plan.md:92` に明示が無い。`instructions_ref` は日本語パスやアンカーが入りうるのに golden vector 4 本は全 ASCII なので、実装が `ensure_ascii=False` でも TC-44 parity が空振りする。
- required: 契約に `ensure_ascii=True` を明記し、非 ASCII を含む golden vector を 1 本追加する。
- disposition in revised Plan: Canonical ID Contract に `ensure_ascii=True` を明記し、非 ASCII `instructions_ref` の 5 本目 golden vector を追加（実測: `ensure_ascii=True` → `sha256:229416de…` / `ensure_ascii=False` → `sha256:20c5bd76…` で差が出る＝空振りしない）。golden vector 件数を 4 → 5 へ横断更新。

### R-148 — minor — `/usr/bin/python3` 不在時の rc=3 経路が未定義

- evidence: `ta-61:341-349` は診断なしの rc=3 を「forbidden route」として FAIL にする。
- required: prerequisite 未充足は必ず `pg_extra_contract_skip` 経由で rc=3 にする。
- disposition in revised Plan: **R-138 の是正へ統合**（Global Constraints の `ta-62` 実行時契約 (d)）。

### R-149 — minor — `review-self.md:123` の自己申告が自ファイルで反証されている

- evidence: 「`ta-61|TA-61` の残存 0（extra-contract 文脈を除く）」に対し、同ファイル `:39` に「fault 76 の ta-61 exact sentinel」が残っている。append-only の履歴行なので実害は小さいが、自己申告が自ファイルで反証されている。
- required: 除外条件を「extra-contract 文脈および Round 8 以前の履歴行を除く」と正確化する。
- disposition in revised Plan: `review-self.md` の Round 10 節で除外条件を正確化して再申告（Round 9 節の既存記述は append-only のため書き換えない）。

## Round 10 entry conditions

1. R-138〜R-149 を Plan / TODO / test-cases / status へ 1 回で確定反映する（**本コミットで反映済み**）。
2. 新 Plan hash で簡易 C-1（Round 10）を再実行する（**本コミットで実行済み**）。
3. maker-context 非共有の design / codebase 2 lane で C-2 Round 10 を実行し、critical / major 0 にする（**未実施**）。
4. R-141 の follow-up issue（`phase` / `current_node` / `last_error` / `approval_session_lost` / `external_wait_resumed` の v2 取り込み）を Human が起票する（**未起票**）。

Round 10 approve 前に production 変更と C-3 へ進まない。live `C2-VERDICT:` マーカーは引き続き**意図的に不在**（fail-closed）。

## 監査表（追記専用）

| R-NNN | severity | lane | status | reflected_in(commit) | notes |
|---|---|---|---|---|---|
| R-138 | major | 両レーン | reflected | 本コミット | `ta-62` 実行時契約 4 項目 + Replan Trigger TC 列挙拡張。R-148 を統合 |
| R-139 | major | 両レーン | reflected | 本コミット | 選択肢 (a) 採用: `ta-62` は `run-tests.sh` を実行しない |
| R-140 | major | 設計 | reflected | 本コミット | 専用カウンタ `_t62_fail` で sentinel を gate |
| R-141 | major | 設計 | reflected (b) | 本コミット | Out of Scope へ明記。**follow-up issue は未起票**（Human 判断） |
| R-142 | major | 整合 | reflected | 本コミット | 書き込み系 Git fixture を shell 層へ責務分割 + boundary corpus scan 行追加 |
| R-143 | major | 整合 | reflected | 本コミット | TC-41 / TC-42 を `ta-62` in-file 実行から除外。plugin parity は `ta-26` パターン |
| R-144 | minor | 設計 | reflected | 本コミット | Boundary 行に相互参照 |
| R-145 | minor | 整合 | reflected | 本コミット | 7 env unset 行を準拠条件へ |
| R-146 | minor | 整合 | reflected | 本コミット | 行頭 init + preamble 契約 |
| R-147 | minor | 整合 | reflected | 本コミット | `ensure_ascii=True` 明記 + 非 ASCII golden vector 追加（4 → 5 本） |
| R-148 | minor | 整合 | merged into R-138 | 本コミット | prerequisite 未充足は `pg_extra_contract_skip` 経由 rc=3 |
| R-149 | minor | 設計 | reflected | 本コミット | `review-self.md` Round 10 で除外条件を正確化 |
