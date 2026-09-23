# PBI INPUT PACKAGE — TASK-1381 / #1381

> Parent: #1376
> Stacked on: PR #1380 Phase A contract
> Goal: verification-skipped Ratchet vertical slice を E2E で実証する
> **Status: READY PLAN / IMPLEMENTATION BLOCKED** — planning / contract refinement only. Production behavior unchanged. Phase A independent review is complete; runtime implementation remains blocked by the Delivery E2E sequencing gate, Phase A contract acceptance, and #1329 invalidation preflight.

## Current repository facts

- PR #1380 latest head `6d15a7d3`: CI / Test / CodeQL / PR Issue Link は PASS。
- PR #1380 Independent Review は head `6d15a7d3` で PASS / GO。contract acceptance / merge は未完了。
- Legacy RunEvidence は `scripts/ai-loop/run_evidence.py` + `docs/schemas/run-evidence.schema.json` として実装済み。
- Legacy RunEvidence には `to_shadow_candidate_input()` / `to_paired_replay()` / `to_promotion_provenance()` の provenance bridge がある。
- V2 canon の `HarnessManifest` / `FailureRecord` / `HarnessImprovementCandidate` / `HarnessExperimentResult` は設計正本のみで、V2 runtime/schema は未実装。
- `scripts/ai-loop-v2/` は main に存在しない。Phase B が最初の V2 runtime namespace になる。
- schema 配置は 2026-07-31 Human 裁定済み: Phase 1 shadow は `docs/schemas/`、本番 Gate 接続時に `schemas/` へ Human-owned HO promotion。
- `docs/ai/ai-loop/**` / `scripts/ai-loop/**` は Legacy / freeze。V2 新機能の増築先にしない。

## Decision

### D1. Phase B は stacked plan。runtime implementation は gate 待ち

planning artifact / contract refinement は先行してよいが、runtime implementation の開始条件を次に固定する。

1. PR #1380 の Independent Review / contract acceptance
2. `phase0-migration.md` §8 / #870 の **Delivery first release boundary E2E** が成立
   - `FAIL -> Diagnose -> Repair -> PASS -> MERGE_READY`
   - `NO_PROGRESS -> STOP / ESCALATE`
3. #1329 の implementation PR checklist に従い、M-1 / M-2 / M-3 と semantic invalidation gate を実施

上記が満たされるまで `scripts/ai-loop-v2/**` を作成しない。

理由: V2 canon は **Evolution 実装を Delivery E2E 成立後に開始する**と明記している。

### D2. V2 runtime namespace

新規:

```text
scripts/ai-loop-v2/
  ratchet.py
  test_ratchet.py
```

Legacy `scripts/ai-loop/run_evidence.py` は変更しない。
Phase B は既存 RunEvidence record を compatibility input として読むだけにする。

### D3. Phase 1 schema は2本に限定

```text
docs/schemas/
  harness-improvement-candidate.schema.json
  harness-experiment-result.schema.json
```

理由:
- #869 の既存裁定と一致
- Phase A の Ratchet contract の中心 artifact
- PromotionDecision schema は #811 / later integration の責務を先取りしない
- FailureRecord / V2 RunEvidence schema は Delivery V2 / #1285 の責務を先取りしない

Phase B では source failure を immutable refs で扱い、FailureRecord の完全 schema は定義しない。

### D4. Failure compatibility bridge

Phase B の source binding:

```yaml
failure_instance_ref:
  run_id: ...
  event_ref: ...
  failure_record_ref: sha256:...
  run_evidence_ref: sha256:...
```

- `run_id + event_ref` = instance binding
- `failure_record_ref` = fixture / observed FailureRecord payload の immutable digest
- `failure_record_ref` / `run_evidence_ref` は Phase B fixture では **canonical JSON digest を evaluator が再計算**して検証する
- canonical JSON は UTF-8 / object key sort / insignificant whitespace除去 / deterministic separators とし、`sha256:<hex>` で表現する
- Candidate が自己申告した digest をそのまま信用しない
- `failure_fingerprint` は identity に使わない

V2 RunEvidence schema 自体は本 PBI で作らない。

### D5. Pattern は Candidate-local snapshot

```yaml
pattern_snapshot:
  pattern_id: pattern:verification-skipped
  pattern_version: 1
  classifier_digest: sha256:...
  source_set_digest: sha256:...
  fingerprint: sha256:...
  occurrence_count: 3
```

Pattern 専用 artifact / DB / registry は作らない。

`source_set_digest` は Candidate の申告値を権威にしない。Evaluator が `failure_instance_refs` を stable tuple (`run_id`, `event_ref`, `failure_record_ref`, `run_evidence_ref`) に正規化・sortして再計算し、一致しなければ provenance 不成立として fail-closed / INCONCLUSIVE にする。

### D6. Evaluation is fixture-driven and evaluator-owned

`ratchet.py` は Phase B では schema validation + deterministic evaluation に限定する。

最低責務:
- candidate validation
- evaluator-owned canonical digest verification
- evaluator が sealed `evaluation-plan.json` から digest を再計算し Candidate の `evaluation_plan_digest` と照合
- baseline / candidate manifest ref presence check
- **sealed baseline/candidate fixture tree から evaluator 側で changed paths を算出**
- observed delta ⊆ allowed_paths
- prevention evidence tri-state
- activation level check
- PASS / FAIL / INCONCLUSIVE projection

Candidate から `observed_component_deltas` / `changed_paths` を自己申告させ、それをそのまま採用しない。
同様に `evaluation_plan_digest` / `source_set_digest` / source content refs も Candidate 自己申告だけでは成立させず、Evaluator-owned input から再計算する。
Phase B の observed delta は production Git diff の代用品ではなく、**sealed fixture tree を Evaluation Harness 役が比較して生成する vertical-slice evidence** とする。

外部 API / GitHub / network / merge / branch mutation は持たない。

## Representative vertical slice

### Known-bad

required verification evidence が無い状態で completion が試行される。

baseline:
- miss が再現される

candidate:
- missing evidence を deterministic verifier が検出
- Decision Engine への input となり completion を stop
- activation = `influenced_decision`

### Negative control

required verification evidence が存在する正常ケース。

candidate:
- block しない
- false-positive を増やさない

## Non-goals

- Legacy schema変更
- `scripts/ai-loop/**` への V2 実装追加
- V2 RunEvidence full schema
- HarnessManifest generator
- general-purpose clustering
- long-term recurrence collector
- automatic Skill / Hook generation
- automatic Production promotion / merge
- plugin distribution
- `bin/plangate` integration


### D7. PromotionDecision は compatibility projection

Phase B の `project_promotion_decision()` は、`HarnessExperimentResult.result` と evidence refs を #811 へ渡せる形に投影するだけであり、#811 の authoritative Promotion Gate / persisted schema を定義しない。

### D8. Fixture is development evidence, not automatic Incident Regression promotion

`tests/fixtures/ai-loop-v2/ratchet/verification-skipped/` は Phase B の development fixture。
#909 Incident Regression Set への正式昇格は、#909 の独立レビュー / Human-owned 変更規律を別途通す。

### D9. I1 exception invalidation gate

`scripts/ai-loop-v2/` の出現は `phase0-migration.md` §7 の **M-2** を baseline から動かす。
さらに Ratchet evaluator は Candidate / Experiment / Promotion evaluation を機械的に判定するため、#1329 の semantic invalidation rule 上も **I1 exception invalidation candidate** である。

runtime implementation PR では必ず:

1. base SHA で M-1 / M-2 / M-3 を再測定
2. head SHA で再測定
3. reviewer が「V2 canon を機械強制する execution surface か」を yes/no 判定
4. 判定不能は yes
5. yes の場合、同じ implementation PR で canon 7 の I1 例外継続を自己宣言しない
6. runtime evidence 成立後は #1329 の別 canon review path へ引き渡す

を実施する。