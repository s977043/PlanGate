# PBI INPUT PACKAGE — TASK-1381 / #1381

> Parent: #1376
> Stacked on: PR #1380 Phase A contract
> Goal: verification-skipped Ratchet vertical slice を E2E で実証する
> Status: planning only. Production behavior unchanged.

## Current repository facts

- PR #1380 latest head `6d15a7d3`: CI / Test / CodeQL / PR Issue Link は PASS。
- PR #1380 の Independent Review は未完了。I0 self-review のみ。
- Legacy RunEvidence は `scripts/ai-loop/run_evidence.py` + `docs/schemas/run-evidence.schema.json` として実装済み。
- Legacy RunEvidence には `to_shadow_candidate_input()` / `to_paired_replay()` / `to_promotion_provenance()` の provenance bridge がある。
- V2 canon の `HarnessManifest` / `FailureRecord` / `HarnessImprovementCandidate` / `HarnessExperimentResult` は設計正本のみで、V2 runtime/schema は未実装。
- `scripts/ai-loop-v2/` は main に存在しない。Phase B が最初の V2 runtime namespace になる。
- schema 配置は 2026-07-31 Human 裁定済み: Phase 1 shadow は `docs/schemas/`、本番 Gate 接続時に `schemas/` へ Human-owned HO promotion。
- `docs/ai/ai-loop/**` / `scripts/ai-loop/**` は Legacy / freeze。V2 新機能の増築先にしない。

## Decision

### D1. Phase B は stacked implementation

#1380 の contract acceptance 後に implementation を開始する。
planning artifact は先行してよいが、V2 runtime/code は Independent Review 前に merge しない。

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
- `run_evidence_ref` = source RunEvidence bytes / canonical payload の immutable ref
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

### D6. Evaluation is fixture-driven and evaluator-owned

`ratchet.py` は Phase B では schema validation + deterministic evaluation に限定する。

最低責務:
- candidate validation
- evaluation plan digest binding
- baseline / candidate manifest ref presence check
- **sealed baseline/candidate fixture tree から evaluator 側で changed paths を算出**
- observed delta ⊆ allowed_paths
- prevention evidence tri-state
- activation level check
- PASS / FAIL / INCONCLUSIVE projection

Candidate から `observed_component_deltas` / `changed_paths` を自己申告させ、それをそのまま採用しない。
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