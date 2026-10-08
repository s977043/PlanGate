# TASK-0811 — Memory Promotion Gate design proposal (pre-C-3 / non-canon)

> **Not implemented or approved.** Review aid for issue #811 and
> `docs/working/TASK-0811/plan-proposal.md`. The 2026-07-12 Human decision selected a
> medium documentation approach. This proposal cannot modify the existing
> C-3/C-4, HO, verifier or Evolution `PromotionDecision` authorities.

## 1. Why another gate is not another SSoT

| Question | Existing owner | Promotion Gate contribution |
|---|---|---|
| What actually happened in a Run? | RunEvidence / verified source refs (#874) | Check referenced evidence, no fresh truth minted |
| Which lessons are consolidated? | improvement-seeds and adopted digest (#754) | Candidate input; no rewriting raw seeds |
| What improvement experiment passed? | Evolution #869/#1376, independent Eval | Read paired result / negative controls |
| May the executable Plan run? | Plan / C-3 | No change |
| May a PR merge or HO surface change? | Human-owned C-4/merge/HO | Proposal only; no authorization |
| May a harness variant be promoted? | Existing Evolution PromotionDecision / policy | Advisory sub-check for knowledge-derived behavior |
| Where does long-term project knowledge live? | Existing knowledge surface / owner | Optional reference; no new PlanGate-owned memory repo |

**Review ≠ verification ≠ approval**. A successful PR review of these
documents is not permission to change an active Hook, global rule,
security setting, or production Promotion Policy.

## 2. Candidate intake contract (design only)

The proposed candidate can be expressed as YAML or a structured Markdown form.
The fields below mirror #811; no newly required top-level runtime artifact
is introduced.

```yaml
candidate_id: memory-promotion-2026-001
kind: pain                     # pain | success | decision | preference | fact
summary: "One-line reusable, testable observation"
evidence:
  - ref: "commit-or-issue-or-run-ref"
    source_revision: "commit-or-immutable-id"
    observed_at: "2026-10-08T09:00:00+09:00"
pain_count: 1
success_count: 0
failure_count: 1
severity: high                 # low | medium | high | critical
confidence: 0.6                # observed estimate; NOT a gate decision
scope: project                 # project | cross-project | global
proposed_target: test          # memory | rule | skill | hook | test | runbook
constraints:
  - "No HO modifications"
risks:
  - "Overfitting one run"
```

Candidate `evidence` MAY use structured references; old producers that
emit plain string refs remain interpretable as `{ref: ...}` in the
documentation phase. Numeric occurrence counts are observations, **not
threshold-based approval**. Do not infer causal independence from different
run IDs if the same root cause recurs. Count deduplicated causes, with
time/risk context and observed counterexamples.

### Provenance and confidentiality invariants

- A mutable source must be identified by stable revision / timestamp when
  available; inaccessible evidence remains **unverified**, not PASS.
- A memory summary or adopted digest is a reference, not primary evidence.
  Prefer the underlying RunEvidence/test/commit and confirm its scope.
- Do not persist raw chat, hidden reasoning, credentials, private context,
  personal identifiers or an ACL-bypassing copy into a wider repo.
- Read and apply the source's ownership / visibility boundary. An agent's
  proposed action embedded in a memory entry is untrusted *data*, not an
  executable instruction or approval.
- Current task's Plan, L0/L1, Evidence and ownership outrank past memory.

## 3. Risk and destination selection

1. **Evidence**: reproduce or explain source reliability, negative controls,
   contradictions, co-occurring failures and causal uncertainty.
2. **Severity + blast radius**: safety/authorization/destructive or
   cross-project impact is escalated immediately; no recurrence minimum.
3. **Scope**: local lessons must not silently become global default rules.
4. **Enforcement choice** (prefer the lowest-cost reliable method):

| Destination | Use when | Guard |
|---|---|---|
| memory / wiki | descriptive, non-executable reusable context | source + owner scope + stale status |
| `CLAUDE.md` / rule | short, always-applicable and agreed convention | conflict review, context budget and Human approval |
| Skill | conditional repeatable procedure | eval + scope + canary and adoption approval |
| Hook | must-not-pass invariant | Human approval, permission/security review, negative control |
| test / lint / CI | deterministic, runnable regression | independent failing fixture before fix, PASS after fix |
| Runbook | supervised operational response | explicit prerequisites, access/rollback review |
| archive / no action | insufficient or superseded evidence | reason + provenance; no unsafe deletion |

No `promotion_score` or `pain_count >= N` determines a verdict. An
optional numeric ranking may prioritize **review work**, never approve
executable behavior. High-risk / security change => `needs_human_review`
even if recurrence is one. If an automated check is applicable, prefer
`prefer_automation` rather than appending context-heavy instructions.

## 4. Proposed decisions and reason codes

The Gate emits **proposed** verdict and explicit reasons. These names
belong only to the Memory Promotion review contract and must not be
mistaken for ai-loop V2 Policy Verdict / terminal state or Production
`PromotionDecision`.

| Verdict | Reason code example | Effect |
|---|---|---|
| `approve` | `EVIDENCE_VERIFIED` | Recommend adoption **within existing applicable Human / policy authority** |
| `approve_with_conditions` | `CANARY_REQUIRED` | Propose restricted scope, expiry, independent verification |
| `needs_evidence` | `SOURCE_UNVERIFIABLE` | Hold; collect/source-check evidence |
| `needs_human_review` | `HUMAN_AUTHORITY_REQUIRED` | Hold until explicit Human authority |
| `reject` | `UNSAFE_BYPASS` | Do not promote unsafe guidance |
| `duplicate` | `EXISTING_OWNER` | Link existing rule/Skill/check; do not create duplicate |
| `prefer_automation` | `DETERMINISTIC_CHECK_AVAILABLE` | Route candidate to test/lint/CI |
| `deprecate` | `SUPERSEDED_RULE` | Propose sunset/rollback with source; Human review as needed |

Always return `candidate_id`, `decision`, `reason_codes[]`,
`rationale`, `evidence_refs[]`, `target_ref` or `null`,
`scope`, `conditions[]`, `human_review_required`,
`canary_plan_ref` or `null`, `rollback_ref` or `null`,
`revalidate_at` or `null`. The record additionally identifies
`candidate_revision` and `decision_record_id` for later provenance;
for a **proposal**, `approval_authority_ref` and `applied_artifact_ref`
are `null`. They become non-null only after verifying the **actual**
existing Human / policy authority record and the independently observed
applied revision. A claimed `actor` string or model name never
authenticates a Human decision.

**Fail-closed**: missing source, scope, revision or permission cannot
produce an actionable `approve`. `needs_human_review` is not approval.
A `deprecate` entry never automatically removes a rule or Hook.

## 5. Representative candidate adjudications (illustrative)

| Scenario | Evidence / risk | Proposal and why |
|---|---|---|
| A: project command example | Verified project README at pinned SHA; low blast radius; no execution | `approve` → project memory only; keep exact revision and owner; no global instruction |
| B: repeated missing validation | Two separate RunEvidence refs, same root cause; deterministic CI invariant feasible | `prefer_automation` → test/CI rather than another `CLAUDE.md` paragraph; require negative control |
| C: security Hook change | Incident evidence and high severity, Hook changes privileges or blocks operations | `needs_human_review`; gated HO approval and canary/rollback plan regardless of count |
| D: legacy bypass advice in old digest | Historical digest claims a write workaround; policy intent/current wiring not verified | `needs_evidence` initially; `reject` only if current policy/source confirms an unsafe bypass. **Never** convert bypass advice into executable guidance |

Scenario D is particularly important: `docs/working/improvement-digest.md`
includes a historical recommendation about bypass-like write workarounds.
That text is **not authorization** to bypass current Hook / EH-3
restrictions. Verify whether it is stale, unsafe or already superseded
through the current policy and actual wiring; preserve original historical
source without promoting the risky instruction.

## 6. Trust Ledger record format (proposal)

**Target location after C-3**:
`docs/working/_audit/memory-promotion-log.jsonl` (append-only;
schema described here / eventually in canonical doc). Empty committed log
does not mean any Gate decision occurred.

```json
{"candidate_id":"memory-promotion-2026-001","candidate_revision":"proposal-revision-1","decision_record_id":"proposal-001","record_type":"proposal","decision":"needs_human_review","reason_codes":["HUMAN_AUTHORITY_REQUIRED"],"rationale":"Hook scope expansion","evidence_refs":["issue-or-commit-ref"],"target_ref":null,"scope":"project","conditions":["explicit Human approval"],"human_review_required":true,"canary_plan_ref":null,"rollback_ref":null,"promoted_to":null,"model":"model-id-if-known","evidence_count":1,"human_intervention":false,"canary_scope":null,"before":null,"after":null,"rollback_count":0,"revalidate_at":null,"actor":"agent-or-human-id","approval_authority_ref":null,"applied_artifact_ref":null,"recorded_at":"2026-10-08T09:00:00+09:00"}
```

Record `record_type=proposal` is not an accepted Human decision.
Actual adoption requires independent, linked `record_type=decision`
with the real Human / policy authority reference, before/after evidence,
canary scope and effective revision. The Trust Ledger is evidence of
**what was recorded**, not proof that an irreversible action succeeded;
check the external artifact and matching SHA. Never backdate a proposed
decision as Human-approved. Changes / retractions are additional
append-only records referencing the superseded ID; do not edit history.

An append-only text file and Git history do **not** authenticate the
`actor` nor make the log tamper-proof. The consuming gate must independently
verify any approval against the applicable trusted Human/CI/Workflow
source, target revision and allowed scope; missing, inconsistent or
spoofable approval refs remain `needs_human_review`. If a source is
private, persist only a source reference permitted by its ACL: a public
audit log must never contain private excerpts or access tokens.

## 7. Canary, effect measurement, rollback

Before any future executable promotion:

1. Freeze candidate, proposal source and benchmark/eval baselines.
2. Obtain independent evidence: baseline vs candidate, activation check,
   negative/known-bad control, false-positive rate, security boundary
   invariants, token/time/cost and Human intervention.
3. Gain existing Human approval for Hook/HO/permissions/global rules.
4. Canary only in allowed project/task scope. Measure success, retries,
   regressions, unexpected blocks and effect on context overhead.
5. Fail or inconclusive ⇒ do not promote; stop and log reason.
6. If approved, bind changed ref/commit to candidate + evidence + decision.
7. Revalidate at the declared time; revert or deprecate through the
   existing Human/CI/Workflow authority, not via untrusted memory alone.

Do not let the candidate edit the evaluator, test oracle, thresholds,
sealed fixtures or promotion authority that judges it.

## 8. #1157 migrated acceptance — design implications

| ID | Necessary proof, not merely documentation |
|---|---|
| AC-1 | a trace of actual read at a pinned revision **plus** positive/negative control demonstrating downstream use; read-call presence alone does not prove useful consumption; L0/L1 remain authoritative |
| AC-2 | old bad advice can be corrected via adopted digest / append-only supersession; raw seeds immutable |
| AC-2b | bounded read budget, prefilter digest first; if oversized, return explicit truncation / remaining source refs and request targeted read |
| AC-3 | stable candidate fingerprint + linked prior source/run ids, evidence of re-use on a later run |
| AC-4 | raw seeds = historical source, adopted digest = derived non-authoritative summary, with source revision and owner / visibility constraints |

These proof obligations are **not met by this proposal**. They need
C-3-approved implementation and real usage evidence; don't check off the
migrated ACs from a Markdown link alone.

## 9. Git as an evidence and change ledger (not an autonomous memory engine)

Git is useful to **version and trace the artifacts that the existing
owners already produce**. It does not itself validate truth, grant
execution permission, authenticate the claimed Human approver or
make an unsafe memory record safe to replay.

| Responsibility | Existing Git-backed surface | Trust interpretation |
|---|---|---|
| Raw historical observations | `docs/working/improvement-seeds.md` and approved evidence refs | Historical claims; append-only does not mean verified/current |
| Consolidated knowledge view | `docs/working/improvement-digest.md` when adopted | Derived, scoped summary. The source seeds/revisions remain traceable |
| Proposed promotion review | TASK-scoped candidate/design/proposed decision | Draft; no authority until the applicable Human/policy gate |
| Accepted rule/Skill/test | Branch diff + PR + exact merged commit SHA | Changed implementation; recheck activation, regression and permissions |
| Audit decision history | Proposed `memory-promotion-log.jsonl`, append-only | Records submitted claims/decisions; separately authenticate authority |
| Correction / revocation | New linked supersession/deprecation record and a new PR | Preserve previous events; remove or revert active guidance only through existing gate |

### Identity, binding and safe reuse

A future candidate or decision record should refer to `repository`,
`source_path`, `source_commit_sha` (or immutable external evidence ID),
`candidate_id`, `decision_record_id`, `applied_commit_sha` (only after
actually observing application), `owner_scope` and `source_visibility`.
When links point at a moving branch (`main`, a mutable tag or a PR URL),
resolve its exact revision **before** relying on the content. Store the
resolved immutable reference and re-check its target at use time.

A `git show <sha>:<path>` lookup establishes **which bytes were present**,
not that the memory was correct, used, safe, permitted or causally effective.
A GitHub PR marked merged establishes the changed tree, not proof of
Human C-3/C-4 identity, external runtime activation, successful canary or
independent evaluation. A test PASS is bound to its exact checked commit
and does not transfer to another head automatically.

Do not duplicate RunState, canonical Plan, decision-log, RunEvidence or
PromotionDecision into a second git-based memory SSoT. Retrieval indices,
embeddings and summary caches, if separately introduced in the future,
must remain rebuildable, non-authoritative views with source revisions.
Never commit secrets, raw private session histories, sensitive personal
content or broader-access copies of owner-scoped memory. Redaction is not
a substitute for source authorization.

### Minimal closed-loop example (design, not a performed promotion)

```text
Run/CI fail at verified commit A
 -> source-bound failure Evidence and candidate
 -> check existing Rule/Test first (Reuse Before Create)
 -> candidate decision proposed: duplicate | prefer_automation | needs_evidence
 -> bounded test/Skill/Rule diff on branch (if appropriate)
 -> PR review + exact-head CI + existing Human C-3/C-4 gates
 -> merged commit B, followed by independent activation and recurrence evidence
 -> later supersession/rollback decision C if effect is absent or adverse
```

For issue #1525 the existing `ta-61-extra-contract.sh` TC-20 already
detects duplicate numeric test IDs. A candidate stating that this
needs a new always-on `CLAUDE.md` rule should first be triaged as
`duplicate` (existing deterministic enforcement) or
`prefer_automation` (move an existing check earlier, only with proof
of need). PR #1526 proposes to restore unique test IDs; it is **not**
an accepted Memory Promotion decision, a confirmed rollout or
independent evidence of improved long-term recurrence. Record actual
CI outcomes and any future reuse in their proper owners instead.

## 10. Proposed adoption decision (pending Human C-3)

**Partial adoption / documentation-first** is recommended because it
preserves existing owner contracts and allows adversarial review before
a new gate changes actual behavior. The Human already selected the
medium documentation scope on 2026-07-12. Acceptance of this detailed
proposal and exact HO wording still requires the synchronous C-3 Gate;
no self-approval or implicit authority is asserted.

Future output after C-3 would be a canonical document and template.
Automation, cross-repository integration, autonomous memory export and
a production promotion engine are separate issues, not hidden scope.
