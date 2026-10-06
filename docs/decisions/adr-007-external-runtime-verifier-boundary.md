# ADR-007: Independent Runtime Verifier Boundary Decision Packet

**Status**: Proposed  
**Date**: 2026-10-06  
**PBI**: #1473（Parent: #1468）  
**Decision Makers**: Human / external-boundary administrator — UNASSIGNED

---

> **This ADR is a decision packet, not a completed decision.**
> AI/automation may prepare options and evidence, but MUST NOT change this ADR to `Accepted`,
> populate Human-owned identities, provision the external boundary, or promote strong authority
> fields without an explicit Human decision.

## Context

PlanGate has completed the repository-side candidate chain needed to consume a future independently
administered runtime-verifier boundary:

- #1470: read-only verification-command candidate
- #1471: external verifier receipt candidate
- #1475 / #1478 / #1479: external-admin admission, canonical Evidence URI, provenance and nonce hardening
- #1483 / #1484: external-verifier bootstrap handoff and content-addressed package manifest
- #1485 / #1493: external verifier provenance candidate and bootstrap↔provenance v2 binding

The repository can now fail closed on self-reference, wrong Evidence subjects, malformed Evidence URIs,
ambiguous bootstrap packages, package tampering, stale/mismatched provenance, and candidate
self-promotion.

What it still cannot prove is administrator independence. A repository-authored file, workflow,
boolean, or issue comment cannot make the repository independent from itself.

The next step in #1473 is therefore a Human-owned P0 decision about the actual external trust boundary.
This ADR makes that decision explicit and auditable without making it on behalf of the Human owner.

## Problem Statement

Four facts are required before external implementation can safely begin:

```text
external_verifier_location = UNDECIDED
external_verifier_admin = UNDECIDED
nonce_ledger_owner = UNDECIDED
trusted_issuer = UNDECIDED
```

If implementation starts while any of these remain undecided, PlanGate risks creating a nominally
"external" component whose administration is still under the same authority, or creating Evidence
that the repository can self-author.

The decision therefore needs to precede provisioning.

## Decision Drivers

- **Administrative independence**: the verifier boundary must be outside normal PlanGate repository writes.
- **Auditability**: ownership, issuer, workflow identity, nonce lifecycle, and Evidence location must be reviewable.
- **Least privilege**: the verifier must not gain PlanGate code-write, approval-write, merge, or deploy authority.
- **Replay resistance**: nonce issue/consume/reuse rejection must be operated outside PlanGate authority.
- **Cryptographic verifiability**: later promotion requires authenticated Evidence, not self-authored claims.
- **Operational clarity**: the selected boundary must have a named owner and an actionable P1 setup path.
- **Reversibility**: changing the selected boundary must require a new Human decision, not silent automation.
- **No authority collapse**: machine attestation, Human rollout, and dispatch remain separate gates.

## Considered Options

### Option A: Dedicated verifier repository with separately controlled administration

Create or select a repository whose administration is separated from normal PlanGate repository
authority. The verifier workflow, signer identity, source-digest policy, and nonce integration are
pinned there.

**Pros**:
- GitHub Actions OIDC can be a concrete issuer candidate.
- Workflow identity can be pinned to `owner/repo/.github/workflows/file.yml@<40-sha>`.
- Repository and workflow provenance are straightforward to audit.
- Fits the existing #1470/#1471 verification model.

**Cons**:
- Independence depends on real administrator separation, not merely a different repository name.
- Requires explicit owner/admin assignment and access-policy maintenance.
- A repository controlled by the same unrestricted admin boundary is not sufficient Evidence.

**Decision status**: CANDIDATE — not selected.

### Option B: External verification service / separate trust root

Use a service or trust root that is operationally and administratively independent from PlanGate.

**Pros**:
- Can provide stronger organizational separation than another repository.
- Can own nonce state and signing material outside GitHub repository authority.
- May provide purpose-built audit logs and key rotation.

**Cons**:
- Higher integration and operational cost.
- Evidence format and issuer policy need an adapter compatible with #1493 v2.
- External availability and lifecycle management become dependencies.

**Decision status**: CANDIDATE — not selected.

### Option C: Another PlanGate-local workflow or repository-authored verifier

Add another workflow/file inside PlanGate and label it "external" or "independent".

**Pros**:
- Lowest implementation cost.

**Cons**:
- Same repository authority can author both the claim and the verifier.
- Cannot provide administrator-separation Evidence.
- Violates #1473's trust-boundary requirement.

**Decision status**: REJECTED.

### Option D: Separate repository without separate administration

Create a second repository, but leave unrestricted administration under the same effective authority
as PlanGate.

**Pros**:
- Separate repository identity.

**Cons**:
- Repository separation is not administrator separation.
- Creates an appearance of independence without the required trust boundary.

**Decision status**: REJECTED unless an independently reviewable admin-separation model is established.

## Decision

**Decision state: NOT_MADE.**

The following values are Human-owned and MUST remain `UNDECIDED` until explicitly recorded by the
Human decision maker:

```text
external_verifier_location = UNDECIDED
external_verifier_admin = UNDECIDED
nonce_ledger_owner = UNDECIDED
trusted_issuer = UNDECIDED
```

### Acceptance rule

This ADR may move from **Proposed** to **Accepted** only when all of the following are true:

1. a Human explicitly selects Option A or Option B, or documents another reviewed equivalent;
2. `external_verifier_location` names the selected external boundary;
3. `external_verifier_admin` names the person/team/account boundary responsible for it;
4. `nonce_ledger_owner` names the external owner/service for issue/consume/reuse state;
5. `trusted_issuer` names the intended issuer/trust root;
6. the Human decision is recorded in an auditable location;
7. the decision does **not** assert that independence has already been proven merely because this ADR exists.

AI/automation MUST NOT satisfy items 1–6 on behalf of the Human owner.

### P1 activation gate

External provisioning may start only after this ADR is `Accepted` by a Human and all four values above
are non-placeholder values.

Until then:

```text
external_boundary = NOT_PROVISIONED
authenticated_external_evidence = NOT_AVAILABLE
admin_evidence_independently_verified = false
nonce_one_time_consumption_verified = false
independent_admin_boundary_verified = false
independent_verifier_execution_attested = false
runtime_probe_attestation_verified = false
human_rollout_decision_verified = false
dispatch_ready = false
dispatch_allowed = false
```

The `Proposed` ADR itself is planning material. It is not external Evidence.

## P1 Handoff Checklist

After Human acceptance:

- provision the selected external verifier boundary;
- establish and capture auditable admin separation;
- independently retrieve and verify the #1484 content-addressed bootstrap package bound by #1493;
- pin immutable verifier workflow/binary identity;
- pin signer workflow and source-digest policy;
- configure the selected issuer/trust root;
- deny self-hosted runners unless separately reviewed;
- establish external nonce issue/consume/reuse-rejection state;
- produce authenticated provenance Evidence compatible with #1493 v2;
- attest the exact #1471-bound artifact;
- return only independently verifiable Evidence to the later PlanGate promotion PR.

## Consequences

### Positive

- The Human decision point becomes explicit instead of being hidden inside implementation.
- An AI agent can prepare options without gaining authority to select or provision the trust boundary.
- P1 has a concrete start condition.
- Future reviewers can distinguish "decision recorded" from "independence proven".
- The existing Evidence != Judgment and machine-attestation != Human-rollout boundaries remain intact.

### Negative / Risks

- Work intentionally stops at P0 until a Human records the decision.
- A second repository can still be falsely treated as independent if admin separation is not reviewed.
- The selected external boundary adds operational ownership and lifecycle work.
- This ADR alone cannot satisfy any strong attestation field.

## Related

- #1468 — independently administered R1 runtime attestation verifier
- #1473 — external verifier boundary execution owner
- #1470 — verification-command candidate
- #1471 — external verifier receipt candidate
- #1475 / #1478 / #1479 — external-admin / Evidence URI / nonce hardening
- #1483 / #1484 — bootstrap handoff and content addressing
- #1485 / #1493 — provenance candidate and bootstrap↔provenance binding v2
- `docs/working/_runtime-attestation/external-verifier-bootstrap/`
- `docs/working/_runtime-attestation/r1-external-verifier-provenance.proposed.json`
