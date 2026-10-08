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
| B-2 latest contract boundary | **#1391** | `validate_append` + `validate_stream` on load/audit | Replan→new `plan_contract_bound`→revert tree: pre-boundary PASS remains unusable; sticky FAIL cannot be washed out |
| B-3 last input seq / transaction adjacency | **#1392** | lock + commit/CAS + recovery/load; #1391 audit | insert another event before `decision_made`, same-transaction second decision, other writer intervenes: reject |
| B-4 decided state binding | **#1392** | under-lock snapshot check at commit, recovery/load | decide as VERIFYING while stored RunState is DIAGNOSING: reject without state/event mutation |
| B-5 state/action transition | **#1392** | derive transition at commit and compare; load replay | submitted target differs from allowed `(state, action)` edge: reject |
| B-6 contract/verifier set | **#1391** | typed `plan_contract_bound` event shape; stream load/audit | missing `loop_contract_ref`, duplicate verifier, changed required set without new contract-bound event: reject |
| B-7 effective FailureRecord | **#1393** (pure rule, not a distinct stream contract) | `make_decision_input` latest FR selection; B-9 owns delivery completeness | old FR for earlier FAIL reused after newer FAIL: reject; do not create another B-7 stream store |
| B-8 accepted verdict / convergence | **#1395** | construct inputs only from #1391 accepted policy and current-head convergence events; #1392 durably commits them | model-supplied `DENIED` removal or stale-head PR convergence: reject; no independent policy source |
| B-9 event-set completeness | **#1391** | deterministic validate/load + audit, via #1392 accepted stream | omit one bound verification, omit latest-FR, inject future/non-current-artifact ref: reject |
| B-10 latest prior decision | **#1391** | scan accepted decision stream at load/audit; #1395 selects result | using older baseline or `FIRST_ITERATION` when a valid baseline exists: reject |
| B-11 historical decision replay | **#1395** | audit orchestration consuming #1391 stream and #1393 pure core, without replacing either owner | mutate recorded decision inputs/action without changing source history: recomputed decision differs → reject |
| B-12 FailureRecord→verification ref | **#1391** | typed `failure_recorded` event, append/load/audit | `verification_ref` missing/unknown/not FAIL, or mismatched artifact/run: reject |
| B-13 blocker-set observation | **#1395** | deterministic observer result linked to accepted #1391 event; #1392 persistence | Worker `repair_attempted` asserts resolved blocker, observer has no delta: ignore claim / reject unsupported delta |

**Human decisions required:** B-3 load enforcement can be implemented by #1392 while #1391 performs separate semantic audit; B-11 has #1395 as audit *caller* but #1391 remains the source of accepted events and #1393 remains the sole Decision semantics owner. Human must confirm this non-duplicating split before making the table authoritative.

B-7 was superseded by #1393 Revision 2.2 and #1422 B-9. Keep its historical ID for traceability but do **not** create a new owner-owned stream validator under B-7.

## 3. Minimal RED fixtures and their independent oracles

Each fixture must be used first to show a real gap in the *provisional* runtime or prove that an existing owner contract already rejects it. Do not write a fixture whose input includes the answer it is meant to derive.

| Fixture | Stimulus (allowed inputs) | Oracle / expected failure |
|---|---|---|
| `binding-replan-revert` (B-2) | accepted PASS for tree A under contract C1, `plan_contract_bound` C2, tree returns to A | PASS from before C2 **unavailable**, unless there is a current C2 PASS. Same-tree deterministic FAIL remains sticky |
| `binding-decision-adjacent` (B-3) | DecisionInput observed at event seq N, another writer accepts event N+1 before decision commit | CAS/seq conflict; no accepted `decision_made` using stale input. On load, altered `input_last_event_seq` rejects |
| `binding-state-snapshot` (B-4/B-5) | valid event draft but stale `decided_in_state` or forbidden action/transition | no durable mutation of RunState or stream |
| `binding-required-set` (B-6) | contract C1 binds deterministic D1; `decision_made` claims D2 without a new contract event | reject on commit and on replay, not merely an application warning |
| `binding-fr-complete` (B-9/B-12) | bound FAIL accepted, latest FailureRecord omitted from DecisionInput | reject; do not treat empty FR set as safe completion |
| `binding-previous-decision` (B-10) | two accepted decisions establish baselines; caller selects older one | reject on binding validation; no retries by selecting favorable baseline |
| `binding-replay` (B-11) | record accepted stream, then change action/stop-reason only in stored decision | independent recomputation detects mismatch and treats evidence as invalid |
| `binding-observed-blockers` (B-13) | Worker self-reports resolved blocker; independent observer sees no blocker delta | ignore unsupported claim; do not suppress NO_PROGRESS |

For every case, measure BOTH:
- commit-time reject (no state/event half-commit); and
- load/replay/audit reject (tampered persisted data must not silently become accepted).

Do not mark a case complete from `run_event.validate_stream` alone when the condition requires authoritative RunState or an actual Git/artifact observer.

## 4. Current runtime evidence and limits

- Current `scripts/ai-loop-v2/run_event.py` validates typed payloads and event references. Its `validate_stream` fixes `plan_hash/source_sha` to the first event and therefore does **not** yet implement B-2 Replan rebinding.
- Current `plan_contract_bound` payload lacks the B-6 explicit `loop_contract_ref` and required-verifier set; adding them requires an owner review, not this report.
- `decision_made` currently has a provisional four-key nested payload and is **not** the final #1393 DecisionInput binding contract.
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
7. Reviewer silence/quota is `unavailable`, never a substituted PASS. Run a real independent reviewer/fallback, record exact reviewed SHA, then request GitHub C-4 Human approval.

This proposal is complete when it allows Human to decide ownership and developers to write failing tests; it is **not** evidence that any B-1–B-13 owner runtime passes.
