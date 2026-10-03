# Production Feedback Loop — Runtime Evidence to Agent Work

> **Status**: ai-loop V2 design guide（non-canon）。正本は [`north-star.md`](./north-star.md) と companion canon。
> **Purpose**: Production で観測した failure / degradation / recurrence を、Human-owned authority を維持したまま、検証可能な Agent Work と Learn / Evolve の Evidence へ接続する。
> **Boundary**: 特定の observability vendor / incident tool / coding agent を前提にしない。Cloudflare Workers Issues は参考実装であり、依存先ではない。

## 1. Principle

Production feedback は「AI に本番障害を自動修復させる機能」ではない。

> **Convert production signals into bounded, evidence-bearing work.**

V2 へ取り込む対象は、特定製品の Issue UI ではなく次の 3 つの責務である。

1. **Production Feedback** — 本番で起きた事実を開発ループへ戻す
2. **Runtime Evidence** — 生 telemetry を、その出所・欠測・不確実性を保った調査可能な Evidence にする
3. **Event-triggered Agent Work** — 条件を満たした外部 event を、権限を増やさず bounded work の開始候補へ変換する

```text
Production
  -> Observe
  -> Detect / Group
  -> Runtime Evidence Package
  -> Trigger Policy
  -> Intake Adapter
  -> Delivery Work
  -> Verify
  -> MERGE_READY
  -> Human C-4 / Merge / Deploy
  -> Post-fix Observation
  -> Learn
  -> Evolve (only when a cross-run pattern justifies it)
```

Production signal の到着は **実装権限・承認・merge 権限を与えない**。既存の Contract / Policy / Human-owned boundary を通る。外部 event を active Run の Contract や Harness identity へ後付け注入せず、必要なら新しい bounded work / Run の入力として取り込む。

## 2. Responsibility boundary

| Concern | Responsibility | Existing owner / authority |
|---|---|---|
| Production signal の収集・grouping | External observability / provider adapter | 外部 system + adapter |
| signal を V2 が読める Evidence へ正規化 | Harness intake | Phase 1 RunEvent / Evidence owner |
| どの event を work 候補へするか | Trigger Policy | Phase 1 で owner を確定。approval / permission / security policy に触れる変更は既存の Human-owned 境界を維持 |
| issue 調査・修正を `MERGE_READY` へ収束 | Delivery Loop | [`north-star.md`](./north-star.md) |
| failure / recovery の記録 | RunEvent / FailureRecord / RunEvidence | [`artifact-responsibilities.md`](./artifact-responsibilities.md) |
| 複数 Run から改善候補を作る | Evolution Loop | [`north-star.md`](./north-star.md) |
| Production への merge / deploy / Harness promotion | Human | North Star §3 / §15 |

重要な分離:

```text
Production Incident != Harness Improvement Candidate
Signal Trigger       != Approval
Issue Group          != Root Cause
Agent Proposal       != Resolution
PR Created           != Production Recovered
```

単一障害から Skill / Agent / Flow / Verifier を直接変更しない。Harness 改善は RunEvidence / Retrospective / Pattern を経て、別 Candidate として評価する。

## 3. Runtime Evidence Package

外部 provider が持つ raw logs / traces / exception を、そのまま prompt に流し込むことを既定にしない。

```text
Raw telemetry
  -> detection
  -> grouping / fingerprinting
  -> provenance + context reduction
  -> Runtime Evidence Package
  -> Agent
```

最低限、次を表現できる必要がある。

- observation: 実際に観測した failure / degradation
- first_seen / last_seen: provider が供給できる場合の観測時刻
- source: observability / incident provider と取得経路
- source_ref: raw evidence へ辿れる参照
- failure_fingerprint: 同一原因候補をまとめる識別子
- occurrence / trend: 発生数・増減。provider が供給する場合のみ
- deployed_artifact_ref: version / commit / deployment identifier
- diagnostic_refs: logs / traces / stack trace / request evidence
- application_context_refs: 調査に必要な場合のみ、user / account / session 等を直接値ではなく opaque ref 等で安全に参照するための情報
- missing_evidence: 欠けている情報
- uncertainty: grouping / cause 推定の不確実性
- sanitization: redaction / omission の実施情報

これは **informative shape** であり、新しい SSoT / schema をこの文書で作らない。Phase 1 の RunEvent / FailureRecord / Evidence contract の owner が最終フィールドを決める。

### Evidence rule

- grouping は原因確定ではない。fingerprint は「同一原因候補」であり root cause と同一視しない。
- provider の summary と raw evidence ref を分ける。
- timestamp を生成側の都合で捏造しない。供給不能なら unavailable とする。
- 観測できない値を `0` / empty success として埋めない。
- Agent の「直った」は Evidence ではない。

## 4. Trigger Policy

Event-driven で Agent を起動する場合も、全 signal を即実装へ流さない。

Trigger は少なくとも次の入力を扱えること。

- occurrence threshold
- recurrence after a quiet period
- severity / affected surface
- deployment correlation
- duplicate / already-open work
- stable intake identity（provider retry / webhook redelivery を同一 work へ収束させるための識別）
- cooldown / debounce
- budget / concurrency / burst limit
- circuit-break / backpressure condition
- policy boundary
- required evidence availability

```text
Runtime Evidence Package
  -> deterministic filters
  -> dedupe / cooldown
  -> Trigger Policy
  -> enqueue bounded work OR notify / escalate / ignore-with-record
```

優先順位:

1. deterministic rule
2. explicit policy
3. independent classification when deterministic rule aloneでは足りない
4. Human escalation

LLM の判断だけで permission / approval boundary を変更しない。Trigger Policy 自体の変更も、既存の policy governance と North Star §3 / §15 の authority 境界に従う。

大量発生時も「signal 数 = Agent 数」にしない。budget / concurrency / burst limit を超えた場合は、新しい work の生成を抑止・集約し、必要なら Human / incident path へ escalate する。provider outage や instrumentation bug による storm を Agent swarm へ変換しない。

### Trigger outcome

Trigger の結果は「Agent に本番修正権限を与える」ではなく、次のいずれかに限定する。

- bounded investigation を開始する
- Delivery work の作成候補を作る
- Human / incident channel へ通知する
- evidence 不足として追加観測を要求する
- duplicate として既存 work に関連付ける
- policy 上の理由で開始しない

## 5. Intake Adapter

Provider integration は V2 core へ provider 固有 semantics を漏らさない。

```text
Cloudflare / Sentry / Datadog / OpenTelemetry / other
                    |
                    v
             Provider Adapter
                    |
                    v
       Runtime Evidence / Trigger Input
                    |
                    v
              ai-loop V2
```

Adapter の責務:

- provider payload の検証
- provenance の保持
- stable fingerprint / provider issue ID の保持
- provider retry / webhook redelivery を新規 work の重複作成へ変換しない intake idempotency
- secret / PII / high-cardinality payload の redaction
- size / context budget 制御
- replay 可能な fixture 化
- provider 固有の retry / webhook delivery semantics の隔離

Adapter は次をしない。

- root cause を権威的に確定する
- acceptance criteria を変更する
- Human-owned approval を生成する
- Production deploy を行う
- Harness を live self-modify する

## 6. Delivery connection

Production issue から Delivery を開始する場合も、既存の Plan / Verification contract を省略しない。

```text
Runtime Evidence
  -> Investigation
  -> Problem statement / scope
  -> Plan
  -> Plan Verification
  -> Build
  -> Verify
  -> PR Convergence
  -> MERGE_READY
```

緊急度が高いことは、Evidence / Verifier / scope 制約を弱める理由にならない。緊急対応用 profile を作る場合も、変更可能な budget / review depth と、変更してはいけない authority / safety boundary を分離する。

Agent が追加 telemetry を問い合わせる場合は、tool permission と read scope を Harness 側で制限し、問い合わせ結果も provenance 付き Evidence として扱う。

## 7. Resolution and post-fix observation

PR が作成されたこと、test が PASS したこと、merge されたことだけでは Production issue の解消を意味しない。

最低限、次を分離する。

```text
Code Fix Verified
  !=
Deployment Completed
  !=
Production Recovery Observed
  !=
Recurrence Prevented
```

Post-fix observation は external evidence として Learn へ返す。**terminal になった Delivery Run の event stream へ後付け append しない**。現行 V2 は terminal transaction を Run の final とし、後続 commit を拒否するため、deploy / recovery / recurrence は Run 外の external observation または後続 work / Run として関連付ける。永続化の最終 owner / schema は Phase 1 で確定し、この文書では第2の mutable SSoT を作らない。

再発は Run 横断なので、[`artifact-responsibilities.md`](./artifact-responsibilities.md) §6 のとおり個別 RunEvidence の mutable 集計値にはしない。

## 8. Security / privacy boundary

Production telemetry は開発時 Evidence より機微情報を含みやすい。

必須原則:

- token / credential / cookie / authorization header を Agent context へ渡さない
- request / response body は既定で raw 転送しない
- user / account / session の直接識別子を既定で Agent context に入れない。必要な場合も用途・保持期間・アクセス権を明示し、opaque ref 等で最小化する
- raw telemetry は必要最小限を参照し、Human-facing artifact へ複製しない
- provider webhook は署名検証・replay 対策・idempotency を持つ。再送は同じ bounded work へ収束させ、同一 signal から複数 Run を無条件に生成しない
- external tool query は least privilege / read-only を既定とする
- context reduction で Evidence provenance を失わない

> **Context reduction must not become evidence laundering.**

## 9. Cloudflare Workers Issues as a reference implementation

Cloudflare は 2026-09-30 に Workers Issues を公開し、repeated exceptions / 5xx / error logs を group し、error・stack trace・logs・traces・Worker version 等を coding agent へ渡し、occurrence threshold や quiet period 後の再発を trigger に Agent workflow を起動できる構成を示した。Agent は追加 telemetry を問い合わせ、code / test change と PR を提案できる一方、Production へ入れる判断は Human review / deploy に残している。

PlanGate が取り込むのは製品機能ではなく、次の一般化された pattern である。

```text
Detect
 -> Group
 -> Contextualize
 -> Trigger
 -> Investigate
 -> Change
 -> Verify
 -> Human-controlled Production
 -> Observe again
```

Reference:

- https://blog.cloudflare.com/real-time-issue-detection/

## 10. Rollout slices

Production feedback をいきなり Production auto-remediation として接続しない。

**North Star §17 の release boundary を優先する。** Delivery V2 が要求する E2E（Verify FAIL -> Diagnose -> Repair -> Verify PASS -> PR convergence -> `MERGE_READY`、および `NO_PROGRESS` の safe stop / escalation）が安定する前に、Production signal を Agent の実行 trigger として接続しない。先行してよいのは fixture / offline replay / redaction / normalization / dedupe 等の Evidence intake 検証までとする。

### Slice A — Evidence intake only

- provider payload fixture を作る
- redaction / validation / dedupe / retry idempotency を検証する
- burst / malformed / unsigned payload の negative control を持つ
- Agent は起動しない

### Slice B — Investigation only

- **Delivery V2 の release boundary 通過後**に Production trigger を有効化する
- trigger で read-only investigation を開始する
- code change は提案まで
- false-positive / duplicate / missing-evidence を測る

### Slice C — Delivery handoff

- bounded Delivery work を作る
- normal Plan / Verify / PR convergence を通す
- Production merge / deploy は Human-owned

### Slice D — Closed feedback

- deployment と post-fix observation を Evidence として接続する
- recurrence / recovery / Time to Learning を Run 横断で評価する
- Harness 改善は Evolution Candidate として別 loop で扱う

## 11. Minimum verification matrix

Provider adapter / Trigger Policy を実装するときは、少なくとも次を fixture / test で検証する。これは schema の正本ではなく、将来実装の受入観点である。

| Case | Expected |
|---|---|
| 同じ provider delivery を複数回受信 | 同じ intake identity に収束し、新規 work を重複生成しない |
| 同じ fingerprint だが deployment / evidence が異なる | root cause 同一と断定せず、既存 work への関連付け可否を policy で判定する |
| webhook signature 不正 / replay 不正 | reject。Agent を起動しない |
| payload に token / cookie / authorization header | redaction / rejection が成立し、Agent context / Human-facing artifact に残らない |
| required evidence が unavailable | 成功扱いにせず、追加観測・notify・escalate のいずれかへ fail-closed |
| threshold 未満 | Delivery work を作らない |
| threshold 境界を超える | policy が許す bounded work だけを作る |
| burst / storm が budget を超える | concurrency を増やし続けず、集約・抑止・escalate |
| Agent が root cause を断定するが Evidence 不十分 | hypothesis として保持し、verified fact に昇格しない |
| fix PR が作成された | Production recovery を宣言しない |
| terminal Delivery Run 後に recovery signal 到着 | terminal Run へ append せず、external observation / follow-up として扱う |
| same input fixture を再実行 | normalization / redaction / trigger 判定が決定論的に再現する |

North Star §21 の negative control / regression / deterministic verifier の要求を、この境界でも維持する。

## 12. Required review questions

Production feedback を扱う Plan / PR は、North Star §21 に加えて次を確認する。

- signal は観測事実か、provider / Agent の推論か
- grouping と root cause を混同していないか
- raw telemetry を必要以上に Agent context へ入れていないか
- trigger が approval / permission grant に化けていないか
- duplicate / recurrence / cooldown / burst / backpressure を扱えるか
- provider outage / webhook retry / replay で work が重複しないか。stable intake identity で既存 work へ収束できるか
- Evidence 不足時に fail-open していないか
- PR 作成を Production recovery と誤認していないか
- post-fix observation を terminal Run へ後付けせず、Run 外の Evidence / 後続 work として扱っているか
- post-fix observation の返却先があるか
- 単一 incident から Harness を live self-modify していないか

## 13. Non-goals

- vendor-specific incident management platform の再実装
- raw telemetry lake の構築
- Production auto-merge / auto-deploy
- incident severity / SLO / on-call policy 全体の所有
- Product Discovery 全体の orchestration
- 単一 incident からの即時 Harness 自己変更
- Provider Issue を V2 の新しい authoritative artifact にすること
