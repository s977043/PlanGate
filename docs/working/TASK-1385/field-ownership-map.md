# TASK-1385 Phase A — Work Item Graph field ownership map

> Status: planning artifact / non-canon  
> Parent: #911  
> Implementation issue: #1385  
> Design boundary: #1379 (Human C-4 / merge pending)  
> Purpose: schema implementation前に各fieldのauthorityを一意にする。

## 1. Invariants

1. WorkItemGraph は **immutable declaration**。第二のRunStateにしない。
2. Assignment は **immutable binding declaration**。session status recordにしない。
3. runtime lifecycle は #1025 RunState が所有する。
4. continue / repair / replan / stop は #894 が所有する。
5. runtime graph facts は #874 / V2 event stream が所有し、RunEvidence / #908 がprojectionする。
6. replanは既存Graphを更新せず、新しいGraph artifactを作る。
7. GraphはHuman-owned authority / policy / Verifier / Gate / acceptance threshold / active Harness identityを変更しない。
8. WorkItemGraphはapproved scopeを狭められるが、広げられない。
9. bounded dynamic instantiationは、approved templateのspecializeまたは既存work itemのpartitionに限定する。新しいAC・権限・scopeを発明しない。

分類:
- owned: 本artifactがsemantic authorityを持つ
- referenced: ownerへのrefだけ保持
- derived: 表示・検証のため算出可能だがauthorityにしない
- forbidden: 本artifactへauthoritativeに保存しない

## 2. WorkItemGraph

| field | class | decision |
|---|---|---|
| schema_version | owned | artifact version only |
| graph_id | owned | logical lineage identity。superseding artifact間で継承可能 |
| graph_ref | derived/reference identity | artifact payloadの外で算出・付与するimmutable ref。self-hash fieldとしてpayloadに埋め込まない |
| supersedes_graph_ref | referenced | replan時のみ前Graphを参照 |
| context_id / context_ref | referenced | #1389 Intent Context Packageへsemantic binding。`snapshot_ref` はoptional audit provenance |
| plan_hash | referenced | approved Planへbinding |
| topology_mode | owned | static / adaptive / bounded_dynamic |
| work_items[] | owned | immutable concrete declarations |
| work_item_templates[] | owned | bounded dynamic用のpre-approved template。AC/scope/capabilityの上限を宣言 |
| edges[] | owned | canonical dependency representation |
| joins[] | owned | join declarationのみ。現在の満足状態は持たない |
| bounded_dynamic_policy | owned | allowlisted template IDs / permitted specialization fields / max instances / max parallelism |
| budget_ref | referenced | LoopContract/budget owner |
| tool_policy_ref / policy_ref | referenced | Harness/policy owner |
| harness_manifest_ref | referenced | provenance/binding only |
| provenance | owned | generator/version/source refs。hidden CoT禁止 |
| current_node / status | forbidden | #1025 RunState |
| outcome / stop_reasons | forbidden | V2 taxonomy / #894 |
| policy_verdict | forbidden | Policy Gate / RunState current value |
| repair_required / replan_required | forbidden | #894 |
| mutable graph_revision | forbidden | second mutable stateを作らない |

### edges[] vs depends_on[]

#911 draftには work itemの `depends_on[]` があるが、`edges[]` と両方をauthoritativeにするとdriftする。

**v1 decision**:
- `edges[]` をcanonicalにする。
- `depends_on[]` はderived/adaptor outputだけ。
- schema/validatorは2つの独立authorityを作らない。

## 3. Work item

| field | class | decision |
|---|---|---|
| id / kind / title | owned | graph-local declaration。dynamic instanceはapproved template/parentから継承 |
| inputs[] | referenced | source/context/artifact refs |
| expected_outputs[] | owned | decomposition contract |
| acceptance_criteria_refs[] | referenced | approved Plan / LoopContract。dynamic instanceも既存refのsubset/partitionのみ。新規AC本文を後付けしない |
| risk_class | derived/reference | authoritative riskを下げられない |
| execution_profile | derived | policy + HO + riskから導出。less restrictive禁止 |
| allowed_paths[] | owned narrowing constraint | Plan scopeかつtemplate/parent scopeのsubset/equivalentのみ |
| required_capabilities[] | owned | vendor-neutral capability requirements |
| provider/model preference | forbidden as authority | #868 routing owner |
| depends_on[] | derived | edges[]から算出 |
| status / timestamps / retry_count | forbidden | RunState / event / RunEvidence owner |

## 4. Edge / Join

Edgeはstructureだけを所有する。

```yaml
from: WI-001
to: WI-002
condition_kind: dependency_satisfied | evidence_present | human_approved | external_event
condition_ref: null
```

- condition_kindはgate typeであり現在値ではない。
- runtime edge selectionはRunEvent fact。
- repair/replan/stop logicをedgeへ埋め込まない。

Joinはmember IDs / join policy / evidence requirement refsを宣言できるが、mutable completion stateやVerifier verdictを所有しない。

## 5. Assignment

Assignmentはimmutable。rebindは新Assignment + eventで表す。

| field | class | decision |
|---|---|---|
| assignment_id | owned | immutable logical identity |
| assignment_ref | derived/reference identity | payload外で算出・付与するimmutable ref。self-hash fieldにしない |
| supersedes_assignment_ref | referenced | rebind時 |
| graph_ref / work_item_id | referenced | WorkItemGraphへbinding |
| requested_capabilities[] | referenced/derived | Work item requirement |
| routing_decision_ref | referenced | #868 |
| provider / runtime / model | provenance | workflow authorityにはしない |
| context_refs[] | referenced | explicit subset |
| tool_policy_ref | referenced | Harness/policy |
| loop_contract_ref / budget_ref | referenced | LoopContract owner |
| run_id | referenced | #1025 logical identity。既知時のみ |
| run_state_ref | derived/reference | Assignment mutationを必要にするなら必須化しない |
| status | forbidden | #1025 / RunEvent |
| started_at / ended_at | forbidden | event / RunEvidence |

## 6. Runtime event semantics

V2 RunEventの最終field名はowner側で確定する。本計画では必要semanticだけ固定する。

- work item instantiated: graph_ref / approved template ID or parent work item / instance ID / inherited AC refs / narrowed scope / trigger evidence
- route selected: graph_ref / from / to / evidence-policy-human-external ref
- join satisfied: graph_ref / join ID / member evidence refs
- assignment bound/rebound: assignment ref / prior assignment ref
- graph superseded: old/new graph refs / new plan_hash / #894 replan decision ref

これらから effective runtime graph view を再生成する。projectionはmutable SSoTではない。

## 7. Fail-closed checks

1. V2 Lifecycle State enumをGraph-owned stateとして受理しない
2. Terminal OutcomeをGraph-owned outcomeとして受理しない
3. Stop ReasonをGraph-owned reasonとして受理しない
4. convergence decisionをGraph authorityとして受理しない
5. allowed_pathsのPlan scope拡大を拒否
6. depends_onとedgesの二重authorityを拒否
7. replanによる既存graph_ref in-place更新を拒否
8. runtime instance/routeにevent evidenceが無い場合はreconstruct不可として扱う
9. human_onlyをAI assignmentへbindしない
10. bounded dynamicにはapproved template allowlist + specialization field allowlist + parallel/budget refsを必須にする
11. dynamic instanceが新しいACを追加、またはtemplate/parent scopeを拡大したら拒否
12. content-addressed `graph_ref` / `assignment_ref` をartifact payload自身のself-hash fieldとして要求しない

## 8. Phase B handoff

Schema work開始条件:

- #1379がHuman-approved/merged、または同等の承認済みboundaryがある
- #1389 Intent Context Package の `context_id/context_ref` semantics（optional `snapshot_ref`）がfreezeされる、または明示的なcompatibility adapterが承認される — **充足済み**（根拠: #1390 / `89d98167` が #1389 Phase A「freeze `context_id/context_ref` semantics」として identity を確定し、#1396 / `35e9a55d` が `schemas/intent-context-package.schema.json` と `scripts/intent_context_contract.py` の `compute_context_ref` / `compute_snapshot_ref` として main に実装した）。#1389 が open なのは Phase E integration（#199 adapter / Plan binding / #1385 downstream）が残るためで、本条件の未充足を意味しない
- immutable declaration vs event stream境界が維持されている
- #1025 / #894 / #874 / #908とのowned conflictが0
- edges[]がdependency topologyの唯一のauthority
- Assignmentからmutable status/timestampsが除外済み
- runtime event semanticが合意済み（最終field名はowner側）
- dynamic instantiationがapproved template/parentのspecializationに限定され、新規AC・scope拡大を禁止している
- immutable artifact refの算出方式がpayload self-referenceを作らない
