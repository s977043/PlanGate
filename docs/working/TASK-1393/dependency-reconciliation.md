# TASK-1393 Dependency Reconciliation / #1381 AC-6 Handoff

> Observed: 2026-10-08 JST, main baseline `e20cf1dac50a24a3d82bc9584ecf5f8e86d4d519` (#1516). Issue #1519. Informative handoff only.
> Post-merge note (2026-10-09, #1519 review): the parent of the merge commit `c6ec773d` was `5a7aba88`, 7 commits after this baseline. Those 7 include #1495 (claim binding, reflected below) and #1511 `7349c2b1` (external verifier P1 gated behind P0 preflight), which touches the AC-6 "real verifier" path. Whether #1511 changes any owner row is for the owner / Human to judge; this note does not claim AC-6 progress.
> The approved Revision 2.5 `plan.md` and Human-issued C-3 approval remain authoritative and unchanged.
> **Verdict: BLOCKED** for execution until the pending Human plan-scope/reapproval ruling and the owner preflights below are completed.

## Live owner inventory

| Owner | Issue on 2026-10-08 | Consumed implementation on main | Residual / decision |
|---|---|---|---|
| #1391 RunEvent / RunEvidence | OPEN | `run_event.py`, `run_evidence.py` (provisional) | Replan re-binding, decision stream binding, policy / convergence vocabulary, negative fixtures. #1422 B-2/B-3/B-6/B-8/B-9/B-10 not proven |
| #1392 durable RunState | OPEN | `run_state.py` (temporary **fixture-only** implementation; Human R-023) | Approved model-B store, `state_transitioned`, crash/position CAS, and migration remain |
| #1393 pure Decision | OPEN / BLOCKED | `decision_core.py` from #1402 (**provisional**; not approved owner core) | Human release of BLOCKED, PF-1–PF-8, approved `make_decision_input -> decide` implementation |
| #1395 owner-backed Delivery E2E | OPEN | `delivery_runtime.py` / TA-93 consume provisional state/Decision | Migrate to #1392 + #1393, true observer-owned changed paths, I3+ independent evidence |
| #1422 Decision Input Binding | OPEN | issue contract B-1–B-13 | Human owner/timing assignment remains unconfirmed; ensure stream completeness before production owner-Decision |
| #1383 Delivery E2E release gate | OPEN | non-authoritative TA-87 / provisional TA-93 | no owner-backed unblock verdict for Evolution |
| #1381 Ratchet vertical slice | OPEN | TA-92 synthetic paired evaluation; repository-backed delta via #1516; expected-prevention claim binding via #1495 (`34420151`, claim != effectiveness evidence) | **AC-6 remains OPEN** until a real verifier changes an owner Decision |
| #1329 canon I1 exception | OPEN | operational semantic invalidation rule | execution-enforcement changes are invalidation candidates; separate I4 review of canon, no self-exemption |

**Already resolved, do not re-open as new implementation**: `ratchet.py -> decision_core._canonical_path` private dependency was removed by PR #1516 (`e20cf1dac50a24a3d82bc9584ecf5f8e86d4d519`). Scope observation is now in `scripts/ai-loop-v2/scope_observer.py` and can be consumed by #1395 after its own artifact/source binding review.

**Still unresolved**: `ratchet.py` imports `DecisionError` and `decide` from provisional `decision_core.py`. Replacing that core under #1393 must migrate Ratchet/TA-92 **as well as** Delivery/TA-93 and their fixtures. The 2026-09-29 Human ruling on #1395 requires explicit plan scope change, review, and C-3 re-issue where approved plan scope is enlarged. Recording this fact here does not approve a plan change.

## Required Human decisions (not silently inferred)

1. Confirm the corrected dependency ownership / outstanding work in #1391, #1392, #1422, #1395 and whether #1393 can leave BLOCKED.
2. Decide whether extending the approved #1393 migration scope to Ratchet and TA-92 requires the stated R-NNN → one settled plan revision → C-1 → **new Human C-3**. Existing approval hashes **do not** automatically authorize a different plan.
3. Confirm I3/I4 independent review placement and external protected-evaluator change review. An author I0 review, CI success or a quota-limited Copilot response are **not** independent review evidence.
4. Keep #1383 unblock and #1381 AC-6 open until owner-backed run evidence is demonstrated.

## AC-6 non-vacuous execution contract

This is an implementation-ready *acceptance handoff*, not a new owner runtime or authorization.

```text
sealed known-bad: changed artifact + no required verification evidence
  -> evidence observer (independent of Worker / Candidate flags)
  -> real deterministic Verifier produces accepted VerificationResult
  -> #1391 RunEvent accepted; #1392 durably commits, event_ref bound to exact artifact
  -> #1422 DecisionInput binding verified
  -> #1393 owner make_decision_input/decide consumes verifier ref
  -> completion attempt STOP/BLOCKED (or reviewed owner outcome)
  -> activation=influenced_decision proven by Decision input ref, not evaluator assertion

same plan + sealed negative-control: fresh applicable evidence present
  -> deterministic PASS bound to same artifact / contract
  -> owner Decision does not reject a valid completion solely due to the verifier
```

Minimum RED / mutation gates:

- Worker-supplied `verification_present=true` without accepted verifier event must not count.
- Candidate verifier code/config/fixture/threshold cannot alter its own held-out evaluator.
- Missing evidence / `unavailable` / `inconclusive` cannot produce completion success.
- A result bound to an older artifact/head, older contract boundary, or another Run cannot satisfy the current requirement.
- A model PASS cannot override a required deterministic FAIL.
- A repeated PASS on the same artifact cannot erase sticky FAIL.
- Decision input must reference the accepted verifier event; stale/duplicate/orphan refs reject.
- No pre-authored `decision_made`, stop reason, `no_progress`, or completion outcome is supplied as runtime input.
- Same evidence when present (negative control) must not be incorrectly blocked.
- No auto C-4 / PR merge / Production promotion or active-Run Harness replacement.

Exit evidence for AC-6:

- explicit source/head/artifact/tree/contract binding and accepted RunEvent refs;
- two owner-backed executable traces (known-bad and negative control), with fixture inputs logically separated from oracle;
- a verifier-produced (not synthesized by `simulate_completion`) VerificationResult;
- the Decision's input refs demonstrably contain the verifier result ref;
- deterministic mutation negative controls, latest-head Test/CI/CodeQL, independent I3/I4 review at exact head;
- explicit #1395 → #1383 → #1381 unblock evidence / Human authority gates.

## Reproducible acceptance commands (only after owner integration)

These are **commands to run later**, not a claim of successful execution in this handoff:

```sh
python3 scripts/ai-loop-v2/test_ratchet.py
python3 scripts/ai-loop-v2/test_delivery_v2.py
sh tests/extras/ta-92-ai-loop-v2-ratchet.sh
sh tests/extras/ta-93-ai-loop-v2-owner-backed-delivery.sh
# Complete required repository test suite / CI on the exact PR head SHA.
```

Current TA-92/TA-93 success is only regression evidence of provisional/synthetic behavior. For #1381 AC-6 record, alongside these green commands, the **new owner-backed verifier E2E command**, fixture IDs, accepted `verification_recorded` event refs, Decision input refs, artifact/contract identity, and exact reviewed head SHA. A green preexisting TA must not replace these missing artifacts.

## Owner implementation sequencing note

The current `ratchet.py` calls provisional `decision_core.decide`; its synthetic `simulate_completion` path must remain explicitly non-authoritative until owner integration. #1393's designed `artifact_verdicts` API is **not currently consumable as a final owner seam**. #1460 Mode A is a tests-only executable specification, not a substitute owner Decision.

## Execution order / stop conditions

1. Keep approved `plan.md` byte-identical; resolve Human scope/approval choices and #1422 owner assignment.
2. Close #1391 event/binding vocabulary and #1392 model-B RunState dependencies first.
3. Implement #1393 pure Decision per the approved plan (or newly approved revision), migrate **all** provisional callers.
4. Prove #1395 Delivery Path A/B against accepted events, artifact-bound scope observer, and real verifier results.
5. Only then implement and prove #1381 AC-6 with the two paired controls; independent review/DoD before closure.
6. Return evidence to #1376; do not assume PASS/Promotion Ready from a synthetic evaluator result.

**Stop** on absent/newly invalidated C-3, unowned B-1–B-13 invariant, provisional Decision as production authority, fixture-supplied outcomes, or missing independent review. No issue closure or Production Promotion follows from this handoff alone.
