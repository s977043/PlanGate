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

> **C-2 反映済み**（`Refs: R-001`〜`R-020` / **別系統 C-2（4 レーン）由来の `R-021`〜`R-037`**）。
> 指摘の正本は [`review-external.md`](./review-external.md)。本文書は 1 回だけの確定反映後の版であり、
> 以降の変更は `plan_hash` を無効化するため C-3 承認前に確定させる。
>
> **R-021〜R-037 の反映で確定しなかった項目は `## Human C-3 の判断事項` に集約した**
> （R-022 / R-023 / R-026 の `timeout-minutes` / R-030）。**R-032 は `resolved-by-design`
> （`516e2f7` / PR #1017 で解消済み）につき反映していない**。

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
  - この 2 系統をどちらも helper へ吸収する（**Task 4b / Slice 2**。
    層 0 は Human 決定 3 により Slice 1 から繰り延べられた）
- **Slice 1 の移行対象（層 A）は 12 本**で、`ta-40` を含む（R-003）
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
- **source 経路で `exit` も非 0 `return` もしない（R-024）**。`tests/run-tests.sh` は `set -eu` で
  動くため、source された extras が**非 0 を `return` するだけでも**後続 extras が丸ごと
  スキップされ、`_pg_drain_cleanup` も `Results:` 行も出ないまま runner が exit 1 する
  （＝「テストが赤い」ようにしか見えず**途中打ち切りに気づけない**）。
  したがって `pg_extra_contract_finalize` は **harness mode では末尾で常に明示 `return 0`**、
  standalone mode でのみ `exit` する。finalize の末尾が `[ "$fail" -gt 0 ]` のような
  **test コマンドで終わる実装も禁止**（暗黙の非 0 return になる）
- **standalone 経路の脱出手段として `return 0 2>/dev/null || …` を型を問わず禁止する（R-021）**。
  skip 経路も必ず `pg_extra_contract_skip` を経由させる。理由は後掲
  `### 早期脱出の 2 型とシェル依存` を参照
- **contract TA は実 `tests/extras/` へ書き込まない（R-028）**。新規ファイル追加を伴う
  検査（TC-16）は `mktemp -d` した repo 実コピー sandbox 内で行う。実ディレクトリに
  probe ファイルを作ると、中断・異常終了時の残留が以後すべての run を汚染する
  （残留ファイルは marker も init も持たないため contract TA が恒常 FAIL になり、
  原因が「前回の中断」であることが判らない）
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
- **helper は `local` を使わない（R-033-1）**。`local` は POSIX 外だが dash / bash / zsh の
  いずれも受け付けるため **どのシェルでも検出されず**、より厳格な `sh` 実装で初めて壊れる。
  内部変数は `_PG_EXTRA_` 接頭辞のグローバルで持ち、`local` を明示禁止とする
- **mode（harness / standalone）は `pg_extra_contract_init` 呼出時に毎回解決し、
  source 時にキャッシュしない（R-033-2）**。キャッシュすると runner が helper を先に
  source する設計（Task 3）で mode が固定される

## 前提の実測検証

| 前提 | 検証 | 実測 | 判定 |
|---|---|---|---|
| #914 完了 | Issue state | closed/completed 2026-08-04 | ✅ |
| harness は source + global counters | `tests/run-tests.sh` | `pass=0`, `fail=0`, `PG_HARNESS_SOURCED=1`, `. "$extra"` | ✅ |
| standalone exit伝播の前例 | 層 0 の 4 本 | `ta-26` / `ta-58` / `ta-59` / `ta-60` が `pass=0` / `fail=0` を自前初期化（R-003） | ✅ |
| layer A file に early exit がありうる | ta-39 | prerequisite未適用時にreturn/exit 0 | ✅ |
| current file countは変動する | pbi-inputと最新監査 | 53→57 | ✅。runtime inventory必須 |
| **早期脱出（early exit）を持つ `ta-*.sh` の現存件数** | 全 `ta-*.sh` に対し **`grep -rn 'return 0 2>/dev/null' tests/extras/`** を起点にする（**`exit 0` を起点にしてはならない** — `\|\| true` 型を取りこぼす。**列位置でも絞り込まない** — 前々版の「列 0-2」という条件付き grep がインデントされた `ta-39` を取りこぼしていた） | **早期脱出は 2 型 7 件（R-021）**。**`\|\| exit 0` 型 3 件**: `ta-39-eh3-doc-light.sh`（+ 裸の `exit 0`）/ `ta-43-eh2-strict-json.sh` / `ta-44-eh457-cli-wiring.sh`。**`\|\| true` 型 4 件**: `ta-45-c3-mode-config.sh` / `ta-46-ehs-wiring.sh` / `ta-47-ehs23-wiring.sh` / `ta-49-bias-export.sh`。（参考・分岐内のみ）`ta-31-codex-plugin-status.sh` は `mktemp` 失敗時にだけ通る `\|\| true` 型を 4 箇所持つが **harness-only 想定＝層 B のため Slice 1 の対象外** | ✅。**7 件とも層 A = Slice 1 の移行対象**（層 A 12 本の一覧は `pbi-input.md`）。案 D の `pg_extra_contract_skip` 置換（**Task 5 の対象は 3 本ではなく 7 本**）で解消される。**前版が 3 件としていたのは誤り**であり本反映で是正した |
| **2 型のシェル依存（案 D の到達性）** | 素の 2 型と、skip guard 形 + 末尾 explicit finalize を `/bin/sh`（macOS = bash）/ `/bin/dash` / `/bin/zsh` で実走（本反映時に再現） | **`\|\| true` 型のみ挙動が分岐する**。`/bin/sh`（bash）= **本体が継続して走る** / `/bin/dash` = 終了 / `/bin/zsh` = 終了。`\|\| exit 0` 型は 3 シェルとも終了 | ❌ **blocker**。詳細と是正は後掲 `### 早期脱出の 2 型とシェル依存`（追跡 issue [#1026](https://github.com/s977043/PlanGate/issues/1026)） |
| **早期 exit で fail を握り潰す実例があるか** | 上記 3 本の SKIP 分岐（記号アンカー: `_T39_SKIP_APPLIED=0` / `_T43_APPLIED=0` / `_T44_APPLIED=0` の分岐）を読む | **存在する（`ta-43` / `ta-44` の 2 本）**。両者は分岐内で `tXX_fail "apply-script が期待差分を生成しない: ..."` を**呼びうる**まま直後の `return 0 2>/dev/null \|\| exit 0` へ到達する。standalone では `return` が失敗して `exit 0` になるため **`fail>0` かつ rc=0**（harness では `return 0` が成功するため顕在化しない）。**`ta-39` は SKIP 分岐でカウンタを更新しない**ため握り潰しは起きない（早期 exit 自体は持つ） | ✅。**AC-1 が塞ごうとしている実害そのものの一次証跡**。案 D の `pg_extra_contract_skip` 置換（Task 5）で解消する |
| top-level `trap ... EXIT` を持つ extras | 全 `ta-*.sh` の grep（C-2 実測） | 5 本（`ta-07` / `ta-09` / `ta-24` / `ta-28` / `ta-45`）。standalone-capable 候補は `ta-45` のみ | ✅。**案 D では trap を張らないため競合しない**（R-012） |
| test-id の一意性 | `ta-*.sh` の番号 | **`ta-14` が 2 本**（`ta-14-codex-guarded.sh` / `ta-14-skip-acknowledge.sh`）→ 番号は一意でない | ❌。**test-id は basename ベースにする**（R-016） |
| `_extra-contract.sh` の glob 混入 | `tests/run-tests.sh` の extras loop（`ta-*.sh` glob） | `_extra-contract.sh` は `ta-*.sh` に一致しない → inventory へ混入しない | ✅（R-014 の反証材料） |
| フルスイート baseline | `sh tests/run-tests.sh`（C-2 実測 / sandbox clone） | rc=0 / **231s** / 541 passed, 0 failed | ✅。CI 時間見積の基準（R-017） |

### 早期脱出の 2 型とシェル依存（R-021 / critical / 追跡 issue [#1026](https://github.com/s977043/PlanGate/issues/1026)）

**案 D（各ファイル末尾で explicit finalize）は、`|| true` 型の早期脱出を持つ 4 件に対して
CI 実行環境（dash）では到達しない**。これは Human 決定 1 で採用した案 D の前提を直接崩す
blocker であり、Slice 1 の直接スコープ内である（4 件とも層 A）。

**シェル別の挙動（本反映時に `/bin/sh` / `/bin/dash` / `/bin/zsh` で実走）**:

| 型 | 該当 | `/bin/dash`（= CI の `sh`） | `/bin/sh`（macOS = bash） | `/bin/zsh` |
|---|---|---|---|---|
| `return 0 2>/dev/null \|\| exit 0` | `ta-39` / `ta-43` / `ta-44` | 終了 | 終了 | 終了 |
| **`return 0 2>/dev/null \|\| true`** | **`ta-45` / `ta-46` / `ta-47` / `ta-49`** | **終了** | **継続（本体が走る）** | 終了 |

top-level の `return` は POSIX で未定義動作であり、dash は「成功して script を終了」、
bash は「失敗（`return: can only return from a function or sourced script` を stderr へ出す）」
として扱う。後者では `|| true` が失敗を握り潰すため **skip guard を素通りして本体が走る**。

`.github/workflows/test.yml` は `runs-on: ubuntu-latest` + `run: sh tests/run-tests.sh` であり
**CI の `/bin/sh` は dash**。したがって二重の破綻が起きる:

1. **CI（dash）**: skip 経路で top-level `return 0` が成功して script が終了するため、
   **案 D の末尾 explicit finalize に到達しない**。contract TA の force-fail probe（rc=1 を要求）が
   当該 4 件で rc=0 を返し **恒常 RED**。Verification Plan の
   「Standalone forced fail → all rc1」「Standalone probe absent → rc0」が**両方とも成立しない**
2. **開発機（bash）**: `return` が失敗して skip guard を素通りし、**前提未充足のまま本体が走る**
   （spurious FAIL）。すなわち **ローカル GREEN が CI の正しさを保証しない**

**本 plan での是正（すべて本反映で確定済み）**:

- `## 前提の実測検証` の早期脱出行を **2 型 7 件**へ是正した（grep 起点を
  `return 0 2>/dev/null` に変更。`exit 0` 起点では `|| true` 型を取りこぼす）
- Global Constraints に **「`return 0 2>/dev/null || …` を型を問わず禁止。skip 経路は
  必ず `pg_extra_contract_skip` を経由」** を追加した
- **Task 5 の置換対象を 3 本 → 7 本**（`ta-39` / `ta-43` / `ta-44` / `ta-45` / `ta-46` /
  `ta-47` / `ta-49`）へ拡大した
- **TC-17 の rc=3 対象へ `ta-45` / `ta-46` / `ta-47` を追加**し（`ta-49` は節スキップのため
  **除外** — 後掲 `#### 7 本は同質ではない`）、**dash と bash の双方**で実走することを
  Verification Plan / test-cases に固定した（**TC-29** / **M-15**。**`dash` 不在は FAIL**）

#### 7 本は同質ではない — ファイル全体ガード 6 本 + 節スキップ 1 本（`ta-49`）

**早期脱出 7 本のうち `ta-49-bias-export.sh` だけは構造が異なる**（本反映時に実物で確認）。
7 本を一律 rc=3 として扱うと **plan 自身の Finalize precedence と矛盾する**ため分離する。

| 区分 | 対象 | ガードの位置 | 移行後の期待 rc |
|---|---|---|---|
| **ファイル全体ガード（6 本）** | `ta-39` / `ta-43` / `ta-44` / `ta-45` / `ta-46` / `ta-47` | ガード到達時点で **カウンタ更新が 1 件も実行されていない**（実測: `ta-39:40-41` / `ta-44:27-28` 等の一致は `tXX_pass()` / `tXX_fail()` の**関数定義**であり実行された加算ではない） | **rc=3**（`pg_extra_contract_skip` 経由） |
| **節スキップ（1 本）** | **`ta-49`** | ファイル冒頭に「**2 層: A. …（常時実行）/ B. `bin/plangate` 配線テスト（HO 未適用時は SKIP）**」と明記され、`:72` の直前は `# ---- 層 B: bin/plangate 配線（未適用なら SKIP）----`。**ガード到達前に層 A の TC-01 / TC-02 / TC-04 / TC-06 が実走し `pass` / `fail` を 8 回更新している**（実測） | **先行 TC の結果に従う（0 または 1）+ SKIP 診断** |

**`ta-49` を rc=3 にしてはならない理由**:

1. rc=3 は本 plan の定義上 **「前提未充足＝検査していない」**を意味するが、`ta-49` は
   **実際に検査した TC を持つ**ため誤表明になる
2. `ta-49` の層 A TC が fail した状態で層 B の前提が未充足だと、
   **本 plan の Finalize precedence（`missing` かつ `fail > 0` → **rc=1**。rc=3 へ丸めない /
   C-1 第 2 ラウンド MN-2）が rc=1 を要求する**のに、7 本一律 rc=3 の TC は rc=3 を要求する。
   **TC が仕様と正面から矛盾する**

**移行方針**:

- **6 本**: guard を `pg_extra_contract_skip <reason>` 呼出へ置換（`_PG_EXTRA_PREREQ_MISSING=1`
  を立て、末尾 finalize で rc=3）
- **`ta-49`**: `pg_extra_contract_skip` を**使わない**。**節スキップ**（層 B をスキップした
  ことを示すフラグを立て、`return 0 2>/dev/null || true` を除去して**末尾 finalize へ落とす**）。
  rc は先行 TC の集計結果に従う。SKIP 診断は従来どおり出力する
- **早期脱出イディオムの除去は 7 本すべてで行う**（Global Constraints の禁止は型・構造に
  依らず適用される）。**分岐するのは「rc の意味」だけ**である

**残る依存**: 本項は **R-022（CI の `sh` 実体固定）と対で解かないと、片方のシェルでしか
検証されない状態が残る**。R-022 は `.github/workflows/**`＝Hardening Override 対象のため
**AI は適用せず patch 提示に留める**（後掲 `## Human C-3 の判断事項`）。

**Slice 1 のファイル数への影響はない**: 追加された 4 本（`ta-45` / `ta-46` / `ta-47` / `ta-49`）は
**もともと層 A 12 本に含まれており Slice 1 の対象**である。したがって
`## Mode判定` の変更ファイル数 15 / `high-risk` 判定は**変わらない**（Task 5 の作業内容が
増えるだけで対象ファイル集合は不変）。

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
2. **案 C が守ろうとしていたケースは案 D でも解消できる**（C-1 第 2 ラウンド実測により
   R-018 の「現存しない」を訂正）: 案 C の第一根拠は「早期 `exit 0` で fail を落とす経路」
   だった。この経路は **実在する**（**早期脱出は 2 型 7 件** — `|| exit 0` 型 3 件
   `ta-39` / `ta-43` / `ta-44` と `|| true` 型 4 件 `ta-45` / `ta-46` / `ta-47` / `ta-49`。
   うち `fail` を握り潰しうるのは `ta-43` / `ta-44` の 2 件。前掲「前提の実測検証」表 /
   `### 早期脱出の 2 型とシェル依存`）。
   しかし **7 件とも層 A = Slice 1 の移行対象**であり、Task 5 で当該分岐を
   `pg_extra_contract_skip` 呼出へ置換すれば rc=3（または `fail>0` を伴う場合は rc=1）として
   表明されるため解消する。すなわち **trap でしか救えない事例は存在しない**。
   trap が救うのは「移行し忘れたファイル」だが、その役割は contract TA の動的 probe
   （TC-12 / TC-16）が実行ベースで担う。

案 D の弱点（早期 return/exit 漏れを静的に完全検出できない）は、**contract TA の
動的 probe（全 standalone-capable を force-fail probe 付きで実走し rc=1 を要求）**で
実行ベースに補う。将来ファイルが top-level `exit` を導入した場合は contract TA が
probe rc≠1 として検出する。

> **R-021 による但し書き（重要）**: 上記「trap でしか救えない事例は存在しない」は
> **7 本すべてを Task 5 で移行し終えた後にのみ成立する**。移行前の `|| true` 型 4 本は
> **CI（dash）で末尾 finalize に到達しない**ため、案 D の下では contract TA の probe が
> rc=0 を返す（＝案 C の trap なら拾えたはずのケース）。したがって **Task 5 の対象を
> 7 本へ拡大することは案 D 成立の必要条件**であり、任意の追加作業ではない。
> 詳細は `### 早期脱出の 2 型とシェル依存`（issue #1026）。
>
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
| **Slice 1**（本 plan の直接対象） | 層 A 12 本 + helper `_extra-contract.sh` + 検査基盤（contract TA）1 本 + `tests/extras/README.md` | **15** | **high-risk** |
| **Slice 2**（本 PBI スコープ内・後続） | 層 B 36 本 + 層 C 5 本（＝ harness-only 化 41 本）+ **層 0 の 4 本**（`ta-26` / `ta-58` / `ta-59` / `ta-60`）+ `docs/working/TASK-0914/handoff.md` writeback | **46** | **着手時に再判定**（定量 16+ のため critical 帯の見込み） |

#### `ta-*.sh` 57 本のスライス帰属（過不足なし検証）

| 層 | 本数 | 帰属 Slice | 根拠 |
|---|---:|---|---|
| 層 0（`ta-26` / `ta-58` / `ta-59` / `ta-60`） | **4** | **Slice 2** | 既存 standalone 契約を helper へ吸収する移行。Slice 1 に入れると 19 ファイル = critical 帯に入るため **Human 決定 3 で Slice 2 へ繰り延べ** |
| 層 A | **12** | **Slice 1** | 本 plan の中核（Task 5） |
| 層 B | **36** | **Slice 2** | harness-only 化（Task 4） |
| 層 C | **5** | **Slice 2** | D-2 (c) により層 B と同一クラスで harness-only 化（Task 4） |
| **合計** | **4 + 12 + 36 + 5 = 57** | — | `ls tests/extras/ta-*.sh \| wc -l` の実測 57 と一致。**どのスライスにも属さない `ta-*.sh` は 0 本** |

> **本表のファイル数は現時点（base commit）の実測値であり、Mode 判定の根拠として記載する。
> exec 開始時に Task 1（runtime inventory）で再実測し、差異があればスライス表と Mode を
> 再判定する**（`file count / ta番号一覧を正本としてハードコードしない` の制約は
> **test 実装側**に掛かるものであり、plan の Mode 判定根拠の記載を禁じるものではない）。

- **Slice 2 は本 PBI のスコープに含めたまま「後続スライス」として扱う**。別 PBI へ切り出すか
  否かは **Slice 1 完了時に判断**し、本時点では決めない。
- `tests/run-tests.sh` への helper source は R-010 の比較検証（Task 3）で要否を確定する。
  必要と判断された場合 Slice 1 は 16 ファイルとなるが、その時点で Mode を再判定する
  （定量 16+ = critical 帯に触れるため、安全側で人間へエスカレーションする）。

#### 未移行 45 本を Slice 1 の contract TA 対象から外す扱い（移行期間 allowlist）

Slice 1 時点では 57 本中 **12 本（層 A）のみ**が helper へ移行済みであり、
残り **45 本（層 0 の 4 + 層 B 36 + 層 C 5）は未移行**である。したがって
**Slice 1 の contract TA は「全 `ta-*.sh`」ではなく「移行済みファイル」を対象**とし、
未移行の 45 本を **移行期間 allowlist** として除外する。

**pbi-input AC-5 の全文（実測引用）**:

> **AC-5**: AC-1 の検査が**回帰テストとして `tests/extras/` に追加**され、**新規スクリプト追加時の
> 伝播漏れを将来も検出できる**。**修正後は「standalone 分岐で `pass`/`fail` を自前初期化して
> いるか」を正規述語として自動判定する**（判定コマンド C）。**修正前の allowlist は移行期間のみ
> 保持し恒久化しない**。除外集合を残す場合は allowlist を明示し、将来の追加ファイルが黙って
> 除外されない構造にする（MJ-6 / D-4）

**後半条項（「allowlist を明示し、将来の追加ファイルが黙って除外されない構造にする」）を
どう満たすか**:

- allowlist は **述語ではなく明示リスト**とする。「helper bootstrap を持たないファイル」という
  述語で解決すると、**marker も init も持たない新規追加ファイルがちょうどその述語に一致して
  自動的に除外される**ため、AC-5 後半条項（黙って除外されない）に真っ向から反する
  （TC-16 / M-06 も同じ理由で空振りする）
- したがって allowlist を **base commit 時点の未移行ファイルを列挙した明示リスト**として定義する
- **置き場所は contract TA 本体**（`tests/extras/ta-XX-extra-contract.sh`）とし、
  **別ファイルを作らない**（Human 決定 4 / 2026-08-06）。実体は同一ファイル内の
  shell 関数 `_pending_migration` が heredoc で返す basename の並びとする

移行期間 allowlist の定義（contract TA 本体に内蔵）:

```sh
# 移行期間 allowlist（Slice 2 完了時に 0 行となり、本関数ごと削除する）
# 生成元: Task 1 の runtime inventory − 層 A（Slice 1 の移行対象）。手書きしない。
_pending_migration() {
  cat <<'EOF'
ta-01-....sh
ta-02-....sh
（base commit 時点の未移行 45 本を 1 行 1 basename で列挙）
EOF
}
```

- **明示リストであることは変わらないため AC-5 後半条項（「除外集合を残す場合は allowlist を
  明示し、将来の追加ファイルが黙って除外されない構造にする」）を引き続き満たす**。
  新規追加ファイルは `_pending_migration` に存在しない → allowlist に落ちない →
  contract TA の検査対象になる。これにより TC-16（marker/init なしの `ta-zz-probe.sh`
  追加で contract TA が FAIL）と M-06 が成立する
- **内蔵化が同時に解消するもの**:
  1. 恒久テストである contract TA が **`docs/working/` を実行時に読む依存が消える**
     （テストの前提がリポジトリの作業コンテキスト配下のファイルに依存しなくなる）
  2. 台帳の**不在・読取不能・パス誤り**という異常系が**原理的に存在しなくなる**
     （リストとテストが同一ファイル・同一プロセス内にあるため）。したがって
     「台帳不在時の fail-closed」を別途明文化する必要はない
  3. **新規ファイルを 1 本も追加しない**ため、Slice 1 = **15 ファイル** /
     Mode = **high-risk** の判定が維持される
- **欠点（正直に記す）**: ファイルを 1 本移行するたびに **contract TA 本体を編集**する必要が
  ある。これは「リストとテストが同一ファイルで version 管理され、片方だけが更新される drift が
  起きない」という利点の裏返しである。**Slice 2 完了でリストが空になった時点で
  `_pending_migration` 関数ごと削除する**（空の関数を恒久的に残さない）
- **生成手順**: Task 1 の `find tests/extras -maxdepth 1 -type f -name 'ta-*.sh'` 結果から
  **層 A（Slice 1 の移行対象）を差し引いた** basename を機械生成し、その出力を contract TA の
  heredoc へ**転記**する。**手書きしない**。生成コマンドと生成物を
  `evidence/test-runs/pending-migration-gen.log` に残し、**転記結果が生成物と一致することを
  目視でなく `diff` で確認する**
- **`_pending_migration` の各行の健全性は TC-25 が検査する**: (1) 各行が `tests/extras/` に
  **実在する** `ta-*.sh` の basename であること (2) その各行が helper bootstrap / init を
  **持たない**こと（＝本当に未移行であること）。移行済みファイルが allowlist に残ると
  **その 1 本が黙って検査から外れる**（MJ-E が塞いだ「新規追加ファイルの黙殺」の**逆向き**の
  リーク）。TC-25 はこれを **Slice 1 で**検出する（Slice 2 の TC-24 まで待たない）
- **`_pending_migration` 関数の不在・破損に対する専用ガードは置かない**（判断と根拠）:
  - 関数が消える / 空を返す → allowlist が空 → 未移行 45 本が検査対象に入り
    **TC-09 / TC-10 が大量 FAIL する**（fail-loud。黙って通る経路ではない）
  - heredoc 終端の破損等でリストが**過大**になる → 検査対象集合が空になり contract TA が
    0 件ループで**黙って PASS** しうる。これは本 PBI が塞ごうとしている症状そのものなので、
    **TC-25 に 3 つの assert（① 検査対象集合から contract TA 自身を除いた集合が非空
    ② `pending ⊊ discovered`（真部分集合） ③ TC-12 / TC-13 を駆動する per-file 実走ループが
    1 件以上を実行）
    を置いて塞ぐ**。**① で自己を除外するのが要点**で、contract TA は inventory に含み
    allowlist には載せない（後述 Task 6）ため、自己を除外しない非空判定は**恒真**になり
    発火しない（C-1 第 4 ラウンド MJ-I）。
    検出点は「関数が存在するか」ではなく「**検査が空振りしていないか**」に置くのが正しい
- **これは「件数を契約値にしない」制約（Global Constraints）に抵触しない**。抵触するのは
  *test の期待値*としての件数であり、移行 allowlist は **除外集合の生成入力**（データ）であって
  期待値ではない。contract TA は `_pending_migration` の**行数を検査しない**
- 移行が進むたびに `_pending_migration` から該当行を削除する。**Slice 2 完了時に
  0 行になることを TC-24 が検証する**（TC-24 の趣旨は不変。検証対象を「述語の結果が空」から
  「`_pending_migration` が 0 行を返す」へ読み替える）
- `ta-*.sh` の basename 一意性検査（TC-20）は移行状態に依存しないため、
  **Slice 1 でも runtime discovery で得た全 `ta-*.sh` を対象**とする（allowlist の対象外）

> 層 0 の 4 本は移行前でも標準的な standalone 伝播（`fail > 0 → exit 1`）を既に備えている
> （実測: `ta-26` / `ta-58` / `ta-59` / `ta-60` の standalone 分岐末尾にいずれも
> `fail` 非 0 で `exit 1` する分岐が実在する）ため、allowlist 期間中も AC-1 の実害
> （exit 0 で失敗を隠す）を新たに生まない。
> **層 B / 層 C 41 本**については、allowlist 期間中は**移行前の既存状態が Slice 2 まで継続する
> のみ**であり、**Slice 1 が新たな実害を作るわけではない**（AC-1 の Slice 1 範囲は
> Traceability で層 A 12 本へ明示縮約済み）。

### 判定根拠（定量）

| 判定軸 | Slice 1 実測 / 見込み | モード |
|---|---|---|
| 変更ファイル数 | **15**（層 A 12 + helper 1 + contract TA 1 + README 1）。**層 0 の 4 本は Slice 2 へ繰り延べ**（Human 決定 3）。**移行期間 allowlist は contract TA 本体に内蔵するため新規ファイルを生まない**（Human 決定 4）。**`docs/working/TASK-0921/` 配下の作業コンテキスト（plan / todo / test-cases / evidence）は PBI アーティファクトであり、本節でも従来どおり算入しない** | **high-risk**（6-15） |
| 受入基準数 | **7**（AC-1〜AC-7 = pbi-input 正本と 1:1。**AC-8 は R-013 由来の派生 AC で Slice 2 の受入基準**） | **high-risk**（6-10） |
| タスク数（見込み） | **11-16**（T-01, T-02, T-03, T-05, T-06, T-07（README 部分）, T-08 + 層 A の batch 分割） | **high-risk**（11-20） |

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

1. 変更ファイル数 15 は `mode-classification.md` 定量基準の high-risk 帯（6-15）に収まる。
   **これは層 0 の 4 本を Slice 2 へ繰り延べた結果である**（Human 決定 3）。層 0 を Slice 1 に
   含めた場合は 19 ファイル = **critical 帯（16+）**となり本判定は成立しない。したがって
   「層 0 を Slice 1 で触らない」ことは Mode 判定の**前提条件**であり、exec 中に層 0 へ
   1 ファイルでも触れる必要が生じた時点で **Stop Condition に該当し Mode を再判定する**
2. 影響範囲は `tests/` に閉じ、プロダクトコード・hooks・CI 定義には波及しない
3. **Hardening Override 対象パス（`check-plan-hash.sh` の 9 カテゴリ）に 1 件も該当しない**
   （C-2 実測で確認済み）。`tests/run-tests.sh` は `scripts/hooks/*.sh` にも `bin/plangate` にも
   一致せず HO 非該当
4. アーキテクチャ変更・横断的リファクタリング・公開 API の破壊的変更のいずれにも当たらない

**Slice 2 の扱い**: 46 ファイル（層 B 36 + 層 C 5 + **層 0 4** + `TASK-0914/handoff.md` 1）は
定量 16+ = **critical 帯**に入る。Slice 2 着手時に
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

#### marker 検出の正規表現仕様（R-027）

marker は**コメント行**として置かれるため、検出式を仕様化しないと以下 4 経路で空振りする
（別系統 C-2 が実測）:

1. **1 行に 2 つの marker** が書かれると count が 2 になる / 書き方次第で 1 に見える
2. **行末スペース**があると厳格アンカー（`$` 固定）の grep が **0 件**になる
3. **heredoc の中**に marker 文字列があると誤カウントする
4. **contract TA 自身**が marker 文字列を持つため自己マッチする

したがって以下を **plan の仕様として固定**する:

```text
検出式（ERE）: ^[[:space:]]*#[[:space:]]*PG_EXTRA_CAPABILITY:[[:space:]]*(standalone-capable|harness-only)[[:space:]]*$
探索範囲    : 各ファイルの先頭 20 行のみ（`head -20`）
合格条件    : マッチ行数がちょうど 1。0 でも 2 以上でも FAIL
```

- **行末スペースを許容する**（`[[:space:]]*$`）。厳格な `$` 固定にすると 2 の空振りを踏む
- **行頭アンカー + 単一行マッチ**により 1（1 行 2 marker）は「1 行に 1 マッチ」となり
  count には 1 しか寄与しないが、**同一行に 2 つ書いた場合は行末アンカーに一致せず FAIL**
  になる（黙って 1 に見えない）
- **探索範囲を先頭 20 行に限定**することで 3（heredoc 内の誤カウント）を構造的に排除する。
  実測上これは安全である: `ta-*.sh` は **57/57 が shebang を持たず**、行 2 が
  `# Sourced by tests/run-tests.sh …` 系で統一されているため、marker は先頭付近に置かれる
- 4（自己マッチ）は **既に採用済みの「自己を除外する」規律（C-1 第 4 ラウンド MJ-I）と同じ扱い**
  とする。contract TA は marker 検査の**対象には含める**が、per-file 実走ループでは
  自分の test-id を skip する
- 対応する mutation は **M-17**（検出式から行末スペース許容を落とす / 探索範囲の 20 行限定を
  外す）。TC-09 が FAIL することを実証する

### Helper location

```text
tests/extras/_extra-contract.sh
```

`ta-*.sh` globに一致させず、runnerのtest inventoryへ混入させない（実測確認済み）。
本ファイルの導入は #914 §4 で棄却された E-1 の意図的反転である（前掲）。

#### bootstrap の helper 解決規約（R-025-1）— アンカーは `$0` にせず、mode で分岐する

各 extras の defensive bootstrap が helper を解決する際、**harness 経路で `$0` をアンカーに
してはならない**。harness 経路では `$0` = `tests/run-tests.sh` であるため、`dirname "$0"` を
起点にすると **`tests/_extra-contract.sh`（不在）** を指し、**suite 全滅**を招く（後述）。

```sh
# mode 判定は既存 extras と同一イディオム（例: ta-45-c3-mode-config.sh の harness 判定）
# 判定結果を _pg_extra_mode に保持し、脱出経路でも再利用する（後述の理由により必須）
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"                                    # harness: runner が設定
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"   # standalone: 自分の位置
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0            # harness: suite を止めずに当該ファイルだけ赤くする
  fi
  exit 1                # standalone: 非 0 を rc へ伝播する
fi
. "$_pg_extra_helper"
```

##### なぜ脱出に `return 0 2>/dev/null || …` を使わないか（自己整合）

本 plan の Global Constraints は **`return 0 2>/dev/null || …` を型を問わず禁止**している（R-021）。
bootstrap の脱出も**この禁止の例外にしない**。理由は 2 つある。

1. **禁止の根拠がそのまま当てはまる**。このイディオムは「`return` が成功するか否か」が
   shell 実体で割れるため挙動が環境依存になる（`|| true` 型は dash 終了 / bash 継続）。
   bootstrap は **suite 全滅を防ぐための経路**であり、そこに環境依存を持ち込むと
   「開発機では通るが CI では止まる」という本 PBI が塞ごうとしている失敗形そのものになる
2. **機械検査と両立しない**。Slice 1 DoD は層 A に対し
   `grep -rn 'return 0 2>/dev/null' tests/extras/` が **0 件**であることを要求する。
   bootstrap が例外を持つと、この grep は「例外を除いて 0 件」という**人手の判断を含む検査**へ
   退化し、検査器としての価値を失う

したがって脱出は **mode 判定の結果（`_pg_extra_mode`）で `return 0` と `exit 1` を書き分ける**。
mode は helper 解決の前に一度だけ判定済みなので追加コストは無い。

> **この節の経緯**: 前版の bootstrap スニペットは脱出に `return 0 2>/dev/null || exit 1` を
> 使っており、**plan 自身の禁止条項に違反していた**。独立 river-review の F1 是正を反映した
> 版でこの矛盾が持ち込まれ、**是正を担当したワーカー自身が申告して発見された**。

##### なぜ「`.` してから失敗を検知する」書き方にできないか（実測）

`.`（source）は POSIX の **special built-in** であり、**失敗すると非対話シェルは
`||` や `if` の中にあっても即座に終了する**。したがって
`. "$helper" || { 診断; ... }` という形は **診断に到達しない**。本反映時の実測:

| シェル | `. /nonexistent/_extra-contract.sh \|\| printf 'DIAG '` の後に `printf 'AFTER'` |
|---|---|
| **`/bin/dash`（= CI の `sh`）** | **rc=2 で即終了。`DIAG` も `AFTER` も出ない** |
| **`/bin/sh`（macOS = bash 3.2）** | **rc=1 で即終了。同上** |
| `/bin/zsh` | 継続（`DIAG` / `AFTER` とも出る。rc=0） |

- **これは `set -e` の有無に依らない**。special built-in の失敗はそれ自体が
  非対話シェルの終了要因であり、「`set -eu` 下で `.` が失敗すると」という説明は**不正確**
  （前版の記述を本反映で是正した）
- したがって **source する前に `[ -r "$helper" ]` で可読性を確認する**のが唯一成立する形である。
  probe が失敗したときのみ診断を出し、`fail` を 1 加算して **harness 経路では `return 0`**
  （Global Constraints「source 経路で非 0 `return` しない」/ R-024 と両立させ、suite を
  止めずに赤くする）、**standalone 経路では `exit 1`** とする
- 残る競合条件（probe と source の間にファイルが消える）は無視できる。実害があるのは
  「helper を配り忘れた」「revert 順序を誤った」という**恒常的な不在**であり、probe で捕捉できる

##### mode で分岐する理由（R-025-1 + 汚染耐性）

**存在判定を `${EXTRAS_DIR:-}` に寄せてはならない**。実測: `tests/run-tests.sh` が
standalone 実行時の汚染除去のために unset する env は **7 個**（`PLANGATE_SKIP_REASON` /
`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_FILE` / `PLANGATE_BYPASS_HOOK` /
`PLANGATE_HOOK_STRICT` / `PG_HARNESS_SOURCED` / `PLANGATE_ALLOW_MASS_DELETE`）であり、
**`EXTRAS_DIR` / `FIXTURES_DIR` は含まれていない**（両者は runner 内で `export` なしに
代入されるだけ）。

- `${EXTRAS_DIR:-…}` を存在判定に使うと、**standalone 実行時に外部から `EXTRAS_DIR` が
  export されていれば別ツリーの helper を source しうる**。TC-15（External env
  contamination）は guarded な env しか汚染しないため**この経路を検出できない**
- **env 汚染耐性が主題の本 PBI が、解決策として新しい汚染面を開けることは許されない**
- `PG_HARNESS_SOURCED` は **runner が冒頭で unset し（汚染除去済み）、extras loop の直前で
  自ら設定する**ため汚染耐性がある。`FIXTURES_DIR` との AND も既存の harness 判定
  （Global Constraints）と同一であり、**新しい依存を増やさない**
- **`EXTRAS_DIR` は harness 経路でのみ読む**。harness 経路では runner が代入済みの値に
  上書きされているため、外部の汚染値は届かない

#### 適用（forward）側の原子性（R-025-2）

revert 順序（`T-05 → T-03` / `T-04b → T-03`）は既に規定済みだが、**適用側の原子性**は
未規定だった。**「runner への helper source」と「各 extras の bootstrap 追加」は
同一 commit・同一 PR に入れる**ことを DoD とする。helper source だけが先に入って
bootstrap が無い中間 commit を作ると full suite が全滅する。

> **R-010 との連動**: Task 3 の比較検証で runner 変更を落とせると確定した場合、
> 本節の原子性要求は**不要になる**（bootstrap 単独になるため）。

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

#### summary の `<NN>` 導出規則（C-1 MN-2）

helper が受け取るのは **basename ベースの test-id のみ**（R-016）だが、summary 書式は
`TA-<NN> standalone: ...` という**番号ベース**である（R-015a により書式は維持が必須）。
両者を橋渡しする導出規則を helper 内に固定する:

```text
<NN> = test-id の先頭から正規表現 ^ta-([0-9]+) で捕捉した数字列を、そのまま大文字接頭辞 TA- に連結
       例: ta-26-plugin-sync      → TA-26
           ta-14-codex-guarded    → TA-14
           ta-14-skip-acknowledge → TA-14
```

- 捕捉に失敗した test-id（`^ta-[0-9]+` に一致しない）は **fail-closed**（診断 + 非ゼロ）とし、
  番号なしの summary を黙って出さない
- **`<NN>` は summary 書式のためだけに使い、識別子としては使わない**。
  `PG_EXTRA_CONTRACT_TARGET`・診断メッセージ・contract TA のループはすべて basename（R-016）
- **既知の非一意性**: `ta-14` 対の 2 本は同じ `TA-14 standalone:` を出力する。
  **2 本とも層 B（harness-only 想定）であり Slice 1 の standalone summary 経路に乗らないため
  Slice 1 では実害がない**。層 B を移行する **Slice 2 の検討事項**として残す
  （harness-only は summary を出さないため Slice 2 でも実害が出ない見込みだが、
  Slice 2 着手時に再確認する）
- **summary 書式を basename ベースへ変える案は採らない**。`ta-26` の TC-13 が
  `TA-26 standalone:` を literal grep しており（R-015a）、書式変更は rc ではなく grep 側を壊す

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
対象は **早期脱出のうち「ファイル全体ガード」6 本**（`ta-39` / `ta-43` / `ta-44` / `ta-45` /
`ta-46` / `ta-47`）。前版の「3 本」は `|| true` 型を取りこぼした誤りであり **R-021 で是正**した。
**`ta-49` は 7 本目だが節スキップのため rc=3 の対象外**（前掲 `#### 7 本は同質ではない`）。

### Finalize precedence

`pg_extra_contract_finalize` は各 file 末尾で明示呼出される（案 D）。

**harness mode では rc を返さず必ず明示 `return 0` する（R-024）**。`tests/run-tests.sh` は
`set -eu` で動くため、finalize が非 0 を `return` すると後続 extras が丸ごとスキップされ、
`Results:` 行も出ないまま runner が exit 1 する（＝赤いだけで途中打ち切りに気づけない）。
standalone mode でのみ `exit` する。

1. registered cleanupをdrain
2. optional contract probeを適用（harness mode では読まない）
3. **probe env を unset して子プロセスへ伝播させない**（再帰ガード / R-015b）
4. summaryを `TA-<NN> standalone: N passed, M failed` 書式で出力（R-015a）
5. rc を precedence に従って決定

precedence:

| prerequisite | original rc | fail | final rc | 備考 |
|---|---:|---:|---:|---|
| missing | any | **>0** | **1** | **`fail > 0` が前提未充足より優先**。既にアサーションが落ちているので「検査していない」ではない |
| missing | any | 0 | **3** | 前提未充足。検査していないので pass/fail を主張しない |
| present | 0 | 0 | 0 | |
| present | 0 | >0 | 1 | |
| present | nonzero | 0 | original rc | |
| present | nonzero | >0 | original rc | 既存のより具体的なfailureを保持 |

> **原則（C-1 第 2 ラウンド MN-2）**: **「前提未充足だが既に失敗している」は「検査していない」
> ではなく「検査して失敗した」である**。したがって `pg_extra_contract_skip` 呼出時点で
> `fail > 0` なら、helper は診断（どの fail が既に立っているか）を出したうえで **rc=1 を優先**し、
> rc=3 へ丸めない。丸めると `ta-43` / `ta-44` の SKIP 分岐にある
> `tXX_fail "apply-script が期待差分を生成しない: ..."` という**本物のアサーション失敗が
> 「検査していない」へ格下げされ**、本 PBI の主題（失敗を隠さない）と逆向きになる。

exit 2はharness-only misuse専用であり、standalone-capableの内部test failure（1）とも
prerequisite未充足（3）とも区別する。

#### `original rc` の捕捉規約は **未確定**（R-030 / Human C-3 の判断事項）

上表の `original rc` を保持する 2 行は、**案 C（trap が `$?` を受け取る）でしか自然に成立しない
設計**だった。**案 D（末尾で明示呼出）では `$?` は直前の 1 コマンドで容易に失われる**。

別系統 C-2 の実測: `fail=0; false; printf 'summary'; fin "$?"` → `orig=0`（rc 1 が消える）。
既存の層 0 の 4 本は **summary を printf してから** `[ "$fail" -eq 0 ] || exit 1` を実行する形で
あり、この形をそのまま helper 化すると **「保持しているつもりで常に 0」**になる。

**選択肢（どちらを採るかで README 規約と Task 5 の置換テンプレートが変わる）**:

| 案 | 内容 | 影響 |
|---|---|---|
| **(a) 2 値化**（別系統 Lane 1 の推奨） | `fail>0 → 1` / `fail==0 → 0` とし、precedence 表から `original rc` 行を落とす | TC-06（original の nonzero rc を握り潰さない）と **正面から衝突**。TC-06 の削除または再定義が必要 |
| **(b) 保持する** | 「`pg_extra_contract_finalize` 呼出の**直前に他コマンドを挟まない**」を規約化し、summary 出力は helper 内部で行う。`tests/extras/README.md` の新規ファイル checklist に入れる | TC-06 を維持できるが、**規約違反が静的に検出しにくい**（案 D の弱点と同型） |

**本反映では裁定しない**。TC-06 が既に Slice 1 の DoD に入っているため (a) を選ぶと
受入基準側の変更を伴う。**Human C-3 で確定する**（`## Human C-3 の判断事項` 参照）。
それまで上表の `original rc` 2 行は **暫定**として扱い、exec 開始前に確定させる。

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
- **probe message は一意文字列 + test-id を載せる（R-029-1）**。書式を
  `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>` に固定する。理由は下記

#### rc の値だけを合格条件にしない（R-029）

TC-12 は裁定 ② の反映で **(a) probe なし → rc=0 / (b) probe あり → rc=1** の差分 assert へ
強化済みだが、**合格条件は依然 rc の値だけ**であり、他要因の rc と区別できない。

- **rc=1 側**: 層 0 の 4 本は legacy の `[ "$fail" -eq 0 ] || exit 1` を持つため、
  **finalize が一度も呼ばれなくても他要因で rc=1 になりうる**。
  「finalize に到達し `fail>0` が rc=1 へ写像された」ことを証明できない
- **rc=2 側**: shell の**構文エラーも rc=2**（コマンド不在は rc=127）。構文を壊された
  ファイルは harness-only guard が実行されていなくても TC-11 を PASS しうる

したがって合格条件を以下へ強化する:

1. **TC-12 の (b)**: `rc == 1` **AND** 出力に `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>` を
   含む、の **AND** にする（plan の Contract probe 節は「区別可能なメッセージ」までは
   規定済みだったが、**TC 側の合格条件になっていなかった**）
2. **TC-11**: `rc == 2` **AND** `[ERROR] <basename-id> is harness-only` の **id 込み照合**にする
   （現行 TC-11 の "emits standard diagnostic naming that basename" を**合格条件として明文化**）
3. **`sh -n` を独立 TC（TC-27）にする**。Verification Plan には `sh -n` 実行があるが
   **TC としては独立していなかった**ため、構文破壊が rc=2 に化けて紛れる余地が残っていた
4. 対応する mutation は **M-18**（probe message から一意文字列 / test-id を落とす）

contract testはmarkerから対象を発見し、各standalone-capableを:

```sh
PG_EXTRA_CONTRACT_PROBE=force-fail \
PG_EXTRA_CONTRACT_TARGET="$id" \
sh "$file" </dev/null
```

で実行し **rc=1** を要求する。加えて **probe なしの実行で rc=0 になること**も取り、
両者の差分を要求する（裁定 ②。(b) 単独では「元から常に rc=1」なファイルを検出できない）。

#### prerequisite 充足の判別手順 — 実行 → 分類 → assert の 2 段構成（C-1 MN-4）

上記の「probe なし → rc=0」は **prerequisite が充足しているファイルにしか成立しない**。
前提未充足のファイルは rc=3 を返すためである（rc 意味レイヤー）。したがって contract TA は
「前提が充足しているか」を assert の**前に**判別する必要があるが、
**rc=3 を分類にも合否判定にも使うと循環定義になる**（rc=3 を「前提未充足だから正しい」と
読むなら、実装が常に rc=3 を返しても検出できない）。

これを次の 2 段構成で解く:

1. **prerequisite 表明の唯一経路を固定する**: 前提未充足の表明は
   **`pg_extra_contract_skip <reason>` の呼出のみ**とする。helper は skip 呼出を受けたときだけ
   `_PG_EXTRA_PREREQ_MISSING=1` を立て、finalize で rc=3 を返す。
   **skip を経ずに rc=3 が出る経路を作らない**（rc=3 は helper が発行する唯一の値であり、
   テスト本体が直接 `exit 3` してはならない）
2. **段 1（実行と分類）**: contract TA は各 standalone-capable を **probe なしで 1 回実行**し、
   その rc で 2 クラスへ分類する:
   - rc=3 → **前提未充足クラス**
   - rc=0 → **前提充足クラス**
   - **それ以外（1 / 2 / その他）→ 分類不能 = 即 FAIL**（fail-closed。
     rc=3 を「常に正しい」と読ませないための対置条件）。
     **Finalize precedence の `missing + fail>0 → 1` はここで rc=1 として現れ、
     分類不能 = FAIL になる**。これは正しい: clean run で本物のアサーション失敗を
     出しているファイルは前提の有無に関わらず欠陥であり、握り潰さない
3. **段 2（クラス別 assert）**:
   - **前提充足クラス** → TC-12 が (a) probe なし rc=0 / (b) probe あり rc=1 の**差分**を assert
   - **前提未充足クラス** → **TC-17** が rc=3 を assert し、あわせて
     **その rc=3 が `pg_extra_contract_skip` 由来であること**（skip 診断メッセージの出現）を
     assert する。probe あり rc=1 は要求しない（前提がないので検査できない）

段 1 の実行結果（各ファイルのクラス）は evidence へ記録する。
**クラス分けの内訳は evidence に出すが、件数を test の期待値へ埋め込まない**。

> **base 時点の実測（C-1 第 2 ラウンドで再測定し、前版の記述を訂正）**:
> 早期 SKIP 経路を持つ 3 本を base commit で standalone 実行した結果は
> **`ta-39` / `ta-43` / `ta-44` いずれも rc=0（前提充足）**である
> （`ta-43` の前提判定先は `scripts/hooks/check-c3-approval.sh` であり、
> 記号アンカー `_T43_APPLIED=1` の分岐に入る。前版が挙げていた
> 「`check-plan-hash.sh` に `_eh2_stdin` が 0 件」は**参照ファイルを取り違えた誤り**で、
> 実際には `check-c3-approval.sh` に `_eh2_stdin` が存在する）。
> すなわち **base commit 時点では前提未充足クラスは空**である。
>
> **それでも 2 段構成を外さない理由**: 前提の充足はリポジトリ状態（hook 適用状況）に依存し、
> **exec 時点や CI 実行環境で反転しうる**。TC-12 を全件一律 rc=0 で固定すると、前提が外れた
> 瞬間に確定的 FAIL になる。**クラス分けは exec 開始時に段 1 で必ず再実測**し、
> どのファイルがどのクラスかを plan に固定しない。TC-17 は前提未充足を構成した sandbox で
> 常に検査できる（実リポジトリ状態に依存しない）。

#### TC-17 / M-10 の sandbox 構成手順（Human 決定 5 / Slice 1 の必須ゲート）

TC-17（前提未充足で rc=3）と M-10（rc 0 を返す変異を TC-17 が検出）は、base commit では
前提未充足クラスが空であるため **sandbox を構成しなければ実行できない**。
**この 2 件を Slice 2 へ繰り延べず、以下の手順を Slice 1 の必須ゲートとして維持する**。

**制約（第 3 ラウンドで実測）— `FIXTURES_DIR` によるルート差し替えは使えない**:
`ta-39` / `ta-43` / `ta-44` はいずれも
`[ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]` が偽のとき
（＝standalone 経路）に **`PG_HARNESS_SOURCED` を含む 7 env を unset したうえで
`_TXX_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"` を採る**。
つまり standalone 実行ではスクリプト自身の位置からルートが決まり、
**`FIXTURES_DIR` を渡してもルートを差し替えられない**。
したがって **repo ツリーの実コピーが必須**である
（第 3 ラウンドは `ta-43` で実測。`ta-39` / `ta-44` も同一構造であることを併せて確認した）。

**手順**:

1. **repo を temp へコピー**する。`SANDBOX="$(mktemp -d)"` を取り、`mkdir -p "$SANDBOX/repo"`
   したうえで **追跡ファイルの「作業ツリー」コピー**を `$SANDBOX/repo` へ展開する:

   ```sh
   command -v git >/dev/null 2>&1 || { printf '  [FAIL] git unavailable: sandbox cannot be built\n' >&2; exit 1; }
   ( cd "$(git rev-parse --show-toplevel)" && git ls-files -z | tar --null -T - -cf "$SANDBOX/tree.tar" ) &&
     tar -xf "$SANDBOX/tree.tar" -C "$SANDBOX/repo"
   ```

   - **cwd を repo ルートへ明示する**: `git ls-files` はサブディレクトリから実行すると
     **そのサブツリーの追跡ファイルしか返さない**。contract TA は `tests/extras/` から
     起動されうるため、cwd 依存のまま走ると sandbox が不完全になり
     （`scripts/hooks/` や `bin/plangate` が欠けて 2 の述語除去が空振りする）、
     TC-17 / M-10 が偽の結果を返す。`cd` と `git ls-files | tar` を**同一のサブシェル**に
     包み、呼び出し元の cwd を変えないこと（`tar --null -T -` も cwd 相対でパスを
     解決するため、`cd` は tar 側にも掛かっている必要がある）

   **`git archive HEAD` を使ってはならない**。`git archive HEAD` は **commit 済みツリー**を
   出力するため、(a) 未 commit の移行が worktree に乗っている TDD ループ中は
   **HEAD 側の未移行 `ta-39` / `ta-43` / `ta-44`** を実行することになり
   （未移行の `ta-39` は述語不在時に `exit 0` を返すので rc=0 となり、rc=3 を期待する
   TC-17 が**偽 FAIL** する＝ローカルで RED/GREEN が回らない）、
   (b) 逆に「commit 済みの移行を worktree で戻した」状態では HEAD 側が緑を返し
   **退行を見逃す**。判定対象は常に**いま編集している作業ツリー**でなければならない。
   symlink ではなく実体コピーであること（`$0` からルートを解決するため）。
   **中間 tar ファイルを経由する**のは、`tar -cf - | tar -x` のパイプ直結が
   macOS の bsdtar で producer 側に `tar: Write error` を出す（第 4 ラウンドで実測。
   内容は一致するが `set -o pipefail` 下で誤 FAIL になる）ためである
   - **git への依存と fail-closed**: 本手順は **git バイナリと git checkout 内であること**に
     依存する。これは sandbox 構成（テスト側の足場）に限った依存であり、allowlist のような
     検査データの実行時依存ではない。**git が使えない場合は SKIP せず fail-closed** とし、
     診断メッセージを stderr へ出して **rc=1** で落とす（`3`＝前提未充足 SKIP でも
     `2`＝harness-only 誤用でもない。sandbox が組めないことを SKIP に丸めると
     TC-17 / M-10 が黙って空振りする）
2. **コピー側から対象述語文字列を除去**して前提未充足を成立させる
   （**実測済みの述語**。除去はコピー側のみで行い、repo 本体には触れない）:

   | test | 述語文字列 | 判定先ファイル |
   |---|---|---|
   | `ta-39` | `EH-3_DOC_LIGHT_SKIP` | `scripts/hooks/check-plan-hash.sh` |
   | `ta-43` | `_eh2_stdin` | **`scripts/hooks/check-c3-approval.sh`** |
   | `ta-44` | `check-test-cases.sh` と `check-verification-evidence.sh` の**両方** | `bin/plangate` |

3. **コピー側の `ta-*.sh` を standalone 実行**する:
   `sh "$SANDBOX/repo/tests/extras/ta-43-eh2-strict-json.sh" </dev/null`。
   `$0` がコピー側を指すため `_T43_ROOT` はコピー側に解決され、2 の除去が効く
4. **rc と診断を記録**する。`> "<log>" 2>&1` で **stderr を必ず合流**させる
   （`tXX_fail` は `>&2` へ出す。前掲 MN-B）。
   assert は **rc=3** かつ **`pg_extra_contract_skip` 由来の診断が出ていること**
5. **後始末**: `rm -rf "$SANDBOX"` は `mktemp -d` が返した path に対してのみ行う
   （Global Constraints「未検証 path を `rm -rf` しない」）

**destructive test は必ず `mktemp` fixture の中で行う**。述語文字列の除去・apply-script の
実行・hook の書き換えを **repo 本体に対して行ってはならない**。`ta-44` の前提除去は
`bin/plangate`（Hardening Override 対象パス）への編集に見えるが、**対象はコピー側だけ**であり
repo 本体の `bin/plangate` は読み取りのみである。

- evidence: `evidence/test-runs/prereq-rc3.log`（Verification Plan の `Prerequisite SKIP` 行と
  同一の成果物。TC-17 / M-10 はこの log を根拠とする）
- 主担当 Task: **Task 6**（contract TA が本手順を内包し、TC-17 / M-10 を実行ベースで回す）。
  **Task 5 の移行前実測**（`pre-migration-fail-swallow.log`）も同一手順で sandbox を構成する

### Harness-only direct execution

helper initがtest bodyより前に:

```text
[ERROR] <id> is harness-only; run: sh tests/run-tests.sh
```

をstderrへ出しexit 2。fixture参照・tmp生成・hook実行より前でなければならない。

### `ta-26` TC-33 の扱い（R-013 / **Slice 2 の必須前提**）

> **スライス帰属（Human 決定 3 / C-1 MJ-A）**: `ta-26` は**層 0 = Slice 2** であり、
> **Slice 1 では `ta-26` を触らないため TC-33 は Slice 1 では壊れない**。
> したがって本節の設計制約と **AC-8 / TC-22 / M-09 は Slice 2 の受入基準**である。
> **R-013 の指摘自体は失効していない**: helper へ 7 env unset を集約する設計を採る限り、
> 層 0 移行時に TC-33 は必ず本節の分岐に到達する。**Slice 2 着手前に本節を再読し、
> 差し替え設計が未確定のまま層 0 の移行に入らないこと**（Stop Condition）。
> なお helper 自体は Slice 1 で作られるため、**helper 側の unset 集合を
> 「`run-tests.sh` の 7 env を包含する」形で Slice 1 のうちに実装しておく**こと
> （Slice 2 での差し替えを可能にする前提条件）。

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
- **移行後も空振りせず同等以上の検出力を保つこと**を **AC-8（Slice 2 の受入基準）** として立てる
- **変異注入で FAIL することを実証する**（Verification Plan の Mutation 行 / M-09。**Slice 2**）

#### 差し替えの等価性の明示（R-031）

別系統 C-2 の maintainability レーンは**本節と異なる結論**（helper に env unset / ROOT 解決を
所有させず、各ファイルの既存 unset ブロックを維持する）に到達した。相違点と、それでも
現行方針を維持する根拠を記録する。

**相違点**: TC-33 は「各ファイル**自身の** unset 行が harness 7 env を包含すること」を
**extras 横断で静的走査**する唯一の箇所である。検査対象を helper 1 ファイルへ差し替えると、
**#914 の「残存 0」という全体性質の検証が消える**ように見える。

**等価性の主張（現行方針を維持する根拠）**: 差し替え後の TC-33 相当は次の **2 条件の AND**
であり、これは元の全体性質と**等価**である。

```text
(1) helper の standalone 分岐の unset 集合 ⊇ run-tests.sh の guarded env 集合
(2) 全 ta-*.sh が helper bootstrap + init を持つ
```

- (1) 単独では「helper を通っていないファイル」を見逃す
- (2) 単独では「helper が実は unset していない」を見逃す
- **(1) AND (2) は「全 `ta-*.sh` が guarded env を unset した状態で走る」と等価**である。
  元の TC-33 は各ファイルの inline unset を直接見ていたが、helper 集約後は
  「helper を必ず通る」ことが (2) で保証されるため、検査点を helper へ移して等価性が保たれる
- **(2) は allowlist の影響を受けてはならない**。移行期間中は `_pending_migration` に載る
  ファイルが (2) を満たさないため、**Slice 2 完了時（allowlist 0 行）に初めて等価性が成立**する。
  したがって **AC-8 / TC-22 は Slice 2 の受入基準**であるという現行の帰属は正しい
- **Slice 2 着手時に本節を再評価する**（別系統の代案＝helper に unset を持たせない設計へ
  切り替える余地は Slice 2 まで残る）

## Files / Interfaces

| File | Operation | Purpose |
|---|---|---|
| `tests/extras/_extra-contract.sh` | create | shared mode/finalization/cleanup/probe contract（#914 E-1 の意図的反転） |
| `tests/run-tests.sh` | **modify（要否は Task 3 で確定 / R-010）** | helperをextras loop前にsource。集計ロジックは不変。bootstrap 単独で代替可能なら本行を落とす |
| `tests/extras/ta-*.sh`（層 A 12 / **Slice 1**） | modify | marker + init + 末尾 finalize |
| `tests/extras/ta-*.sh`（層 B 36 + 層 C 5 / **Slice 2**） | modify | marker + init（harness-only 化。body side effect 前に exit 2） |
| `tests/extras/ta-*.sh`（**層 0 の 4 本 / Slice 2**） | modify | marker + init + 末尾 finalize。**legacy footer 2 系統の helper 吸収**（R-003）と **TC-33 差し替え**（R-013 / AC-8） |
| `tests/extras/ta-XX-extra-contract.sh` | create | inventory/dynamic contract regression test。番号はexec時inventoryで採番。**移行期間 allowlist（`_pending_migration`）を本体に内蔵**し、移行のたびに行削除 → Slice 2 で関数ごと削除（MJ-E / MJ-F / MJ-G / AC-5 後半条項 / Human 決定 4） |
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
- [ ] **移行期間 allowlist の内容を生成する**（MJ-E / MJ-F / MJ-G）。
      内容は「inventory 全件 − Slice 1 の移行対象（層 A）」の basename を 1 行 1 件で列挙。
      **手書きせず inventory から機械生成**し、生成コマンドと生成物を
      `evidence/test-runs/pending-migration-gen.log` に残す。
      **生成物は Task 6 で contract TA 本体の `_pending_migration` heredoc へ転記**し、
      転記結果と生成物が一致することを `diff` で確認する（別ファイルは作らない / Human 決定 4）

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
- **prerequisite missing → rc3**（R-002）。**表明経路は `pg_extra_contract_skip` のみ**であり、
  skip を経ずに rc3 が出る経路がないこと（MN-4）
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
- [ ] **bootstrap を前掲 `#### bootstrap の helper 解決規約` のとおり実装する**（R-025-1 / F5）:
      **mode 判定（`PG_HARNESS_SOURCED` AND `FIXTURES_DIR`）で分岐**し、harness 経路のみ
      `EXTRAS_DIR` を読む。**`${EXTRAS_DIR:-…}` を存在判定に使わない**
      （`EXTRAS_DIR` は runner の unset 7 env に含まれず、standalone 実行時に外部 export で
      別ツリーの helper を source しうる＝新しい汚染面。TC-15 では検出できない）
- [ ] **helper の解決失敗は `.` の前に `[ -r "$helper" ]` で検出する**（R-025-1 / F1）。
      **`. "$helper" || { 診断 }` は成立しない** — `.` は special built-in であり、
      失敗すると非対話シェルは `||` の中でも即終了する（実測: dash rc=2 / bash rc=1 で
      いずれも診断に到達しない。**`set -e` の有無に依らない**）。
      probe 失敗時は診断 + `fail` 加算のうえ **harness では `return 0` / standalone では `exit 1`**
- [ ] **runner を残す場合、「helper source」と「各 extras の bootstrap 追加」を
      同一 commit / 同一 PR に入れる**（forward 側の原子性 / R-025-2）。helper source だけが
      先に入った中間 commit を作らない
- [ ] **helper が harness mode で非 0 を `return` しないことを確認する**（R-024）。
      finalize の末尾が test コマンドで終わっていないこと（`sh -n` では検出できないため目視 + TC-26）
- [ ] **helper に `local` を使っていないことを機械確認**（R-033-1。`grep -n '\blocal\b'` = 0 件）
- [ ] **mode 解決が `pg_extra_contract_init` 呼出時ごとに行われ、source 時にキャッシュ
      されていないことを確認**（R-033-2）
- [ ] synthetic RED testsをGREEN化

**rollback**: helper 追加 commit と（残す場合の）runner source 行 commit を
`git revert <sha>`。未 push なら `git reset --hard`。extras migration 前なので影響なし。
**T-04 / T-04b / T-05 / T-06 を revert する場合は本 Task の revert が最後になる**
（依存順。contract TA（T-06）も helper API を参照する / C-1 MN-3）。

### Task 4: Migrate harness-only files（Slice 2）

**Purpose**: direct misuseをtest body前にexit2。層 C は D-2 (c) により本 Task に含める。

- [ ] inventoryからharness-only全件（層 B 36 + 層 C 5 = 41）へmarker/bootstrap/init
- [ ] 各file standalone `</dev/null` がrc2 + standard message
- [ ] tmp/hook/audit side effect 0を代表 + static ordering checkで確認
- [ ] **`ta-31-codex-plugin-status.sh` の分岐内 `return 0 2>/dev/null || true` 4 箇所を除去する**
      （R-021 の残余。`mktemp` 失敗時にだけ通る経路だが同じシェル依存を持つ。
      **Slice 2 完了時に `grep -rn 'return 0 2>/dev/null' tests/extras/` が全件 0 件になる**）
- [ ] harness full suiteのbaseline維持

**rollback**: batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
**helper 導入前まで戻す場合は Task 3 の revert が前提**（helper 未導入で marker/init だけ
残ると全 harness-only ファイルが起動時に落ちる）。revert 順序は T-04 → T-03。

### Task 4b: Migrate 層 0 files（Slice 2）

**Purpose**: 既存 standalone 契約を持つ層 0 の 4 本（`ta-26` / `ta-58` / `ta-59` / `ta-60`）を
helper へ吸収する。**Human 決定 3 により Slice 1 から繰り延べられた**（Slice 1 に含めると
19 ファイル = critical 帯に入るため）。

- [ ] marker/bootstrap/init + **末尾 explicit finalize** を追加（案 D）
- [ ] **legacy standalone counter/cleanup/footer の 2 系統を helper へ吸収**（R-003）:
      `ta-26` の `[ "$fail" != "0" ]` 形と `ta-59` / `ta-60` の `[ "$fail" -eq 0 ] || exit 1` 形
- [ ] **`ta-26` TC-33 の検査対象を helper 側へ差し替える**（R-013 / AC-8 / TC-22 / M-09）。
      空振り化させない。**着手前に plan の `### ta-26 TC-33 の扱い` を再読する**
- [ ] **summary 書式 `TA-<NN> standalone: N passed, M failed` の等価性を前後比較で確認**
      （R-015a / `ta-26` TC-13 の literal grep / TC-18）
- [ ] **`ta-58` / `ta-59` / `ta-60` の現行 summary 書式を grep する消費者が存在しないことを
      移行前に実測確認する**（MN-6）。実測: 層 0 の 4 本のうち R-015a の
      `TA-<NN> standalone: N passed, M failed` 書式に一致するのは **`ta-26` のみ**であり、
      `ta-58` / `ta-59` は `Results: %d passed, %d failed`、`ta-60` は
      `TA-60 standalone: pass=%s fail=%s`。TC-18 は `ta-26` のパリティしか要求していないため、
      **helper 集約で書式が変わる 3 本について、その literal を grep する箇所が
      リポジトリ内に無いことを確認してから移行する**（無ければ書式統一してよい）
- [ ] `ta-26` migration は Slice 2 の最後に行い、既存 heavy tests を前後比較（TC-18）
- [ ] **移行完了をもって contract TA の `_pending_migration` が 0 行になることを確認し、
      関数ごと削除する**（TC-24 / AC-5）

**rollback**: batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
**helper 導入前まで戻す場合は Task 3 の revert が前提**。`ta-26` は最終 batch なので
単独 revert が可能。revert 順序は T-04b → T-03。

### Task 5: Migrate 層 A files（Slice 1 中核）

**Purpose**: 層 A **12 本**の全終了経路の fail propagation。
**層 0 の 4 本は本 Task の対象外**（Task 4b / Slice 2）。

- [ ] marker/bootstrap/init + **末尾 explicit finalize** を追加（案 D）
- [ ] file固有root fallbackは保持
- [ ] **層 A 12 本は全数がカウンタ未初期化**（pbi-input A-1'）のため、helper 側の
      `pass=0` / `fail=0` 初期化に確実に載せる
- [ ] **早期脱出 7 本（= ファイル全体ガード 6 本 + 節スキップ 1 本）のイディオムを除去する**
      （R-002 / **R-021 により 3 本 → 7 本へ拡大**。**構造が 2 種類ある**ので扱いを分ける。
      詳細は前掲 `#### 7 本は同質ではない`）。
      **置換対象の特定は `grep -rn 'return 0 2>/dev/null' tests/extras/` を起点にする**
      （`exit 0` 起点では `|| true` 型を取りこぼす / R-021）:
      - **ファイル全体ガード 6 本 → `pg_extra_contract_skip` 経由の rc=3**:
        `ta-39-eh3-doc-light` / `ta-43-eh2-strict-json` / `ta-44-eh457-cli-wiring`
        （ここまで `|| exit 0` 型。`ta-39` は裸の `exit 0` も併せて除去）+
        `ta-45-c3-mode-config` / `ta-46-ehs-wiring` / `ta-47-ehs23-wiring`（`|| true` 型）
      - **節スキップ 1 本 → `pg_extra_contract_skip` を使わない**:
        **`ta-49-bias-export`**（`|| true` 型）。**層 A の TC-01 / TC-02 / TC-04 / TC-06 が
        ガード到達前に実走・集計済み**のため rc=3（＝検査していない）は誤表明になり、
        層 A が fail した場合は **precedence が rc=1 を要求する**。
        イディオムだけ除去してフラグを立て、**末尾 finalize へ落として先行 TC の結果に
        従わせる**（期待 rc = 0 または 1 + SKIP 診断）
      **7 本とも層 A であり本 Slice の対象**（ファイル集合は不変なので Mode 判定に影響しない）。
      **`ta-31` の 4 箇所は分岐内（`mktemp` 失敗時）かつ harness-only 想定＝層 B のため対象外**
- [ ] **移行後、`grep -rn 'return 0 2>/dev/null' tests/extras/` が層 A について 0 件になることを
      確認する**（R-021 の恒久ガード。Global Constraints の禁止事項の実測点）
- [ ] **移行前に `ta-43` の SKIP 分岐で `fail>0` かつ rc=0 になる現状を実測記録する**
      （MN-1 / AC-1 の実害の一次証跡。変異注入に依らない実証）。
      手順: 前掲 `#### TC-17 / M-10 の sandbox 構成手順` で `_T43_APPLIED=0` 分岐へ入る sandbox を
      構成し、さらに apply-script の dry-run 出力が期待差分を含まない状態にして `t43_fail` を
      発火させ、rc が **0** であることと **stderr** に `[FAIL]` が出ていることを同時に記録する。
      **`t43_fail` は `printf '  [FAIL] %s\n' "$1" >&2` で stderr へ出す**（実測: `ta-43` の
      `t43_fail` 定義。`ta-44` の `t44_fail` / `ta-39` の `t39_fail` も同一形）ため、
      **stdout だけを捕捉すると受入条件が充足不能になる**。記録コマンドは stderr を
      必ず合流させる:
      `sh tests/extras/ta-43-eh2-strict-json.sh </dev/null > <log> 2>&1` を実行し、
      直後に `rc=$?` を同じ log へ追記する（rc と `[FAIL]` を 1 つの証跡に揃える）。
      evidence: `evidence/verification/pre-migration-fail-swallow.log`
- [ ] helper が出力する summary 書式は `TA-<NN> standalone: N passed, M failed` に固定する
      （R-015a。`ta-26`（層 0 / Slice 2）の TC-13 が将来この literal を grep するため、
      **helper 側の書式は Slice 1 の時点で確定させておく**）

**rollback**: batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
**helper 導入前まで戻す場合は Task 3 の revert が前提**。revert 順序は T-05 → T-03。

### Task 6: Add inventory + dynamic regression test

**Purpose**: future file追加時の契約漏れを自動検出。

- [ ] **検査対象は移行済み集合＝移行期間 allowlist（contract TA 本体に内蔵した
      `_pending_migration`）が返さないファイル**（Slice 1 は層 A 12 本）。allowlist は
      **base commit 時点の未移行ファイルを列挙した明示リスト**であり、**述語で解決しない**
      （述語にすると marker/init を持たない新規追加ファイルが黙って除外され
      TC-16 / M-06 が空振りする / MJ-E）。内容は Task 1 の runtime inventory から生成した
      結果を **contract TA の heredoc へ転記**し、移行のたびに行を削除する。
      **Slice 2 完了時に 0 行**になり `_pending_migration` 関数ごと削除する（TC-24 / AC-5）
- [ ] **`_pending_migration` の各行の健全性を検査する**（TC-25 / MN-E）:
      各行が `tests/extras/` に**実在**し、かつ helper bootstrap / init を**持たない**こと。
      あわせて次の 3 点を assert し、allowlist 過大化による 0 件ループの黙認 PASS を塞ぐ:
      **① 検査対象集合（discovered − pending）から contract TA 自身を除いた集合が非空**
      （**自己を除外しない非空判定は恒真で発火しない** — contract TA は inventory に含み
      allowlist には載せないため / MJ-I）**② `pending ⊊ discovered`（真部分集合。等しければ FAIL）**
      **③ TC-12 / TC-13 を駆動する per-file 実走ループ（段 1 の分類実行）が 1 件以上を実際に
      実行した**（期待件数は置かず「0 でない」のみ）。件数は**ループ進入時ではなく、
      ループ本体のフィルタを通過して段 1 の実行（`sh "$file" </dev/null` の 1 回）を
      開始した時点**で数える（ループ進入時に数えると、ループ本体の先頭でフィルタして
      全件 `continue` する実装が非 0 のまま通ってしまう）。
      **前提未充足（rc=3）に落ちる分も計数に含める**
      （前提充足クラスに落ちた数で数えると、「全件の前提が未充足」という TC-17 が rc=3 で
      正しく扱う正当な状態を確定 FAIL にしてしまうため）
- [ ] **contract TA 自身（`ta-XX-extra-contract.sh`）の集合帰属**:
      **inventory（runtime discovery）には含める / allowlist には載せない /
      marker・init 検査の対象に含める**（＝自身も `standalone-capable` marker と init を持つ）。
      **自己再帰の回避は「集合から外す」ことではなく、per-file の実走ループで
      自分の test-id を skip する**ことで行う（marker/init 検査は自身にも掛ける）
- [ ] 対象 ta file が exactly one marker
- [ ] markerとinit capability一致（**basename ベースの test-id** / R-016）
- [ ] **全 `ta-*.sh` の test-id が一意**（R-016 / TC-20。**移行状態に依存しないため
      allowlist の対象外で runtime discovery した全件を検査**）
- [ ] harness-only全件standalone rc2（TC-11）。**ループ自体は Slice 1 から回す**
      （Slice 1 時点の実 harness-only は 0 本なので **vacuous PASS**。ただし Slice 1 中に
      harness-only marker + init を持つファイルが追加されたら即座に捕捉できる / INFO-1）。
      **対象 0 件の PASS は evidence に「対象 0 件」と明示記録する**（空振りを PASS と
      区別できないまま通さない）。**実効的な全件充足（AC-3）は Slice 2**
- [ ] standalone-capable: **段 1 で probe なし 1 回実行して前提充足 / 未充足へ分類**し、
      **前提充足クラスのみ** (a) probe なし rc0 / (b) probe あり rc1 の両方を要求する（裁定 ②）。
      **前提未充足クラスは rc3 を TC-17 で assert する**（rc0 を要求しない）。
      分類不能な rc（1 / 2 / その他）は fail-closed で即 FAIL（MN-4 の 2 段構成）
- [ ] normal standalone-capable: **prerequisite 充足時 rc0、prerequisite 未充足時 rc3**
      （unexpected `[FAIL]` 不可）（R-002）
- [ ] **TC-17 / M-10 を前掲 `#### TC-17 / M-10 の sandbox 構成手順` に従って Slice 1 で実走する**
      （Slice 2 へ繰り延べない / Human 決定 5）。repo コピー → 述語文字列除去 →
      コピー側 `ta-*.sh` の standalone 実行。**`FIXTURES_DIR` によるルート差し替えは使えない**
      ため実コピーが必須。**destructive な操作は `mktemp` fixture 内のみ**で行い repo 本体を
      書き換えない。evidence: `evidence/test-runs/prereq-rc3.log`
- [ ] harness full suite完走。**`ls tests/extras/ta-*.sh | tail -1` で runtime に決定した
      最終ファイルの `[PASS]` が harness ログに現れることを assert**（**ファイル名を
      ハードコードしない** / R-006）
- [ ] **README が rc 0/1/2/3 の意味と capability marker 規約を含むことを grep 検査**（R-009 / TC-19）
- [ ] **marker 検出は前掲 `#### marker 検出の正規表現仕様` の ERE / 先頭 20 行限定で実装する**
      （R-027 / M-17）
- [ ] **per-file 実走ループに timeout を掛ける**（R-026）:
      - **per-file timeout は最低 180s**（`ta-26` の standalone 実測が **54〜58 秒**であり
        60s では偽 FAIL する。ファイル内コメントの「約 13 秒」は drift しており信用しない）
      - **実装手段は両環境で動く形にする**。`command -v timeout` があれば `timeout(1)`、
        無ければ `perl -e 'alarm shift; exec @ARGV'` 等へフォールバックする。
        **`timeout(1)` は CI（ubuntu-latest / coreutils）には存在するが macOS 開発機には
        存在しない**（本反映時に `command -v timeout` = exit 1 を実測）。
        **CI だけで検証すると macOS 開発機で動かない実装が通る**ため、
        手段の選択理由を実装時に status へ残す
      - **timeout 発火は SKIP ではなく FAIL** とする（SKIP にすると本 PBI が塞ごうとしている
        「静かに通る」クラスを新設することになる）
- [ ] **contract TA の discovery 集合が runner の source 集合と一致することを assert**（R-035 / TC-28）。
      両者が**同じ glob 定義を参照する構造**にするのが最も安価。片方の glob だけが変わると
      contract TA が「全件検査した」と言いながら runner が source する一部を見ていない状態になる
      （本 PBI が塞ごうとしている空振りと同型）。
      関連: `ta-40` は `FIXTURES_DIR:-` を参照しないため `ta-26` TC-33 の網に**そもそも掛からない**
      （`ta-40` の層 A 帰属は R-003 で反映済みだが、TC-33 側の網羅性は別問題）
- [ ] **TC-16 は実 `tests/extras/` へ書き込まず sandbox で行う**（R-028）。
      `#### TC-17 / M-10 の sandbox 構成手順` と同じ repo 実コピー構成を流用する。
      `tests/run-tests.sh` は**無条件に全 `ta-*.sh` を source** するため、実ディレクトリへ
      `ta-zz-probe.sh` を作る方式は中断時の残留が以後すべての run を汚染する
- [ ] **TC-17 / TC-29 を dash と bash の双方で実走する**（R-021）。
      `|| true` 型 4 本の skip guard がシェルによって逆の挙動を示すため、片方だけでは
      検証にならない。**`dash` が解決できない場合は SKIP せず FAIL とする**
      （R-026 の「timeout 発火は SKIP でなく FAIL」と対称。片シェルだけ回して PASS すると
      本 PBI が塞ごうとしている「静かに通る」クラスの再生産になる / F6）。
      **実際に走らせたシェルを evidence に記録する**
- [ ] contract test自身の再帰をmarker/IDで回避

**rollback**: contract TA ファイルの追加 commit を `git revert <sha>`。
検査基盤のみなので単独 revert 可（ただし revert すると回帰検出力を失う）。
**helper 導入前まで戻す場合は Task 3 の revert が前提**（contract TA も helper API
（`pg_extra_contract_init` / `pg_extra_contract_skip` / probe env）を参照するため、
helper だけ先に revert すると contract TA が解決不能になる）。
revert 順序は **T-06 → T-03**（C-1 MN-3）。

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
- [ ] **`return 0 2>/dev/null || …` を型を問わず使わない**ことを新規ファイル checklist に明記し、
      **skip 経路は `pg_extra_contract_skip` を経由する**と書く（R-021）。
      **2 型のシェル依存（dash は終了 / bash は継続）**を理由として併記する
- [ ] **`_extra-contract.sh` を対話シェルへ source しない**ことを明記（R-033-3）。
      standalone finalize の `exit` が**ユーザのシェルを落とす**
- [ ] **`ta-` プレフィクスを持つファイルのみが test として収集される**ことを新規ファイル規約に
      明記する（R-032 の残余の任意項目。runner のコメントと実 glob の不一致自体は
      `516e2f7` / PR #1017 で解消済みのため、README 側の 1 行追記のみ）
- [ ] 案 D（末尾 explicit finalize）であること、**trap を張らないため README 規約 1–2 に
      例外を作らない**ことを明記
- [ ] **`TASK-0914/handoff.md` §3 の 2 行を append-only で CLOSED マーク**（R-008 / Slice 2）

**rollback**: docs commit を `git revert <sha>`。実装への依存なし（単独 revert 可）。

### Task 8: Final verification

- [ ] `sh -n` 全件
- [ ] **contract TA を含むフルスイート 1 回 + contract TA 単独 2 回**（R-017 の CI 時間裁定。
      「full suite 3 runs」からの読み替え。副作用の受容根拠は `### CI 実行時間の裁定` 参照）
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
| Harness-only（**Slice 1 から実行 / 実効は Slice 2**） | loop direct execution `</dev/null` | all rc2 + message。**Slice 1 は対象 0 件の vacuous PASS で可。その場合は log に「対象 0 件」を明示記録する** | `evidence/test-runs/harness-only.log` |
| Prerequisite 分類（段 1 / MN-4） | 対象 standalone-capable を probe なしで 1 回実行し rc で分類 | rc0 = 前提充足クラス / rc3 = 前提未充足クラス / **それ以外は分類不能 = FAIL** | `evidence/test-runs/prereq-classification.log` |
| Standalone forced fail | probe loop（target 一致）。**前提充足クラスのみ** | all rc1 | `evidence/test-runs/standalone-force-fail.log` |
| Standalone probe absent | probe なしループ | **前提充足クラス = rc0**（(b) との差分要求はこのクラスで取る）/ **前提未充足クラス = rc3**（下段 Prerequisite SKIP 行が assert）。**全件一律 rc0 を要求しない** | `evidence/test-runs/standalone-normal.log` |
| Probe fail-closed | `PG_EXTRA_CONTRACT_PROBE=force-fail` かつ TARGET 未設定 | 診断 + 非ゼロ rc（no-op でない） | `evidence/test-runs/probe-fail-closed.log` |
| Prerequisite SKIP（TC-17 / M-10 / **Slice 1**） | `ta-39` / `ta-43` / `ta-44` を前掲 `#### TC-17 / M-10 の sandbox 構成手順`（repo コピー → 述語文字列除去 → コピー側 standalone 実行）で前提未充足にして実行。`> <log> 2>&1` で stderr を合流 | **rc3**（rc0 でないこと）+ **`pg_extra_contract_skip` 由来の診断が出ること** | `evidence/test-runs/prereq-rc3.log` |
| **allowlist 健全性（TC-25 / M-14 / MN-E）** | contract TA が `_pending_migration` の各行を検査 | 各行が **実在**する `ta-*.sh` かつ **helper bootstrap / init を持たない**。加えて **① 検査対象集合から contract TA 自身を除いた集合が非空 ② `pending ⊊ discovered` ③ TC-12 / TC-13 を駆動する per-file 実走ループが 1 件以上を実行（**フィルタ通過後、段 1 の実行を開始した時点**で計数。rc=3 に落ちる分も含める）** | `evidence/test-runs/pending-migration-integrity.log` |
| **allowlist 生成（MJ-E / Human 決定 4）** | inventory から生成 → contract TA の heredoc へ転記 → `diff` で照合 | 生成物と転記結果が一致（手書きでない） | `evidence/test-runs/pending-migration-gen.log` |
| **`fail>0` は skip より優先（MN-2）** | `pg_extra_contract_skip` 呼出前に `fail=1` を立てた synthetic fixture を standalone 実行 | **rc1**（rc3 でないこと）+ 既に立っている fail を示す診断 | `evidence/test-runs/skip-with-fail.log` |
| **移行前の fail 握り潰しの実測（MN-1 / AC-1 一次証跡）** | 移行前 HEAD で `ta-43` の `_T43_APPLIED=0` 分岐かつ `t43_fail` 発火状態を構成し standalone 実行。**記録は `... </dev/null > <log> 2>&1`** で stderr を合流させる（`t43_fail` は `>&2` へ出すため stdout のみでは捕捉できない） | **rc=0 かつ stderr に `[FAIL]`**（＝失敗が隠れている現状の実証） | `evidence/verification/pre-migration-fail-swallow.log` |
| Harness regression | `sh tests/run-tests.sh` | baseline remeasured at exec start, 0 failed。`ls tests/extras/ta-*.sh \| tail -1` の `[PASS]` がログに出現 | `evidence/test-runs/full-suite.log` |
| **Pre-fix FAIL 実証（AC-7 / R-011）** | **helper 導入前の HEAD に contract TA だけを載せて実行** | **contract TA が FAIL する**（修正前実装で検出力があることの実証。Mutation Matrix は修正後 helper への変異であり別物） | `evidence/mutations/pre-fix-head.log` |
| TC-33 差し替えの検出力（AC-8 / R-013 / **Slice 2**） | helper の unset 集合から 1 env を削る変異（M-09） | 差し替え後の TC-33 相当が FAIL（空振りしない） | `evidence/mutations/tc33-substitute.log` |
| Helper mutation | remove fail branch / finalize call / target check in temp copy | contract tests FAIL | `evidence/mutations/` |
| **早期脱出の 2 型 / dual-shell（TC-29 / M-15 / R-021）** | 早期脱出 7 本を **dash と bash の双方**で standalone 実走 | **両シェルで rc が同一**であること。期待値は構造で分かれる: **ファイル全体ガード 6 本 = rc3**（前提未充足時。probe あり → rc=1）/ **`ta-49`（節スキップ）= 先行 TC の結果（0 or 1）+ SKIP 診断**（rc3 を要求しない）。**変異（skip guard を `\|\| true` 型へ戻す）で dash は rc=0、bash は本体が走る、の両方が FAIL として現れる**。**`dash` 不在は SKIP でなく FAIL**（F6） | `evidence/test-runs/dual-shell-skip.log` |
| **早期脱出イディオムの残存 0（R-021）** | `grep -rn 'return 0 2>/dev/null' tests/extras/` | 層 A（Slice 1 の移行対象）について **0 件**。`ta-31` の分岐内 4 箇所は層 B のため Slice 1 の対象外（Slice 2 で解消） | `evidence/verification/early-exit-idiom.log` |
| **source 経路の非 0 return（TC-26 / M-16 / R-024）** | `fail>0` の standalone-capable 相当を含む合成 harness を source して完走させる | **後続ファイルのマーカー行と `Results:` 行が両方出る**（途中打ち切りしない） | `evidence/test-runs/harness-nonzero-return.log` |
| **`sh -n` 独立 TC（TC-27 / R-029-3）** | `sh -n` を contract TA の独立 case として実行 | 全件 syntax OK。構文破壊は **rc=2（harness-only 誤用）と区別して報告される** | `evidence/test-runs/syntax-case.log` |
| **discovery 集合 == runner の source 集合（TC-28 / M-19 / R-035）** | contract TA の discovery 結果と `tests/run-tests.sh` の extras loop が source する集合を突合 | 両集合が**一致**。片方の glob を変える変異で FAIL | `evidence/test-runs/discovery-parity.log` |
| **per-file timeout（R-026）** | 実走ループに timeout を掛けて計測 | **180s 以上**を採用。`ta-26` 実測 54〜58s を偽 FAIL させない。**timeout 発火は FAIL（SKIP にしない）**。`timeout(1)` 不在環境ではフォールバック実装が動く | `evidence/verification/per-file-timeout.log` |
| **CI 実行時間（R-017 / R-026）** | 反映後のフルスイート計測 | **baseline 231s に対し +250〜280s（2 倍超）を許容する**（裁定は下記）。**`timeout-minutes: 10`（600s）に対する余裕を実測で確認する** | `evidence/verification/ci-duration.log` |

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

#### CI の時間予算と `timeout-minutes`（R-026 / **HO 対象・patch 提示のみ**）

`.github/workflows/test.yml` の当該 job は **`timeout-minutes: 10`（600 秒）**である
（本反映時に実測）。

**時間の軸を 2 つに分けて扱う（前版は両者を混同していた / F7）**:

| 軸 | 影響するもの | matrix 化の影響 |
|---|---|---|
| **per-job wall clock**（`timeout-minutes` が効くのはこちら） | baseline 231 秒 + contract TA の増加分 +250〜280 秒 ＝ 約 **480〜510 秒**。加えて **per-file 180 秒 timeout が発火した場合の最悪ケース** | **増えない**。`strategy.matrix` は**独立した job へ展開**され、`timeout-minutes` は **job 単位**に適用されるため、dash / bash は並列の別 job になる |
| **総 CI 分（課金・キュー）** | 上記 × job 数 | **2 倍になる**（dash + bash） |

したがって **`timeout-minutes` 引き上げの根拠は「480〜510 秒 + per-file timeout の
最悪ケース」のみ**であり、**matrix 化は根拠にならない**。
per-file 180 秒も**上限であって加算値ではない**（正常時は `ta-26` の 54〜58 秒で完了する）。

**`.github/workflows/**` は [`mode-classification.md`](../../../.claude/rules/mode-classification.md)
の Hardening Override 対象パスであるため、AI は適用せず patch 提示に留める**。
採否と適用は Human-owned（`## Human C-3 の判断事項` に patch を掲載）。

- **本 PBI の Slice 1 で `.github/workflows/**` を変更しない**方針は維持する
  （変更すると Mode 判定の「HO 対象パスに 1 件も該当しない」根拠が崩れ、
  Slice 1 = high-risk の前提が変わる）
- **exec 中に CI が timeout で落ちた場合は Stop Condition** とし、Human へ
  `timeout-minutes` の引き上げ patch の適用を依頼する

#### 緩和の副作用と、それを受容する裁定根拠（C-1 MN-6）

上記の読み替えにより、**harness（source）経路のサンプル数は 3 → 1 に落ちる**。
本 PBI の最重大リスク **R-1（source 経路への `exit` 漏れで `run-tests.sh` が途中終了し、
少ない件数で 0 failed を返す）は harness 経路でしか観測できない**ため、この低下は
リスク最大の観測点を薄くする方向に効く。受容する根拠を明示しておく:

1. **R-1 は決定論的欠陥である**。source された extras が `exit` すれば `run-tests.sh` は
   **毎回同じ位置で必ず途中終了**する。確率的に現れる欠陥ではないため、
   検出に反復は不要であり **1 回のフルスイートで観測できる**
2. **1 回でも検出力が落ちないよう検査を強化してある**。TC-14 は「0 failed」だけでなく
   **`ls tests/extras/ta-*.sh | tail -1` で runtime に決めた最終ファイルの `[PASS]` が
   ログに出現すること**を assert する。途中終了は件数ではなく**到達点**で検出されるため、
   反復回数に依存しない
3. **「3 連続」が本来守っていたのは別クラスの欠陥**である。すなわち tmp path 衝突・
   実行順依存・タイミング由来の **flaky**（試行ごとに結果が変わる非決定論）であり、
   これは R-1 とは別物。この帯は **contract TA 単独 2 回**（全 standalone-capable を
   実走し tmp 生成・cleanup を繰り返す最も flaky が出やすい経路）で引き続き 3 サンプル
   相当を確保する
4. **不足が判明した場合の戻し**: フルスイートで flaky が 1 件でも観測されたら、
   本緩和を撤回して「フルスイート 3 連続」へ戻す（Replan Trigger）

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
**未移行 45 本は contract TA 本体に内蔵した移行期間 allowlist（`_pending_migration`）に列挙して
contract TA の対象外とする**（恒久化しない。**新規追加ファイルは allowlist に無いため検査対象に入る**）。
**Slice 1 の DoD は [`test-cases.md`](./test-cases.md) の `## Exit Criteria` の Slice 1 節を正本とする**。

**Slice 2**（後続）: 層 B + 層 C 41 本の harness-only 化、**層 0 の 4 本の helper 吸収**
（`ta-26` TC-33 差し替え = AC-8 を含む）、`TASK-0914/handoff.md` writeback、
**移行期間 allowlist の解消**。着手時に Mode を再判定する。

#### Slice 2 着手時の判断材料（R-037 / info。本 PBI では裁定しない）

別系統 C-2 の maintainability レーンが出した 3 提案を、**Slice 2 の設計判断材料として記録**する
（Slice 1 の設計は変更しない）。

1. **batch 基準を risk 分布で切る**: 「10〜15 files/batch」はファイル数基準であり、
   別系統の risk 分布（high 1 / medium 9 / low 47）と無関係。**ハザードはファイル数でなく
   個別に偏在している**ため、batch を risk 単位で切るほうが安全。Slice 1 は Human 決定 3 で
   層 A 12 本に確定済みのため、**Slice 2 の分割設計への提案**として残す
2. **bootstrap の縮小（7 行 → 2 行）**: runner の extras loop に `PG_EXTRA_FILE="$extra"` の
   1 行を足し、bootstrap を `EXTRAS_DIR` アンカー + marker 単一正本にすると
   **「marker と init の不一致」という故障クラス自体が消える**。
   `git diff -U0 | grep '^+' | sort -u` が少数行に収束するためレビュー量が **O(41) → O(1)** になる。
   ただし **runner 変更を増やす方向であり R-010（runner 変更を落とせるか）と正面から競合する**
3. **`ta-26` は legacy adapter のまま残す案**: `ta-26` は既に `fail>0 → exit 1` が成立して
   いるため、helper へ移行しても **#921 への behavioral gain がゼロ**。さらに移行すると
   TC-13 が「helper の出力フォーマット検証」に変質し、**規約を取り締まる側（TC-33 / TC-13）が
   取り締まられる機構（helper）に依存する循環**が生じる。Slice 2 の選択肢として保持する
   （**採用すると AC-8 / TC-22 / M-09 の扱いが変わる**ため、Slice 2 の Mode 再判定と同時に裁定する）

個別test内容、framework刷新、README一覧修正、CI 実行時間の最適化は含まない。

### Security / Operational Risk

- harness source中のexitは全suiteを短絡するためcritical
- broad file migrationでmerge conflictが高い。exec開始時に他branchがtests/extrasを変更していたら停止
- cleanup誤削除、stdin hangを負側で検証
- probeはfail-safeでありsuccess bypassを持たない。ただし **TARGET 未設定は fail-closed**
- **probe env の子プロセス伝播による masking**（`ta-26` 自己再帰）を再帰ガードで遮断
- **移行 PR 生存中に marker 無しの新規 `ta-NN` が着地するリスク（R-036 / info）**:
  `tests/extras/` の追加ペース実測は 2026-05 = 21 本 / 06 = 26 本 / 07 = 8 本 /
  08（5 日時点）= 3 本。**本反映時（2026-08-10）に再測定した結果、リポジトリの
  open PR は 0 件**（`gh pr list --state open` が空）であり、競合の直接リスクは現時点で無い。
  **運用目標として移行 PR は 7 日以内に merge する**。
  仮に marker 無しの新規ファイルが着地しても、`_pending_migration`（base commit 時点の
  明示リスト）に**載っていない**ため **TC-09 / TC-10 が FAIL する ＝ 検出はされる**
  （silent leak にはならない）。是正コストのみの問題である

## Replan Triggers

- helper sourceのためrunner集計契約変更が必要
- standalone-capableの正常実行が外部service/credentialを要求する
- capability分類が2値で表現できない第四カテゴリを必要とする（rc 3 は capability ではなく
  実行時状態なので 2 値分類は維持される）
- migration対象fileがplan時inventoryから増減し、未分類が生じる
- full suite baselineがmainで既に赤
- ta-26 cleanup behavior / summary 書式をhelperで等価にできない
- **フルスイートで flaky が 1 件でも観測された**（CI 時間裁定の「フルスイート 1 回」への
  緩和を撤回し「フルスイート 3 連続」へ戻す / C-1 MN-6）
- **層 A の中に、段 1 の分類で rc 0 / 3 のいずれでもない値を返すファイルがある**
  （前提充足の判別が 2 値で表現できない / MN-4）
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
- **Slice 1 の exec 中に層 0（`ta-26` / `ta-58` / `ta-59` / `ta-60`）へ触る必要が生じた場合**
  （Slice 1 = 15 ファイル / high-risk 判定の前提が崩れる。Mode 再判定 → 人間へエスカレーション）
- **`ta-26` TC-33 の差し替え設計が未確定のまま Slice 2 の層 0 移行へ入ろうとした場合**（R-013 / AC-8）
- **`## Human C-3 の判断事項`（HJ-1〜HJ-5）のいずれかが未確定のまま exec へ入ろうとした場合**
  （とくに **HJ-4 = `original rc` の捕捉規約**は Task 5 の置換テンプレートと README 規約を
  決めるため、未確定のまま移行に入ると後戻りが発生する / R-030）
- **CI が `timeout-minutes: 10` の超過で落ちた場合**（R-026）。
  `.github/workflows/**` は HO 対象のため AI は適用せず、Human へ patch 適用を依頼する
- **`|| true` 型の早期脱出が dash / bash で異なる rc を返す状態のまま Task 6 の
  Verification に入ろうとした場合**（R-021 / issue #1026）

## Human C-3 の判断事項（R-021〜R-037 の反映で AI が確定しなかった項目）

> 別系統 C-2（4 レーン）の指摘のうち、**AI が裁定してはならない / 適用してはならない**ものを
> 本節に集約する。**C-3 でこれらを確定してから exec に入る**。

### HJ-1 CI の `sh` 実体を固定するか（R-022 / major / **HO 対象・patch 提示のみ**）

- **問題**: `.github/workflows/test.yml` は `runs-on: ubuntu-latest` + `run: sh tests/run-tests.sh`
  であり **shell 実体を固定していない**。ubuntu-latest では dash、macOS 開発機では bash になり、
  R-021 のとおり `return` のセマンティクスが分岐する。「どちらか一方でしか検証していない」状態が
  構造的に発生し、本 PBI が導入する契約（rc 0/1/2/3）そのものが環境で意味を変える
- **選択肢**:
  - **(a) CI を dash 明示**（`run: dash tests/run-tests.sh` 相当）
  - **(b) dash + bash の matrix 実行**（別系統 Lane 1 の推奨。(a) 単独では macOS 開発機での
    素通りを検出できないままになる）
- **責務分界**: `.github/workflows/**` は **Hardening Override 対象パス**である。
  **AI は適用しない**。以下は patch 案の提示であり、適用は Human-owned

  ```diff
  # 案 (b): dash + bash の matrix（適用は Human-owned）
   jobs:
     plangate-cli:
  -    name: plangate CLI tests
  +    name: plangate CLI tests (${{ matrix.shell }})
       runs-on: ubuntu-latest
  -    timeout-minutes: 10
  +    timeout-minutes: 20
  +    strategy:
  +      fail-fast: false
  +      matrix:
  +        shell: [dash, bash]
       steps:
         # ...
         - name: Run CLI tests
  -        run: sh tests/run-tests.sh
  +        run: ${{ matrix.shell }} tests/run-tests.sh
  ```

- **適用前の前提条件（Human 向け / 確度 medium）**: **required status checks の設定を確認すること**。
  matrix 化すると check context 名が `plangate CLI tests` から
  **`plangate CLI tests (dash)` / `plangate CLI tests (bash)`** へ変わる。
  旧名が required に設定されている場合、**適用直後に全 PR が「待機中の required check」で
  ブロックされる**。ruleset / branch protection 側の required check 名の更新を
  同時に行う必要がある（**この点は未実測のため確度 medium** — 適用前に設定画面で確認されたい）
- **`timeout-minutes: 20` の根拠**: **per-job wall clock のみ**（480〜510 秒 +
  per-file 180 秒 timeout が発火した場合の余裕）。**matrix 化は per-job wall clock を
  増やさない**（別 job へ並列展開されるため）。増えるのは**総 CI 分**であり、
  それは `timeout-minutes` の対象ではない（前掲の 2 軸表）
- **未確定事項**: per-file timeout が実際に発火したときの最悪 wall clock は
  contract TA 実装後の実測で確定する。20 分は暫定値である
- **本 PBI での扱い**: **Slice 1 では `.github/workflows/**` を変更しない**（HO 非該当が
  Mode = high-risk 判定の根拠の 1 つであるため）。R-022 の適用は Human の別作業とし、
  未適用のままでも Slice 1 の contract TA は **dash と bash の双方でローカル実走する**
  （TC-29）ことで最低限の二重検証を確保する

### HJ-2 層 C の ROOT sentinel を Slice 1 へ前倒しするか（R-023 / minor）

- **既に裁定済みの部分**: 層 C（空振り PASS）の論点そのものは
  **`pbi-input.md` の層 C 定義 + D-2 (c) + 本 plan の In Scope「D-2 = (c) 採用」+ 系統 A `R-007`**
  で裁定済みであり、層 C 5 本は **Slice 2 で harness-only 化（exit 2）** される
- **残る新規要素は 1 点のみ**: 層 C の空振りを Slice 2 まで待たず、
  **helper の `pg_extra_contract_init` に ROOT sentinel 検査を持たせて Slice 1 で前倒しに塞ぐか**

  ```sh
  # 前倒しする場合の案（fail-closed）
  [ -x "$ROOT/bin/plangate" ] && [ -d "$ROOT/schemas" ]
  ```

  件数も allowlist も持たないため「件数を契約値にしない」制約に抵触せず、
  ROOT が `//` へ解決した場合も `tests/` へ解決した場合も落ちる
- **前倒ししても層 C 自体は塞がらない**（Slice 1 の helper は層 A 12 本しか通らない）。
  効果は **将来ファイルが同じ空振りを再生産することを Slice 1 の時点で塞げる**点に限られる
- **判定式の注意（誤検出を作らないため）**: 空振りの正確な定義は
  **「rc=0 かつ `[FAIL]`=0 かつ ROOT 誤解決で assertion が空振り」**であり、
  **`[PASS]` は 0 とは限らない**（実測: `ta-11` は P4 F0 / `ta-32` は P1+WARN1 F0 / `ta-38` は P1 F0）。
  一方 **`[PASS]` 0 かつ `[FAIL]` 0 かつ `[SKIP]` 1 なのは `ta-06` / `ta-08`** であり、
  これらは **README 規約 6 に沿った正当な SKIP** で誤検出してはならない。
  **「PASS 0 件」を判定式に入れると、名指しした 3 本を 1 件も検出できず正当な 2 本だけを
  誤検出する検出器**になる（本 PBI が塞ごうとしている「静かに通る」クラスの再生産）
- **Human 判断**: 前倒しする / Slice 2 の D-2 (c) に委ねる
- **どちらでも変わらないこと**: 層 C 3 本自体の修理は Out of Scope
  （「各 extras のテスト内容・期待値の見直し」）であり、本 PBI では扱わない
- **明示すべき残存リスク（handoff 記載事項）**: D-2 (c) が塞ぐのは **standalone 実行**のみ。
  **harness モードでの層 C の空振り PASS は本 PBI では一切解消しない**
  （harness では `run-tests.sh` が正しい ROOT を与えるため本来の assertion を実行するが、
  「空振りしていないこと」を機械保証する仕組みは本 PBI に無い）

### HJ-3 `timeout-minutes` の再見積り（R-026 / **HO 対象・patch 提示のみ**）

前掲 `#### CI の時間予算と timeout-minutes` を参照。HJ-1 の patch に含めて適用するのが自然。

### HJ-4 案 D における `original rc` の捕捉規約（R-030 / major）

前掲 `#### original rc の捕捉規約は未確定` を参照。**(a) 2 値化** と **(b) 保持 + 規約化** の
いずれかを C-3 で確定する。(a) を採る場合は **TC-06 の削除または再定義**を伴うため、
受入基準側（補助的な設計制約表）の変更も同時に承認する必要がある。

### HJ-5 AC-2 (c) の対象本数を正本（`pbi-input.md`）へ反映するか（F3）

- **問題**: R-021 の実測により、AC-2 (c) が扱う早期脱出は **`ta-39` / `ta-43` / `ta-44` の
  3 本ではなく 7 本**（rc=3 の対象は**ファイル全体ガード 6 本**、`ta-49` は**節スキップ**）
  であることが判明した。しかし **AC-1〜AC-7 の正本は `pbi-input.md` の受入基準節**であり、
  そこは現在も **3 本**のままである
- **AI が確定しなかった理由**: `test-cases.md` の Traceability は自ら
  「**AC-1〜AC-7 は `pbi-input.md` を正本とし、本表は写像のみ**」と宣言している。
  本表の中で対象範囲を 7 本へ広げることは、**本来 Human が決めるべき AC の変更を
  AI が黙って確定する**ことに等しい。**H-05（AC-8 を pbi-input へ追記するか否かの裁定）と
  同型の扱い**とし、本項として提示するに留めた
- **Human 判断**: `pbi-input.md` の AC-2 (c)（および層 A の内訳記述）を
  **7 本 / 6+1 構造へ更新するか**、それとも **AC は 3 本のまま据え置き、残る 4 本は
  AC-1（standalone で exit 0 を返すものが 0 件）で回収する**か
- **本反映での扱い（正直に記す）**: **`pbi-input.md` は編集していない**。
  したがって **`pbi-input.md` の「層 A の 3 本」という記述は HJ-5 の裁定まで stale** であり、
  本 plan が層 A の一覧について pbi-input を参照する箇所から辿ると **3 と 7 が食い違う**。
  これは**既知の未確定点として明示するもの**であり、AI が正本を書き換えて解消することはしない
- **実装上の対象定義**: 裁定が済むまで、TC-17 / TC-29 / Task 5 は前掲
  `#### 7 本は同質ではない` を対象定義として用いる（AC の文言とは独立に、
  **実装対象は 7 本で確定している**）

## Human Approval Boundary

- **案 D（末尾 explicit finalize）への replan の承認**（案 C 不採用）
- **共有ファイル `tests/extras/_extra-contract.sh` の導入 = #914 §4 で棄却された E-1 の
  意図的反転の承認**（前掲「先行決定の反転」節の根拠に対する判断）
- **スライス分割（Slice 1 = 15 ファイル / high-risk、Slice 2 = 46 ファイル / 着手時再判定）の承認**。
  **層 0 の 4 本を Slice 2 へ繰り延べる裁定**（Human 決定 3）と、それに伴う
  **Slice 1 の contract TA の移行期間 allowlist（未移行 45 本を列挙した明示リストを
  contract TA 本体の `_pending_migration` に内蔵する形態 / Human 決定 4）の承認**を含む
- `tests/run-tests.sh` helper source変更（Task 3 の比較検証で必要と確定した場合のみ）
- broad extras migrationのC-3
- contract probe envの採否
- **HJ-1〜HJ-5 の裁定**（`## Human C-3 の判断事項`）:
  **HJ-1** CI の `sh` 実体固定（R-022 / **HO 対象・patch 提示のみ**）/
  **HJ-2** 層 C の ROOT sentinel を Slice 1 へ前倒しするか（R-023）/
  **HJ-3** `timeout-minutes` の再見積り（R-026 / **HO 対象・patch 提示のみ**）/
  **HJ-4** 案 D における `original rc` の捕捉規約（R-030。(a) 2 値化なら **TC-06 の再定義**を伴う）/
  **HJ-5** AC-2 (c) の対象本数（3 本 → 7 本）を `pbi-input.md`（正本）へ反映するか（F3）
- PR C-4 / merge

## C-1 Self Review Checklist

- [x] #914完了を反映
- [x] countをハードコードしない
- [x] 層 A / 層 B+C をrc 1/2で区別し、前提未充足を rc 3 で分離
- [x] early exit問題を設計で扱う（案 D + contract TA の動的 probe）
- [x] source経路exit禁止を明示
- [x] negative controls / mutation evidenceを定義
- [x] **broad migrationのrollback/replanを定義**（`todo.md` 全実装タスクに `rollback:` を付与し、
      **T-04 / T-04b / T-05 / T-06 → T-03** の revert 依存順を明記。自己申告と実体の乖離を解消）
- [x] **Mode判定を判定根拠つきで明記**（D-5 裁定 = スライス分割）
- [x] **AC↔TC 写像を test-cases.md の単一正本へ集約**
- [x] **スライス帰属が `ta-*.sh` 全 57 本を過不足なく覆う**（12 + 4 + 36 + 5 = 57。
      層 0 がどのスライスにも属さない漏れを是正）
- [x] **Slice 1 単独 PR の DoD を定義**（`test-cases.md` の Exit Criteria を Slice 別に分離）
- [x] **rc=3 反転を TC-12 / Task 6 / Verification Plan へ伝播**（前提充足クラスのみ rc0 を要求）
- [ ] runtime inventoryをexec開始時に取得
- [x] C-2 independent review（**完了。`review-external.md` R-001〜R-020 を本版で確定反映**）
- [x] 簡易 C-1 再実行（**FAIL: major 3 / minor 6 → 是正済**。
      MJ-A = 層 0 を Slice 2 へ繰り延べ（Human 決定 3）/ MJ-B = rc=3 反転の未伝播 /
      MJ-C = Slice 1 単独 PR の DoD 未定義 / MN-1〜MN-6）
- [x] 簡易 C-1 第 2 ラウンド（**FAIL: major 2 / minor 7 → 本版で全件是正**。
      MJ-E = allowlist 述語が TC-16 と両立せず AC-5 後半条項に違反 → **明示台帳へ変更** /
      MJ-D = allowlist の一般化が TC 本文へ未伝播 → **TC-09〜TC-13 へ scope 節を追加** /
      MN-1 = 早期 `exit 0` は実測 3 件（`ta-39` / `ta-43` / `ta-44`）・うち fail 握り潰しの実例は 2 件（記述を訂正） /
      MN-2 = `fail>0` は prerequisite missing より優先（precedence に行追加） /
      MN-3 = 「全 57 本」を runtime discovery へ置換 + contract TA の集合帰属を明記 /
      MN-4 = TC-02 に synthetic 限定を追記 / MN-5 = 見出しを「未移行 45 本」へ /
      MN-6 = 層 0 の summary 書式 3 系統の消費者確認を T-04b へ追加 /
      MN-7 = `ta-43` への行番号アンカーを記号アンカー（`_T43_APPLIED` 分岐）へ置換。
      本 3 文書に残る行番号アンカーは grep で 0 件）
- [x] **付随是正（第 2 ラウンド指摘外・実測により発見）**: 前版が
      「`ta-43` は `check-plan-hash.sh` に `_eh2_stdin` が 0 件で前提未充足クラス」と
      記していたが、参照ファイルの取り違えであり実測では `ta-39` / `ta-43` / `ta-44` とも
      base commit で rc=0（前提充足）。plan / test-cases の該当記述を訂正した
      （2 段構成そのものは維持。理由は「前提は環境依存で反転しうる」へ差し替え）
- [x] 簡易 C-1 第 3 ラウンド（**FAIL: major 3 / minor 5 → 本版で全件是正**）:
      **MJ-F**（恒久テストが `docs/working/` の台帳を実行時に読む依存 + 台帳不在時の
      fail-closed 未明文化）と **MJ-G**（台帳の不在・読取不能・不正という異常系が未定義）は
      **Human 決定 4 により allowlist を contract TA 本体（`_pending_migration`）へ内蔵**して
      同時解消（別ファイルを作らないため Slice 1 = 15 ファイル / high-risk も維持）/
      **MJ-H = TC-17 / M-10 の sandbox 構成手順が未定義** → `#### TC-17 / M-10 の sandbox 構成手順`
      を追記し **Slice 1 の必須ゲートとして維持**（Human 決定 5）/
      MN-A = TC-16 の検出根拠を「TC-09 / TC-10（case A/B）+ TC-12 の probe 差分（case C / M-07）」へ訂正 /
      MN-B = `[FAIL]` は **stderr** 出力のため記録コマンドへ `2>&1` を追加（`ta-39` / `ta-44` も同形と実測）/
      MN-C = test-cases.md の共有 scope ブロックを英語へ一本化し、字面一致対象を plan（日本語）↔ todo（日本語）に限定 /
      MN-D = 台帳ファイル不在の区別 → **内蔵化により消滅**（`_pending_migration` 専用ガードの
      要否は「関数の存在」ではなく「検査が空振りしていないか」で判断し、TC-25 の
      非空 assert に置換）/ MN-E = **逆向きリーク**（移行済みファイルが allowlist に残存）を
      **TC-25 / M-14** で Slice 1 から検出 / MN-F = `review-self.md` の `## Verdict` 節冒頭行
      （`#914 完了後のscope…`）の MD018 を解消（`#914` をコード表記にして ATX 見出し誤認を除去）
- [x] 簡易 C-1 第 4 ラウンド（**FAIL: major 2 / minor 3 / info 2 → 本版で全件是正**）:
      **MJ-I = TC-25 の非空 assert が恒真で発火不能**（contract TA 自身は inventory に含み
      allowlist に載せないため covered set は常に非空。allowlist 過大化時に TC-12 / TC-13 が
      0 件ループ、TC-09 / TC-10 が自分 1 件だけで PASS し TC-25 も PASS する＝本 PBI が塞ごうと
      している欠陥そのもの）→ **① 自己を除いた covered set が非空 ② `pending ⊊ discovered`
      ③ TC-12 / TC-13 の実走件数が 0 でない**の 3 assert へ差し替え（件数は契約値にしない）/
      **MJ-J = `review-self.md` が C-3 入力として stale**（案 C 前提・C-2 BLOCKED・trap 監査必須の
      いずれも現状と不一致で、読むと C-2 未実施と誤認する）→ Verdict / Review Matrix /
      C-3 Readiness を実態へ同期し、**C-1 ラウンド履歴表**を追加 /
      MN-G = TC-17 sandbox の `git archive HEAD` は **commit 済みツリー**を出力するため
      作業ツリーの移行が反映されず TDD ループで RED/GREEN が回らない（逆向きに退行も見逃す）→
      **追跡ファイルの作業ツリーコピー**（`git ls-files -z | tar --null -T -`）へ変更し、
      **git 不在時は SKIP せず rc=1 で fail-closed** と明記 /
      MN-H = M-14 (c)「heredoc 終端破損」は**実測で再現しない**（`}` ごと飲み込み
      parse error rc=2。TC-25 は実行すらされない）→ **構文的に妥当な「inventory 全件出力」変異**へ
      差し替え、「構文破損の rc=2 は harness-only 誤用と区別できない」を既知の限界として記録 /
      MN-I = 主張していた plan ↔ todo の**字面一致が実際には不成立**（`述語にすると` vs
      `述語だと` / plan 側だけ転記文あり）→ **両ブロックを実際に一致させ**、一致の判定方法
      （リストマーカー・インデント・改行・空白を正規化して byte 一致）を test-cases に明記 /
      INFO-1 = **TC-11 を Slice 1 でも実行**（Slice 1 の実 harness-only は 0 本＝vacuous だが、
      Slice 1 中に追加された harness-only ファイルの rc=2 拒否を Slice 2 まで待たずに捕捉できる。
      **対象 0 件の PASS は evidence に「対象 0 件」と明示記録**する）/
      INFO-2 = Human 決定 3 / 4 / 5 を `decision-log.jsonl` へ append（`D-0921-06`〜`D-0921-08`。
      mode=high-risk の human decision のため `alternatives_rejected` 必須）
- [x] 簡易 C-1 第 5 ラウンド（**PASS: critical 0 / major 0 / minor 2 / info 3**。
      MN-K = TC-25 の assert ③ の計数点が「ループ進入時」だと、自ら挙げる反例
      （ループ本体先頭のフィルタで全件 `continue`）を捕捉できない → **段 1 の実行を
      開始した時点**へ移動（rc=3 に落ちる分は計数に含める） /
      MN-L = 本チェックリストの C-2 項が「完了」と本文で述べながら未チェックで、
      `review-self.md` の C-3 Readiness と表示が食い違っていた → `[x]` へ /
      INFO-1 = sandbox step 1 に `cd "$(git rev-parse --show-toplevel)"` を追加（cwd 前提の明示）/
      INFO-2 = M-14 (c) の期待値を「①②③ が個別に発火したことを log 出力」へ具体化 /
      INFO-3 = 字面一致の対象が **第 1 項（移行 scope 定義）**であることを test-cases に明記。
      **本ラウンドで解消しない残 minor / info は存在しない**）
- [x] **別系統 C-2（4 レーン）由来 `R-021`〜`R-037` の 1 回確定反映**（本版 / `Refs: R-021`〜`R-037`）:
      **R-021（critical）= `|| true` 型 4 件により案 D の末尾 finalize が CI（dash）で到達しない**
      → `## 前提の実測検証` を「早期脱出は 2 型 7 件」へ是正 + `### 早期脱出の 2 型とシェル依存` を新設
      + Global Constraints にイディオム禁止 + **Task 5 の対象を 3 本 → 7 本** + TC-17 拡張 /
      TC-29 / M-15（追跡 issue **#1026**）/
      **R-024** = source 経路の非 0 `return` 禁止（Global Constraints / finalize は harness で
      常に `return 0` / TC-26 / M-16）/ **R-025** = bootstrap アンカーを `$0` → `EXTRAS_DIR` +
      forward 側の同一 commit 原子性 / **R-026** = per-file timeout ≥180s・両環境で動く実装・
      timeout は FAIL（`timeout-minutes` は HO のため patch 提示のみ）/ **R-027** = marker 検出の
      ERE 仕様化 + 先頭 20 行限定（M-17）/ **R-028** = TC-16 を sandbox 化 + 実 `tests/extras/`
      書込禁止 / **R-029** = probe 合格条件へ一意文字列 AND・TC-11 の id 込み照合・`sh -n` 独立
      TC-27（M-18）/ **R-031** = TC-33 差し替えの等価性（(1) AND (2)）を明示 /
      **R-033** = `local` 禁止 / mode の init 毎回解決 / 対話シェル source 禁止 /
      **R-034** = `seven` の 2 箇所を動的導出へ / **R-035** = discovery 集合 == runner の source
      集合を TC-28（M-19）/ **R-036** = 移行 PR 7 日以内 merge を Risks へ（**本反映時に
      open PR = 0 件を再測定**）/ **R-037** = Slice 2 の判断材料 3 件を記録。
      **未確定として Human C-3 へ回した 4 件は `## Human C-3 の判断事項`（HJ-1 = R-022 /
      HJ-2 = R-023 / HJ-3 = R-026 の `timeout-minutes` / HJ-4 = R-030）**。
      **R-032 は `resolved-by-design`（`516e2f7` / PR #1017）につき反映せず**（README の
      `ta-` プレフィクス規約の 1 行のみ Task 7 へ取り込み）
- [x] **確定反映への独立 river-review（major 3 / minor 4）を是正**（`F1`〜`F7`。同一ブランチ内の追補）:
      **F1 = bootstrap の「診断 + fail カウント + `return 0`」が掲載スニペットでは実装不能**
      （`.` は special built-in であり失敗すると非対話シェルは `||` の中でも即終了。
      **実測: dash rc=2 / bash rc=1 とも診断へ到達しない・`set -e` 非依存**）→
      **source 前の `[ -r "$helper" ]` 可読性プローブへ差し替え**、原因記述も是正 /
      **F2 = `ta-49` は節スキップであり 7 本一律 rc=3 は precedence と矛盾**
      （実測: `ta-49` は層 A の TC-01/02/04/06 がガード前に実走し **カウンタを 8 回更新**。
      他 6 本の一致は `tXX_pass()` / `tXX_fail()` の**関数定義**で実行された加算ではない）→
      **ファイル全体ガード 6 本（rc=3）と節スキップ 1 本（先行 TC の結果に従う）へ分離** /
      **F3 = Traceability が AC-2 (c) の対象を 3 本 → 7 本へ独断拡張**（正本は `pbi-input.md`）→
      **セルを注記参照に戻し `HJ-5` として Human へ委譲**（`pbi-input.md` は編集せず、
      3 と 7 の食い違いを既知の未確定点として明示）/
      F4 = Traceability の AC-7 を `M-01〜M-19` へ追随 /
      **F5 = `EXTRAS_DIR` アンカーが guard 外 env への依存を新設**（実測: runner の unset 7 env に
      `EXTRAS_DIR` / `FIXTURES_DIR` は**含まれない**）→ **mode 判定（`PG_HARNESS_SOURCED` AND
      `FIXTURES_DIR`）で分岐し harness 経路のみ `EXTRAS_DIR` を読む**形へ /
      F6 = **`dash` 不在時は SKIP でなく FAIL**（R-026 の timeout 裁定と対称）を TC-29 へ /
      **F7 = `timeout-minutes` の時間モデルが誤り**（`strategy.matrix` は**独立 job へ展開**され
      `timeout-minutes` は **job 単位**＝matrix は per-job wall clock を増やさない）→
      **per-job wall clock と総 CI 分を分離**し 20 分の根拠を前者のみに置き直し、
      HJ-1 の patch に **check context 名の変更（required status checks の確認）**を追記
- [ ] Human C-3
