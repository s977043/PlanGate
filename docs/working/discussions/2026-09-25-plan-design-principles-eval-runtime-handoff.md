# #1337 Runtime Result → #1359 T-00 Handoff

> Date: 2026-09-25
> Scope: result handoff only
> This document does **not** define or change PDP-EVAL-v1 execution protocol.

## Purpose

#1337 のruntime評価結果を、#1359 T-00が安全に消費できる形へ固定する。

この文書は **実行手順の正本ではない**。
command / model / budget / sandbox / isolation / smoke / retry条件を再定義しない。

## Canonical execution sources

実行時は以下だけを正本として使う。

1. `2026-09-20-plan-design-principles-eval-plan.md`
2. `2026-09-20-plan-design-principles-eval-ledger.md`
3. `2026-09-23-plan-design-principles-eval-execution.md`
4. `2026-09-23-plan-design-principles-eval-execution-review.md`
5. Issue #1337

本handoffと上記が矛盾した場合、**上記正本を優先し、このhandoffを修正する**。

Frozen variants:

- baseline: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- candidate: `4b3f4017ad6c2a64813524ec8567a289f722cb45`

これらをcurrent mainへ置換しない。

## Current repository state

- PR #1371: merged — isolation specification baseline is in main
- PR #1360: merged — TASK-1359 planning baseline is in main
- #1337 effectiveness result: `INCONCLUSIVE_NOT_RUN`
- #1359 production execution: `BLOCKED`
- Runtime Major 1: open until canonical execution sourcesが要求するactual runtime evidenceを満たす

## Operator entrypoint

このhandoffからcommandをコピーして実行しない。

Operatorは次を行う。

1. Eval PlanのStart Gateを確認
2. Execution Packet §8.2のruntime isolation preflightを実行
3. Execution Packet §9のSmoke A/B/Cを実行
4. Start Gateを満たした場合だけ、Eval Planの48 generation → blind scoringへ進む
5. Ledgerへ実測値を記録
6. pair-level resultとdownstream decisionを#1337へ固定
7. 本handoffのresult contractを満たして#1359 T-00へ渡す

未実行・欠測・contaminated evidenceをPASSへ変換しない。

## Runtime result contract

#1359へ渡す結果は、少なくとも以下をhash/参照付きで持つ。

### 1. Runtime identity

- run_set_id
- exact Codex CLI version
- OS/runtime identity
- sandbox backend / policy hash
- checkout materialization method
- generator model / effort
- reviewer model / effort
- started_at / completed_at

### 2. Isolation / smoke

- independent checkout isolation verdict
- model-free sandbox control verdict + evidence refs
- Smoke A verdict + event/log refs
- Smoke B verdict + event/log refs
- Smoke C verdict + event/log refs
- preflight/smoke runtime identity + policy match
- Runtime Major 1 close/not-close decision

### 3. Generation / scoring completeness

- valid generation count / expected count
- valid blind scoring count / expected count
- missing / contaminated / retried pair IDs
- token budget actuals / ceiling status
- raw artifact manifest/hash
- anonymous review manifest/hash

Expected counts are defined by the canonical Eval Plan / Ledger, not by this handoff.

### 4. Pair-level result

Existing rubric classification only:

- Improvement signal
- Regression
- No demonstrated difference
- INCONCLUSIVE
- Other change — needs adjudication

各case/trialのevidence refsを保持する。

### 5. Downstream decision

Pair-level classificationだけでは#1359を自動unblockしない。

#1337には、Humanが確認できる形で次を明示する。

- #1335 / Plan Design Principlesについて何を維持・修正・再評価するか
- #1359をT-00へ進めてよいか、BLOCKEDを維持するか
- replanが必要なら、影響するprinciple / assumption / scope
- #1347 second-candidate experimentへの影響

Runtime Major未解消、実行未完了、重大なmissing/contamination、downstream decision未固定なら、#1359はBLOCKEDを維持する。

## #1359 T-00 consumption contract

T-00は次を確認する。

- [ ] #1337 pair-level resultが固定されている
- [ ] runtime/isolation/smoke evidenceが参照可能
- [ ] generation/scoring completenessが明示されている
- [ ] contamination / missing-data statusが明示されている
- [ ] downstream decisionが明示されている
- [ ] downstream decisionが#1359をT-00へ進めることを許可している、またはBLOCKED継続を明示している
- [ ] #1359のassumptions / Plan Design Principlesへのimpactをdecision-logへ記録する

T-00の結果:

- upstream resultがPlan前提を変える -> replan。Human C-3へ進まない
- upstream resultがPlan前提を維持しdownstream implementationを許可 -> C-1/C-2 freshnessを確認してHuman C-3へ
- upstream resultがinconclusive / blocked -> TASK-1359もBLOCKED維持

## Responsibility boundary

このhandoffが所有する:
- #1337 resultから#1359 T-00へ渡す**必要情報の形**

このhandoffが所有しない:
- Codex CLI command
- model / effort
- token budget
- sandbox/network policy
- canary design
- smoke procedure
- retry policy
- pair-level scoring rule
- Human C-3

それらはcanonical execution sources / existing PlanGate gatesを正本とする。
