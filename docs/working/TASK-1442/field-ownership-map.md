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
| Shadow evaluation report | derived evidence | materializer evaluator | train/test metricsを生成するが write / promotion authority を持たない |
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
- `acceptance_basis=policy_rule`: basis ref が `source_kind=policy` provenance に存在し、repository-visible な policy source file が実在する。
- authority ref は repository-relative のみ。absolute path / `..` traversal / root 解決不能 / source 不在は fail-closed。
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
