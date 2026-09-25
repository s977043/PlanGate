# EXTERNAL / FALLBACK REVIEW — TASK-1392 PLAN

Status: PENDING

Review questions:
1. Is one-file atomic snapshot a valid simpler equivalent to WAL for first slice?
2. Does storing full event history in each snapshot create unacceptable growth or copy cost for the first release?
3. Is conflict evidence generation safe without modifying RunState revision?
4. Is generation/event_seq/revision separation coherent?
5. Are crash points sufficient around fsync/replace?
6. Does #1392 accidentally re-own event semantics?
7. Is trusted runtime_root acceptable for first slice or must repo/common-dir discovery be included now?
8. Does snapshot_ref create false tamper guarantees without external anchor?

## PR independent review (2026-09-24 / head `d369d069`)

Source: PR #1406 comment「独立レビュー（2026-09-24）」. This is a pre-C-2 review, so it does not count as a C-2 round. C-2 (2 rounds, high-risk equivalent) is still PENDING.

| ID | severity | finding | disposition |
|---|---|---|---|
| R-001 | major | No idempotency key or duplicate detection, although pbi-input includes "idempotent transaction retry" and TASK-1391 plan delegates exact retry to #1392. A draft resent without a transition would commit twice | reflected: `transaction_id` + `request_digest` ledger; exact retry returns the current snapshot with `replayed=true`; ST-21a〜21f |
| R-002 | major | Stored `state` and the `state_transitioned` event stream are two truths that strict load does not cross-check | reflected: `state` is a derived cache; strict load folds the stream and rejects a mismatch; ST-28c / 28d |
| R-003 | minor | `state_conflict` is appended on every CAS mismatch with no bound | reflected: one per transaction_id; `MAX_CONFLICTS_PER_REVISION` with `suppressed`; ST-21d / 21g |
| R-004 | minor | INDEX.md / current-state.md / decision-log.jsonl missing | reflected: generated |

Open for Human (not resolved by the plan author): [P1] single-snapshot without WAL; [P2] trusted `runtime_root`.

| ID | status | reflected_in | notes |
|---|---|---|---|
| R-001 | reflected | (this PR, sweep commit) | |
| R-002 | reflected | (this PR, sweep commit) | |
| R-003 | reflected | (this PR, sweep commit) | cap value provisional, fixed by RED fixture |
| R-004 | reflected | (this PR, sweep commit) | |

## Adversarial review of the R-001〜R-004 fix (2026-09-25)

Independent read-only reviewer, focus per `review-principles.md` §7-quater (fix not effective / new hole from the fix / fail-closed breaking normal path). Still pre-C-2.

Verdict: fix needed (major 1 / minor 4). Confirmed as effective: digest covers `expected_revision` + `transition`, so the pre-revision lookup lets no stale or post-terminal writer through; `generation == len(transactions)` is consistent with crash / conflict / replay; `PLAN_VERIFYING` start matches taxonomy.

| ID | severity | finding | class | disposition |
|---|---|---|---|---|
| R-005 | major | Fold checked only `state_transitioned`; per-event `revision` of other events, ledger `result_revision`, and allowlist conformance of stored edges were unchecked (second truth remained) | R-002 not fully fixed | reflected: fold checks every event's revision, re-checks allowlist edges on load, ledger `result_revision`; ST-28f/g/h |
| R-006 | minor | Suppressed request is unrecorded, and a future `expected_revision` was treated as a normal conflict, so the same request could later commit | new (from R-003 fix) | reflected: `expected_revision > current` → `InvalidExpectedRevision`, zero mutation; ST-21h/i |
| R-007 | minor | Plan said `state_transitioned` fields are #1391-defined, but TASK-1391 plan says state/conflict evidence is consumed from #1392; no payload owner on main | new (ownership inversion) | reflected: payloads owned and frozen by #1392 RED fixtures |
| R-008 | minor | Empty commit (no drafts, no transition) would write a ledger entry with no event range and break strict load | new | reflected: rejected with zero mutation; ST-21l |
| R-009 | minor | Replay returned only the current snapshot, not the transaction's own outcome / event range | new (API gap) | reflected: `CommitResult.transaction`; ST-21m |

Missing TCs also added: concurrent exact retry (ST-21j), create_run retry variants (ST-21k), ledger first-entry / conflict-coverage tamper (ST-28e).

Round note (§7-quater): R-005 is the same class as R-002 (fix incomplete); R-006〜R-009 are new classes created by or exposed through the fix. **Not converged** — C-2 rounds must re-check the idempotency / fold design, not only its wording.

| ID | status | reflected_in | notes |
|---|---|---|---|
| R-005 | reflected | (this PR, sweep commit) | |
| R-006 | reflected | (this PR, sweep commit) | |
| R-007 | reflected | (this PR, sweep commit) | |
| R-008 | reflected | (this PR, sweep commit) | |
| R-009 | reflected | (this PR, sweep commit) | |
