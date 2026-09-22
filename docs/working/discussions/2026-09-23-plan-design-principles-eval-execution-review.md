# Plan Design Principles Eval — Execution Freeze Review

> Issue: #1337
> Branch: `docs/1337-eval-execution-freeze`
> Review scope: execution configuration / isolation / variant identity / reproducibility
> Result: **PASS WITH RUNTIME PRECONDITION**
> Critical: 0 / Major: 0 unresolved / Medium: 0 unresolved / Accepted limitation: 1

## 1. Measurement validity

**PASS**

- baseline/candidate repo SHA remain frozen.
- 8 cases × 3 trials × 2 variants = 48 generations remains unchanged.
- same generator model / effort / budget / timeout / tool policy is fixed across both variants.
- pair order remains counterbalanced by the existing matrix.
- no result is inferred from documentation/CI alone.

Finding resolved:
- pilot-wide token ceiling was missing even though per-run ceilings were fixed.
- fixed to 7,296,000 combined tokens across generator + blind scoring.

## 2. Variant identity / activation

**PASS after Major fix**

Major finding:
- the frozen upstream SHAs contain `.agents/skills/ai-dev-plan/SKILL.md`, but not its `references/`.
- executing the upstream dogfood path while expecting bundled references would make activation evidence ambiguous or fail.

Fix:
- repo SHA remains the variant identity.
- the same-SHA `plugin/plangate/skills/ai-dev-plan/` bundle is the execution surface.
- Skill and reference Git blobs are frozen in the ledger.
- evaluation claim is explicitly PR #1336's Plan-generation harness difference, not Skill-only causality.

## 3. Input identity

**PASS**

- 8 derived PBI files are frozen once before runtime.
- field-by-field semantic equality against source was verified for:
  - Context
  - In scope
  - Out of scope
  - Acceptance Criteria
  - Evidence
  - Unknowns
  - Assumptions
- 8/8 PASS.
- run-time procedure only byte-copies a frozen PBI; it does not re-materialize it.
- baseline/candidate runtime SHA256 mismatch => `INCONCLUSIVE_INPUT_MISMATCH`.

Review note:
- the first equality checker produced false mismatches because its heading boundaries were wrong.
- the checker was corrected; derived content did not need modification.
- this is recorded in the manifest instead of silently discarding the failed check.

## 4. Contamination / isolation

**PASS after Major fix; runtime smoke pending**

Generator sees:
- one selected frozen PBI
- common prompt
- selected variant plugin Skill + same-SHA references/rules

Generator does not see:
- rubric
- expected behavior/failure examples
- other cases
- other runs
- reviewer outputs
- variant peer output

Worktree:
- detached per generation
- no thread resume
- output root outside generator worktree
- network disabled
- workspace-write sandbox so normal ai-dev-plan artifact creation remains possible
- common prompt limits writes to `docs/working/TASK-EVAL-PDPXX/`
- pre/post file manifests make out-of-scope writes observable instead of hiding them

Major finding resolved:
- the first execution packet used a read-only sandbox.
- that would prevent ai-dev-plan from creating its normal `plan.md / todo.md / test-cases.md` outputs and would change the behavior under evaluation.
- fixed to workspace-write + explicit network-off + task-directory write boundary + pre/post manifest evidence.

Remaining runtime proof:
- operator smoke must confirm local CLI flags, network-off behavior, file generation and event logging.

## 5. Reviewer independence

**PASS with accepted limitation**

- reviewer uses a fresh context and different model ID: `gpt-5.6-terra`.
- generator uses `gpt-5.6-sol`.
- reviewer does not see variant identity / generator checkout / event log.
- Human adjudicates critical regression / Other change / inconclusive cases.

Accepted limitation:
- generator and reviewer are in the same OpenAI/Codex model family.
- this reduces variant/context coupling but is **not** cross-vendor independence.
- no stronger claim is made.

## 6. Budget / reproducibility

**PASS**

Generator per run:
- input <= 64k
- output <= 16k
- timeout <= 600s

Reviewer per run:
- input <= 64k
- output <= 8k
- timeout <= 600s

Pilot ceiling:
- generator = 3.84M tokens
- reviewer = 3.456M tokens
- combined = 7.296M tokens

Budget changes cannot be mixed into the same run set.
Retry evidence is append-only and counts toward the pilot ceiling.

## 7. Scope discipline

**PASS**

Changed scope is evaluation-only:
- eval plan / ledger
- execution operator packet
- frozen derived PBI inputs / manifest

No changes to:
- baseline SHA
- candidate SHA
- production Skill
- production Plan template
- C-1 definition
- HO
- schemas
- eval runner

No new execution engine / LLM judge was introduced.

## 8. Runtime start gate

**NOT RUN — operator machine required**

The only remaining blocker to 48-generation execution is local runtime evidence:

- `codex --version`
- valid auth
- `gpt-5.6-sol` available
- `gpt-5.6-terra` available
- timeout/gtimeout available
- workspace-write / network-off / approval-never / ephemeral smoke run
- JSONL usage/tool events recorded
- final message capture works
- plugin bundle readable at both frozen SHAs
- reviewer sandbox cannot infer variant identity

Failure of any item => `INCONCLUSIVE_NOT_RUN`.
Do not consume P01 or any production pair for smoke testing.

## 9. Final verdict

**Execution protocol: PASS**

**Actual effectiveness evaluation: NOT RUN**

Current correct state:

```text
protocol frozen
  -> execution config frozen
  -> frozen inputs verified
  -> local operator smoke
  -> 48 generations
  -> blind scoring
  -> pair-level result
  -> #1337 downstream decision
```

Until the pair-level result is fixed:
- do not claim #1335 improved Plan quality;
- keep #1359 production implementation blocked;
- do not start #1347's second-candidate Human Decision Surface experiment.
