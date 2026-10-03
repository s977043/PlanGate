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

### 1.1 Existing implementation baseline — do not duplicate the PBI materializer

This RFC is **not** the owner of feedback / Evidence -> PBI materialization.

Existing work already owns that responsibility:

- #1440 / PR #1441 — bounded Requirement Discovery and `pbi-input.md` semantic authority;
- #1442 / PR #1443 — deterministic shadow/read-only PBI materializer and live-shadow evidence collector;
- `scripts/ai-loop/pbi_materializer.py` — intentionally network-free primitive; GitHub / network access belongs to an adapter;
- `scripts/ai-loop/pbi_live_shadow_collector.py` — persists repository-visible live-shadow evidence under the task evidence namespace.

Therefore the remaining responsibility of this RFC is narrower:

> **External Runtime Ingress Adapter = external provider telemetry -> authenticated, sanitized, repository-visible source evidence -> existing #1442/#1443 materializer / collector path.**

```text
External Runtime Provider
        |
        v
Runtime Ingress Adapter            <- this RFC / follow-up implementation
        |
        v
repository-visible source evidence
        |
        v
#1442 / PR #1443 materializer + collector
        |
        v
bounded pbi-input proposal
        |
        v
existing PlanGate path
```

The adapter must reuse the existing materializer decisions (`materialize | no_action | discover_more` and `update_existing | link_only | create_new`) rather than invent parallel admission or PBI-decision semantics.

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

For the PoC, do **not** invent a new RunEvent type. The external adapter should first materialize a sanitized repository-visible source artifact and feed that source ref into the existing #1442/#1443 shadow path. The resulting PBI proposal may bind the immutable runtime evidence ref in `pbi-input.md`. Phase 1 canon should later define the exact RunEvent semantic that records observation intake.

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

### 5.3 Adapter -> existing admission contract

The ingress adapter must translate provider-specific payloads into the existing #1442/#1443 admission signal contract instead of defining a parallel schema.

Current required semantic fields are:

| Field | Runtime adapter rule |
| --- | --- |
| `signal_id` | deterministic ID derived from provider event / intake identity; retries preserve the same logical ID |
| `source_ref` | repository-visible sanitized source artifact; never a raw external URL as the only evidence |
| `statement` | concise sanitized statement of what the provider reported; no executable instructions |
| `source_kind` | normally `external_source` for provider-originated runtime evidence |
| `claim_class` | default `reported`; promote to `observed` only when the claim is independently correlated with evidence owned by the receiving system |
| `disposition` | `actionable | resolved | informational | ambiguous`; unknown mapping must become `ambiguous`, not guessed |
| `target_layer` | `delivery` for the first PoC; Harness routing remains #874/#869-owned |
| `candidate_problem` | optional bounded problem statement; absent when evidence does not justify one |

Example normalized signal:

```json
{
  "signal_id": "runtime:<stable-intake-id>",
  "source_ref": "docs/working/_runtime-ingress/<provider>/<intake-sha256>/<snapshot-sha256>.json",
  "statement": "External runtime provider reported repeated failures for the deployed service.",
  "source_kind": "external_source",
  "claim_class": "reported",
  "disposition": "actionable",
  "target_layer": "delivery",
  "candidate_problem": "A production failure is recurring and requires bounded investigation."
}
```

#### Claim-class rule

Authentication proves **where the event came from**, not that all provider fields are independently true.

```text
authenticated provider event
  -> reported

reported
  + independent repository/runtime correlation
  -> observed (only for the correlated claim)

model inference / guessed root cause
  -> inferred
```

The adapter must not label a root-cause hypothesis `observed` merely because the source event is authenticated.

#### Repository-visible source snapshot

Before the existing materializer consumes an external signal, the adapter creates a sanitized repository-visible source snapshot. A standalone production incident arrives **before** a PBI/TASK exists, so the first snapshot must not require a `TASK-XXXX` namespace.

Recommended pre-PBI shape:

```text
docs/working/_runtime-ingress/<provider>/<intake-sha256>/<snapshot-sha256>.json
```

This namespace stores immutable sanitized evidence only; mutable dedup / recurrence state remains provider- or adapter-owned. The logical intake digest is stable across equivalent occurrences, while the filename is the **full SHA-256 of the canonical sanitized snapshot**. Therefore the repository path itself binds the Evidence content. After a PBI/TASK is created, `pbi-input.md` references this source artifact.

When the observation is already bound to an existing ai-loop Run and the TASK/run/final-head/time contract is available, the existing #1443 `pbi_live_shadow_collector.py` may additionally bind the signal into task-scoped live-shadow evidence. The collector is **not** a prerequisite for standalone external incident admission. The snapshot should contain only data required to establish provenance and support investigation, for example:

```yaml
runtime_source:
  schema_version: "1"
  provider: "<provider enum>"
  provider_event_id_hash: "sha256:..."
  intake_identity: "sha256:..."
  captured_at: "<RFC3339>"
  environment: "<sanitized enum>"
  issue_fingerprint: "sha256:..."
  deployment_ref: "<sanitized/opaque ref or unavailable>"
  occurrence:
    count: 0
    recurrence: false
  summary:
    error_type: "<sanitized type>"
    statement: "<bounded sanitized text>"
  evidence:
    trace_refs: []
    log_refs: []
  redaction:
    applied: true
    secret_scan: "pass"
```

This is a sanitized provenance snapshot, not a raw telemetry archive. Full logs / traces stay at the provider or approved evidence store.

The source snapshot must be create-only or idempotently reusable for the same canonical content. A retry that produces different content for the same immutable source ref fails closed rather than overwriting prior evidence. Consumers must recompute the canonical snapshot hash and confirm it matches the full digest encoded in `source_ref` before trusting the snapshot.

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

The first activity triggered by runtime evidence should prefer **read-only investigation**. The R1 first slice reuses the existing Explorer role rather than creating a runtime-only Agent:

- inspect repository-visible Evidence refs;
- inspect repository state;
- correlate deployment and commit identity;
- form a cause hypothesis;
- propose a bounded candidate problem.

The initial R1 shadow contract does **not** permit web search, network shell, credential reads, test/build execution, or write-capable shell. Provider evidence may be read only through an approved read-only connector. Runtime-derived text must not define repository paths, commands, tool policy, or trusted instructions.

Static role/config declarations are not runtime enforcement evidence:

```text
read_only_declared
  != hard_read_only_enforced
  != runtime_role_registered
  != dispatch_ready

# only after a real PlanGate Run exists:
selected / fired / produced_evidence / influenced_decision
  -> V2 RunEvent ownership
```

The #1452 shadow implementation therefore keeps `hard_read_only_enforced=false`, `dispatch_ready=false`, `dispatch_allowed=false`, and `agent_invoke_allowed=false`. #1453 adds a pre-run readiness evaluator, but repository-authored candidate Evidence cannot self-attest runtime provenance or Human rollout authority, so `dispatch_ready` remains false until independent verifier/adapter paths exist.

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


### 7.3 External trust roots for R1 dispatch

Pre-PBI R1 dispatch needs two authority classes that repository-authored files cannot self-prove:

1. **runtime attestation** — the runtime actually registered the intended role/connector and enforced the read-only boundary for the exact R1 request;
2. **Human rollout authority** — a Human explicitly approved R1 dispatch through a trust root that automation cannot impersonate merely by writing repository files.

#### GitHub owner comments are candidate Evidence, not Human authority

A live GitHub issue comment can prove useful facts:

- exact repository / issue / comment binding;
- repository-owner account;
- `author_association=OWNER`;
- not authored via a GitHub App;
- exact R1 `request_hash` binding;
- whether the comment was edited.

However, GitHub issue-comment metadata cannot distinguish a Human using the Web UI from automation using the owner's user credential/PAT. Therefore:

```text
owner_account_decision_candidate = true
live_github_metadata_verified = true

human_presence_verified = false
human_identity_verified = false
human_rollout_decision_verified = false
```

#1454 implements this boundary. The owner-account comment is useful out-of-band candidate Evidence, but it does not authorize dispatch.

A stronger Human trust root is still required, for example:

- protected-environment approval; or
- human-held signing-key attestation.

TTY + nonce may remain a best-effort Human-presence pattern, consistent with the existing C-3 approval design, but must not be represented as a strong identity/security boundary.

#### Existing Claude read-only canary is a reusable pattern, not request-bound attestation

`.github/workflows/claude-subscription-canary.yml` provides a strong read-only canary pattern:

- main-only;
- repository-owner workflow dispatch;
- GitHub-hosted runner;
- read-only tool surface;
- post-run mutation checks.

But it is not currently bound to the specific R1:

- `request_hash`;
- Explorer `config_sha`;
- runtime role registration;
- provider connector registration;
- hard read-only enforcement for that request.

Therefore it cannot set `runtime_probe_attestation_verified=true` for R1. A future request-bound canary/verifier must bind those values through an independently verifiable runtime result before dispatch readiness may advance.


#### Request-bound canary proposal remains fail-closed

#1455 adds a reviewed proposal outside the active `.github/workflows` surface plus a live GitHub Actions verifier.

The proposal binds:

- exact R1 `request_hash`;
- Explorer `config_sha`;
- platform;
- provider;
- trusted `main` source;
- exact active workflow bytes.

The current contract stage is `r1-request-bound-v1-unavailable`. The runtime-probe step deliberately exits non-zero with `UNAVAILABLE` because no platform-specific Explorer registration/invocation adapter has been reviewed yet. For this stage, an unexpected successful canary run is invalid.

The proposal may declare `environment: runtime-r1-rollout`, but repository YAML does not prove the GitHub Environment's required-reviewer configuration. Likewise the verifier process cannot attest its own trusted execution provenance. Therefore:

```text
protected_environment_declared = true
protected_environment_configuration_verified = false
verifier_execution_attested = false
runtime_probe_attestation_verified = false
human_rollout_decision_verified = false
dispatch_ready = false
dispatch_allowed = false
```

All GitHub reads used by the implementation must flow through the existing `scripts/ai-loop/gh_exec.py` allowlisted GET boundary; direct `urllib` / arbitrary network access in `scripts/ai-loop/` is forbidden by the repository execution-boundary checker.


### 7.4 Codex Explorer lifecycle probe candidate

#1456 adds a Codex-specific **candidate observation layer** without promoting runtime attestation.

Codex provides structured multi-agent/runtime observation surfaces including lifecycle hooks such as `SubagentStart` and `SubagentStop`. For the R1 Explorer candidate, the proposed hook wiring observes only `agent_type=explorer_agent`.

The candidate verifier requires:

- exact `request_hash`, Explorer `config_sha`, and provider binding;
- exactly one Explorer `SubagentStart` and one `SubagentStop`;
- matching session / turn / agent / role / permission mode;
- start-before-stop ordering;
- bounded record count / JSONL size;
- canonical record hashes;
- hook Evidence stored outside the repository;
- neutral hook stdout so observation data cannot become model context.

The result intentionally remains:

```text
runtime_role_observed_candidate = true
explorer_execution_candidate = true
candidate_trace_structure_verified = true

hook_execution_root_attested = false
codex_jsonl_runtime_correlation_verified = false
hard_read_only_enforced = false
runtime_probe_attestation_verified = false
dispatch_ready = false
dispatch_allowed = false
```

This distinction is required because repository/project hook execution is a runtime observation source, not an independently trusted attestation root.

Codex also supports administrator-managed hooks as a separate policy layer. A future production-grade attestation design may use a managed-hook execution root (or an equivalent independently administered external verifier) so the Evidence producer is outside the repository-controlled project hook boundary. Merely moving the current proposal into project `hooks.json` does not satisfy this requirement. A future promotion requires correlation with runtime-generated Codex JSONL plus an external/trusted execution-root proof before `runtime_probe_attestation_verified` may change.


### 7.5 Codex JSONL pairing candidate

#1457 adds a second Codex observation source using bounded `codex exec --json` output.

Repository evidence from TASK-1078 confirms `item.completed` events such as `command_execution` and `agent_message`. That JSONL does **not** currently provide the R1 `request_hash`, Explorer `config_sha`, provider identity, or a direct Explorer `agent_id` join key.

Therefore #1457 deliberately models:

```text
lifecycle hook candidate
        +
Codex JSONL structural summary
        ↓
cross_source_pairing_candidate = true

same_run_copresence_verified = false
same_run_identity_verified = false
codex_jsonl_runtime_correlation_verified = false
runtime_probe_attestation_verified = false
dispatch_allowed = false
```

Both raw inputs stay outside the repository. The sanitized result retains only bounded counts, hashes, recognized item categories, and non-promotion flags; raw command text, prompts, agent messages, reasoning, transcripts, and runtime log bodies are not copied.

Promotion requires a trusted join key or independently administered capture manifest that proves both observation streams belong to the same concrete runtime execution.


### 7.5 Codex JSONL pairing candidate hardening

#1457 pairs the #1456 Explorer lifecycle candidate with a bounded `codex exec --json` trace, but deliberately does not claim same-run correlation because current JSONL evidence does not carry the R1 `request_hash`, Explorer `config_sha`, provider identity, or the hook candidate's `agent_id`.

The correlator therefore validates both sides independently:

- hook candidate must still assert `runtime_role_observed_candidate=true` and `explorer_execution_candidate=true`;
- all hook-side authority-bearing fields remain false;
- Codex JSONL must contain at least one `item.completed`;
- the trace must contain a later `turn.completed`, proving only that the captured turn reached a completion boundary;
- raw command/message/reasoning bodies are not copied into the artifact;
- raw hook/JSONL inputs must remain outside the repository both lexically and after path resolution, preventing repository symlink indirection.

Even after these checks:

```text
cross_source_pairing_candidate = true
trace_completion_candidate_verified = true

same_run_copresence_verified = false
same_run_identity_verified = false
direct_agent_id_correlation_available = false
trusted_jsonl_capture_root_attested = false
codex_jsonl_runtime_correlation_verified = false
runtime_probe_attestation_verified = false
dispatch_allowed = false
```

A future promotion requires an independently trustworthy shared join key or capture root; structural completion alone is not same-run proof.


### 7.5 Codex exec JSONL thread correlation candidate

#1461 correlates the #1456 Explorer lifecycle-hook candidate with the public `codex exec --json` thread/turn envelope.

The public exec JSONL currently provides a stable `thread.started.thread_id`, but `turn.started` has no turn identifier and the public ThreadItem union has no subagent identity item. Therefore the strongest current deterministic correlation is:

```text
hook.session_id == exec.thread.started.thread_id
```

together with a single successful turn envelope.

The resulting trust state is intentionally split:

```text
exec_jsonl_structure_verified = true
thread_id_correlation_verified = true
single_turn_envelope_verified = true

turn_id_correlation_verified = false
subagent_identity_correlation_verified = false

command_execution_read_only_verified = false
mcp_tool_read_only_verified = false
repository_postcondition_verified = false

codex_jsonl_runtime_correlation_verified = false
hard_read_only_enforced = false
runtime_probe_attestation_verified = false
dispatch_ready = false
dispatch_allowed = false
```

The correlation layer also rejects explicit `file_change`, `web_search`, and `error` items, but their absence is not proof that shell commands or MCP calls were read-only. Repository postconditions require a separate verifier.

Raw exec JSONL may include reasoning summaries, agent messages, commands, arguments, and outputs. The correlation result therefore persists only opaque identifiers, counts, booleans, and the content hash; raw traces remain outside the repository.

A future promotion requires a runtime surface that independently exposes the exact turn/subagent identity (or an equivalent signed execution relation), plus independently verified read-only enforcement and repository postconditions.

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

Use exactly one external source and one repository. The adapter is intentionally thin:

```text
provider event
  -> authenticate / replay check
  -> normalize
  -> redact / secret scan
  -> fingerprint / deduplicate
  -> correlate repository / deployment
  -> read-only investigation
  -> bounded pbi-input candidate
  -> existing PlanGate planning / approval path
  -> Delivery Run
  -> PR / MERGE_READY
```

The PoC should stop at PR / `MERGE_READY`; it must not auto-deploy.

#### Adapter responsibility boundary

The adapter may:

- authenticate and normalize provider events;
- maintain intake-local dedup / recurrence state;
- produce a sanitized **repository-visible source artifact** plus immutable external/provider reference metadata;
- perform read-only correlation / investigation through approved tools;
- translate the normalized observation into the existing #1442 admission/materialization input contract;
- invoke the existing shadow/read-only materializer / collector path;
- request creation of downstream work through a separate idempotent action.

The adapter must not:

- implement a second PBI materializer or second admission decision engine;
- bypass `materialize | no_action | discover_more` or `update_existing | link_only | create_new` semantics owned by #1442/#1443;
- write production code;
- create or approve PlanGate approval records;
- choose or widen `allowed_paths`;
- mutate V2 RunState directly;
- write RunEvidence directly;
- merge, deploy, or publish;
- create unbounded GitHub Issues directly from event volume.

#### GitHub Issue creation is a downstream side effect

For the first PoC, **automatic GitHub Issue creation is out of the hot path**. The adapter should first prove that it can generate a valid bounded `pbi-input` candidate and preserve provider-event traceability.

If automatic Issue creation is added later, treat it as an external side effect with the existing V2 idempotency pattern:

```text
intake decision
  -> intent
  -> GitHub create issue
  -> receipt
```

The idempotency key should bind at least the intake identity + target repository + action kind. Lost responses must be reconciled before retrying so that one runtime incident does not create duplicate Issues. Issue content must still satisfy repository Issue Governance (Why / What / Acceptance Criteria / Non-goals when a roadmap/PBI Issue is created).

This separation keeps "detect an incident" from becoming "perform an external mutation" by implication.

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

### Phase C — staged rollout and evaluation

Do not move directly from "adapter installed" to autonomous downstream action. Roll out in four stages.

| Stage | Runtime behavior | Required evidence before promotion |
| --- | --- | --- |
| R0 Shadow | receive / authenticate / normalize / dedup only; no agent invocation | event authenticity, replay rejection, dedup correctness, redaction success |
| R1 Read-only investigation | current #1452/#1453 implementation stops at shadow request + readiness-gap evaluation; no Agent dispatch | pre-run: hard read-only enforcement + runtime role registration + provider connector registration + admission binding + independently verified Human rollout decision. V2 selected/fired evidence applies only after a real Run exists |
| R2 Work proposal | produce bounded `pbi-input` candidate; Human / normal PlanGate path decides whether to proceed | proposal quality, scope discipline, no invented AC, no `allowed_paths` widening, provenance preserved |
| R3 External side effect | optionally create a governed GitHub Issue using intent → action → receipt | duplicate side-effect prevention, Issue Governance conformance, reconciliation after lost responses |

R3 still does **not** grant the runtime adapter authority to edit code, approve a Plan, merge, or deploy. Code changes occur only after the normal PlanGate Delivery path has begun.

Pre-PBI R1 dispatch readiness and V2 Runtime Activation are separate layers:

- static config or `installed` proves only presence/declaration;
- pre-run `runtime_role_registered` / `provider_connector_registered` require independently authenticated runtime probes, not repository self-declaration;
- Human rollout authority must come from a Human-owned issuance/verification path; `source_kind=human_decision` in a file is insufficient;
- #1452 shadow request generation and #1453 readiness evaluation do not count as V2 `selected` / `fired`;
- only after a real PlanGate Run exists may `selected` / `fired` / `produced_evidence` / `influenced_decision` be recorded as RunEvent-owned activation Evidence;
- a claim that the adapter improved downstream decisions requires Evidence that its output was actually consumed, not merely generated.

#### Rollback / kill conditions

Any of the following blocks promotion and rolls the adapter back to the prior safe stage (or disables it entirely):

- approval / permission / gate bypass;
- sensitive data handed to an agent or persisted outside policy;
- prompt-injection text changes trusted workflow behavior;
- duplicate GitHub Issues or other duplicate external side effects from one intake identity;
- unauthenticated / replayed events accepted as actionable;
- runtime adapter writes code or mutates RunState / RunEvidence directly;
- cross-Run aggregate state leaks into per-Run RunEvidence;
- missing evidence is recorded as success / zero;
- provider-specific behavior changes the provider-neutral core contract.

The kill path must be simpler than the activation path: disabling the provider adapter must stop new runtime-originated work without changing existing PlanGate / ai-loop behavior.

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
- percentage of runtime-originated work that began with read-only investigation;
- Human acceptance / rejection rate of generated `pbi-input` candidates;
- duplicate external side effects prevented by idempotency;
- pre-run dispatch Evidence (runtime attestation / Human rollout decision) and, only for real Runs, V2 activation Evidence (`selected` / `fired` / `produced_evidence` / consumed downstream).

#### Measurement storage / privacy boundary

Runtime PoC metrics inherit the repository's existing Metrics Privacy policy. Evaluation must not create a second telemetry dump inside PlanGate.

Persist only aggregate / sanitized measurements needed for comparison, such as:

- counts / rates / latency;
- fixed enums (provider class, rollout stage, result);
- opaque hashes where stable correlation is necessary;
- TASK / Run identifiers that do not contain runtime payload content.

Do not persist in PlanGate metrics:

- raw provider request / response bodies;
- full stack traces or command output;
- application payloads / customer data / session values;
- Issue / PR body text copied from runtime evidence;
- raw external URLs / account identifiers;
- user-controlled log text or prompt-like content.

Raw evidence remains at the provider or approved evidence store and is referenced through opaque / sanitized refs. Missing data remains missing / unavailable; it must not be replaced with zero or synthetic success.

The pre-PBI source snapshot is immutable point-in-time evidence. Later duplicate occurrences update only intake/provider-owned aggregation or create new immutable evidence deltas; they do not rewrite historical source snapshots or historical RunEvidence.

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
- Human review confirms that provider-specific behavior has not leaked into the provider-neutral core;
- R0 → R1 → R2 promotion evidence is available; R3 is optional and requires separate side-effect evidence;
- a tested kill path disables new runtime-originated work without altering normal PlanGate execution.

These criteria evaluate the intake mechanism. They do not prove that every runtime-generated diagnosis is correct. Diagnosis quality remains subject to normal Plan / Verification / Evidence rules.

### 11.1 Implementation tracking

- #1448 — External Runtime Evidence Ingress Adapter R0/R1 shadow implementation.
- #1449 — R0 provider-neutral ingress + Cloudflare reference mapping + content-addressed pre-PBI Evidence + TA-95.
- #1452 — R1 read-only investigation **shadow request** + pre-run/V2 activation separation + Explorer config content binding + TA-96.
- #1453 — pre-run dispatch readiness evaluator; machine Evidence remains candidate-only, runtime attestation/Human rollout authority cannot self-declare + TA-97.
- Superseded implementation PRs: #1452 (superseded/closed; branch contract preserved) / #1453 (superseded/closed; branch contract preserved) (stack restack中のforce-rewriteでGitHubによりclose。replacementは #1452 / #1453)。
- #1448 depends on #1441 / #1443 finalization before production behavior changes.
- First reference provider: Cloudflare runtime-issue path; provider-neutral contract remains authoritative.
- R1 Agent invocation remains disabled; #1452/#1453 do not emit V2 `selected/fired` because no PlanGate Run exists yet.

## 12. Open questions

1. **Proposed answer**: Runtime Evidence should default to a typed external Evidence reference owned by existing V2 artifacts / events, not a new mutable artifact. A new artifact requires separate justification.
2. **Proposed answer**: deduplication and recurrence state belong to the provider / intake adapter or an intake registry outside Delivery Run state; V2 receives immutable intake decisions / evidence refs.
3. **Proposed answer**: the first PoC creates only a bounded `pbi-input` candidate / internal work request. Automatic GitHub Issue creation is a later downstream side effect and must use intent → action → receipt idempotency plus Issue Governance.
4. **Proposed answer**: building an R1 shadow request requires authenticated/redacted content-addressed source Evidence. Pre-run dispatch additionally requires independently authenticated hard read-only runtime enforcement, runtime role registration, approved provider connector registration, independently bound admission/materialization Evidence, and a Human-owned rollout decision. #1453 intentionally cannot satisfy the last two authority classes by self-declared repository files.
5. Which fields must be redacted or converted to opaque references?
6. How should a runtime-originated task bind to deployment / commit identity when the running version is not traceable?
7. What metrics are sufficient to decide whether the adapter improves Time to Learning without increasing unsafe automation?
8. **Proposed answer**: before a PBI/TASK exists, persist sanitized immutable source evidence in a non-task intake namespace (recommended `docs/working/_runtime-ingress/.../`). Once a PBI exists, bind that external evidence ref in `pbi-input.md`; during a Run, Phase 1 should define a RunEvent semantic that records consumption/correlation of the same refs. RunEvidence only projects those Run-local facts.
9. **Proposed answer**: provider authentication alone remains `reported`; `observed` requires independent repository-visible correlation Evidence. This trust level does not by itself grant Agent execution authority.
10. **Proposed answer**: before a normal PlanGate work request exists, allow repository read/search, read-only repository shell, and approved read-only provider access only. Forbid edit/write/test/build/web-search/network-shell/credential access and all downstream mutation.
11. **Proposed answer**: pass only Evidence refs across the trusted request boundary; do not inline runtime text into trusted instructions. Fixtures must prove prompt-like telemetry cannot alter scope, commands, tool policy, or activation state.
12. **Proposed answer**: use the Cloudflare runtime-issue path as the first R0/R1 reference adapter because it is the motivating case for this RFC. Keep the core provider-neutral and treat Cloudflare-specific fields as adapter mapping only.

## 13. Decision requested

Before promotion into ai-loop V2 canon, review this RFC against:

- North Star: Evidence before judgment / Stable boundaries / Delivery vs Evolution;
- Core Contract: workflow responsibility ends before production release;
- Evaluation Trust Boundary: external runtime data cannot become protected authority;
- privacy / security requirements;
- provider neutrality and reversibility.
