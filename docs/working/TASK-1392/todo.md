# TODO — TASK-1392 / #1392

## Plan
- [x] choose single atomic snapshot first slice
- [x] remove multi-file half-commit by design
- [x] separate event semantics from persistence
- [x] define revision vs generation vs event_seq
- [x] define conflict evidence behavior
- [x] define crash matrix
- [x] reflect PR independent review R-001〜R-004 (idempotency ledger / state fold on load / conflict bound / L0 files)
- [ ] I0 plan review
- [x] fallback/external review record (C-2 round 1: R-017〜R-028)
- [x] C-2 round 2 (R-029〜R-036; not converged)
- [x] C-2 round 3 (R-037〜R-045; not converged; Human: keep idempotency and close by spec / ask #1391 for re-binding)
- [x] C-2 round 4 (R-046〜R-053; not converged; Human: remove idempotency from the first slice, CAS on revision + position, binding via API arguments)
- [ ] C-2 round 5 and later: continue until no new failure class appears (review-principles §7-quater). Focus: the idempotency-free CAS (revision + position) and the binding arguments
- [x] reflect Codex consultation: durability definition / size bound / CAS scope / initial state
- [ ] Human C-3 (incl. [P1] no-WAL single snapshot / [P2] trusted runtime_root)

## Preflight
- [x] Human decisions R-017 (model B) / R-023 (#1402 run_state excluded) / R-029 (conflicts outside idempotency) / R-034 (Replan re-binding) / R-043 (ask #1391 for re-binding) / R-046 (no idempotency in the first slice) / R-049 (CAS on revision + position) — 2026-09-25
- [ ] #1391 merged/consumable — **consumable means**: `validate_append` / `finalize_event` exist on main (0 today), `finalize_event` takes the binding as `bound_context` (not from the draft; R-047), TASK-1391 plan:81 reworded from "idempotency layer" to "#1392 CAS" (R-046), #1391 `validate_append` and projection treat a re-binding `plan_contract_bound` as a binding segment boundary (R-043; otherwise every Replanned Run's RunEvidence is invalid), binding keys live only at the RunEvent top level, and #1391 either defines `state_transitioned` / `state_conflict*` event types (#1402's draft has `state_conflict_recorded` and no `state_transitioned`) or exposes an extension point for #1392-owned types; and the `decision_made` payload keys and size bound are frozen
- [ ] exact base SHA
- [ ] #1329 M-1/M-2/M-3 before/after scope
- [ ] semantic invalidation YES

## RED/GREEN
- [ ] strict loader
- [ ] state validator
- [ ] snapshot canonical hash
- [ ] flock
- [ ] create_run
- [ ] commit
- [ ] transaction envelope (kind only) + derived position / CAS on revision + position (model B, R-049)
- [ ] binding supplied by API arguments (create binding / commit rebinding)
- [ ] state fold check on strict load (incl. Replan re-binding, conflict consistency)
- [ ] conflict evidence
- [ ] conflict evidence bound
- [ ] atomic replace/fsync (platform flush table, fail closed)
- [ ] size bound / terminal reserve / performance fixture
- [ ] fault injection
- [ ] concurrency test
- [ ] TA integration

## Review
- [ ] full CI
- [ ] I0 runtime review
- [ ] machine evidence
- [ ] Human review/merge boundary
- [ ] handoff to #1395
