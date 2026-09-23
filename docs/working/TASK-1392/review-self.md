# SELF REVIEW — TASK-1392 PLAN

## I0 findings

### R-1 — multi-file WAL is unnecessary for first slice

Initial parent design inherited Legacy state/event WAL concerns. If V2 first slice stores RunState and accepted events in independently committed files, half-commit is unavoidable without a transaction protocol.

Adopted simpler equivalent:
- one atomic snapshot contains state + event stream
- one replace is the commit unit
- lock serializes CAS
- directory fsync defines durable completion

Result: half-commit is removed structurally.

### R-2 — revision / generation / event_seq must be distinct

- revision: state transition version
- generation: any durable snapshot commit, including non-state evidence/conflict
- event_seq: contiguous event order

This allows verification/failure/decision evidence without inventing state transitions.

### R-3 — conflict evidence cannot use failed expected revision as committed state

Conflict recording is a separate generation-only commit against current state revision. It records expected vs actual revision but does not change RunState revision.

### R-4 — successful response after replace but before directory fsync is unsafe

API success is returned only after directory fsync.

### R-5 — Terminal Outcome must not be encoded as a state transition

A transaction containing terminal `decision_made` cannot also append `state_transitioned` afterward. Terminality lives in RunEvent/RunEvidence, not Lifecycle State.

Resolution:
- terminal decision and transition request are mutually exclusive
- terminal decision does not increment RunState revision just to encode completion
- no later Run event is allowed

## Verdict

PASS for plan. Runtime remains gated by #1391 consumability and #1329 implementation preflight.
