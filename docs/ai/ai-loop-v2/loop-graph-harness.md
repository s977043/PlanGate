# ai-loop V2 — Loop / Graph / Harness Responsibility Model

> **Status**: ai-loop V2 の責務解釈ガイド。正本は [`north-star.md`](./north-star.md) と companion canon であり、本書はそれらに従属する。
> **Purpose**: Loop / Graph / Harness の境界を明確にし、二重正本や不要な Graph runtime を作らずに設計判断できるようにする。

## 1. Core model

ai-loop V2 では Loop / Graph / Harness を、置換関係ではなく異なる責務として扱う。

> **Loop is the unit of feedback and convergence. Graph is the unit of coordination topology. Harness is the execution environment that makes both reliable.**

- **Loop**: Evidence を観測し、進捗を判断し、repair / replan / stop しながら bounded goal へ収束させる。
- **Graph**: node / edge / branch / join / wait / resume / recovery を通じて、複数責務の実行順序と遷移を明示する。
- **Harness**: context / tool / permission / state primitive / verifier / policy / budget / observability を提供し、Loop と Graph を安全・再現可能に実行する。

`Prompt -> Context -> Harness -> Loop -> Graph` を成熟度や年代順として扱わない。Graph は Loop を置き換えない。

## 2. Composition rules

Loop と Graph は直交し、必要に応じて合成する。

- Graph は複数の Loop を含められる。
- Loop は複数の Graph node を巡回できる。
- Loop 自体を、より大きな Graph の node として扱える。
- node は Agent / LLM に限定しない。deterministic code / tool / verifier / gate / Human action / another Loop も node になれる。

V2 の既存責務へ当てはめると次のようになる。

| Concern | Primary responsibility | Canonical owner / reference |
|---|---|---|
| 1 Task を Evidence で `MERGE_READY` へ収束 | Loop | Delivery Loop / [`north-star.md`](./north-star.md) |
| 複数 Run から Harness N+1 Candidate を作り評価 | Loop | Evolution Loop / #869 |
| progress / retry / no-progress / stop | Loop | #894 |
| branch / join / durable wait / resume / recovery | Graph | #1025 / #911 |
| node 遷移の妥当性評価 | Graph + Evaluation | #908 |
| RunEvidence / failure evidence | Harness evidence | #874 / [`artifact-responsibilities.md`](./artifact-responsibilities.md) |
| Harness identity / activation | Harness | [`harness-manifest.md`](./harness-manifest.md) |
| evaluator / protected authority | Harness trust boundary | [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) |

## 3. Boundary rules

責務が重なる箇所では、次で分ける。

### Loop owns convergence semantics

Loop は「次に何をすべきか」のうち、Evidence と Contract に基づく収束判断を持つ。

```text
continue | repair | replan | stop / escalate
```

単なる `retry < N` は Loop ではない。Iteration 間で progress / evidence delta / failure fingerprint を比較する原則は [`north-star.md`](./north-star.md) §8 を正とする。

### Graph owns coordination topology

Graph は「どの責務へ遷移するか」を明示する。

```text
node -> edge -> node
      branch / join / wait / resume / recovery
```

Graph の node 到達だけでは、その node の Contract が満たされた証拠にならない。完了判定は Verifier / Evidence / Gate の責務を維持する。

### Harness owns reliable execution conditions

Harness は Graph state の意味そのものではなく、state を安全に保存・復元する primitive や runtime 条件を提供する。

- Graph: `current_node`, transition, waiting / recovery path の意味
- Harness: persistence, checkpoint, CAS, tool / permission, verifier availability, activation evidence

Active Run 中の Harness identity は [`harness-manifest.md`](./harness-manifest.md) に従い固定する。

## 4. Minimum topology principle

**まず最小の制御構造を選ぶ。** AI を使うこと自体は Graph 導入理由にならない。

単一 Loop を優先する条件:

- bounded goal が 1 つ
- 実行がほぼ線形
- meaningful な parallel / join がない
- durable Human / External wait-resume がない
- 独立した trust domain への handoff が不要
- failure を同一 Loop 内の repair / replan で表現できる

明示的な Graph を導入する条件:

- branch ごとに Contract / permission が異なる
- parallel work を明示的な join 条件で収束させる必要がある
- Planner / Builder / Verifier / Decision Engine 間の handoff を durable にする必要がある
- Human / External wait を session / process loss を越えて resume する必要がある
- independent reviewer / evaluator を別 trust path として隔離する必要がある
- recovery / rollback が通常経路と異なる
- 複数の sub-Loop を orchestration する必要がある

> **Do not graph what a single Loop can express clearly. Do not hide real coordination complexity inside one opaque Loop.**

## 5. Graph safety invariants

Graph を使う場合も、V2 の既存 invariant を弱めない。

1. node は primary responsibility を明確にし、plan / build / verify / decide を無制限に同居させない。
2. non-trivial edge は Evidence / Policy / Human or External event のいずれかに根拠を持つ。
3. interruption が重要な state は conversation history や live process を正本にしない。
4. parallel work の完了は worker の自己申告ではなく join condition と Evidence で判定する。
5. retry / repair / replan / wait / escalate / rollback / stop を暗黙の例外経路にしない。
6. C-4 / Merge / policy / permission / First Principles / Production Harness promotion の Human-owned authority は Graph edge によって AI-owned へ変換しない。
7. Candidate は Graph を変更しても、自分を裁く authority を変更できない。

> **Candidate cannot modify the authority that judges the candidate.**

## 6. Diagnosis heuristic

失敗を Model に帰属する前に、周辺システムを確認する。

```text
Harness -> Loop -> Graph -> Model -> External
```

これは診断順序の heuristic であり、新しい persisted failure taxonomy ではない。FailureRecord / RunEvidence の schema は companion canon と #874 を正とする。

## 7. Existing owner mapping

Issue #923 は Harness / Loop / Graph の横断整理を提案したが、実装責務が既存 Issue に存在するため **SUPERSEDED** で close 済みである。本書は #923 を reopen せず、概念の解釈だけを残す。

| Concern | Existing owner |
|---|---|
| Stop / progress / retry strategy | #894 |
| Durable state / Human interrupt / resume | #1025 |
| RunEvidence / failure evidence | #874 |
| Trajectory evaluation | #908 |
| Work Item Graph / intent-to-execution structure | #911 |
| Harness Evolution | #869 |
| Canon / Trust Boundary | #1275 + V2 companion canon |

具体的な Contract が owner 側で定義された場合は、owner 側を正とする。

## 8. Non-goals

- LangGraph 等の特定 Graph framework を導入すること
- concrete requirement より先に generic Graph runtime を作ること
- 全 workflow を Graph 化すること
- Delivery Loop / Evolution Loop の用語を Graph に置き換えること
- state / outcome / stop reason / failure schema を本書で再定義すること
- Graph routing を Verifier / Gate の代替にすること
- Human-owned authority を縮小すること

## 9. Working rule

設計責務に迷ったときは、次の 3 問で判断する。

```text
How does this work converge and stop?    -> Loop
What coordinates the next transition?   -> Graph
What makes execution reliable and safe? -> Harness
```

そのうえで、要件を満たせる**最小の既存 owner**へ実装責務を置く。

## References

Informative only. Repository canon takes precedence.

- #923 — Harness / Loop / Graph Engineering responsibility separation (SUPERSEDED)
- https://x.com/Sumanth_077/status/2097689190712692965 — Loop vs Graph Engineering discussion
