# Human Attention Metrics — Cross-layer Measurement Contract

> Tracking: #1343 / WS6 #1349
> Related: #1285 (V2 RunEvidence measurement contract), s977043/river-review#1990
> Scope: metric glossary / measurement semantics / layer adapters only. No runtime schema change.

## 1. Purpose

Human Attention Architectureの効果を、River Review / ai-loop V2 / ai-dev / PlanGate / Evolutionで比較可能にする。

ただし、全layerを単一スコアへ押し込まない。

```text
Common glossary
   +
Layer-specific measurement adapter
   +
Safety / visibility guards
```

を採用する。

## 2. Core rule

> **Human Attention must never be optimized alone.**

採用判断の方向性:

```text
Human Attention decreases

AND

Correctness / Safety >= baseline
Critical visibility >= baseline
No material provenance regression
No material coverage / verification regression
```

低Attentionでも、重要情報が消えていればFAIL。

## 3. Metric glossary

### M1. Human Attention Time

**定義**

Humanが成果物を理解し、判断し、応答するために実際に注意を向けたactive time。

wall-clock待ち時間ではない。

**Unit**

seconds

**Allowed measurement modes**

1. `explicit`
   - Humanがtimer / UI action等でactive intervalを明示
   - timer操作などmeasurement自体のoverheadは可能なら別記し、task attentionへ無条件に混ぜない
2. `bounded_approximation`
   - event間隔から上限・下限を持って近似
3. `unavailable`
   - 信頼できる測定ができない

**禁止**

- unavailableを0にする
- PR open〜mergeのwall-clockをattention timeとして扱う
- LLM latencyをhuman attentionへ加える
- inferred precisionを実測値として扱う

**Representation concept**

```yaml
human_attention:
  value_seconds: 180 | null
  mode: explicit | bounded_approximation | unavailable
  lower_bound_seconds: 120 | null
  upper_bound_seconds: 240 | null
```

これは共通概念例であり、WS6では新schemaを作らない。

---

### M2. Human Intervention Count

**定義**

AI / HarnessからHumanへ、判断・承認・修正・追加情報が必要としてhandoffされた**独立した介入episode数**。

click数、comment数、message数ではない。

同じdecision requestに対する複数UI操作を複数介入として数えない。

**Important compatibility note**

Legacy `scripts/ai-loop/metrics.py` の `human_intervention_rate` は:

```text
(HUMAN_ESCALATED + BLOCKED) / all decisions
```

というoutcome proxyであり、本契約の `Human Intervention Count` と同一ではない。

既存metricはrename / overwriteしない。

呼び分け:

- `legacy_human_intervention_rate`: existing proxy（説明上の呼称）
- `human_intervention_count`: actual handoff episode count

---

### M3. Time to Human Required

**定義**

layerのworkが開始してから、systemが最初の `Human decision/action required` を明示的に出すまでの時間。

**Unit**

seconds

**Start anchor**

layer-specific adapterが評価開始前に固定し、既存のauthoritative event / timestampへ束縛する。
candidateごとにstart anchorを変えてはならない。

例:

- River Review: review run start
- ai-loop V2: Delivery / Evolution run start
- ai-dev: workflow run start（PR_CREATED handoffだけを測る場合はhandoff preparation startを別metricとして記録）
- PlanGate: Plan generation / review start
- Evolution: candidate evaluation cycle start

**End anchor**

Human-required signalがHuman-facing surfaceへ初めてmaterializeされたtimestamp。

**Guard**

短いほど常に良いわけではない。

早すぎるescalationで自律処理を放棄すると値だけ改善するため、最低限:

- human intervention count/rate
- autonomous completion / convergence
- correctness / safety

と併読する。

---

### M4. Human Decision Wait Time

**定義**

判断に必要なEvidenceが揃い、Human-required signalが提示されてから、Human decisionが記録されるまでのwall-clock time。

これはNorth Star §18の「Evidence取得後の意思決定待ち時間」と接続する。

**注意**

Human Attention Timeとは異なる。

```text
Decision Wait = calendar / queue delay
Attention Time = active cognitive work
```

startは、判断に必要なEvidenceが揃った時点とHuman-required signalが提示された時点のうち遅い方とします。Evidence不足の時間をHumanの意思決定待ちとして計上しません。

---

### M5. Decision Extraction Success

**定義**

Human-facing surfaceから、Humanが必要な判断内容を正しく抽出できた割合。

production telemetryより、固定fixtureを使うevalで測ることを基本とする。

最低限の抽出対象:

- required action / decision
- blocker / material risk
- uncertainty / incomplete verification
- evidence / provenance location

**Example rubric**

1 fixtureにつき各項目をbinaryまたはpre-frozen rubricで採点。

```text
success =
required decision correct
AND blocker state correct
AND uncertainty state correct
AND evidence location identifiable
```

speedだけでなくcorrectnessを要求する。

---

### M6. Visibility Regression

**定義**

Human-facing compression / projectionにより、評価前に固定したmaterial reference setの情報がcandidateで確認不能・誤認可能になった割合または件数。

reference setはbaseline出力そのものを正解扱いしない。fixture oracle、独立adjudication、または事前固定したexpected material itemsを用いる。baseline / candidateのどちらにも同じreference setを適用する。

対象例:

- critical / major finding
- blocking condition
- incomplete coverage
- verification uncertainty
- Human-owned decision requirement
- evidence provenance
- rejected / inconclusive state

**Target**

material visibility regression = 0 を基本とする。

分母となるmaterial item集合とseverity / materiality判定はcandidate実行前に固定する。

「L1に全文が出ない」こと自体はregressionではない。
L2/L3へ明確に辿れればvisibilityは維持できる。

---

### M7. Human Reverse Rate

**定義**

AI / systemが提示・推奨・auto-resolvedと扱った判断を、Humanが後からmaterialに覆した割合。

layer固有の母集団を明示する。

**禁止**

既存legacy `reversal_rate` と意味を混同しない。

Legacy reversalは「run内で非AUTO_APPROVED後に最終AUTO_APPROVEDへ収束」の意味であり、Human reverseではない。

---

## 4. Missing / approximation semantics

共通ルール:

| State | Meaning |
| --- | --- |
| measured | 信頼できる直接計測 |
| bounded_approximation | 上下限を持つ近似 |
| unavailable | 観測不能 |
| not_applicable | そのlayer / caseに概念がない |

`unavailable != 0`

`not_applicable != unavailable`

例:

- Humanが一度も関与しなかったrunのattention time:
  - 本当にHuman-facing eventが無く、instrumentationも完全なら `0 measured`
  - instrumentationが無いだけなら `unavailable`
- Human Decision Wait:
  - Human decisionを要求しないrunなら `not_applicable`
  - 要求したがdecision timestampを取得できないなら `unavailable`

## 5. Layer adapters

### River Review

Primary:
- human_attention_time
- human_intervention_count
- time_to_human_required
- decision_extraction_success
- visibility_regression
- human_reverse_rate

Existing inputs:
- #1990 Human Judgment Signal
- Review Artifact
- Review Coverage
- Resolution / Verification
- Decision Surface

Safety:
- critical / major visibility
- false suppression
- provenance loss
- incomplete coverage visibility

### ai-loop V2

Primary:
- time_to_human_required
- human_decision_wait_time
- human_intervention_count
- human_attention_time（instrumentation available時）
- visibility_regression

Existing semantics:
- Lifecycle State
- Terminal Outcome
- Stop Reason
- Policy Verdict
- VerificationResult
- FailureRecord
- RunEvidence / Event stream

#1285がV2 RunEvidence測定contractのowner。
WS6はtimestamp fieldを先行定義しない。

### ai-dev

Primary:
- handoff decision extraction success
- human_attention_time
- clarification / intervention count
- visibility regression

Stable boundary:
- `PR_CREATED` contract unchanged
- Human C-3 / C-4 unchanged

Before / afterはhandoff presentationだけを比較する。

### PlanGate

Primary:
- decision extraction success
- human_attention_time
- clarification count
- plan bloat proxy（参考）
- visibility regression

Guard:
- requirement coverage
- Evidence quality
- B-2 / required contract
- unsupported abstraction / invariant

#1337完了前はcandidate evaluationを開始しない。

### Evolution

Primary:
- promotion decision extraction success
- human_attention_time
- human_intervention_count
- repeated explanation burden
- visibility regression

Guard:
- rejected / INCONCLUSIVE candidate visibility
- Evaluation Evidence traceability
- Human-owned Promotion authority

## 6. Baseline / candidate comparison contract

比較時は最低限固定する。

- task / fixture profile
- layer
- metric start / end anchor
- material reference set / oracle
- model / effort（LLM生成比較の場合）
- tool / budget条件
- Human evaluator rubric
- measurement mode
- missing-data rule

結果は最低限:

- improved
- unchanged
- regressed
- inconclusive

を区別する。

欠測が主要metricにある場合、無理にimproved判定しない。

## 7. Adoption matrix

| Attention | Visibility / Safety | Result |
| --- | --- | --- |
| improves | maintained / improves | candidate for adoption |
| improves | regresses materially | reject |
| unchanged | improves materially | consider adoption |
| regresses | improves materially | explicit trade-off review |
| unknown | any | inconclusive |

「attention improves」だけで自動採用しない。

## 8. Metric gaming review

### Early escalation gaming

`time_to_human_required` を短くするためにすぐHumanへ投げる。

Guard:
- intervention count/rate
- autonomous convergence
- avoidable escalation

### Hidden information gaming

L1を短くしてattentionを下げる。

Guard:
- visibility regression
- decision extraction correctness
- L2/L3 traceability

### Missing-as-zero gaming

instrumentation無しrunを0秒扱いする。

Guard:
- explicit measurement mode
- unavailable / N/A separation

### Anchor shifting

candidate側だけrun start / signal timestampの定義を後ろへずらしてtime metricを改善する。

Guard:
- start / end anchorを評価前に固定
- authoritative eventへ束縛
- adapter version / definitionを記録

### Easy-case selection

簡単なtaskだけcandidateへ流す。

Guard:
- task profile固定
- paired comparison
- eligibility記録

### Reviewer familiarity bias

candidateを知っているreviewerが早く読む。

Guard:
- fixed rubric
- 可能なら blinded / counterbalanced eval
- raw results保存

### Human surveillance / performance gaming

Human Attention telemetryを個人の生産性評価へ転用すると、短時間で判断すること自体が目的化し、慎重なレビューや必要なHuman Gateを抑制します。

Guard:
- 個人の評価・査定KPIとして利用しない
- run / fixture単位の改善評価を基本とする
- 個人識別情報は測定に必要な最小限にする
- aggregateで目的を満たせる場合は個人別データを保持しない
- measurement overhead / consent / retentionを運用設計で明示する

## 9. Storage / ownership

WS6は共通語彙をownerするが、metric raw dataのSSoTにはならない。

- River Review raw signal: River Review側contract
- ai-loop V2 raw event / timestamp: #1285 / V2 RunEvidence・Event stream
- Plan evaluation raw outputs: #1337 / #1347 eval artifact
- aggregate comparison: layer-specific eval

新しいHuman Attention DBを作らない。

## 10. Recommended first evaluation

River Review #2368を最初のvalidation siteとする。

最初は精密なproduction telemetryを要求せず:

1. fixed review fixtures
2. baseline summary vs Decision Surface
3. decision extraction success
4. visibility regression
5. bounded/manual attention measurement

で原則が成立するか確認する。

成立後にinstrumentation投資の価値を判断する。

## 11. Review checklist

- metric名が既存metricと意味衝突していないか
- start / end anchorが曖昧でないか
- unavailableを0へ変換していないか
- Human Attentionだけを最適化していないか
- task selection biasを抑えているか
- layer固有metricを無理に共通化していないか
- safety / visibility guardがあるか
- raw evidenceのownerが明確か
- new schema / databaseを不要に増やしていないか
- 個人のperformance surveillanceへ転用される設計になっていないか

## 12. Decision

Cross-layerでは「同じschema」を共有するのではなく、**同じ意味を共有する**。

```text
Common semantic contract
      ↓
layer-specific adapter
      ↓
baseline / candidate evaluation
```

これにより、River Reviewの `attentionSeconds` とai-loop V2のevent-based timingを同一実装へ無理に寄せず、比較可能な意味だけを保つ。
