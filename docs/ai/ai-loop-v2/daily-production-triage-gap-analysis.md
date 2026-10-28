# Daily Production Triage Shadow — Gap Analysis

> **Status:** proposal / docs-only / no runtime activation (2026-10-28).
> **Tracking:** PlanGate #1620; related #1442, #1448, #1465, #1468, #1473, #1430; River Review #2701.
> **Reviewed baseline:** PlanGate `main@2a02b7b80d047a1bf7ec028129d9e77ac2fceb0f`; River Review `main@92071c95139ef5061fe18f272b1596dbe444b554`.
> **Authority:** `north-star.md` and the existing Runtime Evidence / Admission / PBI / Review contracts remain canonical. This document creates no new SSoT, gate, schema, or activation permission.
> **Evidence status:** repository files and Issue descriptions inspected; no live application telemetry, independent reviewer execution, or local test execution has been observed.

## 1. Problem and decision

The proposed workflow is: analyze the last 24 hours of production behavior, rank failures/friction, associate provenance, and propose reproducible regression tests. **Do not** adopt the claims that every user session can be fully reconstructed from logs or that two prompts provide unattended self-improvement.

**Decision for the first slice:** add an operator-reviewed *offline/shadow triage proposal* on the input side of the existing Runtime Evidence Feedback Loop. Do not add a scheduler, a new PBI materializer, or automatic code changes. The existing Phase 0/1 trust boundaries block active R1 dispatch, and lack of real live-shadow cases blocks a quality rollout claim.

The target path is:

```text
Application-owned telemetry + access controls
  -> application/provider-owned aggregation and redaction
  -> bounded, sanitized evidence projection (source reference + provenance)
  -> existing R0 external-runtime ingress (#1448)
  -> existing PBI admission/materializer (#1442)
  -> ordinary PlanGate investigation, plan, verification, Human-owned approval
  -> targeted RED/GREEN regression verification where eligible
  -> River Review risk/review evidence and optional incident/revert eval (#2701)
  -> post-deployment external observation (not retroactive RunEvent mutation)
```

Daily batch cadence is a **triggering opportunity**, not evidence of an issue or a grant of execution permission. An application problem is not automatically a Harness evolution candidate. The V2 North Star explicitly forbids connecting Evolution to Production feedback before Delivery is stable; an offline intake experiment neither proves Delivery stability nor authorizes the production-feedback-to-Evolution connection.

## 2. Ownership / duplication audit

| Concern | Existing owner / current behavior | Gap / decision |
| --- | --- | --- |
| Production event collection | External provider / application; `production-feedback-loop.md` | Application-specific instrumentation stays outside PlanGate; no raw logs in this repository. |
| Provenance and privacy-bound ingress | `scripts/ai-loop/runtime_evidence_ingress.py` and #1448: sanitized content-addressed R0 candidate | Reuse; validate whether a proposed *aggregate* can map to existing input fields before changing a contract. |
| Grouping / fingerprint / trigger policy | `production-feedback-loop.md` §§3–5: proposal; provider-specific grouping outside core | Need offline assessment of grouping fidelity, time-window comparability, and silent missingness. No provider-dependent global model. |
| Read-only investigation | `runtime_evidence_investigation.py` / `runtime_evidence_dispatch_readiness.py`: R1 shadow/request candidates | Do not represent them as an active read-only agent. Independent runtime attestation is blocked on #1468/#1473. |
| PBI admission / deduplication | `pbi_materializer.py` / #1442: `materialize / no_action / discover_more` and `update_existing / link_only / create_new` | **No second materializer**; any proposal references this decision owner. |
| Real-data rollout | #1465: eligible actual Run, independent Admission oracle, and Human decision required | Synthetic fixture cannot be counted as live. Until valid real cases exist, rollout quality is `unknown`. |
| Test selection and repair boundary | #1430 / existing testing and Human C-3/C-4 | Recommend smallest sufficient layer; no automatic change to requirement, expected outcome, security behavior, or test oracle. |
| Reviewer evidence and benchmark | River Review #2701, #1574 / #2615 and `paired-replay` | Incident/revert cases only after separate human confirmation of pre-fix oracle. A UX complaint alone is not a reviewer false negative. |
| Scheduled execution | External host / optional Claude Code scheduler | Out of first slice. Operator-owned auth, cost ceiling, fail-closed behavior, and explicit activation decision required. |

## 3. Read-only candidate information contract (illustrative, not persisted schema)

An initial daily report may show at most five proposals selected by explicitly defined policy, with all missing values preserved as unknown. The output reuses source references rather than copying raw telemetry.

| Field | Meaning / invariant |
| --- | --- |
| `window_start`, `window_end` | UTC/RFC3339, `[start,end)` interval and observation timezone; no sliding ambiguity or invented timestamp. |
| `source_ref`, `source_digest` | Existing R0 ingress expects a sanitized repository-relative snapshot under `docs/working/_runtime-ingress/<provider>/`, **not** an arbitrary opaque URL. Provider event identities remain opaque within the sanitized snapshot; raw provider URLs or access tokens stay behind provider access controls. A digest binds content, **not** provider/actor authenticity. |
| `provider`, `captured_at` | Origin/collection metadata, independent of any AI-written narrative. |
| `fingerprint`, `deployment_ref` | Candidate grouping / app version, not root cause. Unknown versions are not folded into a proven deployment correlation. |
| `events_observed` | Count of matching recorded events, with collection completeness / sampling declared. |
| `affected_sessions` | Provider-side aggregate count **only if actually measured**; never expose session identifiers. |
| `affected_users` | Provider-side privacy-safe aggregate only when authorized and safe to release (including small-cohort suppression); `null` if unavailable or withheld. Session count is not a user-count surrogate. |
| `eligible_population`, `coverage` | Explicit cohort/denominator and sampling completeness. No rate with unknown or zero denominator. |
| `severity`, `materiality` | Separately attributed operational severity and unverified prioritization hypothesis. Security/data-loss hard floors are not averaged away. |
| `observed_failure`, `cause_hypothesis` | Distinct evidence classes. Reported provider assertion is not automatically independently observed. |
| `test_candidate` | Suggested test layer, RED setup, expected/actual behavior, and gaps; **not** proof a test was executed. |
| `missing_evidence`, `sanitization` | Explicit unknowns and redaction/secret-scanning disposition; missing is never `0` or PASS. |
| `existing_work_refs`, `triage_disposition` | Existing Issue/PBI references, and `investigate / defer / link / unknown` *advice*; never authoritative Admission. |

The table is a reporting checklist only. If any item already exists in a canonical contract, reference it rather than copying a second mutable truth. No new persisted schema or public API is approved by this proposal.

### Ranking and daily windows

1. Separate **observed** event counts from deduced risk/impact and independently verified root causes.
2. First isolate sensitive or irreversible failures (auth/authz, security, payment, data loss). Their escalation floor must not be canceled by low frequency or an unknown denominator.
3. Among otherwise comparable failures, rank using a documented severity policy and a *measured* affected population or frequency; break ties deterministically by sanitized fingerprint and deployment reference. Never use arrival order or an invented weighted impact score.
4. If cohorts, time windows, versions, or sampling differ, mark comparisons `inconclusive` rather than ranking on a false common basis.
5. Keep three identities separate: provider event ID for transport retry deduplication, sanitized failure fingerprint for candidate incident grouping, and `[start,end)` for a daily aggregate snapshot. A new daily window is **not** a new incident identity. Cross-day recurrence links to existing work through the existing materializer; do not derive a new PBI solely from the date.
6. An empty or unavailable collection is `no_evidence / incomplete`, not `zero incidents`. The daily report is optional when the provider is unavailable.

## 4. Security and authority contract

- Provider transport/authentication, replay protection, aggregation, retention, and access logging remain outside this repo. Application owners must obtain lawful/appropriate telemetry collection consent and enforce least privilege.
- Do not place raw events, full URL query strings, bodies, cookies, credentials, user/account IDs, session IDs, screen recording, session replay, unrestricted log excerpts, or sensitive stack traces in a public repository or LLM input. Hashing low-entropy personal identifiers is **not** sufficient anonymization. Suppress small cohorts and evaluate whether overlapping daily windows, segmented drill-downs, or before/after totals can reveal suppressed individuals by subtraction; report unavailable aggregates as withheld, not zero.
- `runtime_evidence_ingress.py` explicitly rejects `session_id`, `request_body`, `response_body`, and other forbidden keys. Never loosen this restriction just to implement a session-based ranking. Aggregate at the provider side.
- Provider-supplied strings remain **untrusted data**: no instructions, shell commands, workflow settings, source paths, or policy updates may be derived as authority from them.
- Attribution is layered: authenticated provider transport, data completeness, verified runtime execution, independent interpretation, and Human authorization are different claims. The existing R0 ingress reads `envelope.authenticated` as a **caller-supplied assertion**; that boolean alone does not authenticate the external provider or attest the caller's execution. An independently governed upstream transport/verifier must establish that claim before live operational reliance. Repository-owned evidence never self-attests independent execution.
- `Signal Trigger != Permission`; `Observation != Root Cause`; `Redaction != Safe-to-publish`; `Test Proposal != Executed Regression`; `CI Green != Production Recovery`.
- No unattended network query, automated Issue/PBI write, code modification, scheduled agent, new required Gate, hard-read-only promotion, merge, deploy, or harness promotion in the initial slice.
- If redaction, provenance, source permission, exact version identity, or count integrity fails, return `unknown / blocked`, preserve only safe diagnostic metadata, and require operator action. No silent fallback.

## 5. Reproduction test proposal and evaluation

A candidate is eligible for test authoring only after a reviewer confirms the intended behavior and that sufficient pre-fix evidence exists. Before a code fix can claim regression protection:

1. Fix the expected behavior / acceptance criteria by the existing PlanGate authority path. Do not let the generator rewrite WHAT to make a test pass.
2. Choose the cheapest valid test layer: Unit (pure logic), Integration/Contract (API or DB boundaries), deterministic E2E (critical user journey), or investigation-only when observations are insufficient.
3. Confirm the regression test actually **fails on the defective pre-fix revision** for the claimed reason (RED), then succeeds on the fixed revision (GREEN), using equivalent test setup and the same oracle. A failure caused only by environment drift or flaky infrastructure is not RED evidence; if the pre-fix revision cannot be tested, keep the candidate investigation-only.
4. Capture code revision, test command and environment, exit code, evidence references, and limitations. A generated test file without actual execution is a proposal only.
5. River Review evaluates the approved change evidence in its existing Review Artifact; only Human-confirmed incident/revert cases with reviewer-visible pre-fix context enter #2701 paired replay.
6. Keep post-deployment recovery telemetry as external follow-up; do not mutate a terminal Run's evidence stream.

### Negative controls to specify before Phase 1 implementation

| Case | Expected result |
| --- | --- |
| Duplicate delivery of the same provider event | One logical candidate / no duplicate PBI. |
| Missing population denominator or incomplete sampling | Affected-user rate is N/A, never 0%. |
| One user with many sessions | No inference that sessions equal unique users. |
| Error group spanning incompatible deployments | Explicit version split or inconclusive correlation. |
| One critical auth/data-loss error among many minor slow requests | Hard floor preserves escalation; no average-based suppression. |
| Prompt injection embedded in provider `statement` | Remains inert evidence; no command/policy/tool change. |
| Credentials, session identifiers, URL query secrets, or request body | Reject / redact before any Agent-visible or repository-visible artifact. |
| Source ref with invalid provenance, stale attestation, or mismatched digest | Unknown/blocked; no promotion to independently verified evidence. |
| Existing related Issue/PBI and daily replay | Refer/update/link via existing materializer; no second parallel decision path. |
| No live data, synthetic-only runs, or failed collector | Quality remains unmeasured; no false-green rollout decision. |
| Test passes before the proposed fix | Not accepted as reproduction of the claimed defect. |
| Test oracle changes during repair | Return to the existing requirement/approval boundary. |
| E2E test proposed for a pure calculation | Prefer unit unless an independently justified journey concern remains. |
| Incident not visible to reviewer at pre-fix PR revision | Not a reviewer miss in River Review #2701. |

## 6. Bounded rollout plan and stop/rollback

| Phase | Deliverable | Entry / exit |
| --- | --- | --- |
| 0 — present PR | This docs-only gap analysis and evidence boundary; existing code unchanged | Validate documentation quality and external reviewer of assumptions; Human C-4 approval before merge. |
| 1 — separate proposed PR | Optional offline deterministic grouping/report over synthetic sanitized fixtures, **only if gap proven** | Baseline comparison, negative controls above, exact-head CI, C-3/Human authorization; no live collection. |
| 2 — operator decision | Authorized application-side instrumentation and limited real-data shadow; no raw telemetry in PlanGate | Measure false candidates, privacy leakage, denominators, human usefulness, execution cost, and source completeness. Keep #1465 live run classification intact. |
| 3 — bounded integration | Candidate → existing PBI path; approval before RED/GREEN tests; River Review case eligibility as separate opt-in | North Star Delivery-stability prerequisite demonstrated before any Production-feedback-to-Evolution wiring; independent evidence review, pre-fix RED and post-fix GREEN where eligible, human review. |
| 4 — optional scheduling | Host-owned daily task with tool-level enforced read-only credentials, scoped repository/provider access, retry/cooldown, budget and kill switch | Activated only on explicit decision; a prompt saying 'read only' is insufficient. Disable on breach, increased false positives, unexpected writes/cost, or unverifiable Evidence. |

Suggested initial success criteria for a later real-data experiment: every actionable suggestion has retrievable permitted provenance, no raw sensitive identifier leaks, all denominators retain their collection windows, no unauthorized mutation, and baseline/after values for operator usefulness, false positive burden, and actual cost are measured. These are **eligibility criteria**, not assertions that they are already met.

Stop on untrusted promotion, semantic test-oracle drift, source scope breach, new unapproved cost, budget exhaustion, or missing exact-head verification. Rollback for Phase 0 is reverting this documentation PR; Phase 1 would require an explicit disabled-by-default path and tests confirming default behavior is unchanged. Any external task must have its own operator-owned kill switch.

## 7. Five-pass design review record (not subagent execution)

The following are five bounded **author self-review passes of the proposal**, not independently executed Claude Code subagents and not real runtime/test evidence. Each pass checks the updated design against a different counterexample.

| Pass | Check / defect or risk found | Correction in this plan | Re-review outcome |
| --- | --- | --- | --- |
| 1 — ownership | A new daily PBI creator would duplicate #1442 and conflate feedback with authority. | Reuse Admission and materializer decisions; Phase 0 creates no new canonical owner. | No parallel PBI authority proposed. |
| 2 — privacy | Session-level reconstruction would require sensitive raw identifiers and conflict with ingress denylist. | Provider-side aggregates only; no `session_id` in PlanGate or LLM input; missing users stay unknown. | Explicit denylist compatibility and data-minimization stop condition. |
| 3 — evidence & ranking | Affected-session count, event count, and unique users were conflated; rare critical harm could be averaged out. | Separate populations/windows and use non-averagable sensitive-risk floor. | Missingness and non-comparable cohorts are not a rankable 0. |
| 4 — test correctness | Generated tests could pass before a fix, and E2E could grow without protecting a real boundary. | Require pre-fix RED, unchanged expected behavior, cheapest suitable test layer, and post-fix GREEN. | No accepted claim based on test-file existence or CI green alone. |
| 5 — operations & cross-repo | A daily schedule might imply active R1 dispatch, real-evidence certification, or River Review reviewer truth. | Schedule optional/later; #1465/#1468/#1473 remain hard boundaries; #2701 uses independently confirmed oracle. | Phase 0 remains docs-only, report-only, and Human-owned activation. |

**Unresolved independently verified evidence:** no real application telemetry, actual affected-user denominators, independent attacker review, subagent-run records, full test execution, or rollout authorization exists in this deliverable. These must not be marked PASS merely because this document is complete.

## 8. Next owner decisions

1. Human review of this docs-only proposal (PlanGate C-4). No change to production behavior follows automatically.
2. Select one *willing* application and a single non-sensitive user journey; document the application's actual observable data and consent/retention boundaries before selecting a provider adapter.
3. Decide whether a reproducible gap truly remains in existing R0 ingress/Admission. If not, close the feature slice with documentation only rather than creating infrastructure.
4. Only after authorized real evidence exists, revisit the #1465 quality decision and the independent #1468/#1473 runtime proof separately.
5. For River Review #2701, obtain eligible human-verified pre-fix incidents; do not promote speculative UX incidents to reviewer ground truth.

**References:** [Runtime Evidence RFC](../../rfc/runtime-evidence-feedback-loop.md), [Production Feedback Guide](./production-feedback-loop.md), [V2 North Star](./north-star.md), [Issue #1620](https://github.com/s977043/PlanGate/issues/1620), [River Review #2701](https://github.com/s977043/river-review/issues/2701).
