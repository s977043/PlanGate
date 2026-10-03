# Evidence Certification View and Risk-Based Promotion Policy

> **Status**: Design guide for issue #1458. Non-canon; existing ai-loop V2 canon takes precedence.
> **Source**: Anthropic, "How to prepare for AI-driven code modernization projects".
> **Scope**: Reuse existing ai-loop V2 artifacts and authority. Do not introduce a new authoritative Certificate artifact, lifecycle state, or promotion authority.

## 1. Why this exists

AI can produce code changes faster than a Human can review every diff in depth. The resulting bottleneck moves from code generation toward proving correctness, selecting the right review depth, and deciding whether a change may advance.

ai-loop V2 already has the core primitives needed for this:

- `VerificationResult`: immutable verifier output bound to the verified target;
- `RunEvidence`: deterministic per-Run projection;
- Policy Verdict: `AUTO_APPROVED | HUMAN_REQUIRED | DENIED`;
- `PromotionDecision` for Harness Evolution;
- Human-owned C-4 / Merge / Production Harness promotion;
- River Review as an external source of independent review / verification evidence.

The design goal is therefore not to copy Anthropic's vocabulary as another SSoT. It is to add a **composition rule** for existing evidence and policy.

## 2. Core model

Anthropic's `Certificate` maps to a non-authoritative **Certification View**.

```text
Target / Contract
  + VerificationResult[]
  + RunEvidence
  + identity bindings
  + policy-required evidence
      |
      v
Certification View
      |
      v
existing Policy / Decision boundary
```

The Certification View answers:

> For this exact target and exact revision, which required claims have trustworthy evidence, which do not, and which remain unresolved?

It does not mint authority and does not replace any underlying artifact.

### 2.1 No new SSoT

The view MUST be reproducible from existing authoritative inputs.

It MUST NOT become:

- a new mutable source of truth;
- a replacement for `VerificationResult`;
- a replacement for `RunEvidence`;
- a replacement for Policy Verdict;
- a second `PromotionDecision`;
- a way to bypass C-4 / Merge / Production Harness promotion.

If persisted for debugging or Human-facing projection, it is cache/report material only and is invalid when its bound inputs change.

## 3. Certification inputs

A Certification View should project at least the following concerns when they are applicable to the target.

| Concern | Existing evidence owner |
|---|---|
| acceptance / behavioral correctness | deterministic / specification `VerificationResult` |
| build / type / lint / static checks | deterministic `VerificationResult` |
| security / policy | security verifier / policy evidence |
| E2E / runtime behavior | bound verifier evidence / external observation |
| independent review | independent reviewer or River Review evidence |
| Run-level provenance | `RunEvidence` / RunEvent projection |
| Plan / source identity | existing plan hash / source SHA / final head SHA |
| Harness identity | `harness_manifest_ref` |
| Evolution evaluation | `HarnessExperimentResult` + `PromotionDecision` |

The required set is selected by existing policy and task/target characteristics. The change author or Builder MUST NOT be the sole authority that weakens the required set.

## 4. Binding and invalidation

Evidence is valid only for the target it actually proves.

At minimum, the projection must preserve existing binding where available:

- Plan / Contract identity;
- source SHA / final head SHA;
- artifact or target hash;
- HarnessManifest identity;
- verifier identity and kind;
- evaluation-plan / fixture binding for Evolution.

A Certification View MUST NOT combine evidence from different revisions merely because the test names or task IDs look similar.

The view becomes stale when a bound input changes. Reuse requires re-verification or an existing verifier-specific rule that proves the previous evidence still applies.

```text
changed target
  -> previous certification projection invalid
  -> verify again
  -> build a new projection
```

## 5. Risk-based Promotion Policy

The purpose of risk is to select **required evidence and Human attention**, not to create authority.

Relevant policy inputs include:

- blast radius;
- reversibility / irreversibility;
- security / permission / approval boundary impact;
- data or privacy impact;
- uncertainty and evidence quality;
- whether a protected Gate / Verifier / Policy surface changes;
- whether independent review is required by existing trust-boundary rules.

An illustrative policy shape is:

| Risk shape | Evidence / review posture |
|---|---|
| bounded + reversible + deterministic evidence strong | existing automated path may continue when current policy allows it |
| moderate impact or material uncertainty | require stronger independent evidence and targeted Human attention |
| high blast radius / irreversible / security-sensitive | `HUMAN_REQUIRED` |
| protected authority / Gate / Verifier weakening | existing Human-owned rules apply; risk classification cannot relax them |
| evidence unavailable / unbound / stale | fail closed; do not treat absence as PASS |

These rows are guidance, not a new persisted risk taxonomy.

### 5.1 Monotonic safety rule

A lower risk classification MUST NOT remove an invariant already required by canon or protected authority.

```text
risk classification
  -> may add evidence / review requirements
  -> may route Human attention
  -> MUST NOT weaken protected requirements
```

## 6. Delivery and Evolution stay separate

### Delivery

Certification supports the existing Delivery contract up to `MERGE_READY`.

```text
Execute
  -> Verify
  -> Evidence
  -> Certification View
  -> existing Policy / Decision logic
  -> MERGE_READY or stop/escalate
  -> Human C-4 / Merge
```

`MERGE_READY` keeps its current meaning.

### Evolution

Harness changes use the existing Evaluation Trust Boundary and ratchet flow.

```text
FailureRecord / RunEvidence
  -> HarnessImprovementCandidate
  -> paired evaluation
  -> HarnessExperimentResult
  -> PromotionDecision
  -> Promotion Ready
  -> Human-owned Production promotion
```

Delivery certification MUST NOT be reused as proof that a Harness Candidate is safe to promote.

## 7. River Review boundary

River Review can provide independent review / verification evidence.

It does not own:

- PlanGate Policy Verdict;
- Delivery terminal state;
- C-4;
- Merge;
- Production Harness promotion.

```text
River Review
  -> finding / verification evidence
  -> PlanGate consumes evidence
  -> PlanGate policy / decision boundary decides
```

This keeps review knowledge and independent Quality Control separate from promotion authority.

## 8. Repair the workflow, not only the output

Repeated failures should not be handled only by patching the current output.

```text
repeated / material failure
  -> FailureRecord / RunEvidence
  -> systemic cause hypothesis
  -> HarnessImprovementCandidate
  -> independent evaluation
  -> canary
  -> Promotion Ready
```

This is the existing Evolution Loop. No live self-modification is introduced.

## 9. Pilot before scale

Adoption should progress through bounded stages.

1. **Shadow projection**
   - compute/read the evidence composition without changing Gate behavior;
   - compare projected missing evidence with current Human review findings.
2. **Human-facing compression**
   - show required claims, evidence refs, unresolved gaps, and risk drivers;
   - keep full provenance reachable.
3. **Policy-assisted routing**
   - use the projection to select stronger verifier / independent review / Human attention;
   - no C-4 or merge authority change.
4. **Bounded automation**
   - widen only after false-negative / false-positive and stale-binding behavior are measured;
   - protected authority remains Human-owned.

Scale is evidence-driven, not based on the number of successful demos.

## 10. Minimum verification for this design

Before any runtime implementation, verify at least these negative cases:

- evidence from the wrong head SHA cannot satisfy a requirement;
- stale evidence after Plan / target change cannot satisfy a requirement;
- Builder self-report alone cannot satisfy a requirement;
- missing / unavailable verifier output cannot become PASS;
- risk classification cannot disable protected verification;
- River Review output cannot directly mint promotion authority;
- Delivery evidence cannot directly promote a Harness Candidate;
- Certification projection cannot mutate its authoritative inputs.

## 11. Non-goals

- a new `Certificate.json` SSoT;
- a new lifecycle state or terminal outcome;
- a new Policy Verdict;
- a second PromotionDecision;
- automatic C-4 / merge;
- automatic Production Harness promotion;
- replacing River Review, Verifier, Decision Engine, or Policy;
- storing hidden CoT / raw unbounded transcripts.

## 12. Relationship to existing V2 docs

This guide is subordinate to:

- `north-star.md` — Human Attention, Evidence before judgment, Delivery/Evolution boundaries;
- `artifact-responsibilities.md` — `VerificationResult`, `RunEvidence`, Decision responsibility;
- `evaluation-trust-boundary.md` — independent evaluation, protected authority, `INCONCLUSIVE`;
- `ratchet-traceability.md` — evidence-backed Harness improvement and promotion handoff.

If this guide conflicts with canon, canon wins.
