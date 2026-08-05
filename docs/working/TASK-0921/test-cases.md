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

For every marker=standalone-capable file, resolved by **basename test-id**, assert **both**:

- (a) **probe absent** → `sh "$file" </dev/null` returns 0
- (b) **probe present with matching `PG_EXTRA_CONTRACT_TARGET=<basename>`** → returns 1

Both must hold; the difference between (a) and (b) is what proves the file reaches finalize. (b) alone cannot detect a file that always returns 1. Non-target file behavior is unchanged.

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

With `PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET=ta-26-plugin-sync`, the self-recursive child invoked by `ta-26` TC-13 (`PG_T26_NO_RECURSE=1`) must **not** see the probe vars; the parent's verdict must come from its own finalize only (R-015b).

## Mutation Matrix

> Mutation Matrix は **修正後 helper への変異**である。pbi-input AC-7 が要求する
> 「修正前実装で FAIL する」実証は別物であり、Verification Plan の
> **pre-fix HEAD 実行 evidence** で担保する（R-011）。

| ID | Mutation | Expected detection |
|---|---|---|
| M-01 | remove `fail > 0` branch from finalizer | TC-04 / TC-12 FAIL |
| M-02 | make the helper act on probe env in harness mode | TC-01 / TC-15 FAIL |
| M-03 | change harness condition to `FIXTURES_DIR` only | TC-15 FAIL |
| M-04 | allow unknown capability as standalone-capable | TC-08 FAIL |
| M-05 | place harness-only init after body sentinel | TC-02 / TC-11 FAIL |
| M-06 | hardcode current file count and add probe file | TC-09 / TC-16 FAIL |
| M-07 | drop the tail `pg_extra_contract_finalize` from one migrated file | TC-12 / TC-16 FAIL |
| M-08 | make `PG_EXTRA_CONTRACT_TARGET` unset a no-op instead of fail-closed | TC-12 FAIL |
| M-09 | remove one env from the helper's standalone unset set | TC-22 FAIL |
| M-10 | return rc 0 instead of 3 on prerequisite-absent | TC-17 FAIL |
| M-11 | change the standalone summary literal format | TC-18 FAIL |
| M-12 | export probe env from finalize instead of unsetting it | TC-23 FAIL |

## Traceability

> **本表が AC↔TC 写像の単一正本**（R-001）。plan.md 側に写像は置かない。
> AC 番号は [`pbi-input.md`](./pbi-input.md) の「受入基準」節（issue #921 の AC を継承・精緻化した
> 確定版）に従う。**AC-8 は本 C-2 反映で追加**（R-013 由来）。

| AC | 内容（要約） | Tests |
|---|---|---|
| AC-1 | standalone で `fail > 0` / 誤動作でも exit 0 を返すものが 0 件（実行ベース判定・件数非固定） | TC-09, TC-10, TC-11, TC-12, TC-13, TC-16, TC-20 |
| AC-2 (a) | 層 A の fail 注入 standalone が exit 1 | TC-04, TC-05, TC-12 |
| AC-2 (b) | 同じ fail 注入状態で source 経路が完走し集計される | TC-01, TC-14, TC-15 |
| AC-2 (c) | 前提未充足 SKIP の rc が「検査していない」を表明（**rc=3**、rc=0 不可） | **TC-17**, TC-13 |
| AC-2 (d) | カウンタ初期化の存在（helper が担保） | TC-03, TC-04, TC-18 |
| AC-3 | 層 B + 層 C 41 本の standalone が明示メッセージ付き exit 2 | TC-02, TC-11 |
| AC-4 | `sh tests/run-tests.sh` が回帰しない + **runtime `tail -1`** 最終ファイルの `[PASS]` 出現 | **TC-14**, TC-15, TC-21 |
| AC-5 | 検査が回帰テスト化され、新規追加の伝播漏れを将来も検出（正規述語） | TC-09, TC-10, TC-16, TC-20, TC-22 |
| AC-6 | README 規約 9（rc 0/1/2/3・marker・probe・rc2 名前空間）+ #914 handoff writeback | **TC-19** + handoff CLOSED マーカーの grep（DoD） |
| AC-7 | 追加した検査が **修正前実装で FAIL** することの実証 | Verification Plan の pre-fix HEAD evidence + M-01〜M-12 |
| **AC-8** | `ta-26` TC-33（#914 AC-9 ゲート）が移行後も**空振りせず**同等以上の検出力を保つ | **TC-22**, M-09 |

補助的な設計制約の紐付け（AC 直属ではないが Exit Criteria に含む）:

| 制約 | Tests |
|---|---|
| summary 書式の維持（`ta-26` TC-13 の literal grep） | TC-18, M-11 |
| probe の internal-only / fail-closed / 再帰ガード | TC-01, TC-12, TC-15, TC-23, M-02, M-08, M-12 |
| `set -eu` source-safe / `register_cleanup` 非再定義 | TC-21 |
| 案 D（末尾 explicit finalize）の漏れ検出 | TC-05, TC-16, M-07 |

## Exit Criteria

- [ ] TC-01〜TC-23 PASS
- [ ] M-01〜M-12 each causes expected FAIL
- [ ] **pre-fix HEAD で contract TA が FAIL する evidence が存在する**（AC-7 / R-011）
- [ ] runtime inventory unclassified=0、test-id（basename）重複=0
- [ ] **contract TA を含むフルスイート 1 回 + contract TA 単独 2 回が 0 failed**
      （R-017 の CI 時間裁定により「フルスイート 3 連続」から読み替え）
- [ ] evidence includes actual file count but test does not hardcode it
- [ ] evidence includes measured CI duration (baseline 231s との差分)
- [ ] **`TASK-0914/handoff.md` §3 の対象 2 行に CLOSED マーカーが grep で確認できる**（AC-6 / Slice 2）
