# TEST CASES — TASK-0921

## Contract RC Table

| Capability / condition | Expected rc |
|---|---:|
| standalone-capable, all pass | 0 |
| standalone-capable, internal fail > 0 | 1 |
| harness-only, direct invocation | 2 |
| standalone-capable, original command exits nonzero | preserve original rc |
| harness source, any individual extras | no process exit; runner decides final rc |

## Helper Unit / Synthetic Cases

### TC-01 Harness mode is non-invasive

Given `PG_HARNESS_SOURCED=1` and valid `FIXTURES_DIR`, when init is called, then pass/fail are not reset, no exit trap is installed, and helper returns 0.

### TC-02 Harness-only direct misuse

Given no valid harness marker, when a `harness-only` script is invoked, then body sentinel is not created, stderr names the test and canonical runner, and rc=2.

### TC-03 Standalone pass

Given standalone-capable init and `fail=0`, when script exits 0, then cleanup runs, summary is emitted, final rc=0.

### TC-04 Standalone internal fail

Given standalone-capable init and `fail=1`, when script exits 0, then final rc=1.

### TC-05 Early exit propagation

Given standalone-capable init, `fail=1`, and test body executes `exit 0` before normal tail, then exit trap changes final rc to1.

### TC-06 Preserve specific nonzero rc

Given original rc=3, then final rc remains3 whether fail is0 or positive. Generic test failure must not hide a more specific command failure.

### TC-07 Cleanup

Given two registered tmp paths and an unregistered sentinel path, on standalone exit only registered paths are deleted; sentinel remains.

### TC-08 Invalid capability

Given unknown capability string, helper fails closed before body with nonzero rc and diagnostic.

## Inventory / Dynamic Cases

### TC-09 Exactly one capability marker

For every runtime-discovered `ta-*.sh`, marker count is exactly1 and value is one of `standalone-capable`, `harness-only`.

### TC-10 Marker and init agree

For every file, marker value and `pg_extra_contract_init` second argument agree. Comment-only token elsewhere does not satisfy this test.

### TC-11 Harness-only all-file execution

For every marker=harness-only file, `sh "$file" </dev/null` returns2, emits standard diagnostic, and creates no body sentinel/tmp/audit evidence.

### TC-12 Standalone-capable all-file force-fail

For every marker=standalone-capable file, target-specific force-fail probe returns1. Non-target file behavior is unchanged.

### TC-13 Standalone-capable normal execution

For every marker=standalone-capable file, clean direct execution with `</dev/null` returns0 and output contains no `[FAIL]`.

### TC-14 Harness regression

`sh tests/run-tests.sh` reaches the final Results line, executes a known file after ta-39, and ends with 0 failed. This detects source-time early exit, not just individual test correctness.

### TC-15 External env contamination

With the seven guarded env values pre-set, runner and standalone-capable normal loop behave as clean baseline; harness-only still exits2 directly.

### TC-16 New file without contract

Adding a temporary `ta-zz-probe.sh` without marker/init makes contract TA fail. Adding only a marker but no matching init also fails.

## Early Exit / Trap Compatibility

### TC-17 ta-39 prerequisite early exit

In a sandbox where doc-light prerequisite is absent, normal standalone exits0; with force-fail target it exits1. Harness source skips without terminating the suite.

### TC-18 ta-26 parity

Before/after migration, ta-26 clean standalone rc, forced-failure rc, summary, cleanup, and full existing TC results are equivalent.

## Mutation Matrix

| ID | Mutation | Expected detection |
|---|---|---|
| M-01 | remove `fail > 0` branch from finalizer | TC-04 / TC-12 FAIL |
| M-02 | install exit trap in harness mode | TC-01 / TC-14 FAIL |
| M-03 | change harness condition to `FIXTURES_DIR` only | TC-15 FAIL |
| M-04 | allow unknown capability as standalone-capable | TC-08 FAIL |
| M-05 | place harness-only init after body sentinel | TC-02 / TC-11 FAIL |
| M-06 | hardcode current file count and add probe file | TC-09 / TC-16 FAIL |

## Traceability

| Issue AC | Tests |
|---|---|
| AC-1 | TC-09〜TC-13, TC-16 |
| AC-2 | TC-04, TC-05, TC-12, TC-17, TC-18 |
| AC-3 | TC-01, TC-14, TC-15 |
| AC-4 | TC-09〜TC-16 |
| AC-5 | README review + TC-16 |
| AC-6 | TC-12〜TC-15 + handoff review |

## Exit Criteria

- [ ] TC-01〜TC-18 PASS
- [ ] M-01〜M-06 each causes expected FAIL
- [ ] runtime inventory unclassified=0
- [ ] three consecutive full suite runs 0 failed
- [ ] evidence includes actual file count but test does not hardcode it
