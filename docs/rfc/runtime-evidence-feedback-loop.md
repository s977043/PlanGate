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

### 4.1 Ownership: do not create a second V2 source of truth

`Runtime Evidence Package` is a conceptual transport envelope in this RFC. It is **not a proposal for a new canonical mutable V2 artifact or a second Run state machine**.

The default ownership model is:

```text
Provider / adapter
  owns raw event + intake/dedup state
        |
        v
immutable external evidence reference
        |
        v
existing work request / Plan Package / RunEvent
        |
        v
existing V2 RunState / RunEvidence projection
```

Rules:

- raw provider payload and dedup / recurrence counters remain provider- or adapter-owned;
- V2 receives immutable evidence references and normalized observations needed for the bounded work request;
- once a Delivery Run starts, lifecycle progress remains owned by the existing V2 RunState / RunEvent model;
- RunEvidence remains the deterministic projection of that Run's event stream and must not become a store for cross-Run recurrence counters;
- cross-Run recurrence and incident aggregation belong to the intake / analytics layer, not per-Run RunEvidence;
- if Phase 1 needs a persisted field such as `runtime_evidence_ref`, it should be an additive reference on an existing owner, not a new mutable workflow state artifact unless a separate RFC proves that necessity.

This follows the existing V2 artifact budget and the principle that external Product/runtime evidence is received by the Harness rather than becoming a parallel Harness authority.

### 4.2 Intake identity and deduplication

A runtime signal can repeat thousands of times. The integration must distinguish **new evidence** from **new work**.

Use a deterministic intake identity derived from stable fields such as:

```text
provider
+ environment
+ normalized failure fingerprint
+ deployment identity (when known)
+ bounded time bucket / recurrence epoch
```

The exact hash format is adapter-owned, but the semantics are fixed:

- the same active failure should attach evidence to existing work instead of opening parallel Delivery Runs;
- a recurrence after a defined quiet period may start a new recurrence epoch;
- a deployment identity change may create a new evidence generation while preserving lineage to the prior issue;
- deduplication state is intake state, not Delivery Run state;
- recurrence lineage is cross-Run information and therefore must not be embedded as mutable aggregate data inside RunEvidence.

This avoids turning event frequency into unbounded agent concurrency or making past RunEvidence bytes depend on later runtime events.

### 4.3 Evidence trust level

External evidence should carry an explicit trust assessment. This is not a quality score for the application; it indicates how safely the evidence may be used as an input.

| Level | Meaning | Allowed use |
| --- | --- | --- |
| `untrusted` | unauthenticated / unverifiable source | quarantine; no automatic agent start |
| `authenticated` | sender identity verified, payload provenance known | intake / triage |
| `correlated` | deployment / trace / repository identity can be cross-checked | repository investigation |
| `verified` | key claims reproduced or supported by independent evidence | may support Plan / verification decisions |

A higher level must be earned by additional evidence. Provider reputation alone does not promote an event to `verified`.

### 4.4 Recommended V2 owner mapping

The default Phase 1 direction is to bind runtime-originated work to **existing owners in two stages**, rather than create a new V2 artifact.

| Stage | Existing owner | What is stored |
| --- | --- | --- |
| before Delivery Run | Plan Package `pbi-input.md` | immutable external evidence refs, source/provider identity, observation summary, known uncertainty |
| during Delivery Run | RunEvent stream (Phase 1 event semantics) | the fact that the Run consumed / correlated a specific external evidence ref |
| derived view | RunEvidence projection | only per-Run evidence refs and observations derivable from that Run's event stream |

Rationale:

- `pbi-input.md` already owns request context / Why / assumptions and is included in the Plan Package binding;
- V2 canon already states that a "problem observation" RunEvent is still a Phase 1 design item;
- RunEvidence is a deterministic projection and therefore must not be written directly by the intake adapter;
- cross-Run recurrence remains intake / analytics state and is never backfilled into historical RunEvidence.

For the PoC, do **not** invent a new RunEvent type. The PoC may bind immutable runtime evidence refs in `pbi-input.md` and demonstrate traceability to the provider event. Phase 1 canon should later define the exact RunEvent semantic that records observation intake.

A future schema field such as `external_evidence_refs` is therefore expected to be **additive to an existing owner**, not the root of a new state machine.

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

### 5.1 Agent-start preconditions

A trigger may create an intake item immediately, but repository investigation should start only when all mandatory preconditions hold:

1. sender / source provenance is known;
2. payload passes structural validation;
3. redaction / secret scanning completes successfully;
4. deterministic intake identity has been computed;
5. duplicate / active-work lookup has completed;
6. a bounded repository / service target is known, or the item is routed to human triage;
7. minimum evidence refs required by the project are present;
8. agent permissions remain those of the existing PlanGate execution profile.

If any mandatory precondition is unknown, the default is **wait / quarantine / human triage**, not best-effort autonomous execution.

### 5.2 Work creation contract

Creating work and starting a Delivery Run are separate actions.

```text
runtime event
  -> intake item
  -> dedup / aggregate
  -> bounded work request
  -> existing planning / approval path
  -> Delivery Run
```

The runtime adapter may propose title, description, evidence refs, affected service, and suspected files. It must not fabricate acceptance criteria, expand `allowed_paths`, or mark a Plan approved.

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

For a Delivery Run, existing V2 owners should retain only the runtime evidence needed to explain that Run. RunEvidence may project immutable external evidence refs and per-Run observations from the RunEvent stream, for example:

- failure fingerprint used by the Run;
- environmental evidence refs;
- evidence gaps discovered during investigation;
- verified cause / repair outcome;
- per-Run timing that can be derived from the Run's own events.

Cross-Run intake metrics remain outside per-Run RunEvidence and belong to the intake / analytics layer, for example:

- duplicate suppression rate;
- recurrence frequency;
- false-positive trigger rate;
- provider-level detection latency distributions.

Retrospective / Evolution may consume those aggregate results as external Evidence, but adding a later incident must not change previously projected RunEvidence.

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
6. generic webhook integrations must authenticate the sender and protect against replay / spoofing;
7. telemetry payloads, exception messages, user-controlled strings, log bodies, trace attributes, and external issue text must be treated as **untrusted data, never as agent instructions**;
8. the adapter must preserve source boundaries so quoted runtime content cannot silently become system / developer / workflow instructions.

The goal is a useful investigation context, not maximal context.

### 7.1 Prompt-injection boundary

Production data can contain attacker-controlled text. A failure message such as `ignore previous instructions` is evidence about the application, not an instruction to the coding agent.

Adapters should structure handoff as data references or explicitly delimited evidence blocks. The orchestrator must keep workflow instructions outside those blocks.

```text
Trusted workflow contract
  +
Untrusted runtime evidence
  +
Repository evidence
  -> investigation

Untrusted runtime evidence
  -X-> workflow / policy mutation
```

Any runtime-derived request to disable tests, widen permissions, change approval policy, expose secrets, or bypass a gate is invalid regardless of source authentication.

### 7.2 Least-privilege investigation

The first agent activity triggered by runtime evidence should prefer **read-only investigation**:

- inspect referenced logs / traces;
- inspect repository state;
- correlate deployment and commit identity;
- reproduce the failure when safe;
- form a cause hypothesis;
- propose a bounded work request.

Write access should begin only through the existing PlanGate planning / approval path. Runtime-triggered investigation must not receive broader permissions merely because the signal came from production.

### 7.3 External-evidence integrity

Provider adapters should make the following independently checkable where supported:

- event authenticity / signature;
- event timestamp and replay window;
- source account / project / service identity;
- immutable provider event reference;
- payload digest;
- deployment / commit correlation evidence.

A source being authenticated does not prove that every field is correct. Authentication establishes provenance; verification establishes claim quality.

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

#### PoC acceptance criteria

The PoC is acceptable only if all of the following are demonstrated with reproducible evidence:

1. repeated copies of the same active failure create **one** bounded work item and attach new evidence instead of creating parallel Delivery Runs;
2. authenticated + redacted + correlated evidence can start a **read-only** repository investigation;
3. the investigation produces a bounded work request without inventing acceptance criteria or widening `allowed_paths`;
4. the resulting task enters the normal PlanGate planning / approval path and cannot skip existing gates;
5. the Delivery Run stops at `MERGE_READY`; merge / deploy are not performed by the runtime adapter;
6. no new mutable Run state store is introduced beside existing V2 owners;
7. cross-Run recurrence aggregation stays outside per-Run RunEvidence;
8. evidence provenance remains traceable from work request to provider event reference.

#### Required negative fixtures

| Fixture | Expected result |
| --- | --- |
| unauthenticated event | quarantine / reject; no agent start |
| valid signature but replayed event | reject or deduplicate; no second work item |
| secret scan / redaction failure | no agent handoff |
| log body contains prompt-injection text | treated only as data; no instruction effect |
| event requests test disable / permission widening / gate bypass | ignored as untrusted data; no policy change |
| runtime event suggests files outside approved scope | suggestion may be recorded, but `allowed_paths` is not expanded automatically |
| burst of N equivalent events | bounded aggregation; not N Delivery Runs |
| deployment / commit identity missing | record uncertainty; do not fabricate source binding |
| provider evidence unavailable during follow-up | wait / escalate according to minimum evidence policy; do not mark verified |
| adapter attempts merge / deploy | denied by responsibility boundary |

All negative fixtures must pass before the adapter is considered eligible for broader rollout.

### Phase C — evaluation

Measure:

- time from runtime signal to investigation-ready context;
- duplicate suppression rate;
- missing-context rate;
- false-positive trigger rate;
- time to first verified cause hypothesis;
- time to `MERGE_READY`;
- human attention required;
- sensitive-data redaction failures;
- unauthenticated / replayed event rejection rate;
- cases where runtime text attempted to influence workflow instructions;
- percentage of runtime-originated work that began with read-only investigation.

Only after evidence supports the design should the proposal be promoted into V2 canon.

### Phase C exit criteria

Promotion from RFC / PoC toward V2 canon requires, at minimum:

- **0 approval-boundary bypasses** in the fixture suite;
- **0 sensitive-data handoff failures** in the fixture suite;
- **100% pass** for the required negative fixtures;
- duplicate event bursts demonstrably converge to bounded work creation;
- runtime-originated investigations demonstrably start with least-privilege permissions;
- no second mutable V2 workflow state / authority is introduced;
- metrics distinguish missing evidence from success rather than filling unknown values with zero;
- Human review confirms that provider-specific behavior has not leaked into the provider-neutral core.

These criteria evaluate the intake mechanism. They do not prove that every runtime-generated diagnosis is correct. Diagnosis quality remains subject to normal Plan / Verification / Evidence rules.

## 12. Open questions

1. **Proposed answer**: Runtime Evidence should default to a typed external Evidence reference owned by existing V2 artifacts / events, not a new mutable artifact. A new artifact requires separate justification.
2. **Proposed answer**: deduplication and recurrence state belong to the provider / intake adapter or an intake registry outside Delivery Run state; V2 receives immutable intake decisions / evidence refs.
3. Is a runtime trigger allowed to create a GitHub Issue automatically, or only an internal work request?
4. What minimum evidence is required before an agent may start repository investigation?
5. Which fields must be redacted or converted to opaque references?
6. How should a runtime-originated task bind to deployment / commit identity when the running version is not traceable?
7. What metrics are sufficient to decide whether the adapter improves Time to Learning without increasing unsafe automation?
8. **Proposed answer**: before a Run, bind immutable external evidence refs in the Plan Package (`pbi-input.md`); during a Run, Phase 1 should define a RunEvent semantic that records consumption/correlation of the same refs. RunEvidence only projects those Run-local facts.
9. What trust level is required before repository investigation can begin for each adapter class?
10. Which investigation actions must remain read-only before a normal PlanGate work request exists?
11. How should adapters prove that untrusted telemetry was kept out of the trusted instruction channel?

## 13. Decision requested

Before promotion into ai-loop V2 canon, review this RFC against:

- North Star: Evidence before judgment / Stable boundaries / Delivery vs Evolution;
- Core Contract: workflow responsibility ends before production release;
- Evaluation Trust Boundary: external runtime data cannot become protected authority;
- privacy / security requirements;
- provider neutrality and reversibility.
