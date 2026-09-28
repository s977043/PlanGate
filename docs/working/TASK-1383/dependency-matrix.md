# TASK-1383 — Delivery E2E Dependency Matrix

## Purpose

#1383 が「全 Issue 完了待ち」にならないよう、各 owner から必要な **minimum consumable contract** を固定する。

## Readiness states

| Dependency | Current state | Minimum needed by #1383 | Readiness verdict |
|---|---|---|---|
| #1025 RunState | minimum V2 semantics fixed in canon; implementation slice #1392 open | transition semantics + revision CAS + harness ref invariant | CONTRACT READY / RUNTIME PENDING |
| #894 Decision / Verification / Failure | minimum V2 semantics fixed in canon; implementation slice #1393 open | result/failure/decision/progress semantics | CONTRACT READY / RUNTIME PENDING |
| #874 V2 RunEvidence | projection boundary fixed in canon; implementation slice #1391 open | projection/binding boundary only | CONTRACT READY / RUNTIME PENDING |
| #1285 RunEvidence metrics | design issue open | no full metrics required; only avoid incompatible schema decisions | NON-BLOCKING unless it changes core field ownership |
| #1369 Worker contract | closed | worker success != verification success, bounded attempt | READY |
| #873/#917 PR convergence | Legacy Evidence complete | reusable fixture/pattern only | READY AS EVIDENCE |
| #1329 I4 transition | operational rule exists | implementation PR preflight | READY FOR PREFLIGHT |

## Gate A — Contract integration readiness

Before runtime code:

- [x] #1025 minimum V2 RunState semantics are stable enough to implement via #1392
- [x] #894 minimum V2 VerificationResult / FailureRecord / Decision Engine semantics are stable enough to implement via #1393
- [x] #874/#1285 field ownership is reconciled; #1391 owns only the minimal projection spine
- [x] #1369 Worker control facts available
- [x] Legacy PR convergence evidence available
- [x] #1329 implementation review procedure available

## Gate B — Runtime implementation readiness

Gate A means **contract semantics are ready**, not that executable owner surfaces already exist.

Owner-backed runtime DAG:

```text
#1391 RunEvent spine / RunEvidence projection
  ├─> #1392 RunState CAS / crash recovery
  └─> #1393 Verification / Failure / Decision core
        (pure core; #1392 data contractをconsumeするがruntime完了待ちは不要)

#1392 + #1393 consumable
  -> #1395 owner-backed Delivery E2E integration
  -> #1383 evidence / #1381 unblock decision
```

Preflight measured on main `b2234bd1097f7b741d372e3353d1877932401731`:

- [x] M-1 = baseline: no matching V2 schema filename/content under `schemas/**`
- [x] M-2 = baseline: no `scripts/ai-loop-v2/**` / `bin/ai-loop-v2/**`
- [x] M-3 = baseline: exactly the known four Legacy files
  - `scripts/ai-loop/corpus_hash.py`
  - `scripts/ai-loop/run_evidence.py`
  - `scripts/ai-loop/test_corpus_hash.py`
  - `scripts/ai-loop/test_run_evidence.py`
- [x] current #1387 tests-only diff is not a Production semantic enforcement surface
- [x] #1391/#1392/#1393/#1395 runtime implementation is a semantic invalidation candidate
- [x] implementation PR must not modify canon 7 to preserve its own exception
- [x] review level: I3 minimum for Verifier/Gate runtime; I4 if protected Evaluation Harness or Human-owned boundary is touched
- [x] Human-owned merge boundary remains unchanged

**Runtime availability remains BLOCKED until #1391/#1392/#1393 are consumable.**

## Anti-dependency rules

#1383 must not:

1. close #1025/#894/#874 by proxy
2. define fields that owner contracts have not stabilized
3. copy Legacy state enums into V2
4. treat Legacy `AUTO_APPROVED` as V2 success
5. make retry count itself equal NO_PROGRESS
6. encode provider error strings into V2 stop semantics
7. require all North Star metrics before Delivery E2E can run
