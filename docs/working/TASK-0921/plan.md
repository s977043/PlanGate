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

> **C-2 反映済み**（`Refs: R-001`〜`R-020`）。指摘の正本は
> [`review-external.md`](./review-external.md)。本文書は 1 回だけの確定反映後の版であり、
> 以降の変更は `plan_hash` を無効化するため C-3 承認前に確定させる。

## Goal

`tests/extras/ta-*.sh` の直接実行を、standalone 対応テストでは内部失敗を exit 1 へ確実に伝播し、harness 専用テストでは誤動作する前に exit 2 で拒否し、前提未充足で検査できていない場合は exit 3 で「検査していない」を表明する明示的契約へ移行する。

## Context

- Issue: [#921](https://github.com/s977043/PlanGate/issues/921)
- Input: [`pbi-input.md`](./pbi-input.md)
- Dependency #914: 2026-08-04 に close。11 extras の harness 判別 AND 化と外部 env 無害化は完了
- **既存 standalone 伝播の起点集合（層 0）= 4 本**（`ta-26` / `ta-58` / `ta-59` / `ta-60`）。
  従来 plan は「`ta-26` のみ」と扱っていたが、`pass=0` / `fail=0` を自前初期化しているのは
  この 4 本である（R-003）。書式は 2 系統:
  - `ta-26`: `[ "$fail" != "0" ]` 形
  - `ta-59` / `ta-60`: `[ "$fail" -eq 0 ] || exit 1` 形
  - この 2 系統をどちらも helper へ吸収する（Task 5）
- **移行対象（層 A）は 12 本**で、`ta-40` を含む（R-003）
- Harness: `tests/run-tests.sh` は `PG_HARNESS_SOURCED=1` を非 export で設定し、各 extras を source。集計後に `fail > 0` なら exit 1
- Current failure: standalone では内部 `[FAIL]` があっても exit 0。harness 専用 file は未定義 fixture 前提のまま走って exit 0 になりうる
- Current inventory count is mutable. pbi-input 作成時は 53、本 backlog 監査時は 57 との実測があるため、**件数を仕様へ固定しない**

## Scope

### In Scope

- 全 `tests/extras/ta-*.sh` の runtime inventory と capability classification
- `standalone-capable` / `harness-only` の機械可読 marker
- 共通 standalone contract helper
- standalone-capable: counter初期化、外部env隔離、cleanup、summary、`fail > 0 → exit 1`
- **前提未充足（prerequisite absent）時の `exit 3`**（＝検査していないことの表明。`rc=0` は不可）
- harness-only: direct invocation を標準message + exit 2で即時拒否
- **D-2 = (c) 採用**: 層 C（fallback 非保持の 5 本）は独立クラスを立てず、
  fallback 非保持クラスとして **harness-only に含め fail-fast（exit 2）で空振り PASS を塞ぐ**（R-007）
- harness source 経路で個別 extras が process exit しないこと
- 新規 extras が契約未宣言・未実装なら failする回帰テスト
- 全 standalone-capable の failure propagation を実行ベースで検査する test seam
- README規約、#914 handoffのV2候補writeback（append-only）

### Out of Scope

- 各 extras のテスト内容・期待値の見直し
- `tests/run-tests.sh` の集計アルゴリズム変更
- harness/standalone 判別シグナルの再設計
- harness-only extras の完全 standalone 対応
- README の現行テスト一覧ドリフト修正
- shell test framework 導入
- **CI 実行時間の予算最適化そのもの**（本 PBI は増加分を見積り、重量ファイルの
  取り扱いを裁定するところまで。スイート全体の高速化は別 PBI）（R-017）

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
- **summary 書式の維持（R-015a）**: helper が出力する standalone summary は
  `TA-<NN> standalone: N passed, M failed` 書式を維持する。
  `ta-26` の TC-13 が子プロセス出力を**この文字列で literal grep** して判定しているため、
  書式変更は rc ではなく grep 側を壊す
- **helper は `set -eu` 下で source-safe（R-019a）**: `tests/run-tests.sh` は `set -eu` で動く。
  helper は source 時に非 0 を返さず、`set -u` 下で未定義変数を参照しない
- **helper は `register_cleanup` を無条件再定義しない（R-019b）**: harness の単一 drain 契約
  （`_pg_drain_cleanup` による一括削除）を壊すため、harness mode では既存定義を維持し、
  standalone mode でのみ未定義時の fallback として定義する
- **`tests/extras/README.md` 規約 1–2 との整合を維持**: 「trap に頼らず末尾で明示 cleanup」
  「親シェルの trap を `trap - EXIT` で消さない」。**本 PBI は案 D（末尾 explicit finalize）を
  採るため、規約 1–2 に例外を作らない**

## 前提の実測検証

| 前提 | 検証 | 実測 | 判定 |
|---|---|---|---|
| #914 完了 | Issue state | closed/completed 2026-08-04 | ✅ |
| harness は source + global counters | `tests/run-tests.sh` | `pass=0`, `fail=0`, `PG_HARNESS_SOURCED=1`, `. "$extra"` | ✅ |
| standalone exit伝播の前例 | 層 0 の 4 本 | `ta-26` / `ta-58` / `ta-59` / `ta-60` が `pass=0` / `fail=0` を自前初期化（R-003） | ✅ |
| layer A file に early exit がありうる | ta-39 | prerequisite未適用時にreturn/exit 0 | ✅ |
| current file countは変動する | pbi-inputと最新監査 | 53→57 | ✅。runtime inventory必須 |
| **top-level `exit N`（列 0-2）の現存件数** | 全 `ta-*.sh` の grep（C-2 実測） | **0 件** | ✅。**案 C（共有 trap）が守ろうとしていた早期 exit ケースは現存しない**（R-018） |
| **`ta-39` の早期 SKIP は failure を落としうるか** | `tests/extras/ta-39-eh3-doc-light.sh` の SKIP 分岐 | 「カウンタは更新しない」と明記。早期 exit 時点で `fail` は構造上必ず 0 | ✅。**早期 exit で fail を握り潰す実例は存在しない**（R-018） |
| top-level `trap ... EXIT` を持つ extras | 全 `ta-*.sh` の grep（C-2 実測） | 5 本（`ta-07` / `ta-09` / `ta-24` / `ta-28` / `ta-45`）。standalone-capable 候補は `ta-45` のみ | ✅。**案 D では trap を張らないため競合しない**（R-012） |
| test-id の一意性 | `ta-*.sh` の番号 | **`ta-14` が 2 本**（`ta-14-codex-guarded.sh` / `ta-14-skip-acknowledge.sh`）→ 番号は一意でない | ❌。**test-id は basename ベースにする**（R-016） |
| `_extra-contract.sh` の glob 混入 | `tests/run-tests.sh` の extras loop（`ta-*.sh` glob） | `_extra-contract.sh` は `ta-*.sh` に一致しない → inventory へ混入しない | ✅（R-014 の反証材料） |
| フルスイート baseline | `sh tests/run-tests.sh`（C-2 実測 / sandbox clone） | rc=0 / **231s** / 541 passed, 0 failed | ✅。CI 時間見積の基準（R-017） |

## Questions / Unknowns

### 未解決（exec 開始時に確定する）

- 現 main における正確な `ta-*.sh` inventory と capability分類。exec開始時に構造/実走で確定する
- standalone-capable files が層 0 の 4 本 + 層 A の 12 本以外に増えているか（R-003）
- helperを `run-tests.sh` から一度sourceする変更が本当に必要か。
  各 extras の defensive bootstrap 単独で代替できるなら runner 変更を落とす（R-010 / Task 3）

### 解決済み（C-2 裁定により確定）

| 旧 Unknown | 裁定 | 根拠 |
|---|---|---|
| top-level `trap 0` を独自利用する extras が存在するか | **不要になった**。案 D（末尾 explicit finalize）採用で trap を張らない | R-012 / R-018 / Human 決定 1 |
| contract probe env を `run-tests.sh` 冒頭で unset すべきか | **不要（internal-only 採用）**。helper 側で「harness mode なら probe 変数を読まない」と実装する。`run-tests.sh` の unset 列は触らない | C-2 委譲裁定 ① |
| probe の TARGET 未設定時の挙動 | **fail-closed**。no-op にせず診断メッセージ + 非ゼロ終了 | C-2 委譲裁定 ② |
| probe を README に公開するか | **公開する（test section 限定）**。秘匿の安全上の利得がなく、隠れた load-bearing seam は腐る | C-2 委譲裁定 ③ |

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | ta-26のheader/footerを各standalone-capableへ複製、harness-onlyへinline guard | 新helperなし、局所的 | early exitごとにfinalizer呼出が必要、将来drift、重複が多い | 不採用 |
| B | 全extrasをsubprocess実行するようrunnerを再設計 | process isolation、exit契約が自然 | harness global counters/fixtures/cleanup契約を全面変更、scope過大 | 不採用 |
| C | 共通helper + capability marker。standalone-capableのみstandalone時の終了trap、harness-onlyはhelperがexit2 | 終了経路を漏らさず一元化 | **`ta-45` が `trap - EXIT` で finalizer を無条件に消す**（合成実証: 制御群 rc=1 / ta-45 パターン rc=0）。README 規約 1–2 の例外導入が必要 | **不採用（replan）** |
| D | 共通helper + 各file末尾explicit finalize | trapを張らないため既存 trap と競合しない。README 規約 1–2 に例外を作らない | early return/exit漏れを静的に完全検出しにくい | **採用** |

### Recommended Approach

**案 D（末尾 explicit finalize）を採用する**（Human 決定 1 / 2026-08-05）。

案 C から replan した根拠は 2 つの実測である:

1. **競合が実在する**（R-012）: `ta-45` は `trap cleanup_t45 EXIT` を張ったうえで末尾で
   `trap - EXIT` を実行する。合成実証で **制御群 rc=1 / ta-45 パターン rc=0**（finalizer 未発火・
   `fail=1` が握り潰される）を確認した。案 C は standalone-capable 候補の中で唯一
   top-level trap を持つファイルに対して成立しない。
2. **案 C が守ろうとしていたケースが現存しない**（R-018）: 案 C の第一根拠は
   「`ta-39` のような早期 `exit 0` で fail を落とす経路」だったが、
   `ta-39` の SKIP 分岐は「カウンタは更新しない」と明記されており早期 exit 時点で
   `fail` は構造上必ず 0。加えて全 `ta-*.sh` の **top-level `exit N`（列 0-2）は 0 件**。
   すなわち **trap でしか救えない現存事例は 1 件も存在しない**。

案 D の弱点（早期 return/exit 漏れを静的に完全検出できない）は、**contract TA の
動的 probe（全 standalone-capable を force-fail probe 付きで実走し rc=1 を要求）**で
実行ベースに補う。将来ファイルが top-level `exit` を導入した場合は contract TA が
probe rc≠1 として検出する。

> **案 C を捨てたことによる差分**: trap 競合の Replan Trigger / Questions / Task 1 の
> trap 競合監査、および `ta-45` の個別対応は不要になった。
> ただし README 規約 1–2 との整合維持は案 D でも継続する（trap を張らない＝規約準拠）。

### 先行決定の反転: `_extra-contract.sh` 共有ファイルの導入（R-014）

本 PBI は `tests/extras/_extra-contract.sh` という**共有ファイル**を導入する。これは
[`TASK-0914/handoff.md`](../TASK-0914/handoff.md) §4「妥協点」で **Human C-3 承認付きで棄却された
論点 E-1（共有 preamble ファイル `_standalone-preamble.sh`）の意図的な反転**である。

**#914 の棄却理由（引用）**:

> ta-26 既存実装と同型（既存パターン準拠）。共有ファイルは `ta-*.sh` glob 外の新規ファイルで
> extras 自己完結の慣習を崩す。重複 drift は AC-9（`run-tests.sh` 集合 ⊆ 各 extras 集合）で機械検出

**反転の根拠（Human 決定 2 / 2026-08-05）**:

1. **exit 契約は inline 複製では保証できない**。#914 が扱った 7 env unset は「値の集合が
   一致しているか」という**静的に検査可能な性質**であり、inline 複製 + 静的検査（AC-9）で
   drift を検出できた。本 PBI が扱うのは**終了経路そのもの**であり、各ファイルが独自の
   終了処理を持つ限り「契約違反が静的検査でしか検出できず、実行時には保証されない」。
   終了経路を一元化して初めて実行時保証が成立する。
2. **glob 非混入は実測で確認済み**（対置）。`tests/run-tests.sh` の extras loop は
   `"$EXTRAS_DIR"/ta-*.sh` glob で走査する。`_extra-contract.sh` はこの glob に一致せず、
   runner の test inventory には混入しない。#914 の棄却理由が挙げた「`ta-*.sh` glob 外の
   新規ファイル」という事実は正しいが、**それ自体が実害を生まないことは実測で確認できる**。
   残る論点は「extras 自己完結の慣習」という規範であり、上記 1 の実行時保証と天秤にかけて
   本 PBI では**慣習側を意図的な例外として崩す**。
3. 例外であることを **README 規約に明記**し、将来の新規 extras が「共有ファイルを置いてよい」と
   一般化しないよう境界を書く（共有してよいのは exit 契約 helper のみ）。

本反転は Human Approval Boundary の項目として C-3 で明示承認を要する。

## Mode判定

**モード**: `high-risk`（Slice 1）

### スライス分割の裁定（D-5 確定 / Human 決定 3）

pbi-input の **D-5（スライス分割・未裁定）を以下で確定する**。

| Slice | 対象 | ファイル数 | Mode |
|---|---|---:|---|
| **Slice 1**（本 plan の直接対象） | 層 A 12 本 + helper `_extra-contract.sh` + 検査基盤（contract TA）+ `tests/extras/README.md` | **15** | **high-risk** |
| **Slice 2**（本 PBI スコープ内・後続） | 層 B 36 本 + 層 C 5 本（＝ harness-only 化 41 本）+ `docs/working/TASK-0914/handoff.md` writeback | **42** | **着手時に再判定**（定量 16+ のため critical 帯の見込み） |

- **Slice 2 は本 PBI のスコープに含めたまま「後続スライス」として扱う**。別 PBI へ切り出すか
  否かは **Slice 1 完了時に判断**し、本時点では決めない。
- `tests/run-tests.sh` への helper source は R-010 の比較検証（Task 3）で要否を確定する。
  必要と判断された場合 Slice 1 は 16 ファイルとなるが、その時点で Mode を再判定する
  （定量 16+ = critical 帯に触れるため、安全側で人間へエスカレーションする）。

### 判定根拠（定量）

| 判定軸 | Slice 1 実測 / 見込み | モード |
|---|---|---|
| 変更ファイル数 | **15**（層 A 12 + helper 1 + contract TA 1 + README 1） | **high-risk**（6-15） |
| 受入基準数 | **8**（AC-1〜AC-8。AC-8 は R-013 由来で本反映により追加） | **high-risk**（6-10 の上限） |
| タスク数（見込み） | **12-18**（T-01〜T-08 + 層 A の batch 分割 + contract TA の TC 追加分） | **high-risk**（11-20） |

### 判定根拠（定性）

| 判定軸 | Slice 1 の評価 | モード |
|---|---|---|
| 変更種別 | 機能追加/リファクタ（既存 12 本の終了経路を helper へ移す）+ **新規設計（rc 意味レイヤー 0/1/2/3 の導入）** | **high-risk** |
| リスク | **高**。source 経路に `exit` が漏れると `run-tests.sh` が途中終了し、以降の extras が実行されないまま少ない件数で 0 failed を返す（CI が静かに緑になる） | **high-risk** |
| 影響範囲 | `tests/` に閉じるが、helper が全 extras の実行制御を握るため**複数ファイルに波及** | **high-risk** |
| ロールバック | **計画的に必要**。batch commit の revert に依存順（helper 導入 commit の revert が前提）がある | **high-risk** |

### 最終判定

- 定量の最大 = **high-risk**（変更ファイル数 15 は 6-15 帯の上限、16+ の critical 帯に入らない）
- 定性の最大 = **high-risk**
- 「定量と定性の高い方を採用」→ **high-risk**

**critical へ引き上げない根拠**:

1. 変更ファイル数 15 は `mode-classification.md` 定量基準の high-risk 帯（6-15）に収まる
2. 影響範囲は `tests/` に閉じ、プロダクトコード・hooks・CI 定義には波及しない
3. **Hardening Override 対象パス（`check-plan-hash.sh` の 9 カテゴリ）に 1 件も該当しない**
   （C-2 実測で確認済み）。`tests/run-tests.sh` は `scripts/hooks/*.sh` にも `bin/plangate` にも
   一致せず HO 非該当
4. アーキテクチャ変更・横断的リファクタリング・公開 API の破壊的変更のいずれにも当たらない

**Slice 2 の扱い**: 42 ファイルは定量 16+ = **critical 帯**に入る。Slice 2 着手時に
本節と同じ形式で Mode を再判定し、critical となる場合は詳細 plan + 複数観点 C-2 +
詳細 C-3 + V-4 を適用する。**Slice 1 の high-risk 判定を Slice 2 へ流用しない**。

## Contract Design

### test-id（R-016）

test-id は **番号ではなく basename（拡張子なし）** で定義する。

```text
ta-14-codex-guarded      ← test-id
ta-14-skip-acknowledge   ← test-id（番号 14 は重複するが basename は一意）
```

理由: `ta-14` が 2 本存在するため（実測）、番号は一意でない。`PG_EXTRA_CONTRACT_TARGET`、
診断メッセージ `[ERROR] <id> is harness-only`、contract TA の「for every file」ループは
すべて basename ベースにする。

**contract TA は「全 `ta-*.sh` の test-id が一意であること」を検査項目に含める**（TC-20）。
現状 basename は一意だが、将来同名ファイルが別ディレクトリ構成で入る可能性に備える。

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

`ta-*.sh` globに一致させず、runnerのtest inventoryへ混入させない（実測確認済み）。
本ファイルの導入は #914 §4 で棄却された E-1 の意図的反転である（前掲）。

### Helper interface

```sh
pg_extra_contract_init <test-id> <standalone-capable|harness-only>
pg_extra_contract_finalize          # 各 file 末尾で明示呼出（案 D）
pg_extra_contract_skip <reason>     # 前提未充足の表明（rc 3 経路）
register_cleanup <path...>          # standalone時のみhelperがfallback提供（無条件再定義しない）
pg_extra_contract_is_standalone     # rc 0/1 query
```

想定内部state:

```sh
_PG_EXTRA_ID=
_PG_EXTRA_CAPABILITY=
_PG_EXTRA_STANDALONE=0
_PG_EXTRA_CLEANUP_PATHS=
_PG_EXTRA_ORIGINAL_RC=0
_PG_EXTRA_PREREQ_MISSING=0
```

### Mode resolution

harness判定:

```sh
[ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]
```

- true: helperはcounter/cleanup/trapを変更しない。**probe 変数も読まない**（internal-only / 裁定 ①）
- false + harness-only: standardized stderr + exit 2
- false + standalone-capable:
  - 7 envをunset
  - `pass=0`, `fail=0`
  - standalone cleanup registryを用意（`register_cleanup` は未定義時のみ定義）
  - **trap は張らない**（案 D）。終了は各 file 末尾の `pg_extra_contract_finalize` に集約

### rc 意味レイヤー（R-002）

| rc | 意味 |
|---:|---|
| **0** | standalone-capable が全件 pass した（検査した結果、問題なし） |
| **1** | standalone-capable の内部テストが失敗した（検査した結果、失敗あり） |
| **2** | 実行方法エラー（harness-only を direct invocation した / capability 未宣言・不正） |
| **3** | **前提未充足＝検査していない**（prerequisite absent。SKIP 状態で `rc=0` を返してはならない） |

**`exit 3` が本 PBI 最優先の実害経路を塞ぐ唯一の変更である**。
`scripts/apply-eh3-doc-light.sh` が案内する `sh tests/extras/ta-39-eh3-doc-light.sh` は、
適用失敗時こそ早期 SKIP で `rc=0` を返し続ける。従来 plan の
「prerequisite SKIP は 0 可」は **誤り**であり本反映で是正した。
対象は `ta-39` / `ta-43` / `ta-44`（早期 SKIP 経路を持つ 3 本）。

### Finalize precedence

`pg_extra_contract_finalize` は各 file 末尾で明示呼出される（案 D）。

1. registered cleanupをdrain
2. optional contract probeを適用（harness mode では読まない）
3. **probe env を unset して子プロセスへ伝播させない**（再帰ガード / R-015b）
4. summaryを `TA-<NN> standalone: N passed, M failed` 書式で出力（R-015a）
5. rc を precedence に従って決定

precedence:

| prerequisite | original rc | fail | final rc | 備考 |
|---|---:|---:|---:|---|
| missing | any | any | **3** | 前提未充足が最優先。検査していないので pass/fail を主張しない |
| present | 0 | 0 | 0 | |
| present | 0 | >0 | 1 | |
| present | nonzero | 0 | original rc | |
| present | nonzero | >0 | original rc | 既存のより具体的なfailureを保持 |

exit 2はharness-only misuse専用であり、standalone-capableの内部test failure（1）とも
prerequisite未充足（3）とも区別する。

### Contract probe

全standalone-capable fileがhelper finalizationへ到達しfailを伝播することを動的に検証するため、helperにtest-only fail-safe seamを置く。

```text
PG_EXTRA_CONTRACT_PROBE=force-fail
PG_EXTRA_CONTRACT_TARGET=<test-id>   # basename ベース
```

裁定に基づく仕様:

- **internal-only（裁定 ①）**: **harness mode では probe 変数を一切読まない**。
  `tests/run-tests.sh` の unset 列は変更しない。汚染 shell から `sh tests/run-tests.sh` を
  叩いても suite は影響を受けない
- **fail-closed（裁定 ②）**: `PG_EXTRA_CONTRACT_PROBE` が設定されているのに
  `PG_EXTRA_CONTRACT_TARGET` が未設定なら **no-op にせず診断メッセージ + 非ゼロ終了**。
  no-op にすると contract TA が TARGET を渡し損ねたとき「全ファイル rc=0 → probe が
  効いていないのに TC-12 が PASS」という検査器自身の空振りが起きる（本 PBI が潰そうと
  している症状と同型）
- **再帰ガード（R-015b）**: finalize 時に probe env を unset し、子プロセスへ継承させない。
  `ta-26` の TC-13 は `PG_T26_NO_RECURSE=1` で自己再帰するため、ガードがないと
  TARGET=ta-26 の probe が子でも発火し親の判定を汚す（rc は 1 のままなので
  **誤った理由で TC-12 が PASS する masking**）
- standalone finalize時、ID一致なら `fail=$((fail + 1))` と明示的なprobe messageを出す。
  probe 由来の失敗は通常の `[FAIL]` と区別可能なメッセージにする

contract testはmarkerから対象を発見し、各standalone-capableを:

```sh
PG_EXTRA_CONTRACT_PROBE=force-fail \
PG_EXTRA_CONTRACT_TARGET="$id" \
sh "$file" </dev/null
```

で実行し **rc=1** を要求する。加えて **probe なしの実行で rc=0 になること**も取り、
両者の差分を要求する（裁定 ②。(b) 単独では「元から常に rc=1」なファイルを検出できない）。

### Harness-only direct execution

helper initがtest bodyより前に:

```text
[ERROR] <id> is harness-only; run: sh tests/run-tests.sh
```

をstderrへ出しexit 2。fixture参照・tmp生成・hook実行より前でなければならない。

### `ta-26` TC-33 の扱い（R-013）

`ta-26` の TC-33 は「`FIXTURES_DIR:-` を含む各 `ta-*.sh`」に対し
(1) `PG_HARNESS_SOURCED` の存在 (2) **そのファイル自身の inline `unset` 行**が
`run-tests.sh` の 7 env 集合を包含、を静的検査している（#914 AC-9 のゲート）。

Task 5 で 7 env unset を helper へ移すと、TC-33 は次のどちらかになる:

- inline unset 残存 → **TC-33 FAIL（フルスイート赤）**
- `FIXTURES_DIR:-` ごと除去 → ループが `continue` して **TC-33 が全件空振り**
  （#914 AC-9 のゲートが無言で消失）

**空振り化を許容しない**。本 PBI は **TC-33 の検査対象を helper 側へ差し替える**:

- 検査対象を「各 `ta-*.sh` の inline unset」から
  「`_extra-contract.sh` の standalone 分岐の unset 集合が `run-tests.sh` の 7 env を包含する」
  および「各 `ta-*.sh` が helper bootstrap + init を持つ」へ移す
- **移行後も空振りせず同等以上の検出力を保つこと**を **AC-8** として立てる
- **変異注入で FAIL することを実証する**（Verification Plan の Mutation 行）

## Files / Interfaces

| File | Operation | Purpose |
|---|---|---|
| `tests/extras/_extra-contract.sh` | create | shared mode/finalization/cleanup/probe contract（#914 E-1 の意図的反転） |
| `tests/run-tests.sh` | **modify（要否は Task 3 で確定 / R-010）** | helperをextras loop前にsource。集計ロジックは不変。bootstrap 単独で代替可能なら本行を落とす |
| `tests/extras/ta-*.sh` | modify | marker + init + 末尾 finalize。standalone対応fileのlegacy footer移行 |
| `tests/extras/ta-XX-extra-contract.sh` | create | inventory/dynamic contract regression test。番号はexec時inventoryで採番 |
| `tests/extras/README.md` | modify | capability/rc 0-3/probe/new-file規約 + 共有ファイル例外の境界 |
| `docs/working/TASK-0914/handoff.md` | **modify（append-only / Slice 2）** | V2候補のクローズ writeback（下記規約に従う） |

### `TASK-0914/handoff.md` writeback 規約（R-008）

- **append-only**。§3「V2 候補」表の該当行の status を
  `CLOSED（#921 / PR #NNN, YYYY-MM-DD）` へ更新し、**行自体は削除しない**
- 参照は **記号アンカー**（§見出し + 行テキスト）で指定し、**行番号を書かない**
- 対象行は **2 行**:
  1. §3「V2 候補」表の `**#921 完了時に AC-6 の判定を exit code ベースへ戻す**` 行
  2. §3「V2 候補」表の `standalone preamble の共通化（7 env unset のインライン 12 ファイル重複の解消）` 行
     — 本 PBI の helper 集約で実質解消されるため writeback 対象に含める

## Work Breakdown

### Task 1: Runtime inventory and capability audit

**Purpose**: file数を固定せず、移行対象とtest-idを確定する。

**Steps**:

- [ ] `find tests/extras -maxdepth 1 -type f -name 'ta-*.sh' -print | sort` をevidence保存
- [ ] 各fileのfallback、counter初期化、top-level exit/return、cleanup、stdin readを機械/目視分類
- [ ] standalone-capable / harness-only candidateを表にする
- [ ] **層 0 の 4 本（`ta-26` / `ta-58` / `ta-59` / `ta-60`）と層 A の 12 本（`ta-40` 含む）を現mainで再確認**（R-003）
- [ ] **basename ベースの test-id 一覧を作り重複がないことを確認**（R-016）

> **注（案 D 採用により削除）**: 旧 Task 1 の「top-level trap 競合監査」は不要になった。
> 案 D は trap を張らないため既存 trap と競合しない。

**Completion Criteria**:

- [ ] inventory全件にcapability判定と根拠
- [ ] silently unclassified 0
- [ ] test-id（basename）重複 0
- [ ] countはevidenceで報告するがcode contractに固定しない

**rollback**: 不要（読取・分類のみ。ファイルを変更しない）

### Task 2: Helper RED tests

**Purpose**: helper実装前にrc/cleanup/mode契約を固定する。

**Tests**:

- harness initはexit/counter resetをしない
- **harness mode では probe 変数を読まない**（裁定 ①）
- harness-only standaloneはbody marker実行前にexit2
- standalone-capable pass=0 → rc0
- fail>0 → rc1
- **prerequisite missing → rc3**（R-002）
- original rc3 + fail0 → rc3
- original rc3 + fail>0 → rc3
- 末尾 finalize 未呼出の file は contract TA が検出する（案 D の弱点補償）
- cleanup pathが削除される
- **`register_cleanup` が harness mode で上書きされない**（R-019b）
- probe target一致→rc1、不一致→通常rc、**TARGET 未設定→fail-closed 非ゼロ**（裁定 ②）
- **probe env が子プロセスへ伝播しない**（R-015b）
- invalid capability→fail-closed exit2以上

**rollback**: 未 push なら `git reset --hard`。push 済みなら該当 commit を `git revert <sha>`。
テストのみの追加であり実装への依存はない。

### Task 3: Implement helper and runner loading

**Purpose**: contract runtimeを最小実装する。

- [ ] `_extra-contract.sh`を実装（`set -eu` 下で source-safe / `register_cleanup` 無条件再定義なし）
- [ ] `sh -n` helper/run-tests
- [ ] **R-010 比較検証**: 各 extras の defensive bootstrap 単独で全経路の helper 解決が
      成立するかを実測する。成立するなら `tests/run-tests.sh` の変更を**落とし**、
      Files 表と Human Approval Boundary から除去する。落とせない場合は
      **「なぜ bootstrap だけでは不足か」を根拠付きで記載**する
- [ ] runner を残す場合、helper source以外のdiffが0であることを確認
- [ ] synthetic RED testsをGREEN化

**rollback**: helper 追加 commit と（残す場合の）runner source 行 commit を
`git revert <sha>`。未 push なら `git reset --hard`。extras migration 前なので影響なし。
**T-04 / T-05 を revert する場合は本 Task の revert が最後になる**（依存順）。

### Task 4: Migrate harness-only files（Slice 2）

**Purpose**: direct misuseをtest body前にexit2。層 C は D-2 (c) により本 Task に含める。

- [ ] inventoryからharness-only全件（層 B 36 + 層 C 5 = 41）へmarker/bootstrap/init
- [ ] 各file standalone `</dev/null` がrc2 + standard message
- [ ] tmp/hook/audit side effect 0を代表 + static ordering checkで確認
- [ ] harness full suiteのbaseline維持

**rollback**: batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
**helper 導入前まで戻す場合は Task 3 の revert が前提**（helper 未導入で marker/init だけ
残ると全 harness-only ファイルが起動時に落ちる）。revert 順序は T-04 → T-03。

### Task 5: Migrate standalone-capable files（Slice 1 中核）

**Purpose**: 全終了経路のfail propagation。

- [ ] marker/bootstrap/init + **末尾 explicit finalize** を追加（案 D）
- [ ] file固有root fallbackは保持
- [ ] **legacy standalone counter/cleanup/footer の 2 系統を helper へ吸収**（R-003）:
      `ta-26` の `[ "$fail" != "0" ]` 形と `ta-59` / `ta-60` の `[ "$fail" -eq 0 ] || exit 1` 形
- [ ] **`ta-39` / `ta-43` / `ta-44` の prerequisite 経路を `pg_extra_contract_skip` 経由の rc=3 へ移す**（R-002）
- [ ] **`ta-26` TC-33 の検査対象を helper 側へ差し替える**（R-013 / AC-8）。空振り化させない
- [ ] **summary 書式 `TA-<NN> standalone: N passed, M failed` を維持**（R-015a / `ta-26` TC-13 の grep）
- [ ] ta-26 migrationは最後に行い、既存heavy testsを前後比較

**rollback**: batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
**helper 導入前まで戻す場合は Task 3 の revert が前提**。`ta-26` は最後の batch なので
単独 revert が可能。revert 順序は T-05 → T-03。

### Task 6: Add inventory + dynamic regression test

**Purpose**: future file追加時の契約漏れを自動検出。

- [ ] 全ta fileがexactly one marker
- [ ] markerとinit capability一致（**basename ベースの test-id** / R-016）
- [ ] **全 `ta-*.sh` の test-id が一意**（R-016 / TC-20）
- [ ] harness-only全件standalone rc2
- [ ] standalone-capable全件 **probe なし rc0 / probe あり rc1 の両方**（裁定 ②）
- [ ] normal standalone-capable: **prerequisite 充足時 rc0、prerequisite 未充足時 rc3**
      （unexpected `[FAIL]` 不可）（R-002）
- [ ] harness full suite完走。**`ls tests/extras/ta-*.sh | tail -1` で runtime に決定した
      最終ファイルの `[PASS]` が harness ログに現れることを assert**（**ファイル名を
      ハードコードしない** / R-006）
- [ ] **README が rc 0/1/2/3 の意味と capability marker 規約を含むことを grep 検査**（R-009 / TC-19）
- [ ] contract test自身の再帰をmarker/IDで回避

**rollback**: contract TA ファイルの追加 commit を `git revert <sha>`。
検査基盤のみなので単独 revert 可（ただし revert すると回帰検出力を失う）。

### Task 7: Documentation and #914 closure writeback

- [ ] READMEへ **rc 0/1/2/3** の意味、capability選択、新規file checklist
- [ ] **README 規約に「extras rc の 2 は harness-only 誤実行専用であり、hook の BLOCK
      （`exit 2`）とは別名前空間」と明記**（R-020）
- [ ] **README に probe を test section 限定で明記**（裁定 ③）。必須記載 5 項目:
  1. test-only であること
  2. 失敗を増やすことしかできず抑止しないこと
  3. CI 設定・開発シェル・`.env` に設定してはならないこと
  4. harness mode では無視されること
  5. probe 由来の失敗は通常の `[FAIL]` と区別可能なメッセージで出力されること
- [ ] **共有ファイル `_extra-contract.sh` は exit 契約 helper に限った例外**であり、
      一般に共有ファイルを増やしてよいわけではないことを規約として明記
- [ ] 案 D（末尾 explicit finalize）であること、**trap を張らないため README 規約 1–2 に
      例外を作らない**ことを明記
- [ ] **`TASK-0914/handoff.md` §3 の 2 行を append-only で CLOSED マーク**（R-008 / Slice 2）

**rollback**: docs commit を `git revert <sha>`。実装への依存なし（単独 revert 可）。

### Task 8: Final verification

- [ ] `sh -n` 全件
- [ ] full suite 3 runs
- [ ] dirty environment run
- [ ] interrupted standalone cleanup check
- [ ] **pre-fix HEAD（helper 導入前）で contract TA を実行し FAIL する evidence**（R-011 / AC-7）
- [ ] C-2 shell/test/workflow lanes
- [ ] PR scope audit

**rollback**: 不要（検証・読取のみ）

## Verification Plan

| Type | Command / Method | Expected | Evidence |
|---|---|---|---|
| Syntax | `sh -n tests/extras/_extra-contract.sh tests/run-tests.sh tests/extras/ta-*.sh` | exit0 | `evidence/verification/syntax.log` |
| Inventory | new contract TA | unclassified=0, marker mismatch=0, test-id 重複=0 | `evidence/test-runs/contract-inventory.log` |
| Harness-only | loop direct execution `</dev/null` | all rc2 + message | `evidence/test-runs/harness-only.log` |
| Standalone forced fail | probe loop（target 一致） | all rc1 | `evidence/test-runs/standalone-force-fail.log` |
| Standalone probe absent | probe なしループ | all rc0（差分要求） | `evidence/test-runs/standalone-normal.log` |
| Probe fail-closed | `PG_EXTRA_CONTRACT_PROBE=force-fail` かつ TARGET 未設定 | 診断 + 非ゼロ rc（no-op でない） | `evidence/test-runs/probe-fail-closed.log` |
| Prerequisite SKIP | `ta-39` / `ta-43` / `ta-44` を前提未充足で standalone 実行 | **rc3**（rc0 でないこと） | `evidence/test-runs/prereq-rc3.log` |
| Harness regression | `sh tests/run-tests.sh` | baseline remeasured at exec start, 0 failed。`ls tests/extras/ta-*.sh \| tail -1` の `[PASS]` がログに出現 | `evidence/test-runs/full-suite.log` |
| **Pre-fix FAIL 実証（AC-7 / R-011）** | **helper 導入前の HEAD に contract TA だけを載せて実行** | **contract TA が FAIL する**（修正前実装で検出力があることの実証。Mutation Matrix は修正後 helper への変異であり別物） | `evidence/mutations/pre-fix-head.log` |
| TC-33 差し替えの検出力（AC-8 / R-013） | helper の unset 集合から 1 env を削る変異 | 差し替え後の TC-33 相当が FAIL（空振りしない） | `evidence/mutations/tc33-substitute.log` |
| Helper mutation | remove fail branch / finalize call / target check in temp copy | contract tests FAIL | `evidence/mutations/` |
| **CI 実行時間（R-017）** | 反映後のフルスイート計測 | **baseline 231s に対し +250〜280s（2 倍超）を許容する**（裁定は下記） | `evidence/verification/ci-duration.log` |

### CI 実行時間の裁定（R-017）

- **実測**: フルスイート baseline = **231s / 541 passed, 0 failed**。`ta-26` の standalone 単体が **76s**
- **見込み**: TC-12（probe あり）+ TC-12（probe なし）は standalone-capable を **2 周**するため
  `ta-26` だけで +152s、全体で概算 **+250〜280s**（スイート時間 2 倍超）
- **裁定**: **既定でフルスイートに載せる**（重量ファイルの opt-in スキップは採らない）。
  理由: スキップ可能にすると「CI では重い 1 本だけ検査されない」状態が常態化し、
  本 PBI が塞ごうとしている「静かに検査が抜ける」構造を再導入する
- **緩和**: Exit Criteria の「three consecutive full suite runs」は **contract TA を含む
  フルスイート 1 回 + contract TA 単独 2 回**に読み替え、乗算を避ける
- スイート全体の高速化そのものは Out of Scope（別 PBI）

## Review Lanes

| Deliverable | Lane |
|---|---|
| helper/finalize design | POSIX shell/control-flow reviewer |
| inventory/probe test | test architecture/mutation reviewer |
| source/harness safety | PlanGate workflow/Human boundary reviewer |
| broad file migration | maintainability/diff-risk reviewer |

## Plan Review Readiness

### 受入基準 ↔ テストケースの対応

**AC↔TC 写像は [`test-cases.md`](./test-cases.md) の `## Traceability` を単一正本とする**（R-001）。
本 plan には写像を持たない（二重正本による全行不一致を防ぐため）。

### Completion Boundary

**Slice 1**: 層 A 12 本が明示 capability を持ち、rc 0/1/2/3 契約と harness regression が
機械検証され、contract TA が新規ファイルの契約漏れを検出できるところまで。

**Slice 2**（後続）: 層 B + 層 C 41 本の harness-only 化と `TASK-0914/handoff.md` writeback。
着手時に Mode を再判定する。

個別test内容、framework刷新、README一覧修正、CI 実行時間の最適化は含まない。

### Security / Operational Risk

- harness source中のexitは全suiteを短絡するためcritical
- broad file migrationでmerge conflictが高い。exec開始時に他branchがtests/extrasを変更していたら停止
- cleanup誤削除、stdin hangを負側で検証
- probeはfail-safeでありsuccess bypassを持たない。ただし **TARGET 未設定は fail-closed**
- **probe env の子プロセス伝播による masking**（`ta-26` 自己再帰）を再帰ガードで遮断

## Replan Triggers

- helper sourceのためrunner集計契約変更が必要
- standalone-capableの正常実行が外部service/credentialを要求する
- capability分類が2値で表現できない第四カテゴリを必要とする（rc 3 は capability ではなく
  実行時状態なので 2 値分類は維持される）
- migration対象fileがplan時inventoryから増減し、未分類が生じる
- full suite baselineがmainで既に赤
- ta-26 cleanup behavior / summary 書式をhelperで等価にできない
- **`TASK-0914/handoff.md` の §3 対象行が消失している**（writeback 先の不在）

### Replan Trigger を書くときの教訓（R-012 由来 / 案 D 採用後も保持）

旧 plan の Replan Trigger #1 は「top-level **`trap 0`**」を検出式にしていたが、
本リポジトリは全件 `trap ... EXIT` 表記であり **`grep 'trap 0'` は 0 件**だった。
すなわち **trigger が exec 時に空振りし「競合なし」と誤結論する**構造だった
（実際には `ta-45` が `trap - EXIT` で finalizer を消す競合を持っていた）。

**教訓: replan trigger の検出式は「設計上の概念」ではなく「リポジトリに実在する表記」に
対して書く。書いた検出式は plan 段階で 1 回実走し、ヒット件数と対象を evidence に残す。**

## Stop Condition

- Human C-3前
- destructive cleanup pathが発見された
- source経路でexitが発火した
- normal standalone probeがhangする
- 新規dependency/bash化が必要
- Slice 1 の migrationをreview可能なcommitへ分割できない
- **Slice 2 着手時に Mode 再判定を行わずに進めようとした場合**

## Human Approval Boundary

- **案 D（末尾 explicit finalize）への replan の承認**（案 C 不採用）
- **共有ファイル `tests/extras/_extra-contract.sh` の導入 = #914 §4 で棄却された E-1 の
  意図的反転の承認**（前掲「先行決定の反転」節の根拠に対する判断）
- **スライス分割（Slice 1 = 15 ファイル / high-risk、Slice 2 = 42 ファイル / 着手時再判定）の承認**
- `tests/run-tests.sh` helper source変更（Task 3 の比較検証で必要と確定した場合のみ）
- broad extras migrationのC-3
- contract probe envの採否
- PR C-4 / merge

## C-1 Self Review Checklist

- [x] #914完了を反映
- [x] countをハードコードしない
- [x] 層 A / 層 B+C をrc 1/2で区別し、前提未充足を rc 3 で分離
- [x] early exit問題を設計で扱う（案 D + contract TA の動的 probe）
- [x] source経路exit禁止を明示
- [x] negative controls / mutation evidenceを定義
- [x] **broad migrationのrollback/replanを定義**（`todo.md` 全実装タスクに `rollback:` を付与し、
      T-04 / T-05 → T-03 の revert 依存順を明記。自己申告と実体の乖離を解消）
- [x] **Mode判定を判定根拠つきで明記**（D-5 裁定 = スライス分割）
- [x] **AC↔TC 写像を test-cases.md の単一正本へ集約**
- [ ] runtime inventoryをexec開始時に取得
- [ ] C-2 independent review（**完了。`review-external.md` R-001〜R-020 を本版で確定反映**）
- [ ] 簡易 C-1 再実行
- [ ] Human C-3
