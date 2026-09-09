# ai-loop V2 — Loop / Graph / Harness Responsibility Model

> **Status**: Interpretation guide for ai-loop V2 architecture. This document is subordinate to [`north-star.md`](./north-star.md), [`taxonomy.md`](./taxonomy.md), [`harness-manifest.md`](./harness-manifest.md), [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md), and [`artifact-responsibilities.md`](./artifact-responsibilities.md).
> **Purpose**: Make the responsibility boundary between Loop, Graph, and Harness explicit without creating a second source of truth or introducing a new Graph runtime.

## 1. Core statement

ai-loop V2 treats Loop, Graph, and Harness as different architectural concerns.

> **Loop is the unit of feedback and convergence. Graph is the unit of coordination topology. Harness is the execution environment that makes both reliable.**

They are not a maturity ladder such as `Harness -> Loop -> Graph`, and Graph does not replace Loop.

- **Loop** answers: how does work observe evidence, decide progress, repair or replan, and stop?
- **Graph** answers: what runs next, what may run in parallel, where does execution branch or join, and where can it wait, resume, recover, or escalate?
- **Harness** answers: under what context, tools, permissions, state, policy, verifier, budget, and observability can that work run safely and reproducibly?

These concerns are composable.

- A Graph may contain multiple Loops.
- A Loop may traverse multiple Graph nodes.
- A Loop can itself be treated as a node in a larger Graph.
- A node does not need to be an Agent or LLM; it may be deterministic code, a tool, a verifier, a gate, a Human action, or another Loop.

## 2. Responsibility boundaries

### Loop Engineering

Loop Engineering owns evidence-based convergence toward a bounded goal.

Typical responsibilities:

- goal / contract for one feedback cycle
- observe -> evaluate -> repair / replan -> verify
- progress detection
- repeated-failure / oscillation / no-progress detection
- iteration / time / token / cost budget
- evidence-based stop conditions
- escalation when the contract cannot be satisfied safely

A Loop is not equivalent to retry. Repeating the same action without new evidence or strategy change is not progress.

Canonical V2 owners:

- Delivery Loop: one Task / Run -> `MERGE_READY`
- Evolution Loop: multiple RunEvidence -> Harness Candidate -> evaluation -> Promotion Ready
- stop / progress contract: #894

### Graph Engineering

Graph Engineering owns explicit control topology and durable transitions between responsibilities.

Typical responsibilities:

- node / edge definition
- conditional branch
- parallel execution and join
- independent role handoff
- Human / External interrupt and resume
- recovery / rollback path
- durable current position and transition reason
- orchestration of multiple Loops, Agents, tools, verifiers, and gates

Graph is introduced for coordination complexity, not because a task uses AI.

Canonical V2 owners:

- durable state / interrupt / resume: #1025
- Work Item Graph / intent-to-execution structure: #911
- trajectory evaluation of transitions: #908

### Harness Engineering

Harness Engineering owns the runtime conditions that make Loop and Graph execution trustworthy.

Typical responsibilities:

- Prompt / project instructions
- context selection / retrieval / compression / handoff
- Skill / Agent definitions
- tools / sandbox / permissions
- model and effort routing
- verifier set and evaluation harness
- policy / approval / Human-owned boundaries
- budget policy
- durable state primitives and checkpoints
- RunEvent / RunEvidence collection
- Harness identity and activation evidence
- observability / logs / traces

Canonical V2 owners include:

- Harness identity: [`harness-manifest.md`](./harness-manifest.md)
- Evaluation authority: [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md)
- artifact responsibilities: [`artifact-responsibilities.md`](./artifact-responsibilities.md)
- Harness evolution: #869

## 3. ai-loop V2 mapping

### Delivery

The Delivery concern is a Loop because it must converge one Task to a bounded terminal outcome using evidence.

Its execution topology may be represented as a Graph when coordination requires explicit transitions.

```text
Request
  -> Plan
  -> Plan Verification
  -> Plan Gate
  -> Execute
  -> Verify
       FAIL -> Diagnose
                  -> Plan still valid? -- yes --> Repair ----┐
                                      \-- no  --> Replan     |
                                                   -> Plan Verification
                                                   -> Plan Gate
                                                          |  |
                                                          +--+
  -> Verify PASS
  -> PR Convergence
  -> MERGE_READY
```

`WAITING_HUMAN`, `WAITING_EXTERNAL`, recovery, and resume are Graph/state concerns. Whether execution should continue, repair, replan, stop, or escalate remains a Loop decision based on evidence and contract state.

### Evolution

The Evolution concern is a separate Loop operating across multiple Delivery Runs.

```text
RunEvidence corpus
  -> Retrospective
  -> Pattern / Friction / Success
  -> Improvement Hypothesis
  -> Harness Candidate
  -> Experiment
  -> Independent Evaluation
  -> Canary
  -> Promotion Ready
  -> Human Decision
  -> Harness N+1
```

When Candidate creation, independent evaluation, canary, Human decision, and rollback require different roles or execution paths, the Evolution Loop may use a Graph topology internally.

The Graph does not weaken the Evolution Trust Boundary:

> Candidate cannot modify the authority that judges the candidate.

## 4. Minimum topology principle

Start with the smallest control structure that can satisfy the contract safely.

Prefer a single Loop when all of the following are true:

- one bounded goal
- mostly linear execution
- one responsibility context is sufficient
- no meaningful parallel branch / join
- no durable Human / External wait and resume
- no independent trust domain requiring a separate execution path
- recovery can be expressed as repair / replan inside the same Loop

Introduce explicit Graph structure when one or more of the following materially improves correctness or recoverability:

- conditional branches have different contracts or permissions
- parallel work must join under an explicit condition
- Planner / Builder / Verifier / Decision Engine require durable handoff
- Human / External wait must survive process or session loss
- independent reviewers or evaluators must be isolated
- recovery / rollback has a distinct path
- multiple sub-Loops need orchestration

> **Do not graph what a single Loop can express clearly. Do not hide real coordination complexity inside one opaque Loop.**

## 5. Node and edge rules

When Graph structure is used:

1. **Nodes have one primary responsibility.** Avoid nodes that plan, build, verify, and decide at the same time.
2. **Edges are explicit decisions.** A transition must be attributable to evidence, policy, or a Human / External event.
3. **State is durable where interruption matters.** Session memory or a live process is not the source of truth for resumable execution.
4. **Join conditions are explicit.** Parallel work is not complete merely because all workers report completion.
5. **Failure paths are first-class.** Retry, repair, replan, wait, escalate, rollback, and stop must not be hidden exceptional behavior.
6. **Human-owned edges remain Human-owned.** Graph orchestration must not convert C-4, merge, policy, permission, First Principles, or Production Harness promotion into AI-owned transitions.
7. **Verifier evidence is not replaced by routing.** Reaching a Graph node does not prove that the node's contract was satisfied.

## 6. Failure diagnosis

Do not attribute failure to the Model before checking the surrounding system.

Use this order as a diagnostic heuristic, not a new persisted taxonomy:

1. **Harness** — context, tool, permission, runtime activation, state, verifier availability, evidence collection
2. **Loop** — progress criteria, evaluation contract, repair strategy, stop condition, budget
3. **Graph** — missing / incorrect edge, branch, join, interrupt, resume, recovery path
4. **Model** — reasoning, instruction following, tool use, or task capability remains insufficient after the above are valid
5. **External** — GitHub, CI, API, network, or another external dependency

Persisted failure fields and RunEvidence responsibilities remain owned by the V2 artifact contracts and #874; this section must not create a parallel failure schema.

## 7. Design review questions

For a V2 Plan / PR that changes orchestration, answer the following in addition to the North Star review questions.

### Loop

- What bounded goal is the Loop converging toward?
- What evidence demonstrates progress?
- What causes repair, replan, escalation, or stop?
- How is no-progress distinguished from ordinary retry?

### Graph

- Why is an explicit Graph needed instead of one Loop?
- What are the nodes and their primary responsibilities?
- What evidence or event authorizes each non-trivial edge?
- Are branch, join, wait, resume, recovery, and rollback paths explicit where needed?
- Can the current position be recovered without conversation history or a live process?

### Harness

- Which HarnessManifest identity is executing the Loop / Graph?
- Which context, tools, permissions, verifiers, policies, and budgets are active?
- Can activation and influence be proven rather than inferred from file presence?
- Does the change touch a protected authority or Human-owned boundary?

## 8. Relationship to existing work

Issue #923 previously proposed a cross-cutting Harness / Loop / Graph classification. It was closed as **SUPERSEDED** because implementation responsibility already belonged to lower-level issues. This document does not reopen that architecture EPIC.

The existing ownership remains:

| Concern | Existing owner |
|---|---|
| Stop / progress / retry strategy | #894 |
| Durable workflow state / Human interrupt / resume | #1025 |
| RunEvidence / failure evidence | #874 |
| Trajectory evaluation | #908 |
| Work Item Graph / context-to-execution structure | #911 |
| Harness Evolution | #869 |
| Canon hardening / trust boundaries | #1275 and V2 companion canon |

If those owners define a more specific contract, the specific contract wins. This document provides responsibility interpretation only.

## 9. Non-goals

- introducing LangGraph or another Graph framework as a dependency
- creating a new generic Graph runtime before a concrete V2 requirement needs it
- graphifying every workflow
- replacing Delivery Loop or Evolution Loop terminology
- creating a second state / outcome / stop-reason taxonomy
- moving verification responsibility from Verifier / Gate to Graph routing
- weakening Human-owned authority
- treating `Prompt -> Context -> Harness -> Loop -> Graph` as a chronological maturity ladder

## 10. Working rule

When architecture becomes ambiguous, use these three questions:

```text
How does this work converge and stop?      -> Loop
What coordinates the next transition?     -> Graph
What makes execution reliable and safe?   -> Harness
```

Then keep the implementation in the smallest existing owner that can satisfy the requirement.

## References

Informative only; repository canon takes precedence.

- #923 — Harness / Loop / Graph Engineering responsibility separation (SUPERSEDED)
- https://x.com/Sumanth_077/status/2097689190712692965 — Loop vs Graph Engineering discussion
