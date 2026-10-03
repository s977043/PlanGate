# TASK-1442 — PBI Materializer Field Ownership Map

> Parent: #1442  
> Design: #1440 / PR #1441  
> Purpose: feedback / RunEvidence -> AI-generated PBI materialization で authority を重複させない。

## Principle

```text
Author != Evidence Source != Semantic Authority != Approval Authority
```

`pbi_materializer.py` は **proposal/materialization primitive** であり、新しい Requirement authority / RunState / Gate / approval store ではない。

## Ownership

| Datum / Concern | Class | Owner | Materializer behavior |
| --- | --- | --- | --- |
| Goal / Problem / Requirement semantics | owned | `pbi-input.md` | draft/render/update proposal を作る。Plan で再定義しない |
| Acceptance Criteria | owned | `pbi-input.md` | refs/本文を保持。bound PBI の semantic delta は Replan |
| PBI author | owned metadata | `pbi-input.md` | human / ai / mixed。trust scoreには使わない |
| claim class | owned metadata | `pbi-input.md` | observed / reported / inferred を保持し、昇格させない |
| source/origin refs | referenced | source artifact / external source | PBIにrefのみ保持。raw transcriptは保存しない |
| Requirement acceptance basis | owned metadata | `pbi-input.md` | evidence / explicit_decision / policy_rule。explicit_decision は decision_log provenance、policy_rule は policy provenance の実 ref を必須とする |
| Issue/PBI similarity | derived | materializer | exact/canonical factsのみ。LLM fuzzy similarityはauthorityにしない |
| admission decision | derived evaluation proposal | materializer | materialize / no_action / discover_more。close/write/suppression authorityを持たない |
| materialization decision | derived | materializer | update_existing / link_only / create_new |
| shadow expectation | referenced evaluation evidence | reviewed external expectation | decision/readiness comparison only。PBI/Run/Harness authorityを持たない |
| shadow comparison | derived | materializer | match / mismatch と差分 field を返すだけ。write/promotionを許可しない |
| proposal kind / apply contract | derived safety metadata | materializer | full_draft / semantic_patch_proposal / link_evidence_only。Phase 1 は write_allowed=false / replacement_allowed=false |
| existing PBI binding | referenced | existing Plan Package / approval | c3.json存在等を入力として読む。materializerはbindingを発行しない |
| Plan Package hash / approval | referenced | existing PlanGate contract | materializerは生成・承認しない |
| current RunState / LoopContract | referenced / forbidden-to-mutate | ai-loop V2 runtime | follow_up では不変。replan_current は既存Replanへroute |
| HarnessManifest identity | referenced / forbidden-to-mutate | ai-loop V2 runtime | active Run中は変更しない |
| HarnessImprovementCandidate | referenced | #869 / Evolution contract | harness draft時pending可、Plan/readiness前にref必須 |
| RunEvidence / FailureRecord | referenced evidence | V2 event projection / failure contract | source ref と claim class を保持。唯一のPBI authorityにはしない |
| decision-log | referenced decision | existing task decision log | `source_kind=decision_log` + 実在 `decision-log.jsonl#<decision_id>` を explicit_decision の basis ref に利用。自由記述 ref のみでは authority を成立させない |
| hidden CoT / raw transcript / session log | forbidden | — | 入力/出力の保存を拒否 |
| Shadow evaluation report | derived evidence | materializer evaluator | train/test + evidence-class metricsを生成するが write / promotion authority を持たない |
| write-review assessment | derived review-readiness projection | materializer assessor | admission/materialization evidenceを集約し Human review 候補かを示す。write/close/suppression/merge authorityは持たない |
| rollout quality metrics | derived evaluation evidence | evaluator cases[] | live_shadow のみから duplicate FP/FN・decision/readiness mismatch・reject distribution を導出。quality acceptance authorityは持たない |
| evaluator report refs | referenced evaluation artifacts | caller / repository evidence store | stored JSON と embedded report の canonical hash 一致を要求。authorship は保証しない |
| evidence class | derived evaluation metadata | evaluation caller | synthetic_fixture / historical_replay / live_shadow。synthetic を rollout evidence と数えない |
| historical/live evidence refs | referenced evidence | tracked repository artifact / live run evidence | repository-visible ref の実在を検証。historical harness signal は #874/#869 へ委譲 |
| live shadow capture identity | referenced capture metadata | passive capture producer + RunEvidence | capture artifact は task_id / run_id / captured_at / runtime_head_sha / capture_ref / signal を保持。単体では live evidence に数えない |
| live shadow RunEvidence binding | referenced verification relation | RunEvidence + evaluator | RunEvidence.evidence_refs が capture_ref と upstream signal.source_ref を含み、task/run/head/time を照合した場合のみ live_shadow case として受理 |
| shadow oracle ref | referenced evaluation evidence | reviewed oracle artifact | historical/live では repo 内実在 + source evidence と別 artifact を要求。author independence は別途必要 |
| GitHub Issue close/merge | forbidden action | GitHub / Human policy | materializerは実行しない |
| Production Harness promotion | forbidden action | Human-owned boundary | materializerは実行しない |

## Existing-work search boundary

Phase 1 first slice は2入力を許す。

1. **normalized external candidate array** — GitHub Issue search等のadapter結果。materializer内部からネットワークを呼ばない。
2. **local working-tree scan** — `docs/working/TASK-*/pbi-input.md` をread-onlyでexact/canonical matchする。

Malformed adapter input は fail-closed。検索結果を黙って捨てて `create_new` に倒さない。

## Acceptance authority boundary

Requirement acceptance は author の自己申告では成立しない。

- `acceptance_basis=evidence`: basis ref が material claim の source/origin に存在し、inferred-only ではない。
- `acceptance_basis=explicit_decision`: basis ref が `source_kind=decision_log` provenance に存在し、repository-visible な `decision-log.jsonl` が実在し、fragment の `decision_id` が **ちょうど 1 件**存在する。
- `acceptance_basis=policy_rule`: basis ref が `source_kind=policy` provenance に存在し、repository-visible な Markdown policy source と **実在する rule fragment** が確認できる。
- authority ref は repository-relative のみ。absolute path / `..` traversal / root 解決不能 / source 不在は fail-closed。`--authority-root` を明示した場合はその root だけを信頼し、cwd/source tree へ fallback しない。
- source-kind と ref を payload 内で同時に捏造しても authority は成立しない。

これにより AI-generated PBI は作成可能だが、Requirement の accepted status を架空の authority で自己付与できない。

## Application axes

```text
application timing = follow_up | replan_current
target layer       = delivery | harness
```

- `follow_up + delivery`: future Run。current Run binding 不変。
- `replan_current + delivery`: existing Replan -> Plan Verification -> Plan Gate。
- `follow_up + harness`: draft可。Plan/readiness前に HarnessImprovementCandidate ref 必須。
- `replan_current + harness`: invalid / fail-closed。

## Phase 1 write boundary

Initial implementation is **shadow/read-only**.

- stdoutへ deterministic JSON / Markdown proposal を出力可能
- reviewed expectation を `--expected` で与えた場合、decision / matched_ref / readiness の一致・不一致を machine-readable に比較する
- comparison が `match` でも write / merge / promotion authority は発生しない
- `update_existing` は semantic patch proposal。既存PBI本文を読まずに全文置換してはならない
- local files / Issue / RunState / HarnessManifest は変更しない
- automatic write はfixtureとshadow結果を確認した後の別slice


## Shadow evaluation boundary

Shadow rollout の比較は case 単位だけでなく、複数 case を `train / test` に分けて集計できる。

- exact-match rate
- decision accuracy
- readiness accuracy
- materialization error count

ただし、**test というラベルだけでは hidden holdout を保証しない**。改善を行う Agent から test case / oracle を隔離できているかは呼び出し側の責務であり、この materializer は secrecy を主張しない。

評価レポートは常に:

```text
write_allowed = false
automatic_promotion = false
```

を返す。train/test が 100% でも automatic write / promotion を有効化しない。


## Historical replay boundary

Repository-grounded replay は `synthetic_fixture` と分離して `historical_replay` として記録する。

- historical/live case は `evidence_refs[]` が必須で、repository root 内に実在することを検証する。
- Harness target の historical replay は materializer で trigger 判断を再実装せず、#874 `to_shadow_candidate_input()` → #869 HarnessImprovementCandidate / Evolution に委譲する。
- historical/live case の `oracle_ref` は repository-visible な実在 artifact を要求し、source evidence 自身を oracle として再利用しない。
- ただし **oracle artifact が別ファイルであることは reviewer independence を意味しない**。独立 reviewer / evaluator による隔離は caller 側の責務。

現時点の historical corpus は delivery target の positive materialization 2 件のみであり、次を保証しない:

```text
materialization_admission_evaluated = false
no_action_coverage = false
oracle_independence_enforced = false
write_review_eligible = false
```

したがって historical replay の 100% match は automatic write 解放条件にならない。


## Admission boundary

PBI admission と PBI materialization は別軸にする。

```text
signal
  -> materialize | no_action | discover_more
  -> materialize の場合のみ
     update_existing | link_only | create_new
```

- `no_action` は評価上の proposal であり、source Issue/PBI を close / resolve / suppress する権限を持たない。
- `suppression_allowed=false` / `close_allowed=false` / `write_allowed=false` を runtime 出力で固定する。
- `reported` / `inferred` の解消・informational signal は自動 `no_action` にせず `discover_more` へ戻す。
- `observed + resolved/informational` のみ shadow 上で `no_action` proposal を生成できる。
- Harness admission は本 materializer で再実装せず、#874/#869 Candidate/Evolution に委譲する。


## Live shadow capture boundary

`evidence_class=live_shadow` はラベルや自己申告 metadata だけでは成立しない。

### 1. Passive capture

`--capture-signal` は stdout に **passive capture artifact** を生成するだけで、PBI / Issue / RunState を変更しない。

```text
upstream evidence
  ↓
--capture-signal
  ↓
passive_shadow_capture artifact
```

capture artifact は最低限:

```text
task_id
run_id
captured_at
runtime_head_sha
capture_ref
signal
signal_hash
authority.write_allowed      = false
authority.close_allowed      = false
authority.suppression_allowed = false
authority.oracle_attached    = false
```

を持つ。

- `signal.source_ref` は repository-relative syntax を必須とする。
- `signal.source_ref == capture_ref` は circular provenance として reject。
- Harness signal は #874/#869 Candidate/Evolution へ委譲する。
- capture producer 自身はファイルを書かない。artifact persistence は caller の明示操作。

### 2. RunEvidence binding

capture artifact 単体は `live_shadow` evidence ではない。後続 RunEvidence が同じ run の証跡として束縛して初めて評価対象にできる。

live evaluation case の `live_capture` は:

```json
{
  "capture_ref": "<repo-relative capture artifact>",
  "run_evidence_ref": "<repo-relative RunEvidence artifact>"
}
```

を持つ。

evaluator は:

- capture / RunEvidence の両 artifact が trusted repository root 内に実在
- RunEvidence schema を再検証
- capture `task_id == RunEvidence.task_id`
- capture `run_id == RunEvidence.run_id`
- capture `runtime_head_sha == RunEvidence.final_head_sha`
- RunEvidence `evidence_refs[]` に `capture_ref` が存在
- RunEvidence `evidence_refs[]` に capture 内 `signal.source_ref` が存在
- capture `captured_at` が RunEvidence `started_at..completed_at` 内
- `signal_hash` が capture 内 signal と一致

を fail-closed で確認する。

これにより:

```text
upstream run evidence/ref
  -> passive capture
  -> RunEvidence.evidence_refs binds source + capture
  -> shadow evaluator
  -> eligible as live_shadow
```

となる。

### 3. Verification limits

機械保証する契約 capability:

```text
live_shadow_label_alone_sufficient = false
live_shadow_run_evidence_binding_enforced = true
run_evidence_schema_revalidated = true
runtime_head_to_run_evidence_binding_enforced = true
```

一方、materializer は task_dir を再読込する RunEvidence verifier の完全検証までは実行しない。

```text
run_evidence_task_binding_reverified = false
run_evidence_task_binding_owner = caller_or_run_evidence_verifier
```

したがって上記は **binding rule が実装されている**ことを意味し、実 live observation が存在することを意味しない。  
`live_shadow_cases=0` の間は #1442 の live-shadow rollout AC を完了扱いにしない。



## Write-review readiness boundary

`write_review_ready=true` は **automatic write を許可する状態ではない**。

```text
Admission evaluation
Materialization evaluation
Dependency / Test assertions
        ↓
write-review assessment
        ↓
Human review candidate
```

runtime 出力は常に:

```text
write_allowed = false
close_allowed = false
suppression_allowed = false
automatic_promotion = false
merge_authority = false
```

を維持する。

assessment は次を fail-closed に確認する:

- materialization/admission report が repository-visible JSON artifact に束縛されている
- embedded report と stored report の canonical hash が一致する
- summary の live-shadow 件数 / observed decisions / error 件数が `cases[]` と一致する
- admission 3 decision と materialization 3 decision の coverage
- live-shadow evidence が admission / materialization 双方に存在する
- design dependency finalized / latest full Test green の caller assertion
- independent oracle review ref の存在
- generalization claim を要求する場合は isolated holdout review ref の存在

ただし以下は **未保証**:

```text
caller_asserted_dependency_status = true
caller_asserted_test_status = true
report_artifact_authorship_verified = false
independent_review_authorship_verified = false
```

したがって `write_review_ready=true` は「Human が write-capable slice をレビューする材料が揃った」という projection に限定し、production mutation authorization として利用してはならない。


## Live upstream source boundary

live-shadow の `signal.source_ref` は trusted repository root 配下の実在 artifact を要求する。

```text
upstream_source_repository_visibility_enforced = true
source_capture_run_evidence_separation_enforced = true
upstream_source_preexistence_verified = false
upstream_source_preexistence_owner = caller_or_capture_pipeline
```

したがって external feedback / Issue / chat 由来の signal は、raw URL や一時本文を直接 live evidence とせず、まず repository-visible な evidence artifact / snapshot として materialize してから `source_ref` へ束縛する。

materializer は source artifact の **存在と分離** を検証するが、「capture より前から存在した」という時間的真正性までは保証しない。


## Concrete final-head boundary

passive live-shadow capture は terminal label ではなく、後続 RunEvidence が concrete 40-hex `final_head_sha` を持てるかで適用可否を決める。

```text
live_capture_requires_concrete_final_head_sha = true
unavailable_final_head_live_capture_supported = false
```

`final_head_sha="unavailable"` の run では live capture を生成せず、`source_sha` / `target_sha` 等を代用して契約を満たしたことにしない。BLOCKED-without-head を扱うには別の binding design が必要であり、本 slice では扱わない。


## Rollout quality boundary

Rollout 品質は `cases[]` から決定論的に再計算する。summary の手入力値を正として扱わない。

### Duplicate detection

```text
expected=create_new
actual=update_existing|link_only
  => duplicate_false_positive

expected=update_existing|link_only
actual=create_new
  => duplicate_false_negative
```

`update_existing <-> link_only` は duplicate FP/FN ではなく通常の decision mismatch として扱う。

### Scope

```text
scope = live_shadow_only
synthetic_fixture -> rollout quality claim から除外
historical_replay -> rollout quality claim から除外
```

0 件の分母は `0.0` ではなく `null` とし、未観測を「0%」へ偽装しない。

materialization error / admission error は rate 計算から静かに除外せず:

```text
unevaluable_error_cases > 0
quality_review_complete = false
```

として明示する。

### Rejection distribution

全 reject:

```text
rejection_error_occurrences_by_category
```

provenance に限定した subset:

```text
provenance_rejection_error_occurrences
  = circular_or_derived
  + acceptance_basis
  + claim_class
  + source_reference
```

privacy / live-binding / unknown validation failure を provenance と誤ラベルしない。

### Review readiness != quality acceptance

```text
quality_thresholds_applied = false
quality_acceptance_decided = false
quality_acceptance_owner = human_or_rollout_policy
```

`write_review_ready=true` は「Human review に必要な Evidence が揃った」という意味に限定し、FP/FN や mismatch の許容可否を自動判定しない。  
実 live-shadow data が存在しない間、#1442 の false-positive / false-negative / mismatch review AC は未完了のまま維持する。
