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
| write-capable rollout policy | policy / activation boundary | Human / rollout policy authority | write adapter の eligibility と mutation boundary を定義。materializer / collector / evaluator は self-activate できない。現在は R0 Shadow / DRAFT / NON-ACTIVE |
| rollout quality metrics | derived evaluation evidence | evaluator cases[] | live_shadow のみから duplicate FP/FN・decision/readiness mismatch・reject distribution を導出。quality acceptance authorityは持たない |
| live-shadow evidence collector | evidence writer / adapter | `pbi_live_shadow_collector.py` | `docs/working/TASK-XXXX/evidence/pbi-live-shadow/**` に capture / blind packet / reviewed case を create-or-reuse-identical で保存。PBI/Issue/RunState/Harness/merge authority は持たない |
| write rollout policy | capability policy (non-active until separate decision) | `write-capable-rollout-policy.md` | policy version + exact content SHA を activation decision が固定。file存在だけでは write authority を持たない |
| rollout activation decision | activation authority | repository-visible decision log / future activation artifact | from/to stage、enabled mutation kinds、policy ref/hash を固定。初回 activation は Human-owned |
| write-attempt receipt | append-only execution Evidence | future `TASK-XXXX/evidence/pbi-write-attempts/**` | deterministic attempt identity / provider result / reconciliation を保存。rollout activation、quality acceptance、PBI semantic authority は持たない |
| rollback evidence | mutation-scoped recovery Evidence | future write adapter | allowed path の inverse + pre-write hash/version のみ。full target backupを既定にせずprivacy再検証 |
| RunEvidence handoff | derived advisory metadata | collector capture result | source_ref + capture_ref の exact `--evidence-ref` args と source/capture hash を返す。authority ではなく、RunEvidence保存後のbinding再検証が必須 |
| materialization oracle | independent reviewed expectation | caller / independent reviewer | Admission materialize match 後の payload / existing-work snapshot / expected decision-readiness を hash で束縛。collector は生成しない |
| reviewed materialization case | derived evaluation input | collector assembler | Admission materialize matchを再検証し、payload/existing-work/oracleを既存 shadow batch contractへ束縛。PBI write authorityなし |
| materialization live inventory | derived read-only projection | collector inventory | tracked `materialization-case.json` を再検証・再評価し duplicate FP/FN / mismatch を再計算。quality acceptance / write Gate ではない |
| live collection plan | derived read-only gap projection | admission/materialization inventories | reviewed expected decision の未観測classを opportunistic observation gap として表示。quota / case generator / representative coverage claimではない |
| blind review packet | derived evidence | collector | maker actual / expected decision を含めず、source/capture/RunEvidence hash だけを束縛。reviewer independence は自己証明しない |
| admission oracle | independent reviewed expectation | caller / independent reviewer | collector は作成しない。同一 TASK live-shadow evidence namespace に置き、packet/source hash と expected admission decision を束縛 |
| reviewed admission case | derived evaluation input | collector assembler | source/capture/RunEvidence/packet と oracle を再検証して evaluator 互換 case を生成。oracle は `expected.oracle_ref` のみで参照し、`evidence_refs[]` に混ぜない |
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


## Live-shadow collector boundary

実 run の Evidence 保存は `pbi_materializer.py` ではなく、
`pbi_live_shadow_collector.py` が担当する。

保存可能 namespace:

```text
docs/working/TASK-XXXX/evidence/pbi-live-shadow/**
```

### Write semantics

```text
missing artifact
  -> atomic create

existing + byte-identical canonical JSON
  -> idempotent reuse

existing + different content
  -> fail closed

existing symlink / non-regular file
  -> fail closed
```

```text
overwrite_allowed = false
idempotent_reuse_allowed = true
```

親 directory fd を開いた後は temp create / hard-link / fsync を同じ dir-fd に束縛し、
事前 symlink 検査だけに依存しない。

### Blind review packet

collector の packet は maker の actual admission decision を保存しない。

```text
packet_blind_to_actual = true
actual_decision_disclosed = false
normalized_disposition_disclosed = false
oracle_attached = false
expected_decision_attached = false
```

ただし capture artifact 自体へのアクセス隔離までは collector が保証しない:

```text
capture_signal_blinding_enforced = false
oracle_independence_owner = caller_or_independent_reviewer
```

### Oracle attachment

oracle は collector が生成しない。別 reviewer / caller が repository-visible artifact として作り、
次を束縛する:

- exact blind packet ref + canonical hash
- exact upstream source ref + byte SHA-256
- expected admission decision
- `independent_review_asserted=true`
- `maker_actual_not_consulted_asserted=true`

collector は assertion の存在を検証するが reviewer identity / authorship independence を証明しない。

reviewed case では:

```text
evidence_refs[] =
  source_ref
  capture_ref
  run_evidence_ref
  packet_ref

expected.oracle_ref =
  oracle_ref
```

とし、oracle を source evidence に混ぜない。

### Rollout accounting

TA-94 の collector E2E は wiring / executable-path Evidence であり、
**real live-shadow rollout case として数えない**。

```text
synthetic collector E2E != real live observation
```

#1442 の live-shadow / FP-FN / mismatch rollout AC は実 run 由来 artifact が収集されるまで open のまま維持する。


## Live-shadow inventory boundary

inventory は repository の現在状態から毎回再計算する read-only projection であり、
永続 registry / lifecycle state / Gate を追加しない。

探索対象:

```text
docs/working/TASK-*/evidence/pbi-live-shadow/**/admission-case.json
```

各 candidate について:

- regular file であること
- artifact path から owner TASK を導出
- case artifact / capture / RunEvidence / oracle が同じ TASK live-shadow namespace に属すること
- existing admission evaluator contract で live binding / oracle / privacy を再検証
- duplicate logical `case_ref` は参加artifactを全件 invalid
- invalid artifact は黙って捨てず `invalid_case_artifacts[]` へ保持
- historical corpusをliveへ昇格しない
- synthetic fixtureをtracked live countへ混ぜない

inventory が報告する:

```text
tracked_live_case_total
evaluated_case_total
invalid_case_total
observed_admission_decisions
observed_source_kinds
rollout_quality
```

0件は0件のまま扱う。未観測を success rate 0% や rollout 完了へ変換しない。

### Verification boundary

```text
repository_chain_revalidated = true
task_namespace_binding_enforced = true
duplicate_logical_case_ids_rejected = true

runtime_execution_verified = false
source_preexistence_verified = false
reviewer_identity_verified = false
representative_coverage_claim_allowed = false
quality_acceptance_decided = false
```

したがって `tracked_live_case_total > 0` は repository-tracked chain の存在だけを意味し、
「実 runtime でその瞬間にcaptureされた」「代表性がある」「品質合格」「write解放可能」を意味しない。

TA-94 の synthetic collector chain を inventory すると tracked case は1件見えるが、
`runtime_execution_verified=false` を同時に要求する。
これは executable-path 検証であり、#1442 の real live-shadow rollout AC の達成には数えない。


## RunEvidence handoff boundary

capture 成功後、collector は caller 向けに exact RunEvidence injection を返す。

```text
run_evidence_handoff.evidence_refs =
  [source_ref, capture_ref]

run_evidence_handoff.cli_args =
  --evidence-ref <source_ref>
  --evidence-ref <capture_ref>
```

さらに:

```text
source_sha256
capture_hash
task_id
run_id
runtime_head_sha
captured_at
advisory_only = true
must_revalidate_after_run_evidence = true
```

を返す。

handoff は command construction の取り違え防止用であり、RunEvidence authority ではない。  
後段の `packet` / live binding が capture / RunEvidence / source を再検証する。

## Live Materialization review boundary

Admission live review の actual/expected がともに `materialize` で一致した場合だけ、
Materialization shadow evaluationへ進める。

必要な repository-visible artifacts:

```text
admission-case.json
materialization-payload.json
existing-work.json
materialization-oracle.json
materialization-case.json
```

すべて同一 `TASK-XXXX/evidence/pbi-live-shadow/**` namespace に束縛する。

materialization oracle は:

- admission case ref + canonical hash
- payload ref + canonical hash
- existing-work ref + canonical hash
- expected `decision / matched_ref / readiness_status / readiness_route`
- independent review assertions

を持つ。

collector は oracle を生成せず、maker actual をoracleへ保存させない。

reviewed materialization case は既存 `_validate_shadow_batch()` を通し、
oracleは `expected.oracle_ref` にのみ置く。source `evidence_refs[]` へ混ぜない。

Materialization inventory は:

```text
docs/working/TASK-*/evidence/pbi-live-shadow/**/materialization-case.json
```

のみを探索し、current repository artifactsから毎回再計算する。

```text
observed_materialization_decisions
missing_materialization_decisions
duplicate_false_positive_rate
duplicate_false_negative_rate
decision_mismatch_count
readiness_mismatch_count
```

を出すが、以下は維持する:

```text
runtime_execution_verified = false
source_preexistence_verified = false
reviewer_identity_verified = false
representative_coverage_claim_allowed = false
quality_thresholds_applied = false
quality_acceptance_decided = false
write_allowed = false
```

したがって tracked materialization case が存在しても、representative coverage / quality acceptance /
automatic PBI write の根拠にはならない。


## Live collection plan boundary

collection plan は admission / materialization inventory から毎回再計算する read-only projection。

coverage basis は **reviewed expected decision** とする。

```text
maker actual decision
  = model behavior observation

reviewed expected decision
  = collection coverage basis
```

actual が `materialize` でも reviewer expected が `no_action` なら、
`materialize` ground-truth case を収集済みとは数えない。

materialization observation gap は reviewed expected admission `materialize` が存在する場合だけ
`collector_path_available=true` とする。

ただし collector 経路の利用可能性と、現在 real runtime observation が発生していることは分離する。

```text
collector_path_available = collector / prerequisite 上その観測経路を処理できる
real_runtime_observation_available = null
real_runtime_observation_available_verified = false
```

後者は collector 自身では証明しない。`null` は「未確認」であり、「確認済みで利用不可」を意味しない。

ただしこれはquotaやcase generation instructionではない:

```text
opportunistic_observation_only = true
synthetic_case_generation_for_coverage_allowed = false
historical_relabeling_allowed = false
decision_coverage_quota_defined = false
source_kind_coverage_requirement_defined = false
representative_coverage_claim_allowed = false
coverage_complete_implies_representative = false
observation_gap_is_quota = false
observation_gap_is_case_generation_instruction = false
coverage_gap_basis = reviewed_expected_decisions
maker_actual_counts_as_ground_truth_coverage = false
runtime_execution_verified = false
quality_acceptance_decided = false
```

したがって missing target を埋める目的で synthetic fixture を作ったり、
historical replay を live evidence に昇格したりしない。


### Observation-gap terminology

`collection-plan` は decision class の不足を **収集目標** ではなく **未観測 gap** として表す。

```text
observation_gaps[]
observation_gap_count
observation_gap_is_quota = false
observation_gap_is_case_generation_instruction = false
coverage_gap_basis = reviewed_expected_decisions
```

この語彙は、coverage不足を理由に synthetic case を生成したり、実runを恣意的に選別する誘因を避けるためのもの。gap は「次に自然発生した実runで観測できれば収集する候補」であり、ノルマではない。



## Collection-plan freshness boundary

`collection-plan` は admission / materialization inventory の current projection から毎回再計算する。
保存された plan の再利用を freshness 証明として扱わない。

```text
inventory_binding.admission_inventory_hash
inventory_binding.materialization_inventory_hash
inventory_binding.combined_inventory_hash

plan_reuse_without_reinventory_allowed = false
runtime_head_bound = false
repository_commit_verified = false
inventory_hashes_are_commit_identity = false
```

hash は inventory JSON 内容の canonical identity であり、Git commit / runtime head /
source preexistence / reviewer identity の証明ではない。

したがって Human / 上位workflow が collection-plan を判断材料に使う直前に再実行し、
repository evidence が変化した場合は新しい snapshot を正とする。

completion-status は collection-plan の `inventory_binding` を
`repository_evidence.collection_plan_inventory_binding` として投影するが、
それ自体で rollout completion / quality acceptance / write activation を決めない。

## Write-capable rollout policy boundary

正本 draft:

```text
docs/working/TASK-1442/write-capable-rollout-policy.md
```

現在値:

```text
effective_stage = R0 Shadow
R1_enabled = false
R2_enabled = false
automatic_mutation_allowed = false
```

policy definition と rollout activation は分離する。

```text
policy definition
!= write adapter implementation
!= rollout activation
!= quality acceptance
```

初期 write-capable slice は single-target に限定し、provider result が `unknown` の場合は
blind retry を禁止する。

```text
one mutation attempt = one semantic target
multi-target transaction = unsupported
unknown -> reconciliation + Human escalation
```

writer は同じ mutation attempt で policy / source evidence / oracle / RunEvidence /
approval authority / evaluator report を変更できない。

activation は別の repository-visible decision とし、少なくとも初回は Human-owned。
materializer / collector / evaluator の自己評価だけで rollout stage を昇格させてはならない。

TA-94 はこの **non-activation contract** を検証するが、write-capable adapter の存在や
production mutation capability は検証しない。


## Completion status boundary

実装を増やす前に、残課題を次の4群へ分類する。

```text
implementation
dependency
evidence
review
```

`completion-status` は repository inventory と caller assertion を組み合わせるが、
GitHub の Test 結果や PR 状態を collector 自身で検証しない。

```text
latest_full_test_status_verified_by_collector = false
design_dependency_status_verified_by_collector = false
assertions_independently_verified = false
```

review ref が指定された場合は repository-visible regular file の実在と byte SHA-256 を束縛する。

ただし:

```text
semantic_content_verified = false
reviewer_identity_verified = false
independence_verified = false
```

を維持する。

`next_action` は残課題分類だけを行う。

```text
fix_repository_or_evidence_integrity
finalize_design_dependency
collect_opportunistic_real_live_evidence
perform_human_evidence_and_quality_review
human_rollout_decision
```

重要な不変条件:

```text
rollout_completion_machine_decidable = false
rollout_complete = false
automatic_write_activation_allowed = false
machine_completion_decision_allowed = false
machine_write_activation_allowed = false
```

したがって `human_rollout_decision` は「Human が判断できる材料へ進む」ことを示すだけで、
自動完了・quality acceptance・write activation を意味しない。

また Evidence gap は新機能実装を自動的に要求しない。

```text
new_feature_work_implied_by_evidence_gap = false
synthetic_case_generation_for_completion_allowed = false
historical_relabeling_for_completion_allowed = false
```

実 run Evidence 待ちしか残っていない場合、追加featureを作るのではなく opportunistic observation を待つ。
