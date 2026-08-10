# TEST CASES — TASK-0921

> **C-2 反映済み**（`Refs: R-001`〜`R-020` / **別系統 C-2（4 レーン）由来の `R-021`〜`R-037`**）。
> 指摘の正本は [`review-external.md`](./review-external.md)。
> 本ファイルの `## Traceability` が **AC↔TC 写像の単一正本**である（R-001）。
>
> **R-032 は `resolved-by-design` につき反映していない**。未確定の 4 件（R-022 / R-023 /
> R-026 の `timeout-minutes` / R-030）+ **AC-2 (c) の対象本数（F3）** は
> plan の `## Human C-3 の判断事項`（**HJ-1〜HJ-5**）に集約した。
> **HJ-4（`original rc` の捕捉規約）の裁定により TC-06 が再定義されうる**点に注意。

## Contract RC Table

| Capability / condition | Expected rc |
|---|---:|
| standalone-capable, all pass | 0 |
| standalone-capable, internal fail > 0 | 1 |
| harness-only, direct invocation | 2 |
| **standalone-capable, prerequisite absent かつ `fail = 0`（検査していない）** | **3** |
| **standalone-capable, prerequisite absent かつ `fail > 0`（検査して失敗した）** | **1** |
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

**Slice 1 では synthetic fixture を対象とする**（実 `ta-*.sh` の harness-only 移行は Slice 2 / TC-11）. Traceability and M-05 already treat this case as the synthetic instantiation; the wording here is aligned with TC-23, which splits Slice 1 (synthetic) / Slice 2 (real) explicitly.

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

> **Migration scope (shared by TC-09 / TC-10 / TC-11 / TC-12 / TC-13)**
>
> The *migrated set* = every runtime-discovered `ta-*.sh` whose basename is **not returned by
> `_pending_migration`**, the migration-period allowlist embedded **inside the contract TA itself**
> (`tests/extras/ta-XX-extra-contract.sh`) as a heredoc-returning shell function. **TC-20 (basename
> uniqueness) is exempt from this restriction and covers every discovered file**, because basename
> uniqueness does not depend on migration state.
>
> The allowlist is an **explicit list generated from the Task 1 inventory**, never a predicate such
> as "has no helper bootstrap": a predicate would silently swallow a newly added file that has
> neither marker nor init, which is exactly what TC-16 and M-06 must catch, and it would violate the
> second clause of pbi-input AC-5 ("将来の追加ファイルが黙って除外されない構造にする"). Keeping the
> list inside the contract TA also removes any runtime dependency on `docs/working/` and makes the
> "allowlist file missing / unreadable / mis-pathed" failure modes structurally impossible. The
> list's **line count is never used as an expected value**; only membership is (and, at Slice 2
> completion only, its emptiness — TC-24).
>
> This block is intentionally **English-only**. The Japanese wording of the same definition lives in
> `plan.md` Task 6 and `todo.md` T-06, and the **字面一致 (literal-agreement) requirement holds
> between those two Japanese blocks only** — this file is not a party to that agreement.
>
> The agreement covers **the first bullet of each block only — 第 1 項（移行 scope 定義）**, i.e.
> "検査対象は移行済み集合＝移行期間 allowlist …" through "… `_pending_migration` 関数ごと削除する
> （TC-24 / AC-5）". The **second bullet**, which states TC-25's three assertions, is deliberately
> **not** covered: `plan.md` carries additional explanatory sentences there, so requiring
> byte-identity would force either duplicated prose into `todo.md` or the removal of the
> explanation from `plan.md`.
>
> "Literal agreement" is defined mechanically: after stripping the list marker (`-` or `- [ ]`),
> the leading indentation, the line breaks introduced by wrapping, and all remaining whitespace,
> the two first bullets must be **byte-identical**. They were confirmed identical under that
> normalization in the C-1 fourth round (they previously differed — `述語にすると` vs `述語だと`,
> and `plan.md` carried one extra sentence — so the agreement was being asserted without holding),
> and re-confirmed in the fifth round after the second bullet was edited.

### TC-09 Exactly one capability marker

**Scope**: the migrated set — every runtime-discovered `ta-*.sh` **not returned by**
`_pending_migration` (the migration-period allowlist embedded in the contract TA).

For every file in scope, marker count is exactly 1 and value is one of `standalone-capable`, `harness-only`.

**Detection is specified, not left to the implementer (R-027).** The normative regex, search range and
pass condition live in `plan.md` `#### marker 検出の正規表現仕様`:

```text
ERE     : ^[[:space:]]*#[[:space:]]*PG_EXTRA_CAPABILITY:[[:space:]]*(standalone-capable|harness-only)[[:space:]]*$
Range   : first 20 lines of the file only
Pass    : exactly 1 matching line (0 or ≥2 is a FAIL)
```

Four vacuity routes are closed by that spec and must stay closed: two markers on one line, a
**trailing space** defeating a strict `$` anchor, a marker string **inside a heredoc**, and the
contract TA **matching itself**. The corresponding mutation is **M-17**.

### TC-10 Marker and init agree

**Scope**: the migrated set — every runtime-discovered `ta-*.sh` **not returned by**
`_pending_migration` (the migration-period allowlist embedded in the contract TA).

For every file in scope, marker value and `pg_extra_contract_init` second argument agree, and the first argument equals the file's **basename without extension**. Comment-only token elsewhere does not satisfy this test.

### TC-11 Harness-only all-file execution

**Scope**: the migrated set — every runtime-discovered `ta-*.sh` **not returned by**
`_pending_migration` (the migration-period allowlist embedded in the contract TA).

For every in-scope marker=harness-only file (resolved by **basename test-id**), `sh "$file" </dev/null` must satisfy **both** conditions — rc alone is not a pass (R-029-2):

- `rc == 2`, **AND**
- the output contains `[ERROR] <basename-id> is harness-only` with the **file's own basename id**

and it creates no body sentinel/tmp/audit evidence.

**Why the id-bearing message is part of the pass condition**: a shell **syntax error also exits 2**
(a missing command exits 127). A file whose syntax was broken would pass an rc-only assertion without
the harness-only guard having run at all. The id match proves the guard executed and identified the
right file. The independent `sh -n` case (**TC-27**) is the second layer of that defence.

**Slice**: the loop **runs from Slice 1**, not only from Slice 2. In Slice 1 no real file carries the
`harness-only` marker yet, so the loop is **vacuous** and its full-coverage value for AC-3 still only
arrives in Slice 2. Running it in Slice 1 anyway is cheap and closes a real window: if a **new file
with a `harness-only` marker plus matching init** is added during Slice 1, TC-09 / TC-10 would check
its marker/init **statically** but nothing would check that it actually **rejects direct execution
with rc=2** until Slice 2. AC-5 is not violated by that window (the file does belong to the covered
set, so it is not silently excluded), but the window exists and is closed here.

**A vacuous pass must not read as a real pass**: when the in-scope harness-only set is empty, TC-11
passes, but the contract TA must **state the count and the fact that it was zero in the evidence**
(`evidence/test-runs/harness-only.log`). A silent green over zero files is precisely the defect class
this PBI exists to close, so it is recorded rather than hidden. The count is written to evidence as
an observation; it is **not** an expected value.

### TC-12 Standalone-capable all-file force-fail (differential)

**Scope**: the migrated set — every runtime-discovered `ta-*.sh` **not returned by**
`_pending_migration` (the migration-period allowlist embedded in the contract TA) — restricted further to
marker=standalone-capable files **whose prerequisites are satisfied**, resolved by
**basename test-id**. Prerequisite class is decided by stage 1 of the two-stage procedure
(see below), not assumed.

For each such file, assert **both**:

- (a) **probe absent** → `sh "$file" </dev/null` returns 0
- (b) **probe present with matching `PG_EXTRA_CONTRACT_TARGET=<basename>`** → returns 1
  **AND** the output contains the probe's unique marker `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>`

Both must hold; the difference between (a) and (b) is what proves the file reaches finalize. (b) alone cannot detect a file that always returns 1. Non-target file behavior is unchanged.

**Why (b) is an AND rather than an rc check (R-029-1)**: rc=1 can arise from causes other than the
probe. The 層 0 files still carry the legacy `[ "$fail" -eq 0 ] || exit 1` footer, so they can return 1
**without finalize ever being called** — an rc-only assertion cannot prove "finalize was reached and
mapped `fail>0` onto rc=1", which is the entire property this case exists to prove. The plan already
required the probe message to be distinguishable; R-029 makes that message a **pass condition** and
fixes its format so the test can grep it. The mutation that removes the unique string / test-id from
the probe message is **M-18**.

**Prerequisite-absent files are excluded from this case and are asserted by TC-17 (rc=3) instead.** Hardcoding rc=0 for every standalone-capable file is nevertheless forbidden, because prerequisite satisfaction depends on repository state (which hooks/scripts are applied) and can flip between the plan, exec and CI environments. Measured at the base commit (C-1 round 2), `ta-39-eh3-doc-light`, `ta-43-eh2-strict-json` and `ta-44-eh457-cli-wiring` **all** return rc=0, i.e. all three are prerequisite-satisfied and the prerequisite-absent class is currently empty; `ta-43`'s prerequisite is checked against `scripts/hooks/check-c3-approval.sh` (which does contain `_eh2_stdin`), not `check-plan-hash.sh`. The class split must therefore be **re-measured by stage 1 at exec start** and never written into the test as a fixed list.

Two-stage procedure (execute → classify → assert):

1. **Stage 1 — classify**: run each target once **with no probe**. rc=0 → prerequisite-satisfied class; rc=3 → prerequisite-absent class; **any other rc (1 / 2 / …) is unclassifiable and is an immediate FAIL** (fail-closed, so an implementation that always returns 3 cannot pass). Note that under the Finalize precedence a prerequisite-absent file that already has `fail > 0` returns **rc=1**, so it lands in the unclassifiable branch and FAILs — this is intended: a clean run that records a real assertion failure is a defect regardless of prerequisite state.
2. **Stage 2 — assert**: prerequisite-satisfied class → (a)/(b) above; prerequisite-absent class → TC-17.

The class split is recorded in evidence; **the number of files in each class is not baked into the test as an expected value**.

Additionally: with `PG_EXTRA_CONTRACT_PROBE=force-fail` set but `PG_EXTRA_CONTRACT_TARGET` unset, the helper **fails closed** (diagnostic + nonzero rc), not no-op.

### TC-13 Standalone-capable normal execution

**Scope**: the migrated set — every runtime-discovered `ta-*.sh` **not returned by**
`_pending_migration` (the migration-period allowlist embedded in the contract TA).

For every in-scope marker=standalone-capable file whose prerequisites are satisfied, clean direct execution with `</dev/null` returns 0 and output contains no `[FAIL]`. Files whose prerequisites are absent are asserted by TC-17 (rc=3), not by this case.

### TC-14 Harness regression (no hardcoded filename)

`sh tests/run-tests.sh` reaches the final Results line and ends with 0 failed. The last executed file is determined **at runtime** by `ls tests/extras/ta-*.sh | tail -1`, and its `[PASS]` output must appear in the harness log. **The filename must not be hardcoded** — this detects source-time early exit, not just individual test correctness.

### TC-15 External env contamination

With **every guarded env value derived at runtime from `tests/run-tests.sh`'s unset list** pre-set, runner and standalone-capable normal loop behave as clean baseline; harness-only still exits 2 directly. Contract probe env vars are additionally set and must have **no effect on the harness run** (internal-only).

**The env count is never written into this case (R-034).** `ta-26`'s TC-33 already derives the env
names dynamically from `run-tests.sh` with `awk` precisely to avoid a fixed count; hardcoding "seven"
here would go the other way and leave the test wording **stale** the moment the runner's unset list
grows or shrinks. It also conflicts with the Global Constraint "file count / ta 番号一覧を正本として
ハードコードしない". Derive the set, do not count it.

### TC-16 New file without contract

Adding a temporary `ta-zz-probe.sh` without marker/init makes contract TA fail. Adding only a marker but no matching init also fails. Adding marker + init but **no tail `pg_extra_contract_finalize`** also fails (case D has no trap safety net).

**The probe file is created inside a sandbox, never in the real `tests/extras/` (R-028).** Use the
same real-tree copy construction as TC-17 / M-10 (`plan.md` `#### TC-17 / M-10 の sandbox 構成手順`):
`mktemp -d`, copy the tracked worktree in, add `ta-zz-probe.sh` **to the copy**, run the copy's contract
TA. `tests/run-tests.sh` sources **every** `ta-*.sh` unconditionally, so a probe file left behind by an
interrupted or crashed run would poison every subsequent run — it carries neither marker nor init, so
the contract TA would fail permanently and the cause ("a previous run was interrupted") would be
invisible. Writing to the real `tests/extras/` is forbidden by Global Constraints for this reason.

This case is the reason the migration-period allowlist must be an **explicit list** and not a predicate: `ta-zz-probe.sh` has no helper bootstrap, so a predicate-based allowlist would exempt it and this case would silently pass. Because `_pending_migration` is generated from the Task 1 inventory at the base commit, the newly added file is absent from it and therefore **falls inside the migrated set** — which is the property MJ-E requires, and it holds for all three patterns below.

Which assertion actually catches each pattern differs, and TC-16 must be read that way:

| Pattern added by the case | Detected by |
|---|---|
| A: no marker, no init | **TC-09** (marker count ≠ 1) and **TC-10** (no init to agree with) |
| B: marker only, no matching init | **TC-10** (marker / init disagree) |
| C: marker (`standalone-capable`) + matching init but **no tail `pg_extra_contract_finalize`** | **TC-12's probe differential** — stage 1 classifies it as prerequisite-satisfied (it ends normally with rc=0), then (b) probe-present fails to return 1 because finalize is never reached (cf. **M-07**). It passes TC-09 (exactly one marker) and TC-10 (marker and init agree), so neither of those can catch it. With a `harness-only` marker the file would instead be caught by TC-11 in Slice 2, finalize being irrelevant there |

Set membership (i.e. "the new file is in scope at all") is established for all three patterns identically; only the detecting assertion differs.

## Early Exit / Prerequisite Cases

### TC-17 Prerequisite-absent files return rc=3

In a sandbox where the prerequisite is absent, the **six whole-file-guard** files —
`ta-39-eh3-doc-light`, `ta-43-eh2-strict-json`, `ta-44-eh457-cli-wiring` (the `|| exit 0` form) and
`ta-45-c3-mode-config`, `ta-46-ehs-wiring`, `ta-47-ehs23-wiring` (the **`|| true` form**, added by
R-021) — each return **rc=3** on normal standalone execution (**rc=0 is a FAIL**); with a matching
force-fail probe they return 1 only when the prerequisite is present. Under harness source they skip
without terminating the suite.

**`ta-49-bias-export` is deliberately excluded from the rc=3 assertion.** It is the seventh early-exit
file but its guard is **section-scoped, not file-scoped**: the file declares two layers in its header
(layer A runs unconditionally, layer B is skipped when the HO wiring is unapplied), and by the time the
guard is reached **layer A's TC-01 / TC-02 / TC-04 / TC-06 have already run and updated the counters
eight times** (measured). Asserting rc=3 there would (i) misstate "not inspected" for a file that did
inspect, and (ii) **contradict this plan's own Finalize precedence**, which requires **rc=1** when a
prerequisite is absent *and* `fail > 0`. Its expectation is therefore **rc follows the preceding TCs
(0 or 1), plus the SKIP diagnostic** — asserted by TC-29, not here. The six above are confirmed to have
**no executed counter update before their guard** (the apparent matches in `ta-39` / `ta-44` are the
`tXX_pass()` / `tXX_fail()` **function definitions**, not executions).

The rc=3 must additionally be shown to originate from `pg_extra_contract_skip` (its diagnostic appears in the output). A file that reaches rc=3 by any other route is a FAIL — `pg_extra_contract_skip` is the sole channel for declaring "prerequisite absent", and the test body must never `exit 3` directly.

This case also covers every file that stage 1 of TC-12 sorts into the prerequisite-absent class. At the base commit that class is **empty under the repository's own state** (`ta-39`, `ta-43` and `ta-44` all return rc=0 — measured in C-1 round 2), so at present TC-17 is exercised **only in a constructed sandbox**; the class must be re-measured by stage 1 at exec start.

**The sandbox construction procedure is normative and lives in `plan.md` `#### TC-17 / M-10 の sandbox 構成手順`** (copy the repo into a temp dir, strip the measured predicate string, run the copy's `ta-*.sh` standalone). It is required because these three files resolve their root from `$0` on the standalone path after unsetting `PG_HARNESS_SOURCED`, so **`FIXTURES_DIR` cannot redirect the root** — a real tree copy is mandatory. **TC-17 and M-10 stay in Slice 1**; they are not deferred to Slice 2. Every destructive step (predicate removal, apply-script execution) happens **inside the `mktemp` fixture only** — the repository itself is read-only for this case.

**Out of scope for TC-17**: a prerequisite-absent run that also has `fail > 0`. Under the Finalize precedence that case returns **rc=1**, not rc=3 ("前提未充足だが既に失敗している" is "検査して失敗した", not "検査していない"). It is asserted as an ordinary failure (TC-04 / TC-12 stage 1 unclassifiable branch), not here.

### TC-18 ta-26 parity including summary literal

Before/after migration, `ta-26` clean standalone rc, forced-failure rc, cleanup, and full existing TC results are equivalent. In addition the standalone summary line must keep the literal format `TA-<NN> standalone: N passed, M failed`, because `ta-26` TC-13 greps that string from a child process rather than checking rc (R-015a).

### TC-19 README documents the rc layers and marker rules

Contract TA greps `tests/extras/README.md` and asserts it documents: rc **0 / 1 / 2 / 3** meanings, the capability marker convention, the probe's five required statements, and the note that extras rc=2 is a **different namespace** from the hook BLOCK `exit 2` (R-009 / R-020).

### TC-20 test-id uniqueness

**Scope**: **every** runtime-discovered `ta-*.sh`, **including files listed in the migration-period
allowlist** — basename uniqueness does not depend on migration state, so this case is explicitly
exempt from the migrated-set restriction that TC-09 / TC-10 / TC-11 / TC-12 / TC-13 carry.

Contract TA asserts every `ta-*.sh` has a **unique basename test-id**. (Numeric prefixes are known to collide — `ta-14` appears twice — so a number-based id would silently conflate two files.)

### TC-21 register_cleanup is not unconditionally redefined

After sourcing the helper inside a harness-like context, `register_cleanup` still resolves to the harness definition (single-drain contract of `tests/run-tests.sh` is intact). In standalone context the helper provides it only when undefined (R-019b). The helper also sources cleanly under `set -eu` with no unbound-variable error (R-019a).

### TC-22 TC-33 substitute keeps its detection power

The `ta-26` TC-33 gate (#914 AC-9) is re-targeted at the helper: the helper's standalone unset set must be a superset of **the runner's guarded env vars, derived at runtime from `tests/run-tests.sh` — the count is not stated (R-034)**, and every `ta-*.sh` must carry helper bootstrap + init. Removing one env from the helper's unset set makes this case FAIL (no silent skip). A `continue`-only loop that inspects zero files is itself a FAIL (R-013).

The equivalence claim behind this re-targeting — that `(1) helper's unset set ⊇ runner's guarded set`
**AND** `(2) every ta-*.sh carries helper bootstrap + init` is equivalent to the original whole-repo
property — is stated explicitly in `plan.md` `#### 差し替えの等価性の明示` (R-031). Note that (2) only
holds once the migration allowlist is empty, which is why this case is a **Slice 2** acceptance criterion.

### TC-23 Probe env does not leak into child processes

Two instantiations, in different slices:

- **Slice 1 (synthetic)**: a standalone-capable fixture that spawns a child `sh` and prints the child's view of `PG_EXTRA_CONTRACT_PROBE` / `PG_EXTRA_CONTRACT_TARGET`. After `pg_extra_contract_finalize` unsets them, the child must see neither. This is a helper-unit property and does not depend on any `ta-*.sh` migration.
- **Slice 2 (real)**: with `PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET=ta-26-plugin-sync`, the self-recursive child invoked by `ta-26` TC-13 (`PG_T26_NO_RECURSE=1`) must **not** see the probe vars; the parent's verdict must come from its own finalize only (R-015b). `ta-26` is 層 0, migrated in Slice 2, so this instantiation cannot run in Slice 1.

### TC-24 Migration allowlist is empty at Slice 2 completion

The contract TA's migration-period allowlist (files exempted because they have not yet been migrated to the helper) is an **explicit list embedded in the contract TA itself** — the shell function `_pending_migration`, which returns one basename per line from a heredoc. It is generated from the Task 1 inventory and shrunk by deleting a line each time a file is migrated. It is **never** resolved by a predicate such as "has no helper bootstrap" — a predicate would auto-exempt any newly added file that carries neither marker nor init, which is precisely the leak pbi-input AC-5's second clause forbids ("将来の追加ファイルが黙って除外されない構造にする") and which TC-16 / M-06 must catch.

At Slice 2 completion **`_pending_migration` must return zero lines**, i.e. the contract TA's per-file loops cover every runtime-discovered `ta-*.sh`. Once that holds, the function itself is deleted rather than left in place as an empty stub.

A test that reports an empty allowlist because its discovery glob matched nothing is itself a FAIL: the case must assert both "`_pending_migration` returns zero lines" and "the covered set is non-empty and equals the discovered set". The list's line count is only ever compared against zero at this point; it is **not** used as an expected value anywhere else (the "件数を契約値にしない" constraint applies to test expectations, and the allowlist is an input to the exclusion set, not an expectation).

Because the list now lives inside the contract TA, the failure modes "allowlist file is missing", "allowlist file is unreadable" and "allowlist path is wrong" **cannot occur** — there is no separate file and no runtime read of `docs/working/`. A dedicated "does `_pending_migration` exist?" guard is deliberately **not** added: if the function disappears or returns nothing, the allowlist is empty, the 45 unmigrated files enter scope, and TC-09 / TC-10 fail loudly. The dangerous direction is the opposite one — an over-broad list (e.g. a broken heredoc terminator) shrinking the covered set to zero and letting the contract TA pass on an empty loop — and that is asserted by **TC-25**, not by an existence check.

This fixes pbi-input AC-5's requirement that a pre-fix allowlist be held only for the migration period and never made permanent, and satisfies its second clause by making the exclusion set explicit.

### TC-25 Migration allowlist entries are sound, and the covered set is non-empty excluding self

**Slice**: 1 (this case must run from the first slice; it is the reverse-direction counterpart of
TC-16 and must not wait for TC-24 in Slice 2).

The contract TA asserts, for **every line returned by `_pending_migration`**:

1. the line names a file that **actually exists** as `tests/extras/<line>` and matches the
   `ta-*.sh` glob — a stale or misspelled entry that names nothing is a FAIL;
2. that file **does not carry** helper bootstrap / `pg_extra_contract_init` — i.e. it is genuinely
   unmigrated. An **already-migrated file left in the list** is a FAIL.

And, independently of the per-line checks, **three further assertions** that must all hold:

1. the **covered set with the contract TA itself removed** — i.e. (runtime-discovered files) minus
   (the ones `_pending_migration` returns) minus (the contract TA's own basename) — is
   **non-empty**. The contract TA is deliberately in the inventory and deliberately never on the
   allowlist (`plan.md` Task 6), so a covered set that merely "contains the contract TA" proves
   nothing: asserting non-emptiness **without** excluding self would be **vacuously true** and could
   never fire. Excluding self is what makes this assertion falsifiable;
2. `_pending_migration`'s output is a **proper subset** of the discovered set: every returned line is
   a discovered basename (already implied per-line by check 1 of the per-line block, restated here as
   a set property) **and** the two sets are **not equal**. An allowlist that has grown to equal the
   inventory is a FAIL even before any loop runs;
3. the per-file execution loop that drives **TC-12 / TC-13** (stage 1 of the two-stage procedure —
   it runs each covered standalone-capable file once and classifies it as prerequisite-satisfied or
   prerequisite-absent) **actually executed at least one file**. The contract TA records how many
   files that loop **actually started executing** — the counter is incremented at the point where
   stage 1's single run of the file begins (`sh "$file" </dev/null`), i.e. **after** every filter
   the loop body applies, **not** when the loop is entered — and asserts the count is **not zero**;
   **no expected count is stated** — only "not zero". This catches the case where the covered set
   passes the set arithmetic above but the loops still iterate over nothing. Counting at loop entry
   would let the very counter-example this assertion exists for slip through: a filter placed at the
   top of the loop body that `continue`s on every file leaves the entry count non-zero while nothing
   is ever run.

   The count deliberately measures **files whose execution was started**, not files that reached the
   prerequisite-satisfied branch: **a file that then falls into the prerequisite-absent branch (rc=3)
   is still counted**, because counting only the satisfied branch would turn "every covered file
   happens to have its prerequisites absent in this environment" — a legitimate state that TC-17
   asserts with rc=3 — into a hard FAIL, i.e. a new environment-dependent false failure. Once its
   execution has started, a file proves the loop is not empty regardless of how it is classified,
   which is the property being asserted here.

The three are deliberately redundant. The failure mode being closed — an over-broad allowlist
shrinking the checked set to nothing, so that TC-09 / TC-10 pass on the contract TA alone and
TC-12 / TC-13 pass on a zero-iteration loop, with everything green and nothing checked — is the
exact class of defect this PBI exists to close, so it is sealed at the set level (1, 2) *and* at
the execution level (3).

Rationale: TC-16 closes the leak where a **newly added** file is silently excluded. The reverse leak
— an **already-migrated** file left in the allowlist — removes that one file from every per-file
check with no other case noticing, and until this addition it was detectable only by TC-24 at Slice
2 completion. TC-25 moves that detection into Slice 1. The corresponding mutation is **M-14**.

Note that the line count of `_pending_migration` is **not** an expected value here; only per-line
soundness, the set relations above, and "the loop count is not zero" are asserted.

The "has no helper bootstrap" predicate appears in check 2 above, which may look like it contradicts
the rule that the allowlist is **never resolved by a predicate**. It does not: the predicate is used
here only as an **assertion about an independently authored list**, never to *derive* membership.
Deriving membership from the predicate is what silently exempts a marker-less new file (M-13's
predicate side, caught by TC-16); asserting the predicate over an explicit list is what catches a
migrated file that was left behind (M-14, caught here). The two directions are complementary.

### TC-26 A non-zero `return` on the source path never truncates the suite

**Slice**: 1. **Origin**: R-024.

Global Constraints previously forbade only `exit` on the source path. Under `set -eu`
(`tests/run-tests.sh`), a sourced extras file that merely **`return`s non-zero** also aborts the run:
every subsequent extras file is skipped, `_pg_drain_cleanup` never drains, and the `Results:` line is
never printed. The runner still exits 1, so the run looks like "tests are red" and **the truncation is
invisible**. The same accident happens by implementation slip — a `finalize` whose last statement is a
test such as `[ "$fail" -gt 0 ]` returns non-zero implicitly.

Source a synthetic harness that includes a standalone-capable-equivalent fixture with `fail > 0`, then
assert **both**:

- the **marker line of a file ordered after the failing one** appears in the output, and
- the `Results:` line appears.

Both are required: either one alone can be satisfied by an unrelated code path. The helper must
therefore end `pg_extra_contract_finalize` with an explicit `return 0` in harness mode and `exit` only
in standalone mode. The mutation is **M-16**.

### TC-27 Syntax check is an independent case

**Slice**: 1. **Origin**: R-029-3.

`sh -n` over the helper, `tests/run-tests.sh` and every `ta-*.sh` is asserted as its **own case**, not
only as a step in the Verification Plan. Reason: a shell **syntax error exits 2**, which is exactly the
rc this contract assigns to "harness-only invoked directly". Without an independent syntax case, a
file broken at parse time can satisfy TC-11's rc while its guard never ran. TC-11's id-bearing message
(R-029-2) and this case together remove that ambiguity. Failures here must be reported as **syntax
errors**, distinctly from the harness-only namespace.

### TC-28 The contract TA's discovery set equals the runner's source set

**Slice**: 1. **Origin**: R-035.

The contract TA performs its own runtime discovery of `ta-*.sh`. Nothing currently asserts that this
set is **the same set `tests/run-tests.sh` actually sources**. If one glob changes and the other does
not, the contract TA reports "every file checked" while some file the runner does source is never
looked at — the same vacuity class this PBI exists to close.

Assert set equality between (a) the contract TA's discovered set and (b) the set the runner's extras
loop sources. The cheapest sound implementation is to have both read the **same glob definition**
rather than to re-derive it in two places. Related observation: `ta-40` does not reference
`FIXTURES_DIR:-` and therefore never enters `ta-26`'s TC-33 scan at all — its 層 A membership was fixed
by R-003, but TC-33's own coverage is a separate matter, which this case covers. The mutation is
**M-19**.

### TC-29 Early-exit skip guards behave identically under dash and bash

**Slice**: 1. **Origin**: R-021 (critical) / issue
[#1026](https://github.com/s977043/PlanGate/issues/1026).

For each of the **seven** early-exit files, run the prerequisite-absent sandbox (TC-17's construction)
under **both `dash` and `bash`** and assert that the rc is **identical across the two shells**. The
expected value differs by structure (see `plan.md` `#### 7 本は同質ではない`):

| Group | Files | Expected under both shells |
|---|---|---|
| Whole-file guard (6) | `ta-39`, `ta-43`, `ta-44`, `ta-45`, `ta-46`, `ta-47` | **rc=3**, with the `pg_extra_contract_skip` diagnostic present |
| **Section-scoped skip (1)** | **`ta-49`** | **rc follows the preceding layer-A TCs (0 or 1)** — never 3 — with the layer-B SKIP diagnostic present. If layer A recorded a failure, the Finalize precedence requires **rc=1** |

Cross-shell **identity** is the property under test in both groups; only the expected value differs.

**If `dash` cannot be resolved, this case FAILs — it must not be skipped (F6).** This mirrors the R-026
ruling that a timeout firing is a FAIL rather than a SKIP, and for the same reason: running only one
shell and reporting green would reproduce the very "silently passes" class this PBI exists to close.
The contract TA records which shells it actually ran in the evidence.

Rationale (measured): top-level `return` is undefined behaviour in POSIX. `dash` treats
`return 0 2>/dev/null` as succeeding and **ends the script**; `bash` treats it as failing, so
`|| true` swallows the failure and **the body runs anyway** while `|| exit 0` still ends the script.
CI runs `sh tests/run-tests.sh` on `ubuntu-latest`, where `/bin/sh` is dash. Consequently, before
migration, the four `|| true` files never reach the tail `pg_extra_contract_finalize` in CI (case D's
core mechanism) and silently run their bodies on a bash developer machine — **local GREEN does not
imply CI correctness**. The mutation that restores the old idiom is **M-15**; it must fail in **both**
directions (dash: probe returns rc=0; bash: the body runs).

> This case gives local two-shell coverage regardless of whether the CI workflow itself is pinned to a
> shell. Pinning CI (R-022) touches `.github/workflows/**`, a **Hardening Override** path, so it is
> proposed as a patch for Human application only — see `plan.md` `## Human C-3 の判断事項` HJ-1.

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
| M-13 | leave an already-migrated file in `_pending_migration`, **or** resolve the allowlist by the predicate "has no helper bootstrap" instead of the explicit list | TC-24 FAIL (list is not empty at Slice 2 completion) / TC-16 FAIL (predicate auto-exempts a marker-less new file) | **2**（list 側は TC-24 の完了時判定）/ **1**（predicate 側は TC-16 で Slice 1 から検出可能） |
| M-15 | restore the old early-exit idiom in one migrated file — replace its `pg_extra_contract_skip` call with `return 0 2>/dev/null \|\| true` | **TC-29 FAIL in both directions**: under **dash** the file ends before the tail finalize, so the force-fail probe returns **rc=0** instead of 1; under **bash** the guard falls through and the **body runs** (prerequisite-absent output plus a spurious `[FAIL]`). A kill observed in only one shell does **not** count — the evidence must record both (R-021) | **1** |
| M-16 | make `pg_extra_contract_finalize` return the computed rc in harness mode instead of an explicit `return 0` (equivalently: end it with a bare `[ "$fail" -gt 0 ]`) | **TC-26 FAIL** — the sourced suite truncates: the marker line of the file after the failing one and the `Results:` line are both absent (R-024) | **1** |
| M-17 | weaken the marker detection spec — anchor strictly on `$` with no trailing-space tolerance, **or** drop the first-20-lines restriction so heredoc bodies are scanned | **TC-09 FAIL** — the strict anchor yields 0 matches on a marker line with a trailing space; the unrestricted scan counts a heredoc occurrence as a second marker (R-027) | **1** |
| M-18 | drop the unique string / test-id from the probe message (keep the `fail` increment) | **TC-12 FAIL** — (b) still returns rc=1 but `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>` is absent, so the AND condition fails. This is the mutation that proves the pass condition is not rc-only (R-029-1) | **1** |
| M-19 | change the contract TA's discovery glob (e.g. to `ta-[0-9]*.sh`) so it no longer equals the runner's extras glob | **TC-28 FAIL** — the two sets differ. Note TC-09 / TC-10 would still pass over the narrowed set, which is why the equality is asserted separately (R-035) | **1** |
| M-14 | (a) leave an already-migrated file's basename in `_pending_migration`; (b) put a name that does not exist under `tests/extras/` in it; (c) make `_pending_migration` emit the **entire runtime inventory** (i.e. replace the heredoc body with the discovery output, keeping the function syntactically valid) so the covered set collapses | **TC-25 FAIL** — (a) migrated file still listed / (b) non-existent entry / (c) **all three** set/execution assertions must fire **individually**: covered-set-minus-self is empty, `_pending_migration` is no longer a proper subset (it equals the discovered set), and TC-12 / TC-13 report zero executed files. Because (c) is killed by four independent paths (per-line check 2 also fires on every entry), the evidence must record **which assertion fired**: the contract TA prints one line per failing assertion, and the mutation is only counted as killed by ①②③ when **all three lines are present in the log**. A kill by per-line check 2 alone does **not** demonstrate ①②③ | **1** |

> **M-13 と M-14 の関係**: 同じ「移行済みファイルが allowlist に残る」欠陥クラスを、
> M-13 は **Slice 2 完了時点の allowlist 空判定（TC-24）**で、M-14 は **Slice 1 の各行健全性
> 判定（TC-25）**で検出する。M-14 は M-13 を置き換えるのではなく、検出時期を Slice 1 まで
> 前倒しする（MN-E）。(b)(c) は M-13 が扱っていなかった追加の欠陥形態である。
>
> **既知の限界（構文破損は変異として使えない / MN-H）**: 第 3 ラウンド版の (c) は
> 「heredoc 終端を壊してリストを過大化する」だったが、**実測で再現しない**。終端を壊すと
> `cat <<'EOF'` が関数の `}` ごと飲み込み、contract TA は **parse error（`syntax error:
> unexpected end of file`）で rc=2** になる。TC-25 は実行すらされないので「TC-25 が検出する」
> という帰属自体が誤りだった。さらに **rc=2 は本 contract の harness-only 誤用の名前空間**
> であり、構文破損を「harness-only が正しく拒否された」と読み違えうる。**構文破損は
> shell の parse エラーとして扱い、変異による検出力の実証には用いない**（(c) を
> 構文的に妥当な「全件出力」変異へ差し替えた理由）。この読み違いの余地は本 PBI の
> scope では解消せず、既知の限界として記録するにとどめる。

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
>
> **注記 1（AC-2 (c) の対象本数 — 本表では確定しない / F3）**: R-021 の実測により、
> 早期脱出は **`ta-39` / `ta-43` / `ta-44` の 3 本ではなく 7 本**（うち rc=3 の対象は
> **ファイル全体ガード 6 本**、`ta-49` は節スキップ）であることが判明した。
> しかし **AC-2 (c) の正本は `pbi-input.md` の受入基準節**であり、そこでは現在も
> **3 本**のままである。**本表は写像のみを持つ**という宣言に従い、
> **本表で対象を 7 本（または 6 本）へ拡張して確定しない**。
> **正本の更新可否は Human 裁定事項 `HJ-5`**（`todo.md` の `H-06`）として提示している。
> **`pbi-input.md` は本反映で編集していない**ため、
> `pbi-input.md` 側の「層 A の 3 本」という記述は **HJ-5 の裁定まで stale のまま**である
> （`plan.md` は層 A の一覧について pbi-input を参照するため、辿ると 3 と 7 が食い違う。
> これは**既知の未確定点であり隠していない**）。
> 裁定が済むまで、TC-17 / TC-29 は plan の
> `#### 7 本は同質ではない` を実装上の対象定義として用いる。

| AC | 内容（要約） | Tests | Slice |
|---|---|---|---|
| AC-1 | standalone で `fail > 0` / 誤動作でも exit 0 を返すものが 0 件（実行ベース判定・件数非固定） | TC-09, TC-10, TC-11, TC-12, TC-13, TC-16, TC-20, **TC-28**（検査集合 == runner の source 集合 / R-035）, **TC-29**（`\|\| true` 型が CI で finalize に到達しない経路 / R-021） | **1（層 A 12 本の範囲）/ 2（runtime discovery で得た全 `ta-*.sh`）** |
| AC-2 (a) | 層 A の fail 注入 standalone が exit 1 | TC-04, TC-05, TC-12 | 1 |
| AC-2 (b) | 同じ fail 注入状態で source 経路が完走し集計される | TC-01, TC-14, TC-15, **TC-26**（非 0 `return` でも途中打ち切りしない / R-024） | 1 |
| AC-2 (c) | 前提未充足 SKIP の rc が「検査していない」を表明（**rc=3**、rc=0 不可） | **TC-17**, **TC-29**（dash / bash 双方）, TC-13 ※**対象本数は注記 1 を参照（正本は `pbi-input.md`・裁定待ち）** | 1 |
| AC-2 (d) | カウンタ初期化の存在（helper が担保。層 A 12 本は全数が未初期化） | TC-03, TC-04 | 1 |
| AC-3 | 層 B + 層 C 41 本の standalone が明示メッセージ付き exit 2 | TC-02（synthetic）, TC-11（全件。**ループは Slice 1 から回すが対象 0 件で vacuous**） | **1（TC-02 のみ）/ 2（TC-11 で充足）** |
| AC-4 | `sh tests/run-tests.sh` が回帰しない + **runtime `tail -1`** 最終ファイルの `[PASS]` 出現 | **TC-14**, TC-15, TC-21 | 1（Slice 2 でも再実行） |
| AC-5 | 検査が回帰テスト化され、新規追加の伝播漏れを将来も検出（正規述語）。**移行期間 allowlist を恒久化しない** | TC-09, TC-10, TC-16, TC-20, **TC-25**, **TC-24** | **1（allowlist 付きで成立。逆向きリークは TC-25 が Slice 1 で担保）/ 2（TC-24 で allowlist 空）** |
| AC-6 | README 規約 9（rc 0/1/2/3・marker・probe・rc2 名前空間）+ #914 handoff writeback | **TC-19**（README）+ handoff CLOSED マーカーの grep（DoD） | **1（TC-19）/ 2（writeback）** |
| AC-7 | 追加した検査が **修正前実装で FAIL** することの実証 | Verification Plan の pre-fix HEAD evidence + **M-01〜M-19**（各 M の Slice は Mutation Matrix に従う） | 1（Slice 1 で走る M。**M-13 の predicate 側 / M-14 / M-15〜M-19（全 Slice 1）を含む**）/ 2（M-09 / M-11 / M-13 の list 側） |
| **AC-8**（派生・pbi-input 正本外） | `ta-26` TC-33（#914 AC-9 ゲート）が移行後も**空振りせず**同等以上の検出力を保つ | **TC-22**, M-09 | **2** |

補助的な設計制約の紐付け（AC 直属ではないが Exit Criteria に含む）:

| 制約 | Tests | Slice |
|---|---|---|
| **original の nonzero rc を握り潰さない（Finalize precedence の保持）** | **TC-06** ※ **HJ-4（R-030）の裁定次第で再定義されうる**。案 (a) 2 値化を採ると本行は落ちる | 1 |
| **早期脱出イディオムの禁止**（`return 0 2>/dev/null \|\| …` を型を問わず使わない / R-021） | **TC-17**, **TC-29**, M-15 | 1 |
| **source 経路で非 0 `return` しない**（R-024） | **TC-26**, M-16 | 1 |
| **marker 検出の正規表現仕様 + 先頭 20 行限定**（R-027） | **TC-09**, M-17 | 1 |
| **probe / harness-only の合格条件を rc 単独にしない**（R-029） | **TC-11**, **TC-12**, **TC-27**, M-18 | 1 |
| **検査集合 == runner の source 集合**（R-035） | **TC-28**, M-19 | 1 |
| **`seven` を書かず runner から動的導出する**（R-034） | TC-15, TC-22 | 1（TC-15）/ 2（TC-22） |
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

- [ ] **TC-01, TC-02, TC-03, TC-04, TC-05, TC-06, TC-07, TC-08, TC-09, TC-10, TC-11, TC-12,
      TC-13, TC-14, TC-15, TC-16, TC-17, TC-19, TC-20, TC-21, TC-23（synthetic 側）, TC-25,
      TC-26, TC-27, TC-28, TC-29 PASS**（TC-26〜TC-29 は R-024 / R-029-3 / R-035 / R-021 由来）。
      **TC-06 は HJ-4（R-030）の裁定次第で再定義されうる**ため、C-3 で (a) 2 値化が選ばれた
      場合は本行から TC-06 を外し precedence 表と併せて改訂する。
      **TC-11 は Slice 1 では対象 0 件の vacuous PASS でよい**が、その場合は
      `evidence/test-runs/harness-only.log` に **「対象 0 件」を明示記録**すること
      （空振りを黙って PASS にしない / INFO-1）。AC-3 の全件充足は Slice 2
- [ ] **M-01〜M-08, M-10, M-12（synthetic 側）, M-13（predicate 側）, M-14 が期待どおり FAIL**。
      **M-13 の predicate 側は Slice 1 の必須ゲート**: allowlist を `_pending_migration` から
      「helper bootstrap を持たない」述語へ差し替える変異を入れ、**TC-16 が FAIL する**ことを
      実証する。これは MJ-E の是正（contract TA 内蔵の明示リスト `_pending_migration`）が
      実効を持つことの唯一の実行ベース証拠であり、
      Slice 2 へ繰り延べてはならない
- [ ] **AC-2 (a)(b)(c)(d), AC-4, AC-7 を充足**
- [ ] **AC-1 を層 A 12 本の範囲で充足**（全件の充足は Slice 2）
- [ ] **AC-3 を TC-02（synthetic）で充足**（層 B + 層 C 41 本の全件充足は Slice 2）
- [ ] **AC-5 を移行期間 allowlist 付きで充足**（allowlist 空の証明は Slice 2 / TC-24）
- [ ] **AC-6 を TC-19（README）で充足**（`TASK-0914/handoff.md` writeback は Slice 2）
- [ ] **pre-fix HEAD で contract TA が FAIL する evidence が存在する**（AC-7 / R-011）
- [ ] runtime inventory unclassified=0、test-id（basename）重複=0（**TC-20 は runtime discovery で得た全 `ta-*.sh` を対象（allowlist 対象外）**）
- [ ] **contract TA を含むフルスイート 1 回 + contract TA 単独 2 回が 0 failed**
      （R-017 の CI 時間裁定により「フルスイート 3 連続」から読み替え。
      副作用の受容根拠は plan の `### 緩和の副作用と、それを受容する裁定根拠` 参照）
- [ ] evidence includes actual file count but test does not hardcode it
- [ ] evidence includes measured CI duration (baseline 231s との差分)
- [ ] **移行期間 allowlist が contract TA 本体の `_pending_migration`（明示リスト）で解決され、
      「helper bootstrap を持たない」等の述語解決になっていない**（述語だと新規追加ファイルが
      黙って除外され TC-16 / M-06 が空振りする）
- [ ] **`_pending_migration` の内容が Task 1 の inventory から機械生成され、生成コマンド・生成物・
      heredoc への転記との `diff` 照合結果が evidence に残っている**
- [ ] **TC-17 / M-10 が sandbox（repo 実コピー + 述語文字列除去）で実走済み**
      （Slice 2 へ繰り延べていない / plan `#### TC-17 / M-10 の sandbox 構成手順`）
- [ ] **M-15〜M-19 が期待どおり FAIL**（R-021 / R-024 / R-027 / R-029 / R-035）。
      **M-15 は dash と bash の両方で kill されたことが evidence に記録されている**
      （片方だけの kill は不十分 / R-021）
- [ ] **早期脱出 7 本のイディオムが除去され、`grep -rn 'return 0 2>/dev/null' tests/extras/` が
      層 A について 0 件**（R-021。`ta-31` の分岐内 4 箇所は層 B のため Slice 2 で解消）。
      **内訳**: ファイル全体ガード **6 本**（`ta-39` / `ta-43` / `ta-44` / `ta-45` / `ta-46` /
      `ta-47`）は `pg_extra_contract_skip` 経由へ移行 / **`ta-49` は節スキップ**のため
      `pg_extra_contract_skip` を使わず末尾 finalize へ落とす（**rc=3 を要求しない** / F2）
- [ ] **TC-16 が実 `tests/extras/` へ書き込まず sandbox で実行されている**（R-028）
- [ ] **per-file timeout が 180s 以上で実装され、`timeout(1)` 不在環境でも動くフォールバックを
      持ち、timeout 発火が FAIL（SKIP ではない）として扱われる**（R-026）
- [ ] **`seven` 等の env 件数がテスト文言に残っていない**（R-034。TC-15 / TC-22 とも
      `run-tests.sh` から動的導出）
- [ ] **HJ-1〜HJ-5 が C-3 で裁定済み**（plan `## Human C-3 の判断事項`）

### Slice 2 の DoD（Slice 2 着手時に Mode 再判定のうえ適用）

- [ ] **TC-11（Slice 1 では対象 0 件で vacuous。ここで初めて実対象を持って実効になる）,
      TC-18, TC-22, TC-23（`ta-26` 実地側）, TC-24 PASS**
- [ ] **M-09, M-11, M-13（list 側 = 移行済みファイルが `_pending_migration` に残存）が期待どおり FAIL**
      （M-13 の predicate 側と M-14 は Slice 1 で実証済み）
- [ ] **AC-3 を層 B + 層 C 41 本の全件で充足**（TC-11）
- [ ] **AC-1 を runtime discovery で得た全 `ta-*.sh` で充足**（allowlist 空の状態で再評価）
- [ ] **AC-5 を allowlist 空の状態で充足**（TC-24）。**`_pending_migration` 関数ごと削除されている**
- [ ] **AC-6 の writeback 側**: `TASK-0914/handoff.md` §3 の対象 2 行に CLOSED マーカーが
      grep で確認できる
- [ ] **AC-8 を充足**（TC-22 / M-09。`ta-26` TC-33 の検出力が空振りしない）
- [ ] **TC-01〜TC-29 を通しで再実行して PASS**（Slice 1 の DoD が Slice 2 の変更で退行していないこと）
- [ ] **`ta-31` の分岐内 `return 0 2>/dev/null || true` 4 箇所が解消され、
      `grep -rn 'return 0 2>/dev/null' tests/extras/` が全件 0 件**（R-021 の残余）
