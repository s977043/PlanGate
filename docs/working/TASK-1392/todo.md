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
- [ ] fallback/external review record (C-2 round 1)
- [ ] C-2 round 2 and later: **at least 2 rounds, continue until no new failure class appears** (review-principles §7-quater). Next round = design review comparing the ledger + fold + replay model with alternatives (e.g. event stream as the only truth / state not persisted), not a wording check
- [x] reflect Codex consultation: durability definition / size bound / CAS scope / initial state
- [ ] Human C-3 (incl. [P1] no-WAL single snapshot / [P2] trusted runtime_root)

## Preflight
- [ ] #1391 merged/consumable — **consumable means**: `validate_append` / `finalize_event` exist on main (0 today), and #1391 either defines `state_transitioned` / `state_conflict*` event types (#1402's draft has `state_conflict_recorded` and no `state_transitioned`) or exposes an extension point for #1392-owned types; and the `decision_made` payload keys and size bound are frozen
- [ ] decide the relation to #1402 `scripts/ai-loop-v2/run_state.py` (a different model already implementing #1392): replace / exclude (Human, C-3)
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
- [ ] idempotency ledger / exact retry replay
- [ ] state fold check on strict load
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
