# EXECUTION PLAN — TASK-1383 / #1383

## Goal

V2 Delivery first release boundary の2経路を、owner contracts を再実装せず executable fixture で統合する。

## Current verdict

```text
Contract integration planning: GO
Non-authoritative executable specification: GO
Production V2 runtime: BLOCKED
```

The executable specification may proceed under tests only. It is not a runtime authority and does not satisfy owner implementation issues by proxy.

## Strategy

### Stage 0 — Contract integration readiness

Owner Issue の責務を横取りせず、#1383 が consume する最小フィールド / semantic を固定する。

Deliverables:

- dependency matrix
- two E2E trace specifications
- artifact/event ownership map
- negative/mutation cases
- implementation entry checklist

No `scripts/ai-loop-v2/**` in this stage.

### Stage 1 — Owner subset confirmation

#1025 / #894 / #874 の各 owner に #1383 required subset を comment で提示する。

Acceptance:

- owner issue側で衝突が見つかったら #1383 planをrebase
- owner全体のcloseは要求しない
- subsetが stable / accepted になれば Gate A を進める

### Stage 2 — Executable specification (allowed now)

Production runtime を作らず、tests 配下に event-trace contract を置く。

```text
tests/fixtures/ai-loop-v2/delivery/
  repair-convergence.json
  no-progress-stop.json

tests/extras/
  ta-87-ai-loop-v2-delivery-e2e.sh
```

TA-87 は fixture を読み、canon invariant を検証する。

- Builder != Verifier != Decision Engine
- worker self-report alone cannot complete
- deterministic FAIL remains blocking
- repair requires fresh re-verification
- stale VerificationResult cannot be reused after artifact change
- Stage 2 fixture の `scope_ok` は宣言値として false case を検査するだけで、Production authority にしない
- MERGE_READY requires PR convergence evidence
- NO_PROGRESS is Stop Reason, not State
- no-progress uses failure/artifact/evidence delta
- harness_manifest_ref remains unchanged
- no merge side effect is represented

This is **non-authoritative executable specification**. Production dispatcher / store / evaluator is not implemented.

### Stage 3 — Owner-backed runtime integration

Contract Gate A is ready. Production implementation is split by owner:

```text
#1391 Event / Projection
 -> #1392 State / CAS
 -> #1393 Verify / Failure / Decision
 -> #1395 Integration
```

#1329 preflight baseline is measured on main `b2234bd1097f7b741d372e3353d1877932401731`: M-1/M-2/M-3 all remain at baseline.
The current tests-only PR does not establish runtime invalidation, but each runtime slice above is a semantic invalidation candidate.

Runtime code is therefore implemented in owner issues first and integrated only in #1395.

Runtime code should reuse the same Stage 2 fixtures as acceptance tests.

Production integration では `scope_ok` を Worker / fixture の自己申告から受け取って authority にしない。
actual changed paths / artifact delta を owner-backed collector から取得し、LoopContract `allowed_scope` と機械比較して導出する。
Stage 2 の `scope_ok` は、この後続 invariant を表現する non-authoritative placeholder に限定する。

### Stage 4 — E2E evidence

Path A asserts:

- Worker completion alone does not advance
- deterministic FAIL produces FailureRecord
- decision = repair
- artifact/evidence delta after repair
- re-verification occurs
- PASS + PR convergence conditions yield MERGE_READY
- no C-4/merge side effect

Path B asserts:

- equivalent repeated failure alone is not enough unless progress comparator says no meaningful delta
- comparator sees failure/evidence/artifact delta
- decision = stop
- Stop Reason = NO_PROGRESS
- finite termination
- outcome uses existing taxonomy

### Stage 5 — Review / release of #1381 gate

- I0 self-review
- I1+ independent review
- exact reviewed_at_sha
- CI green
- evidence link to #870
- explicit gate-release verdict to #1381

## Test-first plan

### Contract tests

- unknown lifecycle/state/outcome mixing => reject
- VerificationResult unavailable/inconclusive => cannot be treated as PASS
- deterministic FAIL cannot be overridden by model reviewer PASS
- missing harness_manifest_ref => invalid/inconclusive
- run harness ref changes mid-run => fail
- worker says complete, verifier missing => no advance

### Repair convergence mutation tests

Kill mutants:

1. skip re-verification after repair
2. ignore deterministic FAIL
3. generate MERGE_READY from worker self-report
4. reuse stale VerificationResult after artifact change
5. allow repair outside allowed scope
6. auto-merge after MERGE_READY

### No-progress mutation tests

Kill mutants:

1. retry-count-only stop
2. identical FailureRecord but changed artifact/evidence incorrectly treated as no progress
3. no artifact/evidence/failure change incorrectly treated as progress
4. NO_PROGRESS stored as Lifecycle State
5. stop without evidence refs
6. endless loop when budget exhausted

## Files in planning PR

- `docs/working/TASK-1383/pbi-input.md`
- `docs/working/TASK-1383/dependency-matrix.md`
- `docs/working/TASK-1383/plan.md`
- `docs/working/TASK-1383/test-cases.md`
- `docs/working/TASK-1383/todo.md`

## Production runtime implementation preconditions

1. Stage 2 executable specification green — satisfied on PR #1387
2. Gate A contract semantics complete — satisfied
3. #1329 M-1/M-2/M-3 base measurement — satisfied on `b2234bd1...`
4. semantic invalidation classification — runtime slices = YES candidate
5. review level — I3 minimum; I4 on protected Evaluation Harness / Human-owned boundary
6. each implementation branch is based on latest main at its start
7. #1391 -> #1392 -> #1393 become consumable before #1395 integration
8. no conflicting owner contract change in flight

## Replan triggers

- #1025 changes V2 RunState field ownership
- #894 changes Decision Engine action or progress semantics
- #874/#1285 changes RunEvidence projection ownership
- #1329 changes implementation invalidation procedure
- #870 changes Delivery first release boundary
- implementation requires a new top-level artifact

## Stop conditions

- owner contract must be duplicated inside #1383
- Delivery integration requires changing ai-dev public contract
- Legacy ai-loop must become runtime authority
- Candidate/Evolution logic becomes necessary
- Human C-4 / merge authority must change


## Why tests-only first is preferable

- #870 explicitly asks for an **E2E fixture**
- avoids inventing a premature production orchestrator
- does not create `scripts/ai-loop-v2/`, so M-2 remains unchanged
- #1329 explicitly separates inactive fixture/evidence-only changes from execution-surface invalidation
- creates reusable acceptance evidence for the later V2 runtime
- keeps owner implementation responsibilities with #1025/#894/#874

## Gate interpretation — executable spec is necessary but not sufficient

TA-87 が green でも、それ単独では #870 の「Delivery E2E が成立」を完了扱いしない。

TA-87 が証明するもの:
- current canon / owner assumptions が1本の trace として矛盾なく表現できる
- negative/mutation cases に対して契約が fail-closed になる
- later runtime が満たすべき acceptance fixture が存在する

TA-87 が証明しないもの:
- #1025 RunState implementation が実際に transition/CAS する
- #894 Decision Engine implementation が実際に判断する
- #874 V2 projection implementation が実際に再生成する
- real Worker / PR collector が event を生成する

Therefore:

```text
TA-87 green
  -> Executable Contract READY
  != Delivery Runtime E2E DONE
```

#1383 close / #1381 unblock には、後続の owner-backed adapter/runtime が **同じ fixture を通した evidence** か、Human が明示的に「spec-level fixture を #870 DoD の成立と認める」判断のどちらかが必要。
