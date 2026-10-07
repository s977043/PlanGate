# External verifier P0 preflight

Status: **repository-local candidate / non-authoritative**

This document connects ADR-007 to the P1 external-verifier setup without
modifying the content-addressed bootstrap package from #1484/#1493.

## Why this sits outside the bootstrap package

The four files under
`docs/working/_runtime-attestation/external-verifier-bootstrap/` are the exact
package bytes content-addressed by the existing bootstrap-manifest contract.
Changing those files merely to add a new P0 link would change the package
identity. This P0 preflight therefore lives outside that package.

## Command

```sh
python3 scripts/ai-loop/runtime_evidence_external_verifier_p0_preflight.py \
  --repo-root .
```

Current ADR-007 is `Proposed / NOT_MADE`, so the expected current result is:

- JSON is emitted without Human-owned field values (ADR SHA-256 + state only);
- `decision_record_structurally_valid=true`;
- `human_decision_recorded_candidate=false`;
- `p1_preflight_candidate=false`;
- `state=blocked_on_human_decision`;
- process exit code = 1.

After an explicit Human decision records a structurally complete
`Accepted / RECORDED_BY_HUMAN` ADR-007, the preflight may return exit code 0
with `p1_preflight_candidate=true`.

Even in that state:

```text
p1_activation_allowed=false
external_provisioning_allowed=false
```

Exit code 0 is **not** a provisioning trigger or permission. It is only a
repository-local structural preflight result.

## Critical limitation

A zero exit code means only:

> the repository-local ADR-007 structure is consistent with the recorded P0
> transition, including an exact match between `Decision Makers` and
> `decision_recorded_by`.

The output omits `Decision Makers` and all eight Human Decision Record values;
any required review of those values stays in the Human-owned ADR/evidence source.
An invalid line is not echoed into stderr.

It does **not** prove:

- that the named decision maker is actually Human (matching strings are not identity proof);
- that `decision_evidence_ref` is authentic;
- that the selected repository/service has been provisioned;
- that administrator separation exists;
- that the nonce ledger is externally operated;
- that any runtime attestation is valid;
- that Human rollout or dispatch has been approved.

Accordingly these fields remain false even for a structurally complete Accepted
record:

```text
human_decision_identity_verified=false
decision_evidence_ref_authenticated=false
external_boundary_provisioned_verified=false
p1_activation_allowed=false
external_provisioning_allowed=false
admin_evidence_independently_verified=false
nonce_one_time_consumption_verified=false
independent_admin_boundary_verified=false
independent_verifier_execution_attested=false
runtime_probe_attestation_verified=false
human_rollout_decision_verified=false
dispatch_ready=false
dispatch_allowed=false
```

## P1 handoff rule

1. Human explicitly records the P0 decision in ADR-007.
2. This preflight checks only structural consistency.
3. The Human/external operator independently confirms the actual decision and
   ownership boundary out of band.
4. Only then may P1 provisioning start.
5. P1/P2 must return independently verifiable external Evidence before any
   strong PlanGate field is considered for promotion.

The preflight must never be used as administrator-independence Evidence.
