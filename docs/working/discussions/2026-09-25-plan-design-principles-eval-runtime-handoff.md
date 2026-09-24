# #1337 Runtime Execution → #1359 T-00 Handoff

> Date: 2026-09-25
> Scope: operator handoff only
> This document does **not** change PDP-EVAL-v1 protocol, frozen inputs, rubric, model configuration, budget, isolation requirements, or baseline/candidate SHAs.

## Purpose

#1337 の仕様準備は完了している。残作業は認証済み Codex CLI runtime での実測だけである。

この文書は、既存の正本を変更せずに次の2点を明確にする。

1. operator がどの順序で既存 procedure を実行するか
2. 実行結果を #1359 T-00 が何を根拠に受け取るか

## Canonical sources

以下が実行条件の正本。本handoffより優先する。

1. `2026-09-20-plan-design-principles-eval-plan.md`
2. `2026-09-20-plan-design-principles-eval-ledger.md`
3. `2026-09-23-plan-design-principles-eval-execution.md`
4. `2026-09-23-plan-design-principles-eval-execution-review.md`
5. Issue #1337

Frozen variants:

- baseline: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- candidate: `4b3f4017ad6c2a64813524ec8567a289f722cb45`

これらをcurrent mainへ置換しない。

## Current repository state

- PR #1371: merged — isolation specification baseline is in main
- PR #1360: merged — TASK-1359 planning baseline is in main
- #1337 effectiveness result: `INCONCLUSIVE_NOT_RUN`
- #1359 production execution: `BLOCKED`
- Runtime Major 1: open until actual isolation evidence is collected

## Operator environment start gate

Operator machineで最初に実測する。

```sh
codex --version
command -v timeout || command -v gtimeout
```

Required:

- Codex CLI >= 0.144.0
- exact CLI version frozen for smoke, all 48 generations, and all blind scoring
- valid Codex authentication
- `gpt-5.6-sol` usable for generator
- `gpt-5.6-terra` usable for blind reviewer
- no-network / sandbox / approval policy resolved exactly as the execution packet requires

このどれかが欠けた場合:

- 48 generationを開始しない
- resultは `INCONCLUSIVE_NOT_RUN`
- missing prerequisiteを記録する
- 条件を緩めて同じrun setへ混ぜない

## Execution order

正本のcommand・policy・canary定義をそのまま使い、次の順序を変えない。

```text
runtime preflight
  -> freeze exact Codex CLI version
  -> independent single-SHA checkout isolation
  -> model-free codex sandbox controls
  -> Smoke A: baseline generator actual tool-boundary
  -> Smoke B: candidate generator actual tool-boundary
  -> Smoke C: blind reviewer actual tool-boundary
  -> confirm preflight/smoke runtime identity + policy match
  -> close Runtime Major 1 only if all controls PASS
  -> 48 generations
  -> 48 blind scoring calls
  -> pair-level judgment
  -> explicit #1337 downstream decision
  -> #1359 T-00
```

### Fail-closed rules

- isolation control missing/failing -> no 48-run
- smoke A/B/C incomplete -> no 48-run
- CLI version changes mid-set -> stop; new run set required
- input/hash mismatch -> affected pair is inconclusive
- rubric visible to generator -> contaminated; do not score as valid evidence
- reviewer cannot receive required read-only tool boundary -> `INCONCLUSIVE_NOT_RUN`
- budget ceiling reached -> `INCONCLUSIVE_BUDGET`; do not silently increase budget

## Runtime evidence bundle

Run中のraw evidenceは既存contractどおり評価checkout外へ保存する。

```text
$TMPDIR/plangate-pdp-eval-v1/
  runs/<pair>/<variant>/
  review/<pair>/
  manifests/
```

Repositoryへ結果を返す際は、少なくとも以下をhash付きで参照可能にする。

### Runtime identity

- run_set_id
- exact Codex CLI version
- OS/runtime identity
- sandbox backend / policy hash
- checkout materialization method
- generator model / effort
- reviewer model / effort
- started_at / completed_at

### Isolation / smoke

- independent checkout isolation verdict
- model-free sandbox positive controls
- model-free sandbox negative controls
- Smoke A verdict + event/log refs
- Smoke B verdict + event/log refs
- Smoke C verdict + event/log refs
- preflight/smoke policy identity match
- Runtime Major 1 close/not-close decision

### Generation / scoring completeness

- valid generation count / expected 48
- valid blind scoring count / expected 48
- missing / contaminated / retried pair IDs
- token budget actuals / ceiling status
- raw artifact manifest/hash
- anonymous review manifest/hash

### Pair-level result

8 caseについてtrial evidenceを集約し、既存rubricの分類を使用する。

- Improvement signal
- Regression
- No demonstrated difference
- INCONCLUSIVE
- Other change — needs adjudication

未実行・欠測をPASSや0へ変換しない。

## Required downstream decision

#1337のpair-level集計だけでは #1359 を自動unblockしない。

#1337には最終的に、Humanが確認できる形で **downstream decision** を記録する。

最低限:

- #1335 / Plan Design Principlesについて何を維持・修正・再評価するか
- #1359がT-00へ進んでよいか、引き続きBLOCKEDか
- replanが必要な場合、その理由と影響する原則/assumption
- #1347 second-candidate experimentへの影響

`INCONCLUSIVE_NOT_RUN` / unresolved Runtime Major /重大な未判定が残る場合、#1359はBLOCKEDを維持する。

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

## Current session observation

2026-09-25 06:29 JST 時点、このChatGPT実行環境では `codex` executableは検出されなかった。
これは**ユーザーのローカル環境についての判定ではない**。

したがってこのセッションではprotocol/handoff/repository準備まで行い、#1337のruntime effectiveness evidenceを偽装しない。
