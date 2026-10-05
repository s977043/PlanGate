# External R1 verifier bootstrap package

Status: **proposal / non-activating**

This package is a handoff contract for creating the independently administered
verifier boundary tracked by #1473. Files under this directory are examples and
requirements only. They MUST NOT be treated as proof that administrator
separation exists.

## Boundary rule

PlanGate may define the contract, but PlanGate must not self-certify the
external boundary.

The external operator must establish, outside normal PlanGate repository write
authority:

- a separately administered signer repository or equivalent verifier service;
- an immutable signer workflow/binary identity;
- GitHub Actions OIDC (or an explicitly reviewed equivalent issuer);
- GitHub-hosted execution unless a self-hosted runner is separately reviewed;
- a one-time nonce ledger with atomic issue/consume/reuse rejection;
- three independently retrievable Evidence objects:
  - administrator-separation-attestation, subject = signer_repo;
  - signer-identity-attestation, subject = signer_workflow@signer_digest;
  - nonce-lifecycle-policy, subject = nonce_owner.

## Bootstrap sequence

1. Content-address the exact reviewed bootstrap package with
   `runtime_evidence_external_verifier_bootstrap_manifest.py`. Treat the
   declared PlanGate source commit as a bound candidate value, not independently
   verified Git provenance.
2. Give the external operator the exact package bytes + package content hash.
   Repository-local generation does not prove operator receipt or acceptance.
3. Provision the external signer repository/service under separately controlled administration.
4. Apply the workflow/policy equivalent to `verifier-workflow.proposed.yml`.
5. Accept the external-operator responsibilities in `operator-handoff.proposed.json`.
6. Establish the nonce ledger described by `nonce-ledger-policy.proposed.json`.
7. Freeze the real signer workflow digest and source policy.
8. Produce the three Evidence objects outside PlanGate.
9. Build the external boundary descriptor consumed by
   `runtime_evidence_external_admin_admission.py`.
10. Run PlanGate admission. Treat PASS as structural admission only.
11. Independently verify the Evidence objects and the accepted bootstrap package identity.
12. Only then open a separate promotion PR for evidenced strong fields.

## Stop conditions

Stop and keep all strong fields false if any of the following is true:

- the signer repository can be administered by normal PlanGate repository writers;
- the nonce ledger is owned by PlanGate or the attestation repository;
- the verifier identity is mutable or branch-only;
- self-hosted runner execution is possible without separate review;
- Evidence is stored only in PlanGate;
- nonce consumption cannot be proven one-time and atomic;
- the external verifier cannot attest the exact #1471 receipt artifact.

## Authority

This package never changes:

```text
admin_evidence_independently_verified=false
nonce_one_time_consumption_verified=false
independent_admin_boundary_verified=false
independent_verifier_execution_attested=false
runtime_probe_attestation_verified=false
human_rollout_decision_verified=false
dispatch_ready=false
dispatch_allowed=false
```
