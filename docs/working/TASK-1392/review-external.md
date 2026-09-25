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

## Codex consultation on C-3 decision items (2026-09-25)

Read-only consultation (Codex), not a C-2 round. Human selected all four to reflect.

| ID | item | Codex recommendation | disposition |
|---|---|---|---|
| R-010 | [P1] no-WAL single snapshot | adopt conditionally: add size bound, performance threshold, per-OS durability definition | reflected: Durability definition / Size and cost bound; ST-30〜32 |
| R-011 | [P2] trusted `runtime_root` | allow inside the primitive, but state CAS holds only within one root; common-dir resolver + linked-worktree test before the first production adapter | reflected: CAS guarantee scope |
| R-012 | initial state | keep `PLAN_VERIFYING`; keep `PLANNING` in canon, add its edge in a later planning slice | reflected: Initial state and PLANNING |
| R-013 | C-2 rounds | 2 fixed rounds are not enough; at least 2, until no new class; next round compares the model with alternatives | reflected: INDEX / todo |

| ID | status | reflected_in | notes |
|---|---|---|---|
| R-010 | reflected | (this PR, follow-up commit) | bound values provisional |
| R-011 | reflected | (this PR, follow-up commit) | |
| R-012 | reflected | (this PR, follow-up commit) | |
| R-013 | reflected | (this PR, follow-up commit) | |

## Requests from #1393 (PR #1407 comments, 2026-09-25)

Cross-PR requests from #1407's adversarial reviews (R3 / Rev2-R1〜R3). Not a C-2 round.

| ID | request | disposition |
|---|---|---|
| R-014 | derive the transition from `(lifecycle_state, action)`; reject a mismatching `transition` and a bare Decision-bound edge; re-check on load | reflected: Decision-bound transitions (checks 3〜5); ST-35〜38 |
| R-015 | reject when `decided_in_state` differs from snapshot `lifecycle_state` | reflected: check 1; ST-33 |
| R-016 | `decision_made` must be assigned `event_seq == input_last_event_seq + 1` (replaces the withdrawn `expected_last_event_seq` argument); re-check on load | reflected: check 2; ST-34 / 34a |

Open dependency: #1391 must freeze the `decision_made` payload keys (`decided_in_state`, `action`, `outcome`, `input_last_event_seq`) before RED fixtures.

| ID | status | reflected_in | notes |
|---|---|---|---|
| R-014 | reflected | (this PR, #1407-requests commit) | |
| R-015 | reflected | (this PR, #1407-requests commit) | |
| R-016 | reflected | (this PR, #1407-requests commit) | |

## C-2 round 1 (2026-09-25 / reviewed head `2f64beb0`)

Two lanes per `review-principles.md` §7-bis. Design lane run twice: Codex `gpt-5.6-sol` and Codex `gpt-6-sol` (model confirmed from the Codex rollout log, not from the report). Codebase lane: independent Claude agent. Key codebase claims were re-checked against files (main has 0 `validate_append`; #1402 `run_event.py` has `state_conflict_recorded` and no `state_transitioned`; #1402 `run_state.py` is multi-file + journal with plain `os.fsync` and WAITING_* / self edges).

Verdict: **fix needed; not converged** (new classes R-018 / R-020 / R-022).

| ID | lane | severity | finding | disposition |
|---|---|---|---|---|
| R-017 | design (both models) | major | Model A stores derived state and ledger aggregates and re-derives them on every load; R-002 → R-005 was the same class. Both models recommend model B (store only events + #1392 transaction envelope, derive state / index) with the same single-file atomic replace. B conflicts with canon §4 (CAS writes `new_state`) and pbi-input (single snapshot incl. RunState), so **B requires a canon revision** | **Human decision (C-3)** — not changed by the plan author |
| R-018 | design (both models) | major | A fixed `TERMINAL_RESERVE` does not prove a terminal Decision fits | reflected: reserve derived from `MAX_DECISION_EVENT_BYTES`; guarantee not claimed until #1391/#1393 bound the payload; ST-30c |
| R-019 | design (gpt-6-sol) | major | Boundary between replay and canon §4 "mismatch -> STATE_CONFLICT" undefined | reflected: replay = re-delivery for the same transaction_id + digest only; everything else stale is STATE_CONFLICT |
| R-020 | design (gpt-5.6-sol) | major | `request_digest` is not re-derivable from stored data, so a consistent-looking ledger replacement is undetectable | open: disappears under model B (envelope stores the request identity with its events); under A needs the canonical request stored with the entry. Depends on R-017 |
| R-021 | design (gpt-5.6-sol) | major | Owner boundary of a B-style transaction envelope vs #1391 RunEvent is undefined | open: depends on R-017 |
| R-022 | codebase | major | #1391 implementation exists only in PR #1402; its closed `EVENT_PAYLOAD_KEYS` has no `state_transitioned` (name there: `state_conflict_recorded`) | reflected: "consumable" preflight now requires the #1391 API on main and either the state event types or an extension point |
| R-023 | codebase | major | #1402 `run_state.py` already implements #1392 with a different model (multi-file + journal, plain fsync, WAITING_* / self edges) | **Human decision (C-3)**: replace or exclude #1402's run_state |
| R-024 | codebase | major | No re-open + dev/ino check after flock (TASK-1025 had `runtime_path_changed`) | reflected: Locking; ST-39 |
| R-025 | codebase | major | #1393 requests not in plan at `2f64beb0` | already reflected in `77d7802d` (R-014〜R-016) |
| R-026 | codebase | minor | TA number collisions (main ta-88; open PRs ta-88〜91; sweep reserves 92〜93) | reflected: ta-94 or later |
| R-027 | codebase | minor | `scripts/ai-loop-v2/` is outside ta-70 / exec-boundary scans, so ST-25/26 would pass vacuously | reflected: Implementation placement and static coverage (positive control required) |
| R-028 | codebase | minor | temp file naming undefined | reflected: fixed `<run-id>.json.tmp`, other siblings rejected; ST-40 |

Info (not reflected): TA-87 fixture on main models state per event with a REPAIRING self edge and +1 revision on terminal decision — hand over to #1395. `F_FULLFSYNC` succeeded on this machine (APFS) for file and directory.

Round note (§7-quater): the design lane in two independent models reached the same verdict (move to B), and the codebase lane found a competing implementation of this slice. The next round should not start until the Human decides R-017 / R-023, because both change what is being reviewed.

| ID | status | reflected_in | notes |
|---|---|---|---|
| R-017 | human-decision | — | canon §4 / pbi-input revision if B |
| R-018 | reflected | (C-2 R1 commit) | |
| R-019 | reflected | (C-2 R1 commit) | |
| R-020 | open | — | depends on R-017 |
| R-021 | open | — | depends on R-017 |
| R-022 | reflected | (C-2 R1 commit) | |
| R-023 | human-decision | — | |
| R-024 | reflected | (C-2 R1 commit) | |
| R-025 | reflected | `77d7802d` | |
| R-026 | reflected | (C-2 R1 commit) | |
| R-027 | reflected | (C-2 R1 commit) | |
| R-028 | reflected | (C-2 R1 commit) | |

## Human decisions on C-2 R1 (2026-09-25)

| ID | decision | reflected |
|---|---|---|
| R-017 | **model B** | plan: Snapshot / Transaction identity / create_run / commit / Revision conflict / Strict loading / Integration API / Tests; test-cases ST-28c〜e, 28h, 28i, 41; pbi-input Key design decision (revision note); canon `artifact-responsibilities.md` §4 (RunState is logical; CAS may be realised by an appended transition event; replay is not a CAS retry) |
| R-023 | **exclude `run_state.py` from #1402**; #1406 is the owner of RunState persistence and #1402 consumes the #1392 API | plan: Implementation placement; request posted to PR #1402 |

Status updates (append-only):

| ID | status | reflected_in | notes |
|---|---|---|---|
| R-017 | reflected | (model B commit) | canon §4 revised in this PR |
| R-020 | reflected | (model B commit) | digest of commit/create envelopes recomputed from stored events; conflict digest carried in the #1392-owned payload (tampering changes only the zero-mutation answer); ST-28i |
| R-021 | reflected | (model B commit) | envelope = #1392 metadata, RunEvent = #1391 type, no key crosses; ST-41 |
| R-023 | reflected | (model B commit) | |

C-2 round 2 reviews the model-B plan (§7-quater: is the fix effective / did it create new holes / did fail-closed break the normal path), including the new dependency that #1391 `finalize_event` adds only a closed set of binding keys.

## C-2 round 2 (2026-09-25 / reviewed head `47b7927f`)

Lanes: design — Codex `gpt-6-sol` (model confirmed from the rollout log); adversarial — independent Claude agent (diff `2f64beb0..47b7927f`, model-A remnant grep, TC ↔ rule mapping). Key claims re-checked against files (canon fixture row still distinguished no transaction id; create digest included the unstored `initial_state`; `transition` check was one-directional).

Verdict: **fix needed; not converged** — new classes R-032 / R-033 / R-034 / R-035 and the conflict-digest response variance (R-029). The idempotency layer has produced a new class every round (R-001 → R-006〜R-009 → R-020 → R-029 / R-035), so the Human was asked to narrow it.

| ID | lane | severity | finding | class | disposition |
|---|---|---|---|---|---|
| R-029 | design | major | conflict digest cannot be re-derived, so the same request can get a different answer after tampering | new | **Human decision: conflicts are outside idempotency.** Replay only for committed create / commit; a conflicted id gets a live RevisionConflict, no digest kept |
| R-030 | both | major | conflict envelope vs payload not cross-checked; `transition` checked one way only; create / conflict `expected_revision` undefined | R-017 fix incomplete | reflected: numbers only in the payload, envelope fields null per kind, `transition` iff trailing `state_transitioned`, conflict consistency on load; ST-28j / 28k |
| R-031 | adversarial | major | renaming an events-only envelope's `transaction_id` (snapshot_ref recomputed) lets the original request append again; "cannot append twice" claim was wrong | R-020 fix incomplete | reflected: claim withdrawn; Trust limit stated (unkeyed hash, hostile writer out of scope); ST-28i narrowed to corruption |
| R-032 | design | major | conflict evidence consumes the terminal reserve | new | reflected: conflicts recorded only outside the reserve, else `suppressed`; ST-30d |
| R-033 | adversarial | minor | states that accept `stop` undefined; a Run at the reserve in EXECUTING cannot terminate | new | reflected: guarantee scoped to Decision states; #1395 budget must stop earlier; residual in handoff; ST-30a pinned to VERIFYING |
| R-034 | adversarial | major | `plan_hash` cannot change but `REPLANNING -> PLAN_VERIFYING` is allowed, so a new Plan is rejected | new | **Human decision: allow one re-binding `plan_contract_bound` while REPLANNING**; ST-43 / 43a; #1391 dependency |
| R-035 | adversarial | major | digest input set ≠ recomputable set (`initial_state` unstored, trailing `state_transitioned` not excluded, #1391 canonicalization may change drafts) → legitimate retries get `TransactionIdReuse` | new | reflected: digest over recomputable data only, no `initial_state` input, trailing transition excluded, drafts with binding keys rejected, Preflight `strip(finalize(d)) == d`; ST-21e / 21e2 / 42 |
| R-036 | adversarial | major/minor | canon fixture row contradicts the revised §4; ST-41 recursive check would reject valid conflicts; model-A remnants in INDEX / current-state / review-self / todo | R-019 fix incomplete / cleanup | reflected: canon fixture rows split (new id → STATE_CONFLICT / same request → replay / conflicted id → live conflict); ST-41 top-level only; remnants cleaned |

Info (not reflected): `resumed_from_run_id?` in pbi-input has no deriving event under B (to be defined by the waiting/resume or Replan-as-new-Run slice). Cost: B recomputes digests on load; compute lazily for the looked-up id only (performance fixture decides).

Round note (§7-quater): not converged. R3 should check that the narrowed idempotency and the re-binding rule are effective and create no new hole; if R3 again finds a new class in the idempotency layer, the next step is to drop idempotency from the first slice (the third option offered to the Human).

| ID | status | reflected_in | notes |
|---|---|---|---|
| R-029 | reflected | (C-2 R2 commit) | Human decision |
| R-030 | reflected | (C-2 R2 commit) | |
| R-031 | reflected | (C-2 R2 commit) | residual, documented |
| R-032 | reflected | (C-2 R2 commit) | |
| R-033 | reflected | (C-2 R2 commit) | residual for #1395 |
| R-034 | reflected | (C-2 R2 commit) | Human decision; #1391 dependency |
| R-035 | reflected | (C-2 R2 commit) | #1391 dependency |
| R-036 | reflected | (C-2 R2 commit) | |
