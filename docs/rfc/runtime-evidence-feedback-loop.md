# RFC: Runtime Evidence Feedback Loop

**Status**: Draft
**Created**: 2026-10-03
**Scope**: ai-loop V2 design proposal (non-canonical)
**Source case study**: Cloudflare "Detect and send production issues straight to your agent" (2026-09-30)

## 1. Motivation

ai-loop V2 already separates Delivery, Learn, and Evolve, but production/runtime observations are not yet described as a first-class external input boundary.

Cloudflare Workers Issues provides a useful reference pattern:

```text
Production telemetry
  -> issue detection / grouping
  -> diagnostic context
  -> trigger
  -> coding agent
  -> repository investigation
  -> code / test change
  -> pull request
  -> human review / deploy
```

The reusable idea is not Cloudflare-specific automation. It is the boundary:

> Runtime observations become evidence packages that can seed a new bounded development run without giving the runtime system authority to bypass PlanGate gates.

This RFC proposes a provider-neutral Runtime Evidence Feedback Loop for ai-loop V2.

## 2. Design principles

### 2.1 Runtime is an evidence source, not an approval authority

Production systems may emit observations and trigger investigation, but they do not decide that a code change is correct or safe.

```text
Runtime
  -> Observation
  -> Evidence Package
  -> Intake / Triage
  -> Plan / Investigation
  -> Build
  -> Verify
  -> PR
  -> Human-owned boundary
```

Runtime evidence can start work. It cannot weaken C-3/C-4, merge, policy, permission, Hardening Override, or Production Harness promotion boundaries.

### 2.2 Evidence before agent autonomy

An agent should not be started from an unbounded log stream. A runtime event should first be reduced into a bounded evidence package with provenance.

Minimum properties:

- source system and source reference
- observed time window
- issue / failure fingerprint
- occurrence count or recurrence signal
- relevant logs / traces / stack information
- affected version / deployment identity when available
- application context that is explicitly safe to expose
- redaction status
- confidence / missing evidence
- links for deeper investigation

### 2.3 Observation != cause

Runtime detection records what happened. Root cause remains a hypothesis until verified.

```text
Observation -> Cause Hypothesis -> Repository Evidence -> Verification
```

The intake contract must keep observed facts separate from inferred causes.

### 2.4 Trigger != permission

A threshold crossing or recurrence may trigger a new investigation request, but it does not grant permission to edit arbitrary files or perform irreversible operations.

```text
Event trigger
  != approval
  != allowed_paths
  != merge authority
```

### 2.5 Provider-neutral core

Cloudflare Issues is a reference implementation only. The core model should support equivalent sources such as:

- Cloudflare Workers Issues
- Datadog / Sentry / OpenTelemetry pipelines
- CI production smoke failures
- application-specific incident detectors
- generic webhooks

Provider adapters should translate external events into the same internal intake contract.

## 3. Proposed architecture

```text
[Production / External System]
          |
          v
[Observation Collector]
          |
          v
[Issue Grouper / Fingerprinter]
          |
          v
[Runtime Evidence Package]
          |
          v
[Intake Policy]
  |       |        |
  |       |        +--> ignore / deduplicate
  |       +-----------> wait / aggregate
  +-------------------> create bounded work request
                              |
                              v
                       [PlanGate / ai-loop V2]
                              |
                              v
                   Plan -> Verify Plan -> Build
                              |
                              v
                      Verify -> PR convergence
                              |
                              v
                         MERGE_READY
                              |
                              v
                       Human C-4 / merge

Production release / deployment remains outside the PlanGate workflow boundary.
```

## 4. Runtime Evidence Package

This RFC does not define a persisted schema yet. The following shape is informative and exists to clarify responsibilities.

```yaml
runtime_evidence:
  source:
    provider: ""
    environment: ""
    event_ref: ""
  observation:
    first_seen_at: ""
    last_seen_at: ""
    fingerprint: ""
    occurrence_count: 0
    recurrence: false
  deployment:
    version: ""
    commit_ref: ""
  evidence_refs:
    logs: []
    traces: []
    stack: []
  application_context:
    refs: []
  privacy:
    redaction_applied: true
    secret_scan_status: ""
  assessment:
    confidence: ""
    missing_evidence: []
```

The package is a transport / intake artifact, not a judgment artifact.

## 5. Intake policy

The intake layer should decide only what happens next, not whether the eventual code change is valid.

Suggested actions:

| Condition | Action |
| --- | --- |
| known duplicate with active work | attach evidence to existing work |
| low-signal / below threshold | aggregate and wait |
| recurrence after quiet period | create investigation request |
| threshold exceeded | create investigation request |
| security-sensitive or secret exposure suspected | human escalation |
| missing provenance / malformed evidence | reject or quarantine |
| provider unavailable for deeper evidence | continue only if minimum evidence contract is met; otherwise wait / escalate |

The exact threshold policy should remain project-owned and should not be hard-coded into ai-loop V2 core.

## 6. Connection to Delivery / Learn / Evolve

### Delivery

Runtime evidence may create the initial request or be attached to an existing task.

```text
Runtime Evidence
  -> Request
  -> Plan
  -> Plan Verification
  -> Delivery Loop
  -> MERGE_READY
```

A runtime-originated task has the same Delivery gates as any other task.

### Learn

The runtime observation becomes part of RunEvidence and Retrospective inputs:

- failure fingerprint
- environmental evidence
- detection latency
- investigation latency
- false-positive / duplicate rate
- evidence gaps
- repair outcome

### Evolve

Repeated runtime patterns may create Harness improvement candidates:

- better Verifier
- better diagnostic Skill
- improved failure fingerprinting
- better context collection
- safer intake policy
- better routing

These remain candidates and must pass the existing independent evaluation / promotion process.

## 7. Security and privacy boundary

Runtime telemetry may contain credentials, personal data, customer payloads, session identifiers, or internal topology.

Therefore:

1. raw telemetry must not be copied blindly into agent context;
2. provider adapters must support redaction / allowlisting before agent handoff;
3. secret detection failure must fail closed for automatic handoff;
4. application context should prefer opaque references over raw sensitive values;
5. evidence retention and downstream storage must follow the project's data-handling policy;
6. generic webhook integrations must authenticate the sender and protect against replay / spoofing.

The goal is a useful investigation context, not maximal context.

## 8. Relationship to existing V2 boundaries

This proposal must not change the following existing contracts:

- `ai-dev-workflow` remains stable;
- Delivery ends at `MERGE_READY`;
- C-4 / merge remain Human-owned;
- release / deployment remains outside the PlanGate workflow responsibility boundary;
- active Harness identity is immutable during a Run;
- Runtime input cannot modify Evaluation Trust Boundary or protected authority;
- Observation and Cause Hypothesis remain separate.

This RFC should be treated as an external Evidence intake extension, not a new approval path.

## 9. Cloudflare case study mapping

Cloudflare's 2026-09-30 article demonstrates a concrete implementation of the pattern:

| Cloudflare concept | V2 interpretation |
| --- | --- |
| Workers Issues | Observation Collector + Issue Grouper |
| occurrence threshold / recurrence | Intake trigger |
| issue diagnostic context | Runtime Evidence Package |
| Claude Code / Cursor / Devin / webhook | Agent / orchestrator adapter |
| Cloudflare MCP | deeper Evidence acquisition |
| proposed code / test changes | Builder output |
| pull request | Delivery artifact |
| human review / deploy | Human-owned downstream boundary |

Reference:
- https://blog.cloudflare.com/real-time-issue-detection/

## 10. Non-goals

This RFC does not propose:

- autonomous production deployment;
- automatic merge;
- incident-management replacement;
- making Cloudflare a required dependency;
- copying all production logs into model context;
- redefining V2 taxonomy;
- redefining existing Evidence / Promotion authority;
- creating a second mutable state machine beside the existing V2 owners.

## 11. Proposed adoption path

### Phase A — contract only

1. agree on Runtime Evidence Package semantics;
2. define security / redaction requirements;
3. define deduplication / recurrence semantics;
4. identify which existing V2 artifact owns the intake reference;
5. define a minimal fixture set.

### Phase B — one adapter PoC

Use exactly one external source and one repository:

```text
External issue
  -> normalized runtime evidence
  -> bounded work request
  -> existing PlanGate / ai-loop path
  -> PR
```

The PoC should stop at PR / `MERGE_READY`; it must not auto-deploy.

### Phase C — evaluation

Measure:

- time from runtime signal to investigation-ready context;
- duplicate suppression rate;
- missing-context rate;
- false-positive trigger rate;
- time to first verified cause hypothesis;
- time to `MERGE_READY`;
- human attention required;
- sensitive-data redaction failures.

Only after evidence supports the design should the proposal be promoted into V2 canon.

## 12. Open questions

1. Should Runtime Evidence be its own artifact type, or a typed external Evidence reference owned by an existing V2 artifact?
2. Which component owns deduplication and recurrence state?
3. Is a runtime trigger allowed to create a GitHub Issue automatically, or only an internal work request?
4. What minimum evidence is required before an agent may start repository investigation?
5. Which fields must be redacted or converted to opaque references?
6. How should a runtime-originated task bind to deployment / commit identity when the running version is not traceable?
7. What metrics are sufficient to decide whether the adapter improves Time to Learning without increasing unsafe automation?

## 13. Decision requested

Before promotion into ai-loop V2 canon, review this RFC against:

- North Star: Evidence before judgment / Stable boundaries / Delivery vs Evolution;
- Core Contract: workflow responsibility ends before production release;
- Evaluation Trust Boundary: external runtime data cannot become protected authority;
- privacy / security requirements;
- provider neutrality and reversibility.
