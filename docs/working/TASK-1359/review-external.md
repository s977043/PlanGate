# TASK-1359 External / Multi-perspective Plan Review

> 対象: TASK-1359 pbi-input / plan / todo / test-cases
> Mode: critical
> Review stage: pre-C-3
> Overall: **PASS WITH EXTERNAL BLOCKER — #1337**
> Fresh review after #1358 merge/rebase
> Critical: 0 / Major: 0 / Minor: 1

## Lane 1 — Architecture / Responsibility

**Verdict: PASS**

確認:
- #933 / #810 / #867を3個のGateとして足さず、Evidence → Unknown → Knowledge Delta → Design → pre-PR re-checkへ統合している。
- Plan Design Principlesをsource of truthに維持。
- generic pre-PR self-reviewは`diff-audit`、independent implementation reviewは`review-gate`と責務分離。
- ai-loop execution-runbookはcomposition layerに限定しgeneric正本にしていない。

Finding:
- blockerなし。

## Lane 2 — Governance / Safety Boundary

**Verdict: PASS**

確認:
- workflow definition changeによりcritical mode。
- Human C-3前にexec禁止。
- HO pathはPhase 1対象外。必要ならHuman-owned patchへsplit。
- C-1 total countを変更しない。
- mergeはC-4 Human-owned。

Finding:
- blockerなし。
- #960のHO driftを本Taskへ巻き込まない判断は適切。

## Lane 3 — Test / Evidence Design

**Verdict: WARN (minor)**

確認:
- AC-01〜14 → TC-01〜11 mappingあり。
- simple/prior-artifact/blocked/KDの4fixtureを明示。
- positive/negative controlsあり。
- stale refs / sync / full testsはdeterministic。

Minor M-01:
- Plan生成semantic behaviorの一部はmanual fixture reviewで、production behaviorを自動証明しない。

Disposition:
- **accepted for this Plan**。新runnerを本Taskへ追加するとvalidator-first/over-engineeringへ寄る。
- #1337 paired evaluation基盤と後続接続するのが適切。
- 未自動化をPASS証拠として扱わない。

## Lane 4 — Adversarial Simplicity

**Verdict: PASS**

反証した案:
- Generic Unknown subsystem → 実測needなし、棄却。
- New Trust Ledger schema → current records不足の実測なし、棄却。
- New C-1 check ID → #960 drift再発 + existing checksで表現可能、棄却。
- Validator-first → artifact shapeがsource of truthになる危険、defer。
- New pre-PR gate → diff-auditが既存正本、不要。

Finding:
- blockerなし。

## Review findings reflected during this round

1. **AC trace error**: PlanがTC-01..10を参照していたがTC-11が存在
   - fixed: TC-01..11へ修正。
2. **Task granularity too coarse**: multi-file T-03/T-04が差し戻し単位として大きい
   - fixed: todo T-01..16、Plan Work Breakdown 12 unitsへ再分割。
3. **AC-14 fixture mapping error**: simple caseをTC-02へ誤map
   - fixed: simple=TC-06、prior=TC-01/02、blocked=TC-05、KD=TC-07。
4. **Verification method missing**: TCに検証方法/commandが不足
   - fixed: semantic review方法 + TC-11 deterministic commandsを明記。
5. **Todo completion implicit**: C1-TODO-12に対してcompletionが暗黙
   - fixed: T/H全Taskに`completion:`を追加。
6. **Decision log missing**: Plan自身が重要判断を `decision-log.jsonl` に残すと要求する一方、TASK-1359に監査ログが無かった
   - fixed: Approach / review boundary / Prior Artifact placement / scope boundary / mode / manual semantic eval受容の6判断をappend-only JSONLへ記録。
7. **C-1 landing ambiguity / #1358 collision risk**: `review-self.md` の既存checkへの着地点を実装時選択にしており、#1358が所有する `C1-TEST-14` と責務衝突し得た
   - fixed: C1-B1B2-16 / C1-PLAN-02 / C1-PLAN-03 / C1-PLAN-06へ事前固定し、C1-TEST-14は変更禁止。TC-12でcompatibilityを検証。
8. **Source-of-truth ambiguity**: `docs/ai-driven-development.md` を単独の「Prompt 1正本」と扱うとHO `working-context` とSkill/templateの責務境界が曖昧
   - fixed: core contract / workflow definition / executable guide / artifact shape / review の階層を明文化。HO core contractは変更しない。
9. **Unverified operational timestamps**: `status.md` 初稿で過去フェーズの分単位時刻を実測せず補完していた
   - fixed: 推測時刻を削除し、実測したstatus発行時刻のみ記録。過去順序はGit history / decision-logへ委譲。

## Post-rebase compatibility refresh

- branch vs main: ahead 1 / behind 0 at evidence point
- `C1-TEST-14` block equality: PASS
- `ai-dev-plan` branch == main: PASS
- `diff-audit` branch == main: PASS
- `review-gate` branch == main: PASS
- evidence: `evidence/c1-review/2026-09-23-rebase-compatibility.md`

## Finding 10 — Evaluation-order dependency discovered after latest-main rebase

**Severity before mitigation: Major**

Fresh main contains / references:
- #1337: frozen Plan Design Principles baseline/candidate; implementation order places #933/#810/#867 after paired evaluation.
- #1347: hard dependency on #1337 and explicit prohibition on changing `ai-dev-plan` / Plan Design Principles before #1337 completes.

Risk:
- moving TASK-1359 to C-3/exec now would violate evaluation order and could contaminate the experiment or make its downstream interpretation ambiguous.

Mitigation applied:
- add external blocker EB-01 (#1337 result fixed)
- add T-00 before Human C-3
- keep PR #1360 draft / planning-only
- add #1347 Human Decision Surface as explicit non-goal

**Resolved in plan: yes**

## Final Review Verdict

**Plan quality: PASS**
**Execution readiness: BLOCKED on #1337 result fixed**
**C-3 readiness: NO until T-00 completes**

次の正しい遷移:

```text
#1337 result fixed
  -> T-00 evaluate downstream impact
  -> C-1/C-2 refresh if needed
  -> Human C-3
  -> APPROVED
  -> T-03..T-16 exec / verify
  -> Human C-4
```
