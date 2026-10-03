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
| evidence class | derived evaluation metadata | evaluation caller | synthetic_fixture / historical_replay / live_shadow。synthetic を rollout evidence と数えない |
| historical/live evidence refs | referenced evidence | tracked repository artifact / live run evidence | repository-visible ref の実在を検証。historical harness signal は #874/#869 へ委譲 |
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
