# ai-loop V2 Ratchet Traceability — Phase 1 Implementation Contract

> **Status**: Phase 1 implementation contract for #1376 / #1381
> **Normative source**: existing ai-loop V2 canon takes precedence.
> **Scope**: this document is not one of the canon 7 files and does not redefine Delivery taxonomy or Human-owned authority.

## Purpose

The Evolution Loop must turn observed failures into evidence-backed Harness improvement proposals without silently rewriting the Harness.

```text
FailureRecord / RunEvidence
  -> HarnessImprovementCandidate
  -> evaluator-observed Harness delta
  -> paired known-bad + negative-control evidence
  -> HarnessExperimentResult
  -> PromotionDecision
  -> Human-owned Production promotion
```

The current executable slice is intentionally narrow: `verification-skipped`.

## Artifact ownership

No new top-level artifact is introduced.

| Concern | Owner |
|---|---|
| immutable failure observation | FailureRecord + RunEvent |
| per-Run aggregate evidence | RunEvidence |
| pattern snapshot / hypothesis / declared scope | HarnessImprovementCandidate |
| Harness N / N+1 identity | HarnessManifest |
| actual delta / paired evaluation / activation | HarnessExperimentResult |
| PASS / FAIL / INCONCLUSIVE | PromotionDecision |
| production promotion / merge | Human-owned boundary |

## Identity and provenance

### Failure instance

A failure instance is bound to:

```yaml
run_id: ...
event_ref: ...
failure_record_ref: sha256:...
run_evidence_ref: sha256:...
```

`event_ref`, `failure_record_ref`, and `run_evidence_ref` are evaluator-verified bindings. The evaluator reuses the owner RunEvent validator to recompute the RunEvent digest, requires a `failure_recorded` event for the same `run_id`, binds its FailureRecord payload to `failure_record`, and requires the RunEvent / RunEvidence `harness_manifest_ref` to agree. It independently recomputes the FailureRecord and RunEvidence content refs.

This does not make Ratchet a second RunEvent-stream validator: stream ordering and cross-event reference rules remain owned by the RunEvent spine. Ratchet consumes one already-materialized content-addressed source event to prove failure-instance identity.

`failure_fingerprint` is a classifier/search hint, not primary identity.

### Pattern snapshot

Pattern classification is Candidate-local rather than a new mutable Pattern SSoT.

```yaml
pattern_id: pattern:verification-skipped
pattern_version: 1
classifier_digest: sha256:...
source_set_digest: sha256:...
fingerprint: sha256:...
occurrence_count: 1
scope: project
```

`source_set_digest` is recomputed from stable failure-instance tuples. A Candidate cannot self-attest the source set.

### Expected prevention claim

A Candidate that enters this Ratchet slice must make its prevention claim structurally explicit:

```yaml
expected_prevention:
  mode: detect | prevent | stop | reduce_impact
  pattern_refs: [pattern:...]
  expected_effect: ...
```

The current `pattern_snapshot.pattern_id` must appear exactly once in a non-empty `pattern_refs` set, and `expected_effect` must be non-empty. Missing or mismatched claims are `INCONCLUSIVE / EXPECTED_PREVENTION_BINDING`.

This binding proves only **what the Candidate claims it will improve**. It is not evidence that the change works. Paired replay, known mutants, negative controls, activation, and independent evaluation remain the effectiveness evidence.

## Evaluation plan authority

The evaluation plan is supplied to the evaluator separately from the Candidate.

The Candidate stores only `evaluation_plan_digest`.

The evaluator recomputes that digest. A Candidate cannot make itself self-consistent by supplying a weaker plan.

The sealed plan fixes at least:

- baseline HarnessManifest ref
- known-bad fixture ID + digest
- negative-control fixture ID + digest
- known-mutant fixture IDs + digests
- required activation level
- protected evaluation paths
- critical regression conditions

Changing the plan after seeing results creates a new evaluation.

## Actual delta authority

Candidate `allowed_paths` is a declaration.

The evaluator compares baseline and candidate Harness manifests and derives:

- changed components
- before/after content SHA
- actual changed paths

Required invariant:

```text
actual changed paths ⊆ Candidate.allowed_paths
```

A mismatch is fail-closed.

If actual changed paths intersect protected Evaluation Harness / sealed fixture paths, ordinary paired evaluation cannot promote the Candidate.

How actual changed paths are derived:

- Path canonicalization and scope matching are owned by `scripts/ai-loop-v2/scope_observer.py`; Ratchet no longer imports a private path helper from the provisional Decision core.
- For every changed Harness component, the paths of **both** the baseline and the candidate side are counted. Moving a protected component under `allowed_paths` is still seen on its baseline path.
- Every counted path must be canonical: no empty string, no leading `/`, and no `.` / `..` / duplicate segment. `fnmatch`'s `*` crosses `/`, so `harness/verifiers/../../x` would otherwise match `harness/verifiers/*`. A non-canonical path is `FAIL` (`NON_CANONICAL_CHANGED_PATH`).
- A changed component without a non-empty `paths` list is `INCONCLUSIVE` (`COMPONENT_PATHS_MISSING`): an empty path set would make the subset check vacuous.
- A manifest whose components lack a `component_id` or repeat one is `INCONCLUSIVE` (`MANIFEST_COMPONENT_IDENTITY`): a duplicate could shadow a changed component.
- Synthetic fixture evaluation continues to use the manifest-observed delta for deterministic regression compatibility.
- Repository-backed evaluation additionally observes changed paths from an exact baseline/candidate commit pair using `git diff --no-ext-diff --name-only -z --no-renames`. Only full lowercase commit object IDs are accepted, the repository root is verified, and observation failure is `INCONCLUSIVE`.
- Repository-observed baseline/candidate commit IDs must equal the corresponding HarnessManifest `source_commit` values.
- Every manifest-observed changed component path must also appear in the repository-observed changed path set. A mismatch is `INCONCLUSIVE / MANIFEST_REPOSITORY_DELTA_MISMATCH`; the Candidate cannot hide a manifest change by supplying another repository delta.
- Scope and protected-authority checks use the repository-observed path set in repository-backed mode. An extra repository path outside `allowed_paths` is `FAIL / ACTUAL_DELTA_OUTSIDE_ALLOWED_PATHS`; an extra protected path is `FAIL / PROTECTED_AUTHORITY_CHANGED`.
- Protected authority is checked before the `allowed_paths` subset check, so a protected mutation is not downgraded into a generic scope error.

Repository-backed evaluation is a stronger evidence path; it does not turn the current synthetic vertical-slice fixture into Production evidence. The real completion verifier / owner Decision integration required by #1381 AC-6 remains separate.

## Verification-skipped paired evaluation

Known-bad:

```text
verification evidence missing

baseline
  -> existing deterministic tests PASS
  -> completion path remains available
  -> MERGE_READY (miss reproduced)

candidate
  -> completion-evidence verifier produces unavailable evidence
  -> Decision Engine consumes that VerificationResult
  -> BLOCKED / VERIFIER_UNAVAILABLE
```

Negative control:

```text
valid verification evidence present

candidate
  -> completion-evidence verifier PASS
  -> completion path remains available
  -> MERGE_READY
```

Known-mutant detection power is evaluated by the stable Ratchet evaluator, not by the Candidate verifier itself. The sealed plan pins the mutant IDs and their fixture digests. Baseline and Candidate run the exact same mutant set; if the Candidate detects fewer mutants than the baseline, the result is `FAIL / BASELINE_DETECTION_POWER_REGRESSION`. Duplicate or unsealed mutant IDs make the evaluation `INCONCLUSIVE`.

For the current `verification-skipped` vertical slice, the incident fixture is also the first known mutant. This keeps the contract narrow while proving the non-regression rule before adding a larger mutant corpus.

The Candidate is not considered active merely because the component is installed or registered.

For this verifier/gate improvement the required activation is:

```text
influenced_decision
```

The Decision must contain the relevant VerificationResult ref.

## Result semantics

```text
PASS
  all pre-registered conditions pass
  critical regression = 0

FAIL
  known-bad is not stopped
  negative control regresses
  Candidate known-mutant detection power falls below baseline
  Candidate allowed scope is malformed
  actual delta exceeds allowed scope
  protected authority is changed

INCONCLUSIVE
  identity/provenance cannot be verified
  baseline miss is not reproduced
  activation is below influenced_decision
  required manifest/evidence is missing
  evaluation-plan binding is invalid
```

`INCONCLUSIVE` never promotes.

"Identity/provenance cannot be verified" includes at least:

- no source failure instance (`SOURCE_INSTANCE_BINDING`)
- a repeated failure-instance tuple (`SOURCE_INSTANCE_BINDING`)
- a source `event_ref` that does not match the recomputed RunEvent ref (`SOURCE_FAILURE_BINDING`)
- a source RunEvent that is not `failure_recorded`, has a different `run_id`, carries a different FailureRecord payload, or disagrees with RunEvidence on `harness_manifest_ref` (`SOURCE_FAILURE_BINDING`)
- a source `run_id` that differs from its RunEvidence `run_id` (`SOURCE_FAILURE_BINDING`)
- a pattern snapshot missing `pattern_id` / `pattern_version` / `classifier_digest` / `source_set_digest` (`PATTERN_SNAPSHOT_INCOMPLETE`)
- a missing or invalid `expected_prevention`, unsupported prevention mode, duplicate/missing current pattern ref, or empty expected effect (`EXPECTED_PREVENTION_BINDING`)
- a sealed plan that does not pin the digests of the known-bad, negative-control, and known-mutant fixtures (`EVALUATION_PLAN_INCOMPLETE`)
- a missing, empty, duplicate, or unsealed known-mutant set (`EVALUATION_PLAN_INCOMPLETE`)

The simulated delivery artifact's change set is part of each sealed fixture (`changed_paths`), so it is covered by the fixture digest.

## Promotion handoff and reverse provenance

PromotionDecision records:

- candidate ID + content ref
- candidate HarnessManifest ref
- ExperimentResult ref
- source failure-instance refs
- decision + reason codes
- `production_promotion_executed: false`

This permits lookup from Harness N+1 candidate identity to Candidate and back to source failure evidence without adding a new RatchetRecord artifact.

Production promotion itself remains Human-owned.

## Recurrence measurement

Do not record a counterfactual `prevented_recurrence_count`.

The minimal recurrence observation is:

```yaml
pattern_classifier_digest: sha256:...
eligible_run_count: N
matching_failure_run_count: M
same_pattern_recurrence_rate: M / N
```

Only observations using the same classifier digest belong to the denominator.

`occurrence_count` may trigger investigation but never grants promotion authority.

## Create Last / lifecycle operations

Evolution supports:

- CREATE
- UPDATE
- SPLIT
- MERGE
- DEPRECATE

New Skill / Agent / Hook / Flow creation is not the default response to a repeated failure.

Evaluate, in order:

1. existing configuration correction
2. deterministic test / lint / invariant
3. existing Verifier improvement
4. reuse / update / merge / deprecate
5. create only when existing ownership cannot express the fix

## Scorer-driven improvement linkage

A future scorer may supply derived evaluation provenance such as #908 / #910 refs.

That does not replace primary evidence.

```text
primary evidence
  = RunEvent / FailureRecord / RunEvidence

derived evidence
  = scorer / Run Evaluation Result / judge calibration
```

Raw conversation transcript, hidden CoT, credentials, and unbounded session memory are not Ratchet assets.

## Current executable evidence

- `scripts/ai-loop-v2/ratchet.py`
- `scripts/ai-loop-v2/scope_observer.py`
- `scripts/ai-loop-v2/test_ratchet.py`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped.json`
- `tests/fixtures/ai-loop-v2/ratchet/evolution-input-non-success.json`
- `tests/extras/ta-92-ai-loop-v2-ratchet.sh`

The vertical slice verifies:

- evaluator-owned plan digest
- immutable source provenance, including owner-validated RunEvent content binding
- source-set digest
- Candidate expected-prevention claim binding (claim != effectiveness evidence)
- evaluator-observed delta
- sealed fixture integrity
- protected-surface fail-closed
- paired baseline/candidate behavior
- negative control
- sealed known-mutant baseline detection power
- non-success Evolution inputs: `HUMAN_ESCALATED`, `BLOCKED`, crash/partial, and `NO_PROGRESS`
- influenced-decision activation
- PASS / FAIL / INCONCLUSIVE
- reverse promotion provenance
- recurrence measurement
- no automatic production promotion
