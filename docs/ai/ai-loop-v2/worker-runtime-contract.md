# Worker Runtime Contract — Disposable Worker / Durable Run

> **Status**: Phase 1A Architecture / Contract draft（#1369）
> **Parent**: #1368
> **Runtime canary**: #1370
> **Canon dependencies**: [North Star](./north-star.md) / [Artifact Responsibilities](./artifact-responsibilities.md) / [Taxonomy](./taxonomy.md) / [HarnessManifest](./harness-manifest.md)
> **Source pattern**: https://x.com/polydao/status/2102328801531150718

## 1. Purpose

ai-loop V2 で、Claude Code subscription を最初の実証 backend とする **交換可能な Worker Runtime** の責務境界を固定する。

この契約の中心原則は次の 1 点である。

> **Worker process is disposable. Run continuity belongs to durable state and evidence.**

Agent process、conversation history、TTY、GitHub Actions runner、persistent workspace の生存を Run 継続性の前提にしない。

本書は Architecture / Contract design であり、production workflow、V2 schema、runtime script を実装しない。

## 2. Non-goals

本 Phase 1A では次を行わない。

- `.agent-runtime/`、`checkpoint.json`、Worker 専用 DB の新設
- raw conversation transcript / hidden chain-of-thought の保存
- Claude 固有 error text を V2 core taxonomy に直接追加
- API / WIF への silent billing fallback
- Claude Code → Codex CLI の直接 fallback
- scheduler / cron / 24x365 daemon
- persistent self-hosted runner
- C-3 / C-4 / merge authority の変更
- auto merge
- River Review の Review Resolution を Worker Runtime へ取り込む

## 3. Responsibility boundary

| Concern | Owner | Worker Runtime の責務 |
| --- | --- | --- |
| acceptance criteria / allowed scope / budget / required verifier | **LoopContract** | 読み取り・強制する。拡張しない |
| lifecycle / revision / pending action / binding | **RunState (#1025)** | 次の安全な attempt に必要な入力として消費する |
| execution attempt facts | **RunEvent stream** | attempt の観測事実を emit する |
| normalized execution failure | **FailureRecord** | provider 固有 detail を境界で正規化して渡す |
| verification | **VerificationResult** | Worker の自己申告と分離する |
| continue / repair / replan / stop | **Decision Engine (#894)** | 決めない |
| run-level summary | **RunEvidence (#874)** | mutable log を持たず projection へ材料を渡す |
| harness/runtime identity | **HarnessManifest** | `harness_manifest_ref` を binding として消費する |
| review judgment / coverage / resolution | **River Review** | diff / tests / evidence refs を渡すだけ |
| Human approval / merge | **Human-owned boundary** | 実行しない |

### Artifact budget rule

Worker Runtime を理由に新しい top-level artifact を初手で追加しない。

新 artifact が必要だと主張する場合は、既存 artifact へ additive に表現できない具体 fixture、lifetime / mutability の差、North Star 上の必要性を先に示し、artifact budget review を通す。

## 4. Preflight contract

Provider を呼ぶ前に、少なくとも次を fail-closed で検証する。

1. `run_id` / task identity が解決可能
2. `source_sha` / `plan_hash` / `harness_manifest_ref` が RunState と一致
3. pending action が current revision に束縛されている
4. allowed scope / branch / write boundary が解決可能
5. timeout / max-turns が明示されている
6. backend / auth class が一意
7. billing policy が一意
8. conflicting auth configuration が無い
9. Worker が要求された capability を勝手に拡張していない

不明・欠損・binding mismatch は provider call 前に停止する。

## 5. Derived execution view

Worker invocation のために次の **derived view** を組み立ててよい。ただし、新しい mutable SSoT として保存しない。

```yaml
run_id:
task_id:
run_state_revision:
source_sha:
plan_hash:
harness_manifest_ref:
pending_action:
runtime:
backend:
auth_class:
billing_mode:
execution_bounds:
  timeout_seconds:
  max_turns:
effective_capabilities:
  allowed_paths:
  write_mode:
  network:
  secret_classes:
  branch_policy:
```

導出元:

- task / acceptance / allowed scope / budget / paid-fallback permission / execution bounds: LoopContract
- revision / binding / pending action: RunState
- runtime / routing-policy / policy-profile identity: HarnessManifest
- selected backend / auth class / availability: approved policyを満たした attempt-time observation

Worker の local configuration や environment variable は authority ではない。既存 contract / manifest を満たすかを検証する入力に限る。

**derived view 自体に新しい authority を持たせない。**

### Active-run immutability

Run 開始後に Worker local config が変わっても、approved policy を暗黙変更してはならない。

- paid fallback permission / budget / execution bounds は active Run 中に拡張しない
- routing / policy identity は `harness_manifest_ref` が指す内容から drift させない
- environment 差分が approved policy と矛盾する場合は provider call 前に fail
- policy を変更して続行したい場合は、既存の Replan / new revision / new Run 境界を通す

attempt-time observation（選ばれた backend、auth class、availability）は Event / FailureRecord に残せるが、それ自体が policy を書き換える根拠にはならない。

## 6. Authentication / billing invariant

### Subscription-only Worker

Claude Code subscription の最初の vertical slice では auth surface を exactly one にする。

```text
CLAUDE_CODE_OAUTH_TOKEN = present
ANTHROPIC_API_KEY       = absent
WIF federation inputs   = absent
```

次は dispatch 前に拒否する。

- OAuth token が無い
- subscription-only なのに API key が存在する
- static credential と federation input が混在する
- paid fallback が policy で許可されていないのに API backend が要求される

Credential value は artifact / log / RunEvidence へ保存しない。

### Cross-runtime

Claude Code → Codex CLI は Worker fallback ではない。

```text
Router re-evaluation
  -> Prompt Compiler / Runtime Adapter
  -> target runtime Worker
```

を通す。

## 7. Capability enforcement

`.mcp.json` 等の host-specific file を Core Contract にしない。

effective capability boundary は既存 owner から解決する。

- LoopContract: allowed scope / budget / required verifier
- HarnessManifest: policy profile / runtime identity / activated components
- Worker Runtime: runtime-specific tool / write / secret / branch restrictions

Worker はこの境界を **狭めることはできるが広げられない**。

Phase 1A では独立した `CapabilityPolicy` artifact を追加しない。fixture で既存 owner では曖昧になることが実証された場合のみ再検討する。

## 8. Intent / attempt / receipt semantics

外部副作用の exactly-once 相当制御は #1025 の intent / receipt と revision CAS を再利用する。

### Identity

- **action_id**: Run が要求する外部 action の stable identity。#1025 が所有する
- **attempt_id**: 1 回の bounded execution attempt の identity。RunEvent / FailureRecord の観測用であり RunState の代替ではない

原則:

1. intent を durable にした後でだけ external execution を dispatch する
2. dispatch には、外部 control plane が対応する場合は `action_id` に束縛された idempotency / correlation key を必ず渡す
3. dispatch 前 crash は同じ `action_id` から安全に再開できる
4. dispatch の成否が不明な crash では、外部 control plane から「未実行」を一意に証明できる場合だけ自動 redispatch してよい
5. 外部 control plane が idempotency key / execution identity / queryable status を提供せず、実行有無を証明できない場合は自動 redispatch せず Human reconciliation へ倒す
6. external side effect 完了後は action / attempt に束縛された receipt が duplicate dispatch を止める
7. retry は Decision Engine が retry を選んだ後だけ新 attempt として作る
8. Worker process の「完了しました」という自己申告だけでは receipt 完了・Run success にしない
9. receipt に raw model transcript を保存しない

### Minimum observable attempt facts

attempt から残す情報は必要最小限にする。

- action / attempt identity
- backend / auth class（credential value なし）
- bounded start / finish / interruption の観測
- source / head binding
- normalized failure observation
- validation / evidence refs
- sanitized output ref（必要な場合のみ）

## 9. Resume semantics

再開時、独立した reader は conversation history を読まずに次の安全な action を判断できなければならない。

```text
RunState(revision N)
+ pending action / receipt
+ Worker-related RunEvent / FailureRecord
+ immutable bindings
=> next safe action or fail-closed stop
```

### Resume rules

- state revision が stale → `STATE_CONFLICT`
- source / plan binding が stale → provider call 前に拒否
- receipt 済み external action →再実行しない
- intent あり receipt 無し → external controller evidence を確認してから再 dispatch 可否を決める
- controller evidence が取得不能 → success に倒さない
- malformed / unknown attempt result → success に倒さない
- persistent agent memory が無いと再開できない設計は invalid

## 10. Crash windows

| Window | Durable evidence | Required behavior |
| --- | --- | --- |
| W1: intent 前に crash | action 未発行 | 同じ approved binding から新しい intent を作れる |
| W2: intent 後・dispatch 前に crash | intent あり / receipt 無し | 同じ action を再利用。intent を増殖させない |
| W3: dispatch 後・開始確認前に crash | intent あり / controller state 不明 | action に束縛された controller evidence を照合。「未実行」を証明できる場合のみ redispatch。証明不能なら Human reconciliation |
| W4: execution 中に crash | started evidence あり / finish 無し | interrupted/unknown として fail-closed。success 禁止 |
| W5: external side effect 後・receipt 前に crash | controller 側完了 / local receipt 無し | action / attempt に束縛された controller evidence から receipt reconciliation。duplicate side effect 禁止 |
| W6: receipt 後・RunState CAS 前に crash | receipt あり / revision N | resume で receipt を再消費せず state transition を再評価 |
| W7: concurrent resume | 2 writer が revision N | 1 writer のみ CAS 成功。残りは `STATE_CONFLICT` |
| W8: stale binding で resume | source / plan mismatch | provider call 前に拒否 |

## 11. Failure normalization

Provider 固有 error string を Decision Engine の contract に直接流さない。

Phase 1A で観測対象とする意味カテゴリ:

- auth configuration invalid
- auth failed
- capacity exhausted
- backend unavailable
- execution timeout
- execution failed
- scope violation
- output invalid / missing

**この表は Core Stop Reason の追加ではない。**

Adapter が安定した signal を得られない場合、推測して細分類せず unknown/inconclusive な FailureRecord と evidence ref に倒す。

### Attempt failure != Run outcome

```text
Worker attempt failed
  -> FailureRecord / evidence
  -> Decision Engine
  -> continue | repair | replan | stop
```

Worker adapter 自身が `MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` を決めない。

## 12. Cancellation / timeout

### Timeout

timeout / max-turns は dispatch 前の必須条件とする。

timeout が観測された attempt は成功扱いしない。既存 taxonomy へ写像可能な場合のみ Decision Engine が正式な Stop Reason を決める。

### Explicit cancellation

GitHub Actions / operator 等による explicit cancellation は **attempt-level observation** とする。

Phase 1A では新しい Core Stop Reason を先に作らない。

- cancellation 後に missing output を success とみなさない
- 次回 resume は controller evidence と durable state を照合する
- exact terminal mapping を既存 taxonomy で意味を壊さず表現できない場合、canary は Human handoff / non-advancing で停止する
- autonomous scheduler を導入する前に provider-neutral な terminal mapping の要否を別途決める

つまり「kill できる」ことより **kill 後に誤って成功しない・二重実行しない**ことを先に保証する。

## 13. Scheduler boundary

scheduler は Run continuity の owner ではない。

将来導入する scheduler / condition watcher は:

1. durable state を読む
2. dispatch eligibility を確認する
3. bounded Worker attempt を起動する
4. attempt evidence を残す

だけを行う。

scheduler 自体に conversation memory / mutable Run SSoT / approval authority を持たせない。

**#1370 Stage A + Stage B が成立するまで scheduler 実装を開始しない。**

## 14. River Review boundary

```text
PlanGate Worker
  -> diff / tests / evidence refs
  -> River Review
  -> findings / coverage
  -> Review Resolution
  -> Organizer / Human Decision Surface
```

River Review は Worker attempt lifecycle、auth/capacity、retry policy、RunState revision/CAS を所有しない。

River Review の `plugin-task-checkpoint-hook.sh` は review trigger adapter であり、PlanGate Durable Run State の checkpoint ではない。

## 15. Phase 1A fixture specification

production harness を作る前に、少なくとも以下を executable fixture へ落とせる形で仕様固定する。

| ID | Scenario | Expected |
| --- | --- | --- |
| WR-01 | valid subscription-only config | derived view が一意に解決 |
| WR-02 | OAuth missing | provider call 前に fail |
| WR-03 | subscription-only + API key present | conflicting auth として fail |
| WR-04 | paid fallback requested / denied | provider call 前に fail |
| WR-05 | stale `plan_hash` / `source_sha` | provider call 前に fail |
| WR-06 | timeout / max-turns missing | invalid contract |
| WR-07 | crash after intent before dispatch | intent 増殖なし・同じ action から resume |
| WR-08 | external completion before local receipt | action-bound controller evidence で reconcile・duplicate side effect なし |
| WR-08b | dispatch state unknown + controller cannot prove not-run | auto redispatch 禁止・Human reconciliation |
| WR-09 | concurrent resume | exactly one CAS / loser = `STATE_CONFLICT` |
| WR-10 | unknown / malformed Worker result | success 不可 |
| WR-11 | cancelled execution | non-advancing / missing output を success 扱いしない |
| WR-12 | raw secret/transcript appears in persisted evidence | validation fail |
| WR-13 | Worker requests wider write/tool scope | dispatch 前に fail |
| WR-14 | cross-runtime target requested | direct fallbackせず reroute requirement |
| WR-15 | clean runner resume | persistent workspace / conversation なしで next action を導出可能 |
| WR-16 | worker config / environment drift widens billing, timeout, scope or backend permission | provider call 前に fail。policy変更はReplan/new revision境界へ |

## 16. Phase 1A exit criteria

#1369 を Exit とできる条件:

- [ ] responsibility matrix が existing V2 artifact owner と重複しない
- [ ] new top-level Worker artifact を追加していない
- [ ] subscription-only auth / billing invariant が固定されている
- [ ] active-run worker policy immutability が固定され、local config が authority にならない
- [ ] effective capability boundary の owner が固定されている
- [ ] intent / attempt / receipt / CAS の責務分離が固定されている
- [ ] W1-W8 crash window が定義され、W3/W5 が外部 controller evidence の信頼境界を持つ
- [ ] WR-01〜WR-16 + WR-08b を実装可能な fixture specification として説明できる
- [ ] cancellation / timeout が fail-open しない
- [ ] raw transcript / hidden CoT / credential を永続化しない
- [ ] persistent Worker / workspace が Run SSoT でない
- [ ] River Review が Worker lifecycle を所有しない
- [ ] scheduler が #1370 後に defer されている
- [ ] Human-owned C-3 / C-4 / merge 境界が不変

## 17. Phase 1B handoff

Phase 1A 後は #1370 へ進む。

```text
Stage A
read-only subscription canary
  -> auth / bounds / sanitized evidence / failure signals

Stage B
low-risk bounded builder
  -> source + plan binding
  -> bounded write
  -> deterministic validation
  -> River Review input
  -> clean-runner resume / crash fixture
```

Stage A / B の両方が再現可能になるまで、scheduled unattended execution を「完成」とみなさない。

## 18. Phase 1A start-condition remeasurement

2026-09-23 の #1369 着手時点で、`phase0-migration.md` §7 の I4 移行条件を再測定した。

- **M-1**: canon-derived schema / canon vocabulary in `schemas/` — baseline 維持
- **M-2**: `scripts/ai-loop-v2` / `bin/ai-loop-v2` — 未出現
- **M-3**: canon vocabulary in execution surfaces — baseline の既知 4 files のみ
  - `scripts/ai-loop/corpus_hash.py`
  - `scripts/ai-loop/run_evidence.py`
  - `scripts/ai-loop/test_corpus_hash.py`
  - `scripts/ai-loop/test_run_evidence.py`

本 PR は Architecture / Contract docs のみを追加し、canon 7 本、schema、V2 runtime namespace、production workflow を変更しない。したがってこの差分自体では I4 移行条件を発火させない。
