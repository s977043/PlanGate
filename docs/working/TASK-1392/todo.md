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
- [x] C-2 round 5 (R-054〜R-059; not converged, all closed by specification; Human: single-writer premise for lost-response recovery)
- [x] C-2 round 6 (R-060〜R-064; not converged; Human: drop the landed-check rule, recovery moves to #1395 re-derivation)
- [x] C-2 round 7 (R-065〜R-070; not converged, all closed by specification)
- [x] C-2 round 8 (R-071〜R-076; split verdict, not converged; Human: halt marker in #1392)
- [x] C-2 round 9 (R-077〜R-083; split verdict; Human: pending marker before replace)
- [x] C-2 round 10 (R-084〜R-089; split verdict, no design change; closed by specification)
- [x] C-2 round 11 (R-090〜R-094; split verdict; Human: one directory descriptor per call)
- [ ] C-2 round 12 and later: continue until no new failure class appears (review-principles §7-quater)
- [ ] #1395 handoff (source of truth = the outcome table in plan "Retry after a lost response"): lost response / own crash / `StateConflict` / `RunAlreadyExists` → discard, `load_run`, re-derive from the stream (≤ `MAX_REDERIVE_PER_POSITION`); `RuntimeBusy` → retry the same call (≤ `MAX_BUSY_RETRIES`); `RunNotFound` from `load_run` → `create_run` only for a run_id never successfully created or loaded, else `halt_run(RUN_MISSING)`; `RunNotFound` from `commit` → `halt_run(RUN_MISSING)`; `RunHalted` → stop; everything else → `halt_run(CALLER_STOP)`; stopping completes only when `halt_run` succeeds (busy retried; other failures → Human, never auto-resume); record issued / observed run_ids and intents durably; never resend old drafts with a re-read token; Human unhalt procedure per reason (incl. pending-only and file flush of restored snapshots); `halt_run` busy bounded by `MAX_HALT_BUSY_RETRIES`, then Human; do not interrupt a commit with #1395's own timeouts or signals (a kill between the pending write and step 14 always halts the Run) (R-060 / R-065〜R-067 / R-072〜R-074 / R-080〜R-082 / R-091〜R-094)
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
- [ ] halt marker (`halt_run`, `RunHalted`, `lstat` presence, check after lock, `DURABILITY_UNKNOWN` on flush failure)
- [ ] pending marker (write before replace, resolve on every operation)
- [ ] fault injection
- [ ] concurrency test
- [ ] TA integration

## Review
- [ ] full CI
- [ ] I0 runtime review
- [ ] machine evidence
- [ ] Human review/merge boundary
- [ ] handoff to #1395
