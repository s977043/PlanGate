# Decision Input Binding: owner/timing review proposal (#1422)

> As-of: 2026-10-09 JST / main at drafting: `3382d712518a32c7bf83421194fd481f7e7d3873`.
> **PROPOSAL, NOT A DECISION.** #1422 requires a Human to confirm accountable owners and test timing.
> This report is not an approved replacement for #1393 Revision 2.5 `plan.md`, a new source of truth,
> a C-3 artifact, or permission to execute protected Verification/Decision code.

## 1. Design boundary

```text
#1391  accepted RunEvent vocabulary + stream validation / projection
#1392  sequence/binding assignment, CAS, durable commit, recovery, load
#1395  gather observed artifact/verifier/convergence/blocker inputs
       -> apply #1422 binding rules before #1393
#1393  pure make_decision_input(...) / decide(...) on verified inputs
```

These duties may overlap at enforcement points but have one *proposed accountable owner* per invariant. A value produced by a Worker/fixture must not impersonate a recorded event. A value produced by #1393 does not prove that its input accurately reflects the stream.

## 2. Proposed B-1–B-13 owner matrix

| Rule | Accountable owner (proposal) | Where to enforce / prove | Independent negative or mutation oracle |
|---|---|---|---|
| B-1 tree identity | **#1395** | input construction + observer, audit against exact Git tree | using SHA-256 of JSON-quoted `"git-tree:<oid>"` instead of raw UTF-8 must reject; same tree, different commit must not change identity |
| B-2 latest contract boundary | **#1391** | `validate_append` + `validate_stream` on load/audit prove boundary identity; #1393 pure core applies PASS/FAIL semantics | Replan→new `plan_contract_bound`→revert tree: pre-boundary PASS remains unusable; sticky FAIL cannot be washed out |
| B-3 last input seq / transaction adjacency | **#1392** | lock + commit/CAS + recovery/load; #1391 audit | insert another event before `decision_made`, same-transaction second decision, other writer intervenes: reject |
| B-4 decided state binding | **#1392** | at commit compare with under-lock snapshot; at load replay **historical** state at each decision's event position, not current terminal snapshot | decide as VERIFYING while the **historical pre-decision** state is DIAGNOSING: reject without state/event mutation |
| B-5 state/action transition | **#1392** | derive `(historical pre-decision state, action)` at commit; replay each accepted transition against historical per-seq RunState evidence at load/audit | committed next state differs from derived edge; comparing an old decision against the *current* RunState must not be used as an oracle |
| B-6 contract/verifier set | **#1391** | typed `plan_contract_bound` event shape; stream load/audit | missing `loop_contract_ref`, duplicate verifier, changed required set without new contract-bound event: reject |
| B-7 effective FailureRecord | **RETIRED / folded into B-9** (no separate binding owner) | #1391 B-9 ensures no latest-FR omission; #1393's already-owned pure `make_decision_input` selects effective latest FR | stale FR or an omitted later FR must reject under B-9 + #1393 pure rules; no new validator or store is created for B-7 |
| B-8 accepted verdict / convergence | **#1395** | construct inputs only from #1391 accepted policy and current-head convergence events; #1392 durably commits them | model-supplied `DENIED` removal or stale-head PR convergence: reject; no independent policy source |
| B-9 event-set completeness | **#1391** | deterministic validate/load + audit, via #1392 accepted stream | omit one bound verification, omit latest-FR, inject future/non-current-artifact ref: reject |
| B-10 latest prior decision | **#1391** | scan accepted decision stream at load/audit; #1395 selects result | using older baseline or `FIRST_ITERATION` when a valid baseline exists: reject |
| B-11 historical decision replay | **#1395** | audit orchestration reconstructs DecisionInput from **preceding accepted events + authoritative contract/policy**, calls #1393 pure core; #1391 remains stream authority | rehash an altered decision/event history consistently but keep original preceding facts; independently computed owner Decision != altered record → reject |
| B-12 FailureRecord→verification ref | **#1391** | typed `failure_recorded` event, append/load/audit | `verification_ref` missing/unknown/not FAIL, or mismatched artifact/run: reject |
| B-13 blocker-set observation | **#1395** | independent blocker observer derives deltas; **#1391 new event vocabulary proposed, not implemented**; #1392 durably accepts; #1395 builds inputs from accepted observer event only | Worker `repair_attempted` asserts resolved blocker with no observer evidence: ignore claim/reject; until new event exists, use empty sets conservatively and do NOT claim B-13 PASS |

**Human decisions required:** B-3 load enforcement can be implemented by #1392 while #1391 performs separate semantic audit; B-11 has #1395 as audit *caller* but #1391 remains the source of accepted events and #1393 remains the sole Decision semantics owner. B-13 must specify a deterministic observer provenance contract and accepted-event shape/owner before runtime activation.

**B-4/B-5 historical replay rule:** for each accepted `decision_made`, #1392 must reconstruct the *state immediately before that event* by replaying prior accepted event/state transitions and durable transaction evidence (including the revision/position binding). Compare `decided_in_state` against that historical snapshot and derive the next state from `(historical_state, action)`. Comparing old decisions to the **latest** RunState snapshot would reject valid history. If accepted events/transaction receipts are insufficient to reconstruct the historical state at a given seq, return `INCONCLUSIVE` / block readiness and do not fabricate an audit PASS. #1391 does not implement a second state store. Human must confirm this non-duplicating split before making the table authoritative.

B-7 is **RETIRED/SUPERSEDED**, not a 13th newly assigned binding authority. #1393 Revision 2.2 already defines pure effective-FR selection and #1391 B-9 owns stream completeness. Retain historical ID for traceability only; no new B-7 validator/store.

## 3. Minimal RED fixtures and their independent oracles

Each fixture must be used first to show a real gap in the *provisional* runtime or prove that an existing owner contract already rejects it. Do not write a fixture whose input includes the answer it is meant to derive.

| Fixture | Stimulus (allowed inputs) | Oracle / expected failure |
|---|---|---|
| `binding-replan-revert` (B-2) | accepted PASS for tree A under contract C1, `plan_contract_bound` C2, tree returns to A | PASS from before C2 **unavailable**, unless there is a current C2 PASS. Same-tree deterministic FAIL remains sticky |
| `binding-decision-adjacent` (B-3) | DecisionInput observed at event seq N, another writer accepts event N+1 before decision commit | CAS/seq conflict; no accepted `decision_made` using stale input. On load, altered `input_last_event_seq` rejects |
| `binding-state-snapshot` (B-4/B-5) | create accepted historical state S at seq K, then decide with another state or disallowed transition; replay entire committed state/event transaction history through seq K+1 and *later valid transitions* | commit must fail on the under-lock snapshot; load/audit independently derives **pre-decision state at K** and rejects mismatch. **Valid-history negative control:** old decision S remains valid even if today's RunState is S2; do not compare historical decisions to today's terminal state |
| `binding-required-set` (B-6) | contract C1 binds deterministic D1; `decision_made` claims D2 without a new contract event | reject on commit and on replay, not merely an application warning; valid Replan C2 can replace required verifier IDs only through an accepted new contract-bound event |
| `binding-fr-complete` (B-9/B-12) | bound FAIL accepted, latest FailureRecord omitted from DecisionInput | reject; do not treat empty FR set as safe completion |
| `binding-previous-decision` (B-10) | two accepted decisions establish baselines; caller selects older one | reject on binding validation; no retries by selecting favorable baseline |
| `binding-replay` (B-11) | mutate decision action/outcome while preserving preceding unmodified verifier, failure, policy and contract facts; recompute altered decision event hash AND downstream references so structure validates | reconstruct DecisionInput **only from the original preceding accepted observations** using #1422 binding, then derive the oracle from #1393 pure `decide` and check mismatch. Never read the altered decision outcome to derive its own expected outcome. Exercise the **semantic replay audit** separately from storage tamper rejection; both checks must be meaningful |
| `binding-observed-blockers` (B-13) | Worker self-reports a resolved blocker; observer has no accepted blocker event, then later emits accepted zero-delta observation | without owner event vocabulary: empty sets as conservative input (not B-13 PASS); with accepted observer evidence: Worker-only resolution is rejected and NO_PROGRESS remains eligible |

For every case, measure BOTH:
- commit-time reject (no state/event half-commit); and
- load/replay/audit reject (tampered persisted data must not silently become accepted).

Do not mark a case complete from `run_event.validate_stream` alone when the condition requires authoritative RunState or an actual Git/artifact observer. Not every scenario has an identical commit-time and audit-time assertion: for B-11 the core proof is independent historical replay; for B-13 the first RED may be an explicitly unsupported/missing observer event, not a fabricated accepted event.

## 4. Current runtime evidence and limits

- Current `scripts/ai-loop-v2/run_event.py` validates typed payloads and event references. Its `validate_stream` fixes `plan_hash/source_sha` to the first event and therefore does **not** yet implement B-2 Replan rebinding.
- Current `plan_contract_bound` payload lacks the B-6 explicit `loop_contract_ref` and required-verifier set; adding them requires an owner review, not this report.
- No accepted `blocker_delta_observed` event type or verified equivalent exists in the current #1391 event vocabulary. **B-13 has no implemented acceptance channel**. Proposed producer: #1395 deterministic observer with explicit previous/current blocker-set identity, observed artifact/contract/run refs, observer identity, and evidence refs; owner for strict event schema/acceptance: #1391; durable recorder: #1392. Human #1422 decision required before naming/freezing a new event. A Worker `repair_attempted` payload is never an authoritative blocker observation.
- `decision_made` currently has a provisional four-key nested payload and is **not** the final #1393 DecisionInput binding contract.
- There is no accepted dedicated policy-verdict event in the current #1391 vocabulary; #1422 B-8 must freeze the vocabulary and latest-current-head convergence binding before anyone treats a caller-supplied policy result as accepted authority.
- `scripts/ai-loop-v2/run_state.py` remains temporary/fixture-owned under the 2026-09-29 Human R-023 ruling; #1392 model B is not complete.
- #1395 must reuse `scope_observer.py` from PR #1516 only after the observed artifact/commit binding matches Delivery's owner contract. A Candidate/Worker's declared `changed_paths` is not itself observational evidence.
- TA-87 is a non-authoritative executable specification. TA-92 synthetic completion and TA-93 provisional E2E do not establish #1381 AC-6 real-verifier proof.
- #1393 approved `plan.md` and its Human C-3 token are unchanged. PF-1 expanded migration to Ratchet/TA-92 is still subject to the recorded Human reapproval decision.

## 5. Review and release criteria

1. Human explicitly adjudicates this matrix and chooses where B-3/B-11 checks execute without duplicating the owner.
2. Implement #1391 event vocabulary and stream binding, then #1392 durable commit/recovery under their **own** approved plans.
3. Run RED fixtures against provisional and owner-backed paths; preserve exact failing input and accepted evidence refs.
4. Only after #1391/#1392/#1422 preflights, build #1393 pure core, migrate all callers, and run #1395 Path A/B with independent I3/I4 review.
5. Recheck #1381 AC-6: actual verifier → accepted VerificationResult → bound DecisionInput → Decision that blocks known-bad; negative-control passes. No automatic C-4, merge or Promotion.
6. Under #1329, treat any runtime policy/Verifier/Gate enforcement addition as semantic invalidation candidate; do not modify canon 7 inside the same implementation PR to self-exempt.
7. Reviewer silence/quota is `unavailable`, never a substituted PASS. Run a real independent reviewer/fallback, record exact reviewed SHA, then request GitHub C-4 Human approval. Post-merge review debt is tracked separately: #1519 was reopened on 2026-10-09 because PR #1520 merged without recorded independent-review evidence; this proposal must not repeat that precedent.

This proposal is complete when it allows Human to decide ownership and developers to write failing tests; it is **not** evidence that any B-1–B-13 owner runtime passes.
