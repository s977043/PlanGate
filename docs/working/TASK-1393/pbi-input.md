# PBI INPUT PACKAGE — TASK-1393 / #1393

> Parent owner: #894
> Event contract: #1391
> RunState shape: #1392
> Delivery gate: #1383
> Integration: #1395
> Status: PLAN-ONLY

## Goal

V2 の immutable VerificationResult / FailureRecord と pure Decision Engine を、Delivery first release boundary に必要な最小範囲で実装する。

## Responsibility

Owns:
- VerificationResult validation
- FailureRecord validation
- deterministic progress assessment
- pure decision from already-observed facts

Does not own:
- verifier execution
- Worker execution
- changed-path observation
- RunState persistence
- RunEvent persistence
- PR API
- merge/promotion

## First-slice decisions

Required:
- deterministic implementation Verify FAIL + repairable FailureRecord -> repair
- deterministic FAIL cannot be overridden by model PASS
- same failure + no artifact/evidence/blocker progress -> stop + HUMAN_ESCALATED + NO_PROGRESS
- fresh deterministic PASS + PR convergence PASS -> stop + MERGE_READY
- unavailable/inconclusive cannot yield MERGE_READY

Deferred to a later #1393 slice (Human decision 2026-09-25, first slice accepts only VERIFYING / DIAGNOSING / PR_CONVERGING):
- Initial Plan Verification PASS -> continue (PLAN_VERIFYING decisions)

## Input authority

Decision Engine consumes records/observations. It must not trust:
- Worker “done”
- fixture `no_progress`
- fixture `scope_ok`
- fixture Outcome/Stop Reason
- pre-authored decision

Progress and terminal decision are derived values.
