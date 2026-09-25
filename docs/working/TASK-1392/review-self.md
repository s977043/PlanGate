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

### R-6 — state enum alone must not imply all-to-all transitions

The canon lists Lifecycle State values but does not authorize arbitrary edges.

Resolution: first slice explicitly allowlists only Delivery graph edges needed by #1383 and adjacent PR convergence. WAITING_* resume is deferred until pending-action resume contract exists.

### R-7 — WAITING_* without pending_action contract would be fake durability

Resolved by keeping WAITING_* canonical values recognizable but unsupported for transition in the first slice. pending_action must remain null until a later waiting/resume contract is defined.

### R-8 — conflict evidence cannot violate terminality

A stale writer arriving after terminal Outcome cannot append STATE_CONFLICT after the terminal event. It receives terminal/stale error with zero mutation.

### R-9 — state_transitioned revision binding

Events before the transition describe the pre-transition state revision; the final state_transitioned event carries the new revision. This removes ambiguity for projection/recovery.

## Verdict

PASS for plan. Runtime remains gated by #1391 consumability and #1329 implementation preflight.

## C-1 re-run after review reflection (2026-09-25)

Scope: plan / test-cases after reflecting R-001〜R-009 (`review-external.md`).

### R-10 — idempotency must precede the revision check, and must not become a bypass

An exact retry after success always carries a stale `expected_revision`, so the ledger lookup comes first. It is not a bypass because the digest includes `expected_revision` and `transition`, and a hit performs zero mutation.

### R-11 — the stored state must be a checked cache, not a second truth

Strict load folds every event (per-event revision, allowlist edges, bound context) and the ledger `result_revision`. A snapshot whose `snapshot_ref` was recomputed after tampering with any of these is rejected (ST-28c〜h).

### R-12 — conflict evidence must be bounded without letting a refused request commit later

Per-transaction and per-revision caps bound growth. A future `expected_revision` is refused outright, so unrecorded (suppressed / invalid) requests can never become current and commit later.

### Checklist

| item | result |
|---|---|
| pbi-input scope covered (incl. "idempotent transaction retry") | PASS |
| TASK-1391 contract (exact retry → no second event; state/conflict evidence owned by #1392) | PASS |
| every new rule has a TC | PASS (ST-21a〜m, ST-28b〜h) |
| scope creep (no CLI, no event vocabulary beyond state/conflict evidence) | PASS |
| open decisions surfaced | WARN — [P1] no-WAL single snapshot / [P2] trusted runtime_root / `MAX_CONFLICTS_PER_REVISION` value are Human / RED-fixture decisions |

### Verdict

PASS with WARN (open decisions above). The adversarial round did not converge (new classes R-006〜R-009), so C-2 must run at least 2 rounds before C-3.

## C-1 re-run after model B and C-2 R2 (2026-09-25)

Supersedes R-10 / R-11 above where they mention a stored ledger or stored state: under model B nothing derived is stored.

### R-13 — one truth

Stored: RunEvents in #1392 envelopes (`transaction_id`, `kind`, `expected_revision`, `transition`, with per-kind null rules). Everything else — RunState, generation, per-transaction results, replay index — is derived by the fold on each load. Every stored field that could duplicate a derived value is either null by rule or cross-checked on load (R-030).

### R-14 — idempotency is narrow on purpose

Replay only for committed create / commit, with a digest computed solely from recomputable data (R-035). Conflicts are outside idempotency (R-029): a conflicted id is answered live. Tampering by a writer who can recompute `snapshot_ref` is outside the guarantee (R-031).

### R-15 — Replan changes bindings only at one defined point

One re-binding `plan_contract_bound` per `REPLANNING` visit; `harness_manifest_ref` never changes (R-034).

### Checklist

| item | result |
|---|---|
| pbi-input scope (incl. idempotent retry, with the R-017 revision note) | PASS |
| canon consistency (§4 principle text and fixture rows agree) | PASS |
| TASK-1391 contract (exact retry → no second event; state/conflict payloads owned by #1392) | PASS |
| every new rule has a TC (ST-21d〜e2, 28c〜k, 30a〜d, 41〜43a) | PASS |
| dependencies surfaced as Preflight (strip/finalize round trip, re-binding event, decision payload keys and size, event type names) | PASS |
| open decisions | WARN — [P1] no-WAL single snapshot / [P2] trusted runtime_root / provisional `MAX_*` values (Human C-3) |

### Verdict

PASS with WARN. C-2 has not converged (R2 found new classes); C-3 waits for a round without new classes.

## C-1 re-run after C-2 R3 (2026-09-25)

| item | result |
|---|---|
| create and commit share the draft rules (binding keys, envelope keys, #1392-owned types) | PASS (R-038 / R-039) |
| every stored `state_transitioned` position is constrained on load | PASS (R-039) |
| conflicted id behaviour needs no stored digest | PASS (R-037) |
| per-event binding across a re-binding | PASS (R-040) |
| Decision states enforced as a check | PASS (R-041) |
| canon principle and fixture rows agree (incl. non-recording paths) | PASS (R-044) |
| TC references exist (no removed IDs referenced in plan) | PASS (R-045) |
| external dependencies surfaced in Preflight (#1391 re-binding segment, strip round trip, top-level binding keys, decision payload keys and size, event type names) | PASS |
| open decisions | WARN — [P1] / [P2] / provisional `MAX_*` (Human C-3) |

Verdict: PASS with WARN. C-2 still not converged.
