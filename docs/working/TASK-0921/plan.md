---
task_id: TASK-0921
artifact_type: plan
schema_version: 1
status: draft
mode: high-risk
related_issue: https://github.com/s977043/PlanGate/issues/921
created_by: orchestrator
---

# TASK-0921 Implementation Plan

## Goal

`tests/extras/ta-*.sh` の直接実行を、standalone 対応テストでは内部失敗を exit 1 へ確実に伝播し、harness 専用テストでは誤動作する前に exit 2 で拒否する明示的契約へ移行する。

## Context

- Issue: [#921](https://github.com/s977043/PlanGate/issues/921)
- Input: [`pbi-input.md`](./pbi-input.md)
- Dependency #914: 2026-08-04 に close。11 extras の harness 判別 AND 化と外部 env 無害化は完了
- Existing canonical example: `tests/extras/ta-26-plugin-sync.sh`
- Harness: `tests/run-tests.sh` は `PG_HARNESS_SOURCED=1` を非 export で設定し、各 extras を source。集計後に `fail > 0` なら exit 1
- Current failure: standalone では内部 `[FAIL]` があっても exit 0。harness 専用 file は未定義 fixture 前提のまま走って exit 0 になりうる
- Current inventory count is mutable. pbi-input 作成時は53、本backlog監査時は57との実測があるため、**件数を仕様へ固定しない**

## Scope

### In Scope

- 全 `tests/extras/ta-*.sh` の runtime inventory と capability classification
- `standalone-capable` / `harness-only` の機械可読 marker
- 共通 standalone contract helper
- standalone-capable: counter初期化、外部env隔離、cleanup、summary、`fail > 0 → exit 1`
- harness-only: direct invocation を標準message + exit 2で即時拒否
- harness source 経路で個別 extras が process exit しないこと
- 新規 extras が契約未宣言・未実装なら failする回帰テスト
- 全 standalone-capable の failure propagation を実行ベースで検査する test seam
- README規約、#914 handoffのV2候補writeback

### Out of Scope

- 各 extras のテスト内容・期待値の見直し
- `tests/run-tests.sh` の集計アルゴリズム変更
- harness/standalone 判別シグナルの再設計
- harness-only extras の完全 standalone 対応
- README の現行テスト一覧ドリフト修正
- shell test framework 導入

## Global Constraints

- C-3 前に実装しない
- sourceされた extras から `exit` して harness 全体を終了させない
- helperはPOSIX `sh` で動作し、bash専用構文を使わない
- file count / ta番号一覧を正本としてハードコードしない
- direct invocation probe は必ず `</dev/null` を付け、ta-50等のstdin待ちを防ぐ
- 外部env汚染により harness mode と誤認しない。`PG_HARNESS_SOURCED=1` と有効な `FIXTURES_DIR` のANDを維持
- cleanupは repository外の登録済みtmpのみを削除し、未検証pathを `rm -rf` しない
- contract test の故障注入は fail-safe（テストを余分に失敗させる方向）とし、successを偽装しない
- #994のTC-33 observation gapを前提にせず、本Taskのcontract testは対象condition/markerを直接検査する

## 前提の実測検証

| 前提 | 検証 | 実測 | 判定 |
|---|---|---|---|
| #914 完了 | Issue state | closed/completed 2026-08-04 | ✅ |
| harness は source + global counters | `tests/run-tests.sh` | `pass=0`, `fail=0`, `PG_HARNESS_SOURCED=1`, `. "$extra"` | ✅ |
| ta-26 は standalone exit伝播の前例 | ta-26 top/tail | standalone flag、cleanup、summary、fail時exit1 | ✅ |
| layer A file に early exit がありうる | ta-39 | prerequisite未適用時にreturn/exit 0 | ✅ |
| current file countは変動する | pbi-inputと最新監査 | 53→57 | ✅。runtime inventory必須 |

## Questions / Unknowns

- 現 main における正確な `ta-*.sh` inventory と capability分類。exec開始時に構造/実走で確定する
- standalone-capable filesが現在の11 + ta-26以外に増えているか
- top-level `trap 0` を独自利用する extras が存在するか。存在する場合は共有trap案を採用せずexplicit finalizerへreplan
- helperを `run-tests.sh` から一度sourceする変更が「集計ロジック変更ではない」とC-2/C-3で許容されるか
- contract probe envを `run-tests.sh` 冒頭でunsetすべきか。通常runではfail-safeだが、外部envの予期しないtest failureを避けるならHuman判断で追加

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | ta-26のheader/footerを各standalone-capableへ複製、harness-onlyへinline guard | 新helperなし、局所的 | early exitごとにfinalizer呼出が必要、将来drift、重複が多い | 不採用 |
| B | 全extrasをsubprocess実行するようrunnerを再設計 | process isolation、exit契約が自然 | harness global counters/fixtures/cleanup契約を全面変更、scope過大 | 不採用 |
| C | 共通helper + capability marker。standalone-capableのみstandalone時の終了trap、harness-onlyはhelperがexit2 | 終了経路を漏らさず一元化、新規fileをinventory testで拘束 | 全filesへinit call、trap互換性の事前調査が必要 | 条件付き採用 |
| D | 共通helper + 各file末尾explicit finish | trapを避けられる | early return/exit漏れを静的に完全検出しにくい | C不可時のfallback |

### Recommended Approach

案Cを第一候補とする。

`ta-39` のような早期 `exit 0` が存在するため、末尾footerの複製だけではfailure propagationを全終了経路で保証できない。standalone modeでのみ `trap ... 0` を設定すれば、harness source連鎖のtrapを上書きせず、normal/early exitの双方でcleanupと最終rcを一元化できる。

ただし、exec前inventoryでtop-level exit trapを持つextrasが1件でも見つかり共存方法を証明できない場合は、案Dへreplanする。trap導入を強行しない。

## Contract Design

### Capability marker

各 `ta-*.sh` のheaderにexactly one:

```sh
# PG_EXTRA_CAPABILITY: standalone-capable
```

または:

```sh
# PG_EXTRA_CAPABILITY: harness-only
```

markerは説明ではなくinventoryの機械正本。filename listは正本にしない。

### Helper location

```text
tests/extras/_extra-contract.sh
```

`ta-*.sh` globに一致させず、runnerのtest inventoryへ混入させない。

### Helper interface

```sh
pg_extra_contract_init <test-id> <standalone-capable|harness-only>
register_cleanup <path...>          # standalone時のみhelperがfallback提供
pg_extra_contract_is_standalone     # rc 0/1 query
```

想定内部state:

```sh
_PG_EXTRA_ID=
_PG_EXTRA_CAPABILITY=
_PG_EXTRA_STANDALONE=0
_PG_EXTRA_CLEANUP_PATHS=
_PG_EXTRA_ORIGINAL_RC=0
```

### Mode resolution

harness判定:

```sh
[ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]
```

- true: helperはcounter/cleanup/trapを変更しない
- false + harness-only: standardized stderr + exit 2
- false + standalone-capable:
  - 7 envをunset
  - `pass=0`, `fail=0`
  - standalone cleanup registryを用意
  - exit trapを設定

### Helper loading

runnerは extras loop 前に helper を一度sourceする。各 extras は defensive bootstrapを持つ:

```sh
if ! command -v pg_extra_contract_init >/dev/null 2>&1; then
  _pg_extra_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  # shellcheck source=/dev/null
  . "$_pg_extra_dir/_extra-contract.sh"
fi
pg_extra_contract_init "ta-39" "standalone-capable"
```

harness時は既にfunctionがあり `$0`（runner）から誤path解決しない。standalone時だけ自身のdirnameを使う。

### Standalone exit trap

POSIX signal 0 trapをstandalone時だけ設定する。

```sh
trap 'pg_extra_contract_finalize "$?"' 0
```

finalize:

1. trapを解除し再帰を防ぐ
2. registered cleanupをdrain
3. optional contract probeを適用
4. summaryをstderr/stdout方針に従い出力
5. `fail > 0` なら exit 1
6. `fail == 0` なら元rcを保持（元rcが非0なら上書きしない）

precedence:

| original rc | fail | final rc |
|---:|---:|---:|
| 0 | 0 | 0 |
| 0 | >0 | 1 |
| nonzero | 0 | original rc |
| nonzero | >0 | original rc（既存のより具体的なfailureを保持） |

exit 2はharness-only misuse専用で、standalone-capableの内部test failureと区別する。

### Contract probe

全standalone-capable fileがhelper finalizationへ到達しfailを伝播することを動的に検証するため、helperにtest-only fail-safe seamを置く。

```text
PG_EXTRA_CONTRACT_PROBE=force-fail
PG_EXTRA_CONTRACT_TARGET=<test-id>
```

standalone finalize時、ID一致なら `fail=$((fail + 1))` と明示的なprobe messageを出す。通常値では無効。誤って外部から設定されても成功偽装ではなくtest failureになる。

contract testはmarkerから対象を発見し、各standalone-capableを:

```sh
PG_EXTRA_CONTRACT_PROBE=force-fail \
PG_EXTRA_CONTRACT_TARGET="$id" \
sh "$file" </dev/null
```

で実行しrc=1を要求する。

### Harness-only direct execution

helper initがtest bodyより前に:

```text
[ERROR] <id> is harness-only; run: sh tests/run-tests.sh
```

をstderrへ出しexit 2。fixture参照・tmp生成・hook実行より前でなければならない。

## Files / Interfaces

| File | Operation | Purpose |
|---|---|---|
| `tests/extras/_extra-contract.sh` | create | shared mode/finalization/cleanup/probe contract |
| `tests/run-tests.sh` | modify | helperをextras loop前にsource。集計ロジックは不変 |
| `tests/extras/ta-*.sh` | modify | marker + init。standalone対応fileのlegacy footer移行 |
| `tests/extras/ta-XX-extra-contract.sh` | create | inventory/dynamic contract regression test。番号はexec時inventoryで採番 |
| `tests/extras/README.md` | modify | capability/rc/probe/new-file規約 |
| `docs/working/TASK-0914/handoff.md` | modify | V2候補の解消writeback（実装完了時） |

## Work Breakdown

### Task 1: Runtime inventory and conflict audit

**Purpose**: file数を固定せず、移行対象とtrap互換性を確定する。

**Steps**:

- [ ] `find tests/extras -maxdepth 1 -type f -name 'ta-*.sh' -print | sort` をevidence保存
- [ ] 各fileのfallback、counter初期化、top-level exit/return、trap、cleanup、stdin readを機械/目視分類
- [ ] standalone-capable / harness-only candidateを表にする
- [ ] ta-26と#914対象11本を現mainで再確認
- [ ] top-level trap競合があればReplan Trigger発火

**Completion Criteria**:

- [ ] inventory全件にcapability判定と根拠
- [ ] silently unclassified 0
- [ ] countはevidenceで報告するがcode contractに固定しない

### Task 2: Helper RED tests

**Purpose**: helper実装前にrc/cleanup/mode契約を固定する。

**Tests**:

- harness initはexit/trap/counter resetをしない
- harness-only standaloneはbody marker実行前にexit2
- standalone-capable pass=0 → rc0
- fail>0 → rc1
- original rc3 + fail0 → rc3
- original rc3 + fail>0 → rc3
- early exit0 + fail>0 → rc1
- cleanup pathが削除される
- probe target一致→rc1、不一致→通常rc
- invalid capability→fail-closed exit2以上

### Task 3: Implement helper and runner loading

**Purpose**: contract runtimeを最小実装する。

- [ ] `_extra-contract.sh`を実装
- [ ] `sh -n` helper/run-tests
- [ ] runnerのhelper source以外のdiffが0であることを確認
- [ ] synthetic RED testsをGREEN化

**Rollback**: helper追加とrunner source行をrevert。extras migration前なら影響なし。

### Task 4: Migrate harness-only files

**Purpose**: direct misuseをtest body前にexit2。

- [ ] inventoryからharness-only全件へmarker/bootstrap/init
- [ ] 各file standalone `</dev/null` がrc2 + standard message
- [ ] tmp/hook/audit side effect 0を代表 + static ordering checkで確認
- [ ] harness full suiteのbaseline維持

### Task 5: Migrate standalone-capable files

**Purpose**:全終了経路のfail propagation。

- [ ] marker/bootstrap/initを追加
- [ ] legacy standalone counter/cleanup/footerをhelperへ統合
- [ ] file固有root fallbackは保持
- [ ] early exit経路でtrapがfinalizeすることを代表file（ta-39含む）で確認
- [ ] ta-26 migrationは最後に行い、既存heavy testsを前後比較

### Task 6: Add inventory + dynamic regression test

**Purpose**: future file追加時の契約漏れを自動検出。

- [ ]全ta fileがexactly one marker
- [ ] markerとinit capability一致
- [ ] harness-only全件standalone rc2
- [ ] standalone-capable全件probe rc1
- [ ] normal standalone-capable全件rc0（prerequisite SKIPは0可、unexpected `[FAIL]`不可）
- [ ] harness full suite完走、後続test markerが出ることを確認
- [ ] contract test自身の再帰をmarker/IDで回避

### Task 7: Documentation and #914 closure writeback

- [ ] READMEへrc 0/1/2意味、capability選択、新規file checklist
- [ ] standalone-only exit trapはharness trap禁止規約の例外であることを説明
- [ ] TASK-0914 handoffの代理判定V2をexit code contractへ更新
- [ ] #921 AC実績、inventory件数、evidenceをwriteback

## Verification Plan

| Type | Command / Method | Expected | Evidence |
|---|---|---|---|
| Syntax | `sh -n tests/extras/_extra-contract.sh tests/run-tests.sh tests/extras/ta-*.sh` | exit0 | `evidence/verification/syntax.log` |
| Inventory | new contract TA | unclassified=0, marker mismatch=0 | `evidence/test-runs/contract-inventory.log` |
| Harness-only | loop direct execution `</dev/null` | all rc2 + message | `evidence/test-runs/harness-only.log` |
| Standalone forced fail | probe loop | all rc1 | `evidence/test-runs/standalone-force-fail.log` |
| Standalone normal | loop | rc0 and `[FAIL]` 0 | `evidence/test-runs/standalone-normal.log` |
| Harness regression | `sh tests/run-tests.sh` | baseline remeasured at exec start, 0 failed | `evidence/test-runs/full-suite.log` |
| Early-exit mutation | synthetic + ta-39 prerequisite path | fail count cannot exit0 | `evidence/test-runs/early-exit.log` |
| Helper mutation | remove trap/fail branch/target check in temp copy | contract tests FAIL | `evidence/mutations/` |

## Review Lanes

| Deliverable | Lane |
|---|---|
| helper/trap design | POSIX shell/control-flow reviewer |
| inventory/probe test | test architecture/mutation reviewer |
| source/harness safety | PlanGate workflow/Human boundary reviewer |
| broad file migration | maintainability/diff-risk reviewer |

## Plan Review Readiness

### Success Criteria

- AC-1: TC-01/02/03/04/09/10
- AC-2: TC-05/06
- AC-3: TC-07/08/11
- AC-4: TC-09/10
- AC-5: TC-12
- AC-6: TC-13

### Completion Boundary

全extrasが明示capabilityを持ち、direct executionのrc契約とharness regressionが機械検証され、#914の代理判定をexit codeへ戻せるところまで。個別test内容、framework刷新、README一覧修正は含まない。

### Security / Operational Risk

- harness source中のexitは全suiteを短絡するためcritical
- broad file migrationでmerge conflictが高い。exec開始時に他branchがtests/extrasを変更していたら停止
- trap競合、cleanup誤削除、stdin hangを負側で検証
- probeはfail-safeでありsuccess bypassを持たない

## Replan Triggers

- top-level trapを持つextrasがあり共有trapとの合成を証明できない
- helper sourceのためrunner集計契約変更が必要
- standalone-capableの正常実行が外部service/credentialを要求する
- capability分類が2値で表現できない第三カテゴリを必要とする
- migration対象fileがplan時inventoryから増減し、未分類が生じる
- full suite baselineがmainで既に赤
- ta-26 cleanup behaviorをhelperで等価にできない

## Stop Condition

- Human C-3前
- destructive cleanup pathが発見された
- source経路でexit/trapが発火した
- normal standalone probeがhangする
-新規dependency/bash化が必要
-50件規模のmigrationをreview可能なcommitへ分割できない

## Human Approval Boundary

- shared trap案Cの採否
- `tests/run-tests.sh` helper source変更
- broad extras migrationのC-3
- contract probe envの採否
- PR C-4 / merge

## C-1 Self Review Checklist

- [x] #914完了を反映
- [x] countをハードコードしない
- [x] layer A/Bをrc 1/2で区別
- [x] early exit問題を設計で扱う
- [x] source経路exit禁止を明示
- [x] negative controls / mutation evidenceを定義
- [x] broad migrationのrollback/replanを定義
- [ ] runtime inventoryをexec開始時に取得
- [ ] trap conflict audit
- [ ] C-2 independent review
- [ ] Human C-3
