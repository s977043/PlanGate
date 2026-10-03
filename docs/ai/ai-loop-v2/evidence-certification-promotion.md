# Evidence Certification View and Risk-Based Promotion Policy

> **Status**: Design guide for issue #1458. Non-canon; existing ai-loop V2 canon takes precedence.
> **Source**: Anthropic, "How to prepare for AI-driven code modernization projects".
> **Scope**: Reuse existing ai-loop V2 artifacts and authority. Do not introduce a new authoritative Certificate artifact, lifecycle state, verdict, or promotion authority.

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
Certification View (projection only)
      |
      v
existing Policy / Decision boundary
```

The Certification View answers:

> For this exact target and exact revision, which policy-required claims are backed by applicable evidence, which are not, and which remain unresolved?

It does **not** answer "may this change merge?" by itself.

### 2.1 Projection-only rule

The Certification View MUST NOT emit or own:

- Policy Verdict;
- Lifecycle State;
- Terminal Outcome;
- Stop Reason;
- `PromotionDecision`;
- C-4 / Merge / Production Harness authority.

It may expose the inputs needed by the existing Policy / Decision boundary, but the projection itself never mints authority.

### 2.2 No new SSoT

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

### 3.1 Required-evidence ownership

The **required evidence set is a policy input**, not Builder output.

A Builder / change author may report target characteristics, but MUST NOT be the sole authority that:

- lowers required verifier coverage;
- removes independent review;
- marks a protected surface as low risk;
- narrows a verifier set;
- changes the Evaluation Trust Boundary.

Where the required-evidence set is derived dynamically, its derivation rule / policy identity must be traceable. Missing or unverifiable policy input is not permission to use a weaker set.

## 4. Binding and invalidation

Evidence is valid only for the target it actually proves.

At minimum, the projection must preserve existing binding where available:

- Plan / Contract identity;
- source SHA / final head SHA;
- artifact or target hash;
- HarnessManifest identity;
- verifier identity and kind;
- evaluation-plan / fixture binding for Evolution;
- policy / verifier-set identity when it controls required evidence.

A Certification View MUST NOT combine evidence from different revisions merely because the test names or task IDs look similar.

The view becomes stale when a bound input changes. Reuse requires re-verification or an existing verifier-specific rule that proves the previous evidence still applies.

```text
changed bound input
  -> previous certification projection invalid
  -> verify applicability / re-run as required
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
| bounded + reversible + deterministic evidence strong | existing automated path may continue **only when existing policy already permits it** |
| moderate impact or material uncertainty | require stronger independent evidence and targeted Human attention |
| high blast radius / irreversible / security-sensitive | existing policy should resolve to Human-required handling |
| protected authority / Gate / Verifier weakening | existing Human-owned rules apply; risk classification cannot relax them |
| evidence unavailable / unbound / stale | fail closed; do not treat absence as PASS |

These rows are guidance, not a new persisted risk taxonomy and not a new verdict table.

### 5.1 Risk input is not self-authorizing

A risk label produced by the same Agent that authored the change is a **claim**, not trusted authority.

The policy owner must decide how risk inputs are established, for example through deterministic path/rule classification, protected metadata, or sufficiently independent review. If trustworthy classification is unavailable, the system must not choose a less restrictive path on that basis.

### 5.2 Monotonic safety rule

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

A current-Run repair may still be necessary to complete Delivery. The principle is additive:

- repair the current output when the Delivery contract permits it;
- when the failure reveals a repeated/systemic Harness weakness, create a separate Evolution Candidate;
- do not mutate the active Harness to fix the current Run.

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
- stale evidence after a bound Plan / target change cannot satisfy a requirement;
- Builder self-report alone cannot satisfy a requirement;
- missing / unavailable verifier output cannot become PASS;
- Builder-supplied risk cannot choose a less restrictive path by itself;
- risk classification cannot disable protected verification;
- required verifier-set / policy identity cannot be silently narrowed;
- River Review output cannot directly mint promotion authority;
- Delivery evidence cannot directly promote a Harness Candidate;
- Certification projection cannot mutate its authoritative inputs.

## 11. Non-goals

- a new `Certificate.json` SSoT;
- a new lifecycle state or terminal outcome;
- a new Policy Verdict;
- a second PromotionDecision;
- a new canonical risk taxonomy;
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
