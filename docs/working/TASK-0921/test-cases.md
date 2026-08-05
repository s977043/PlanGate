# TEST CASES — TASK-0921

> **C-2 反映済み**（`Refs: R-001`〜`R-020`）。指摘の正本は [`review-external.md`](./review-external.md)。
> 本ファイルの `## Traceability` が **AC↔TC 写像の単一正本**である（R-001）。

## Contract RC Table

| Capability / condition | Expected rc |
|---|---:|
| standalone-capable, all pass | 0 |
| standalone-capable, internal fail > 0 | 1 |
| harness-only, direct invocation | 2 |
| **standalone-capable, prerequisite absent（検査していない）** | **3** |
| standalone-capable, original command exits nonzero | preserve original rc |
| harness source, any individual extras | no process exit; runner decides final rc |

> **rc=3 の意味**（R-002）: 「前提未充足＝検査していない」。**rc=0 は不可**。
> `scripts/apply-eh3-doc-light.sh` が案内する `sh tests/extras/ta-39-eh3-doc-light.sh` は
> 適用失敗時こそ早期 SKIP で rc=0 を返し続ける。これを塞ぐのが本 PBI 最優先の変更。
> **rc=2 は harness-only 誤実行専用**であり、hook の BLOCK（`exit 2`）とは別名前空間（R-020）。
>
> **test-id の定義**（R-016）: test-id は **basename（拡張子なし）**。
> 番号は一意でない（`ta-14` が 2 本実在）。`PG_EXTRA_CONTRACT_TARGET`・診断メッセージ・
> 「for every file」ループはすべて basename ベースで解決する。

## Helper Unit / Synthetic Cases

### TC-01 Harness mode is non-invasive

Given `PG_HARNESS_SOURCED=1` and valid `FIXTURES_DIR`, when init is called, then pass/fail are not reset, no exit trap is installed, **probe env vars are not read**, and helper returns 0.

### TC-02 Harness-only direct misuse

Given no valid harness marker, when a `harness-only` script is invoked, then body sentinel is not created, stderr names the test (basename test-id) and canonical runner, and rc=2.

### TC-03 Standalone pass

Given standalone-capable init and `fail=0`, when the script reaches `pg_extra_contract_finalize`, then cleanup runs, summary is emitted, final rc=0.

### TC-04 Standalone internal fail

Given standalone-capable init and `fail=1`, when the script reaches `pg_extra_contract_finalize`, then final rc=1.

### TC-05 Explicit finalize propagation

Given standalone-capable init and `fail=1`, when the test body takes an alternate path and still calls `pg_extra_contract_finalize` at the tail, then final rc=1. A file that returns without calling finalize must be detected by TC-16 (contract TA), not silently pass.

### TC-06 Preserve specific nonzero rc

Given original rc=3 from the command under test, then final rc remains 3 whether fail is 0 or positive. Generic test failure must not hide a more specific command failure.

### TC-07 Cleanup

Given two registered tmp paths and an unregistered sentinel path, on standalone finalize only registered paths are deleted; sentinel remains.

### TC-08 Invalid capability

Given unknown capability string, helper fails closed before body with nonzero rc and diagnostic.

## Inventory / Dynamic Cases

### TC-09 Exactly one capability marker

For every runtime-discovered `ta-*.sh`, marker count is exactly 1 and value is one of `standalone-capable`, `harness-only`.

### TC-10 Marker and init agree

For every file, marker value and `pg_extra_contract_init` second argument agree, and the first argument equals the file's **basename without extension**. Comment-only token elsewhere does not satisfy this test.

### TC-11 Harness-only all-file execution

For every marker=harness-only file (resolved by **basename test-id**), `sh "$file" </dev/null` returns 2, emits standard diagnostic naming that basename, and creates no body sentinel/tmp/audit evidence.

### TC-12 Standalone-capable all-file force-fail (differential)

Scope: every marker=standalone-capable file **whose prerequisites are satisfied**, resolved by **basename test-id**. Prerequisite class is decided by stage 1 of the two-stage procedure (see below), not assumed.

For each such file, assert **both**:

- (a) **probe absent** → `sh "$file" </dev/null` returns 0
- (b) **probe present with matching `PG_EXTRA_CONTRACT_TARGET=<basename>`** → returns 1

Both must hold; the difference between (a) and (b) is what proves the file reaches finalize. (b) alone cannot detect a file that always returns 1. Non-target file behavior is unchanged.

**Prerequisite-absent files are excluded from this case and are asserted by TC-17 (rc=3) instead.** Requiring rc=0 from every standalone-capable file would fail deterministically: at the base commit, `ta-43-eh2-strict-json` takes its early SKIP path (`scripts/hooks/check-plan-hash.sh` contains no `_eh2_stdin`, so `_T43_APPLIED=0`) and therefore returns rc=3 after migration, not rc=0. `ta-39-eh3-doc-light`'s prerequisite is satisfied at the same commit, so the two classes genuinely coexist within 層 A.

Two-stage procedure (execute → classify → assert):

1. **Stage 1 — classify**: run each target once **with no probe**. rc=0 → prerequisite-satisfied class; rc=3 → prerequisite-absent class; **any other rc (1 / 2 / …) is unclassifiable and is an immediate FAIL** (fail-closed, so an implementation that always returns 3 cannot pass).
2. **Stage 2 — assert**: prerequisite-satisfied class → (a)/(b) above; prerequisite-absent class → TC-17.

The class split is recorded in evidence; **the number of files in each class is not baked into the test as an expected value**.

Additionally: with `PG_EXTRA_CONTRACT_PROBE=force-fail` set but `PG_EXTRA_CONTRACT_TARGET` unset, the helper **fails closed** (diagnostic + nonzero rc), not no-op.

### TC-13 Standalone-capable normal execution

For every marker=standalone-capable file whose prerequisites are satisfied, clean direct execution with `</dev/null` returns 0 and output contains no `[FAIL]`. Files whose prerequisites are absent are asserted by TC-17 (rc=3), not by this case.

### TC-14 Harness regression (no hardcoded filename)

`sh tests/run-tests.sh` reaches the final Results line and ends with 0 failed. The last executed file is determined **at runtime** by `ls tests/extras/ta-*.sh | tail -1`, and its `[PASS]` output must appear in the harness log. **The filename must not be hardcoded** — this detects source-time early exit, not just individual test correctness.

### TC-15 External env contamination

With the seven guarded env values pre-set, runner and standalone-capable normal loop behave as clean baseline; harness-only still exits 2 directly. Contract probe env vars are additionally set and must have **no effect on the harness run** (internal-only).

### TC-16 New file without contract

Adding a temporary `ta-zz-probe.sh` without marker/init makes contract TA fail. Adding only a marker but no matching init also fails. Adding marker + init but **no tail `pg_extra_contract_finalize`** also fails (case D has no trap safety net).

## Early Exit / Prerequisite Cases

### TC-17 Prerequisite-absent files return rc=3

In a sandbox where the prerequisite is absent, `ta-39-eh3-doc-light`, `ta-43-*`, and `ta-44-*` each return **rc=3** on normal standalone execution (**rc=0 is a FAIL**); with a matching force-fail probe they return 1 only when the prerequisite is present. Under harness source they skip without terminating the suite.

The rc=3 must additionally be shown to originate from `pg_extra_contract_skip` (its diagnostic appears in the output). A file that reaches rc=3 by any other route is a FAIL — `pg_extra_contract_skip` is the sole channel for declaring "prerequisite absent", and the test body must never `exit 3` directly.

This case also covers every file that stage 1 of TC-12 sorts into the prerequisite-absent class, which at the base commit includes `ta-43-eh2-strict-json` under the repository's own state (not only in a constructed sandbox).

### TC-18 ta-26 parity including summary literal

Before/after migration, `ta-26` clean standalone rc, forced-failure rc, cleanup, and full existing TC results are equivalent. In addition the standalone summary line must keep the literal format `TA-<NN> standalone: N passed, M failed`, because `ta-26` TC-13 greps that string from a child process rather than checking rc (R-015a).

### TC-19 README documents the rc layers and marker rules

Contract TA greps `tests/extras/README.md` and asserts it documents: rc **0 / 1 / 2 / 3** meanings, the capability marker convention, the probe's five required statements, and the note that extras rc=2 is a **different namespace** from the hook BLOCK `exit 2` (R-009 / R-020).

### TC-20 test-id uniqueness

Contract TA asserts every `ta-*.sh` has a **unique basename test-id**. (Numeric prefixes are known to collide — `ta-14` appears twice — so a number-based id would silently conflate two files.)

### TC-21 register_cleanup is not unconditionally redefined

After sourcing the helper inside a harness-like context, `register_cleanup` still resolves to the harness definition (single-drain contract of `tests/run-tests.sh` is intact). In standalone context the helper provides it only when undefined (R-019b). The helper also sources cleanly under `set -eu` with no unbound-variable error (R-019a).

### TC-22 TC-33 substitute keeps its detection power

The `ta-26` TC-33 gate (#914 AC-9) is re-targeted at the helper: the helper's standalone unset set must be a superset of the runner's seven guarded env vars, and every `ta-*.sh` must carry helper bootstrap + init. Removing one env from the helper's unset set makes this case FAIL (no silent skip). A `continue`-only loop that inspects zero files is itself a FAIL (R-013).

### TC-23 Probe env does not leak into child processes

Two instantiations, in different slices:

- **Slice 1 (synthetic)**: a standalone-capable fixture that spawns a child `sh` and prints the child's view of `PG_EXTRA_CONTRACT_PROBE` / `PG_EXTRA_CONTRACT_TARGET`. After `pg_extra_contract_finalize` unsets them, the child must see neither. This is a helper-unit property and does not depend on any `ta-*.sh` migration.
- **Slice 2 (real)**: with `PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET=ta-26-plugin-sync`, the self-recursive child invoked by `ta-26` TC-13 (`PG_T26_NO_RECURSE=1`) must **not** see the probe vars; the parent's verdict must come from its own finalize only (R-015b). `ta-26` is 層 0, migrated in Slice 2, so this instantiation cannot run in Slice 1.

### TC-24 Migration allowlist is empty at Slice 2 completion

The contract TA's migration-period allowlist (files exempted because they have not yet been migrated to the helper) is resolved by the predicate "has no helper bootstrap", never by a hardcoded filename list. At Slice 2 completion the allowlist must resolve to **zero files**, i.e. the contract TA's per-file loops cover every runtime-discovered `ta-*.sh`.

A test that reports an empty allowlist because its discovery glob matched nothing is itself a FAIL: the case must assert both "allowlist is empty" and "the covered set is non-empty and equals the discovered set".

This fixes pbi-input AC-5's requirement that a pre-fix allowlist be held only for the migration period and never made permanent.

## Mutation Matrix

> Mutation Matrix は **修正後 helper への変異**である。pbi-input AC-7 が要求する
> 「修正前実装で FAIL する」実証は別物であり、Verification Plan の
> **pre-fix HEAD 実行 evidence** で担保する（R-011）。
>
> **Slice**: the mutation is exercised in the earliest slice in which one of its detecting cases can run.

| ID | Mutation | Expected detection | Slice |
|---|---|---|---|
| M-01 | remove `fail > 0` branch from finalizer | TC-04 / TC-12 FAIL | 1 |
| M-02 | make the helper act on probe env in harness mode | TC-01 / TC-15 FAIL | 1 |
| M-03 | change harness condition to `FIXTURES_DIR` only | TC-15 FAIL | 1 |
| M-04 | allow unknown capability as standalone-capable | TC-08 FAIL | 1 |
| M-05 | place harness-only init after body sentinel | TC-02 FAIL (synthetic) / TC-11 FAIL (all-file) | 1（TC-02）/ 2（TC-11） |
| M-06 | hardcode current file count and add probe file | TC-09 / TC-16 FAIL | 1 |
| M-07 | drop the tail `pg_extra_contract_finalize` from one migrated file | TC-12 / TC-16 FAIL | 1 |
| M-08 | make `PG_EXTRA_CONTRACT_TARGET` unset a no-op instead of fail-closed | TC-12 FAIL | 1 |
| M-09 | remove one env from the helper's standalone unset set | TC-22 FAIL | **2** |
| M-10 | return rc 0 instead of 3 on prerequisite-absent | TC-17 FAIL | 1 |
| M-11 | change the standalone summary literal format | TC-18 FAIL | **2** |
| M-12 | export probe env from finalize instead of unsetting it | TC-23 FAIL | 1（synthetic）/ 2（`ta-26` 実地） |
| M-13 | make the allowlist a hardcoded filename list that still contains a migrated file | TC-24 FAIL | **2** |

## Traceability

> **本表が AC↔TC 写像の単一正本**（R-001）。plan.md 側に写像は置かない。
> **AC-1〜AC-7 は [`pbi-input.md`](./pbi-input.md) の「受入基準」節を正本**とし、本表は写像のみを持つ。
> **AC-8 は C-2（R-013）由来の派生 AC であり、pbi-input 正本には存在しない。
> Human 決定 3 により層 0（`ta-26` を含む）が Slice 2 へ繰り延べられたため、
> AC-8 は Slice 2 の受入基準である**。pbi-input へ AC-8 を追記するか否かは
> **Slice 2 着手時に Human が裁定**する（Slice 1 の受入基準は AC-1〜AC-7 と 1:1 に戻る / C-1 MN-5）。
>
> **Slice 列**: `1` = Slice 1 で充足 / `2` = Slice 2 で充足 / `1(部分)/2(全体)` = 全体量化子を
> 含むため Slice 1 では対象範囲を限定して充足し、Slice 2 完了時に全体で充足する。

| AC | 内容（要約） | Tests | Slice |
|---|---|---|---|
| AC-1 | standalone で `fail > 0` / 誤動作でも exit 0 を返すものが 0 件（実行ベース判定・件数非固定） | TC-09, TC-10, TC-11, TC-12, TC-13, TC-16, TC-20 | **1（層 A 12 本の範囲）/ 2（全 57 本）** |
| AC-2 (a) | 層 A の fail 注入 standalone が exit 1 | TC-04, TC-05, TC-12 | 1 |
| AC-2 (b) | 同じ fail 注入状態で source 経路が完走し集計される | TC-01, TC-14, TC-15 | 1 |
| AC-2 (c) | 前提未充足 SKIP の rc が「検査していない」を表明（**rc=3**、rc=0 不可） | **TC-17**, TC-13 | 1 |
| AC-2 (d) | カウンタ初期化の存在（helper が担保。層 A 12 本は全数が未初期化） | TC-03, TC-04 | 1 |
| AC-3 | 層 B + 層 C 41 本の standalone が明示メッセージ付き exit 2 | TC-02（synthetic）, TC-11（全件） | **1（TC-02 のみ）/ 2（TC-11 で充足）** |
| AC-4 | `sh tests/run-tests.sh` が回帰しない + **runtime `tail -1`** 最終ファイルの `[PASS]` 出現 | **TC-14**, TC-15, TC-21 | 1（Slice 2 でも再実行） |
| AC-5 | 検査が回帰テスト化され、新規追加の伝播漏れを将来も検出（正規述語）。**移行期間 allowlist を恒久化しない** | TC-09, TC-10, TC-16, TC-20, **TC-24** | **1（allowlist 付きで成立）/ 2（TC-24 で allowlist 空）** |
| AC-6 | README 規約 9（rc 0/1/2/3・marker・probe・rc2 名前空間）+ #914 handoff writeback | **TC-19**（README）+ handoff CLOSED マーカーの grep（DoD） | **1（TC-19）/ 2（writeback）** |
| AC-7 | 追加した検査が **修正前実装で FAIL** することの実証 | Verification Plan の pre-fix HEAD evidence + M-01〜M-13（各 M の Slice は Mutation Matrix に従う） | 1（Slice 1 で走る M）/ 2（M-09 / M-11 / M-13） |
| **AC-8**（派生・pbi-input 正本外） | `ta-26` TC-33（#914 AC-9 ゲート）が移行後も**空振りせず**同等以上の検出力を保つ | **TC-22**, M-09 | **2** |

補助的な設計制約の紐付け（AC 直属ではないが Exit Criteria に含む）:

| 制約 | Tests | Slice |
|---|---|---|
| **original の nonzero rc を握り潰さない（Finalize precedence の保持）** | **TC-06** | 1 |
| **登録済み tmp のみ削除し未登録 path を消さない（cleanup の既存パターン制約）** | **TC-07** | 1 |
| **capability 宣言の不正を fail-closed で拒否する（AC-5 の「契約未宣言なら fail」の裏面）** | **TC-08**, M-04 | 1 |
| summary 書式の維持（`ta-26` TC-13 の literal grep） | TC-18, M-11 | **2**（`ta-26` は層 0） |
| probe の internal-only / fail-closed / 再帰ガード | TC-01, TC-12, TC-15, TC-23, M-02, M-08, M-12 | 1（TC-23 は synthetic のみ / 実地は 2） |
| `set -eu` source-safe / `register_cleanup` 非再定義 | TC-21 | 1 |
| 案 D（末尾 explicit finalize）の漏れ検出 | TC-05, TC-16, M-07 | 1 |

## Exit Criteria

> **Slice 1 は単独 PR として C-4 / merge される**（`todo.md` の `H-02`）。したがって
> **Slice 1 の DoD は Slice 2 の成果物に依存してはならない**。以下を Slice ごとに分離する
> （C-1 MJ-C）。Slice 1 の V-1 受け入れ検査は **Slice 1 節のみ**を突合する。

### Slice 1 の DoD（Slice 1 PR の V-1 / C-4 の判定対象）

- [ ] **TC-01, TC-02, TC-03, TC-04, TC-05, TC-06, TC-07, TC-08, TC-09, TC-10, TC-12,
      TC-13, TC-14, TC-15, TC-16, TC-17, TC-19, TC-20, TC-21, TC-23（synthetic 側）PASS**
- [ ] **M-01〜M-08, M-10, M-12（synthetic 側）が期待どおり FAIL**
- [ ] **AC-2 (a)(b)(c)(d), AC-4, AC-7 を充足**
- [ ] **AC-1 を層 A 12 本の範囲で充足**（全 57 本の充足は Slice 2）
- [ ] **AC-3 を TC-02（synthetic）で充足**（層 B + 層 C 41 本の全件充足は Slice 2）
- [ ] **AC-5 を移行期間 allowlist 付きで充足**（allowlist 空の証明は Slice 2 / TC-24）
- [ ] **AC-6 を TC-19（README）で充足**（`TASK-0914/handoff.md` writeback は Slice 2）
- [ ] **pre-fix HEAD で contract TA が FAIL する evidence が存在する**（AC-7 / R-011）
- [ ] runtime inventory unclassified=0、test-id（basename）重複=0（**TC-20 は全 57 本を対象**）
- [ ] **contract TA を含むフルスイート 1 回 + contract TA 単独 2 回が 0 failed**
      （R-017 の CI 時間裁定により「フルスイート 3 連続」から読み替え。
      副作用の受容根拠は plan の `### 緩和の副作用と、それを受容する裁定根拠` 参照）
- [ ] evidence includes actual file count but test does not hardcode it
- [ ] evidence includes measured CI duration (baseline 231s との差分)
- [ ] **移行期間 allowlist が「helper bootstrap を持たない」述語で解決され、
      ファイル名のハードコード列になっていない**

### Slice 2 の DoD（Slice 2 着手時に Mode 再判定のうえ適用）

- [ ] **TC-11, TC-18, TC-22, TC-23（`ta-26` 実地側）, TC-24 PASS**
- [ ] **M-09, M-11, M-13 が期待どおり FAIL**
- [ ] **AC-3 を層 B + 層 C 41 本の全件で充足**（TC-11）
- [ ] **AC-1 を全 57 本で充足**（allowlist 空の状態で再評価）
- [ ] **AC-5 を allowlist 空の状態で充足**（TC-24）
- [ ] **AC-6 の writeback 側**: `TASK-0914/handoff.md` §3 の対象 2 行に CLOSED マーカーが
      grep で確認できる
- [ ] **AC-8 を充足**（TC-22 / M-09。`ta-26` TC-33 の検出力が空振りしない）
- [ ] **TC-01〜TC-24 を通しで再実行して PASS**（Slice 1 の DoD が Slice 2 の変更で退行していないこと）
