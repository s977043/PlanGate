# EXECUTION PLAN — TASK-1381 / #1381

## Goal

`verification-skipped` の1 vertical sliceで、

```text
RunEvidence / Failure instance
 -> Candidate
 -> Harness N/N+1 identity
 -> observed delta
 -> prevention evidence
 -> ExperimentResult
 -> PromotionDecision projection
```

を決定論的に通し、#1376 Phase A contract が executable であることを証明する。

## Preconditions

### Contract-design preconditions

1. PR #1380 の contract を base にする
2. Legacy freeze を維持する
3. Phase 1 shadow schema は `docs/schemas/` に置く

### Runtime implementation hard gates

4. **PR #1380 Independent Review / contract acceptance が完了**
5. **#1383 Delivery E2E Gate が成立**
   - `FAIL -> Diagnose -> Repair -> PASS -> MERGE_READY`
   - `NO_PROGRESS -> STOP / ESCALATE`
   - #1383 が #870 DoD へ evidence を返し、#1381 の解除可否を明示
6. **#1329 invalidation preflight を実施**
   - M-1 / M-2 / M-3 base measurement
   - semantic invalidation review

**4〜6 のいずれかが未充足なら `scripts/ai-loop-v2/**` を作成しない。**
Planning / contract drafting は進めてよいが、Evolution runtime implementation は NO-GO。

## Approach comparison

| 案 | 内容 | 判定 |
|---|---|---|
| A | Legacy `scripts/ai-loop/evolution.py` に実装 | 却下。V2 new feature を Legacy freeze namespaceへ追加 |
| B | `scripts/ai-loop-v2/ratchet.py` に最小実装 | **採用**。V2 migration point が明示的 |
| C | 先に汎用 Evolution Engine / Graph を作る | 却下。vertical slice 前に過剰抽象化 |
| D | #811/#1285 完了まで待つ | 却下。fixture-driven compatibility bridge で独立検証可能 |

## Files / Interfaces

### New runtime

- `scripts/ai-loop-v2/ratchet.py`
- `scripts/ai-loop-v2/test_ratchet.py`

### New Phase 1 schemas

- `docs/schemas/harness-improvement-candidate.schema.json`
- `docs/schemas/harness-experiment-result.schema.json`

### New fixture

- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/source-bundle.json`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/candidate.json`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/baseline-manifest.json`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/candidate-manifest.json`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/known-bad.json`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/negative-control.json`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/baseline-tree/**`
- `tests/fixtures/ai-loop-v2/ratchet/verification-skipped/candidate-tree/**`

この fixture は development evidence であり、#909 Incident Regression Set の正式登録ではない。

### CI integration

- `tests/extras/ta-NN-ai-loop-v2-ratchet.sh`
- `tests/extras/README.md`（現行 convention が registration を要求する場合のみ）

現時点の main の最大番号は 86 なので候補は 87。ただし repo は並行更新されるため、**実装直前に next-free number を再取得して確定**する。

### Planning / handoff

- `docs/working/TASK-1381/**`

## Data contract

### HarnessImprovementCandidate

minimum fields:

```yaml
schema_version: "1"
candidate_id: ...
hypothesis: ...
source:
  run_evidence_refs: [...]
  failure_instance_refs:
    - run_id: ...
      event_ref: ...
      failure_record_ref: sha256:...
      run_evidence_ref: sha256:...
  pattern_snapshot:
    pattern_id: ...
    pattern_version: 1
    classifier_digest: sha256:...
    source_set_digest: sha256:...
    fingerprint: sha256:...
    occurrence_count: 3
target:
  operation: UPDATE
  component_refs: [...]
  allowed_paths: [...]
expected_prevention:
  mode: stop
  expected_effect: ...
baseline_manifest_ref: sha256:...
evaluation_plan_digest: sha256:...
```

### HarnessExperimentResult

minimum fields:

```yaml
schema_version: "1"
candidate_id: ...
evaluation_plan_digest: sha256:...
baseline_manifest_ref: sha256:...
candidate_manifest_ref: sha256:...
observed_component_deltas: [...]
prevention_evidence:
  - kind: known_bad_replay
    status: PASS
  - kind: negative_control
    status: PASS
activation:
  required_level: influenced_decision
  observed_level: influenced_decision
result: PASS
```

## Evaluation rules

### FAIL

- critical regression
- known-bad が candidate 後も miss
- negative control が false-positive
- actual delta が allowed_paths を超える
- candidate が protected fixture / evaluator / threshold を変更

### INCONCLUSIVE

- baseline / candidate manifest ref 欠落
- evaluation plan digest mismatch
- activation が required level 未満
- prevention evidence が未実行 / unavailable
- identity binding を再検証できない

### PASS

- pre-registered evaluation plan と一致
- known-bad prevention evidence PASS
- negative control PASS
- critical regression 0
- actual delta ⊆ allowed_paths
- activation requirement を満たす
- manifest identity が両側で固定

## Work breakdown

### Phase B0A — Allowed now: contract readiness

1. Candidate / Experiment schema field mappingを Plan 上で固定
2. fixture layout / source binding / expected resultsを固定
3. RED test cases / mutation matrixを固定
4. #1383 Delivery E2E evidence linkを取得
5. #1329 M-1 / M-2 / M-3 base measurement手順を handoff に用意

### Phase B0B — Runtime gate

次がすべて満たされたら RED 実装へ進む。

- Phase A Independent Review complete
- Delivery E2E gate complete
- #1329 invalidation preflight complete

### Phase B1 — RED runtime contracts

1. schema validation RED test
2. missing manifest -> INCONCLUSIVE
3. evaluation plan digest mismatch -> INCONCLUSIVE
4. allowed_paths overflow -> fail-closed
5. activation `fired` only -> INCONCLUSIVE
6. candidate-side sealed fixture mutation -> fail-closed
7. known-bad baseline miss / candidate stop
8. negative control pass

### Phase B2 — GREEN minimal evaluator

`ratchet.py` に純関数のみ実装。

推奨 API:

```python
validate_candidate(candidate, schema)
validate_experiment_result(result, schema)
compute_fixture_tree_delta(baseline_tree, candidate_tree)
evaluate_candidate(
    candidate,
    *,
    baseline_manifest,
    candidate_manifest,
    observed_tree_delta,
    prevention_evidence,
    activation,
    evaluation_plan_digest,
)
project_promotion_decision(experiment_result)
```

CLI は Phase B では必須にしない。test / fixture で決定論 API を先に固定する。

`compute_fixture_tree_delta()` は sealed fixture tree を読み、relative path + content digest の差分を Evaluation Harness 側で生成する。Candidate JSON 内の changed paths は入力にしない。Production の source-commit diff calculator は Non-goal。

### Phase B3 — integration

TA-NN で:
- 2 schema parse
- unit tests
- fixture E2E
- no network / merge API in V2 module static check

Legacy schema / `scripts/ai-loop/**` 無変更は CI test に base branch 依存を持ち込まず、PR diff review / handoff evidence で確認する。

### Phase B4 — review

- I0 self-review
- I1+ independent review
- exact head SHA を review record に固定
- CI green
- #1376 / #1381 へ evidence links

## Verification plan

### Unit

```sh
python3 scripts/ai-loop-v2/test_ratchet.py
```

### Integration

```sh
sh tests/extras/ta-NN-ai-loop-v2-ratchet.sh
```

### Full suite

```sh
sh tests/run-tests.sh
```

### Review guards

- PR diff で `scripts/ai-loop/**` / `docs/schemas/run-evidence.schema.json` が無変更であること
- `git grep` で merge / approve / destructive GitHub mutation API が `scripts/ai-loop-v2/ratchet.py` に無いこと
- fixture tree から evaluator が算出した delta と Candidate `allowed_paths` を比較すること

## Replan triggers

- #1383 Delivery E2E Gate が未成立または成立条件が変更
- #1329 semantic invalidation procedure が変更
- Phase A Independent Review で contract が変更
- V2 RunEvidence / HarnessManifest implementation が先に main へ入り compatibility bridge が不要になる
- `docs/schemas/` placement policy が変更
- #811 が authoritative PromotionDecision / Gate contract を先に確定し compatibility projection の shape が衝突
- representative fixture が Legacy RunEvidence では表現不能

## Stop conditions

- Delivery E2E の成立前に Evolution runtime 実装が必要になる
- #1329 invalidation gate を通さず `scripts/ai-loop-v2/**` を追加する必要がある
- Candidate が自身の evaluator / sealed fixture / threshold を変更しないと PASS できない
- Harness identity を machine-readable に固定できない
- Legacy freeze を破らないと実装できない
- Phase B が general-purpose learning engine 化し始める
- Production merge / promotion automation が必要になる

## Human approval boundary

- PR #1380 acceptance / merge
- Production Harness promotion
- HO schema promotion (`docs/schemas/` -> `schemas/`)
- merge / C-4

Phase B code itselfは shadow / fixture-only、Production behavior 非変更。


## Ownership notes

- `project_promotion_decision()` は #811 の authoritative Gate ではない。ExperimentResult を downstream へ渡す compatibility projection。
- FailureRecord full schema / V2 RunEvidence schema は本 Task で定義しない。
- HarnessManifest generator / canonicalization algorithm も本 Task で定義しない。fixture は canon fields の必要 subset を使う。
- Phase B development fixture を #909 Incident Regression Set へ自動昇格しない。

## Governance / sequencing review

### Delivery-before-Evolution

本 Task の runtime 実装は `phase0-migration.md` §8 の順序制約に従う。
#1383 が未完了の間、本 Plan の verdict は:

```text
Planning / contract readiness: GO
Runtime implementation: NO-GO / BLOCKED
```

### I4 invalidation

最初の `scripts/ai-loop-v2/` commit は M-2 を確実に変化させる。
したがって runtime implementation PR は #1329 の **I1 exception invalidation candidate** として扱う。
この Task 自身が canon 7 を編集して例外継続を宣言してはならない。