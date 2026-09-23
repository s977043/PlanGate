# TASK-1383 — Delivery E2E Dependency Matrix

## Purpose

#1383 が「全 Issue 完了待ち」にならないよう、各 owner から必要な **minimum consumable contract** を固定する。

## Readiness states

| Dependency | Current state | Minimum needed by #1383 | Readiness verdict |
|---|---|---|---|
| #1025 RunState | V2 rebaseline open | transition semantics + revision CAS + harness ref invariant | BLOCKED |
| #894 Decision / Verification / Failure | V2 rebaseline open | result/failure/decision/progress semantics | BLOCKED |
| #874 V2 RunEvidence | Legacy implementation exists; V2 rebaseline open | projection/binding boundary only | PARTIAL |
| #1285 RunEvidence metrics | design issue open | no full metrics required; only avoid incompatible schema decisions | NON-BLOCKING unless it changes core field ownership |
| #1369 Worker contract | closed | worker success != verification success, bounded attempt | READY |
| #873/#917 PR convergence | Legacy Evidence complete | reusable fixture/pattern only | READY AS EVIDENCE |
| #1329 I4 transition | operational rule exists | implementation PR preflight | READY FOR PREFLIGHT |

## Gate A — Contract integration readiness

Before runtime code:

- [ ] #1025 provides stable V2 RunState minimum subset
- [ ] #894 provides stable V2 VerificationResult / FailureRecord / Decision Engine minimum subset
- [ ] #874/#1285 do not conflict on the RunEvidence fields consumed by E2E
- [x] #1369 Worker control facts available
- [x] Legacy PR convergence evidence available
- [x] #1329 implementation review procedure available

## Gate B — Runtime implementation readiness

After Gate A:

- [ ] record M-1/M-2/M-3 on base SHA
- [ ] reviewer answers semantic invalidation question
- [ ] indeterminate => invalidation candidate
- [ ] implementation PR does not modify canon 7 to preserve its own exception
- [ ] Human-owned merge boundary remains unchanged

## Anti-dependency rules

#1383 must not:

1. close #1025/#894/#874 by proxy
2. define fields that owner contracts have not stabilized
3. copy Legacy state enums into V2
4. treat Legacy `AUTO_APPROVED` as V2 success
5. make retry count itself equal NO_PROGRESS
6. encode provider error strings into V2 stop semantics
7. require all North Star metrics before Delivery E2E can run
