# SELF REVIEW — TASK-1391 PLAN

> Review type: I0
> Scope: Plan-only
> Base: `b2234bd1097f7b741d372e3353d1877932401731`

## Perspectives

### Architecture

PASS after refinement.

The initial decomposition risked giving #1391 an independently persisted event writer while #1392 persisted RunState. That would recreate state/event half-commit.

Refinement:
- #1391 = event semantics + pure projection
- #1392 = durable transaction/persistence
- #1393 = decision semantics

### Responsibility / SSoT

PASS.

- authoritative logical source = accepted RunEvent stream
- RunEvidence = rebuildable projection/cache
- durable storage transaction is not duplicated here
- WAL remains #1392 internal storage mechanism, not a new domain SSoT

### Testability

PASS.

Negative and mutation targets cover identity, ordering, taxonomy, reference provenance, terminality, privacy, deterministic projection, and responsibility leakage.

### Governance

PASS for plan-only.

No runtime/schema/canon files are changed. Production implementation remains subject to #1329 and must not self-preserve the I1 exception.

## Review round 2 findings — resolved

### R-3 — event_seq / event_ref authority was ambiguous

Severity: major.

Initial plan let the producer present a RunEvent candidate already containing authoritative sequence/ref while #1392 owned durable concurrency. Two concurrent producers could therefore pre-choose conflicting sequence identity.

Resolution:
- producer emits EventDraft without authoritative seq/ref
- #1392 assigns event_seq and binding under its lock
- #1391 finalizes canonical accepted event and computes event_ref

### R-4 — duplicate retry vs duplicate accepted event was mixed

Severity: major.

Initial EV-02 allowed vague "duplicate handling" inside the accepted stream.

Resolution:
- accepted stream must contain unique event_ref
- exact transaction retry is absorbed by #1392 before append
- duplicate already present in stream is invalid

### R-5 — reject vs evidence_status=invalid was ambiguous

Severity: major.

Resolution:
- structurally unusable input: reject, no fabricated RunEvidence
- readable but contract-invalid stream: RunEvidence invalid
- valid unfinished: partial
- valid terminal: ready

## Remaining findings

### R-1 — Storage location intentionally unresolved

Severity: minor / intentional.

The plan does not choose a Production runtime path because #1391 must not own persistence. #1392 decides the durable store layout.

### R-2 — Formal JSON Schema deferred

Severity: minor / deliberate scope reduction.

First vertical slice uses strict runtime validators/fixtures. If cross-language/external consumers require a formal schema before safe integration, this becomes a replan trigger rather than silently expanding scope.

## I0 verdict

```text
Plan responsibility: GO
Plan test strategy: GO
Production code: BLOCKED
Independent review: REQUIRED
```
