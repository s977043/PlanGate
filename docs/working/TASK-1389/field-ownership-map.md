# TASK-1389 Phase A — Intent Context Package ownership map

> Status: planning artifact / non-canon  
> Parent: #911  
> Implementation issue: #1389  
> Reuses: #199 Dynamic Context Engine v1  
> Downstream: #1385 Work Item Graph v1  
> Purpose: freeze ownership and identity before adding a new schema.

## 1. Layering decision

The repository already has a released Context Manifest (#199). Do not replace it.

```text
Source evidence / intent
        ↓
Intent Context Package     ← NEW: immutable pre-Plan provenance snapshot
        ↓
PBI / Plan                 ← requirement / execution contract
        ↓
Approval / Plan binding
        ↓
Context Manifest (#199)    ← EXISTING: phase/mode/profile resolved runtime context
        ↓
Execution
```

The two context artifacts answer different questions:

- Intent Context Package: what source evidence and unresolved uncertainty was this Plan based on?
- Context Manifest: what context should this phase/runtime receive now?

## 2. Invariants

1. Intent Context Package is immutable.
2. It does not replace PBI, Plan, test-cases, C-3 approval, or #199 Context Manifest.
3. Final acceptance criteria are not owned by this package. It may only hold source-backed acceptance inputs.
4. A source-backed normalized statement must reference one or more known source IDs.
5. An unsourced statement may exist only as an explicit assumption/unknown, never as authoritative fact.
6. Conflicting authoritative inputs remain conflicts; the resolver does not silently choose.
7. authority is a source-role classification, not model confidence.
8. freshness=current requires auditable source identity.
9. Full raw source bodies, raw transcripts, hidden CoT, secrets, and command output are not package contents.
10. context_ref / snapshot_ref are derived outside the payload. The payload does not contain its own self-hash.
11. Re-resolving unchanged semantic context must not stale an approved Plan only because timestamps or resolver version changed.

Classification:

- owned: semantic authority belongs to Intent Context Package.
- referenced: only point to another owner.
- derived: may be computed for validation/display; not an independent authority.
- forbidden: must not become authoritative package data.

## 3. Existing #199 Context Manifest ownership

| #199 field / concern | Owner | #1389 treatment |
|---|---|---|
| task_id | Context Manifest / task identity | package may reference the same task ID |
| phase | #199 | forbidden in Intent Context Package; pre-Plan snapshot is phase-independent |
| mode / profile | #199 | forbidden; runtime selection concern |
| contract_context[] | #199 | do not duplicate; later add only an intent_context reference adapter |
| dynamic_context[] | #199 | forbidden; runtime retrieval descriptors remain #199 |
| budget | #199 / model profile | forbidden |
| stale_guard.plan_hash_match | #199 + EH-3 | forbidden; package precedes approved Plan |
| plan_hash in approved_plan entry | Plan/#872/#199 adapter | package does not own it |

Decision: #1389 is upstream provenance, not Context Manifest v2.

## 4. Package top-level ownership

| field | class | decision |
|---|---|---|
| schema_version | owned | package schema version |
| context_id | owned | logical lineage identifier; not content hash |
| context_ref | derived semantic identity | canonical hash of the **contract projection**; used for Plan stale binding; not a payload field |
| snapshot_ref | derived byte identity | hash of exact immutable artifact bytes; audit/provenance only; not a payload field |
| task_id | referenced | existing task identity |
| supersedes_context_ref | referenced | optional previous semantic context ref when semantics change |
| created_at | owned snapshot metadata | included in snapshot_ref, excluded from context_ref |
| resolver_version | provenance | included in snapshot_ref, excluded from context_ref unless it changes normalized contract data |
| intent | owned normalized inputs | source-backed normalized intent, not final PBI/Plan |
| sources[] | owned provenance | source inventory and evidence identity |
| constraints[] | owned normalized inputs | source-backed inputs only |
| acceptance_inputs[] | owned normalized inputs | source-backed inputs only; never final AC |
| assumptions[] | owned uncertainty | explicit unsupported hypotheses |
| unknowns[] | owned uncertainty | unanswered questions |
| conflicts[] | owned uncertainty | conflicting source-backed statements |
| phase / mode / profile | forbidden | #199 concern |
| dynamic_context / budget | forbidden | #199 concern |
| plan_hash / c3 status | forbidden | downstream Plan/approval concern |
| final acceptance_criteria | forbidden | PBI/Plan concern |

## 5. Source provenance ownership

A source record identifies exactly what was observed and how it may be used.

| field | class | decision |
|---|---|---|
| source_id | owned | unique within package |
| kind | owned | pbi_input / issue / spec / adr / code / discussion / prior_run |
| ref | owned provenance | stable locator where possible |
| revision_ref | owned provenance | source-kind-specific revision identity when available |
| content_digest | owned provenance | digest of observed source content when revision identity is insufficient |
| observed_at | owned provenance | when source was observed |
| authority | owned classification | authoritative / supporting / unverified |
| authority_basis | owned structured provenance | basis kind + optional ref explaining why this source is authoritative; model confidence is insufficient |
| freshness | owned classification | current / stale / unknown at snapshot time |
| freshness_basis | owned provenance | revision comparison / explicit user assertion / unavailable, etc. |
| excerpts / raw_body | forbidden | package stores normalized statements + refs, not copied source bodies |
| confidence score | forbidden as authority | model confidence is not source authority |

### Source identity and freshness rule

Every source used for normalized facts must have an auditable observed identity when feasible: revision_ref and/or content_digest.

That identity proves **what was observed**; it does **not by itself prove freshness=current**.

freshness=current additionally requires a freshness_basis showing why the observed identity represented the applicable current source at observed_at, for example:

- resolver compared against source HEAD/latest revision at observation time
- repository canonical artifact at the bound commit
- explicit Human assertion where machine verification is unavailable

If currentness cannot be established, freshness=unknown. A mutable URL or content_digest alone is insufficient.

### Authority rule

authority=authoritative requires structured authority_basis. Minimum basis kinds:

- explicit_human_designation
- repository_canon
- artifact_contract

The basis may carry a policy/artifact ref. Free-form rationale alone is not sufficient for machine enforcement.

The resolver must not upgrade a source to authoritative because an LLM considers it convincing.

## 6. Normalized intent / constraint ownership

Normalized statements make provenance machine-checkable; they are not a second requirements document.

### desired_outcomes / non_goals / constraints / acceptance_inputs

Each item owns:

- stable local ID
- minimal normalized statement
- source_ids[]

Rules:

- at least one source ID required
- all source IDs must resolve
- source role/freshness is derived from referenced sources
- acceptance_input is an input to PBI/Plan authoring, not an approved acceptance criterion
- materially transformed meaning must be rejected or represented as an assumption

### assumptions

May be unsourced, but must remain visibly unsupported:

- assumption_id
- statement
- optional source_ids[]
- verification_needed=true

No automatic promotion from assumption to fact.

### unknowns

Own unknown_id / question / blocking. They do not invent answers.

### conflicts

Own conflict_id / at least two source-or-statement refs / incompatibility description / optional downstream blocking classification.

The package does not own conflict resolution.

## 7. Relationship to PBI / Plan / #872

| Concern | Owner | Package behavior |
|---|---|---|
| requirement authority | PBI / approved Plan flow | package supplies provenance inputs |
| final acceptance criteria | PBI / Plan | package stores only acceptance inputs |
| source_pbi_hash | existing artifact schema | do not redefine |
| plan_hash / artifact_hashes / source_sha | #872 / Plan Package | do not redefine |
| C-3 / C-3' approval | approval owner | package is evidence/input only |
| Plan stale due to context change | Plan binding integration | downstream compares semantic context_ref; snapshot_ref is audit-only |

The Plan binding design should record semantic context_ref used for Plan creation and may also record snapshot_ref for exact audit provenance. #1389 defines identity semantics, not Plan approval semantics.

## 8. Relationship to #1385 Work Item Graph

#1385 should consume:

- context_id: logical lineage
- context_ref: semantic contract identity
- snapshot_ref: optional exact artifact audit identity
- approved plan_hash

#1385 must not recompute package authority/freshness rules or copy source claims.

Migration note: prior #1385 text referring to context_hash should become context_ref once #1389 identity semantics are approved.

## 9. Identity model: semantic binding vs exact snapshot

One ref cannot safely serve both Plan stale detection and exact artifact audit. Timestamps/resolver-version changes would create false stale results if exact bytes were used as the Plan contract identity.

### context_ref — semantic contract identity

Derived outside the payload from a canonical **contract projection** containing semantically material fields such as:

- context_id / task binding
- normalized intent / constraints / acceptance inputs
- source observed identities (revision/digest)
- source authority/freshness classifications
- assumptions / unknowns / conflicts

Exclude volatile audit metadata such as created_at, observed_at, and resolver_version when those fields do not change semantic context.

### snapshot_ref — exact artifact identity

Hash of exact immutable JSON artifact bytes (or canonical full payload). Used for audit/provenance, not Plan stale comparison.

Requirements:

1. same semantic contract projection -> same context_ref
2. semantically material change -> different context_ref
3. timestamp-only/resolver-version-only change -> context_ref unchanged, snapshot_ref may change
4. same exact artifact -> same snapshot_ref
5. payload contains neither derived ref
6. presentation-only Markdown is outside both identities
7. set-like structures have deterministic ordering/canonicalization

### Hash implementation

Repository already has c3_contract.canonical_hash() as the shared canonical JSON hash used by multiple ai-loop consumers. Phase B must **not silently introduce a divergent canonical JSON algorithm**.

Before implementation, choose one reviewed path:

- reuse the existing canonical_hash contract where dependency direction is acceptable, or
- extract/generalize that exact contract to a neutral shared helper with compatibility tests.

Copy-pasting a second subtly different JSON canonicalization is forbidden.

## 10. #199 compatibility adapter

The smallest additive integration is preferred.

Possible later representation:

```json
{
  "kind": "intent_context",
  "path": "docs/working/TASK-XXXX/intent-context.json",
  "status": "present"
}
```

#199 currently knows only pbi_input / approved_plan / test_cases / c3_approval.

Phase B/C must decide between:

1. extending #199 enum additively, or
2. leaving #199 schema unchanged and resolving intent_context through an adapter.

Do not migrate #199 draft-07 schema to 2020-12 as incidental work.

## 11. Fail-closed cases for future tests

1. source ID duplicate
2. statement references unknown source ID
3. desired outcome with zero source refs
4. constraint with zero source refs
5. acceptance input with zero source refs
6. assumption represented as authoritative fact
7. freshness=current with no evidence that observed identity was current at observed_at
8. authority=authoritative with missing/unknown structured authority basis
9. two authoritative conflicting sources silently collapsed
10. raw transcript / hidden CoT / secret field present
11. context_ref/snapshot_ref self-hash field inside payload
12. source raw body copied into package
13. package tries to own phase/mode/profile/budget
14. package tries to own final Plan AC/C-3 decision

## 12. Phase B handoff conditions

Schema work starts after review confirms:

- #199 is reused, not replaced
- source authority and freshness have explicit bases
- final AC stays downstream
- context_ref and snapshot_ref are external/derived and non-recursive
- semantic contract projection vs exact snapshot identity is fixed
- canonical hash implementation reuses or explicitly extracts the existing repository contract; no divergent duplicate
- #1385 dependency is updated to context_id/context_ref
- no unresolved ownership conflict exists with #199 / PBI / Plan / #872
