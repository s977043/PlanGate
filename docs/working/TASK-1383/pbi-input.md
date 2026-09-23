# PBI INPUT PACKAGE — TASK-1383 / #1383

> Parent: #870
> Unblocks: #1381
> Goal: ai-loop V2 Delivery first release boundary を executable evidence で成立させる
> Status: EXECUTABLE SPECIFICATION IN PROGRESS / PRODUCTION RUNTIME BLOCKED

## Current facts

- V2 canon requires Delivery before Evolution.
- #1383 owns exactly two release-boundary paths:
  - `FAIL -> Diagnose -> Repair -> PASS -> MERGE_READY`
  - `NO_PROGRESS -> safe STOP / ESCALATE`
- `scripts/ai-loop-v2/` does not exist on main.
- V2 core artifacts are canonized but not yet implemented as V2 runtime/schema.
- #1369 Worker Architecture / Contract is closed and can be consumed as execution-backend boundary.
- #1025, #894, #874, #1285 remain open and own required Delivery contracts.
- #1329 requires an implementation-PR semantic invalidation review before V2 runtime enforcement is introduced.

## Dependency ownership matrix

| Concern required by #1383 | Owner | Required minimum output | #1383 must not own |
|---|---|---|---|
| Run position / revision CAS / harness binding | #1025 | V2 RunState transition contract + `revision` CAS + `harness_manifest_ref` invariant | durable-state architecture redefinition |
| verifier blocking / progress / no-progress / decision | #894 | LoopContract budget + VerificationResult / FailureRecord / Decision Engine semantics | new stop taxonomy / duplicate control contract |
| Run-level evidence projection | #874 + #1285 | V2 RunEvidence event-projection boundary and binding contract sufficient for E2E evidence refs | Legacy RunEvidence mutation / full metric expansion |
| Worker attempt contract | #1369 / #1368 | success/failure is control fact, not provider text; bounded attempt; no self-declared completion | provider-specific worker implementation |
| PR convergence pattern | Legacy Evidence #873/#917 | MERGE_READY preconditions / collector-reconciler pattern as evidence only | making Legacy implementation V2 canon |
| I1 -> I4 transition | #1329 | M-1/M-2/M-3 before/after + semantic invalidation review | canon self-exemption |

## Exact unblock contract

#1383 does **not** require every owner Issue to be globally complete.

It requires only the following **integration-ready subset** to be stable enough to consume:

1. RunState
   - run identity
   - lifecycle state
   - revision
   - plan/source binding
   - harness_manifest_ref immutable during a run
2. VerificationResult
   - verifier identity
   - status = pass/fail/unavailable/inconclusive
   - bound artifact/source/head refs
3. FailureRecord
   - observation
   - normalized failure fingerprint
   - cause hypothesis separate from observation
   - repairability signal
4. Decision Engine
   - output action = continue/repair/replan/stop
   - terminal outcome separate from stop reason
   - no-progress uses evidence/artifact/failure delta, not retry count alone
5. RunEvidence boundary
   - event/evidence refs can be projected deterministically
   - no need for full North Star §18 metrics in this slice
6. Worker boundary
   - worker self-report != verification success
   - required worker attempt without success evidence cannot advance

## Representative E2E paths

### Path A — Repair convergence

```text
LoopContract fixed
 -> RunState EXECUTING
 -> Worker attempt
 -> VerificationResult FAIL
 -> FailureRecord
 -> Decision = repair
 -> RunState REPAIRING
 -> repair artifact delta
 -> VerificationResult PASS
 -> Decision = continue
 -> PR convergence evidence
 -> Terminal Outcome MERGE_READY
```

### Path B — No progress stop

```text
Verification FAIL
 -> FailureRecord F1
 -> repair attempt
 -> Verification FAIL
 -> FailureRecord F2
 -> progress comparator:
      failure/evidence/artifact delta = insufficient
 -> Decision = stop
 -> Stop Reason NO_PROGRESS
 -> Terminal Outcome HUMAN_ESCALATED or BLOCKED
```

The exact terminal outcome is determined by existing policy/decision contract. #1383 does not invent a new outcome.

## Non-goals

- Replan E2E
- Evolution / Candidate / Experiment
- provider-specific production Worker
- V2 RunEvidence full metrics schema
- HarnessManifest generator redesign
- new Stop Reason
- new top-level artifact
- Legacy ai-loop promotion to V2 canon
- Production auto-merge


## Review refinement — executable spec before runtime

#870 の DoD が要求するのは **Delivery first release boundary の E2E fixture が CI で通ること**であり、Production runtime の存在ではない。

また #1329 は **inactive fixture / evidence-only change は semantic invalidation rule だけでは invalidation としない** と明記している。

したがって #1383 の第一実装は `scripts/ai-loop-v2/**` ではなく、tests 配下の **non-authoritative executable specification** とする。

```text
tests/fixtures/ai-loop-v2/delivery/
  repair-convergence.json
  no-progress-stop.json

tests/extras/
  ta-87-ai-loop-v2-delivery-e2e.sh
```

この spec は:
- canon / owner issue の現時点 semantic を検証可能な event trace として固定する
- Production dispatcher / state store / verifier / Decision Engine ではない
- owner contract の代替正本にならない
- M-2 を動かさない
- runtime 実装時には同じ fixture を production adapter に対して再利用する

これにより Delivery-before-Evolution gate を **runtime namespace を作る前に**検証できる。