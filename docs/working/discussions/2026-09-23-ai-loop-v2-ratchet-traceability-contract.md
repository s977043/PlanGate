# ai-loop V2 Ratchet Traceability Contract — Phase A Design

> **Status**: Draft / Phase A design for #1376
> **Parent**: #869
> **Related**: #870 / #874 / #909 / #811
> **Canon**: `docs/ai/ai-loop-v2/north-star.md` §7, §10–§15, §17–§18; `harness-manifest.md`; `artifact-responsibilities.md`; `evaluation-trust-boundary.md`
> **Scope**: contract / traceability design only. Production behavior is unchanged.

## 1. Goal

ai-loop V2 の Evolution Loop で、失敗・摩擦・成功パターンから生成した改善 Candidate が、

```text
source evidence
 -> pattern
 -> improvement candidate
 -> actual Harness delta
 -> prevention / regression evidence
 -> experiment result
 -> promotion decision
 -> Harness N+1
```

まで追跡可能であることを保証する。

本設計の目的は「失敗したらルールを増やす」ことではない。
同型失敗を繰り返す場合に、再指示だけで終わらせず、検知・防止・停止・影響低減へ変換できる Harness change を評価可能な形で提案する。

## 2. Decision summary

### D-1. 新しい top-level artifact は追加しない

Ratchet Traceability は既存 artifact の責務を接続する。

| 情報 | Owner artifact |
|---|---|
| 実際に発生した失敗の不変参照 | `FailureRecord` + `RunEvidence` |
| 複数 Run から導出した pattern | `HarnessImprovementCandidate` |
| 改善仮説 / expected prevention | `HarnessImprovementCandidate` |
| Harness N / N+1 identity | `HarnessManifest` |
| baseline / candidate comparison | `HarnessExperimentResult` |
| regression / prevention fixture | #909 Regression Set |
| PASS / FAIL / INCONCLUSIVE | `PromotionDecision` |
| 最終 Production Promotion | Human-owned |

新しい `RatchetRecord` 等は作らない。
同じ事実を複数 artifact に複製せず、content-addressed / immutable ref で接続する。

### D-2. Failure instance と Pattern identity を分離する

`failure_fingerprint` を恒久 identity として使用しない。
fingerprint は分類ロジック変更で変化しうるため、immutable event identity と versioned pattern identity を分離する。

```yaml
failure_instance_ref:
  run_id: run-...
  failure_record_ref: sha256:...
  event_ref: event-...
  evidence_refs:
    - ...

pattern_snapshot:
  pattern_id: pattern:verification-skipped
  pattern_version: 1
  classifier_digest: sha256:...
  source_set_digest: sha256:...
  fingerprint: sha256:...
```

原則:

- `failure_instance_ref` は観測事実への immutable reference。instance key は少なくとも `run_id + event_ref` に束縛し、cause hypothesis の改訂で同一 failure instance が別物にならないようにする。
- `failure_record_ref` はその時点の immutable FailureRecord payload への content-addressed ref とし、instance key と分離する。
- `pattern_snapshot` は Retrospective が Candidate 作成時点で固定する classification snapshot。独立 artifact への ref ではない。
- `fingerprint` は dedup / similarity の補助。主キーではない。
- pattern classifier を更新しても過去の Failure instance provenance は変えない。

### D-3. “prevented recurrence” を事実として記録しない

「この変更が無ければ再発したはず」は反事実であり、直接証明できない。

代わりに以下を Evidence として扱う。

1. known-bad replay / Incident Regression fixture で既知失敗を再現
2. baseline Harness で期待する failure / miss が起きる
3. candidate Harness で `detect | prevent | stop | reduce_impact` の期待結果になる
4. sealed / negative controls で別の能力を壊していない
5. canary / post-promotion window で same-pattern recurrence を観測する

authoritative metric は例えば:

- `prevention_fixture_pass_rate`
- `same_pattern_recurrence_rate`
- `false_positive_rate`
- `false_negative_rate`
- `rollback_rate`

とし、`prevented_recurrence_count` のような反事実値を正本にしない。

### D-4. Pattern は独立 SSoT にしない

新しい Pattern artifact を暗黙に作らない。
Pattern は Candidate 作成時点の **classification snapshot** として保持し、分類方法と source set を digest で固定する。

```yaml
pattern_snapshot:
  pattern_id: pattern:verification-skipped
  pattern_version: 1
  classifier_digest: sha256:...
  source_set_digest: sha256:...
  fingerprint: sha256:...
  occurrence_count: 3
  scope: project
```

原則:

- `pattern_id` は人間可読な semantic label。単独では identity にしない。
- `classifier_digest` は分類規則 / classifier version を固定する。
- `source_set_digest` は Candidate 作成時に cluster へ含めた immutable Failure instance refs の集合を固定する。
- 同じ `pattern_id` でも classifier / source set が異なる snapshot を同一 evidence として比較しない。
- 複数 Candidate で Pattern 専用 SSoT を共有する必要が実証されるまでは、新 artifact を追加しない。

## 3. Artifact ownership and additive fields

### 3.1 FailureRecord

既存 canon の責務を維持する。

```yaml
failure_record:
  failure_record_id: sha256:...
  observation: ...
  failure_fingerprint: ...
  evidence_refs: [...]
  cause_hypothesis: ...
  repairability: ...
  result: ...
```

追加原則:

- `failure_record_id` は canonical content / event binding から決まる immutable ref とする方向で Phase 1 schema を設計する。
- `failure_fingerprint` は検索・cluster 用であり identity としない。
- cause hypothesis は observation と同一 artifact 内でも field を分離する。

### 3.2 RunEvidence (#874)

RunEvidence は source FailureRecord refs を projection できる。

```yaml
run_evidence:
  run_id: ...
  harness_manifest_ref: sha256:...
  failure_record_refs:
    - sha256:...
  evidence_refs:
    - ...
```

Ratchet 用に raw transcript や新しい memory payload を足さない。

### 3.3 HarnessImprovementCandidate (#869)

Candidate が Ratchet Traceability の中心となる。

```yaml
candidate:
  candidate_id: candidate:...
  hypothesis: ...

  source:
    run_evidence_refs:
      - sha256:...
    failure_instance_refs:
      - run_id: ...
        failure_record_ref: sha256:...
    pattern_snapshot:
      pattern_id: pattern:...
      pattern_version: 1
      classifier_digest: sha256:...
      source_set_digest: sha256:...
      fingerprint: sha256:...
      occurrence_count: 3
      scope: project

  target:
    operation: UPDATE
    component_refs:
      - component_id: verifier:completion-evidence
    allowed_paths:
      - ...

  expected_prevention:
    mode: detect | prevent | stop | reduce_impact
    pattern_refs:
      - pattern:...
    expected_effect: ...

  baseline_manifest_ref: sha256:...
  evaluation_plan_digest: sha256:...
  canary_plan_ref: ...
  rollback_plan_ref: ...
```

原則:

- **1 Candidate = 1 Hypothesis** を維持する。
- `occurrence_count` だけで promotion を決めない。
- Candidate は baseline HarnessManifest の内容を再定義しない。ref のみ持つ。
- Candidate 作成後、`evaluation_plan_digest` は不変。

### 3.4 HarnessManifest

既存 `harness-manifest.md` をそのまま identity source とする。
Ratchet 専用フィールドは追加しない。

Candidate implementation 後の actual delta は Evaluation Harness が baseline / candidate Manifest と実差分から算出する。

```yaml
baseline_manifest_ref: sha256:...
candidate_manifest_ref: sha256:...

component_deltas:
  - component_id: verifier:completion-evidence
    before_content_sha: sha256:...
    after_content_sha: sha256:...
```

`component_deltas` は Candidate 自己申告ではなく Evaluation Harness の観測値。

### 3.5 HarnessExperimentResult

```yaml
experiment_result:
  candidate_id: candidate:...
  evaluation_plan_digest: sha256:...
  baseline_manifest_ref: sha256:...
  candidate_manifest_ref: sha256:...

  observed_component_deltas:
    - component_id: ...
      before_content_sha: sha256:...
      after_content_sha: sha256:...

  prevention_evidence:
    - kind: incident_regression | known_bad_replay | negative_control | invariant | canary_observation
      ref: ...
      expected: ...
      observed: ...
      status: PASS | FAIL | INCONCLUSIVE

  activation:
    required_level: influenced_decision
    observed_level: influenced_decision

  metrics:
    prevention_fixture_pass_rate: ...
    false_positive_rate: ...
    false_negative_rate: ...
    rollback_rate: ...
    recurrence_observation:
      pattern_classifier_digest: sha256:...
      window_start: ...
      window_end: ...
      eligible_run_count: ...
      matching_failure_run_count: ...
      same_pattern_recurrence_rate: ...

  result: PASS | FAIL | INCONCLUSIVE
```

原則:

- Candidate が verifier / gate を変更する場合は `influenced_decision` まで必要。
- baseline / candidate Manifest identity が取れなければ `INCONCLUSIVE`。
- actual diff が `allowed_paths` を超えた場合 fail-closed。
- Candidate が sealed fixture / Evaluation Harness を変更した場合通常評価で PASS にしない。

### 3.6 PromotionDecision / #811

PromotionDecision は ExperimentResult を参照し、同じ評価を再実装しない。

```yaml
promotion_decision:
  candidate_id: candidate:...
  experiment_result_ref: sha256:...
  decision: PASS | FAIL | INCONCLUSIVE
  prevention_evidence_refs:
    - ...
  decision_reason_codes:
    - ...
```

Human-owned Production Promotion / merge は別であり、この decision が自動 merge を許可しない。

## 4. Ratchet invariants

### R1. Provenance completeness

Promotion Ready へ進む Candidate は最低限次を辿れる。

```text
FailureRecord / RunEvidence
 -> Candidate
 -> baseline HarnessManifest
 -> candidate HarnessManifest
 -> observed component delta
 -> prevention evidence
 -> ExperimentResult
 -> PromotionDecision
```

どれかが欠落する場合は `INCONCLUSIVE` または Human-required。

### R2. Evidence before prevention claim

自然言語の「次から注意する」「ルールを追加した」は prevention evidence にならない。

少なくとも 1 つの executable / observable evidence が必要。

- known-bad replay
- Incident Regression fixture
- deterministic invariant
- negative control / mutation
- canary observation

### R3. Candidate cannot weaken its judge

Candidate は次を同一評価中に変更できない。

- evaluation plan
- sealed / held-out fixtures
- Promotion Policy
- protected Gate
- stable meta-verifier
- acceptance threshold

変更する場合は別 Candidate / 別 evaluation とする。

### R4. Actual delta beats declared delta

`allowed_paths` / target component は宣言値。
Promotion Evaluator は baseline / candidate Manifest と source commits から実差分を観測し、

```text
actual delta ⊆ allowed_paths
```

を必須確認する。

### R5. Recurrence count is evidence, not authority

同型失敗回数は候補生成の evidence には使えるが、採用権限にはしない。

severity / reproducibility / generalizability / blast radius / false-positive risk / maintenance cost を合わせて評価する。

`same_pattern_recurrence_rate` を比較する場合は、少なくとも classifier digest / observation window / eligible run denominator を一緒に記録する。これらが異なる値を同一系列として比較しない。

### R6. Create Last

同型失敗への対応で新 Skill / Agent / Hook / Flow を増やす前に、

1. 既存 component の設定修正
2. deterministic test / lint / invariant
3. existing Verifier の改善
4. reuse / update / merge

を検討する。

## 5. Representative scenario — verification skipped

### 5.1 Source failure

```text
Run A:
  code change exists
  required verification evidence missing
  completion was attempted
```

FailureRecord:

```yaml
failure_record_id: sha256:F1
observation: "completion attempted without required verification evidence"
failure_fingerprint: "verification-required-but-missing"
evidence_refs:
  - event:completion_attempted
  - verifier:missing
```

### 5.2 Retrospective / pattern

複数 Run の同型 failure を cluster。

```yaml
pattern_id: pattern:verification-skipped
pattern_version: 1
classifier_digest: sha256:CLASSIFIER-V1
source_set_digest: sha256:SOURCE-SET
occurrence_count: 3
scope: project
```

### 5.3 Candidate

```yaml
candidate_id: C-VERIFY-001
hypothesis: "completion gate が required verification evidence の存在を決定論的に要求すれば同型 miss を検知・停止できる"
target:
  operation: UPDATE
  component_refs:
    - verifier:completion-evidence
expected_prevention:
  mode: stop
baseline_manifest_ref: sha256:H-N
evaluation_plan_digest: sha256:E-001
```

### 5.4 Pre-registered evaluation

- fixture: `incident-verification-skipped-v1`
- negative control: verification evidence が正しく存在する正常ケース
- baseline manifest: H-N
- required activation: `influenced_decision`
- critical regression:
  - verification evidence 無しで completion を許可したら FAIL
  - 正常ケースを block したら FAIL

### 5.5 Expected paired result

```text
baseline:
  known-bad replay -> completion accepted / miss reproduced

candidate:
  known-bad replay -> verifier detects missing evidence
                   -> Decision Engine stops completion

negative control:
  valid verification evidence -> completion path remains available
```

この組を満たして初めて「既知 failure に対する prevention evidence がある」と言える。

## 6. Phase A validation matrix

| Question | Decision |
|---|---|
| 新 artifact が必要か | **No**。既存 artifact refs で表現する |
| failure fingerprint を identity にするか | **No** |
| immutable source identity | FailureRecord / RunEvent refs |
| pattern identity | Candidate-local snapshot: `pattern_id + pattern_version + classifier_digest + source_set_digest` |
| Harness delta の正本 | Evaluation Harness が観測する baseline/candidate Manifest + actual diff |
| regression evidence | #909 Regression Set |
| promotion owner | #811 / Promotion surface + Human final decision |
| auto promotion | **No** |
| Legacy schema変更 | **No** |
| live self-modification | **No** |

## 7. Implementation handoff

Phase B 実装前に以下を子タスク化する。

1. **Schema design**
   - V2 FailureRecord stable ref
   - HarnessImprovementCandidate additive fields
   - HarnessExperimentResult additive fields
2. **Incident regression linkage**
   - #909 fixture manifest に source failure / candidate refs を追加する設計
3. **Observed delta**
   - Evaluation Harness 側で baseline / candidate Manifest から component delta を算出
4. **Representative executable fixture**
   - `verification-skipped` known-bad replay + negative control
5. **Promotion integration**
   - #811 が ExperimentResult / prevention evidence refs を consume
6. **Metrics**
   - prevention fixture pass rate
   - same-pattern recurrence rate（classifier digest / observation window / denominator とセット）
   - false positive / negative
   - rollback

Phase B では最初から general-purpose learning engine を作らない。
`verification-skipped` の 1 vertical slice で provenance を E2E に通し、契約が成立してから対象 pattern を増やす。

## 8. Review checklist

- [x] North Star の新原則を不要に増やしていない
- [x] 新 top-level artifact を追加していない
- [x] Failure observation と Pattern classification を分離した
- [x] Pattern を独立 SSoT にせず classifier/source-set digest 付き snapshot とした
- [x] fingerprint を primary identity にしていない
- [x] Candidate 宣言値と actual diff を分離した
- [x] Candidate が評価系を変更できない
- [x] PASS / FAIL / INCONCLUSIVE を維持した
- [x] Human-owned Promotion / merge を維持した
- [x] Legacy RunEvidence schema を変更しない
- [x] regression fixture と false-positive control の両方を要求した
- [x] “prevented recurrence” を直接の事実として扱っていない
- [x] Create Last / simplification を維持した
