# ai-loop V2 — Loop / Graph / Harness Responsibility Model

> **Status**: ai-loop V2 の責務解釈ガイド。正本は [`north-star.md`](./north-star.md) と companion canon であり、本書はそれらに従属する。
> **Purpose**: Loop / Graph / Harness の境界を明確にし、二重正本や不要な Graph runtime を作らずに設計判断できるようにする。
> **Derived from**: canon 6 本（`north-star.md` / `taxonomy.md` / `harness-manifest.md` / `evaluation-trust-boundary.md` / `artifact-responsibilities.md` / `phase0-migration.md`）@ `b1217b41`。**本書は canon ではないため `phase0-migration.md` §7 の canon 7 本には加えない。** 下記が `b1217b41` 以外を返したら canon が動いているので、§2 の責務表と §3 の境界規則を読み直すこと。
>
> ```sh
> git log -1 --format=%h origin/main -- docs/ai/ai-loop-v2/north-star.md \
>   docs/ai/ai-loop-v2/taxonomy.md docs/ai/ai-loop-v2/harness-manifest.md \
>   docs/ai/ai-loop-v2/evaluation-trust-boundary.md \
>   docs/ai/ai-loop-v2/artifact-responsibilities.md \
>   docs/ai/ai-loop-v2/phase0-migration.md
> ```

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

**本表が責務と owner の唯一の対応表である**（§7 で再掲しない）。

| Concern | 責務 | Owner / 正本 |
|---|---|---|
| 1 Task を Evidence で `MERGE_READY` へ収束 | Loop | Delivery Loop / [`north-star.md`](./north-star.md) |
| 複数 Run から Harness N+1 Candidate を作り評価（Harness Evolution） | Loop | Evolution Loop / #869 |
| stop / progress / retry strategy | Loop | #894 / [`north-star.md`](./north-star.md) §8 |
| durable state / Human interrupt / wait-resume / recovery | Graph + Harness | #1025 |
| Work Item Graph / intent-to-execution structure（branch / join） | Graph | #911 |
| node 遷移の妥当性評価（Trajectory evaluation） | Graph + Evaluation | #908 |
| RunEvidence / failure evidence | Harness evidence | #874 / [`artifact-responsibilities.md`](./artifact-responsibilities.md) |
| Harness identity / activation | Harness | [`harness-manifest.md`](./harness-manifest.md) |
| evaluator / protected authority | Harness trust boundary | [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) |
| Canon / Trust Boundary の維持 | Harness canon | #1275 + V2 companion canon |

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

## 7. Precedence

Issue #923 は Harness / Loop / Graph の横断整理を提案したが、実装責務が既存 Issue に存在するため **SUPERSEDED** で close 済みである。本書は #923 を reopen せず、概念の解釈だけを残す。

owner と正本の対応は **§2 の表が唯一**である。ここで再掲しない（2 箇所を同期し続ける状態を作らないため）。

優先順位は次のとおり。

1. **owner 側で具体的な Contract が定義されたら owner 側を正とする**
2. canon（`north-star.md` と companion canon）が本書と食い違ったら **canon を正とし、本書を直す**
3. 本書は 1 / 2 のいずれも定めていない範囲の**解釈**だけを持つ

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
