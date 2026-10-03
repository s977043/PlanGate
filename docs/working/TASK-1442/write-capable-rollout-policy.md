# TASK-1442 — PBI write-capable rollout policy

> Policy version: `pbi-write-rollout/v1`
>
> Status: **DRAFT / NON-ACTIVE**
>
> この文書は、将来の PBI write-capable adapter をレビュー可能にするための
> rollout policy を定義する。**automatic PBI mutation を有効化するものではない。**
>
> 現在の effective mode:
>
> ```text
> rollout_mode = shadow_only
> write_allowed = false
> automatic_mutation_allowed = false
> ```

## 1. Purpose

PBI materializer は既に次を分離している。

```text
admission
  -> materialize | no_action | discover_more

materialization
  -> create_new | update_existing | link_only
```

しかし、分類が正しくても write は安全とは限らない。

write-capable rollout は少なくとも次を独立に満たす必要がある。

```text
Evidence quality
Authority
Target mutability
Concurrency
Idempotency
Rollback
Version / freshness binding
Explicit activation
```

**単一の accuracy threshold だけで write を解放してはならない。**

## 2. Non-goals

本 policy は以下を行わない。

- write adapter の実装
- `pbi_materializer.py` への write authority 付与
- Issue close / merge / RunState / Harness mutation の許可
- 新しい PBI lifecycle state / registry / database / Gate の追加
- historical / synthetic case の production live evidence 化
- `write_review_ready=true` の mutation permission 化
- live observation が不足した状態での数値閾値の決定
- fuzzy similarity による target 自動選択
- bound / approved PBI の silent semantic rewrite

## 2.1 Policy identity

将来の activation は「最新 policy」や file path だけを参照してはならない。

activation decision は最低限:

```text
policy_version = pbi-write-rollout/v1
policy_ref = docs/working/TASK-1442/write-capable-rollout-policy.md
policy_sha256 = sha256:<exact content bytes>
activation_decision_ref = <repository-visible decision ref>
enabled_mutation_kinds = [...]
```

を固定する。

`policy_sha256` は activation decision を書く直前の policy bytes から計算し、
writer は write attempt ごとに現在の policy bytes を再計算して一致を確認する。

```text
current_policy_sha256 != activated_policy_sha256
  -> write forbidden
  -> new review / activation decision required
```

policy file の編集は既存 activation authority を暗黙継承しない。
version文字列が同じでも byte hash が変われば再activationを要求する。

mutation attempt の idempotency identity には
`policy_version` だけでなく activated `policy_sha256` も含める。

## 3. Rollout stages

rollout stage は capability の段階であり、PBI lifecycle state ではない。

| Stage | Capability | Current |
| --- | --- | --- |
| R0 Shadow | proposal / evaluation only | **ACTIVE** |
| R1 Human-applied | adapter が mutation plan/diff を生成し、Human が明示実行 | NOT ACTIVE |
| R2 Policy-authorized low-risk write | policy で許可された低リスク mutation を adapter が実行 | NOT ACTIVE |
| R3 Broader automation | evidence に基づき対象を拡張 | NOT DEFINED |

R1/R2 への移行は本 document の activation prerequisites を満たし、
別の明示 decision で有効化するまで禁止する。

## 4. Decision-specific mutation boundary

### 4.1 link_only

許可候補となり得る mutation:

- existing PBI の semantic fields を変更しない
- provenance / evidence ref の append のみ
- duplicate ref の再追加は idempotent no-op
- Issue close / resolve / suppress はしない

write 時にも対象 PBI の semantic hash が評価時点から変わっていないことを確認する。

### 4.2 create_new

許可候補となり得る mutation:

- 新規 PBI artifact の作成のみ
- existing PBI の本文変更なし
- write 直前に Reuse / Update Before Create を再評価
- equivalent open work が現れた場合は write を停止し再評価
- deterministic target path / identifier を使い retry で duplicate を作らない

### 4.3 update_existing

最も高リスクとして扱う。

- full replacement 禁止
- `semantic_patch_proposal` の field-level patch のみ
- target の exact version/hash を write precondition にする
- 評価後に target が変化していたら fail closed
- bound / approved semantics への変更は既存 Replan authority へ route
- Human / policy が認めていない semantic field は変更しない
- title / Goal / Problem / Requirement / AC の authority を write adapter が再定義しない

初期 write-capable rollout では `update_existing` を R2 自動 mutation の対象外としてよい。
解除には別 decision を要求する。

## 5. Activation prerequisites

R1/R2 を有効化するには、少なくとも以下が必要。

### 5.1 Dependency / repository health

- design dependency #1441 が merged または明示的に finalized
- 対象 head の full repository Test が green
- plugin distribution / privacy / Issue-link checks が green
- write adapter 自身が repository test で fired される
- source/plugin distribution drift がない

### 5.2 Real live-shadow evidence

対象 decision class について:

- repository-tracked live-shadow chain が存在
- admission / materialization oracle が reviewed expectation として束縛済み
- invalid case artifact が未解消のまま残っていない
- evaluator error を success 分母から黙って除外していない
- synthetic / historical evidence を live evidence と数えていない
- maker actual を ground-truth coverage として数えていない

固定件数 quota は定めない。観測が不足している decision class は **未評価** とする。

### 5.3 Quality review

Human / rollout policy が少なくとも次を確認する。

- duplicate false-positive / false-negative
- admission false-positive / false-negative
- decision mismatch
- matched-ref mismatch
- readiness mismatch
- provenance rejection distribution
- evaluator error / unevaluable case

```text
quality_thresholds_applied = false
quality_acceptance_decided = false
```

の間は write activation 不可。

数値閾値は real live observations を確認した別 decision で決める。

### 5.4 Authority review

mutation 前に必ず再確認する。

- PBI semantic authority
- approval / binding state
- Replan requirement
- target layer
- source provenance
- acceptance basis authority
- Human-owned boundary

write adapter は authority を自己発行しない。

## 6. Optimistic concurrency

write は **read -> decide -> compare -> write** の間の競合を前提にする。

最低限:

```text
evaluated_target_ref
evaluated_target_hash
proposal_hash
write_policy_version
write_policy_sha256
activation_decision_ref
adapter_version
```

を mutation plan に束縛する。

write 直前に target を再読込し:

```text
current_target_hash == evaluated_target_hash
```

を満たさなければ mutation せず再評価する。

GitHub 等の remote adapter を使う場合は、可能なら expected SHA / version / ETag 等の
provider-native optimistic concurrency を併用する。

### 6.1 Mutation surface

初期 write-capable slice は:

```text
one mutation attempt = one semantic target
multi-target transaction = unsupported
```

とする。

mutation plan は最低限:

```text
target_ref
mutation_kind
allowed_mutation_paths
forbidden_paths
evaluated_target_hash
proposal_hash
```

を持つ。

adapter は `allowed_mutation_paths` 外を書き換えてはならない。

特に同一 mutation attempt から以下を変更することを禁止する。

- rollout policy
- oracle / reviewed expectation
- source evidence
- RunEvidence
- capture / review packet
- evaluator report
- approval / decision authority
- RunState / LoopContract / HarnessManifest

writer が自身の Evidence / policy / approval を同時に書き換えられる構造を作らない。

### 6.2 Partial / unknown result

provider API / filesystem operation の結果は:

```text
confirmed_success
confirmed_not_applied
unknown
```

として扱う。

`unknown` は成功/失敗へ推測で寄せない。

例:

- request timeout
- connection drop after send
- provider response parse failure
- post-write read-back unavailable

`unknown` の場合:

```text
automatic_retry_allowed = false
reconciliation_required = true
human_escalation_required = true
```

とする。

再試行前に provider-native identity / target ref で対象を再読込し:

1. intended mutation が既に存在 -> idempotent success / no-op として再評価
2. mutation が存在せず precondition も同一 -> retry-safe 候補
3. target version/hash が変化 -> conflict / fail closed
4. 状態を判定不能 -> Human escalation 継続

とする。

## 7. Idempotency

retry は duplicate mutation を作ってはならない。

mutation attempt は少なくとも次から deterministic idempotency identity を導出する。

```text
target_ref
evaluated_target_hash
proposal_hash
write_policy_version
write_policy_sha256
activation_decision_ref
mutation_kind
```

同じ identity の retry:

- 同一結果なら reuse / no-op
- 異なる結果なら fail closed

`create_new` では deterministic target identity を使い、
retry による PBI 二重作成を防ぐ。

## 8. Freshness / TOCTOU

shadow evaluation が過去に green だったことだけでは write しない。

write attempt ごとに:

1. source refs を再解決
2. target を再読込
3. binding / approval state を再確認
4. Reuse / Update Before Create を再実行
5. materialization decision を再計算
6. proposal hash を再確認
7. concurrency precondition を確認

の順で freshness を確認する。

評価時と write 直前で decision が変わった場合は write を中止する。

## 9. Rollback

write-capable adapter は実行前に rollback 方法を示す。

最低限:

- create_new: 作成 artifact を特定可能。ただし自動 delete/close は別 authority
- link_only: append 前状態を復元可能な patch / inverse を保持
- update_existing: exact pre-write content/hash と inverse patch を保持

rollback artifact は mutation success の証拠とは別に保存し、
「rollback可能」という申告だけで reversible とみなさない。

## 10. Post-write verification

write成功判定は provider API / filesystem call の成功だけでは成立しない。

write 後に対象を再読込し:

- intended patch が反映された
- unintended semantic fields が変わっていない
- target hash/version が期待どおり進んだ
- PBI schema / privacy / provenance validation が通る

ことを verifier が確認する。

```text
Writer != Post-write Verifier
```

を維持する。

## 11. Activation authority

本 policy file の存在だけでは rollout stage は変わらない。

activation は別の repository-visible decision により:

```text
from_stage
to_stage
enabled_mutation_kinds
policy_version
policy_sha256
policy_ref
activation_decision_ref
evidence_refs
known_limits
rollback_owner
chosen_by
```

を固定する。

少なくとも初回 activation は Human-owned とする。

adapter / materializer / evaluator は自身の評価結果を根拠に
自分で rollout stage を昇格させてはならない。

## 12. Fail-closed conditions

以下では write を実行しない。

- dependency / Test / policy version が未確認
- target hash/version drift
- ambiguous existing-work match
- duplicate top match
- invalid live-shadow evidence
- unresolved evaluator error
- required oracle/review missing
- authority ref 不正
- bound semantic update なのに Replan 未成立
- rollback plan 不明
- adapter/version mismatch
- multi-target mutation attempt
- mutation surface / allowed path violation
- provider result が unknown のまま自動 retry
- write decision が shadow evaluation と不一致
- decision class が未activation
- policy interpretation が曖昧

## 13. Current decision

本 document の追加時点では:

```text
effective_stage = R0 Shadow
R1_enabled = false
R2_enabled = false
automatic_mutation_allowed = false
```

#1442 の write-capable rollout policy AC は「policy を定義・レビューした」ことで進められるが、
実 write activation は以下と分離する。

```text
policy definition
!= write adapter implementation
!= rollout activation
!= quality acceptance
```
